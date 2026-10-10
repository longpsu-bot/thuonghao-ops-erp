// Owner-approved source identities. Names validate identity; never resolve it.
export const ownerSchoolIdentityExpectations = [
  ["52", "BÌNH QUỚI"],
  ["10", "BÌNH QUỚI - PHÂN HIỆU"],
  ["47", "CHUYÊN HÙNG VƯƠNG (Sáng)"],
  ["48", "CHUYÊN HÙNG VƯƠNG (Trưa)"],
  ["49", "CHUYÊN HÙNG VƯƠNG (Trưa Mặn 2)"],
  ["50", "CHUYÊN HÙNG VƯƠNG (Chiều)"],
  ["53", "CHUYÊN HÙNG VƯƠNG (Chiều Mặn 2)"],
  ["40", "VĨNH TÂN"],
  ["38", "VĨNH TÂN - PHÂN HIỆU"],
  ["19", "PHÚ HOÀ ĐÔNG 1"],
  ["46", "PHÚ HOÀ ĐÔNG 1 - PHÂN HIỆU 1"],
  ["27", "PHÚ HOÀ ĐÔNG 1 - PHÂN HIỆU 2"],
  ["28", "PHÚ HOÀ ĐÔNG 1 - PHÂN HIỆU 3"],
  ["17", "PHẠM VĂN CỘI"],
  ["14", "LÊ VĂN THẾ"],
];

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function reconciliationRequired(detail) {
  throw new Error(`SCHOOL_MASTER_RECONCILIATION_REQUIRED: ${detail}`);
}

// A report may describe missing/stale facts; it never resolves identity by name.
// Ambiguous target mappings are reported so a caller can stop before mutation.
export function buildSchoolMasterReconciliationReport({
  source,
  schools,
  mappings,
}) {
  if (![source, schools, mappings].every(Array.isArray))
    reconciliationRequired("Missing source or typed target evidence.");
  const typed = mappings.filter(
    (m) => m.source_system === "OPS_V1" && m.object_type === "SCHOOL",
  );
  const expected = new Map(ownerSchoolIdentityExpectations);
  return [
    "10",
    "52",
    "47",
    "48",
    "49",
    "50",
    "53",
    "40",
    "38",
    "19",
    "46",
    "27",
    "28",
    "17",
    "14",
  ].map((legacyId) => {
    const sourceRows = source.filter((r) => r.legacy_school_id === legacyId);
    if (
      sourceRows.length !== 1 ||
      sourceRows[0].source_name !== expected.get(legacyId)
    )
      reconciliationRequired(
        `Current source identity differs for OPS_V1/${legacyId}.`,
      );
    const matches = typed.filter((m) => m.legacy_id === legacyId);
    const mapping = matches.length === 1 ? matches[0] : null;
    const targets = mapping
      ? schools.filter((s) => s.school_id === mapping.school_id)
      : [];
    const target = targets.length === 1 ? targets[0] : null;
    const code = `v1-school-${legacyId}`;
    const shared =
      mapping &&
      typed.some(
        (m) => m.legacy_id !== legacyId && m.school_id === mapping.school_id,
      );
    const collision = schools.some(
      (s) => s.school_code === code && s.school_id !== mapping?.school_id,
    );
    let status;
    if (matches.length > 1 || shared || targets.length > 1)
      status = "DUPLICATE_MAPPING";
    else if (
      collision ||
      (mapping &&
        (!uuid.test(mapping.school_id) ||
          !target ||
          target.school_code !== code))
    )
      status = "WRONG_MAPPING";
    else if (!mapping) status = "MISSING";
    else if (target.school_name !== sourceRows[0].source_name)
      status = "NAME_MISMATCH";
    else status = "MATCH";
    return {
      legacy_school_id: legacyId,
      source_name: sourceRows[0].source_name,
      current_atlas_school_id: mapping?.school_id ?? null,
      current_atlas_code: target?.school_code ?? null,
      current_atlas_name: target?.school_name ?? null,
      status,
      proposed_action:
        status === "MATCH"
          ? "PRESERVE_TYPED_IDENTITY; REVIEW_CURRENT_SOURCE_FACTS"
          : status === "NAME_MISMATCH"
            ? "RECONCILE_SOURCE_FACTS; PRESERVE_MAPPED_UUID"
            : status === "MISSING"
              ? "CONTROLLED_CREATE_WITH_TYPED_MAPPING"
              : "STOP: SCHOOL_MASTER_RECONCILIATION_REQUIRED",
    };
  });
}

// Read-only plan builder. Inputs come from the existing controlled master
// reconciliation path and its typed mapping readback, never a name lookup.
export function buildSchoolDocumentConfiguration({ schools, mappings }) {
  if (!Array.isArray(schools) || !Array.isArray(mappings))
    reconciliationRequired("Missing master evidence.");
  const byId = new Map();
  const codes = new Set();
  for (const school of schools) {
    if (
      !uuid.test(school.school_id) ||
      byId.has(school.school_id) ||
      codes.has(school.school_code) ||
      !Number.isSafeInteger(school.display_order) ||
      school.display_order < 0
    )
      reconciliationRequired("Invalid or duplicate School identity/order.");
    byId.set(school.school_id, school);
    codes.add(school.school_code);
  }
  const resolved = new Map();
  for (const [legacyId, expectedName] of ownerSchoolIdentityExpectations) {
    const matches = mappings.filter(
      (m) =>
        m.source_system === "OPS_V1" &&
        m.object_type === "SCHOOL" &&
        m.legacy_id === legacyId,
    );
    if (matches.length !== 1)
      reconciliationRequired(
        `Expected one typed SCHOOL mapping for OPS_V1/${legacyId}.`,
      );
    const school = byId.get(matches[0].school_id);
    if (
      !school ||
      school.school_code !== `v1-school-${legacyId}` ||
      school.school_name !== expectedName
    )
      reconciliationRequired(
        `Canonical School mismatch for OPS_V1/${legacyId}.`,
      );
    if (
      mappings.some(
        (m) =>
          m.source_system === "OPS_V1" &&
          m.object_type === "SCHOOL" &&
          m.legacy_id !== legacyId &&
          m.school_id === school.school_id,
      )
    )
      reconciliationRequired("Multiple source Schools resolve to one target.");
    if ([...resolved.values()].includes(school.school_id))
      reconciliationRequired("Multiple source Schools resolve to one target.");
    resolved.set(legacyId, school.school_id);
  }
  const ids = (legacyIds) => legacyIds.map((id) => resolved.get(id));
  const dispatch_groups = [
    { dispatch_group_name: "VĨNH TÂN", school_ids: ids(["40", "38"]) },
    {
      dispatch_group_name: "CHUYÊN HÙNG VƯƠNG",
      school_ids: ids(["47", "48", "49", "50", "53"]),
    },
    {
      dispatch_group_name: "PHÚ HOÀ ĐÔNG 1",
      school_ids: ids(["19", "46", "27"]),
    },
  ];
  const cooking_locations = [
    {
      display_name: "PHẠM VĂN CỘI",
      location_kind: "SCHOOL",
      host_school_id: resolved.get("17"),
      school_ids: ids(["17", "14"]),
    },
    {
      display_name: "VĨNH TÂN",
      location_kind: "SCHOOL",
      host_school_id: resolved.get("40"),
      school_ids: ids(["40", "38"]),
    },
    {
      display_name: "Công ty Thượng Hảo",
      location_kind: "COMPANY",
      host_school_id: null,
      school_ids: ids(["53"]),
    },
  ];
  let order = [...schools]
    // Stable sort retains canonical readback order when display_order ties.
    .sort((a, b) => a.display_order - b.display_order)
    .map((s) => s.school_id);
  for (const target of [
    ids(["52", "10"]),
    ids(["47", "48", "49", "50", "53"]),
  ]) {
    const targetSet = new Set(target);
    const first = order.findIndex((id) => targetSet.has(id));
    const insertion = order
      .slice(0, first)
      .filter((id) => !targetSet.has(id)).length;
    order = order.filter((id) => !targetSet.has(id));
    order.splice(insertion, 0, ...target);
  }
  return {
    status: "CONFIGURATION_PLAN_ONLY",
    dispatch_groups,
    cooking_locations,
    excluded_dispatch_school_ids: ids(["28"]),
    target_school_order_ids: order,
  };
}
