import type { AllocationFamilyRow } from "../bridges/procurement";
import { compareCanonicalSchools } from "../canonicalSchoolOrder";
import { compareAtlasText } from "../atlasTableSort";
import { parseExactQuantity } from "./procurementExactQuantity";

export function derivedDefaultAllocation(row: AllocationFamilyRow) {
  const quantity = parseExactQuantity(row.family_quantity ?? "");
  const recommendation = row.recommendation;
  if (
    row.state !== "UNALLOCATED" ||
    row.complete !== true ||
    row.splits.length > 0 ||
    row.blockers.length > 0 ||
    quantity === null ||
    quantity <= 0n ||
    !recommendation ||
    parseExactQuantity(recommendation.allocated_quantity) !== quantity
  )
    return null;

  const supplier = row.eligible_suppliers.find(
    (candidate) => candidate.supplier_id === recommendation.supplier_id,
  );
  return supplier ? { recommendation, supplier } : null;
}

export function allocationSchools(row: AllocationFamilyRow) {
  return (
    row.schools ??
    (row.school_id && row.school_name
      ? [
          {
            school_id: row.school_id,
            school_name: row.school_name,
            display_order: row.display_order,
          },
        ]
      : [])
  )
    .slice()
    .sort(compareCanonicalSchools);
}

export function allocationRecipient(row: AllocationFamilyRow) {
  const schools = allocationSchools(row);
  const primary =
    schools.map((school) => school.school_name).join(", ") || row.location_name;
  const secondary =
    row.location_name.trim() && primary.trim() !== row.location_name.trim()
      ? row.location_name
      : null;
  return { primary, secondary, schools };
}

export function compareAllocationRecipients(
  left: AllocationFamilyRow,
  right: AllocationFamilyRow,
) {
  const leftSchool = allocationSchools(left)[0];
  const rightSchool = allocationSchools(right)[0];
  if (leftSchool && rightSchool)
    return compareCanonicalSchools(leftSchool, rightSchool);
  if (leftSchool || rightSchool) return leftSchool ? -1 : 1;
  return compareAtlasText(left.location_name, right.location_name);
}
