import { act, cleanup, renderHook, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { useConfirmedNeedWorkbench } from "./useConfirmedNeedWorkbench";
import {
  createConfirmedNeedCorrectionFixture as correctionFixture,
  reviewDate,
  reviewFailure,
  reviewSuccess,
} from "./confirmedNeedReviewFixtures";

afterEach(cleanup);
async function mount(
  prepare?: (fixture: ReturnType<typeof correctionFixture>) => void,
) {
  const fixture = correctionFixture();
  prepare?.(fixture);
  const save = vi.spyOn(fixture.confirmedNeedApi, "save");
  const read = vi.spyOn(fixture.confirmedNeedApi, "getReview");
  const preflight = vi.spyOn(fixture.preflightApi, "preflight");
  const hook = renderHook(() =>
    useConfirmedNeedWorkbench({
      ...fixture,
      authSubject: "operator",
      initialServiceDate: reviewDate,
      onContinueAllocation: vi.fn(),
    }),
  );
  await waitFor(() => expect(hook.result.current.busy).toBe(false));
  return { ...hook, fixture, save, read, preflight };
}
describe("K3 explicit correction controller", () => {
  it("reuses the exact v3 envelope only for an unchanged proven-safe retry", async () => {
    const h = await mount();
    h.save.mockResolvedValue(
      reviewFailure("INTERNAL_COMMAND_FAILURE", "NO_COMMITTED_CHANGE"),
    );
    act(() => h.result.current.startCorrection());
    act(() => h.result.current.setCorrectionReason("Điều chỉnh thực tế"));
    act(() =>
      h.result.current.edit("line-0", {
        exact_quantity: "110",
        quantity_entered: true,
      }),
    );
    await act(() => h.result.current.save());
    expect(h.result.current.lock).toBeNull();
    await act(() => h.result.current.save());
    expect(h.save.mock.calls[1]![0]).toEqual(h.save.mock.calls[0]![0]);
    act(() =>
      h.result.current.edit("line-0", {
        exact_quantity: "111",
        quantity_entered: true,
      }),
    );
    await act(() => h.result.current.save());
    expect(h.save.mock.calls[2]![0].command_id).not.toBe(
      h.save.mock.calls[0]![0].command_id,
    );
  });
  it("uses distinct backend v3 permission with the real released v2 lifecycle blocker", async () => {
    const h = await mount((f) => {
      f.batch.blockers = [
        {
          code: "CONFIRMED_NEED_BATCH_NOT_REVIEWABLE",
          message:
            "Nhu cầu đã phát hành không thể lưu theo quy trình thông thường.",
        },
      ];
    });
    expect(h.result.current.canStartCorrection).toBe(true);
    expect(h.result.current.canSave).toBe(false);
    act(() => h.result.current.startCorrection());
    act(() => h.result.current.setCorrectionReason("Điều chỉnh sau phát hành"));
    act(() =>
      h.result.current.edit("line-0", {
        exact_quantity: "110",
        quantity_entered: true,
      }),
    );
    expect(h.result.current.editable).toBe(true);
    expect(h.result.current.canSave).toBe(true);
  });
  it("retains unrelated blocking evidence even when v3 permission is present", async () => {
    const h = await mount((f) => {
      f.batch.blockers = [{ code: "UNKNOWN_BLOCKER", message: "Cần kiểm tra" }];
    });
    expect(h.result.current.canStartCorrection).toBe(false);
  });
  it("keeps an authentic K1 REOPENED batch read-only until a second explicit correction", async () => {
    const h = await mount((f) => {
      f.batch.authoritative_batch_status = "REOPENED";
      f.batch.batch_status = "REOPENED";
      f.batch.editing_allowed = true;
      f.batch.allowed_actions.save_confirmed_needs = false;
      f.batch.lines[0]!.confirmed_quantity_after = "110.000000";
    });
    expect(h.result.current.editable).toBe(false);
    act(() =>
      h.result.current.edit("line-0", {
        exact_quantity: "90",
        quantity_entered: true,
      }),
    );
    expect(h.result.current.dirty).toBe(false);
    expect(h.result.current.canStartCorrection).toBe(true);
    act(() => h.result.current.startCorrection());
    expect(h.result.current.editable).toBe(true);
  });
  it("keeps released quantity read-only until explicit server-authorized entry", async () => {
    const h = await mount();
    expect(h.result.current.editable).toBe(false);
    expect(h.result.current.canStartCorrection).toBe(true);
    act(() => h.result.current.startCorrection());
    expect(h.result.current.correctionMode).toBe(true);
    expect(h.result.current.editable).toBe(true);
    act(() =>
      h.result.current.edit("line-0", {
        exact_quantity: "110.000000",
        quantity_entered: true,
      }),
    );
    expect(h.result.current.canSave).toBe(false);
    act(() => h.result.current.setCorrectionReason("Bếp xác nhận thay đổi"));
    expect(h.result.current.canSave).toBe(true);
  });
  it.each([false, undefined])(
    "never locally enables an unavailable correction action %s",
    async (allowed) => {
      const h = await mount((f) => {
        f.batch.allowed_actions.correct_released_confirmed_needs = allowed;
      });
      act(() => h.result.current.startCorrection());
      expect(h.result.current.correctionMode).toBe(false);
      expect(h.result.current.editable).toBe(false);
      expect(h.save).not.toHaveBeenCalled();
    },
  );
  it("saves only the changed line using v3 then obtains fresh canonical preflight and review", async () => {
    const h = await mount();
    h.save.mockImplementation(async (request) => {
      expect(request.contract_version).toBe("RMVP-05.v3");
      h.fixture.batch.batch_version++;
      h.fixture.batch.authoritative_batch_status = "REOPENED";
      h.fixture.batch.lines[0]!.confirmed_quantity_after = "110.000000";
      return reviewSuccess({ authoritative_readback: h.fixture.batch });
    });
    act(() => h.result.current.startCorrection());
    act(() => h.result.current.setCorrectionReason("Tăng theo yêu cầu bếp"));
    act(() =>
      h.result.current.edit("line-0", {
        exact_quantity: "110.000000",
        quantity_entered: true,
      }),
    );
    await act(() => h.result.current.save());
    expect(h.save).toHaveBeenCalledTimes(1);
    const request = h.save.mock.calls[0]![0];
    expect(request.payload.lines).toHaveLength(1);
    expect(request.payload.lines[0]).toMatchObject({
      proposed_confirmed_quantity: "110.000000",
      reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT",
      reason_note: "Tăng theo yêu cầu bếp",
    });
    expect(h.preflight).toHaveBeenCalledTimes(2);
    expect(h.read).toHaveBeenCalledTimes(2);
    expect(h.result.current.correctionMode).toBe(false);
    expect(h.result.current.dirty).toBe(false);
    expect(h.result.current.notice).toContain("chưa được phát hành lại");
  });
  it("guards a reason-only draft on School/context changes", async () => {
    const h = await mount();
    act(() => h.result.current.startCorrection());
    act(() => h.result.current.setCorrectionReason("Đang xác minh"));
    act(() => h.result.current.transition({ schoolIds: ["school-1"] }));
    expect(h.result.current.pendingTransition).toEqual({
      schoolIds: ["school-1"],
    });
    expect(h.result.current.schoolIds).toEqual([]);
    act(() => h.result.current.discardTransition());
    expect(h.result.current.schoolIds).toEqual(["school-1"]);
    expect(h.result.current.correctionMode).toBe(false);
  });
  it("locks UNKNOWN without retry and recovers through canonical reads", async () => {
    const h = await mount();
    h.save.mockResolvedValue(reviewFailure("UNREVIEWED_RESULT", "UNKNOWN"));
    act(() => h.result.current.startCorrection());
    act(() => h.result.current.setCorrectionReason("Điều chỉnh số lượng"));
    act(() =>
      h.result.current.edit("line-0", {
        exact_quantity: "110",
        quantity_entered: true,
      }),
    );
    await act(() => h.result.current.save());
    expect(h.result.current.lock).toBe("unknown");
    await act(() => h.result.current.save());
    expect(h.save).toHaveBeenCalledTimes(1);
    await act(() => h.result.current.recover());
    expect(h.result.current.lock).toBeNull();
    expect(h.result.current.correctionMode).toBe(false);
    expect(h.save).toHaveBeenCalledTimes(1);
  });
});
