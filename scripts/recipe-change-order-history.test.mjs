// @vitest-environment node
import { describe, expect, it } from "vitest";
import {
  buildRecipeHistorySourceSql,
  normalizeRecipeHistorySnapshot,
  extractRecipeHistorySnapshot,
  runLocalRecipeHistory,
} from "./recipe-change-order-history.mjs";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const tables = [
  "ingredient_change_orders",
  "system_bom_change_orders",
  "school_wide_overrides",
  "school_recipe_overrides",
];
function raw() {
  return {
    source_project_ref: "qnthofvccilhnefdcxnz",
    exported_at: "2026-11-05T00:00:00Z",
    source_access: {
      role_name: "supabase_read_only_user",
      superuser: false,
      bypassRls: true,
      createRole: false,
      createDb: false,
      hasRequiredSelect: true,
      hasNonSelectTablePrivilege: false,
    },
    records: Object.fromEntries(tables.map((t) => [t, []])),
    source_counts: Object.fromEntries(tables.map((t) => [t, 0])),
  };
}
const identity = {
  snapshotId: "history-test",
  extractorVersion: "test-revision",
};
const row = {
  id: "9007199254740993",
  action: "adjust_qty",
  is_active: false,
  effective_date: "2026-01-19",
  created_at: "2026-01-19 09:00:00",
  usable_quantity_override: "1.000001",
  dish_name: "Canh",
  school_name: null,
  ingredient_name: "Muối",
  substitute_name: null,
  purchase_unit: "kg",
  note: "Nguồn inactive; ngày hủy không rõ.",
};

describe("Recipe source history", () => {
  it("preserves inactive evidence, exact identity/quantity and unknown issuance", () => {
    const source = raw();
    source.records.system_bom_change_orders = [row];
    source.source_counts.system_bom_change_orders = 1;
    const snapshot = normalizeRecipeHistorySnapshot(source, identity);
    expect(snapshot.records[0]).toMatchObject({
      legacy_id: row.id,
      source_active: false,
      quantity: "1.000001",
      action: "ADJUST_QUANTITY",
      source_created_at: row.created_at,
      source_record: row,
    });
    expect(snapshot.records[0]).not.toHaveProperty("cancelled_at");
    expect(snapshot.snapshot_checksum).toMatch(/^[a-f0-9]{64}$/);
    expect(normalizeRecipeHistorySnapshot(source, identity)).toEqual(snapshot);
  });
  it("rejects incomplete and conflicting source identities", () => {
    const source = raw();
    delete source.records.school_recipe_overrides;
    expect(() => normalizeRecipeHistorySnapshot(source, identity)).toThrow(
      "SOURCE_COMPLETENESS_INVALID",
    );
    const duplicate = raw();
    duplicate.records.system_bom_change_orders = [row, row];
    duplicate.source_counts.system_bom_change_orders = 2;
    expect(() => normalizeRecipeHistorySnapshot(duplicate, identity)).toThrow(
      "DUPLICATE_SOURCE_IDENTITY",
    );
    const mismatch = raw();
    mismatch.source_counts.system_bom_change_orders = 1;
    expect(() => normalizeRecipeHistorySnapshot(mismatch, identity)).toThrow(
      "SOURCE_COMPLETENESS_INVALID",
    );
  });
  it("rejects unsafe source role, unsafe integer IDs and numeric quantity coercion", () => {
    const source = raw();
    source.source_access.superuser = true;
    expect(() => normalizeRecipeHistorySnapshot(source, identity)).toThrow(
      "SOURCE_NOT_READ_ONLY",
    );
    for (const changed of [
      { ...row, id: 9007199254740992 },
      { ...row, usable_quantity_override: 1.000001 },
      { ...row, action: "toString" },
    ]) {
      const invalid = raw();
      invalid.records.system_bom_change_orders = [changed];
      invalid.source_counts.system_bom_change_orders = 1;
      expect(() => normalizeRecipeHistorySnapshot(invalid, identity)).toThrow(
        "SOURCE_RECORD_INVALID",
      );
    }
  });
  it("uses one fixed source statement without filtering inactive rows", () => {
    const sql = buildRecipeHistorySourceSql();
    for (const table of tables) expect(sql).toContain(`public.${table}`);
    expect(sql).not.toMatch(/where\s+.*is_active/i);
    expect(sql).toContain("has_table_privilege");
    expect(sql).toContain("usable_quantity_override::text");
  });
  it("calls only the read-only endpoint and rejects another project", async () => {
    let request;
    const fetchImpl = async (url, options) => {
      request = { url, options };
      return { status: 201, json: async () => [{ snapshot: raw() }] };
    };
    await extractRecipeHistorySnapshot({
      ...identity,
      accessToken: "not-a-real-key",
      fetchImpl,
    });
    expect(request.url).toBe(
      "https://api.supabase.com/v1/projects/qnthofvccilhnefdcxnz/database/query/read-only",
    );
    expect(request.options.redirect).toBe("error");
    await expect(
      extractRecipeHistorySnapshot({
        ...identity,
        projectRef: "other",
        accessToken: "x",
        fetchImpl,
      }),
    ).rejects.toThrow("UNAPPROVED_SOURCE_PROJECT");
  });
  it("requires a database-enforced read-only transaction when a connected role has write privileges", () => {
    const source = raw();
    Object.assign(source.source_access, {
      role_name: "postgres",
      createRole: true,
      createDb: true,
      hasNonSelectTablePrivilege: true,
      transactionReadOnly: "off",
    });
    expect(() => normalizeRecipeHistorySnapshot(source, identity)).toThrow(
      "SOURCE_NOT_READ_ONLY",
    );
    source.source_access.transactionReadOnly = "on";
    expect(
      normalizeRecipeHistorySnapshot(source, identity).source_access.role_name,
    ).toBe("postgres");
    source.source_access.bypassRls = false;
    expect(() => normalizeRecipeHistorySnapshot(source, identity)).toThrow(
      "SOURCE_NOT_READ_ONLY",
    );
  });
  it("requires a guarded disposable target and reviewed Actor-bound apply", () => {
    const directory = mkdtempSync(join(tmpdir(), "atlas-history-test-"));
    try {
      const file = join(directory, "snapshot.json");
      writeFileSync(
        file,
        JSON.stringify(normalizeRecipeHistorySnapshot(raw(), identity)),
      );
      let called = false;
      expect(() =>
        runLocalRecipeHistory({
          file,
          checkTarget: () => {
            throw new Error("LOOPBACK_REQUIRED");
          },
          executeSql: () => {
            called = true;
          },
        }),
      ).toThrow("LOOPBACK_REQUIRED");
      expect(called).toBe(false);
      expect(() => runLocalRecipeHistory({ file, apply: true })).toThrow(
        "ACTOR_AND_REVIEWED_PLAN_REQUIRED",
      );
      let statement;
      const preview = runLocalRecipeHistory({
        file,
        checkTarget: () => ({ workdir: "disposable" }),
        executeSql: (sql) => {
          statement = sql;
          return { status: "PREVIEW" };
        },
      });
      expect(preview.status).toBe("PREVIEW");
      expect(statement).toMatch(/,null,null\) as result/);
      expect(statement).not.toContain("not-a-real-key");
    } finally {
      rmSync(directory, { recursive: true, force: true });
    }
  });
});
