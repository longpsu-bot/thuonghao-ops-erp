import { foldVietnameseSearch } from "../foldVietnameseSearch";
import { compareCanonicalSchools } from "../canonicalSchoolOrder";
import type {
  SchoolMasterData,
  WeekdayPortionDefaults,
} from "../bridges/schoolMasterData";

export const MAX_PORTION_COUNT = 2_147_483_647;

export type SchoolDefaultsDraft = {
  student: string;
  teacher: string;
  weekdays?: Partial<Record<Weekday, { student: string; teacher: string }>>;
};

export const SCHOOL_WEEKDAYS = ["1", "2", "3", "4", "5"] as const;
export type Weekday = (typeof SCHOOL_WEEKDAYS)[number];

export type SchoolDefaultsDrafts = Record<string, SchoolDefaultsDraft>;

export type SchoolDefaultsReviewRow = {
  new_weekday_portion_defaults?: WeekdayPortionDefaults;
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
    parsePortionDraft(draft.teacher) === school.default_teacher_portions &&
    (!draft.weekdays ||
      JSON.stringify(parseWeekdays(draft)) ===
        JSON.stringify(
          parseWeekdays({
            student: "",
            teacher: "",
            weekdays: schoolWeekdayDrafts(school),
          }),
        ))
  );
}

export function schoolWeekdayDrafts(school: SchoolMasterData) {
  return Object.fromEntries(
    SCHOOL_WEEKDAYS.map((day) => [
      day,
      {
        student: String(
          school.weekday_portion_defaults?.[day]?.student_portions ?? "",
        ),
        teacher: String(
          school.weekday_portion_defaults?.[day]?.teacher_portions ?? "",
        ),
      },
    ]),
  ) as Record<Weekday, { student: string; teacher: string }>;
}

function parseWeekdays(
  draft: SchoolDefaultsDraft,
): WeekdayPortionDefaults | null {
  const result: WeekdayPortionDefaults = {};
  for (const day of SCHOOL_WEEKDAYS) {
    const values = draft.weekdays?.[day];
    if (!values) continue;
    const portions: { student_portions?: number; teacher_portions?: number } =
      {};
    for (const field of ["student", "teacher"] as const) {
      if (!values[field].trim()) continue;
      const count = parsePortionDraft(values[field]);
      if (count === null) return null;
      portions[`${field}_portions`] = count;
    }
    if (Object.keys(portions).length) result[day] = portions;
  }
  return result;
}

export function applySchoolWeekdayDraftEdit(
  drafts: SchoolDefaultsDrafts,
  school: SchoolMasterData,
  day: Weekday,
  field: "student" | "teacher",
  value: string,
): SchoolDefaultsDrafts {
  const current = drafts[school.school_id] ?? {
    student: String(school.default_student_portions),
    teacher: String(school.default_teacher_portions),
  };
  const weekdays = current.weekdays ?? schoolWeekdayDrafts(school);
  const draft = {
    ...current,
    weekdays: { ...weekdays, [day]: { ...weekdays[day], [field]: value } },
  };
  const next = { ...drafts, [school.school_id]: draft };
  if (draftMatchesAuthority(draft, school)) delete next[school.school_id];
  return next;
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
      parsePortionDraft(draft.teacher) === null ||
      parseWeekdays(draft) === null,
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
    .sort(compareCanonicalSchools);
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
    const weekdays = parseWeekdays(draft);
    if (student === null || teacher === null || weekdays === null) return null;
    rows.push({
      ...(draft.weekdays ? { new_weekday_portion_defaults: weekdays } : {}),
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
