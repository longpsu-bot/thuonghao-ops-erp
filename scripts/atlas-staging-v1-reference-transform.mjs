import { createHash } from "node:crypto";

export const ATLAS_STAGING_V1_NAMESPACE =
  "6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7";

const KG_UNIT_ID = "a1020000-0000-4000-8000-000000000205";
const ELIGIBILITY_EFFECTIVE_FROM = "2000-01-01";
const ELIGIBILITY_REASON =
  "Imported from OPS v1 reference snapshot; source relationship has no effective dating.";

const COUNT_UNIT_LABELS = new Set([
  "Bịch",
  "Bó",
  "Cái",
  "Cây",
  "Chai",
  "Cốc",
  "Gói",
  "Hộp",
  "Hũ",
  "Hủ",
  "Lon",
  "Miếng",
  "Ổ",
  "Quả",
  "Trái",
]);

const INGREDIENT_TYPES = new Map([
  ["Bánh kẹo", ["c3100000-0000-4000-8000-000000000001", "banh_keo"]],
  ["Bánh nước", ["c3100000-0000-4000-8000-000000000002", "banh_nuoc"]],
  ["Bò", ["c3100000-0000-4000-8000-000000000003", "bo"]],
  ["Bơ sữa", ["c3100000-0000-4000-8000-000000000004", "bo_sua"]],
  [
    "Bún, nui, mì khô",
    ["c3100000-0000-4000-8000-000000000005", "bun_nui_mi_kho"],
  ],
  ["Chả", ["c3100000-0000-4000-8000-000000000006", "cha"]],
  ["Đậu hủ", ["c3100000-0000-4000-8000-000000000007", "dau_hu"]],
  ["Gia cầm", ["c3100000-0000-4000-8000-000000000008", "gia_cam"]],
  ["Heo", ["c3100000-0000-4000-8000-000000000009", "heo"]],
  ["Khác", ["c3100000-0000-4000-8000-000000000010", "khac"]],
  [
    "Lạp xưởng - tôm khô",
    ["c3100000-0000-4000-8000-000000000011", "lap_xuong_tom_kho"],
  ],
  ["Rau củ quả", ["c3100000-0000-4000-8000-000000000012", "rau_cu_qua"]],
  ["Sữa tươi", ["c3100000-0000-4000-8000-000000000013", "sua_tuoi"]],
  ["Tần tươi", ["c3100000-0000-4000-8000-000000000014", "tan_tuoi"]],
  [
    "Thực phẩm khô - gia vị",
    ["c3100000-0000-4000-8000-000000000015", "thuc_pham_kho_gia_vi"],
  ],
  ["Thuỷ hải sản", ["c3100000-0000-4000-8000-000000000016", "thuy_hai_san"]],
  ["Trứng", ["c3100000-0000-4000-8000-000000000017", "trung"]],
]);

const ORDER_GROUPS = new Map([
  ["Hàng đặt riêng", ["c3200000-0000-4000-8000-000000000001", "pantry"]],
  ["Rau củ", ["c3200000-0000-4000-8000-000000000002", "daily_vegetable"]],
  ["Còn lại", ["c3200000-0000-4000-8000-000000000003", "daily_other"]],
]);

function parseUuid(value) {
  const hex = String(value).replaceAll("-", "");
  if (!/^[0-9a-f]{32}$/i.test(hex))
    throw new Error("UUID namespace is invalid.");
  return Buffer.from(hex, "hex");
}

function formatUuid(bytes) {
  const hex = Buffer.from(bytes).toString("hex");
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20),
  ].join("-");
}

export function deterministicV1Uuid(name) {
  const hash = createHash("sha1")
    .update(parseUuid(ATLAS_STAGING_V1_NAMESPACE))
    .update(Buffer.from(String(name), "utf8"))
    .digest();
  const bytes = Buffer.from(hash.subarray(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  return formatUuid(bytes);
}

function text(value) {
  const normalized = String(value ?? "").trim();
  return normalized || null;
}

function integer(value, label) {
  const number = Number(value);
  if (!Number.isSafeInteger(number)) throw new Error(`${label} is invalid.`);
  return number;
}

function positiveDecimal(value, label) {
  const normalized = text(value);
  if (
    !normalized ||
    !/^\d+(?:\.\d+)?$/.test(normalized) ||
    Number(normalized) <= 0
  ) {
    throw new Error(`${label} is invalid.`);
  }
  return normalized;
}

function uniqueById(rows, id, duplicateCode) {
  const seen = new Set();
  for (const row of rows) {
    const key = id(row);
    if (seen.has(key)) throw new Error(duplicateCode);
    seen.add(key);
  }
}

function unitCode(label) {
  return `v1-unit-${createHash("sha256").update(label, "utf8").digest("hex").slice(0, 12)}`;
}

function sourceLookupMap(rows, label) {
  const result = new Map();
  for (const row of rows) {
    const id = integer(row.id, `${label} ID`);
    const name = text(row.name);
    if (!name) throw new Error(`${label} name is missing.`);
    if (result.has(id) && result.get(id) !== name) {
      throw new Error(`${label} source identity is ambiguous.`);
    }
    result.set(id, name);
  }
  return result;
}

function transformCatalog(source, atlas, kind) {
  return [...source.entries()]
    .map(([sourceId, name]) => {
      const match = atlas.get(name);
      if (!match) throw new Error(`UNMAPPED_${kind}:${name}`);
      const [id, code] = match;
      return kind === "INGREDIENT_TYPE"
        ? {
            source_id: sourceId,
            ingredient_type_id: id,
            ingredient_type_code: code,
            ingredient_type_name: name,
            ingredient_type_status: "ACTIVE",
            managed: false,
          }
        : {
            source_id: sourceId,
            ingredient_order_group_id: id,
            ingredient_order_group_code: code,
            ingredient_order_group_name: name,
            ingredient_order_group_status: "ACTIVE",
            managed: false,
          };
    })
    .sort((left, right) => left.source_id - right.source_id);
}

function transformUnits(activeIngredients) {
  const labels = [
    ...new Set(activeIngredients.map((row) => text(row.purchase_unit))),
  ].sort((left, right) => left.localeCompare(right, "vi"));
  const unitsById = new Map();
  const unitByLabel = new Map();
  for (const label of labels) {
    if (!label) throw new Error("MISSING_PURCHASE_UNIT");
    let unit;
    if (label.toLowerCase() === "kg") {
      unit = {
        source_labels: [],
        canonical_source_unit: "kg",
        unit_id: KG_UNIT_ID,
        unit_code: "kg",
        unit_name: "Kilogram",
        dimension_code: "MASS",
        decimal_scale: 6,
        unit_status: "ACTIVE",
        managed: false,
      };
    } else if (!COUNT_UNIT_LABELS.has(label)) {
      throw new Error(`UNSUPPORTED_UNIT_SEMANTICS:${label}`);
    } else {
      unit = {
        source_labels: [],
        canonical_source_unit: label,
        unit_id: deterministicV1Uuid(`unit:${label}`),
        unit_code: unitCode(label),
        unit_name: label,
        dimension_code: "COUNT",
        decimal_scale: 0,
        unit_status: "ACTIVE",
        managed: true,
      };
    }
    const existing = unitsById.get(unit.unit_id);
    const canonical = existing ?? unit;
    canonical.source_labels.push(label);
    unitsById.set(unit.unit_id, canonical);
    unitByLabel.set(label, canonical);
  }
  return {
    units: [...unitsById.values()].sort((left, right) =>
      left.unit_code.localeCompare(right.unit_code),
    ),
    unitByLabel,
  };
}

function procurementSummary(eligibilities) {
  const priorities = new Map();
  for (const item of eligibilities) {
    const values = priorities.get(item.ingredient_id) ?? [];
    values.push(item.priority);
    priorities.set(item.ingredient_id, values);
  }
  let atLeast2 = 0;
  let atLeast4 = 0;
  let equalBest = 0;
  for (const values of priorities.values()) {
    if (values.length >= 2) atLeast2 += 1;
    if (values.length >= 4) atLeast4 += 1;
    const best = Math.min(...values);
    if (values.filter((value) => value === best).length > 1) equalBest += 1;
  }
  return {
    ingredientsWithAtLeast2Suppliers: atLeast2,
    ingredientsWithAtLeast4Suppliers: atLeast4,
    ingredientsWithEqualBestPriority: equalBest,
  };
}

export function transformV1ReferenceSnapshot(snapshot) {
  if (snapshot?.sourceProjectRef !== "qnthofvccilhnefdcxnz") {
    throw new Error("OPS v1 source project identity is invalid.");
  }
  if (snapshot.transactionReadOnly !== "on") {
    throw new Error("OPS v1 extraction transaction was not read-only.");
  }
  if (!text(snapshot.snapshotAt))
    throw new Error("Snapshot timestamp is missing.");

  const sourceSchools = Array.isArray(snapshot.schools) ? snapshot.schools : [];
  const sourceIngredients = Array.isArray(snapshot.ingredients)
    ? snapshot.ingredients
    : [];
  const sourceSuppliers = Array.isArray(snapshot.suppliers)
    ? snapshot.suppliers
    : [];
  const sourceRelationships = Array.isArray(snapshot.ingredientSuppliers)
    ? snapshot.ingredientSuppliers
    : [];
  uniqueById(sourceSchools, (row) => String(row.id), "DUPLICATE_SCHOOL");
  uniqueById(
    sourceIngredients,
    (row) => String(row.id),
    "DUPLICATE_INGREDIENT",
  );
  uniqueById(sourceSuppliers, (row) => String(row.id), "DUPLICATE_SUPPLIER");
  uniqueById(
    sourceRelationships,
    (row) => `${row.ingredient_id}:${row.supplier_id}`,
    "DUPLICATE_SUPPLIER_ELIGIBILITY",
  );

  const sourceIngredientTypes = sourceLookupMap(
    snapshot.ingredientTypes ?? [],
    "Ingredient Type",
  );
  const sourceOrderGroups = sourceLookupMap(
    snapshot.ingredientShoppingTypes ?? [],
    "Ingredient Order Group",
  );
  const ingredientTypes = transformCatalog(
    sourceIngredientTypes,
    INGREDIENT_TYPES,
    "INGREDIENT_TYPE",
  );
  const ingredientOrderGroups = transformCatalog(
    sourceOrderGroups,
    ORDER_GROUPS,
    "INGREDIENT_ORDER_GROUP",
  );
  const ingredientTypeIds = new Map(
    ingredientTypes.map((item) => [item.source_id, item.ingredient_type_id]),
  );
  const orderGroupIds = new Map(
    ingredientOrderGroups.map((item) => [
      item.source_id,
      item.ingredient_order_group_id,
    ]),
  );

  const validSchools = [];
  const skippedSchoolIds = new Set();
  for (const row of [...sourceSchools].sort(
    (a, b) => Number(a.id) - Number(b.id),
  )) {
    const id = integer(row.id, "School ID");
    if (row.default_students_num == null || row.default_teacher_num == null) {
      skippedSchoolIds.add(id);
      continue;
    }
    const displayName = text(row.school_full_name) ?? text(row.name);
    const address = text(row.delivery_info);
    const typeId = integer(row.school_type_id, "School Type ID");
    if (!displayName || !address || !text(row.school_type_name)) {
      throw new Error(`INVALID_SCHOOL:${id}`);
    }
    validSchools.push({
      id,
      displayName,
      address,
      typeId,
      typeName: text(row.school_type_name),
      displayOrder: integer(row.display_order, "School display order"),
      studentPortions: integer(
        row.default_students_num,
        "Default Student portions",
      ),
      teacherPortions: integer(
        row.default_teacher_num,
        "Default Teacher portions",
      ),
    });
  }

  const schoolTypeNames = new Map();
  for (const row of sourceSchools) {
    const typeId = integer(row.school_type_id, "School Type ID");
    const typeName = text(row.school_type_name);
    if (!typeName) throw new Error(`INVALID_SCHOOL_TYPE:${typeId}`);
    const existing = schoolTypeNames.get(typeId);
    if (existing && existing !== typeName) {
      throw new Error(`AMBIGUOUS_SCHOOL_TYPE:${typeId}`);
    }
    schoolTypeNames.set(typeId, typeName);
  }
  const schoolTypes = [...schoolTypeNames.entries()]
    .map(([id, name]) => ({
      source_id: id,
      school_type_id: deterministicV1Uuid(`school-type:${id}`),
      school_type_code: `v1-school-type-${id}`,
      school_type_name: name,
      school_type_status: "ACTIVE",
    }))
    .sort((left, right) => left.source_id - right.source_id);

  const customers = validSchools.map((school) => ({
    source_id: school.id,
    customer_id: deterministicV1Uuid(`customer:school:${school.id}`),
    customer_code: `v1-customer-${school.id}`,
    customer_name: school.displayName,
    customer_type: "SCHOOL_CATERING",
    customer_status: "ACTIVE",
  }));
  const deliveryLocations = validSchools.map((school) => ({
    source_id: school.id,
    delivery_location_id: deterministicV1Uuid(
      `delivery-location:school:${school.id}`,
    ),
    customer_id: deterministicV1Uuid(`customer:school:${school.id}`),
    location_code: `v1-location-${school.id}`,
    location_name: `${school.displayName} — Điểm giao hàng`,
    address_text: school.address,
    delivery_instructions: null,
    timezone_name: "Asia/Ho_Chi_Minh",
    location_status: "ACTIVE",
  }));
  const schools = validSchools.map((school) => ({
    source_id: school.id,
    school_id: deterministicV1Uuid(`school:${school.id}`),
    customer_id: deterministicV1Uuid(`customer:school:${school.id}`),
    customer_type: "SCHOOL_CATERING",
    school_code: `v1-school-${school.id}`,
    school_name: school.displayName,
    school_type_id: deterministicV1Uuid(`school-type:${school.typeId}`),
    default_delivery_location_id: deterministicV1Uuid(
      `delivery-location:school:${school.id}`,
    ),
    school_status: "ACTIVE",
    display_order: school.displayOrder,
    operational_notes: null,
    default_student_portions: school.studentPortions,
    default_teacher_portions: school.teacherPortions,
  }));

  const activeSourceIngredients = sourceIngredients
    .filter((row) => row.is_active === true)
    .sort((a, b) => Number(a.id) - Number(b.id));
  const transformedUnits = transformUnits(activeSourceIngredients);
  const units = transformedUnits.units;
  const unitByLabel = transformedUnits.unitByLabel;
  const ingredients = activeSourceIngredients.map((row) => {
    const id = integer(row.id, "Ingredient ID");
    const name = text(row.name);
    const label = text(row.purchase_unit);
    const typeId = ingredientTypeIds.get(
      integer(row.ingredient_type_id, "Ingredient Type ID"),
    );
    const groupId = orderGroupIds.get(
      integer(row.shopping_type_id, "Ingredient Order Group ID"),
    );
    if (!name || !label || !typeId || !groupId) {
      throw new Error(`INVALID_INGREDIENT:${id}`);
    }
    const unit = unitByLabel.get(label);
    return {
      source_id: id,
      ingredient_id: deterministicV1Uuid(`ingredient:${id}`),
      ingredient_code: `v1-ingredient-${id}`,
      ingredient_name: name,
      ingredient_group: sourceIngredientTypes.get(
        Number(row.ingredient_type_id),
      ),
      purchase_unit_id: unit.unit_id,
      ingredient_type_id: typeId,
      ingredient_order_group_id: groupId,
      ingredient_type: sourceIngredientTypes.get(
        Number(row.ingredient_type_id),
      ),
      shopping_type: sourceOrderGroups.get(Number(row.shopping_type_id)),
      order_step: positiveDecimal(row.order_step, "Ingredient order step"),
      ingredient_status: "ACTIVE",
    };
  });
  const activeIngredientIds = new Set(
    ingredients.map((item) => item.source_id),
  );

  const suppliers = [...sourceSuppliers]
    .sort((a, b) => Number(a.id) - Number(b.id))
    .map((row) => {
      const id = integer(row.id, "Supplier ID");
      const name = text(row.name);
      if (!name) throw new Error(`INVALID_SUPPLIER:${id}`);
      return {
        source_id: id,
        supplier_id: deterministicV1Uuid(`supplier:${id}`),
        supplier_code: `v1-supplier-${id}`,
        supplier_name: name,
        supplier_status: "ACTIVE",
      };
    });
  const supplierIds = new Set(suppliers.map((item) => item.source_id));

  const supplierEligibilities = sourceRelationships
    .filter((row) => activeIngredientIds.has(Number(row.ingredient_id)))
    .sort(
      (left, right) =>
        Number(left.ingredient_id) - Number(right.ingredient_id) ||
        Number(left.default_priority) - Number(right.default_priority) ||
        Number(left.supplier_id) - Number(right.supplier_id),
    )
    .map((row) => {
      const ingredientId = integer(
        row.ingredient_id,
        "Eligibility Ingredient ID",
      );
      const supplierId = integer(row.supplier_id, "Eligibility Supplier ID");
      const priority = integer(row.default_priority, "Eligibility priority");
      if (!supplierIds.has(supplierId) || priority < 1 || priority > 6) {
        throw new Error(
          `INVALID_SUPPLIER_ELIGIBILITY:${ingredientId}:${supplierId}`,
        );
      }
      return {
        source_ingredient_id: ingredientId,
        source_supplier_id: supplierId,
        supplier_eligibility_id: deterministicV1Uuid(
          `supplier-eligibility:${ingredientId}:${supplierId}`,
        ),
        supplier_id: deterministicV1Uuid(`supplier:${supplierId}`),
        ingredient_id: deterministicV1Uuid(`ingredient:${ingredientId}`),
        eligibility_status: "ACTIVE",
        priority,
        effective_from: ELIGIBILITY_EFFECTIVE_FROM,
        effective_to: null,
        reason_note: ELIGIBILITY_REASON,
      };
    });

  const priorityCounts = new Map();
  for (const eligibility of supplierEligibilities) {
    const key = `${eligibility.ingredient_id}:${eligibility.priority}`;
    priorityCounts.set(key, (priorityCounts.get(key) ?? 0) + 1);
  }
  const duplicatePriorityCount = [...priorityCounts.values()].filter(
    (count) => count > 1,
  ).length;

  return {
    metadata: {
      sourceSystem: "OPS_V1",
      sourceProjectRef: snapshot.sourceProjectRef,
      snapshotAt: snapshot.snapshotAt,
      sourceCounts: {
        schools: sourceSchools.length,
        activeIngredients: activeSourceIngredients.length,
        suppliers: sourceSuppliers.length,
        ingredientSupplierRelationships: sourceRelationships.length,
      },
      transformedCounts: {
        schoolTypes: schoolTypes.length,
        customers: customers.length,
        deliveryLocations: deliveryLocations.length,
        schools: schools.length,
        units: units.length,
        ingredients: ingredients.length,
        suppliers: suppliers.length,
        supplierEligibilities: supplierEligibilities.length,
      },
      skipped: {
        schools: skippedSchoolIds.size,
        schoolBundles: skippedSchoolIds.size,
        inactiveIngredients:
          sourceIngredients.length - activeSourceIngredients.length,
        supplierEligibilities:
          sourceRelationships.length - supplierEligibilities.length,
      },
      warnings: skippedSchoolIds.size
        ? [
            {
              code: "MISSING_REQUIRED_DEFAULT_PORTIONS",
              count: skippedSchoolIds.size,
            },
          ]
        : [],
      blockers: duplicatePriorityCount
        ? [
            {
              code: "DUPLICATE_INGREDIENT_PRIORITY",
              count: duplicatePriorityCount,
            },
          ]
        : [],
      unmappedSourceLookupValues: [],
      procurementUsefulness: procurementSummary(supplierEligibilities),
    },
    schoolTypes,
    customers,
    deliveryLocations,
    schools,
    units,
    ingredientTypes,
    ingredientOrderGroups,
    ingredients,
    suppliers,
    supplierEligibilities,
  };
}

export function formatImportReport({ manifest, comparison, mode }) {
  return JSON.stringify(
    {
      mode,
      sourceProjectRef: manifest.metadata.sourceProjectRef,
      snapshotAt: manifest.metadata.snapshotAt,
      source: manifest.metadata.sourceCounts,
      transformation: {
        counts: manifest.metadata.transformedCounts,
        skipped: manifest.metadata.skipped,
        warnings: manifest.metadata.warnings,
        blockers: manifest.metadata.blockers,
        unmappedSourceLookupValues:
          manifest.metadata.unmappedSourceLookupValues,
      },
      procurementUsefulness: manifest.metadata.procurementUsefulness,
      targetComparison: comparison,
    },
    null,
    2,
  );
}
