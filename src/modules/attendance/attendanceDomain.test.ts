import { describe, expect, it } from "vitest";
import {
  ApproveAttendance,
  EditAttendanceLine,
  ImportAttendance,
  MarkAttendanceUsedForNeedGeneration,
  ReopenAttendance,
  ValidateAttendance,
  type AttendanceImportRow,
} from "./attendanceDomain";

const references = { schoolIds: ["school-nguyen-du", "school-minh-an"] };
const at = "2026-07-13T08:00:00.000Z";
const validRow: AttendanceImportRow = {
  serviceDate: "2026-07-14",
  schoolId: "school-nguyen-du",
  studentPortions: 320,
  teacherPortions: 24,
  sourceRowRef: "Sheet1!A2",
};
function imported(rows = [validRow]) {
  return ImportAttendance(
    {
      attendanceBatchId: "attendance-29",
      periodStart: "2026-07-13",
      periodEnd: "2026-07-19",
      sourceType: "GOOGLE_SHEET",
      sourceName: "Week 29 attendance",
      sourceSignature: "attendance-29-v1",
      rows,
      actorId: "planner-lan",
      at,
    },
    references,
  ).batch;
}
function approved() {
  const validated = ValidateAttendance(
    imported(),
    references,
    "planner-lan",
    at,
  ).batch;
  return ApproveAttendance(validated, "manager-minh", at).batch;
}
function used() {
  return MarkAttendanceUsedForNeedGeneration(approved(), "planner-lan", at)
    .batch;
}

describe("Attendance domain", () => {
  it("creates Draft attendance lines from a valid import", () => {
    const batch = imported();
    expect(batch.status).toBe("DRAFT");
    expect(batch.lines[0]).toMatchObject({
      studentPortions: 320,
      teacherPortions: 24,
    });
    expect(batch.issues).toEqual([]);
  });
  it("creates a blocking issue for an unknown school", () => {
    const batch = imported([{ ...validRow, schoolId: "unknown" }]);
    expect(batch.issues.map((item) => item.issueCode)).toContain(
      "UNKNOWN_SCHOOL",
    );
    expect(batch.issues.every((item) => item.isBlocking)).toBe(true);
  });
  it("creates a blocking issue for a date outside the period", () => {
    const batch = imported([{ ...validRow, serviceDate: "2026-07-20" }]);
    expect(batch.issues.map((item) => item.issueCode)).toContain(
      "DATE_OUTSIDE_PERIOD",
    );
  });
  it("creates a blocking issue for duplicate school and date", () => {
    const batch = imported([
      validRow,
      { ...validRow, studentPortions: 100, sourceRowRef: "Sheet1!A3" },
    ]);
    expect(batch.issues.map((item) => item.issueCode)).toContain(
      "DUPLICATE_SCHOOL_DATE",
    );
  });
  it("blocks negative student portions", () => {
    expect(
      imported([{ ...validRow, studentPortions: -1 }]).issues.map(
        (item) => item.issueCode,
      ),
    ).toContain("NEGATIVE_STUDENT_PORTIONS");
  });
  it("blocks negative teacher portions", () => {
    expect(
      imported([{ ...validRow, teacherPortions: -1 }]).issues.map(
        (item) => item.issueCode,
      ),
    ).toContain("NEGATIVE_TEACHER_PORTIONS");
  });
  it("blocks approval while blocking issues exist", () => {
    const result = ApproveAttendance(
      imported([{ ...validRow, schoolId: "unknown" }]),
      "manager-minh",
      at,
    );
    expect(result.accepted).toBe(false);
  });
  it("does not allow an approved attendance batch to be edited", () => {
    const result = EditAttendanceLine(
      approved(),
      "attendance-29-line-1",
      validRow,
      "planner-lan",
      at,
    );
    expect(result.accepted).toBe(false);
  });
  it("does not allow used attendance to be edited", () => {
    const result = EditAttendanceLine(
      used(),
      "attendance-29-line-1",
      validRow,
      "planner-lan",
      at,
    );
    expect(result.accepted).toBe(false);
  });
  it("cannot demote approved attendance by validation", () => {
    const batch = approved();
    const result = ValidateAttendance(batch, references, "planner-lan", at);
    expect(result.accepted).toBe(false);
    expect(result.batch.status).toBe("APPROVED");
    expect(result.batch.changes).toEqual(batch.changes);
  });
  it("cannot demote used attendance by validation", () => {
    const batch = used();
    const result = ValidateAttendance(batch, references, "planner-lan", at);
    expect(result.accepted).toBe(false);
    expect(result.batch.status).toBe("USED_FOR_NEED_GENERATION");
    expect(result.batch.changes).toEqual(batch.changes);
  });
  it("preserves the reopen reason in change history", () => {
    const result = ReopenAttendance(
      approved(),
      "Corrected school attendance",
      "manager-minh",
      at,
    );
    expect(result.accepted).toBe(true);
    expect(result.batch.changes.at(-1)).toMatchObject({
      type: "AttendanceReopened",
      reason: "Corrected school attendance",
    });
  });
  it("only allows handoff from Approved", () => {
    expect(
      MarkAttendanceUsedForNeedGeneration(imported(), "planner-lan", at)
        .accepted,
    ).toBe(false);
    expect(used().status).toBe("USED_FOR_NEED_GENERATION");
  });
});
