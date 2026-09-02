export const OPS_V1_SOURCE_PROJECT_REF = "qnthofvccilhnefdcxnz";

const REQUIRED_SOURCE_TABLES = Object.freeze([
  "schools",
  "ingredients",
  "suppliers",
  "ingredient_suppliers",
  "ingredient_type",
  "ingredient_shopping_type",
]);

export function buildV1SourceSnapshotSql() {
  const qualifiedTables = REQUIRED_SOURCE_TABLES.map(
    (name) => `public.${name}`,
  );
  const requiredSelectChecks = qualifiedTables
    .map(
      (table) =>
        `pg_catalog.has_table_privilege(role.oid, '${table}', 'SELECT')`,
    )
    .join("\n        and ");
  const nonSelectChecks = qualifiedTables
    .flatMap((table) =>
      ["INSERT", "UPDATE", "DELETE", "TRUNCATE"].map(
        (privilege) =>
          `pg_catalog.has_table_privilege(role.oid, '${table}', '${privilege}')`,
      ),
    )
    .join("\n        or ");
  return `select jsonb_build_object(
  'sourceProjectRef', '${OPS_V1_SOURCE_PROJECT_REF}',
  'snapshotAt', pg_catalog.clock_timestamp(),
  'sourceAccess', (
    select jsonb_build_object(
      'roleName', role.rolname,
      'superuser', role.rolsuper,
      'bypassRls', role.rolbypassrls,
      'createRole', role.rolcreaterole,
      'createDb', role.rolcreatedb,
      'hasRequiredSelect', (
        ${requiredSelectChecks}
      ),
      'hasNonSelectTablePrivilege', (
        ${nonSelectChecks}
      )
    )
    from pg_catalog.pg_roles role
    where role.rolname = current_user
  ),
  'schools', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', school.id,
      'name', school.name,
      'delivery_info', school.delivery_info,
      'default_students_num', school.default_students_num,
      'default_teacher_num', school.default_teacher_num,
      'school_type_id', school.school_type_id,
      'school_type_name', school.school_type_name,
      'school_full_name', school.school_full_name,
      'display_order', school.display_order
    ) order by school.id), '[]'::jsonb)
    from public.schools school
  ),
  'ingredientTypes', (
    select coalesce(jsonb_agg(jsonb_build_object('id', item.id, 'name', item.name) order by item.id), '[]'::jsonb)
    from public.ingredient_type item
  ),
  'ingredientShoppingTypes', (
    select coalesce(jsonb_agg(jsonb_build_object('id', item.id, 'name', item.name) order by item.id), '[]'::jsonb)
    from public.ingredient_shopping_type item
  ),
  'ingredients', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', ingredient.id,
      'name', ingredient.name,
      'purchase_unit', ingredient.purchase_unit,
      'ingredient_type_id', ingredient.ingredient_type_id,
      'shopping_type_id', ingredient.shopping_type_id,
      'is_active', ingredient.is_active,
      'order_step', ingredient.order_step
    ) order by ingredient.id), '[]'::jsonb)
    from public.ingredients ingredient
  ),
  'suppliers', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', supplier.id,
      'name', supplier.name
    ) order by supplier.id), '[]'::jsonb)
    from public.suppliers supplier
  ),
  'ingredientSuppliers', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'ingredient_id', relationship.ingredient_id,
      'supplier_id', relationship.supplier_id,
      'default_priority', relationship.default_priority
    ) order by relationship.ingredient_id, relationship.default_priority, relationship.supplier_id), '[]'::jsonb)
    from public.ingredient_suppliers relationship
  )
) as snapshot;`;
}

function findSnapshot(value) {
  if (Array.isArray(value)) {
    for (const child of value) {
      const found = findSnapshot(child);
      if (found) return found;
    }
    return null;
  }
  if (!value || typeof value !== "object") return null;
  if (value.snapshot && typeof value.snapshot === "object")
    return value.snapshot;
  if (typeof value.snapshot === "string") {
    try {
      return JSON.parse(value.snapshot);
    } catch {
      return null;
    }
  }
  for (const child of Object.values(value)) {
    const found = findSnapshot(child);
    if (found) return found;
  }
  return null;
}

function validateSourceAccess(snapshot) {
  const access = snapshot?.sourceAccess;
  if (
    snapshot?.sourceProjectRef !== OPS_V1_SOURCE_PROJECT_REF ||
    !access ||
    access.roleName !== "supabase_read_only_user" ||
    access.superuser !== false ||
    access.createRole !== false ||
    access.createDb !== false ||
    access.hasRequiredSelect !== true ||
    access.hasNonSelectTablePrivilege !== false
  ) {
    throw new Error("The OPS v1 source response is not proven read-only.");
  }
  return snapshot;
}

export async function extractV1ReferenceSnapshot({
  projectRef = OPS_V1_SOURCE_PROJECT_REF,
  accessToken,
  fetchImpl = fetch,
} = {}) {
  if (
    String(projectRef ?? "")
      .trim()
      .toLowerCase() !== OPS_V1_SOURCE_PROJECT_REF
  ) {
    throw new Error("The project is not the approved OPS v1 source project.");
  }
  const token = String(accessToken ?? "").trim();
  if (!token)
    throw new Error("OPS v1 read-only extraction requires an access token.");

  let response;
  try {
    response = await fetchImpl(
      `https://api.supabase.com/v1/projects/${OPS_V1_SOURCE_PROJECT_REF}/database/query/read-only`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({ query: buildV1SourceSnapshotSql() }),
      },
    );
  } catch {
    throw new Error("OPS v1 read-only extraction failed safely.");
  }
  if (response.status !== 201) {
    const safeStatus =
      Number.isInteger(response.status) &&
      response.status >= 100 &&
      response.status <= 599
        ? ` (HTTP ${response.status})`
        : "";
    throw new Error(`OPS v1 read-only extraction failed safely${safeStatus}.`);
  }

  let output;
  try {
    output = JSON.parse(await response.text());
  } catch {
    throw new Error("OPS v1 read-only extraction returned malformed output.");
  }
  const snapshot = findSnapshot(output);
  if (!snapshot) {
    throw new Error("OPS v1 read-only extraction returned no snapshot.");
  }
  return validateSourceAccess(snapshot);
}
