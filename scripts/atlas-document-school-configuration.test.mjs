// @vitest-environment node
import { test } from "vitest";
import assert from "node:assert/strict";
import {
  buildSchoolDocumentConfiguration,
  ownerSchoolIdentityExpectations,
} from "./atlas-document-school-configuration.mjs";

function fixture() {
  const schools = ownerSchoolIdentityExpectations.map(([id, name], i) => ({
    school_id: `00000000-0000-4000-8000-${String(i + 1).padStart(12, "0")}`,
    school_code: `v1-school-${id}`,
    school_name: name,
    display_order: i + 1,
  }));
  const mappings = schools.map((s, i) => ({
    source_system: "OPS_V1",
    object_type: "SCHOOL",
    legacy_id: ownerSchoolIdentityExpectations[i][0],
    school_id: s.school_id,
  }));
  return { schools, mappings };
}
test("rejects the verified stale v1-school-10 mapping and absent Hùng Vương before any configuration", () => {
  const f = fixture();
  f.schools.find((s) => s.school_code === "v1-school-10").school_name =
    "BÌNH QUỚI";
  assert.throws(
    () => buildSchoolDocumentConfiguration(f),
    /SCHOOL_MASTER_RECONCILIATION_REQUIRED/,
  );
  const missing = fixture();
  missing.schools = missing.schools.filter(
    (s) => s.school_code !== "v1-school-47",
  );
  assert.throws(
    () => buildSchoolDocumentConfiguration(missing),
    /SCHOOL_MASTER_RECONCILIATION_REQUIRED/,
  );
});
test("rejects missing, duplicate, or mismatched typed source identities without name fallback", () => {
  for (const mode of [
    "mapping_missing",
    "mapping_duplicate",
    "school_duplicate",
    "wrong_target",
  ]) {
    const f = fixture();
    if (mode === "mapping_missing") f.mappings.pop();
    if (mode === "mapping_duplicate") f.mappings.push({ ...f.mappings[0] });
    if (mode === "school_duplicate") f.schools.push({ ...f.schools[0] });
    if (mode === "wrong_target")
      f.mappings[0].school_id = f.schools[1].school_id;
    assert.throws(
      () => buildSchoolDocumentConfiguration(f),
      /SCHOOL_MASTER_RECONCILIATION_REQUIRED/,
    );
  }
});
test("generates only the three exact Owner Dispatch groups and excludes PH3", () => {
  const f = fixture();
  const p = buildSchoolDocumentConfiguration(f);
  assert.deepEqual(
    p.dispatch_groups.map((g) => [g.dispatch_group_name, g.school_ids.length]),
    [
      ["VĨNH TÂN", 2],
      ["CHUYÊN HÙNG VƯƠNG", 5],
      ["PHÚ HOÀ ĐÔNG 1", 3],
    ],
  );
  const ph3 = f.schools.find((s) => s.school_code === "v1-school-28").school_id;
  assert(!p.dispatch_groups.some((g) => g.school_ids.includes(ph3)));
  assert.equal(
    p.cooking_locations.find((g) => g.location_kind === "COMPANY")
      .host_school_id,
    null,
  );
  const pvc = p.cooking_locations.find(
    (g) => g.display_name === "PHẠM VĂN CỘI",
  );
  assert(pvc.school_ids.includes(pvc.host_school_id));
  assert.equal(pvc.school_ids.length, 2);
});
test("preserves canonical readback order for unrelated Schools sharing display_order", () => {
  const f = fixture();
  const a = {
    school_id: "10000000-0000-4000-8000-000000000002",
    school_code: "other-a",
    school_name: "A unrelated",
    display_order: 0,
  };
  const z = {
    school_id: "10000000-0000-4000-8000-000000000001",
    school_code: "other-z",
    school_name: "Z unrelated",
    display_order: 0,
  };
  f.schools.unshift(a, z);
  assert.deepEqual(
    buildSchoolDocumentConfiguration(f).target_school_order_ids.slice(0, 2),
    [a.school_id, z.school_id],
  );
});
test("places Bình Quới pair and all five Hùng Vương adjacent without changing unrelated relative order", () => {
  const f = fixture();
  // Deliberately interleave unrelated Schools and reverse the target members.
  f.schools.reverse().forEach((s, i) => (s.display_order = i * 10));
  const unrelated = [
    {
      school_id: "10000000-0000-4000-8000-000000000001",
      school_code: "other-a",
      school_name: "Z unrelated",
      display_order: 25,
    },
    {
      school_id: "10000000-0000-4000-8000-000000000002",
      school_code: "other-b",
      school_name: "A unrelated",
      display_order: 75,
    },
  ];
  f.schools.push(...unrelated);
  const original = [...f.schools].sort(
    (a, b) => a.display_order - b.display_order,
  );
  const result = buildSchoolDocumentConfiguration(f);
  const id = (code) =>
    f.schools.find((s) => s.school_code === `v1-school-${code}`).school_id;
  const order = result.target_school_order_ids;
  const bq = order.indexOf(id("52"));
  assert.equal(order[bq + 1], id("10"));
  const hv = ["47", "48", "49", "50", "53"].map(id);
  assert.deepEqual(
    order.slice(order.indexOf(hv[0]), order.indexOf(hv[0]) + 5),
    hv,
  );
  const targets = new Set([id("52"), id("10"), ...hv]);
  assert.deepEqual(
    order.filter((x) => !targets.has(x)),
    original.map((s) => s.school_id).filter((x) => !targets.has(x)),
  );
  // Vĩnh Tân order remains its original order; no name-derived adjacency.
  assert.equal(
    Math.sign(order.indexOf(id("40")) - order.indexOf(id("38"))),
    Math.sign(
      original.findIndex((s) => s.school_id === id("40")) -
        original.findIndex((s) => s.school_id === id("38")),
    ),
  );
});
