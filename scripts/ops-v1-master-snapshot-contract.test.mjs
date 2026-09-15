// @vitest-environment node
import { describe, expect, it, vi } from "vitest";
import {
  canonicalizeUnitSourceLabel,
  recipeLegacyId,
  recipeLineLegacyId,
  buildOpsV1MasterSnapshotSql,
  normalizeOpsV1MasterSnapshot,
  checksumOpsV1MasterSnapshot,
  extractOpsV1MasterSnapshot,
} from "./ops-v1-master-snapshot-contract.mjs";

const project = "qnthofvccilhnefdcxnz";
function source() {
  return {
    source_project_ref: project,
    exported_at: "2026-09-15T08:00:00.000Z",
    source_access: {
      role_name: "supabase_read_only_user",
      bypass_rls: true,
      superuser: false,
      create_role: false,
      create_db: false,
      has_required_select: true,
      has_non_select_privilege: false,
    },
    schools: [
      {
        id: "21",
        name: "Trường mẫu",
        school_full_name: "Trường mẫu đầy đủ",
        delivery_info: "21 Đường mẫu",
        default_students_num: 420,
        default_teacher_num: 32,
        school_type_id: "1",
        school_type_name: "TIỂU HỌC",
        is_active: true,
        display_order: 1,
        contract_type: 2,
        region_code: 1,
      },
    ],
    ingredient_type: [{ id: "37", name: "Khác" }],
    ingredient_shopping_type: [{ id: "2", name: "Còn lại" }],
    ingredients: ["Kg", "kg", "Hũ", "Hủ"].map((purchase_unit, index) => ({
      id: String(index + 1),
      name: `Nguyên liệu ${index + 1}`,
      purchase_unit,
      ingredient_type_id: "37",
      shopping_type_id: "2",
      is_active: true,
      archived_at: null,
      order_step: "1.000000",
    })),
    suppliers: [
      { id: "12", name: "NCC mẫu", contact_details: "Raw contact evidence" },
    ],
    ingredient_suppliers: [
      {
        ingredient_id: "1",
        supplier_id: "12",
        default_priority: 1,
        lead_time_days: 2,
      },
    ],
    dish_types: [{ id: "1", name: "Canh" }],
    dishes: [
      {
        id: "100",
        name: "Canh mẫu",
        dish_type_id: "1",
        is_active: true,
        archived_at: null,
      },
    ],
    recipes: [1, 2].map((type) => ({
      id: String(199 + type),
      dish_id: "100",
      school_type_id: String(type),
      recipe_name: `Công thức ${type}`,
      school_id: null,
      is_general: true,
      is_active: true,
      is_locked: true,
      archived_at: null,
    })),
    bill_of_materials: [1, 2].map((type) => ({
      id: String(299 + type),
      recipe_id: String(199 + type),
      ingredient_id: "1",
      usable_quantity: "1.500000",
      purchase_unit: "Kg",
      note: null,
    })),
  };
}
const meta = {
  snapshotId: "synthetic-rehearsal-a",
  extractorVersion: "fixture-v1",
};
const normalized = (s = source()) => normalizeOpsV1MasterSnapshot(s, meta);

describe("approved master snapshot contract", () => {
  it.each([
    ["Kg", "kg"],
    ["kg", "kg"],
    [" Hủ ", "Hũ"],
    ["Hũ", "Hũ"],
  ])("canonicalizes the approved alias %s", (raw, canonical) => {
    expect(canonicalizeUnitSourceLabel(raw)).toBe(canonical);
  });
  it("rejects unapproved tokens instead of fuzzy matching", () => {
    for (const raw of ["123", "KG", "hu", "", null, "kilogram"])
      expect(() => canonicalizeUnitSourceLabel(raw)).toThrow(
        /UNSUPPORTED_UNIT/,
      );
  });
  it("uses Recipe business identity rather than churn-prone source row IDs", () => {
    expect(recipeLegacyId({ dishId: "100", schoolTypeId: 1 })).toBe(
      "dish:100:school-type:1",
    );
    expect(
      recipeLineLegacyId({ dishId: "100", schoolTypeId: 1, ingredientId: "1" }),
    ).toBe("recipe:dish:100:school-type:1:ingredient:1");
  });
  it("covers exactly the ten approved source tables with one SELECT", () => {
    const sql = buildOpsV1MasterSnapshotSql();
    const from = [...sql.matchAll(/from public\.(\w+)/gi)].map((m) => m[1]);
    expect([...new Set(from)].sort()).toEqual(
      Object.keys(source())
        .filter((k) => Array.isArray(source()[k]))
        .sort(),
    );
    expect(sql.trim()).toMatch(/^select\b/i);
    expect(sql).not.toMatch(/;\s*\S/);
    expect(sql).toContain("has_non_select_privilege");
    for (const col of [
      "contract_type",
      "region_code",
      "is_active",
      "archived_at",
      "contact_details",
      "lead_time_days",
      "default_priority",
      "is_locked",
      "purchase_unit",
      "note",
    ])
      expect(sql).toContain(col);
    expect(sql).toContain("usable_quantity::text");
    expect(sql).not.toMatch(
      /public\.(daily_orders|purchase_orders|dispatch_headers)/,
    );
  });
  it("derives both Recipe School Types and a canonical Unit union", () => {
    const result = normalized();
    expect(result.records.school_types.map((r) => r.legacy_id)).toEqual([
      "1",
      "2",
    ]);
    expect(result.records.units.map((r) => r.legacy_id).sort()).toEqual([
      "Hũ",
      "kg",
    ]);
    expect(result.records.schools[0].default_student_portions).toBe(420);
    expect(result.records.schools[0].dispatch_document_issuer_name).toBe(
      "CÔNG TY TNHH MTV TM - DV THƯỢNG HẢO",
    );
    expect(result.records.recipe_lines[0].quantity_per_basis).toBe("1.5");
    expect(
      result.source_diagnostics.filter((d) => d.severity === "BLOCKER"),
    ).toEqual([]);
  });
  it("hashes equivalent reordered source rows identically without mutating input", () => {
    const a = source();
    const before = structuredClone(a);
    const b = structuredClone(a);
    for (const value of Object.values(b))
      if (Array.isArray(value)) value.reverse();
    expect(normalized(a).snapshot_checksum).toBe(
      normalized(b).snapshot_checksum,
    );
    expect(a).toEqual(before);
    expect(checksumOpsV1MasterSnapshot(normalized(a))).toBe(
      normalized(a).snapshot_checksum,
    );
  });
  it("normalizes NFC and outer whitespace deterministically", () => {
    const a = source();
    const b = source();
    b.schools[0].name = `  ${a.schools[0].name.normalize("NFD")} `;
    expect(normalized(a).records.schools).toEqual(
      normalized(b).records.schools,
    );
  });
  it("retains evidence of source ID churn but no changed Recipe business fingerprint", () => {
    const a = source();
    const b = source();
    b.recipes.forEach((r) => {
      r.id = String(Number(r.id) + 1000);
    });
    b.bill_of_materials.forEach((r) => {
      r.id = String(Number(r.id) + 1000);
      r.recipe_id = String(Number(r.recipe_id) + 1000);
    });
    expect(normalized(a).records.recipes.map((r) => r.legacy_id)).toEqual(
      normalized(b).records.recipes.map((r) => r.legacy_id),
    );
    expect(normalized(a).source_fingerprints.recipes).toEqual(
      normalized(b).source_fingerprints.recipes,
    );
    expect(normalized(a).source_fingerprints.recipe_lines).toEqual(
      normalized(b).source_fingerprints.recipe_lines,
    );
    expect(normalized(a).snapshot_checksum).not.toBe(
      normalized(b).snapshot_checksum,
    );
  });
  it("retains inactive roots and diagnoses empty recipes and invalid Units without filtering", () => {
    const s = source();
    s.ingredients[0].is_active = false;
    s.ingredients[0].purchase_unit = "123";
    s.bill_of_materials = s.bill_of_materials.slice(0, 1);
    const n = normalized(s);
    expect(n.records.ingredients).toHaveLength(4);
    expect(n.records.ingredients[0].ingredient_status).toBe("INACTIVE");
    expect(n.records.recipes).toHaveLength(2);
    expect(n.source_diagnostics.map((d) => d.code)).toEqual(
      expect.arrayContaining([
        "UNSUPPORTED_UNIT",
        "RECIPE_EMPTY",
        "INACTIVE_INGREDIENT_REFERENCE",
      ]),
    );
  });
  it("does not coerce a missing School default into zero", () => {
    const s = source();
    s.schools[0].default_students_num = null;
    expect(normalized(s).source_diagnostics.map((d) => d.code)).toContain(
      "INVALID_SCHOOL_DEFAULT",
    );
    expect(normalized(s).records.schools).toHaveLength(1);
  });
  it("reports duplicate business identities and reference mismatches", () => {
    const s = source();
    s.recipes.push({ ...s.recipes[0], id: "999" });
    s.bill_of_materials[0].ingredient_id = "999";
    expect(normalized(s).source_diagnostics.map((d) => d.code)).toEqual(
      expect.arrayContaining(["DUPLICATE_IDENTITY", "MISSING_INGREDIENT"]),
    );
  });
  it("requires every source relation to be present, even when empty", () => {
    const s = source();
    delete s.suppliers;
    expect(() => normalized(s)).toThrow(/INCOMPLETE_SOURCE/);
  });
  it("rejects unsafe numeric identifiers rather than rounding them", () => {
    const s = source();
    s.schools[0].id = 9007199254740992;
    expect(() => normalized(s)).toThrow(/INVALID_SOURCE_ID/);
  });
  it("enforces a read-only source response and rejects mutable endpoint redirects", async () => {
    const fetchImpl = vi.fn(
      async () =>
        new Response(JSON.stringify([{ snapshot: source() }]), { status: 201 }),
    );
    const n = await extractOpsV1MasterSnapshot({
      accessToken: "synthetic-secret",
      ...meta,
      fetchImpl,
    });
    expect(n.records.dishes).toHaveLength(1);
    const [url, init] = fetchImpl.mock.calls[0];
    expect(url).toBe(
      `https://api.supabase.com/v1/projects/${project}/database/query/read-only`,
    );
    expect(init.redirect).toBe("error");
    const unsafe = source();
    unsafe.source_access.has_non_select_privilege = true;
    await expect(
      extractOpsV1MasterSnapshot({
        accessToken: "synthetic-secret",
        ...meta,
        fetchImpl: async () =>
          new Response(JSON.stringify([{ snapshot: unsafe }]), { status: 201 }),
      }),
    ).rejects.toThrow(/READ_ONLY/);
  });
  it("rejects the wrong source before making any request and redacts upstream errors", async () => {
    const f = vi.fn();
    await expect(
      extractOpsV1MasterSnapshot({
        projectRef: "rnzxmxiiqgtdevzregff",
        accessToken: "secret",
        ...meta,
        fetchImpl: f,
      }),
    ).rejects.toThrow(/SOURCE_PROJECT/);
    expect(f).not.toHaveBeenCalled();
    await expect(
      extractOpsV1MasterSnapshot({
        accessToken: "synthetic-secret",
        ...meta,
        fetchImpl: async () => {
          throw new Error("synthetic-secret raw upstream");
        },
      }),
    ).rejects.toThrow("SOURCE_FETCH_FAILED");
  });
});

describe("immutable source export CLI", () => {
  it("writes exclusively and refuses an existing output without fetching", async () => {
    const { mkdtemp, readFile, rm } = await import("node:fs/promises");
    const { tmpdir } = await import("node:os");
    const { join } = await import("node:path");
    const { exportOpsV1MasterSnapshotFile } =
      await import("./extract-ops-v1-master-snapshot.mjs");
    const dir = await mkdtemp(join(tmpdir(), "atlas-snapshot-test-"));
    try {
      const path = join(dir, "snapshot.json");
      const get = vi.fn(async () => normalized());
      const result = await exportOpsV1MasterSnapshotFile({
        output: path,
        snapshotId: meta.snapshotId,
        extractorVersion: meta.extractorVersion,
        extract: get,
      });
      const parsed = JSON.parse(await readFile(path, "utf8"));
      expect(parsed.snapshot_checksum).toBe(result.snapshot_checksum);
      await expect(
        exportOpsV1MasterSnapshotFile({
          output: path,
          snapshotId: meta.snapshotId,
          extractorVersion: meta.extractorVersion,
          extract: get,
        }),
      ).rejects.toThrow(/OUTPUT_EXISTS/);
      expect(get).toHaveBeenCalledTimes(1);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });
  it("does not leave a partial snapshot when extraction fails", async () => {
    const { mkdtemp, readdir, rm } = await import("node:fs/promises");
    const { tmpdir } = await import("node:os");
    const { join } = await import("node:path");
    const { exportOpsV1MasterSnapshotFile } =
      await import("./extract-ops-v1-master-snapshot.mjs");
    const dir = await mkdtemp(join(tmpdir(), "atlas-snapshot-test-"));
    try {
      await expect(
        exportOpsV1MasterSnapshotFile({
          output: join(dir, "failed.json"),
          snapshotId: "test",
          extractorVersion: "test",
          extract: async () => {
            throw new Error("SOURCE_FETCH_FAILED");
          },
        }),
      ).rejects.toThrow("SOURCE_FETCH_FAILED");
      expect(await readdir(dir)).toEqual([]);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });
});

describe("full-source integrity", () => {
  it("detects duplicated physical source IDs even across distinct business keys", () => {
    const s = source();
    s.recipes[1].id = s.recipes[0].id;
    expect(normalized(s).source_diagnostics.map((d) => d.code)).toContain(
      "DUPLICATE_SOURCE_ID",
    );
  });
  it("requires unfiltered read-only access before claiming a complete snapshot", () => {
    const s = source();
    s.source_access.bypass_rls = false;
    expect(() => normalized(s)).toThrow(/READ_ONLY/);
    expect(buildOpsV1MasterSnapshotSql()).toContain("role.rolbypassrls");
  });
  it("preserves explicit raw-to-canonical Unit evidence without duplicate Units", () => {
    const n = normalized();
    expect(n.unit_alias_evidence).toContainEqual({
      source_label: "Hủ",
      canonical_label: "Hũ",
    });
    expect(n.unit_alias_evidence).toContainEqual({
      source_label: "Kg",
      canonical_label: "kg",
    });
    expect(n.records.units).toHaveLength(2);
  });
});
