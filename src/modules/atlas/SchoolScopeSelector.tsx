import { useEffect, useId, useMemo, useState } from "react";

export type SchoolScopeOption = {
  school_id: string;
  school_code?: string;
  school_name: string;
  display_order?: number;
};

type SchoolScopeSelectorProps = {
  id?: string;
  schools: SchoolScopeOption[];
  selectedSchoolIds: string[];
  onChange: (ids: string[]) => void;
  className?: string;
};

function foldSearch(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .toLocaleLowerCase("vi");
}

function orderedOptions(schools: SchoolScopeOption[]) {
  return schools
    .slice()
    .sort(
      (left, right) =>
        (left.display_order ?? Number.MAX_SAFE_INTEGER) -
          (right.display_order ?? Number.MAX_SAFE_INTEGER) ||
        left.school_name.localeCompare(right.school_name, "vi"),
    );
}

function normalizedCommittedIds(
  selectedSchoolIds: string[],
  schools: SchoolScopeOption[],
) {
  const orderedIds = schools.map((school) => school.school_id);
  const allowed = new Set(orderedIds);
  const valid = new Set(selectedSchoolIds.filter((id) => allowed.has(id)));
  if (!valid.size || valid.size === orderedIds.length) return [];
  return orderedIds.filter((id) => valid.has(id));
}

function selectionLabel(ids: string[], schools: SchoolScopeOption[]) {
  if (!ids.length) return "Tất cả trường";
  if (ids.length === 1)
    return (
      schools.find((school) => school.school_id === ids[0])?.school_name ??
      "1 trường"
    );
  return `${ids.length} trường`;
}

export function SchoolScopeSelector({
  id,
  schools,
  selectedSchoolIds,
  onChange,
  className,
}: SchoolScopeSelectorProps) {
  const generatedId = useId();
  const controlId = id ?? `school-scope-${generatedId}`;
  const dropdownId = `${controlId}-options`;
  const [search, setSearch] = useState("");
  const [opened, setOpened] = useState(false);
  const orderedSchools = useMemo(() => orderedOptions(schools), [schools]);
  const committedIds = normalizedCommittedIds(
    selectedSchoolIds,
    orderedSchools,
  );
  const expandedCommittedIds = committedIds.length
    ? committedIds
    : orderedSchools.map((school) => school.school_id);
  const committedKey = expandedCommittedIds.join("|");
  const [draftIds, setDraftIds] = useState(expandedCommittedIds);

  useEffect(() => {
    if (!opened) setDraftIds(expandedCommittedIds);
  }, [committedKey, opened]);

  const selected = new Set(draftIds);
  const query = foldSearch(search.trim());
  const visibleSchools = orderedSchools.filter((school) =>
    foldSearch(`${school.school_code ?? ""} ${school.school_name}`).includes(
      query,
    ),
  );

  const setSchoolChecked = (schoolId: string, checked: boolean) => {
    const next = new Set(selected);
    if (checked) next.add(schoolId);
    else next.delete(schoolId);
    setDraftIds(
      orderedSchools
        .map((school) => school.school_id)
        .filter((orderedId) => next.has(orderedId)),
    );
  };

  const applyDraft = () => {
    if (!draftIds.length) return;
    onChange(normalizedCommittedIds(draftIds, orderedSchools));
    setOpened(false);
  };

  return (
    <div className={`school-scope-selector ${className ?? ""}`.trim()}>
      <button
        id={controlId}
        type="button"
        aria-label="Phạm vi trường"
        aria-expanded={opened}
        aria-controls={dropdownId}
        className="school-scope-trigger"
        onClick={() => {
          setOpened((value) => !value);
          if (!opened) {
            setSearch("");
            setDraftIds(expandedCommittedIds);
          }
        }}
      >
        <span>{selectionLabel(committedIds, orderedSchools)}</span>
        <span aria-hidden="true">⌄</span>
      </button>
      {opened && (
        <div
          id={dropdownId}
          className="school-scope-dropdown"
          role="dialog"
          aria-label="Chọn phạm vi trường"
        >
          <label>
            Tìm trường
            <input
              type="search"
              value={search}
              onChange={(event) => setSearch(event.currentTarget.value)}
              placeholder="Mã hoặc tên trường"
            />
          </label>
          <div className="school-scope-bulk-actions">
            <button
              type="button"
              onClick={() =>
                setDraftIds(orderedSchools.map((school) => school.school_id))
              }
            >
              Chọn tất cả
            </button>
            <button type="button" onClick={() => setDraftIds([])}>
              Bỏ chọn tất cả
            </button>
          </div>
          <div className="school-scope-options">
            {visibleSchools.map((school) => (
              <label key={school.school_id}>
                <input
                  type="checkbox"
                  checked={selected.has(school.school_id)}
                  onChange={(event) =>
                    setSchoolChecked(
                      school.school_id,
                      event.currentTarget.checked,
                    )
                  }
                />
                <span>
                  {school.school_code
                    ? `${school.school_code} · ${school.school_name}`
                    : school.school_name}
                </span>
              </label>
            ))}
          </div>
          {!draftIds.length && (
            <p className="school-scope-guidance" role="alert">
              Chọn ít nhất một trường
            </p>
          )}
          <div className="school-scope-footer">
            <button
              type="button"
              className="primary"
              disabled={!draftIds.length}
              onClick={applyDraft}
            >
              Áp dụng
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
