import {
  defaultCommandRunner,
  redactAtlasStagingDiagnostic,
  repositorySupabaseCliInvocation,
} from "./atlas-staging-contract.mjs";

export const OPS_V1_SOURCE_PROJECT_REF = "qnthofvccilhnefdcxnz";

const REQUIRED_SOURCE_TABLES = Object.freeze([
  "schools",
  "ingredients",
  "suppliers",
  "ingredient_suppliers",
  "ingredient_type",
  "ingredient_shopping_type",
]);

export function validateV1SourceDatabaseUrl(value) {
  let url;
  try {
    url = new URL(String(value ?? ""));
  } catch {
    throw new Error("OPS_V1_READONLY_DATABASE_URL is missing or malformed.");
  }
  if (
    !["postgres:", "postgresql:"].includes(url.protocol) ||
    !url.username ||
    !url.password ||
    !url.hostname ||
    url.pathname !== "/postgres" ||
    (url.port && url.port !== "5432")
  ) {
    throw new Error(
      "OPS_V1_READONLY_DATABASE_URL must be a dedicated session connection.",
    );
  }
  const direct = /^db\.([a-z0-9]{20})\.supabase\.co$/i.exec(url.hostname)?.[1];
  const pooled = /^postgres\.([a-z0-9]{20})$/i.exec(
    decodeURIComponent(url.username),
  )?.[1];
  const projectRef = String(direct ?? pooled ?? "").toLowerCase();
  if (projectRef !== OPS_V1_SOURCE_PROJECT_REF) {
    throw new Error(
      "The database URL is not the approved OPS v1 source project.",
    );
  }
  return { projectRef, databaseUrl: url.toString() };
}

export function buildV1SourceSnapshotSql() {
  const quotedTables = REQUIRED_SOURCE_TABLES.map((name) => `'${name}'`).join(
    ", ",
  );
  return `begin transaction isolation level repeatable read read only;
select jsonb_build_object(
  'sourceProjectRef', '${OPS_V1_SOURCE_PROJECT_REF}',
  'snapshotAt', pg_catalog.clock_timestamp(),
  'transactionReadOnly', pg_catalog.current_setting('transaction_read_only'),
  'sourceAccess', (
    select jsonb_build_object(
      'roleName', role.rolname,
      'superuser', role.rolsuper,
      'bypassRls', role.rolbypassrls,
      'createRole', role.rolcreaterole,
      'createDb', role.rolcreatedb,
      'hasRequiredSelect', (
        select count(distinct grant_row.table_name) = ${REQUIRED_SOURCE_TABLES.length}
        from information_schema.role_table_grants grant_row
        where grant_row.grantee = role.rolname
          and grant_row.table_schema = 'public'
          and grant_row.table_name in (${quotedTables})
          and grant_row.privilege_type = 'SELECT'
      ),
      'hasNonSelectTablePrivilege', exists (
        select 1
        from information_schema.role_table_grants grant_row
        where grant_row.grantee = role.rolname
          and grant_row.table_schema = 'public'
          and grant_row.table_name in (${quotedTables})
          and grant_row.privilege_type <> 'SELECT'
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
) as snapshot;
commit;`;
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
    snapshot?.transactionReadOnly !== "on" ||
    !access ||
    access.superuser !== false ||
    access.bypassRls !== false ||
    access.createRole !== false ||
    access.createDb !== false ||
    access.hasRequiredSelect !== true ||
    access.hasNonSelectTablePrivilege !== false
  ) {
    throw new Error("The OPS v1 source credential is not proven read-only.");
  }
  return snapshot;
}

export function extractV1ReferenceSnapshot({
  databaseUrl,
  cwd = process.cwd(),
  environment = process.env,
  runCommand = defaultCommandRunner,
} = {}) {
  const source = validateV1SourceDatabaseUrl(databaseUrl);
  const invocation = repositorySupabaseCliInvocation(
    [
      "db",
      "query",
      buildV1SourceSnapshotSql(),
      "--db-url",
      source.databaseUrl,
      "--output-format",
      "json",
      "--agent",
      "yes",
    ],
    { cwd },
  );
  const result = runCommand(invocation.command, invocation.args, {
    cwd,
    shell: invocation.shell,
    env: { ...environment, SUPABASE_TELEMETRY_DISABLED: "1" },
  });
  if (result.status !== 0) {
    throw new Error(
      redactAtlasStagingDiagnostic(
        `${result.stdout ?? ""}\n${result.stderr ?? ""}`,
        [databaseUrl],
      ).trim() || "OPS v1 read-only extraction failed safely.",
    );
  }
  let output;
  try {
    output = JSON.parse(String(result.stdout ?? ""));
  } catch {
    throw new Error("OPS v1 read-only extraction returned malformed output.");
  }
  const snapshot = findSnapshot(output);
  if (!snapshot) {
    throw new Error("OPS v1 read-only extraction returned no snapshot.");
  }
  return validateSourceAccess(snapshot);
}
