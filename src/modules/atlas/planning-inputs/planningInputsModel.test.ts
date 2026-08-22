import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import type { AtlasRpcResult } from "../connection/atlasRpc";
import {
  attendanceReviewChanges,
  attendanceNeedsConfirmation,
  attendanceWorkingRows,
  fuzzyTextMatch,
  menuReviewChanges,
  mondayOf,
  planningPreviewFromResult,
  planningResultMessage,
  viDate,
} from "./planningInputsModel";

describe("Planning input model", () => {
  beforeAll(() => {
    vi.stubEnv("TZ", "Asia/Ho_Chi_Minh");
  });

  afterAll(() => {
    vi.unstubAllEnvs();
  });

  it("maps an ordinary local weekday to its Monday", () => {
    expect(mondayOf(new Date(2026, 7, 6, 10))).toBe("2026-08-03");
  });

  it("maps local Sunday back to the preceding Monday", () => {
    expect(mondayOf(new Date(2026, 7, 9, 12))).toBe("2026-08-03");
  });

  it("preserves an early-morning local Monday across UTC rollover", () => {
    expect(mondayOf(new Date(2026, 7, 9, 0, 30))).toBe("2026-08-03");
  });

  it("returns a zero-padded YYYY-MM-DD date", () => {
    expect(mondayOf(new Date(2026, 0, 7, 10))).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it("formats Vietnamese dates", () => {
    expect(viDate("2026-08-03")).toBe("03/08/2026");
  });

  it("parses a canonical preview and identifies stale source evidence", () => {
    const result: AtlasRpcResult = {
      kind: "success",
      response: {
        success: true,
        preview: {
          week_start: "2026-08-03",
          week_end: "2026-08-09",
          canonical_rows: [],
          source_signature: "checksum",
          row_count: 0,
          issues: { blockers: [], warnings: [] },
          can_save: true,
        },
      },
    };
    expect(planningPreviewFromResult(result)?.source_signature).toBe(
      "checksum",
    );
    expect(
      planningResultMessage({
        kind: "backend_error",
        error: {
          success: false,
          error_code: "STALE_SOURCE_SIGNATURE",
          safe_message: "safe",
        },
      }),
    ).toContain("Nguồn dữ liệu đã thay đổi");
    expect(
      planningResultMessage({
        kind: "backend_error",
        error: {
          success: false,
          error_code: "VALIDATION_FAILED",
          safe_message: "safe",
          field_errors: [
            { field: "requested_at", message: "bounded clock skew" },
          ],
        },
      }),
    ).toMatch(/Thời gian trên thiết bị/);
  });

  it("uses persisted Attendance for matching pairs and defaults only for missing pairs", () => {
    const defaults = [
      {
        school_id: "school-a",
        service_date: "2026-08-03",
        student_portions: 500,
        teacher_portions: 20,
        source_row_reference: null,
      },
      {
        school_id: "school-b",
        service_date: "2026-08-03",
        student_portions: 400,
        teacher_portions: 15,
        source_row_reference: null,
      },
    ];
    const working = attendanceWorkingRows(
      {
        attendance_batch_id: "attendance",
        period_start: "2026-08-03",
        period_end: "2026-08-09",
        source_type: "MANUAL",
        source_name: "Atlas",
        source_signature: "signature",
        attendance_status: "DRAFT",
        row_count: 1,
        version: 1,
        latest_approved_at: null,
        latest_approval_snapshot_id: null,
        lines: [
          {
            school_id: "school-a",
            service_date: "2026-08-03",
            student_portions: 0,
            teacher_portions: 18,
            source_row_reference: null,
          },
        ],
        issues: { blockers: [], warnings: [] },
        change_history: [],
        approval_history: [],
      },
      defaults,
    );

    expect(working).toEqual([
      expect.objectContaining({
        school_id: "school-a",
        student_portions: 0,
        teacher_portions: 18,
      }),
      expect.objectContaining({
        school_id: "school-b",
        student_portions: 400,
        teacher_portions: 15,
      }),
    ]);
  });

  it("requires confirmation only when a displayed default pair is not persisted", () => {
    const defaults = [
      {
        school_id: "school-a",
        service_date: "2026-08-03",
        student_portions: 500,
        teacher_portions: 20,
        source_row_reference: null,
      },
      {
        school_id: "school-b",
        service_date: "2026-08-03",
        student_portions: 400,
        teacher_portions: 15,
        source_row_reference: null,
      },
    ];
    const attendance = {
      attendance_batch_id: "attendance",
      period_start: "2026-08-03",
      period_end: "2026-08-09",
      source_type: "MANUAL",
      source_name: "Atlas",
      source_signature: "signature",
      attendance_status: "APPROVED" as const,
      row_count: 1,
      version: 1,
      latest_approved_at: null,
      latest_approval_snapshot_id: null,
      lines: [
        {
          school_id: "school-a",
          service_date: "2026-08-03",
          student_portions: 0,
          teacher_portions: 18,
          source_row_reference: null,
        },
      ],
      issues: { blockers: [], warnings: [] },
      change_history: [],
      approval_history: [],
    };

    expect(attendanceNeedsConfirmation(attendance, [defaults[0]!])).toBe(false);
    expect(attendanceNeedsConfirmation(attendance, defaults)).toBe(true);
    expect(
      attendanceNeedsConfirmation(attendance, [defaults[0]!, defaults[0]!]),
    ).toBe(false);

    attendance.lines.push({ ...defaults[1]!, student_portions: 0 });
    expect(attendanceNeedsConfirmation(attendance, defaults)).toBe(false);
  });

  it("derives human-readable Menu and Attendance differences from canonical rows", () => {
    expect(
      menuReviewChanges(
        [
          {
            school_id: "school-a",
            service_date: "2026-08-03",
            menu_slot_code: "soup",
            dish_id: "dish-before",
            source_row_reference: null,
          },
        ],
        [
          {
            school_id: "school-a",
            service_date: "2026-08-03",
            menu_slot_code: "soup",
            dish_id: "dish-after",
            source_row_reference: null,
          },
        ],
      ),
    ).toEqual([
      expect.objectContaining({
        previous_dish_id: "dish-before",
        proposed_dish_id: "dish-after",
      }),
    ]);
    expect(
      attendanceReviewChanges(
        [
          {
            school_id: "school-a",
            service_date: "2026-08-03",
            student_portions: 500,
            teacher_portions: 20,
            source_row_reference: null,
          },
        ],
        [
          {
            school_id: "school-a",
            service_date: "2026-08-03",
            student_portions: 0,
            teacher_portions: 21,
            source_row_reference: null,
          },
        ],
      ),
    ).toEqual([
      expect.objectContaining({
        previous_student_portions: 500,
        proposed_student_portions: 0,
        previous_teacher_portions: 20,
        proposed_teacher_portions: 21,
      }),
    ]);
  });

  it("matches School search without accents and with compact fuzzy input", () => {
    expect(
      fuzzyTextMatch("ngyn du", "TH001", "Trường Tiểu học Nguyễn Du"),
    ).toBe(true);
    expect(fuzzyTextMatch("th002", "TH002", "Trường Trần Quốc Toản")).toBe(
      true,
    );
    expect(fuzzyTextMatch("hoa hong", "TH003", "Mầm non Hoa Hồng")).toBe(true);
  });
});
