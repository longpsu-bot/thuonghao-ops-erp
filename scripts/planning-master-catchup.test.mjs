import { describe, expect, it } from "vitest";
import { checksumOpsV1MasterSnapshot } from "./ops-v1-master-snapshot-contract.mjs";
import {
  derivePlanningCatchup,
  buildPlanningCatchupSql,
} from "./planning-master-catchup.mjs";

function fixture() {
  const records = Object.fromEntries(
    [
      "customers",
      "delivery_locations",
      "dish_types",
      "dishes",
      "ingredient_order_groups",
      "ingredient_types",
      "ingredients",
      "recipe_lines",
      "recipes",
      "school_types",
      "schools",
      "supplier_eligibilities",
      "suppliers",
      "units",
    ].map((k) => [k, []]),
  );
  records.schools = [
    { legacy_id: "33", school_name: "THUẬN AN - PHÂN HIỆU", display_order: 16 },
    { legacy_id: "11", school_name: "ĐẤT CUỐC", display_order: 0 },
  ];
  records.dishes = [
    {
      legacy_id: "9",
      dish_name: "Món mới",
      dish_status: "ACTIVE",
      dish_type_legacy_id: "1",
    },
    {
      legacy_id: "8",
      dish_name: "Món cũ",
      dish_status: "ACTIVE",
      dish_type_legacy_id: "1",
    },
  ];
  records.recipes = [
    {
      legacy_id: "dish:9:school-type:1",
      dish_legacy_id: "9",
      school_type_legacy_id: "1",
    },
  ];
  records.recipe_lines = [
    {
      legacy_id: "recipe:dish:9:school-type:1:ingredient:5",
      recipe_legacy_id: "dish:9:school-type:1",
      ingredient_legacy_id: "5",
      unit_legacy_id: "kg",
    },
  ];
  records.ingredients = [
    {
      legacy_id: "5",
      ingredient_name: "Mới",
      ingredient_type_legacy_id: "1",
      ingredient_order_group_legacy_id: "1",
      purchase_unit_legacy_id: "kg",
    },
  ];
  records.units = [{ legacy_id: "kg" }];
  records.dish_types = [{ legacy_id: "1" }];
  records.school_types = [{ legacy_id: "1" }];
  records.ingredient_types = [{ legacy_id: "1" }];
  records.ingredient_order_groups = [{ legacy_id: "1" }];
  records.suppliers = [{ legacy_id: "2" }];
  records.supplier_eligibilities = [
    {
      legacy_id: "ingredient:5:supplier:2",
      ingredient_legacy_id: "5",
      supplier_legacy_id: "2",
    },
  ];
  const s = {
    contract_version: "OPS-V1-MASTER-SNAPSHOT.v1",
    source_system: "OPS_V1",
    source_project_ref: "qnthofvccilhnefdcxnz",
    snapshot_id: "fixture",
    records,
    source_diagnostics: [
      {
        severity: "INFO",
        code: "INACTIVE_SCHOOL_DISPLAY_ORDER_DEFAULTED",
        entity: "schools",
        legacy_id: "11",
      },
    ],
    source_access: {
      role_name: "supabase_read_only_user",
      has_required_select: true,
      has_non_select_privilege: false,
      bypass_rls: true,
      superuser: false,
      create_role: false,
      create_db: false,
    },
  };
  return { ...s, snapshot_checksum: checksumOpsV1MasterSnapshot(s) };
}
const mappings = [
  {
    object_type: "DISH",
    legacy_id: "8",
    target_id: "00000000-0000-4000-8000-000000000008",
  },
];
describe("bounded Planning master closure", () => {
  it("derives only missing active dishes and exact dependencies", () => {
    const p = derivePlanningCatchup(fixture(), mappings);
    expect(p.records.dishes.map((x) => x.legacy_id)).toEqual(["9"]);
    expect(p.records.recipes).toHaveLength(1);
    expect(p.records.ingredients).toHaveLength(1);
    expect(p.records.suppliers).toHaveLength(1);
    expect(p.records.supplier_eligibilities).toHaveLength(1);
    expect(p.records.customers).toEqual([]);
  });
  it("maps NULL-source School orders to deterministic tail", () => {
    expect(derivePlanningCatchup(fixture(), mappings).schoolOrders).toEqual([
      { legacy_id: "33", display_order: 16 },
      { legacy_id: "11", display_order: 17 },
    ]);
  });
  it("blocks missing ingredients before planning recipes", () => {
    const s = fixture();
    s.records.ingredients = [];
    s.snapshot_checksum = checksumOpsV1MasterSnapshot(s);
    expect(() => derivePlanningCatchup(s, mappings)).toThrow(
      "MISSING_DEPENDENCY:ingredients:5",
    );
  });
  it("requires a read-only, checksum-bound immutable source", () => {
    const s = fixture();
    s.records.dishes[0].dish_name = "drift";
    expect(() => derivePlanningCatchup(s, mappings)).toThrow(
      "SNAPSHOT_CHECKSUM",
    );
    const t = fixture();
    t.source_access.has_non_select_privilege = true;
    t.snapshot_checksum = checksumOpsV1MasterSnapshot(t);
    expect(() => derivePlanningCatchup(t, mappings)).toThrow(
      "SOURCE_NOT_PROVEN_READ_ONLY",
    );
  });
  it("rejects ambiguous typed source mappings", () => {
    expect(() =>
      derivePlanningCatchup(fixture(), [...mappings, ...mappings]),
    ).toThrow("DUPLICATE_TYPED_MAPPING");
  });
  it("only builds SQL for exact Staging and requires reviewed apply checksums", () => {
    const s = fixture();
    expect(() =>
      buildPlanningCatchupSql(s, { targetProjectRef: "qnthofvccilhnefdcxnz" }),
    ).toThrow("EXACT_STAGING_TARGET");
    expect(() =>
      buildPlanningCatchupSql(s, {
        targetProjectRef: "rnzxmxiiqgtdevzregff",
        apply: true,
      }),
    ).toThrow("REVIEWED_PLAN");
  });
});
