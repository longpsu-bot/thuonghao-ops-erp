import { createHash } from "node:crypto";

export const OPS_V1_MASTER_SOURCE_REF = "qnthofvccilhnefdcxnz";
export const OPS_V1_MASTER_CONTRACT = "OPS-V1-MASTER-SNAPSHOT.v1";
const UNIT_ALIASES = new Map([
  ["Kg", "kg"],
  ["kg", "kg"],
  ["Hủ", "Hũ"],
  ["Hũ", "Hũ"],
]);
const COUNT_UNITS = new Set([
  "Bịch",
  "Bó",
  "Cái",
  "Cây",
  "Chai",
  "Cốc",
  "Gói",
  "Hộp",
  "Hũ",
  "Lon",
  "Miếng",
  "Ổ",
  "Quả",
  "Trái",
]);
const SCHOOL_TYPES = new Map([
  ["1", "TIỂU HỌC"],
  ["2", "TRUNG HỌC"],
]);
const DISH_TYPES = new Map([
  ["1", ["Canh", "soup"]],
  ["2", ["Món mặn", "savory"]],
  ["3", ["Món xào", "stir_fry"]],
  ["4", ["Tráng miệng", "dessert"]],
  ["5", ["Món xế", "afternoon_snack"]],
  ["6", ["Nước", "beverage"]],
]);
const ISSUERS = new Map([
  [1, "CƠ SỞ CUNG CẤP THỰC PHẨM THƯỢNG HẢO"],
  [2, "CÔNG TY TNHH MTV TM - DV THƯỢNG HẢO"],
]);
const ISSUER_ADDRESS =
  "ĐC: 96/3 KP. Thạnh Lợi, Phường Thuận An, Tp Hồ Chí Minh, Việt Nam";

// Fixed relation/column allowlist. No caller-supplied SQL, table, field or project.
const SOURCE_COLUMNS = Object.freeze({
  schools: {
    id: "id::text",
    name: "name",
    school_full_name: "school_full_name",
    delivery_info: "delivery_info",
    default_students_num: "default_students_num",
    default_teacher_num: "default_teacher_num",
    school_type_id: "school_type_id::text",
    school_type_name: "school_type_name",
    contract_type: "contract_type",
    region_code: "region_code",
    display_order: "display_order",
    is_active: "is_active",
  },
  ingredient_type: { id: "id::text", name: "name" },
  ingredient_shopping_type: { id: "id::text", name: "name" },
  ingredients: {
    id: "id::text",
    name: "name",
    purchase_unit: "purchase_unit",
    ingredient_type_id: "ingredient_type_id::text",
    shopping_type_id: "shopping_type_id::text",
    order_step: "order_step::text",
    is_active: "is_active",
    archived_at: "archived_at",
  },
  suppliers: {
    id: "id::text",
    name: "name",
    contact_details: "contact_details",
  },
  ingredient_suppliers: {
    ingredient_id: "ingredient_id::text",
    supplier_id: "supplier_id::text",
    default_priority: "default_priority",
    lead_time_days: "lead_time_days",
  },
  dish_types: { id: "id::text", name: "name" },
  dishes: {
    id: "id::text",
    name: "name",
    dish_type_id: "dish_type_id::text",
    is_active: "is_active",
    archived_at: "archived_at",
  },
  recipes: {
    id: "id::text",
    dish_id: "dish_id::text",
    school_type_id: "school_type_id::text",
    school_id: "school_id::text",
    recipe_name: "recipe_name",
    is_general: "is_general",
    is_active: "is_active",
    archived_at: "archived_at",
    is_locked: "is_locked",
  },
  bill_of_materials: {
    id: "id::text",
    recipe_id: "recipe_id::text",
    ingredient_id: "ingredient_id::text",
    usable_quantity: "usable_quantity::text",
    purchase_unit: "purchase_unit",
    note: "note",
  },
});
export const OPS_V1_MASTER_TABLES = Object.freeze(Object.keys(SOURCE_COLUMNS));
const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
const text = (v) => (typeof v === "string" ? v.normalize("NFC").trim() : null);
function id(v) {
  if (typeof v === "number" && (!Number.isSafeInteger(v) || v < 1))
    throw new Error("INVALID_SOURCE_ID");
  const s = typeof v === "number" ? String(v) : text(v);
  if (!s || !/^[1-9]\d*$/.test(s)) throw new Error("INVALID_SOURCE_ID");
  return s;
}
const nullableId = (v) => (v == null ? null : id(v));
const hash = (s) => createHash("sha256").update(s, "utf8").digest("hex");
export function canonicalMasterJson(v) {
  if (Array.isArray(v)) return `[${v.map(canonicalMasterJson).join(",")}]`;
  if (v && typeof v === "object")
    return `{${Object.keys(v)
      .sort(cmp)
      .map((k) => `${JSON.stringify(k)}:${canonicalMasterJson(v[k])}`)
      .join(",")}}`;
  if (v === undefined || (typeof v === "number" && !Number.isFinite(v)))
    throw new Error("INVALID_JSON_VALUE");
  return JSON.stringify(v);
}
export function checksumOpsV1MasterSnapshot(snapshot) {
  const { snapshot_checksum: ignored, ...unsigned } = snapshot;
  return hash(canonicalMasterJson(unsigned));
}
export function canonicalizeUnitSourceLabel(raw) {
  const label = text(raw);
  const canonical = UNIT_ALIASES.get(label) ?? label;
  if (canonical !== "kg" && !COUNT_UNITS.has(canonical))
    throw new Error("UNSUPPORTED_UNIT");
  return canonical;
}
export function recipeLegacyId({ dishId, schoolTypeId }) {
  return `dish:${id(dishId)}:school-type:${id(schoolTypeId)}`;
}
export function recipeLineLegacyId({ dishId, schoolTypeId, ingredientId }) {
  return `recipe:${recipeLegacyId({ dishId, schoolTypeId })}:ingredient:${id(ingredientId)}`;
}
export function buildOpsV1MasterSnapshotSql() {
  const selectChecks = OPS_V1_MASTER_TABLES.map(
    (t) => `pg_catalog.has_table_privilege(role.oid, 'public.${t}', 'SELECT')`,
  ).join(" and ");
  const writeChecks = OPS_V1_MASTER_TABLES.flatMap((t) =>
    ["INSERT", "UPDATE", "DELETE", "TRUNCATE"].map(
      (p) => `pg_catalog.has_table_privilege(role.oid, 'public.${t}', '${p}')`,
    ),
  ).join(" or ");
  const relations = Object.entries(SOURCE_COLUMNS).map(([table, columns]) => {
    const fields = Object.entries(columns)
      .map(([key, expression]) => `'${key}', item.${expression}`)
      .join(", ");
    const order =
      table === "ingredient_suppliers"
        ? "item.ingredient_id, item.supplier_id"
        : "item.id";
    return `'${table}', (select coalesce(jsonb_agg(jsonb_build_object(${fields}) order by ${order}), '[]'::jsonb) from public.${table} item)`;
  });
  return `select jsonb_build_object(
    'source_project_ref', '${OPS_V1_MASTER_SOURCE_REF}',
    'exported_at', pg_catalog.statement_timestamp(),
    'source_access', (select jsonb_build_object('role_name', role.rolname,
      'superuser', role.rolsuper, 'bypass_rls', role.rolbypassrls, 'create_role', role.rolcreaterole, 'create_db', role.rolcreatedb,
      'has_required_select', (${selectChecks}), 'has_non_select_privilege', (${writeChecks}))
      from pg_catalog.pg_roles role where role.rolname = current_user),
    ${relations.join(",\n    ")}
  ) as snapshot;`;
}
function assertReadOnly(raw) {
  const a = raw?.source_access;
  if (
    raw?.source_project_ref !== OPS_V1_MASTER_SOURCE_REF ||
    !a ||
    a.role_name !== "supabase_read_only_user" ||
    a.superuser !== false ||
    a.bypass_rls !== true ||
    a.create_role !== false ||
    a.create_db !== false ||
    a.has_required_select !== true ||
    a.has_non_select_privilege !== false
  )
    throw new Error("SOURCE_NOT_PROVEN_READ_ONLY");
}
function cleanJson(v) {
  if (typeof v === "string") return text(v);
  if (Array.isArray(v)) return v.map(cleanJson);
  if (v && typeof v === "object")
    return Object.fromEntries(
      Object.entries(v).map(([k, x]) => [k, cleanJson(x)]),
    );
  return v;
}
export function normalizeOpsV1MasterSnapshot(
  raw,
  { snapshotId, extractorVersion } = {},
) {
  assertReadOnly(raw);
  if (
    !text(snapshotId) ||
    !text(extractorVersion) ||
    !text(raw.exported_at) ||
    !Number.isFinite(Date.parse(raw.exported_at))
  )
    throw new Error("INVALID_SNAPSHOT_METADATA");
  for (const t of OPS_V1_MASTER_TABLES)
    if (!Array.isArray(raw[t])) throw new Error(`INCOMPLETE_SOURCE:${t}`);
  const s = cleanJson(raw);
  const records = Object.fromEntries(
    [
      "school_types",
      "customers",
      "delivery_locations",
      "schools",
      "units",
      "ingredient_types",
      "ingredient_order_groups",
      "ingredients",
      "suppliers",
      "supplier_eligibilities",
      "dish_types",
      "dishes",
      "recipes",
      "recipe_lines",
    ].map((k) => [k, []]),
  );
  const diagnostics = [];
  const diag = (
    code,
    entity,
    legacyId,
    field,
    detail = null,
    severity = "BLOCKER",
  ) =>
    diagnostics.push({
      code,
      entity,
      legacy_id: legacyId,
      field,
      detail,
      severity,
    });
  const sourceOnly = (entity, legacyId, field, value) => {
    if (value != null && value !== "")
      diag("SOURCE_ONLY_UNMAPPED", entity, legacyId, field, value, "INFO");
  };
  const lifecycle = (row, entity, key, archive = true) => {
    if (typeof row.is_active !== "boolean")
      diag("INVALID_LIFECYCLE", entity, key, "is_active");
    if (row.is_active === true && row.archived_at)
      diag("CONFLICTING_LIFECYCLE", entity, key, "archived_at");
    return archive && row.archived_at
      ? "ARCHIVED"
      : row.is_active === true
        ? "ACTIVE"
        : "INACTIVE";
  };
  const positive = (v, entity, key, field) => {
    const token =
      typeof v === "string"
        ? text(v)
        : typeof v === "number" && Number.isSafeInteger(v)
          ? String(v)
          : null;
    if (
      !token ||
      !/^\d{1,14}(?:\.\d{1,6})?$/.test(token) ||
      !/[1-9]/.test(token)
    ) {
      diag("INVALID_QUANTITY", entity, key, field, token);
      return token;
    }
    return token
      .replace(/^0+(?=\d)/, "")
      .replace(/(\.\d*?)0+$/, "$1")
      .replace(/\.$/, "");
  };
  const requiredName = (v, entity, key) => {
    if (!text(v)) diag("MISSING_NAME", entity, key, "name");
    return text(v);
  };
  // Physical IDs are evidence, but duplicates still make source references ambiguous.
  for (const table of OPS_V1_MASTER_TABLES) {
    const seen = new Set();
    for (const row of s[table]) {
      const key =
        table === "ingredient_suppliers"
          ? `${id(row.ingredient_id)}:${id(row.supplier_id)}`
          : id(row.id);
      if (seen.has(key))
        diag("DUPLICATE_SOURCE_ID", table, key, "source_record_id");
      seen.add(key);
    }
  }
  const types = new Set();
  for (const row of s.schools) types.add(id(row.school_type_id));
  for (const row of s.recipes) types.add(id(row.school_type_id));
  for (const key of types) {
    if (!SCHOOL_TYPES.has(key))
      diag("UNKNOWN_SCHOOL_TYPE", "school_types", key, "school_type_id");
    const names = new Set(
      s.schools
        .filter((r) => String(r.school_type_id) === key)
        .map((r) => r.school_type_name),
    );
    if ([...names].some((n) => n !== SCHOOL_TYPES.get(key)))
      diag(
        "SCHOOL_TYPE_NAME_MISMATCH",
        "school_types",
        key,
        "school_type_name",
      );
    records.school_types.push({
      legacy_id: key,
      school_type_code: `v1-school-type-${key}`,
      school_type_name: SCHOOL_TYPES.get(key) ?? null,
      school_type_status: "ACTIVE",
    });
  }
  for (const row of s.schools) {
    const key = id(row.id),
      customer = `school:${key}:customer`,
      location = `school:${key}:delivery-location`;
    const name = requiredName(row.name, "schools", key),
      status = lifecycle(row, "schools", key, false);
    const full = text(row.school_full_name) || name;
    for (const field of ["default_students_num", "default_teacher_num"])
      if (!Number.isSafeInteger(row[field]) || row[field] < 0)
        diag("INVALID_SCHOOL_DEFAULT", "schools", key, field);
    if (!Number.isSafeInteger(row.display_order) || row.display_order < 0)
      diag("INVALID_DISPLAY_ORDER", "schools", key, "display_order");
    if (!text(row.delivery_info))
      diag("MISSING_DELIVERY_ADDRESS", "schools", key, "delivery_info");
    if (!ISSUERS.has(row.contract_type))
      diag("UNKNOWN_ISSUER", "schools", key, "contract_type");
    records.customers.push({
      legacy_id: customer,
      customer_code: `v1-customer-${key}`,
      customer_name: full,
      customer_type: "SCHOOL_CATERING",
      customer_status: status,
    });
    records.delivery_locations.push({
      legacy_id: location,
      customer_legacy_id: customer,
      location_code: `v1-location-${key}`,
      location_name: name,
      address_text: text(row.delivery_info),
      delivery_instructions: null,
      timezone_name: "Asia/Ho_Chi_Minh",
      location_status: status,
    });
    records.schools.push({
      legacy_id: key,
      customer_legacy_id: customer,
      delivery_location_legacy_id: location,
      school_type_legacy_id: id(row.school_type_id),
      school_code: `v1-school-${key}`,
      school_name: name,
      school_status: status,
      display_order: row.display_order,
      default_student_portions: row.default_students_num,
      default_teacher_portions: row.default_teacher_num,
      dispatch_document_issuer_name: ISSUERS.get(row.contract_type) ?? null,
      dispatch_document_issuer_address: ISSUER_ADDRESS,
    });
    sourceOnly("schools", key, "region_code", row.region_code);
  }
  for (const [sourceTable, target, prefix] of [
    ["ingredient_type", "ingredient_types", "ingredient_type"],
    [
      "ingredient_shopping_type",
      "ingredient_order_groups",
      "ingredient_order_group",
    ],
  ]) {
    for (const row of s[sourceTable])
      records[target].push({
        legacy_id: id(row.id),
        [`${prefix}_name`]: requiredName(row.name, target, id(row.id)),
      });
  }
  const units = new Map();
  const unitAliases = new Map();
  function unit(rawLabel, entity, key) {
    let label;
    try {
      label = canonicalizeUnitSourceLabel(rawLabel);
    } catch {
      label = text(rawLabel) ?? "";
      diag("UNSUPPORTED_UNIT", entity, key, "purchase_unit", label);
    }
    unitAliases.set(text(rawLabel) ?? "", label);
    if (!units.has(label))
      units.set(label, {
        legacy_id: label,
        unit_code:
          label === "kg" ? "kg" : `v1-unit-${hash(label).slice(0, 12)}`,
        unit_name: label === "kg" ? "Kilogram" : label,
        dimension_code:
          label === "kg" ? "MASS" : COUNT_UNITS.has(label) ? "COUNT" : null,
        decimal_scale: label === "kg" ? 6 : 0,
        unit_status: "ACTIVE",
      });
    return label;
  }
  const ingredientById = new Map(s.ingredients.map((r) => [id(r.id), r]));
  for (const row of s.ingredients) {
    const key = id(row.id);
    records.ingredients.push({
      legacy_id: key,
      ingredient_code: `v1-ingredient-${key}`,
      ingredient_name: requiredName(row.name, "ingredients", key),
      ingredient_type_legacy_id: nullableId(row.ingredient_type_id),
      ingredient_order_group_legacy_id: nullableId(row.shopping_type_id),
      purchase_unit_legacy_id: unit(row.purchase_unit, "ingredients", key),
      order_step: positive(row.order_step, "ingredients", key, "order_step"),
      ingredient_status: lifecycle(row, "ingredients", key),
    });
    if (
      !s.ingredient_type.some(
        (r) => String(r.id) === String(row.ingredient_type_id),
      )
    )
      diag("MISSING_INGREDIENT_TYPE", "ingredients", key, "ingredient_type_id");
    if (
      !s.ingredient_shopping_type.some(
        (r) => String(r.id) === String(row.shopping_type_id),
      )
    )
      diag("MISSING_ORDER_GROUP", "ingredients", key, "shopping_type_id");
  }
  for (const row of s.suppliers) {
    const key = id(row.id);
    records.suppliers.push({
      legacy_id: key,
      supplier_code: `v1-supplier-${key}`,
      supplier_name: requiredName(row.name, "suppliers", key),
      supplier_status: "ACTIVE",
    });
    sourceOnly("suppliers", key, "contact_details", row.contact_details);
  }
  for (const row of s.ingredient_suppliers) {
    const ingredient = id(row.ingredient_id),
      supplier = id(row.supplier_id),
      key = `ingredient:${ingredient}:supplier:${supplier}`;
    records.supplier_eligibilities.push({
      legacy_id: key,
      ingredient_legacy_id: ingredient,
      supplier_legacy_id: supplier,
      priority: row.default_priority,
    });
    if (!ingredientById.has(ingredient))
      diag(
        "MISSING_INGREDIENT",
        "supplier_eligibilities",
        key,
        "ingredient_id",
      );
    if (!s.suppliers.some((r) => String(r.id) === supplier))
      diag("MISSING_SUPPLIER", "supplier_eligibilities", key, "supplier_id");
    if (
      !Number.isInteger(row.default_priority) ||
      row.default_priority < 1 ||
      row.default_priority > 6
    )
      diag(
        "INVALID_PRIORITY",
        "supplier_eligibilities",
        key,
        "default_priority",
      );
    sourceOnly(
      "supplier_eligibilities",
      key,
      "lead_time_days",
      row.lead_time_days,
    );
  }
  for (const row of s.dish_types) {
    const key = id(row.id),
      approved = DISH_TYPES.get(key);
    if (!approved || row.name !== approved[0])
      diag("UNKNOWN_DISH_TYPE", "dish_types", key, "name", row.name);
    records.dish_types.push({
      legacy_id: key,
      dish_type_code: approved?.[1] ?? null,
      source_name: row.name,
    });
  }
  for (const row of s.dishes) {
    const key = id(row.id);
    records.dishes.push({
      legacy_id: key,
      dish_code: `v1-dish-${key}`,
      dish_name: requiredName(row.name, "dishes", key),
      dish_type_legacy_id: nullableId(row.dish_type_id),
      dish_status: lifecycle(row, "dishes", key, false),
    });
    if (!s.dish_types.some((r) => String(r.id) === String(row.dish_type_id)))
      diag("MISSING_DISH_TYPE", "dishes", key, "dish_type_id");
  }
  const recipeByRecordId = new Map();
  for (const row of s.recipes) {
    const key = recipeLegacyId({
      dishId: row.dish_id,
      schoolTypeId: row.school_type_id,
    });
    recipeByRecordId.set(id(row.id), row);
    records.recipes.push({
      legacy_id: key,
      source_record_id: id(row.id),
      dish_legacy_id: id(row.dish_id),
      school_type_legacy_id: id(row.school_type_id),
      recipe_status: lifecycle(row, "recipes", key, false),
      basis_portions: 100,
    });
    if (row.school_id != null)
      diag("UNSUPPORTED_SCHOOL_RECIPE", "recipes", key, "school_id");
    if (!s.dishes.some((r) => String(r.id) === String(row.dish_id)))
      diag("MISSING_DISH", "recipes", key, "dish_id");
    if (
      !s.bill_of_materials.some((r) => String(r.recipe_id) === String(row.id))
    )
      diag("RECIPE_EMPTY", "recipes", key, "composition", id(row.id));
    for (const f of ["recipe_name", "is_general", "is_locked"])
      sourceOnly("recipes", key, f, row[f]);
  }
  for (const row of s.bill_of_materials) {
    const recipe = recipeByRecordId.get(id(row.recipe_id)),
      ingredient = id(row.ingredient_id);
    const key = recipe
      ? recipeLineLegacyId({
          dishId: recipe.dish_id,
          schoolTypeId: recipe.school_type_id,
          ingredientId: ingredient,
        })
      : `orphan-bom:${id(row.id)}`;
    if (!recipe) diag("MISSING_RECIPE", "recipe_lines", key, "recipe_id");
    const ingredientRow = ingredientById.get(ingredient);
    if (!ingredientRow)
      diag("MISSING_INGREDIENT", "recipe_lines", key, "ingredient_id");
    else if (ingredientRow.is_active !== true || ingredientRow.archived_at)
      diag(
        "INACTIVE_INGREDIENT_REFERENCE",
        "recipe_lines",
        key,
        "ingredient_id",
      );
    records.recipe_lines.push({
      legacy_id: key,
      source_record_id: id(row.id),
      recipe_legacy_id: recipe
        ? recipeLegacyId({
            dishId: recipe.dish_id,
            schoolTypeId: recipe.school_type_id,
          })
        : null,
      ingredient_legacy_id: ingredient,
      unit_legacy_id: unit(row.purchase_unit, "recipe_lines", key),
      quantity_per_basis: positive(
        row.usable_quantity,
        "recipe_lines",
        key,
        "usable_quantity",
      ),
      operational_note: text(row.note),
    });
  }
  records.units = [...units.values()];
  for (const [entity, rows] of Object.entries(records)) {
    const keys = new Set();
    for (const row of rows) {
      if (keys.has(row.legacy_id))
        diag("DUPLICATE_IDENTITY", entity, row.legacy_id, "legacy_id");
      keys.add(row.legacy_id);
    }
    rows.sort(
      (a, b) =>
        cmp(a.legacy_id, b.legacy_id) ||
        cmp(canonicalMasterJson(a), canonicalMasterJson(b)),
    );
  }
  diagnostics.sort((a, b) =>
    cmp(canonicalMasterJson(a), canonicalMasterJson(b)),
  );
  const fingerprints = Object.fromEntries(
    Object.entries(records).map(([entity, rows]) => [
      entity,
      rows.map(({ source_record_id: ignored, ...business }) => ({
        legacy_id: business.legacy_id,
        fingerprint: hash(canonicalMasterJson(business)),
      })),
    ]),
  );
  const snapshot = {
    contract_version: OPS_V1_MASTER_CONTRACT,
    source_system: "OPS_V1",
    source_project_ref: OPS_V1_MASTER_SOURCE_REF,
    snapshot_id: text(snapshotId),
    exported_at: new Date(raw.exported_at).toISOString(),
    extractor_version: text(extractorVersion),
    complete_entities: Object.keys(records).sort(cmp),
    records,
    source_counts: Object.fromEntries(
      OPS_V1_MASTER_TABLES.map((t) => [t, s[t].length]),
    ),
    source_fingerprints: fingerprints,
    source_diagnostics: diagnostics,
    unit_alias_evidence: [...unitAliases.entries()]
      .sort(([a], [b]) => cmp(a, b))
      .map(([source_label, canonical_label]) => ({
        source_label,
        canonical_label,
      })),
    source_access: s.source_access,
  };
  return {
    ...snapshot,
    snapshot_checksum: checksumOpsV1MasterSnapshot(snapshot),
  };
}
export async function extractOpsV1MasterSnapshot({
  projectRef = OPS_V1_MASTER_SOURCE_REF,
  accessToken,
  snapshotId,
  extractorVersion,
  fetchImpl = fetch,
} = {}) {
  if (projectRef !== OPS_V1_MASTER_SOURCE_REF)
    throw new Error("UNAPPROVED_SOURCE_PROJECT");
  if (!text(accessToken)) throw new Error("SOURCE_CREDENTIAL_MISSING");
  let response;
  try {
    response = await fetchImpl(
      `https://api.supabase.com/v1/projects/${projectRef}/database/query/read-only`,
      {
        method: "POST",
        redirect: "error",
        signal: AbortSignal.timeout(60000),
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({ query: buildOpsV1MasterSnapshotSql() }),
      },
    );
  } catch {
    throw new Error("SOURCE_FETCH_FAILED");
  }
  if (response.status !== 201)
    throw new Error(`SOURCE_FETCH_FAILED_HTTP_${Number(response.status) || 0}`);
  let data;
  try {
    data = await response.json();
  } catch {
    throw new Error("SOURCE_RESPONSE_INVALID");
  }
  let raw = Array.isArray(data) && data.length === 1 ? data[0]?.snapshot : null;
  if (typeof raw === "string") {
    try {
      raw = JSON.parse(raw);
    } catch {
      throw new Error("SOURCE_RESPONSE_INVALID");
    }
  }
  assertReadOnly(raw);
  return normalizeOpsV1MasterSnapshot(raw, { snapshotId, extractorVersion });
}
