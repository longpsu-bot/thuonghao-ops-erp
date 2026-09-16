type Matrix = (string | number | boolean | null)[][];
type ReadResult =
  | { ok: true; values: Matrix }
  | {
      ok: false;
      status: number;
      code: string;
      message: string;
      retryable: boolean;
    };
type ReadOptions = {
  url?: string;
  secret?: string;
  spreadsheetId: string;
  sheetName: string;
  range: string;
  weekStart: string;
  requestId: string;
  fetchImpl: typeof fetch;
};
const maximumBytes = 1_500_000;
const fail = (
  status: number,
  code: string,
  message: string,
  retryable = false,
): ReadResult => ({ ok: false, status, code, message, retryable });
function endpoint(raw: string | undefined): URL | null {
  try {
    const u = new URL(raw ?? "");
    return u.protocol === "https:" &&
      u.hostname === "script.google.com" &&
      !u.port &&
      !u.username &&
      !u.password &&
      !u.search &&
      !u.hash &&
      /^\/macros\/s\/[A-Za-z0-9_-]+\/exec$/.test(u.pathname)
      ? u
      : null;
  } catch {
    return null;
  }
}
function contentRedirect(raw: string | null): URL | null {
  try {
    const u = new URL(raw ?? "");
    return u.protocol === "https:" &&
      u.hostname === "script.googleusercontent.com" &&
      !u.port &&
      !u.username &&
      !u.password &&
      !u.hash &&
      u.pathname === "/macros/echo"
      ? u
      : null;
  } catch {
    return null;
  }
}
function record(x: unknown): x is Record<string, unknown> {
  return typeof x === "object" && x !== null && !Array.isArray(x);
}
async function boundedJson(response: Response): Promise<unknown> {
  const length = Number(response.headers.get("Content-Length") ?? 0);
  if (length > maximumBytes) {
    await response.body?.cancel();
    throw new Error("RESPONSE_SIZE_LIMIT");
  }
  if (!response.body) return null;
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    for (;;) {
      const part = await reader.read();
      if (part.done) break;
      total += part.value.byteLength;
      if (total > maximumBytes) {
        await reader.cancel();
        throw new Error("RESPONSE_SIZE_LIMIT");
      }
      chunks.push(part.value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(total);
  let at = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, at);
    at += chunk.length;
  }
  try {
    return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch {
    return null;
  }
}
export async function readWeeklyMenuWebApp(
  options: ReadOptions,
): Promise<ReadResult> {
  const target = endpoint(options.url);
  if (!target)
    return fail(
      503,
      "GOOGLE_WEBAPP_NOT_CONFIGURED",
      "The configured Apps Script Web App endpoint is unavailable or invalid.",
    );
  if (!options.secret || options.secret.length > 1024)
    return fail(
      503,
      "GOOGLE_CREDENTIAL_MISSING",
      "The server-side Apps Script shared secret is not configured.",
    );
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 30000);
  try {
    let response = await options.fetchImpl(target.href, {
      method: "POST",
      redirect: "manual",
      signal: controller.signal,
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        event: "atlas_weekly_menu_read",
        contract_version: "ATLAS-WEEKLY-MENU-READ.v1",
        week_start: options.weekStart,
        request_id: options.requestId,
        secret: options.secret,
      }),
    });
    // Only Google's documented one-time ContentService response location. The
    // second request is a fresh GET, with no incoming JWT, shared secret or body.
    if (response.status === 302 || response.status === 303) {
      const location = contentRedirect(response.headers.get("Location"));
      await response.body?.cancel();
      if (!location)
        return fail(
          502,
          "GOOGLE_WEBAPP_REDIRECT_REJECTED",
          "The Web App did not return an allowed content-service redirect.",
        );
      response = await options.fetchImpl(location.href, {
        method: "GET",
        redirect: "manual",
        signal: controller.signal,
        headers: { Accept: "application/json" },
      });
    }
    if (response.status >= 300 && response.status < 400) {
      await response.body?.cancel();
      return fail(
        502,
        "GOOGLE_WEBAPP_REDIRECT_REJECTED",
        "Unexpected Web App redirect.",
      );
    }
    if (!response.ok) {
      await response.body?.cancel();
      const retryable = response.status === 429 || response.status >= 500;
      return fail(
        retryable ? 503 : 502,
        retryable ? "GOOGLE_UPSTREAM_RETRYABLE" : "GOOGLE_UPSTREAM_FAILED",
        "The Apps Script read is currently unavailable.",
        retryable,
      );
    }
    const data = await boundedJson(response);
    if (!record(data))
      return fail(
        502,
        "MALFORMED_GOOGLE_RESPONSE",
        "The Apps Script Web App returned malformed data.",
      );
    if (data.success !== true) {
      const known: Record<string, [number, string, string]> = {
        UNAUTHORIZED: [
          502,
          "GOOGLE_AUTH_FAILED",
          "The Apps Script reader rejected its server credential.",
        ],
        WEEKLY_SHEET_MISSING: [
          404,
          "WEEKLY_SHEET_MISSING",
          "The selected weekly sheet was not found.",
        ],
        EMPTY_SHEET: [
          422,
          "EMPTY_SHEET",
          "The selected weekly sheet contains no rows.",
        ],
        RESPONSE_SIZE_LIMIT: [
          413,
          "RESPONSE_SIZE_LIMIT",
          "The weekly sheet exceeds the bounded source range or response size.",
        ],
        SOURCE_NOT_CONFIGURED: [
          503,
          "GOOGLE_WEBAPP_NOT_CONFIGURED",
          "The Apps Script reader source has not been configured.",
        ],
      };
      const safe =
        typeof data.error_code === "string"
          ? known[data.error_code]
          : undefined;
      return safe
        ? fail(...safe)
        : fail(
            502,
            "GOOGLE_UPSTREAM_FAILED",
            "The Apps Script reader rejected the request safely.",
          );
    }
    if (
      data.contract_version !== "ATLAS-WEEKLY-MENU-READ.v1" ||
      data.request_id !== options.requestId ||
      data.week_start !== options.weekStart ||
      data.spreadsheet_id !== options.spreadsheetId ||
      data.sheet_name !== options.sheetName ||
      data.range !== options.range
    )
      return fail(
        502,
        "GOOGLE_SOURCE_EVIDENCE_MISMATCH",
        "Returned source evidence does not match the configured Sheet and selected week.",
      );
    const values = data.rows;
    if (Array.isArray(values) && !values.length)
      return fail(
        422,
        "EMPTY_SHEET",
        "The selected weekly sheet contains no rows.",
      );
    if (
      !Array.isArray(values) ||
      !values.every(
        (row) =>
          Array.isArray(row) &&
          row.length <= 9 &&
          row.every(
            (cell) =>
              cell === null ||
              typeof cell === "string" ||
              typeof cell === "boolean" ||
              (typeof cell === "number" && Number.isFinite(cell)),
          ),
      )
    )
      return fail(
        502,
        "MALFORMED_GOOGLE_RESPONSE",
        "The Apps Script reader returned malformed matrix rows.",
      );
    if (values.length > 498)
      return fail(
        413,
        "RESPONSE_SIZE_LIMIT",
        "The weekly sheet exceeds the bounded source range.",
      );
    return { ok: true, values: values as Matrix };
  } catch (error) {
    if (error instanceof Error && error.message === "RESPONSE_SIZE_LIMIT")
      return fail(
        413,
        "RESPONSE_SIZE_LIMIT",
        "The Apps Script response exceeds the safe size limit.",
      );
    return fail(
      503,
      "GOOGLE_UPSTREAM_RETRYABLE",
      "The Apps Script read could not complete; retry the explicit fetch.",
      true,
    );
  } finally {
    clearTimeout(timer);
  }
}
