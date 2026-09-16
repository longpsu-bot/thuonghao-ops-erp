// @vitest-environment node
import { readFileSync } from "node:fs";
import vm from "node:vm";
import { createHash } from "node:crypto";
import { describe, expect, it, vi } from "vitest";

const base = new URL(
  "../integrations/google-apps-script/weekly-menu/",
  import.meta.url,
);
const secret = "synthetic-read-secret-abcdefghijklmnopqrstuvwxyz";
const requestId = "a1000000-0000-4000-8000-000000000002";
const protocol = "ATLAS-WEEKLY-MENU-READ.v1";
const body = (extra = {}) => ({
  event: "atlas_weekly_menu_read",
  contract_version: protocol,
  week_start: "2026-09-21",
  request_id: requestId,
  secret,
  ...extra,
});
const event = (data) => ({
  parameter: {},
  postData: { contents: JSON.stringify(data), type: "application/json" },
});
function harness({
  missingSecret = false,
  missingSheet = false,
  lastRow = 5,
  rows,
  spreadsheetId = "fixture-spreadsheet",
} = {}) {
  const props = {
    SYNC_SECRET: missingSecret ? "" : secret,
    ATLAS_WEEKLY_MENU_SPREADSHEET_ID: spreadsheetId,
  };
  const sheet = {
    getLastRow: () => lastRow,
    getRange: vi.fn(() => ({
      getValues: () =>
        rows ?? [
          [
            "Tên trường",
            "Thứ",
            "Ngày",
            "Món canh",
            "Món mặn",
            "Món xào",
            "Tráng miệng",
            "Buổi xế",
            "Nước",
          ],
          [
            "School A",
            "Hai",
            new Date("2026-09-20T17:00:00Z"),
            "Soup",
            "",
            "",
            "",
            "",
            "",
          ],
        ],
    })),
  };
  const book = {
    getId: () => spreadsheetId,
    getSpreadsheetTimeZone: () => "Asia/Ho_Chi_Minh",
    getSheetByName: vi.fn(() => (missingSheet ? null : sheet)),
  };
  const openById = vi.fn(() => book);
  const schools = vi.fn(() => ({ school_count: 1 }));
  const dishes = vi.fn();
  const context = vm.createContext({
    Date,
    JSON,
    Object,
    Array,
    String,
    Number,
    Math,
    RegExp,
    Error,
    PropertiesService: {
      getScriptProperties: () => ({
        getProperty: (name) => props[name] ?? null,
      }),
    },
    SpreadsheetApp: { openById },
    Utilities: {
      DigestAlgorithm: { SHA_256: "SHA_256" },
      Charset: { UTF_8: "UTF_8" },
      computeDigest: (_alg, value) =>
        Array.from(createHash("sha256").update(value, "utf8").digest()),
      formatDate: (date, timezone, format) => {
        expect(timezone).toBe("Asia/Ho_Chi_Minh");
        expect(format).toBe("yyyy-MM-dd");
        return new Date(date.valueOf() + 7 * 3600000)
          .toISOString()
          .slice(0, 10);
      },
    },
    ContentService: {
      MimeType: { TEXT: "text", JSON: "json" },
      createTextOutput: (text) => ({
        text,
        setMimeType() {
          return this;
        },
      }),
    },
    syncSchoolsToLists_: schools,
    syncListsValidationFromSupabase: dishes,
  });
  const adapter = readFileSync(
    new URL("AtlasWeeklyMenuReader.js", base),
    "utf8",
  );
  vm.runInContext(adapter, context);
  vm.runInContext(
    readFileSync(new URL("fixtures/legacy-school-handler.js", base), "utf8"),
    context,
  );
  const legacy = readFileSync(
    new URL("fixtures/legacy-doPost.js", base),
    "utf8",
  );
  vm.runInContext(
    legacy.replace(
      "function doPost(e) {",
      "function doPost(e) {\n const atlasRead = maybeHandleAtlasWeeklyMenuRead_(e);\n if (atlasRead !== null) return atlasRead;",
    ),
    context,
  );
  return {
    props,
    context,
    openById,
    book,
    sheet,
    schools,
    dishes,
    read: (data) => JSON.parse(context.doPost(event(data)).text),
  };
}
describe("Apps Script narrow read and preserved v1 dispatcher", () => {
  it("reads only the server-selected workbook/range and preserves Vietnam calendar dates", () => {
    const h = harness();
    const r = h.read(body());
    expect(r).toMatchObject({
      success: true,
      contract_version: protocol,
      request_id: requestId,
      week_start: "2026-09-21",
      spreadsheet_id: "fixture-spreadsheet",
      sheet_name: "Tuần 21-09-2026",
      range: "'Tuần 21-09-2026'!A3:I500",
    });
    expect(r.rows[1][2]).toBe("2026-09-21");
    expect(h.openById).toHaveBeenCalledWith("fixture-spreadsheet");
    expect(h.sheet.getRange).toHaveBeenCalledWith(3, 1, 3, 9);
    expect(h.schools).not.toHaveBeenCalled();
    expect(h.dishes).not.toHaveBeenCalled();
    expect(JSON.stringify(r)).not.toContain(secret);
  });
  it.each([
    { secret: "wrong" },
    { secret: "" },
    { week_start: "2026-09-22" },
    { week_start: "2026-02-30" },
    { request_id: "" },
    { spreadsheet_id: "other" },
    { range: "A1:Z999" },
    { event: "atlas_unknown" },
  ])(
    "rejects invalid Atlas requests without falling into v1 writes: %o",
    (extra) => {
      const h = harness();
      expect(h.read(body(extra)).success).toBe(false);
      expect(h.openById).not.toHaveBeenCalled();
      expect(h.schools).not.toHaveBeenCalled();
      expect(h.dishes).not.toHaveBeenCalled();
    },
  );
  it("fails closed when both shared secrets are missing", () => {
    const h = harness({ missingSecret: true });
    expect(h.read(body()).success).toBe(false);
    expect(h.openById).not.toHaveBeenCalled();
  });
  it("a separate read secret cannot invoke the old write handler", () => {
    const h = harness();
    h.props.ATLAS_WEEKLY_MENU_SECRET = "different-read-secret";
    expect(h.read(body({ secret: "different-read-secret" })).success).toBe(
      true,
    );
    expect(h.dishes).not.toHaveBeenCalled();
    const r = h.context.doPost({
      parameter: { secret: "different-read-secret" },
      postData: { contents: '{"event":"dishes_changed"}' },
    });
    expect(r.text).toBe("FORBIDDEN");
  });
  it("does not trust a query-string secret for Atlas reads", () => {
    const h = harness();
    const e = event(body({ secret: "" }));
    e.parameter.secret = secret;
    expect(JSON.parse(h.context.doPost(e).text).success).toBe(false);
  });
  it("preserves the existing school callback with original query-secret semantics", () => {
    const h = harness();
    const e = event({
      event: "schools_changed",
      schools: [{ id: 1, name: "A" }],
    });
    e.parameter.secret = secret;
    expect(JSON.parse(h.context.doPost(e).text).ok).toBe(true);
    expect(h.schools).toHaveBeenCalledOnce();
    expect(h.dishes).not.toHaveBeenCalled();
    expect(h.openById).not.toHaveBeenCalled();
  });
  it("preserves the existing dish webhook and exact text response", () => {
    const h = harness();
    const e = event({ event: "dishes_changed" });
    e.parameter.secret = secret;
    expect(h.context.doPost(e).text).toBe("OK_SYNCED");
    expect(h.dishes).toHaveBeenCalledOnce();
    expect(h.openById).not.toHaveBeenCalled();
  });
  it("fails closed rather than truncating a weekly sheet beyond row 500", () => {
    const h = harness({ lastRow: 501 });
    expect(h.read(body()).error_code).toBe("RESPONSE_SIZE_LIMIT");
    expect(h.sheet.getRange).not.toHaveBeenCalled();
  });
  it("classifies missing week and empty sheet without invoking validation hooks", () => {
    expect(harness({ missingSheet: true }).read(body()).error_code).toBe(
      "WEEKLY_SHEET_MISSING",
    );
    expect(harness({ lastRow: 2 }).read(body()).error_code).toBe("EMPTY_SHEET");
  });
});

describe("deployment-scoped reader credential", () => {
  it("accepts a hashed dedicated read secret without exposing or replacing the v1 secret", () => {
    const h = harness();
    const readSecret = "independent-high-entropy-reader-test-secret";
    h.context.atlasWeeklyMenuDeploymentConfig_ = () => ({
      spreadsheetId: "fixture-spreadsheet",
      secretSha256: createHash("sha256").update(readSecret).digest("hex"),
    });
    delete h.props.ATLAS_WEEKLY_MENU_SPREADSHEET_ID;
    expect(h.read(body({ secret: readSecret })).success).toBe(true);
    expect(h.read(body()).success).toBe(false);
    expect(h.props.SYNC_SECRET).toBe(secret);
    expect(h.dishes).not.toHaveBeenCalled();
  });
  it("never falls back to the v1 credential when a reader digest is malformed", () => {
    const h = harness();
    h.context.atlasWeeklyMenuDeploymentConfig_ = () => ({
      spreadsheetId: "fixture-spreadsheet",
      secretSha256: "bad",
    });
    expect(h.read(body()).success).toBe(false);
    expect(h.openById).not.toHaveBeenCalled();
  });
});
