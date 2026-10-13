import { describe, expect, it } from "vitest";
import { createHash } from "node:crypto";
import {
  assertReadAcceptance,
  postgresJsonbText,
  assertSnapshotsEqual,
} from "./atlas-procurement-cutover.mjs";

const row = (i) => ({
  complete: true,
  state: "BALANCED",
  service_date: "2026-10-12",
  delivery_location_id: "location-" + i,
  ingredient_id: "ingredient",
  unit_id: "unit",
  family_quantity: "1.000000",
  source_purchase_handoff_revision_id: "handoff",
  family: {
    family_id: "family-" + String(i).padStart(3, "0"),
    source_kind: "PURCHASE_HANDOFF",
    source_confirmed_need_batch_id: "69661e86-abb3-4bf4-88a5-4717fe18c472",
    source_confirmed_need_batch_version: 5,
  },
  splits: [
    {
      supplier_id: "supplier",
      allocated_quantity: "1.000000",
      supplier_note: null,
    },
  ],
  contributions: [
    {
      school_id: "school",
      purchase_handoff_line_id: "line",
      contribution_quantity: "1.000000",
    },
  ],
});
const response = () => ({
  success: true,
  rows: Array.from({ length: 236 }, (_, i) => row(i)),
  preparation: {
    service_date: "2026-10-12",
    confirmed_need_batch_id: "69661e86-abb3-4bf4-88a5-4717fe18c472",
    expected_version: 5,
    ready: true,
    allowed: true,
    blockers: [],
  },
});
const digest = (r) =>
  createHash("md5")
    .update(
      postgresJsonbText(
        r.rows.toSorted((a, b) =>
          a.family.family_id.localeCompare(b.family.family_id),
        ),
      ),
    )
    .digest("hex");
const expected = (r) => ({
  rows_md5: digest(r),
  families: r.rows.map((x) => x.family.family_id),
});

describe("released hosted acceptance gates", () => {
  it("matches PostgreSQL jsonb canonical order and spacing", () => {
    expect(
      postgresJsonbText({ long_key: "á", z: 1, aa: [true, null], a: "x" }),
    ).toBe('{"a": "x", "z": 1, "aa": [true, null], "long_key": "á"}');
  });
  it("accepts exact response regardless of transport object-key and row order", () => {
    const r = response(),
      e = expected(r);
    r.rows.reverse();
    expect(() =>
      assertReadAcceptance(
        { http_status: 200, elapsed_ms: 3100, response: r },
        e,
      ),
    ).not.toThrow();
  });
  for (const [label, change] of [
    ["quantity", (r) => (r.rows[0].family_quantity = "2.000000")],
    ["Supplier note", (r) => (r.rows[0].splits[0].supplier_note = "changed")],
    [
      "contribution lineage",
      (r) => (r.rows[0].contributions[0].purchase_handoff_line_id = "other"),
    ],
    ["duplicate identity", (r) => (r.rows[0] = structuredClone(r.rows[1]))],
    ["authority", (r) => (r.rows[0].family.source_kind = "CONFIRMED_NEED")],
    ["completeness", (r) => (r.rows[0].complete = false)],
    ["preparation version", (r) => (r.preparation.expected_version = 4)],
  ])
    it("rejects " + label + " corruption without relying on count", () => {
      const r = response(),
        e = expected(r);
      change(r);
      expect(() =>
        assertReadAcceptance(
          { http_status: 200, elapsed_ms: 3100, response: r },
          e,
        ),
      ).toThrow();
    });
  it("rejects 8 seconds and non-200 business results", () => {
    const r = response(),
      e = expected(r);
    expect(() =>
      assertReadAcceptance(
        { http_status: 200, elapsed_ms: 8000, response: r },
        e,
      ),
    ).toThrow();
    expect(() =>
      assertReadAcceptance(
        { http_status: 504, elapsed_ms: 2000, response: r },
        e,
      ),
    ).toThrow();
  });
  it("rejects a receipt mutation even when fact counts are unchanged", () => {
    expect(() =>
      assertSnapshotsEqual(
        {
          facts: { count: 1, digest: "same" },
          receipts: { count: 1, digest: "old" },
        },
        {
          facts: { count: 1, digest: "same" },
          receipts: { count: 1, digest: "new" },
        },
      ),
    ).toThrow();
  });
});
