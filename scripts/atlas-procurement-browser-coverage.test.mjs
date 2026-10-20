// @vitest-environment node
import assert from "node:assert/strict";
import { test } from "vitest";
import {
  supplierQuantityFootprint,
  schoolQuantityFootprint,
} from "./atlas-procurement-browser-coverage.mjs";

const order = (supplier, quantity) => ({
  purchase_order_id: `po-${supplier}`,
  supplier: { supplier_id: supplier },
  service_date: "2050-09-19",
  lines: [
    {
      purchase_order_line_id: `line-${supplier}`,
      ingredient: { ingredient_id: "ingredient" },
      unit: { unit_id: "unit" },
      delivery_location: { delivery_location_id: "location" },
      source: { family_id: "family" },
      ordered_quantity: quantity,
    },
  ],
});
const school = (id, quantity) => ({
  school_id: id,
  delivery_location_id: "location",
  ordered_quantity: quantity,
});

test("Draft regeneration preserves both explicit marginals while generated supplier/School overlaps may move", () => {
  const orders = [order("a", "30.000000"), order("b", "18.000000")];
  const before = {
    "line-a": [school("one", "30")],
    "line-b": [school("two", "18")],
  };
  const after = {
    "line-a": [school("one", "12"), school("two", "18")],
    "line-b": [school("one", "18")],
  };
  const regenerated = structuredClone(orders).reverse();
  regenerated.forEach((po) => {
    po.lines[0].purchase_order_line_id += "-new";
  });
  const newCoverage = Object.fromEntries(
    Object.entries(after).map(([id, rows]) => [id + "-new", rows]),
  );
  assert.deepEqual(
    supplierQuantityFootprint(regenerated),
    supplierQuantityFootprint(orders),
  );
  assert.deepEqual(
    schoolQuantityFootprint(regenerated, newCoverage),
    schoolQuantityFootprint(orders, before),
  );
  regenerated[0].lines[0].ordered_quantity = "19";
  assert.notDeepEqual(
    supplierQuantityFootprint(regenerated),
    supplierQuantityFootprint(orders),
  );
  newCoverage["line-a-new"][0].ordered_quantity = "13";
  assert.notDeepEqual(
    schoolQuantityFootprint(regenerated, newCoverage),
    schoolQuantityFootprint(orders, before),
  );
});

test("School quantity projection retains exact decimals and all source scope dimensions", () => {
  const orders = [order("a", "99999999999999.000001")];
  const rows = { "line-a": [school("one", "99999999999999.000001")] };
  const expected = schoolQuantityFootprint(orders, rows);
  assert.equal(expected[0].quantity, "99999999999999000001");
  for (const mutate of [
    (po) => {
      po.service_date = "2050-09-20";
    },
    (po) => {
      po.lines[0].ingredient.ingredient_id = "other";
    },
    (po) => {
      po.lines[0].unit.unit_id = "other";
    },
    (po) => {
      po.lines[0].source.family_id = "other";
    },
  ]) {
    const changed = structuredClone(orders);
    mutate(changed[0]);
    assert.notDeepEqual(schoolQuantityFootprint(changed, rows), expected);
  }
  for (const field of [
    "school_id",
    "delivery_location_id",
    "ordered_quantity",
  ]) {
    const changed = structuredClone(rows);
    changed["line-a"][0][field] =
      field === "ordered_quantity" ? "99999999999999.000002" : "other";
    assert.notDeepEqual(schoolQuantityFootprint(orders, changed), expected);
  }
  assert.throws(() => schoolQuantityFootprint(orders, {}));
});
