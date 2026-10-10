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
