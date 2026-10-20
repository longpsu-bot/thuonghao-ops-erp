// Certification projections only. Draft overlap is generated; released coverage
// is checked separately, with exact line/source identities, by the browser gate.
import assert from "node:assert/strict";

const sorted = (rows) =>
  rows.sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b)));
const ticks = (value) => {
  assert(
    /^\d+(?:\.\d{1,6})?$/.test(String(value)),
    "Exact decimal quantity required.",
  );
  const [whole, fraction = ""] = String(value).split(".");
  return BigInt(whole) * 1000000n + BigInt(fraction.padEnd(6, "0"));
};
export const supplierQuantityFootprint = (orders) =>
  sorted(
    orders.map((order) => ({
      id: order.purchase_order_id,
      supplier: order.supplier.supplier_id,
      date: order.service_date,
      lines: sorted(
        order.lines.map((line) => ({
          ingredient: line.ingredient.ingredient_id,
          unit: line.unit.unit_id,
          location: line.delivery_location.delivery_location_id,
          family: line.source.family_id,
          quantity: ticks(line.ordered_quantity).toString(),
        })),
      ),
    })),
  );

export function schoolQuantityFootprint(orders, schoolsByLine) {
  const totals = new Map();
  for (const order of orders)
    for (const line of order.lines) {
      const schools = schoolsByLine[line.purchase_order_line_id];
      assert(
        Array.isArray(schools) && schools.length > 0,
        "Complete School coverage required.",
      );
      for (const school of schools) {
        const scope = {
          date: order.service_date,
          school: school.school_id,
          location: school.delivery_location_id,
          ingredient: line.ingredient.ingredient_id,
          unit: line.unit.unit_id,
          family: line.source.family_id,
        };
        const key = JSON.stringify(scope);
        const previous = totals.get(key);
        totals.set(key, {
          scope,
          quantity: (previous?.quantity ?? 0n) + ticks(school.ordered_quantity),
        });
      }
    }
  return sorted(
    [...totals.values()].map(({ scope, quantity }) => ({
      ...scope,
      quantity: quantity.toString(),
    })),
  );
}
