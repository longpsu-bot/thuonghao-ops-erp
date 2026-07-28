import { describe, expect, it, vi } from "vitest";
import { createGoogleSyncHandler } from "./index";

const sourceId = "a1000000-0000-4000-8000-000000000001";
const correlationId = "a1000000-0000-4000-8000-000000000002";
const authorization = "Bearer test-atlas-jwt";
const source = {
  weekly_menu_google_source_id: sourceId,
  source_code: "synthetic-menu",
  source_name: "Synthetic weekly menu",
  spreadsheet_id: "synthetic-spreadsheet",
  sheet_name_pattern: "Tuần {DD-MM-YYYY}",
  range_a1_template: "'{sheet}'!A3:Z500",
  source_status: "ACTIVE",
  display_order: 1,
  version: 1,
};

function request(body: Record<string, unknown> = {}) {
  return new Request(
    "http://localhost/functions/v1/atlas-weekly-menu-google-sync",
    {
      method: "POST",
      headers: {
        Authorization: authorization,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        weekly_menu_google_source_id: sourceId,
        week_start: "2026-07-27",
        correlation_id: correlationId,
        ...body,
      }),
    },
  );
}

function environment(hasCredential = true) {
  const values: Record<string, string> = {
    SUPABASE_URL: "http://supabase.test",
    SUPABASE_ANON_KEY: "test-browser-key",
  };
  if (hasCredential)
    values.GOOGLE_SERVICE_ACCOUNT_JSON =
      '{"client_email":"fixture@example.test","private_key":"not-used"}';
  return { get: (name: string) => values[name] };
}

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function successfulFetch(
  googleResponse: Response = json({
    values: [
      ["Tên trường", "Ngày", "Món canh"],
      ["school-a", "2026-07-27", "dish-a"],
    ],
  }),
) {
  return vi.fn<typeof fetch>(async (input) => {
    const url = String(input);
    if (url.endsWith("/auth/v1/user")) return json({ id: "user-1" });
    if (url.includes("/rpc/get_planning_inputs_workbench"))
      return json({ success: true, google_connector_source: source });
    if (url.startsWith("https://sheets.googleapis.com/")) return googleResponse;
    throw new Error(`Unexpected fetch: ${url}`);
  });
}

function handler(fetchMock = successfulFetch(), hasCredential = true) {
  return {
    fetchMock,
    handle: createGoogleSyncHandler({
      fetch: fetchMock,
      env: environment(hasCredential),
      now: () => new Date("2026-07-27T03:00:00.000Z"),
      getGoogleAccessToken: async () => ({ accessToken: "test-google-token" }),
    }),
  };
}

describe("atlas-weekly-menu-google-sync", () => {
  it("rejects a missing bearer token before any external call", async () => {
    const fetchMock = successfulFetch();
    const handle = createGoogleSyncHandler({
      fetch: fetchMock,
      env: environment(),
    });
    const response = await handle(
      new Request("http://localhost/function", {
        method: "POST",
        body: JSON.stringify({}),
      }),
    );
    expect(response.status).toBe(401);
    expect(await response.json()).toMatchObject({
      success: false,
      error_code: "SESSION_REQUIRED",
    });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("rejects an invalid source identifier", async () => {
    const { handle, fetchMock } = handler();
    const response = await handle(
      request({ weekly_menu_google_source_id: "browser-value" }),
    );
    expect(await response.json()).toMatchObject({
      error_code: "INVALID_GOOGLE_SOURCE",
    });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("rejects a source absent from the authorized active read", async () => {
    const fetchMock = vi.fn<typeof fetch>(async (input) => {
      const url = String(input);
      if (url.endsWith("/auth/v1/user")) return json({ id: "user-1" });
      return json({
        success: false,
        error_code: "GOOGLE_SOURCE_UNAVAILABLE",
      });
    });
    const { handle } = handler(fetchMock);
    const response = await handle(request());
    expect(response.status).toBe(404);
    expect(await response.json()).toMatchObject({
      error_code: "GOOGLE_SOURCE_UNAVAILABLE",
    });
  });

  it("rejects an inactive connector source returned by a malformed mock", async () => {
    const fetchMock = vi.fn<typeof fetch>(async (input) => {
      const url = String(input);
      if (url.endsWith("/auth/v1/user")) return json({ id: "user-1" });
      return json({
        success: true,
        google_connector_source: { ...source, source_status: "INACTIVE" },
      });
    });
    const { handle } = handler(fetchMock);
    const response = await handle(request());
    expect(await response.json()).toMatchObject({
      error_code: "GOOGLE_SOURCE_UNAVAILABLE",
    });
  });

  it("rejects browser-supplied spreadsheet and range authority", async () => {
    const { handle, fetchMock } = handler();
    const response = await handle(
      request({ spreadsheet_id: "attacker-sheet", range: "A1:Z999" }),
    );
    expect(await response.json()).toMatchObject({
      error_code: "BROWSER_SOURCE_AUTHORITY_REJECTED",
    });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("fails safely when the server-side credential is missing", async () => {
    const { handle } = handler(successfulFetch(), false);
    const response = await handle(request());
    expect(await response.json()).toMatchObject({
      error_code: "GOOGLE_CREDENTIAL_MISSING",
    });
  });

  it("classifies a missing weekly sheet safely", async () => {
    const { handle } = handler(
      successfulFetch(json({ error: { message: "not exposed" } }, 404)),
    );
    const response = await handle(request());
    expect(await response.json()).toMatchObject({
      error_code: "WEEKLY_SHEET_MISSING",
      retryable: false,
    });
  });

  it("classifies retryable upstream failures", async () => {
    const { handle } = handler(successfulFetch(json({}, 429)));
    const response = await handle(request());
    expect(response.status).toBe(503);
    expect(await response.json()).toMatchObject({
      error_code: "GOOGLE_UPSTREAM_RETRYABLE",
      retryable: true,
    });
  });

  it("returns safe source metadata and matrix rows without a database write", async () => {
    const { handle, fetchMock } = handler();
    const response = await handle(request());
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      success: true,
      source: {
        source_id: sourceId,
        source_code: "synthetic-menu",
        source_name: "Synthetic weekly menu",
        sheet_name: "Tuần 27-07-2026",
        range: "'Tuần 27-07-2026'!A3:Z500",
      },
      fetched_at: "2026-07-27T03:00:00.000Z",
      rows: [
        ["Tên trường", "Ngày", "Món canh"],
        ["school-a", "2026-07-27", "dish-a"],
      ],
      correlation_id: correlationId,
    });
    const calls = fetchMock.mock.calls.map(([input, init]) => ({
      url: String(input),
      method: init?.method ?? "GET",
    }));
    expect(calls).toEqual([
      { url: "http://supabase.test/auth/v1/user", method: "GET" },
      {
        url: "http://supabase.test/rest/v1/rpc/get_planning_inputs_workbench",
        method: "POST",
      },
      {
        url:
          "https://sheets.googleapis.com/v4/spreadsheets/" +
          "synthetic-spreadsheet/values/" +
          encodeURIComponent("'Tuần 27-07-2026'!A3:Z500") +
          "?majorDimension=ROWS",
        method: "GET",
      },
    ]);
  });

  it("never exposes credential values or logs connector secrets", async () => {
    const log = vi.spyOn(console, "log").mockImplementation(() => undefined);
    const error = vi
      .spyOn(console, "error")
      .mockImplementation(() => undefined);
    const { handle } = handler(successfulFetch(json({}, 500)));
    const responseText = await (await handle(request())).text();
    expect(responseText).not.toContain("test-google-token");
    expect(responseText).not.toContain("fixture@example.test");
    expect(log).not.toHaveBeenCalled();
    expect(error).not.toHaveBeenCalled();
    log.mockRestore();
    error.mockRestore();
  });
});
