import {
  APPROVED_ATLAS_STAGING_PROJECT_REF,
  LIVE_OPS_PROJECT_DENYLIST,
  executeAtlasStagingManagementSql,
  validateApprovedAtlasStagingTarget,
} from "./atlas-staging-contract.mjs";
import { OPS_V1_SOURCE_PROJECT_REF } from "./atlas-staging-v1-reference-source.mjs";

const ELIGIBILITY_REASON =
  "Imported from OPS v1 reference snapshot; source relationship has no effective dating.";

const OBJECTS = Object.freeze([
  {
    name: "ingredientTypes",
    id: "ingredient_type_id",
    natural: ["ingredient_type_code"],
    fields: [
      "ingredient_type_code",
      "ingredient_type_name",
      "ingredient_type_status",
    ],
    managed: () => false,
    owned: () => false,
  },
  {
    name: "ingredientOrderGroups",
    id: "ingredient_order_group_id",
    natural: ["ingredient_order_group_code"],
    fields: [
      "ingredient_order_group_code",
      "ingredient_order_group_name",
      "ingredient_order_group_status",
    ],
    managed: () => false,
    owned: () => false,
  },
  {
    name: "schoolTypes",
    id: "school_type_id",
    natural: ["school_type_code"],
    fields: ["school_type_code", "school_type_name", "school_type_status"],
    owned: (row) =>
      String(row.school_type_code ?? "").startsWith("v1-school-type-"),
  },
  {
    name: "customers",
    id: "customer_id",
    natural: ["customer_code"],
    fields: [
      "customer_code",
      "customer_name",
      "customer_type",
      "customer_status",
    ],
    owned: (row) => String(row.customer_code ?? "").startsWith("v1-customer-"),
  },
  {
    name: "deliveryLocations",
    id: "delivery_location_id",
    natural: ["customer_id", "location_code"],
    fields: [
      "customer_id",
      "location_code",
      "location_name",
      "address_text",
      "delivery_instructions",
      "timezone_name",
      "location_status",
    ],
    owned: (row) => String(row.location_code ?? "").startsWith("v1-location-"),
  },
  {
    name: "schools",
    id: "school_id",
    natural: ["customer_id", "school_code"],
    fields: [
      "customer_id",
      "customer_type",
      "school_code",
      "school_name",
      "school_type_id",
      "default_delivery_location_id",
      "school_status",
      "display_order",
      "operational_notes",
      "default_student_portions",
      "default_teacher_portions",
    ],
    owned: (row) => String(row.school_code ?? "").startsWith("v1-school-"),
  },
  {
    name: "units",
    id: "unit_id",
    natural: ["unit_code"],
    fields: [
      "unit_code",
      "unit_name",
      "dimension_code",
      "decimal_scale",
      "unit_status",
    ],
    managed: (row) => row.managed,
    owned: (row) => String(row.unit_code ?? "").startsWith("v1-unit-"),
  },
  {
    name: "ingredients",
    id: "ingredient_id",
    natural: ["ingredient_code"],
    fields: [
      "ingredient_code",
      "ingredient_name",
      "ingredient_group",
      "purchase_unit_id",
      "ingredient_type_id",
      "ingredient_order_group_id",
      "ingredient_type",
      "shopping_type",
      "order_step",
      "ingredient_status",
    ],
    owned: (row) =>
      String(row.ingredient_code ?? "").startsWith("v1-ingredient-"),
  },
  {
    name: "suppliers",
    id: "supplier_id",
    natural: ["supplier_code"],
    fields: ["supplier_code", "supplier_name", "supplier_status"],
    owned: (row) => String(row.supplier_code ?? "").startsWith("v1-supplier-"),
  },
  {
    name: "supplierEligibilities",
    id: "supplier_eligibility_id",
    natural: ["supplier_id", "ingredient_id", "effective_from"],
    fields: [
      "supplier_id",
      "ingredient_id",
      "eligibility_status",
      "priority",
      "effective_from",
      "effective_to",
      "reason_note",
    ],
    owned: (row) => row.reason_note === ELIGIBILITY_REASON,
  },
]);

function same(left, right) {
  return String(left ?? "") === String(right ?? "");
}

function naturalMatch(config, left, right) {
  return config.natural.every((field) => same(left[field], right[field]));
}

function materialMatch(config, left, right) {
  return config.fields.every((field) => same(left[field], right[field]));
}

export function validateV1ReferenceImportRequest({
  environment = process.env,
  applyRequested = false,
  applyFlagPresent = false,
  targetConfirmation,
} = {}) {
  const rawTarget = String(environment.ATLAS_STAGING_PROJECT_REF ?? "")
    .trim()
    .toLowerCase();
  if (rawTarget === OPS_V1_SOURCE_PROJECT_REF) {
    throw new Error(
      "The live OPS project is forbidden as a target; source and target must differ.",
    );
  }
  if (LIVE_OPS_PROJECT_DENYLIST.includes(rawTarget)) {
    throw new Error("The live OPS project is forbidden as an import target.");
  }
  const target = validateApprovedAtlasStagingTarget(
    rawTarget,
    environment.VITE_SUPABASE_URL,
  );
  if (OPS_V1_SOURCE_PROJECT_REF === target.projectRef) {
    throw new Error("OPS v1 source and Atlas Staging target must differ.");
  }
  const accessToken = String(
    environment.ATLAS_STAGING_SUPABASE_ACCESS_TOKEN ?? "",
  ).trim();
  if (!accessToken) {
    throw new Error("ATLAS_STAGING_SUPABASE_ACCESS_TOKEN is required.");
  }
  if (applyRequested && !applyFlagPresent) {
    throw new Error("Target writes require the explicit --apply flag.");
  }
  if (
    applyRequested &&
    String(targetConfirmation ?? "")
      .trim()
      .toLowerCase() !== APPROVED_ATLAS_STAGING_PROJECT_REF
  ) {
    throw new Error("Apply requires exact target confirmation.");
  }
  return {
    apply: applyRequested,
    sourceProjectRef: OPS_V1_SOURCE_PROJECT_REF,
    targetProjectRef: target.projectRef,
    targetSupabaseUrl: target.supabaseUrl,
    targetAccessToken: accessToken,
  };
}

export function compareManifestToTarget(manifest, target = {}) {
  const byObject = {};
  let inserts = 0;
  let updates = 0;
  let noops = 0;
  let conflicts = 0;
  let sourceMissing = 0;

  for (const config of OBJECTS) {
    const desired = config.manifestRows
      ? config.manifestRows(manifest)
      : (manifest[config.name] ?? []);
    const current = target[config.name] ?? [];
    const desiredIds = new Set(desired.map((row) => String(row[config.id])));
    const counts = {
      inserts: 0,
      updates: 0,
      noops: 0,
      conflicts: 0,
      sourceMissing: current.filter(
        (row) => config.owned(row) && !desiredIds.has(String(row[config.id])),
      ).length,
      deletes: 0,
    };
    for (const row of desired) {
      const byId = current.find((item) =>
        same(item[config.id], row[config.id]),
      );
      const byNatural = current.find((item) => naturalMatch(config, item, row));
      const managed = config.managed ? config.managed(row) : true;
      if (!managed) {
        if (
          !byId ||
          !byNatural ||
          !same(byNatural[config.id], row[config.id]) ||
          !materialMatch(config, byId, row)
        ) {
          counts.conflicts += 1;
        } else {
          counts.noops += 1;
        }
      } else if (byNatural && !same(byNatural[config.id], row[config.id])) {
        counts.conflicts += 1;
      } else if (!byId) {
        counts.inserts += 1;
      } else if (!naturalMatch(config, byId, row)) {
        counts.conflicts += 1;
      } else if (materialMatch(config, byId, row)) {
        counts.noops += 1;
      } else {
        counts.updates += 1;
      }
    }
    byObject[config.name] = counts;
    inserts += counts.inserts;
    updates += counts.updates;
    noops += counts.noops;
    conflicts += counts.conflicts;
    sourceMissing += counts.sourceMissing;
  }
  return {
    byObject,
    totals: { inserts, updates, noops, conflicts, sourceMissing, deletes: 0 },
    unrelatedRowsTouched: 0,
  };
}

export function buildTargetSnapshotSql() {
  return `select jsonb_build_object(
  'ingredientTypes', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'ingredient_type_id', ingredient_type_id,
      'ingredient_type_code', ingredient_type_code,
      'ingredient_type_name', ingredient_type_name,
      'ingredient_type_status', ingredient_type_status
    ) order by ingredient_type_id), '[]'::jsonb)
    from atlas_admin.ingredient_types
  ),
  'ingredientOrderGroups', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'ingredient_order_group_id', ingredient_order_group_id,
      'ingredient_order_group_code', ingredient_order_group_code,
      'ingredient_order_group_name', ingredient_order_group_name,
      'ingredient_order_group_status', ingredient_order_group_status
    ) order by ingredient_order_group_id), '[]'::jsonb)
    from atlas_admin.ingredient_order_groups
  ),
  'schoolTypes', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'school_type_id', school_type_id,
      'school_type_code', school_type_code,
      'school_type_name', school_type_name,
      'school_type_status', school_type_status
    ) order by school_type_id), '[]'::jsonb)
    from atlas_admin.school_types
  ),
  'customers', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'customer_id', customer_id,
      'customer_code', customer_code,
      'customer_name', customer_name,
      'customer_type', customer_type,
      'customer_status', customer_status
    ) order by customer_id), '[]'::jsonb)
    from atlas_admin.customers
  ),
  'deliveryLocations', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'delivery_location_id', delivery_location_id,
      'customer_id', customer_id,
      'location_code', location_code,
      'location_name', location_name,
      'address_text', address_text,
      'delivery_instructions', delivery_instructions,
      'timezone_name', timezone_name,
      'location_status', location_status
    ) order by delivery_location_id), '[]'::jsonb)
    from atlas_admin.delivery_locations
  ),
  'schools', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'school_id', school_id,
      'customer_id', customer_id,
      'customer_type', customer_type,
      'school_code', school_code,
      'school_name', school_name,
      'school_type_id', school_type_id,
      'default_delivery_location_id', default_delivery_location_id,
      'school_status', school_status,
      'display_order', display_order,
      'operational_notes', operational_notes,
      'default_student_portions', default_student_portions,
      'default_teacher_portions', default_teacher_portions
    ) order by school_id), '[]'::jsonb)
    from atlas_admin.schools
  ),
  'units', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'unit_id', unit_id,
      'unit_code', unit_code,
      'unit_name', unit_name,
      'dimension_code', dimension_code,
      'decimal_scale', decimal_scale,
      'unit_status', unit_status
    ) order by unit_id), '[]'::jsonb)
    from atlas_admin.units
  ),
  'ingredients', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'ingredient_id', ingredient_id,
      'ingredient_code', ingredient_code,
      'ingredient_name', ingredient_name,
      'ingredient_group', ingredient_group,
      'purchase_unit_id', purchase_unit_id,
      'ingredient_type_id', ingredient_type_id,
      'ingredient_order_group_id', ingredient_order_group_id,
      'ingredient_type', ingredient_type,
      'shopping_type', shopping_type,
      'order_step', order_step,
      'ingredient_status', ingredient_status
    ) order by ingredient_id), '[]'::jsonb)
    from atlas_admin.ingredients
  ),
  'suppliers', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'supplier_id', supplier_id,
      'supplier_code', supplier_code,
      'supplier_name', supplier_name,
      'supplier_status', supplier_status
    ) order by supplier_id), '[]'::jsonb)
    from atlas_admin.suppliers
  ),
  'supplierEligibilities', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'supplier_eligibility_id', supplier_eligibility_id,
      'supplier_id', supplier_id,
      'ingredient_id', ingredient_id,
      'eligibility_status', eligibility_status,
      'priority', priority,
      'effective_from', effective_from,
      'effective_to', effective_to,
      'reason_note', reason_note
    ) order by supplier_eligibility_id), '[]'::jsonb)
    from atlas_admin.supplier_eligibilities
  )
) as target_state;`;
}

function findTargetState(value) {
  if (Array.isArray(value)) {
    for (const child of value) {
      const found = findTargetState(child);
      if (found) return found;
    }
    return null;
  }
  if (!value || typeof value !== "object") return null;
  if (value.target_state && typeof value.target_state === "object") {
    return value.target_state;
  }
  if (typeof value.target_state === "string") {
    try {
      return JSON.parse(value.target_state);
    } catch {
      return null;
    }
  }
  for (const child of Object.values(value)) {
    const found = findTargetState(child);
    if (found) return found;
  }
  return null;
}

export async function readV1ReferenceTargetState({
  target,
  fetchImpl = fetch,
} = {}) {
  const output = await executeAtlasStagingManagementSql(
    target,
    buildTargetSnapshotSql(),
    fetchImpl,
  );
  let parsed;
  try {
    parsed = JSON.parse(output);
  } catch {
    throw new Error(
      "Atlas Staging target comparison returned malformed output.",
    );
  }
  const state = findTargetState(parsed);
  if (!state) {
    throw new Error("Atlas Staging target comparison returned no state.");
  }
  return state;
}

function json(value) {
  return `'${JSON.stringify(value).replaceAll("'", "''")}'::jsonb`;
}

function catalogAssertions(manifest) {
  const typeValues = json(manifest.ingredientTypes);
  const groupValues = json(manifest.ingredientOrderGroups);
  return `
  if not exists (
    select 1 from atlas_admin.units
    where unit_id = 'a1020000-0000-4000-8000-000000000205'::uuid
      and unit_code = 'kg' and unit_status = 'ACTIVE'
  ) then raise exception 'ATLAS_STAGING_V1_KG_PREREQUISITE_MISSING'; end if;
  if exists (
    select 1
    from jsonb_to_recordset(${typeValues}) as desired(
      ingredient_type_id uuid, ingredient_type_code text,
      ingredient_type_name text
    )
    left join atlas_admin.ingredient_types current
      on current.ingredient_type_id = desired.ingredient_type_id
    where current.ingredient_type_id is null
       or current.ingredient_type_code is distinct from desired.ingredient_type_code
       or current.ingredient_type_name is distinct from desired.ingredient_type_name
       or current.ingredient_type_status <> 'ACTIVE'
  ) then raise exception 'ATLAS_STAGING_V1_INGREDIENT_TYPE_MISMATCH'; end if;
  if exists (
    select 1
    from jsonb_to_recordset(${groupValues}) as desired(
      ingredient_order_group_id uuid, ingredient_order_group_code text,
      ingredient_order_group_name text
    )
    left join atlas_admin.ingredient_order_groups current
      on current.ingredient_order_group_id = desired.ingredient_order_group_id
    where current.ingredient_order_group_id is null
       or current.ingredient_order_group_code is distinct from desired.ingredient_order_group_code
       or current.ingredient_order_group_name is distinct from desired.ingredient_order_group_name
       or current.ingredient_order_group_status <> 'ACTIVE'
  ) then raise exception 'ATLAS_STAGING_V1_ORDER_GROUP_MISMATCH'; end if;`;
}

function collisionAssertion({ values, record, table, id, natural, code }) {
  return `
  if exists (
    select 1 from jsonb_to_recordset(${json(values)}) as desired(${record})
    join ${table} current on ${natural}
    where current.${id} <> desired.${id}
  ) then raise exception '${code}'; end if;`;
}

export function buildTargetApplySql(manifest) {
  if (manifest?.metadata?.blockers?.length) {
    throw new Error("A manifest with blockers cannot be applied.");
  }
  const managedUnits = manifest.units.filter((row) => row.managed);
  const preflight = [
    collisionAssertion({
      values: manifest.schoolTypes,
      record: "school_type_id uuid, school_type_code text",
      table: "atlas_admin.school_types",
      id: "school_type_id",
      natural: "current.school_type_code = desired.school_type_code",
      code: "ATLAS_STAGING_V1_SCHOOL_TYPE_COLLISION",
    }),
    collisionAssertion({
      values: manifest.customers,
      record: "customer_id uuid, customer_code text",
      table: "atlas_admin.customers",
      id: "customer_id",
      natural: "current.customer_code = desired.customer_code",
      code: "ATLAS_STAGING_V1_CUSTOMER_COLLISION",
    }),
    collisionAssertion({
      values: manifest.deliveryLocations,
      record: "delivery_location_id uuid, customer_id uuid, location_code text",
      table: "atlas_admin.delivery_locations",
      id: "delivery_location_id",
      natural:
        "current.customer_id = desired.customer_id and current.location_code = desired.location_code",
      code: "ATLAS_STAGING_V1_LOCATION_COLLISION",
    }),
    collisionAssertion({
      values: manifest.schools,
      record: "school_id uuid, customer_id uuid, school_code text",
      table: "atlas_admin.schools",
      id: "school_id",
      natural:
        "current.customer_id = desired.customer_id and current.school_code = desired.school_code",
      code: "ATLAS_STAGING_V1_SCHOOL_COLLISION",
    }),
    collisionAssertion({
      values: managedUnits,
      record: "unit_id uuid, unit_code text",
      table: "atlas_admin.units",
      id: "unit_id",
      natural: "current.unit_code = desired.unit_code",
      code: "ATLAS_STAGING_V1_UNIT_COLLISION",
    }),
    collisionAssertion({
      values: manifest.ingredients,
      record: "ingredient_id uuid, ingredient_code text",
      table: "atlas_admin.ingredients",
      id: "ingredient_id",
      natural: "current.ingredient_code = desired.ingredient_code",
      code: "ATLAS_STAGING_V1_INGREDIENT_COLLISION",
    }),
    collisionAssertion({
      values: manifest.suppliers,
      record: "supplier_id uuid, supplier_code text",
      table: "atlas_admin.suppliers",
      id: "supplier_id",
      natural: "current.supplier_code = desired.supplier_code",
      code: "ATLAS_STAGING_V1_SUPPLIER_COLLISION",
    }),
    collisionAssertion({
      values: manifest.supplierEligibilities,
      record:
        "supplier_eligibility_id uuid, supplier_id uuid, ingredient_id uuid, effective_from date",
      table: "atlas_admin.supplier_eligibilities",
      id: "supplier_eligibility_id",
      natural:
        "current.supplier_id = desired.supplier_id and current.ingredient_id = desired.ingredient_id and current.effective_from = desired.effective_from",
      code: "ATLAS_STAGING_V1_ELIGIBILITY_COLLISION",
    }),
  ].join("");

  return `begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';
do $atlas_staging_v1_preflight$
begin${catalogAssertions(manifest)}${preflight}
end;
$atlas_staging_v1_preflight$;

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name, school_type_status
)
select school_type_id, school_type_code, school_type_name, school_type_status
from jsonb_to_recordset(${json(manifest.schoolTypes)}) as desired(
  school_type_id uuid, school_type_code text, school_type_name text,
  school_type_status text
)
on conflict (school_type_id) do update set
  school_type_code = excluded.school_type_code,
  school_type_name = excluded.school_type_name,
  school_type_status = excluded.school_type_status,
  version = atlas_admin.school_types.version + 1,
  updated_at = transaction_timestamp()
where (atlas_admin.school_types.school_type_code,
       atlas_admin.school_types.school_type_name,
       atlas_admin.school_types.school_type_status)
  is distinct from (excluded.school_type_code, excluded.school_type_name,
                    excluded.school_type_status);

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type, customer_status
)
select customer_id, customer_code, customer_name, customer_type, customer_status
from jsonb_to_recordset(${json(manifest.customers)}) as desired(
  customer_id uuid, customer_code text, customer_name text,
  customer_type text, customer_status text
)
on conflict (customer_id) do update set
  customer_code = excluded.customer_code,
  customer_name = excluded.customer_name,
  customer_type = excluded.customer_type,
  customer_status = excluded.customer_status,
  version = atlas_admin.customers.version + 1,
  updated_at = transaction_timestamp()
where (atlas_admin.customers.customer_code, atlas_admin.customers.customer_name,
       atlas_admin.customers.customer_type, atlas_admin.customers.customer_status)
  is distinct from (excluded.customer_code, excluded.customer_name,
                    excluded.customer_type, excluded.customer_status);

insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name,
  address_text, delivery_instructions, timezone_name, location_status
)
select delivery_location_id, customer_id, location_code, location_name,
       address_text, delivery_instructions, timezone_name, location_status
from jsonb_to_recordset(${json(manifest.deliveryLocations)}) as desired(
  delivery_location_id uuid, customer_id uuid, location_code text,
  location_name text, address_text text, delivery_instructions text,
  timezone_name text, location_status text
)
on conflict (delivery_location_id) do update set
  customer_id = excluded.customer_id,
  location_code = excluded.location_code,
  location_name = excluded.location_name,
  address_text = excluded.address_text,
  delivery_instructions = excluded.delivery_instructions,
  timezone_name = excluded.timezone_name,
  location_status = excluded.location_status,
  version = atlas_admin.delivery_locations.version + 1,
  updated_at = transaction_timestamp()
where (atlas_admin.delivery_locations.customer_id,
       atlas_admin.delivery_locations.location_code,
       atlas_admin.delivery_locations.location_name,
       atlas_admin.delivery_locations.address_text,
       atlas_admin.delivery_locations.delivery_instructions,
       atlas_admin.delivery_locations.timezone_name,
       atlas_admin.delivery_locations.location_status)
  is distinct from (excluded.customer_id, excluded.location_code,
                    excluded.location_name, excluded.address_text,
                    excluded.delivery_instructions, excluded.timezone_name,
                    excluded.location_status);

insert into atlas_admin.schools (
  school_id, customer_id, customer_type, school_code, school_name,
  school_type_id, default_delivery_location_id, school_status, display_order,
  operational_notes, default_student_portions, default_teacher_portions
)
select school_id, customer_id, customer_type, school_code, school_name,
       school_type_id, default_delivery_location_id, school_status, display_order,
       operational_notes, default_student_portions, default_teacher_portions
from jsonb_to_recordset(${json(manifest.schools)}) as desired(
  school_id uuid, customer_id uuid, customer_type text, school_code text,
  school_name text, school_type_id uuid, default_delivery_location_id uuid,
  school_status text, display_order integer, operational_notes text,
  default_student_portions integer, default_teacher_portions integer
)
on conflict (school_id) do update set
  customer_id = excluded.customer_id,
  customer_type = excluded.customer_type,
  school_code = excluded.school_code,
  school_name = excluded.school_name,
  school_type_id = excluded.school_type_id,
  default_delivery_location_id = excluded.default_delivery_location_id,
  school_status = excluded.school_status,
  display_order = excluded.display_order,
  operational_notes = excluded.operational_notes,
  default_student_portions = excluded.default_student_portions,
  default_teacher_portions = excluded.default_teacher_portions,
  version = atlas_admin.schools.version + 1,
  updated_at = transaction_timestamp()
where (atlas_admin.schools.customer_id, atlas_admin.schools.customer_type,
       atlas_admin.schools.school_code, atlas_admin.schools.school_name,
       atlas_admin.schools.school_type_id,
       atlas_admin.schools.default_delivery_location_id,
       atlas_admin.schools.school_status, atlas_admin.schools.display_order,
       atlas_admin.schools.operational_notes,
       atlas_admin.schools.default_student_portions,
       atlas_admin.schools.default_teacher_portions)
  is distinct from (excluded.customer_id, excluded.customer_type,
                    excluded.school_code, excluded.school_name,
                    excluded.school_type_id,
                    excluded.default_delivery_location_id,
                    excluded.school_status, excluded.display_order,
                    excluded.operational_notes,
                    excluded.default_student_portions,
                    excluded.default_teacher_portions);

insert into atlas_admin.units (
  unit_id, unit_code, unit_name, dimension_code, decimal_scale, unit_status
)
select unit_id, unit_code, unit_name, dimension_code, decimal_scale, unit_status
from jsonb_to_recordset(${json(managedUnits)}) as desired(
  unit_id uuid, unit_code text, unit_name text, dimension_code text,
  decimal_scale smallint, unit_status text
)
on conflict (unit_id) do update set
  unit_code = excluded.unit_code,
  unit_name = excluded.unit_name,
  dimension_code = excluded.dimension_code,
  decimal_scale = excluded.decimal_scale,
  unit_status = excluded.unit_status
where (atlas_admin.units.unit_code, atlas_admin.units.unit_name,
       atlas_admin.units.dimension_code, atlas_admin.units.decimal_scale,
       atlas_admin.units.unit_status)
  is distinct from (excluded.unit_code, excluded.unit_name,
                    excluded.dimension_code, excluded.decimal_scale,
                    excluded.unit_status);

insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name, ingredient_group,
  purchase_unit_id, ingredient_type_id, ingredient_order_group_id,
  ingredient_type, shopping_type, order_step, ingredient_status
)
select ingredient_id, ingredient_code, ingredient_name, ingredient_group,
       purchase_unit_id, ingredient_type_id, ingredient_order_group_id,
       ingredient_type, shopping_type, order_step, ingredient_status
from jsonb_to_recordset(${json(manifest.ingredients)}) as desired(
  ingredient_id uuid, ingredient_code text, ingredient_name text,
  ingredient_group text, purchase_unit_id uuid, ingredient_type_id uuid,
  ingredient_order_group_id uuid, ingredient_type text, shopping_type text,
  order_step numeric, ingredient_status text
)
on conflict (ingredient_id) do update set
  ingredient_code = excluded.ingredient_code,
  ingredient_name = excluded.ingredient_name,
  ingredient_group = excluded.ingredient_group,
  purchase_unit_id = excluded.purchase_unit_id,
  ingredient_type_id = excluded.ingredient_type_id,
  ingredient_order_group_id = excluded.ingredient_order_group_id,
  ingredient_type = excluded.ingredient_type,
  shopping_type = excluded.shopping_type,
  order_step = excluded.order_step,
  ingredient_status = excluded.ingredient_status,
  version = atlas_admin.ingredients.version + 1,
  updated_at = transaction_timestamp()
where (atlas_admin.ingredients.ingredient_code,
       atlas_admin.ingredients.ingredient_name,
       atlas_admin.ingredients.ingredient_group,
       atlas_admin.ingredients.purchase_unit_id,
       atlas_admin.ingredients.ingredient_type_id,
       atlas_admin.ingredients.ingredient_order_group_id,
       atlas_admin.ingredients.ingredient_type,
       atlas_admin.ingredients.shopping_type,
       atlas_admin.ingredients.order_step,
       atlas_admin.ingredients.ingredient_status)
  is distinct from (excluded.ingredient_code, excluded.ingredient_name,
                    excluded.ingredient_group, excluded.purchase_unit_id,
                    excluded.ingredient_type_id,
                    excluded.ingredient_order_group_id,
                    excluded.ingredient_type, excluded.shopping_type,
                    excluded.order_step, excluded.ingredient_status);

insert into atlas_admin.suppliers (
  supplier_id, supplier_code, supplier_name, supplier_status
)
select supplier_id, supplier_code, supplier_name, supplier_status
from jsonb_to_recordset(${json(manifest.suppliers)}) as desired(
  supplier_id uuid, supplier_code text, supplier_name text,
  supplier_status text
)
on conflict (supplier_id) do update set
  supplier_code = excluded.supplier_code,
  supplier_name = excluded.supplier_name,
  supplier_status = excluded.supplier_status,
  version = atlas_admin.suppliers.version + 1,
  updated_at = transaction_timestamp()
where (atlas_admin.suppliers.supplier_code, atlas_admin.suppliers.supplier_name,
       atlas_admin.suppliers.supplier_status)
  is distinct from (excluded.supplier_code, excluded.supplier_name,
                    excluded.supplier_status);

update atlas_admin.supplier_eligibilities current
set priority = null
from jsonb_to_recordset(${json(manifest.supplierEligibilities)}) as desired(
  supplier_eligibility_id uuid, supplier_id uuid, ingredient_id uuid,
  eligibility_status text, priority smallint, effective_from date,
  effective_to date, reason_note text
)
where current.supplier_eligibility_id = desired.supplier_eligibility_id
  and (current.supplier_id, current.ingredient_id,
       current.eligibility_status, current.priority, current.effective_from,
       current.effective_to, current.reason_note)
    is distinct from (desired.supplier_id, desired.ingredient_id,
                      desired.eligibility_status, desired.priority,
                      desired.effective_from, desired.effective_to,
                      desired.reason_note);

insert into atlas_admin.supplier_eligibilities (
  supplier_eligibility_id, supplier_id, ingredient_id, eligibility_status,
  priority, effective_from, effective_to, reason_note
)
select supplier_eligibility_id, supplier_id, ingredient_id, eligibility_status,
       priority, effective_from, effective_to, reason_note
from jsonb_to_recordset(${json(manifest.supplierEligibilities)}) as desired(
  supplier_eligibility_id uuid, supplier_id uuid, ingredient_id uuid,
  eligibility_status text, priority smallint, effective_from date,
  effective_to date, reason_note text
)
on conflict (supplier_eligibility_id) do update set
  supplier_id = excluded.supplier_id,
  ingredient_id = excluded.ingredient_id,
  eligibility_status = excluded.eligibility_status,
  priority = excluded.priority,
  effective_from = excluded.effective_from,
  effective_to = excluded.effective_to,
  reason_note = excluded.reason_note,
  version = atlas_admin.supplier_eligibilities.version + 1,
  updated_at = transaction_timestamp()
where (atlas_admin.supplier_eligibilities.supplier_id,
       atlas_admin.supplier_eligibilities.ingredient_id,
       atlas_admin.supplier_eligibilities.eligibility_status,
       atlas_admin.supplier_eligibilities.priority,
       atlas_admin.supplier_eligibilities.effective_from,
       atlas_admin.supplier_eligibilities.effective_to,
       atlas_admin.supplier_eligibilities.reason_note)
  is distinct from (excluded.supplier_id, excluded.ingredient_id,
                    excluded.eligibility_status, excluded.priority,
                    excluded.effective_from, excluded.effective_to,
                    excluded.reason_note);
commit;`;
}
