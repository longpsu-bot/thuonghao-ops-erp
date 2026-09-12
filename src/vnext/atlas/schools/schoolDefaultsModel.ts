import { foldVietnameseSearch } from "../foldVietnameseSearch";
import type { SchoolMasterData } from "../bridges/schoolMasterData";

export const MAX_PORTION_COUNT = 2_147_483_647;

export type SchoolDefaultsDraft = {
  student: string;
  teacher: string;
};

export type SchoolDefaultsDrafts = Record<string, SchoolDefaultsDraft>;

export type SchoolDefaultsReviewRow = {
  school_id: string;
  school_code: string;
  school_name: string;
  expected_version: number;
  current_student_portions: number;
  new_student_portions: number;
  current_teacher_portions: number;
  new_teacher_portions: number;
};

export function parsePortionDraft(value: string): number | null {
  const normalized = value.trim();
  if (!/^\d+$/.test(normalized)) return null;
  const parsed = Number(normalized);
  return Number.isSafeInteger(parsed) && parsed <= MAX_PORTION_COUNT
    ? parsed
    : null;
}

function draftMatchesAuthority(
  draft: SchoolDefaultsDraft,
  school: SchoolMasterData,
) {
  return (
    parsePortionDraft(draft.student) === school.default_student_portions &&
    parsePortionDraft(draft.teacher) === school.default_teacher_portions
  );
}

export function reconcileSchoolDrafts(
  drafts: SchoolDefaultsDrafts,
  schools: readonly SchoolMasterData[],
): SchoolDefaultsDrafts {
  const authority = new Map(
    schools.map((school) => [school.school_id, school]),
  );
  return Object.fromEntries(
    Object.entries(drafts).filter(([schoolId, draft]) => {
      const school = authority.get(schoolId);
      return school ? !draftMatchesAuthority(draft, school) : false;
    }),
  );
}

export function applySchoolDraftEdit(
  drafts: SchoolDefaultsDrafts,
  school: SchoolMasterData,
  field: keyof SchoolDefaultsDraft,
  value: string,
): SchoolDefaultsDrafts {
  const nextDraft = {
    ...(drafts[school.school_id] ?? {
      student: String(school.default_student_portions),
      teacher: String(school.default_teacher_portions),
    }),
    [field]: value,
  };
  const next = { ...drafts };
  if (draftMatchesAuthority(nextDraft, school)) delete next[school.school_id];
  else next[school.school_id] = nextDraft;
  return next;
}

export function countInvalidDraftSchools(drafts: SchoolDefaultsDrafts) {
  return Object.values(drafts).filter(
    (draft) =>
      parsePortionDraft(draft.student) === null ||
      parsePortionDraft(draft.teacher) === null,
  ).length;
}

export function countHiddenDraftSchools(
  drafts: SchoolDefaultsDrafts,
  visibleSchools: readonly SchoolMasterData[],
) {
  const visibleIds = new Set(visibleSchools.map((school) => school.school_id));
  return Object.keys(drafts).filter((schoolId) => !visibleIds.has(schoolId))
    .length;
}

export function filterAndOrderSchools(
  schools: readonly SchoolMasterData[],
  query: string,
  schoolType: string,
): SchoolMasterData[] {
  const foldedQuery = foldVietnameseSearch(query.trim());
  return schools
    .filter((school) => {
      if (schoolType !== "ALL" && school.school_type_name !== schoolType)
        return false;
      if (!foldedQuery) return true;
      return [
        school.school_name,
        school.school_code,
        school.school_type_name,
        school.customer_name,
        school.delivery_location_name,
        school.delivery_address,
      ].some((value) =>
        foldVietnameseSearch(value ?? "").includes(foldedQuery),
      );
    })
    .sort(
      (left, right) =>
        left.display_order - right.display_order ||
        left.school_name.localeCompare(right.school_name, "vi"),
    );
}

export function createSchoolDefaultsReview(
  schools: readonly SchoolMasterData[],
  drafts: SchoolDefaultsDrafts,
): SchoolDefaultsReviewRow[] | null {
  const rows: SchoolDefaultsReviewRow[] = [];
  for (const school of filterAndOrderSchools(schools, "", "ALL")) {
    const draft = drafts[school.school_id];
    if (!draft) continue;
    const student = parsePortionDraft(draft.student);
    const teacher = parsePortionDraft(draft.teacher);
    if (student === null || teacher === null) return null;
    rows.push({
      school_id: school.school_id,
      school_code: school.school_code,
      school_name: school.school_name,
      expected_version: school.version,
      current_student_portions: school.default_student_portions,
      new_student_portions: student,
      current_teacher_portions: school.default_teacher_portions,
      new_teacher_portions: teacher,
    });
  }
  return rows.length === Object.keys(drafts).length ? rows : null;
}
