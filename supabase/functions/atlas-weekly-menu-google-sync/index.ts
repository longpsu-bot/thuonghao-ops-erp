import { readWeeklyMenuWebApp } from "./webAppTransport.ts";

type RuntimeEnv = {
  get(name: string): string | undefined;
};

type HandlerDependencies = {
  fetch: typeof fetch;
  env: RuntimeEnv;
  now: () => Date;
};

type GoogleSource = {
  weekly_menu_google_source_id: string;
  source_code: string;
  source_name: string;
  spreadsheet_id: string;
  sheet_name_pattern: string;
  range_a1_template: string;
  source_status: "ACTIVE";
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const jsonHeaders = {
  ...corsHeaders,
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const weekPattern = /^\d{4}-\d{2}-\d{2}$/;

function safeResponse(
  status: number,
  value: Record<string, unknown>,
): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: jsonHeaders,
  });
}

function failure(
  status: number,
  code: string,
  safeMessage: string,
  correlationId: string | null,
  retryable = false,
) {
  return safeResponse(status, {
    success: false,
    error_code: code,
    safe_message: safeMessage,
    retryable,
    correlation_id: correlationId,
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function safeJson(response: Response): Promise<unknown> {
  try {
    return await response.json();
  } catch (error) {
    if (error instanceof SyntaxError) return null;
    throw error;
  }
}

function validMonday(value: string) {
  if (!weekPattern.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return (
    !Number.isNaN(date.valueOf()) &&
    date.toISOString().slice(0, 10) === value &&
    date.getUTCDay() === 1
  );
}

function weekLabel(value: string) {
  const [year, month, day] = value.split("-");
  return `${day}-${month}-${year}`;
}

function configuredRange(source: GoogleSource, weekStart: string) {
  const sheetName = source.sheet_name_pattern.replaceAll(
    "{DD-MM-YYYY}",
    weekLabel(weekStart),
  );
  const escapedSheetName = sheetName.replaceAll("'", "''");
  const range = source.range_a1_template.replaceAll(
    "{sheet}",
    escapedSheetName,
  );
  const valid =
    source.sheet_name_pattern === "Tuần {DD-MM-YYYY}" &&
    source.range_a1_template === "'{sheet}'!A3:I500" &&
    sheetName.length > 0 &&
    sheetName.length <= 100 &&
    range.length <= 250 &&
    /^(?:'[^']+'|[^'!]+)![A-Z]{1,3}\d+:[A-Z]{1,3}\d+$/i.test(range);
  return { sheetName, range, valid };
}

function defaultEnvironment(): RuntimeEnv {
  const runtime = globalThis as typeof globalThis & {
    Deno?: { env?: { get(name: string): string | undefined } };
  };
  return {
    get(name: string) {
      return runtime.Deno?.env?.get(name);
    },
  };
}

function atlasHeaders(apiKey: string, authorization: string) {
  return {
    apikey: apiKey,
    Authorization: authorization,
    "Content-Type": "application/json",
    "Content-Profile": "atlas_api",
  };
}

export function createGoogleSyncHandler(
  overrides: Partial<HandlerDependencies> = {},
) {
  const dependencies: HandlerDependencies = {
    fetch,
    env: defaultEnvironment(),
    now: () => new Date(),
    ...overrides,
  };
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS")
      return new Response(null, { status: 204, headers: corsHeaders });
    if (request.method !== "POST")
      return failure(
        405,
        "METHOD_NOT_ALLOWED",
        "Use POST for this connector.",
        null,
      );

    const authorization = request.headers.get("Authorization") ?? "";
    if (!/^Bearer\s+\S+$/i.test(authorization)) {
      return failure(
        401,
        "SESSION_REQUIRED",
        "An authenticated Atlas session is required.",
        null,
      );
    }

    let body: Record<string, unknown>;
    try {
      const parsed = await request.json();
      if (!isRecord(parsed))
        return failure(
          400,
          "INVALID_REQUEST",
          "The connector request is invalid.",
          null,
        );
      body = parsed;
    } catch {
      return failure(
        400,
        "INVALID_REQUEST",
        "The connector request is invalid.",
        null,
      );
    }
    const correlationId =
      typeof body.correlation_id === "string" ? body.correlation_id : null;
    const sourceId =
      typeof body.weekly_menu_google_source_id === "string"
        ? body.weekly_menu_google_source_id
        : "";
    const weekStart =
      typeof body.week_start === "string" ? body.week_start : "";
    if (
      "spreadsheet_id" in body ||
      "sheet_name" in body ||
      "range" in body ||
      "range_a1" in body ||
      "url" in body ||
      "webapp_url" in body ||
      "secret" in body ||
      "event" in body
    ) {
      return failure(
        400,
        "BROWSER_SOURCE_AUTHORITY_REJECTED",
        "Spreadsheet identity and range must come from Atlas configuration.",
        correlationId,
      );
    }
    if (!correlationId || !uuidPattern.test(correlationId)) {
      return failure(
        400,
        "INVALID_CORRELATION_ID",
        "A valid correlation ID is required.",
        correlationId,
      );
    }
    if (!uuidPattern.test(sourceId)) {
      return failure(
        400,
        "INVALID_GOOGLE_SOURCE",
        "The configured Google Sheet source is invalid.",
        correlationId,
      );
    }
    if (!validMonday(weekStart)) {
      return failure(
        400,
        "INVALID_WEEK",
        "Select a valid Monday service-week start.",
        correlationId,
      );
    }

    const supabaseUrl = dependencies.env
      .get("SUPABASE_URL")
      ?.replace(/\/$/u, "");
    const apiKey =
      dependencies.env.get("SUPABASE_PUBLISHABLE_KEY") ??
      dependencies.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !apiKey) {
      return failure(
        503,
        "CONNECTOR_UNAVAILABLE",
        "The Atlas connector environment is unavailable.",
        correlationId,
        true,
      );
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 35_000);
    const signal = AbortSignal.any([request.signal, controller.signal]);
    try {
      signal.throwIfAborted();
      const userResponse = await dependencies.fetch(
        `${supabaseUrl}/auth/v1/user`,
        {
          headers: { apikey: apiKey, Authorization: authorization },
          signal,
        },
      );
      if (!userResponse.ok) {
        await userResponse.body?.cancel();
        const unauthenticated = [401, 403].includes(userResponse.status);
        const retryable =
          userResponse.status === 429 || userResponse.status >= 500;
        return failure(
          unauthenticated ? 401 : retryable ? 503 : 502,
          unauthenticated ? "SESSION_EXPIRED" : "CONNECTOR_UNAVAILABLE",
          unauthenticated
            ? "The Atlas session is missing or expired."
            : "The Atlas authentication service is currently unavailable.",
          correlationId,
          retryable,
        );
      }
      const userBody = await safeJson(userResponse);
      signal.throwIfAborted();
      if (!isRecord(userBody) || typeof userBody.id !== "string") {
        return failure(
          502,
          "CONNECTOR_UNAVAILABLE",
          "The Atlas authentication service returned an invalid response.",
          correlationId,
        );
      }
      const atlasResponse = await dependencies.fetch(
        `${supabaseUrl}/rest/v1/rpc/get_planning_inputs_workbench`,
        {
          method: "POST",
          headers: atlasHeaders(apiKey, authorization),
          signal,
          body: JSON.stringify({
            request: {
              contract_version: "RMVP-03A.v1",
              requested_by_auth_subject: userBody.id,
              correlation_id: correlationId,
              payload: {
                week_start: weekStart,
                google_connector_source_id: sourceId,
              },
            },
          }),
        },
      );
      if (atlasResponse.status === 429 || atlasResponse.status >= 500) {
        await atlasResponse.body?.cancel();
        return failure(
          503,
          "CONNECTOR_UNAVAILABLE",
          "The Atlas Planning service is temporarily unavailable.",
          correlationId,
          true,
        );
      }
      if (atlasResponse.status === 401) {
        await atlasResponse.body?.cancel();
        return failure(
          401,
          "SESSION_EXPIRED",
          "The Atlas session is missing or expired.",
          correlationId,
        );
      }
      const atlasBody = await safeJson(atlasResponse);
      signal.throwIfAborted();
      if (
        !atlasResponse.ok ||
        !isRecord(atlasBody) ||
        atlasBody.success !== true
      ) {
        const atlasCode =
          isRecord(atlasBody) && typeof atlasBody.error_code === "string"
            ? atlasBody.error_code
            : "CONNECTOR_AUTHORIZATION_FAILED";
        const denied =
          atlasResponse.status === 403 ||
          atlasCode === "CAPABILITY_DENIED" ||
          atlasCode === "SCOPE_DENIED";
        const missing = atlasCode === "GOOGLE_SOURCE_UNAVAILABLE";
        return failure(
          denied ? 403 : missing ? 404 : 502,
          denied
            ? "CAPABILITY_DENIED"
            : missing
              ? "GOOGLE_SOURCE_UNAVAILABLE"
              : "CONNECTOR_UNAVAILABLE",
          denied
            ? "You are not authorized to read Planning inputs."
            : missing
              ? "The configured Google Sheet source is unknown or inactive."
              : "The Atlas Planning service returned an invalid response.",
          correlationId,
        );
      }
      const sourceValue = atlasBody.google_connector_source;
      if (isRecord(sourceValue) && sourceValue.source_status === "INACTIVE") {
        return failure(
          404,
          "GOOGLE_SOURCE_UNAVAILABLE",
          "The configured Google Sheet source is unknown or inactive.",
          correlationId,
        );
      }
      if (!isRecord(sourceValue) || sourceValue.source_status !== "ACTIVE") {
        return failure(
          502,
          "MALFORMED_ATLAS_SOURCE",
          "Atlas returned malformed connector configuration.",
          correlationId,
        );
      }
      const source = sourceValue as unknown as GoogleSource;
      if (
        source.weekly_menu_google_source_id !== sourceId ||
        typeof source.spreadsheet_id !== "string" ||
        typeof source.sheet_name_pattern !== "string" ||
        typeof source.range_a1_template !== "string"
      ) {
        return failure(
          502,
          "MALFORMED_ATLAS_SOURCE",
          "Atlas returned malformed connector configuration.",
          correlationId,
        );
      }
      const range = configuredRange(source, weekStart);
      if (!range.valid) {
        return failure(
          422,
          "CONFIGURED_RANGE_INVALID",
          "The configured Google Sheet range is invalid.",
          correlationId,
        );
      }

      const webApp = await readWeeklyMenuWebApp({
        url: dependencies.env.get("GOOGLE_APPS_SCRIPT_WEBAPP_URL"),
        secret: dependencies.env.get("GOOGLE_APPS_SCRIPT_SECRET"),
        spreadsheetId: source.spreadsheet_id,
        sheetName: range.sheetName,
        range: range.range,
        weekStart,
        requestId: correlationId,
        fetchImpl: dependencies.fetch,
        signal,
      });
      signal.throwIfAborted();
      if (!webApp.ok)
        return failure(
          webApp.status,
          webApp.code,
          webApp.message,
          correlationId,
          webApp.retryable,
        );
      const values = webApp.values;
      return safeResponse(200, {
        success: true,
        source: {
          source_id: source.weekly_menu_google_source_id,
          source_code: source.source_code,
          source_name: source.source_name,
          sheet_name: range.sheetName,
          range: range.range,
        },
        fetched_at: dependencies.now().toISOString(),
        rows: values,
        warnings: [],
        correlation_id: correlationId,
      });
    } catch {
      return failure(
        503,
        controller.signal.aborted
          ? "CONNECTOR_TIMEOUT"
          : "CONNECTOR_UNAVAILABLE",
        controller.signal.aborted
          ? "The Menu source read exceeded its time limit; retry the explicit synchronization."
          : "The Menu source read was interrupted; retry the explicit synchronization.",
        correlationId,
        true,
      );
    } finally {
      clearTimeout(timer);
    }
  };
}

const runtime = globalThis as typeof globalThis & {
  Deno?: {
    serve(handler: (request: Request) => Response | Promise<Response>): void;
  };
};

if (runtime.Deno?.serve) {
  runtime.Deno.serve(createGoogleSyncHandler());
}
