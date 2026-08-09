import { describe, expect, it, vi } from "vitest";
import type { AtlasRpcResult } from "../connection/atlasRpc";
import {
  attendanceCompletionRequest,
  createPlanningInputsApi,
  planningCommandRequest,
  planningReadRequest,
  weeklyMenuCompletionRequest,
} from "./planningInputsApi";

const success: AtlasRpcResult = {
  kind: "success",
  response: { success: true },
};

describe("RMVP-03A Planning inputs API adapter", () => {
  it("builds exact read and command envelopes", () => {
    expect(
      planningReadRequest("subject-1", "correlation-1", {
        week_start: "2026-08-03",
      }),
    ).toEqual({
      contract_version: "RMVP-03A.v1",
      requested_by_auth_subject: "subject-1",
      correlation_id: "correlation-1",
      payload: { week_start: "2026-08-03" },
    });
    const command = planningCommandRequest(
      "subject-1",
      "correlation-1",
      2,
      "WEEKLY_MENU_REOPEN",
      { week_start: "2026-08-03" },
      "Sửa thực đơn đã duyệt.",
    );
    expect(command).toMatchObject({
      contract_version: "RMVP-03A.v1",
      expected_version: 2,
      requested_by_auth_subject: "subject-1",
      reason_code: "WEEKLY_MENU_REOPEN",
      reason_note: "Sửa thực đơn đã duyệt.",
      payload: { week_start: "2026-08-03" },
    });
    expect(command.command_id).toBeTruthy();
    expect(command.idempotency_key).toContain("weekly_menu_reopen:");
  });

  it("routes all twelve reviewed API names without retry logic", async () => {
    const invoke = vi.fn().mockResolvedValue(success);
    const api = createPlanningInputsApi({ invoke });
    await api.getWorkbench("subject", "correlation", "2026-08-03");
    await api.previewMenu("subject", "correlation", "2026-08-03", []);
    await api.previewAttendance("subject", "correlation", "2026-08-03", []);
    const request = planningCommandRequest(
      "subject",
      "correlation",
      1,
      "TEST",
      { week_start: "2026-08-03" },
    );
    await api.saveMenu(request);
    await api.validateMenu(request);
    await api.approveMenu(request);
    await api.reopenMenu(request);
    await api.createAttendanceDefaults(request);
    await api.saveAttendance(request);
    await api.validateAttendance(request);
    await api.approveAttendance(request);
    await api.reopenAttendance(request);
    expect(invoke.mock.calls.map(([name]) => name)).toEqual([
      "atlas_api.get_planning_inputs_workbench",
      "atlas_api.preview_weekly_menu_import",
      "atlas_api.preview_attendance_import",
      "atlas_api.save_weekly_menu_draft",
      "atlas_api.validate_weekly_menu",
      "atlas_api.approve_weekly_menu",
      "atlas_api.reopen_weekly_menu",
      "atlas_api.create_attendance_draft_from_defaults",
      "atlas_api.save_attendance_draft",
      "atlas_api.validate_attendance",
      "atlas_api.approve_attendance",
      "atlas_api.reopen_attendance",
    ]);
  });

  it("builds and routes each RMVP-03A.v2 source completion as one RPC", async () => {
    const invoke = vi.fn().mockResolvedValue(success);
    const api = createPlanningInputsApi({ invoke });
    const menu = weeklyMenuCompletionRequest("subject", "correlation", 3, {
      week_start: "2026-08-03",
      source_type: "MANUAL",
      source_name: "Atlas",
      source_signature: "a".repeat(64),
      expected_source_signature: null,
      rows: [],
    });
    const attendance = attendanceCompletionRequest(
      "subject",
      "correlation",
      2,
      {
        week_start: "2026-08-03",
        source_type: "MANUAL",
        source_name: "Atlas",
        source_signature: "c".repeat(64),
        expected_source_signature: null,
        rows: [],
      },
    );

    await api.saveCompletedMenu(menu);
    await api.saveCompletedAttendance(attendance);

    expect(menu).toMatchObject({
      contract_version: "RMVP-03A.v2",
      expected_version: 3,
      reason_code: "WEEKLY_MENU_SAVED",
      payload: { expected_source_signature: null },
    });
    expect(attendance).toMatchObject({
      contract_version: "RMVP-03A.v2",
      expected_version: 2,
      reason_code: "ATTENDANCE_SAVED",
      payload: { expected_source_signature: null },
    });
    expect(invoke.mock.calls).toEqual([
      ["atlas_api.save_weekly_menu", menu],
      ["atlas_api.save_attendance", attendance],
    ]);
  });

  it("routes Google fetch through the one reviewed Edge Function without adding an RPC", async () => {
    const invoke = vi.fn().mockResolvedValue(success);
    const invokeEdgeFunction = vi.fn().mockResolvedValue(success);
    const api = createPlanningInputsApi({ invoke, invokeEdgeFunction });
    await api.syncMenuFromGoogle("source-1", "2026-08-03", "correlation-1");
    expect(invoke).not.toHaveBeenCalled();
    expect(invokeEdgeFunction).toHaveBeenCalledWith(
      "atlas-weekly-menu-google-sync",
      {
        weekly_menu_google_source_id: "source-1",
        week_start: "2026-08-03",
        correlation_id: "correlation-1",
      },
    );
  });
});
