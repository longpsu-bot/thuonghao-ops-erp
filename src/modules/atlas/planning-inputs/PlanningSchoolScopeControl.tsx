import { useMemo, useState } from "react";
import { Button, Checkbox, Popover, TextInput } from "@mantine/core";
import {
  normalizePlanningSchoolScope,
  planningSchoolScopeLabel,
  type PlanningSchoolOption,
} from "./planningSchoolScope";

type PlanningSchoolScopeControlProps = {
  schools: PlanningSchoolOption[];
  selectedSchoolIds: string[];
  onChange: (ids: string[]) => void;
};

function foldSearch(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .toLocaleLowerCase("vi");
}

export function PlanningSchoolScopeControl({
  schools,
  selectedSchoolIds,
  onChange,
}: PlanningSchoolScopeControlProps) {
  const [search, setSearch] = useState("");
  const orderedSchools = useMemo(
    () =>
      schools
        .slice()
        .sort(
          (a, b) =>
            a.display_order - b.display_order ||
            a.school_name.localeCompare(b.school_name, "vi"),
        ),
    [schools],
  );
  const normalizedSelection = normalizePlanningSchoolScope(
    selectedSchoolIds,
    orderedSchools,
  );
  const selected = new Set(
    normalizedSelection.length
      ? normalizedSelection
      : orderedSchools.map((school) => school.school_id),
  );
  const query = foldSearch(search.trim());
  const visibleSchools = orderedSchools.filter((school) =>
    foldSearch(`${school.school_code} ${school.school_name}`).includes(query),
  );

  const toggleSchool = (schoolId: string, checked: boolean) => {
    const next = new Set(selected);
    if (checked) next.add(schoolId);
    else next.delete(schoolId);
    onChange(normalizePlanningSchoolScope(Array.from(next), orderedSchools));
  };

  return (
    <Popover position="bottom-start" width={360} withinPortal={false}>
      <Popover.Target>
        <Button
          type="button"
          variant="outline"
          aria-label="Phạm vi trường"
          className="planning-school-scope-control"
        >
          {planningSchoolScopeLabel(normalizedSelection, orderedSchools)}
        </Button>
      </Popover.Target>
      <Popover.Dropdown>
        <TextInput
          label="Tìm trường"
          value={search}
          onChange={(event) => setSearch(event.currentTarget.value)}
          placeholder="Mã hoặc tên trường"
        />
        <Button type="button" variant="subtle" onClick={() => onChange([])}>
          Chọn tất cả
        </Button>
        <div className="planning-school-scope-options">
          {visibleSchools.map((school) => (
            <Checkbox
              key={school.school_id}
              label={`${school.school_code} · ${school.school_name}`}
              checked={selected.has(school.school_id)}
              onChange={(event) =>
                toggleSchool(school.school_id, event.currentTarget.checked)
              }
            />
          ))}
        </div>
      </Popover.Dropdown>
    </Popover>
  );
}
