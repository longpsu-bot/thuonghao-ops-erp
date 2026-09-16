// @vitest-environment node
import { describe, expect, it, vi } from "vitest";
import { readWeeklyMenuWebApp } from "./webAppTransport";
const url = "https://script.google.com/macros/s/synthetic-deployment/exec";
const secret = "synthetic-secret-atlas";
const requestId = "a1000000-0000-4000-8000-000000000002";
const rows = [
  ["Tên trường", "Thứ", "Ngày", "Món canh"],
  ["A", "Hai", "2026-09-21", "Soup"],
];
const expected = {
  spreadsheetId: "fixture-sheet",
  sheetName: "Tuần 21-09-2026",
  range: "'Tuần 21-09-2026'!A3:I500",
  weekStart: "2026-09-21",
  requestId,
};
const success = (extra = {}) =>
  Response.json({
    success: true,
    contract_version: "ATLAS-WEEKLY-MENU-READ.v1",
    request_id: requestId,
    week_start: expected.weekStart,
    spreadsheet_id: expected.spreadsheetId,
    sheet_name: expected.sheetName,
    range: expected.range,
    rows,
    ...extra,
  });
const read = (fetchImpl: typeof fetch, extra = {}) =>
  readWeeklyMenuWebApp({ url, secret, ...expected, fetchImpl, ...extra });
describe("Apps Script server transport", () => {
  it("POSTs only the bounded request and never an Atlas JWT or caller range", async () => {
    const f = vi.fn<typeof fetch>(async () => success());
    expect(await read(f)).toEqual({ ok: true, values: rows });
    const [target, init] = f.mock.calls[0];
    expect(target).toBe(url);
    expect(init?.redirect).toBe("manual");
    expect(JSON.parse(String(init?.body))).toEqual({
      event: "atlas_weekly_menu_read",
      contract_version: "ATLAS-WEEKLY-MENU-READ.v1",
      week_start: expected.weekStart,
      request_id: requestId,
      secret,
    });
    expect(new Headers(init?.headers).has("Authorization")).toBe(false);
  });
  it("follows ContentService response redirect using GET without forwarding the secret", async () => {
    const f = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(
        new Response(null, {
          status: 302,
          headers: {
            Location:
              "https://script.googleusercontent.com/macros/echo?user_content_key=opaque",
          },
        }),
      )
      .mockResolvedValueOnce(success());
    expect((await read(f)).ok).toBe(true);
    expect(f.mock.calls[1][1]).toMatchObject({
      method: "GET",
      redirect: "manual",
    });
    expect(f.mock.calls[1][1]?.body).toBeUndefined();
    expect(JSON.stringify(f.mock.calls[1])).not.toContain(secret);
  });
  it.each([
    "https://attacker.test/exec",
    "http://script.google.com/macros/s/a/exec",
    "https://script.google.com.evil.test/macros/s/a/exec",
    "https://user:password@script.google.com/macros/s/a/exec",
    "https://script.google.com/macros/s/a/dev",
    url + "?secret=bad",
  ])("rejects invalid configured endpoint %s before fetch", async (invalid) => {
    const f = vi.fn<typeof fetch>();
    expect((await read(f, { url: invalid })).ok).toBe(false);
    expect(f).not.toHaveBeenCalled();
  });
  it.each([
    "https://accounts.google.com/login",
    "https://script.googleusercontent.com.evil.test/echo",
    "http://script.googleusercontent.com/echo",
    "https://elsewhere.test/echo",
  ])("rejects redirect target %s", async (target) => {
    const f = vi.fn<typeof fetch>(
      async () =>
        new Response(null, { status: 302, headers: { Location: target } }),
    );
    expect((await read(f)).ok).toBe(false);
    expect(f).toHaveBeenCalledOnce();
  });
  it.each([307, 308])(
    "never replays a secret-bearing POST on HTTP %s",
    async (status) => {
      const f = vi.fn<typeof fetch>(
        async () =>
          new Response(null, {
            status,
            headers: {
              Location: "https://script.googleusercontent.com/macros/echo",
            },
          }),
      );
      expect((await read(f)).ok).toBe(false);
      expect(f).toHaveBeenCalledOnce();
    },
  );
  it("rejects mismatched source, week, request and protocol evidence", async () => {
    for (const extra of [
      { spreadsheet_id: "other" },
      { week_start: "2026-09-28" },
      { request_id: "other" },
      { range: "'Tuần 21-09-2026'!A1:Z999" },
      { contract_version: "OLD" },
      { sheet_name: "wrong" },
    ])
      expect((await read(async () => success(extra))).ok).toBe(false);
  });
  it("does not confuse HTTP 200 errors with data or expose upstream errors", async () => {
    const r = await read(async () =>
      Response.json({
        success: false,
        error_code: "WEEKLY_SHEET_MISSING",
        message: "private detail",
      }),
    );
    expect(r).toMatchObject({ ok: false, code: "WEEKLY_SHEET_MISSING" });
    expect(JSON.stringify(r)).not.toContain("private detail");
  });
  it("bounds streamed UTF-8 bytes without trusting Content-Length", async () => {
    const r = await read(
      async () =>
        new Response(
          new ReadableStream({
            start(c) {
              c.enqueue(new TextEncoder().encode("x".repeat(1500001)));
              c.close();
            },
          }),
          { headers: { "Content-Type": "application/json" } },
        ),
    );
    expect(r).toMatchObject({ ok: false, code: "RESPONSE_SIZE_LIMIT" });
  });
  it("rejects malformed/empty matrices and enforces nine columns", async () => {
    for (const value of [null, [{}], [[{}]], [["x"].concat(Array(9).fill(""))]])
      expect((await read(async () => success({ rows: value }))).ok).toBe(false);
    expect(await read(async () => success({ rows: [] }))).toMatchObject({
      ok: false,
      code: "EMPTY_SHEET",
    });
  });
  it("returns a safe retryable result for network/429 failures without automatic retry", async () => {
    const f = vi.fn<typeof fetch>(async () => {
      throw new Error(secret);
    });
    expect(await read(f)).toMatchObject({ ok: false, retryable: true });
    expect(f).toHaveBeenCalledOnce();
    expect(
      await read(async () => new Response("upstream private", { status: 429 })),
    ).toMatchObject({ ok: false, retryable: true });
  });
  it("fails before network when credential absent", async () => {
    const f = vi.fn<typeof fetch>();
    expect(await read(f, { secret: "" })).toMatchObject({
      ok: false,
      code: "GOOGLE_CREDENTIAL_MISSING",
    });
    expect(f).not.toHaveBeenCalled();
  });
});
