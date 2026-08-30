import type { PlanningSchool } from "./planningInputsModel";

export type PlanningSchoolOption = Pick<
  PlanningSchool,
  "school_id" | "school_code" | "school_name" | "display_order"
>;

export function normalizePlanningSchoolScope(
  selectedIds: string[],
  schools: PlanningSchoolOption[],
) {
  const orderedIds = schools
    .slice()
    .sort(
      (a, b) =>
        a.display_order - b.display_order ||
        a.school_name.localeCompare(b.school_name, "vi"),
    )
    .map((school) => school.school_id);
  const allowed = new Set(orderedIds);
  const valid = Array.from(new Set(selectedIds)).filter((id) =>
    allowed.has(id),
  );
  if (valid.length === 0 || valid.length === orderedIds.length) return [];
  return orderedIds.filter((id) => valid.includes(id));
}

export function schoolInPlanningScope(schoolId: string, selectedIds: string[]) {
  return selectedIds.length === 0 || selectedIds.includes(schoolId);
}

export function planningSchoolScopeLabel(
  selectedIds: string[],
  schools: PlanningSchoolOption[],
) {
  if (!selectedIds.length) return "Tất cả trường";
  if (selectedIds.length === 1)
    return (
      schools.find((school) => school.school_id === selectedIds[0])
        ?.school_name ?? "1 trường"
    );
  return `${selectedIds.length} trường`;
}
