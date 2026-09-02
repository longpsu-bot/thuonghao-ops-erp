type RuntimeEnv = {
  get(name: string): string | undefined;
};

type HandlerDependencies = {
  fetch: typeof fetch;
  env: RuntimeEnv;
  now: () => Date;
  getGoogleAccessToken?: (
    credential: Record<string, unknown>,
  ) => Promise<
    | { accessToken: string; error?: never }
    | { error: string; accessToken?: never }
  >;
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
const maximumResponseBytes = 1_500_000;
const maximumRows = 500;
const maximumColumns = 100;

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
  } catch {
    return null;
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
    sheetName.length > 0 &&
    sheetName.length <= 100 &&
    range.length <= 250 &&
    /^(?:'[^']+'|[^'!]+)![A-Z]{1,3}\d+:[A-Z]{1,3}\d+$/i.test(range);
  return { sheetName, range, valid };
}

function base64Url(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/u, "");
}

function encodedJson(value: unknown) {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)));
}

function pemBytes(pem: string) {
  const body = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/gu, "");
  const binary = atob(body);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function googleAccessToken(
  credential: Record<string, unknown>,
  dependencies: HandlerDependencies,
) {
  const clientEmail =
    typeof credential.client_email === "string" ? credential.client_email : "";
  const privateKey =
    typeof credential.private_key === "string" ? credential.private_key : "";
  const tokenUri =
    typeof credential.token_uri === "string"
      ? credential.token_uri
      : "https://oauth2.googleapis.com/token";
  if (!clientEmail || !privateKey || !tokenUri.startsWith("https://")) {
    return { error: "GOOGLE_CREDENTIAL_INVALID" } as const;
  }
  try {
    const issuedAt = Math.floor(dependencies.now().valueOf() / 1000);
    const header = encodedJson({ alg: "RS256", typ: "JWT" });
    const payload = encodedJson({
      iss: clientEmail,
      scope: "https://www.googleapis.com/auth/spreadsheets.readonly",
      aud: tokenUri,
      iat: issuedAt,
      exp: issuedAt + 3600,
    });
    const signingInput = `${header}.${payload}`;
    const key = await crypto.subtle.importKey(
      "pkcs8",
      pemBytes(privateKey),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"],
    );
    const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(signingInput),
    );
    const assertion = `${signingInput}.${base64Url(new Uint8Array(signature))}`;
    const response = await dependencies.fetch(tokenUri, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    });
    const body = await safeJson(response);
    if (
      !response.ok ||
      !isRecord(body) ||
      typeof body.access_token !== "string"
    ) {
      return {
        error:
          response.status === 429 || response.status >= 500
            ? "GOOGLE_AUTH_RETRYABLE"
            : "GOOGLE_AUTH_FAILED",
      } as const;
    }
    return { accessToken: body.access_token } as const;
  } catch {
    return { error: "GOOGLE_CREDENTIAL_INVALID" } as const;
  }
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
      "range_a1" in body
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
    const userResponse = await dependencies.fetch(
      `${supabaseUrl}/auth/v1/user`,
      {
        headers: { apikey: apiKey, Authorization: authorization },
      },
    );
    const userBody = await safeJson(userResponse);
    if (
      !userResponse.ok ||
      !isRecord(userBody) ||
      typeof userBody.id !== "string"
    ) {
      return failure(
        401,
        "SESSION_EXPIRED",
        "The Atlas session is missing or expired.",
        correlationId,
      );
    }
    const atlasResponse = await dependencies.fetch(
      `${supabaseUrl}/rest/v1/rpc/get_planning_inputs_workbench`,
      {
        method: "POST",
        headers: atlasHeaders(apiKey, authorization),
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
    const atlasBody = await safeJson(atlasResponse);
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
        atlasCode === "CAPABILITY_DENIED" || atlasCode === "SCOPE_DENIED";
      return failure(
        denied ? 403 : 404,
        denied ? "CAPABILITY_DENIED" : "GOOGLE_SOURCE_UNAVAILABLE",
        denied
          ? "You are not authorized to read Planning inputs."
          : "The configured Google Sheet source is unknown or inactive.",
        correlationId,
      );
    }
    const sourceValue = atlasBody.google_connector_source;
    if (!isRecord(sourceValue) || sourceValue.source_status !== "ACTIVE") {
      return failure(
        404,
        "GOOGLE_SOURCE_UNAVAILABLE",
        "The configured Google Sheet source is unknown or inactive.",
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

    const credentialText = dependencies.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
    if (!credentialText) {
      return failure(
        503,
        "GOOGLE_CREDENTIAL_MISSING",
        "The read-only Google credential is not configured.",
        correlationId,
      );
    }
    let credential: Record<string, unknown>;
    try {
      const parsed = JSON.parse(credentialText);
      if (!isRecord(parsed))
        return failure(
          503,
          "GOOGLE_CREDENTIAL_INVALID",
          "The read-only Google credential is invalid.",
          correlationId,
        );
      credential = parsed;
    } catch {
      return failure(
        503,
        "GOOGLE_CREDENTIAL_INVALID",
        "The read-only Google credential is invalid.",
        correlationId,
      );
    }
    const token = dependencies.getGoogleAccessToken
      ? await dependencies.getGoogleAccessToken(credential)
      : await googleAccessToken(credential, dependencies);
    if ("error" in token) {
      const retryable = token.error === "GOOGLE_AUTH_RETRYABLE";
      return failure(
        retryable ? 503 : 502,
        token.error,
        retryable
          ? "Google authentication is temporarily unavailable."
          : "Google authentication failed safely.",
        correlationId,
        retryable,
      );
    }
    const googleUrl =
      "https://sheets.googleapis.com/v4/spreadsheets/" +
      `${encodeURIComponent(source.spreadsheet_id)}/values/` +
      `${encodeURIComponent(range.range)}?majorDimension=ROWS`;
    const googleResponse = await dependencies.fetch(googleUrl, {
      headers: { Authorization: `Bearer ${token.accessToken}` },
    });
    const contentLength = Number(
      googleResponse.headers.get("Content-Length") ?? "0",
    );
    if (contentLength > maximumResponseBytes) {
      return failure(
        413,
        "RESPONSE_SIZE_LIMIT",
        "The Google Sheet response exceeds the safe size limit.",
        correlationId,
      );
    }
    const googleBody = await safeJson(googleResponse);
    if (!googleResponse.ok) {
      if (googleResponse.status === 404 || googleResponse.status === 400) {
        return failure(
          404,
          "WEEKLY_SHEET_MISSING",
          "The selected weekly sheet was not found.",
          correlationId,
        );
      }
      if (googleResponse.status === 401) {
        return failure(
          502,
          "GOOGLE_AUTH_FAILED",
          "Google authentication failed safely.",
          correlationId,
        );
      }
      if (googleResponse.status === 403) {
        return failure(
          403,
          "SPREADSHEET_INACCESSIBLE",
          "The configured spreadsheet is not accessible.",
          correlationId,
        );
      }
      const retryable =
        googleResponse.status === 429 || googleResponse.status >= 500;
      return failure(
        retryable ? 503 : 502,
        retryable ? "GOOGLE_UPSTREAM_RETRYABLE" : "GOOGLE_UPSTREAM_FAILED",
        retryable
          ? "Google Sheets is temporarily unavailable; retry the same fetch."
          : "Google Sheets rejected the configured read safely.",
        correlationId,
        retryable,
      );
    }
    if (!isRecord(googleBody)) {
      return failure(
        502,
        "MALFORMED_GOOGLE_RESPONSE",
        "Google Sheets returned malformed data.",
        correlationId,
      );
    }
    const values = googleBody.values;
    if (
      values === undefined ||
      (Array.isArray(values) && values.length === 0)
    ) {
      return failure(
        422,
        "EMPTY_SHEET",
        "The selected weekly sheet contains no rows.",
        correlationId,
      );
    }
    if (
      !Array.isArray(values) ||
      !values.every(
        (row) =>
          Array.isArray(row) &&
          row.length <= maximumColumns &&
          row.every(
            (cell) =>
              typeof cell === "string" ||
              typeof cell === "number" ||
              typeof cell === "boolean" ||
              cell === null,
          ),
      )
    ) {
      return failure(
        502,
        "MALFORMED_GOOGLE_RESPONSE",
        "Google Sheets returned malformed matrix rows.",
        correlationId,
      );
    }
    if (
      values.length > maximumRows ||
      JSON.stringify(values).length > maximumResponseBytes
    ) {
      return failure(
        413,
        "RESPONSE_SIZE_LIMIT",
        "The Google Sheet response exceeds the safe size limit.",
        correlationId,
      );
    }
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
