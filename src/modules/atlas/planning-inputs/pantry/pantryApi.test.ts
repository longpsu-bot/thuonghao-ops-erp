import { describe, expect, it, vi } from "vitest";
import type { AtlasRpcResult } from "../../connection/atlasRpc";
import {
  createPantryApi,
  pantryCompletionRequest,
  pantryCommandRequest,
  pantryReadRequest,
} from "./pantryApi";
import {
  pantryPreviewFromResult,
  pantryResultMessage,
  pantryWorkbenchFromResult,
} from "./pantryModel";

const success: AtlasRpcResult = {
  kind: "success",
  response: { success: true },
};

describe("PANTRY-02 API adapter", () => {
  it("builds the exact PANTRY-02 read and command envelopes", () => {
    expect(
      pantryReadRequest("subject-1", "correlation-1", {
        week_start: "2026-08-03",
      }),
    ).toEqual({
      contract_version: "PANTRY-02.v1",
      requested_by_auth_subject: "subject-1",
      correlation_id: "correlation-1",
      payload: { week_start: "2026-08-03" },
    });

    expect(
      pantryCommandRequest(
        "subject-1",
        "correlation-1",
        4,
        "PANTRY_REOPEN",
        {
          week_start: "2026-08-03",
          expected_source_signature: "a".repeat(64),
        },
        "Điều chỉnh lượng Pantry đã duyệt.",
      ),
    ).toMatchObject({
      contract_version: "PANTRY-02.v1",
      expected_version: 4,
      requested_by_auth_subject: "subject-1",
      reason_code: "PANTRY_REOPEN",
      reason_note: "Điều chỉnh lượng Pantry đã duyệt.",
      payload: {
        week_start: "2026-08-03",
        expected_source_signature: "a".repeat(64),
      },
    });
  });

  it("routes exactly the six reviewed Pantry APIs", async () => {
    const invoke = vi.fn().mockResolvedValue(success);
    const api = createPantryApi({ invoke });
    await api.getWorkbench("subject", "correlation", "2026-08-03");
    await api.preview("subject", "correlation", "2026-08-03", false, []);
    const command = pantryCommandRequest("subject", "correlation", 1, "TEST", {
      week_start: "2026-08-03",
    });
    await api.save(command);
    await api.validate(command);
    await api.approve(command);
    await api.reopen(command);

    expect(invoke.mock.calls.map(([name]) => name)).toEqual([
      "atlas_api.get_pantry_source_workbench",
      "atlas_api.preview_pantry_source",
      "atlas_api.save_pantry_draft",
      "atlas_api.validate_pantry",
      "atlas_api.approve_pantry",
      "atlas_api.reopen_pantry",
    ]);
  });

  it("builds PANTRY-02.v3 with explicit School/date modes and routes one consequential Save", async () => {
    const invoke = vi.fn().mockResolvedValue(success);
    const api = createPantryApi({ invoke });
    const request = pantryCompletionRequest("subject", "correlation", 4, {
      week_start: "2026-08-03",
      no_additions_confirmed: false,
      source_signature: "a".repeat(64),
      expected_source_signature: "b".repeat(64),
      rows: [],
      school_date_modes: [],
    });

    await api.saveCompleted(request);

    expect(request).toMatchObject({
      contract_version: "PANTRY-02.v3",
      expected_version: 4,
      reason_code: "PANTRY_SAVED",
    });
    expect(invoke.mock.calls).toEqual([["atlas_api.save_pantry", request]]);
  });

  it("sends explicit School/date composition authority with a v3 preview", async () => {
    const invoke = vi.fn().mockResolvedValue(success);
    const api = createPantryApi({ invoke });

    await api.preview(
      "subject",
      "correlation",
      "2026-08-03",
      false,
      [],
      [
        {
          school_id: "school-1",
          service_date: "2026-08-03",
          direct_need_mode: "COMPLETE",
        },
      ],
    );

    expect(invoke).toHaveBeenCalledWith(
      "atlas_api.preview_pantry_source",
      expect.objectContaining({
        contract_version: "PANTRY-02.v3",
        payload: expect.objectContaining({
          school_date_modes: [
            {
              school_id: "school-1",
              service_date: "2026-08-03",
              direct_need_mode: "COMPLETE",
            },
          ],
        }),
      }),
    );
  });

  it("parses only authoritative success payloads and preserves safe errors", () => {
    const workbenchResult: AtlasRpcResult = {
      kind: "success",
      response: {
        success: true,
        workbench: {
          week_start: "2026-08-03",
          allowed_actions: { can_save: true },
        },
      },
    };
    const previewResult: AtlasRpcResult = {
      kind: "success",
      response: {
        success: true,
        preview: {
          source_signature: "a".repeat(64),
          can_save: false,
          issues: { blockers: [{ code: "MISSING_REQUIRED_NOTE" }] },
        },
      },
    };
    const stale: AtlasRpcResult = {
      kind: "backend_error",
      error: {
        success: false,
        error_code: "STALE_VERSION",
        safe_message: "safe",
      },
    };

    expect(pantryWorkbenchFromResult(workbenchResult)).toMatchObject({
      week_start: "2026-08-03",
      allowed_actions: { can_save: true },
    });
    expect(pantryPreviewFromResult(previewResult)).toMatchObject({
      source_signature: "a".repeat(64),
      can_save: false,
    });
    expect(pantryWorkbenchFromResult(stale)).toBeNull();
    expect(pantryResultMessage(stale)).toMatch(/đã thay đổi/i);
  });

  it("uses Nhu cầu bổ sung in representative operator result messages", () => {
    const backend = (errorCode: string, safeMessage = "safe") =>
      ({
        kind: "backend_error",
        error: {
          success: false,
          error_code: errorCode,
          safe_message: safeMessage,
        },
      }) satisfies AtlasRpcResult;
    const messages = [
      pantryResultMessage(success),
      pantryResultMessage({
        kind: "client_error",
        diagnostic: { code: "RPC_NOT_ALLOWED", safeMessage: "safe" },
      }),
      pantryResultMessage(backend("CAPABILITY_DENIED")),
      pantryResultMessage(backend("STALE_VERSION")),
      pantryResultMessage(backend("STALE_SOURCE_SIGNATURE")),
      pantryResultMessage(backend("INVALID_LIFECYCLE_STATE")),
      pantryResultMessage(backend("INVARIANT_VIOLATION")),
      pantryResultMessage(
        backend("UNMAPPED", "Pantry source signature lifecycle version"),
      ),
    ];

    expect(messages).toEqual(
      expect.arrayContaining([
        "Đã lưu Nhu cầu bổ sung.",
        "Bạn không có quyền cập nhật Nhu cầu bổ sung.",
        "Nhu cầu bổ sung đã thay đổi. Hãy tải lại dữ liệu trước khi tiếp tục.",
        "Dữ liệu Nhu cầu bổ sung đã thay đổi. Hãy xem thay đổi lại trước khi lưu.",
      ]),
    );
    for (const message of messages) {
      expect(message).toMatch(/Nhu cầu bổ sung/);
      expect(message).not.toMatch(
        /Pantry|source signature|lifecycle|contract|version/i,
      );
    }
  });

  it("preserves authentication and uncertain-write guidance", () => {
    expect(
      pantryResultMessage({
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
    expect(
      pantryResultMessage({
        kind: "auth_error",
        diagnostic: { code: "SESSION_EXPIRED", safeMessage: "safe" },
      }),
    ).toMatch(/đăng nhập lại/i);
    expect(
      pantryResultMessage({
        kind: "transport_error",
        diagnostic: { code: "NETWORK_FAILURE", safeMessage: "safe" },
      }),
    ).toMatch(/không tự động gửi lại/i);
  });
});
