export type CanonicalSchoolOrder = {
  display_order?: number | null;
  school_name: string;
  school_id: string;
};

const schoolNameCollator = new Intl.Collator("vi");

/** Presentation only: configured master order, then name and stable identity. */
export function compareCanonicalSchools(
  left: CanonicalSchoolOrder,
  right: CanonicalSchoolOrder,
): number {
  const leftOrder = left.display_order ?? Number.POSITIVE_INFINITY;
  const rightOrder = right.display_order ?? Number.POSITIVE_INFINITY;
  if (leftOrder !== rightOrder) return leftOrder < rightOrder ? -1 : 1;
  return (
    schoolNameCollator.compare(left.school_name, right.school_name) ||
    (left.school_id < right.school_id
      ? -1
      : left.school_id > right.school_id
        ? 1
        : 0)
  );
}
