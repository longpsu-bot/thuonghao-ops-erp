import { SchoolScopeSelector } from "../SchoolScopeSelector";
import type { PlanningSchoolOption } from "./planningSchoolScope";

type PlanningSchoolScopeControlProps = {
  schools: PlanningSchoolOption[];
  selectedSchoolIds: string[];
  onChange: (ids: string[]) => void;
};

export function PlanningSchoolScopeControl({
  schools,
  selectedSchoolIds,
  onChange,
}: PlanningSchoolScopeControlProps) {
  return (
    <SchoolScopeSelector
      id="planning-school-scope"
      className="planning-school-scope-control"
      schools={schools}
      selectedSchoolIds={selectedSchoolIds}
      onChange={onChange}
    />
  );
}
