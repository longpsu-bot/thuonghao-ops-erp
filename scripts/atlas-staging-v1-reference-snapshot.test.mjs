import { readFileSync } from "node:fs";
import { describe, expect, it, vi } from "vitest";
import {
  ATLAS_STAGING_V1_NAMESPACE,
  deterministicV1Uuid,
  formatImportReport,
  transformV1ReferenceSnapshot,
} from "./atlas-staging-v1-reference-transform.mjs";
import {
  buildV1SourceSnapshotSql,
  extractV1ReferenceSnapshot,
} from "./atlas-staging-v1-reference-source.mjs";
import {
  buildTargetApplySql,
  buildTargetSnapshotSql,
  compareManifestToTarget,
  readV1ReferenceTargetState,
  validateV1ReferenceImportRequest,
} from "./atlas-staging-v1-reference-target.mjs";
import {
  runAtlasStagingV1ReferenceImport,
  verifyExactMainCheckout,
} from "./import-atlas-staging-v1-reference-snapshot.mjs";

const sourceRef = "qnthofvccilhnefdcxnz";
const targetRef = "rnzxmxiiqgtdevzregff";

function environment(overrides = {}) {
  return {
    ATLAS_STAGING_PROJECT_REF: targetRef,
    VITE_SUPABASE_URL: `https://${targetRef}.supabase.co`,
    ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "synthetic-management-token",
    ...overrides,
  };
}

function sourceSnapshot(overrides = {}) {
  return {
    sourceProjectRef: sourceRef,
    snapshotAt: "2026-09-02T01:02:03.000Z",
    sourceAccess: {
      roleName: "supabase_read_only_user",
      superuser: false,
      bypassRls: false,
      createRole: false,
      createDb: false,
      hasRequiredSelect: true,
      hasNonSelectTablePrivilege: false,
    },
    schools: [
      {
        id: 21,
        name: "School 21",
        delivery_info: "21 Synthetic Street",
        default_students_num: 420,
        default_teacher_num: 32,
        school_type_id: 1,
        school_type_name: "TIỂU HỌC",
        school_full_name: "Synthetic Primary School 21",
        display_order: 21,
      },
      {
        id: 22,
        name: "School 22",
        delivery_info: "22 Synthetic Street",
        default_students_num: null,
        default_teacher_num: null,
        school_type_id: 2,
        school_type_name: "TRUNG HỌC",
        school_full_name: "Synthetic Secondary School 22",
        display_order: 22,
      },
    ],
    ingredientTypes: [
      { id: 37, name: "Khác" },
      { id: 39, name: "Rau củ quả" },
    ],
    ingredientShoppingTypes: [
      { id: 1, name: "Rau củ" },
      { id: 2, name: "Còn lại" },
    ],
    ingredients: [
      {
        id: 153,
        name: "Synthetic Rice",
        purchase_unit: "Kg",
        ingredient_type_id: 37,
        shopping_type_id: 2,
        is_active: true,
        order_step: "0.500000",
      },
      {
        id: 154,
        name: "Synthetic Jar Item",
        purchase_unit: "Hũ",
        ingredient_type_id: 39,
        shopping_type_id: 1,
        is_active: true,
        order_step: "1.000000",
      },
      {
        id: 155,
        name: "Synthetic Inactive Item",
        purchase_unit: "Hủ",
        ingredient_type_id: 37,
        shopping_type_id: 2,
        is_active: false,
        order_step: "1.000000",
      },
    ],
    suppliers: [
      {
        id: 12,
        name: "Synthetic Supplier 12",
        contact_details: "private-contact-12@example.test",
      },
      {
        id: 13,
        name: "Synthetic Supplier 13",
        contact_details: "private-contact-13@example.test",
      },
    ],
    ingredientSuppliers: [
      {
        ingredient_id: 153,
        supplier_id: 12,
        default_priority: 1,
        lead_time_days: 2,
      },
      {
        ingredient_id: 153,
        supplier_id: 13,
        default_priority: 2,
        lead_time_days: 3,
      },
      {
        ingredient_id: 155,
        supplier_id: 12,
        default_priority: 1,
        lead_time_days: 4,
      },
    ],
    ...overrides,
  };
}

function atlasPrerequisites(manifest) {
  return {
    ingredientTypes: manifest.ingredientTypes.map((row) => ({
      ...row,
      ingredient_type_status: "ACTIVE",
    })),
    ingredientOrderGroups: manifest.ingredientOrderGroups.map((row) => ({
      ...row,
      ingredient_order_group_status: "ACTIVE",
    })),
    units: manifest.units.filter((row) => !row.managed),
  };
}

describe("Atlas Staging OPS v1 reference snapshot", () => {
  it("generates fixed UUIDv5-compatible identities from one namespace", () => {
    expect(ATLAS_STAGING_V1_NAMESPACE).toBe(
      "6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7",
    );
    expect(deterministicV1Uuid("school:21")).toBe(
      "1e883ce8-6d86-58ea-8056-d7bc91445008",
    );
    expect(deterministicV1Uuid("supplier-eligibility:153:12")).toBe(
      "a3de657a-6326-5041-bffb-951e6742bd3b",
    );
    expect(deterministicV1Uuid("unit:Hũ")).toBe(
      "fda4e446-57af-5e99-aabf-011a9da67d3a",
    );
    expect(deterministicV1Uuid("unit:Hủ")).toBe(
      "c18f9882-9410-572a-b556-44b6e53deb59",
    );
  });

  it("transforms one complete School into a deterministic bundle and skips the incomplete bundle", () => {
    const manifest = transformV1ReferenceSnapshot(sourceSnapshot());

    expect(manifest.customers).toEqual([
      expect.objectContaining({
        customer_id: deterministicV1Uuid("customer:school:21"),
        customer_code: "v1-customer-21",
        customer_name: "Synthetic Primary School 21",
      }),
    ]);
    expect(manifest.deliveryLocations).toEqual([
      expect.objectContaining({
        delivery_location_id: deterministicV1Uuid(
          "delivery-location:school:21",
        ),
        address_text: "21 Synthetic Street",
        timezone_name: "Asia/Ho_Chi_Minh",
      }),
    ]);
    expect(manifest.schools).toEqual([
      expect.objectContaining({
        school_id: deterministicV1Uuid("school:21"),
        school_type_id: deterministicV1Uuid("school-type:1"),
        default_student_portions: 420,
        default_teacher_portions: 32,
      }),
    ]);
    expect(manifest.metadata.skipped).toMatchObject({
      schools: 1,
      schoolBundles: 1,
    });
    expect(manifest.metadata.warnings).toContainEqual({
      code: "MISSING_REQUIRED_DEFAULT_PORTIONS",
      count: 1,
    });
    expect(manifest.schoolTypes).toContainEqual(
      expect.objectContaining({
        school_type_id: deterministicV1Uuid("school-type:2"),
        school_type_name: "TRUNG HỌC",
      }),
    );
  });

  it("maps exact Atlas catalogs, keeps count units distinct, imports only active Ingredients, and preserves supplier priority", () => {
    const manifest = transformV1ReferenceSnapshot(sourceSnapshot());

    expect(manifest.ingredientTypes).toContainEqual(
      expect.objectContaining({
        source_id: 37,
        ingredient_type_id: "c3100000-0000-4000-8000-000000000010",
        managed: false,
      }),
    );
    expect(manifest.ingredientOrderGroups).toContainEqual(
      expect.objectContaining({
        source_id: 2,
        ingredient_order_group_id: "c3200000-0000-4000-8000-000000000003",
        managed: false,
      }),
    );
    expect(manifest.units).toContainEqual(
      expect.objectContaining({ unit_code: "kg", managed: false }),
    );
    expect(manifest.units).toContainEqual(
      expect.objectContaining({
        unit_id: deterministicV1Uuid("unit:Hũ"),
        unit_name: "Hũ",
        dimension_code: "COUNT",
        decimal_scale: 0,
        managed: true,
      }),
    );
    expect(manifest.units).not.toContainEqual(
      expect.objectContaining({ unit_id: deterministicV1Uuid("unit:Hủ") }),
    );
    expect(manifest.ingredients.map((item) => item.ingredient_code)).toEqual([
      "v1-ingredient-153",
      "v1-ingredient-154",
    ]);
    expect(manifest.supplierEligibilities).toEqual([
      expect.objectContaining({
        ingredient_id: deterministicV1Uuid("ingredient:153"),
        supplier_id: deterministicV1Uuid("supplier:12"),
        priority: 1,
        effective_from: "2000-01-01",
        effective_to: null,
      }),
      expect.objectContaining({
        ingredient_id: deterministicV1Uuid("ingredient:153"),
        supplier_id: deterministicV1Uuid("supplier:13"),
        priority: 2,
      }),
    ]);
    expect(manifest.metadata.procurementUsefulness).toMatchObject({
      ingredientsWithAtLeast2Suppliers: 1,
      ingredientsWithAtLeast4Suppliers: 0,
      ingredientsWithEqualBestPriority: 0,
    });
  });

  it("is byte-equivalent for the same snapshot and excludes supplier contacts and lead times", () => {
    const first = transformV1ReferenceSnapshot(sourceSnapshot());
    const second = transformV1ReferenceSnapshot(sourceSnapshot());
    const serialized = JSON.stringify(first);

    expect(JSON.stringify(second)).toBe(serialized);
    expect(serialized).not.toContain("private-contact");
    expect(serialized).not.toContain("contact_details");
    expect(serialized).not.toContain("lead_time_days");
  });

  it("canonicalizes Kg and kg to one existing Atlas Unit row", () => {
    const base = sourceSnapshot();
    const manifest = transformV1ReferenceSnapshot({
      ...base,
      ingredients: [
        base.ingredients[0],
        { ...base.ingredients[0], id: 156, purchase_unit: "kg" },
      ],
      ingredientSuppliers: [],
    });
    expect(
      manifest.units.filter((unit) => unit.unit_code === "kg"),
    ).toHaveLength(1);
    expect(
      new Set(manifest.ingredients.map((row) => row.purchase_unit_id)),
    ).toEqual(new Set(["a1020000-0000-4000-8000-000000000205"]));
  });

  it("reports equal best priorities as an Atlas apply blocker", () => {
    const base = sourceSnapshot();
    const manifest = transformV1ReferenceSnapshot({
      ...base,
      ingredientSuppliers: [
        base.ingredientSuppliers[0],
        { ...base.ingredientSuppliers[1], default_priority: 1 },
      ],
    });
    expect(manifest.metadata.procurementUsefulness).toMatchObject({
      ingredientsWithEqualBestPriority: 1,
    });
    expect(manifest.metadata.blockers).toContainEqual({
      code: "DUPLICATE_INGREDIENT_PRIORITY",
      count: 1,
    });
    expect(() => buildTargetApplySql(manifest)).toThrow(/blockers/i);
  });

  it("reports duplicate source pairs and unsupported unit semantics instead of guessing", () => {
    const duplicate = sourceSnapshot();
    duplicate.ingredientSuppliers.push({
      ...duplicate.ingredientSuppliers[0],
    });
    expect(() => transformV1ReferenceSnapshot(duplicate)).toThrow(
      /DUPLICATE_SUPPLIER_ELIGIBILITY/,
    );

    const unsupported = sourceSnapshot({
      ingredients: [
        {
          ...sourceSnapshot().ingredients[0],
          purchase_unit: "Lít",
        },
      ],
      ingredientSuppliers: [],
    });
    expect(() => transformV1ReferenceSnapshot(unsupported)).toThrow(
      /UNSUPPORTED_UNIT_SEMANTICS.*Lít/,
    );
  });

  it("builds one SELECT-only source snapshot statement over the six approved tables", () => {
    const sql = buildV1SourceSnapshotSql();
    expect(sql.trim()).toMatch(/^select\b/i);
    expect(sql.trim()).toMatch(/;$/);
    expect(sql.match(/\bselect\b/gi)?.length).toBeGreaterThan(1);
    expect(sql).toContain("from public.ingredient_suppliers");
    expect(sql).not.toMatch(
      /\b(begin|commit|insert|update|delete|truncate|alter|drop|create)\b/i,
    );
    for (const table of [
      "schools",
      "ingredients",
      "suppliers",
      "ingredient_suppliers",
      "ingredient_type",
      "ingredient_shopping_type",
    ]) {
      expect(sql).toContain(`public.${table}`);
    }
  });

  it("extracts only through the fixed live OPS read-only Management API endpoint", async () => {
    const fetchImpl = vi.fn(async () => ({
      status: 201,
      text: async () =>
        JSON.stringify([
          {
            snapshot: sourceSnapshot(),
          },
        ]),
    }));
    const result = await extractV1ReferenceSnapshot({
      accessToken: "synthetic-management-token",
      fetchImpl,
    });
    expect(result.sourceProjectRef).toBe(sourceRef);
    expect(fetchImpl).toHaveBeenCalledOnce();
    expect(fetchImpl).toHaveBeenCalledWith(
      `https://api.supabase.com/v1/projects/${sourceRef}/database/query/read-only`,
      expect.objectContaining({
        method: "POST",
        headers: expect.objectContaining({
          Authorization: "Bearer synthetic-management-token",
        }),
      }),
    );
    const requestBody = JSON.parse(fetchImpl.mock.calls[0][1].body);
    expect(requestBody).toEqual({ query: buildV1SourceSnapshotSql() });
  });

  it("rejects any Management API source project other than live OPS", async () => {
    await expect(
      extractV1ReferenceSnapshot({
        projectRef: targetRef,
        accessToken: "synthetic-management-token",
        fetchImpl: vi.fn(),
      }),
    ).rejects.toThrow(/approved OPS v1 source project/i);
  });

  it("rejects a source response that was not executed as the Supabase read-only role", async () => {
    const fetchImpl = vi.fn(async () => ({
      status: 201,
      text: async () =>
        JSON.stringify([
          {
            snapshot: sourceSnapshot({
              sourceAccess: {
                ...sourceSnapshot().sourceAccess,
                roleName: "postgres",
              },
            }),
          },
        ]),
    }));
    await expect(
      extractV1ReferenceSnapshot({
        accessToken: "synthetic-management-token",
        fetchImpl,
      }),
    ).rejects.toThrow(/not proven read-only/i);
  });

  it("requires no direct source database URL and fails closed for forbidden/wrong targets and implicit apply", () => {
    expect(
      validateV1ReferenceImportRequest({ environment: environment() }),
    ).toMatchObject({ sourceProjectRef: sourceRef });
    expect(() =>
      validateV1ReferenceImportRequest({
        environment: environment({
          ATLAS_STAGING_PROJECT_REF: sourceRef,
          VITE_SUPABASE_URL: `https://${sourceRef}.supabase.co`,
        }),
      }),
    ).toThrow(/forbidden/i);
    expect(() =>
      validateV1ReferenceImportRequest({
        environment: environment({
          ATLAS_STAGING_PROJECT_REF: "aaaaaaaaaaaaaaaaaaaa",
          VITE_SUPABASE_URL: "https://aaaaaaaaaaaaaaaaaaaa.supabase.co",
        }),
      }),
    ).toThrow(/approved Atlas Staging/i);
    expect(() =>
      validateV1ReferenceImportRequest({
        environment: environment(),
        applyRequested: true,
        applyFlagPresent: false,
        targetConfirmation: targetRef,
      }),
    ).toThrow(/explicit --apply/i);
    expect(() =>
      validateV1ReferenceImportRequest({
        environment: environment(),
        applyRequested: true,
        applyFlagPresent: true,
        targetConfirmation: "wrong-target",
      }),
    ).toThrow(/exact target confirmation/i);
  });

  it("classifies inserts, material updates, noops, conflicts, and source disappearance without deleting unrelated rows", () => {
    const manifest = transformV1ReferenceSnapshot(sourceSnapshot());
    const existingIngredient = manifest.ingredients[0];
    const target = {
      ...atlasPrerequisites(manifest),
      customers: [],
      deliveryLocations: [],
      schoolTypes: [],
      schools: [],
      ingredients: [
        { ...existingIngredient },
        {
          ...manifest.ingredients[1],
          ingredient_name: "Stale source-owned name",
        },
        {
          ingredient_id: deterministicV1Uuid("ingredient:999"),
          ingredient_code: "v1-ingredient-999",
          ingredient_name: "Missing from source",
        },
        {
          ingredient_id: "99999999-9999-4999-8999-999999999999",
          ingredient_code: "atlas-only-ingredient",
          ingredient_name: "Unrelated Atlas row",
        },
      ],
      suppliers: [],
      supplierEligibilities: [],
    };

    const comparison = compareManifestToTarget(manifest, target);
    expect(comparison.byObject.ingredients).toMatchObject({
      inserts: 0,
      updates: 1,
      noops: 1,
      sourceMissing: 1,
      deletes: 0,
    });
    expect(comparison.unrelatedRowsTouched).toBe(0);

    const conflicting = compareManifestToTarget(manifest, {
      ...target,
      suppliers: [
        {
          supplier_id: "99999999-9999-4999-8999-999999999998",
          supplier_code: "v1-supplier-12",
          supplier_name: "Natural key collision",
        },
      ],
    });
    expect(conflicting.totals.conflicts).toBe(1);
  });

  it("reports missing Atlas-owned catalog and kg prerequisites as dry-run conflicts", () => {
    const manifest = transformV1ReferenceSnapshot(sourceSnapshot());
    const comparison = compareManifestToTarget(manifest, {
      ingredientTypes: [],
      ingredientOrderGroups: [],
      customers: [],
      deliveryLocations: [],
      schoolTypes: [],
      schools: [],
      units: [],
      ingredients: [],
      suppliers: [],
      supplierEligibilities: [],
    });
    expect(comparison.byObject.ingredientTypes).toMatchObject({
      inserts: 0,
      updates: 0,
      conflicts: manifest.ingredientTypes.length,
    });
    expect(comparison.byObject.ingredientOrderGroups).toMatchObject({
      inserts: 0,
      updates: 0,
      conflicts: manifest.ingredientOrderGroups.length,
    });
    expect(comparison.byObject.units.conflicts).toBe(1);
  });

  it("builds a single idempotent apply transaction with no delete, reset, or operational write", () => {
    const sql = buildTargetApplySql(
      transformV1ReferenceSnapshot(sourceSnapshot()),
    );
    expect(sql).toMatch(/^begin;/i);
    expect(sql.trim().toLowerCase().endsWith("commit;")).toBe(true);
    expect(sql).toMatch(/on conflict \(ingredient_id\) do update/i);
    expect(sql).toMatch(/is distinct from/i);
    expect(sql).not.toMatch(/\b(delete|truncate|drop|alter)\b/i);
    expect(sql).not.toMatch(
      /atlas_(planning|procurement|warehouse|dispatch|evidence)\./i,
    );
  });

  it("formats aggregate-only reports without credentials, contacts, or raw source rows", () => {
    const manifest = transformV1ReferenceSnapshot(sourceSnapshot());
    const report = formatImportReport({
      manifest,
      comparison: compareManifestToTarget(manifest, {
        ...atlasPrerequisites(manifest),
        customers: [],
        deliveryLocations: [],
        schoolTypes: [],
        schools: [],
        ingredients: [],
        suppliers: [],
        supplierEligibilities: [],
      }),
      mode: "dry-run",
    });
    expect(report).toContain('"mode": "dry-run"');
    expect(report).toContain('"sourceProjectRef": "qnthofvccilhnefdcxnz"');
    expect(report).not.toContain("Synthetic Supplier 12");
    expect(report).not.toContain("private-contact");
    expect(report).not.toContain("synthetic-password");
  });

  it("reads only the bounded Atlas Admin target fields and omits supplier contacts", async () => {
    const sql = buildTargetSnapshotSql();
    expect(sql).toContain("from atlas_admin.supplier_eligibilities");
    expect(sql).not.toMatch(
      /\b(insert|update|delete|truncate|alter|drop|create)\b/i,
    );
    expect(sql).not.toContain("contact_name");
    expect(sql).not.toContain("contact_phone");
    expect(sql).not.toContain("contact_email");

    const targetState = {
      ingredientTypes: [],
      ingredientOrderGroups: [],
      customers: [],
      deliveryLocations: [],
      schoolTypes: [],
      schools: [],
      units: [],
      ingredients: [],
      suppliers: [],
      supplierEligibilities: [],
    };
    const fetchImpl = vi.fn(async () => ({
      status: 201,
      text: async () => JSON.stringify([{ target_state: targetState }]),
    }));
    await expect(
      readV1ReferenceTargetState({
        target: {
          projectRef: targetRef,
          supabaseUrl: `https://${targetRef}.supabase.co`,
          accessToken: "synthetic-management-token",
        },
        fetchImpl,
      }),
    ).resolves.toEqual(targetState);
  });

  it("verifies an exact clean checkout at the current origin/main commit", () => {
    const commitSha = "b".repeat(40);
    const runCommand = vi.fn((_command, args) => {
      if (args[0] === "rev-parse" && args[1] === "HEAD") {
        return { status: 0, stdout: `${commitSha}\n`, stderr: "" };
      }
      if (args[0] === "rev-parse" && args[1] === "origin/main") {
        return { status: 0, stdout: `${commitSha}\n`, stderr: "" };
      }
      return { status: 0, stdout: "", stderr: "" };
    });
    expect(verifyExactMainCheckout({ commitSha, runCommand })).toBe(commitSha);
    expect(runCommand.mock.calls[0][1]).toEqual([
      "fetch",
      "--no-tags",
      "origin",
      "main:refs/remotes/origin/main",
    ]);

    const moved = vi.fn((_command, args) => {
      if (args[0] === "rev-parse" && args[1] === "HEAD") {
        return { status: 0, stdout: `${commitSha}\n`, stderr: "" };
      }
      if (args[0] === "rev-parse" && args[1] === "origin/main") {
        return { status: 0, stdout: `${"c".repeat(40)}\n`, stderr: "" };
      }
      return { status: 0, stdout: "", stderr: "" };
    });
    expect(() =>
      verifyExactMainCheckout({ commitSha, runCommand: moved }),
    ).toThrow(/current origin\/main/i);
  });

  it("keeps dry-run as the default and performs no target write", async () => {
    const executeTargetSql = vi.fn();
    const extractSnapshot = vi.fn(() => sourceSnapshot());
    const manifest = transformV1ReferenceSnapshot(sourceSnapshot());
    const emptyTarget = {
      ...atlasPrerequisites(manifest),
      customers: [],
      deliveryLocations: [],
      schoolTypes: [],
      schools: [],
      ingredients: [],
      suppliers: [],
      supplierEligibilities: [],
    };
    const result = await runAtlasStagingV1ReferenceImport({
      commitSha: "b".repeat(40),
      environment: environment(),
      verifyCheckout: () => "b".repeat(40),
      extractSnapshot,
      readTarget: async () => emptyTarget,
      executeTargetSql,
    });
    expect(result.status).toBe("dry-run");
    expect(executeTargetSql).not.toHaveBeenCalled();
    expect(extractSnapshot).toHaveBeenCalledWith(
      expect.objectContaining({
        projectRef: sourceRef,
        accessToken: "synthetic-management-token",
      }),
    );
    expect(result.report).toContain('"mode": "dry-run"');
  });

  it("blocks apply on target conflicts and verifies an explicit successful apply by rereading target", async () => {
    const source = sourceSnapshot();
    const manifest = transformV1ReferenceSnapshot(source);
    const emptyTarget = {
      ...atlasPrerequisites(manifest),
      customers: [],
      deliveryLocations: [],
      schoolTypes: [],
      schools: [],
      ingredients: [],
      suppliers: [],
      supplierEligibilities: [],
    };
    const conflictTarget = {
      ...emptyTarget,
      suppliers: [
        {
          supplier_id: "99999999-9999-4999-8999-999999999998",
          supplier_code: "v1-supplier-12",
          supplier_name: "Conflicting target",
          supplier_status: "ACTIVE",
        },
      ],
    };
    await expect(
      runAtlasStagingV1ReferenceImport({
        commitSha: "b".repeat(40),
        apply: true,
        applyFlagPresent: true,
        targetConfirmation: targetRef,
        environment: environment(),
        verifyCheckout: () => "b".repeat(40),
        extractSnapshot: () => source,
        readTarget: async () => conflictTarget,
        executeTargetSql: vi.fn(),
      }),
    ).rejects.toThrow(/target conflicts/i);

    const appliedTarget = {
      ingredientTypes: manifest.ingredientTypes,
      ingredientOrderGroups: manifest.ingredientOrderGroups,
      customers: manifest.customers,
      deliveryLocations: manifest.deliveryLocations,
      schoolTypes: manifest.schoolTypes,
      schools: manifest.schools,
      units: manifest.units,
      ingredients: manifest.ingredients,
      suppliers: manifest.suppliers,
      supplierEligibilities: manifest.supplierEligibilities,
    };
    const readTarget = vi
      .fn()
      .mockResolvedValueOnce(emptyTarget)
      .mockResolvedValueOnce(appliedTarget);
    const executeTargetSql = vi.fn(async () => "[]");
    const result = await runAtlasStagingV1ReferenceImport({
      commitSha: "b".repeat(40),
      apply: true,
      applyFlagPresent: true,
      targetConfirmation: targetRef,
      environment: environment(),
      verifyCheckout: () => "b".repeat(40),
      extractSnapshot: () => source,
      readTarget,
      executeTargetSql,
    });
    expect(result.status).toBe("applied");
    expect(executeTargetSql).toHaveBeenCalledOnce();
    expect(readTarget).toHaveBeenCalledTimes(2);
    expect(result.comparison.totals).toMatchObject({
      inserts: 0,
      updates: 0,
      conflicts: 0,
    });
  });

  it("registers only a protected manual dry-run/apply workflow with no snapshot artifact", () => {
    const packageJson = JSON.parse(readFileSync("package.json", "utf8"));
    expect(packageJson.scripts["atlas:staging:v1-reference:import"]).toBe(
      "node scripts/import-atlas-staging-v1-reference-snapshot.mjs",
    );

    const workflow = readFileSync(
      ".github/workflows/atlas-staging-v1-reference-import.yml",
      "utf8",
    );
    expect(workflow).toMatch(/on:\s*\n\s*workflow_dispatch:/);
    expect(workflow).toMatch(/commit_sha:[\s\S]*required: true/);
    expect(workflow).toMatch(/mode:[\s\S]*default: validate/);
    expect(workflow).toMatch(/environment: atlas-staging/);
    expect(workflow).not.toContain("OPS_V1_READONLY_DATABASE_URL");
    expect(
      workflow.match(/pnpm atlas:staging:v1-reference:import --/g),
    ).toHaveLength(2);
    expect(workflow).toMatch(
      /- name: Validate OPS v1 reference snapshot\s+if: \$\{\{ inputs\.mode == 'validate' \}\}\s+run: pnpm atlas:staging:v1-reference:import -- --commit-sha "\$\{\{ inputs\.commit_sha \}\}"/,
    );
    expect(workflow).toMatch(
      /- name: Validate and apply OPS v1 reference snapshot\s+if: \$\{\{ inputs\.mode == 'apply' \}\}\s+run: >-\s+pnpm atlas:staging:v1-reference:import --\s+--commit-sha "\$\{\{ inputs\.commit_sha \}\}"\s+--apply\s+--target-project-ref "\$\{ATLAS_STAGING_PROJECT_REF\}"/,
    );
    expect(workflow).not.toMatch(/upload-artifact|artifacts?:/i);
    expect(workflow).not.toMatch(/\b(push|pull_request|schedule):/);
  });
});
