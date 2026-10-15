import { confirmedNeedSaveV2Request } from "../bridges/confirmedNeed";
import { act, cleanup, renderHook, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { useConfirmedNeedWorkbench } from "./useConfirmedNeedWorkbench";
import {
  createConfirmedNeedReviewFixture,
  reviewDate,
  reviewFailure,
  reviewPreflight,
  reviewSuccess,
  type ConfirmedReviewScenario,
} from "./confirmedNeedReviewFixtures";
afterEach(cleanup);
function mount(scenario: ConfirmedReviewScenario = "normal") {
  const fixture = createConfirmedNeedReviewFixture(scenario);
  const preflightRead = vi.spyOn(fixture.preflightApi, "preflight");
  const read = vi.spyOn(fixture.confirmedNeedApi, "getReview");
  const execute = vi.spyOn(fixture.needGenerationApi, "execute");
  const save = vi.spyOn(fixture.confirmedNeedApi, "save");
  const navigate = vi.fn();
  const hook = renderHook(() =>
    useConfirmedNeedWorkbench({
      ...fixture,
      authSubject: "operator",
      initialServiceDate: reviewDate,
      onContinueAllocation: navigate,
    }),
  );
  return { ...hook, fixture, read, execute, save, preflightRead, navigate };
}
async function ready(scenario: ConfirmedReviewScenario = "normal") {
  const h = mount(scenario);
  await waitFor(() => expect(h.result.current.busy).toBe(false));
  return h;
}
describe("Confirmed Need date authority and generation", () => {
  it("derives the new Monday while keeping preflight on one exact service day", async () => {
    const h = await ready();
    act(() => h.result.current.transition({ date: "2026-09-14" }));
    await waitFor(() => expect(h.result.current.busy).toBe(false));
    expect(h.result.current.date).toBe("2026-09-14");
    expect(h.result.current.week).toBe("2026-09-14");
    expect(h.preflightRead).toHaveBeenLastCalledWith(
      "operator",
      expect.any(String),
      "2026-09-14",
      "2026-09-14",
    );
  });
  it("applies quantity proposals only locally, ignores note-only proposals and discards delayed imports", async () => {
    const h = await ready();
    const before = h.result.current.drafts;
    act(() =>
      h.result.current.captureShoppingListImport()({
        drafts: structuredClone(before),
        changedLineIds: [],
      }),
    );
    expect(h.result.current.drafts).toBe(before);
    expect(h.result.current.dirty).toBe(false);
    const apply = h.result.current.captureShoppingListImport();
    const imported = {
      drafts: {
        ...before,
        "line-0": {
          ...before["line-0"]!,
          exact_quantity: "12,5",
          quantity_entered: true,
        },
      },
      changedLineIds: ["line-0"],
    };
    act(() => apply(imported));
    expect(h.result.current.dirty).toBe(true);
    expect(h.save).not.toHaveBeenCalled();
    expect(h.result.current.drafts["line-0"]!.reason_code).toBe(
      before["line-0"]!.reason_code,
    );
    expect(() => apply(imported)).toThrow("đã thay đổi");
  });
  it("discards an import after switching the exact service date", async () => {
    const h = await ready(),
      apply = h.result.current.captureShoppingListImport(),
      drafts = h.result.current.drafts;
    act(() => h.result.current.transition({ date: "2026-09-08" }));
    expect(() => apply({ drafts, changedLineIds: ["line-0"] })).toThrow(
      "đã thay đổi",
    );
    expect(h.save).not.toHaveBeenCalled();
  });
  it("ignores a delayed read failure from a previous authenticated context", async () => {
    const fixture = createConfirmedNeedReviewFixture();
    let finish!: (r: ReturnType<typeof reviewFailure>) => void;
    vi.spyOn(fixture.preflightApi, "preflight").mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          finish = resolve;
        }),
    );
    const { result, rerender } = renderHook(
      ({ authSubject }) =>
        useConfirmedNeedWorkbench({
          ...fixture,
          authSubject,
          initialServiceDate: reviewDate,
          onContinueAllocation: vi.fn(),
        }),
      { initialProps: { authSubject: "first" } },
    );
    rerender({ authSubject: "second" });
    await waitFor(() => expect(result.current.canContinue).toBe(true));
    await act(async () => {
      finish(reviewFailure());
    });
    expect(result.current.lock).toBeNull();
    expect(result.current.readError).toBeNull();
    expect(result.current.canContinue).toBe(true);
  });
  it("still reads the exact batch when sources become outdated during unknown Save recovery", async () => {
    const h = await ready("unknown");
    act(() =>
      h.result.current.edit("line-0", {
        exact_quantity: "12.5",
        quantity_entered: true,
        reason_code: "OTHER",
        reason_note: "Bếp yêu cầu",
      }),
    );
    await act(() => h.result.current.save());
    h.fixture.preflight.downstream_currentness = "OUTDATED";
    h.read.mockResolvedValue(reviewFailure());
    await act(() => h.result.current.recover());
    expect(h.read).toHaveBeenCalledTimes(2);
    expect(h.result.current.lock).toBe("unknown");
    expect(h.result.current.readError).toBeTruthy();
    expect(h.result.current.canGenerate).toBe(false);
  });
  it("does not offer an outdated update without current run identity", async () => {
    const h = await ready("outdated");
    h.fixture.preflight.current_need = null;
    await act(() => h.result.current.recover());
    expect(h.result.current.canGenerate).toBe(false);
  });
  it("locks incomplete batch pagination rather than silently saving a partial batch", async () => {
    const h = await ready();
    h.fixture.batch.pagination.has_more = true;
    await act(() => h.result.current.recover());
    expect(h.result.current.lock).toBe("eligibility");
    expect(h.result.current.canContinue).toBe(false);
  });
  it("never treats unchanged version readback as a committed Save", async () => {
    const h = await ready("needs_review");
    h.save.mockResolvedValue(
      reviewSuccess({ authoritative_readback: h.fixture.batch }),
    );
    await act(() => h.result.current.save());
    expect(h.result.current.lock).toBe("unknown");
  });
  it("blocks navigation when backend readback contains current source blockers", async () => {
    const h = await ready();
    h.fixture.batch.blockers = [
      { code: "SOURCE_BLOCKER_PRESENT", message: "Nguồn cần kiểm tra" },
    ];
    await act(() => h.result.current.recover());
    expect(h.result.current.canContinue).toBe(false);
  });
  it("treats historical precision as immutable even through controller edits", async () => {
    const h = await ready("historical");
    act(() =>
      h.result.current.edit("line-0", {
        exact_quantity: "10.12",
        quantity_entered: true,
      }),
    );
    expect(h.result.current.drafts["line-0"].exact_quantity).toBe("10.123456");
    expect(h.result.current.dirty).toBe(false);
  });
  it("retains batch authority for clean presentation-only school scope", async () => {
    const h = await ready();
    act(() => h.result.current.transition({ schoolIds: ["school-1"] }));
    expect(h.result.current.visibleLines).toHaveLength(3);
    expect(h.read).toHaveBeenCalledTimes(1);
    expect(h.preflightRead).toHaveBeenCalledTimes(1);
  });
  it("enforces backend Save eligibility", async () => {
    const h = await ready("needs_review");
    h.fixture.batch.allowed_actions.save_confirmed_needs = false;
    await act(() => h.result.current.recover());
    expect(h.result.current.canSave).toBe(false);
    await act(() => h.result.current.save());
    expect(h.save).not.toHaveBeenCalled();
  });
  it("requires refreshed eligibility after definite no-business-write failure", async () => {
    const h = await ready("needs_review");
    h.save.mockResolvedValue(reviewFailure());
    await act(() => h.result.current.save());
    expect(h.result.current.lock).toBe("eligibility");
    expect(h.result.current.canSave).toBe(false);
  });
  it("locks a thrown transport write without automatic retry", async () => {
    const h = await ready("needs_review");
    h.save.mockRejectedValue(new Error("offline"));
    await act(() => h.result.current.save());
    expect(h.result.current.lock).toBe("unknown");
    expect(h.save).toHaveBeenCalledTimes(1);
  });
  it("resolves exact selected-day preflight and batch automatically", async () => {
    const h = await ready();
    expect(h.preflightRead).toHaveBeenCalledWith(
      "operator",
      expect.any(String),
      reviewDate,
      reviewDate,
    );
    expect(h.read).toHaveBeenCalledWith(
      "operator",
      expect.any(String),
      "batch-current",
      expect.objectContaining({ service_date: reviewDate }),
      0,
      1000,
    );
    expect(h.result.current.workbench?.confirmed_need_batch_id).toBe(
      "batch-current",
    );
    expect(h.result.current.date).toBe(reviewDate);
  });
  it.each([
    "no_demand",
    "blocked",
    "legacy_overlap",
    "correction_blocked",
  ] as const)("blocks generation for %s", async (scenario) => {
    const h = await ready(scenario);
    expect(h.result.current.canGenerate).toBe(false);
    await act(() => h.result.current.generate());
    expect(h.execute).not.toHaveBeenCalled();
  });
  it.each(["not_generated", "outdated"] as const)(
    "executes %s once with exact date and expected identity",
    async (scenario) => {
      const h = await ready(scenario);
      expect(h.result.current.canGenerate).toBe(true);
      await act(() => h.result.current.generate());
      expect(h.execute).toHaveBeenCalledTimes(1);
      expect(h.execute.mock.calls[0]![0]).toMatchObject({
        contract_version: "RMVP-04.v3",
        expected_version: scenario === "outdated" ? 3 : 1,
        requested_by_auth_subject: "operator",
        payload: {
          service_date: reviewDate,
          expected_current_need_generation_run_id:
            scenario === "outdated" ? "run-current" : null,
        },
      });
      expect(h.result.current.workbench?.confirmed_need_batch_id).toBe(
        "batch-current",
      );
      if (scenario === "outdated")
        expect(h.result.current.notice).toContain("5 xác nhận được giữ nguyên");
    },
  );
  it("locks successful generation without readback and never retries", async () => {
    const h = await ready("not_generated");
    h.execute.mockResolvedValue(reviewSuccess({}));
    await act(() => h.result.current.generate());
    expect(h.result.current.lock).toBe("unknown");
    await act(() => h.result.current.generate());
    expect(h.execute).toHaveBeenCalledTimes(1);
  });
  it("rejects another date's preflight without selecting it", async () => {
    const h = await ready();
    const p = reviewPreflight();
    p.period_start = p.period_end = "2026-09-08";
    h.preflightRead.mockResolvedValue(reviewSuccess({ preflight: p }));
    await act(() => h.result.current.recover());
    expect(h.result.current.date).toBe(reviewDate);
    expect(h.result.current.canContinue).toBe(false);
  });
  it("rejects incomplete or mismatched batch authority", async () => {
    const h = await ready();
    h.read.mockResolvedValue(
      reviewSuccess({
        workbench: {
          ...h.fixture.batch,
          confirmed_need_batch_id: "other-batch",
        },
      }),
    );
    await act(() => h.result.current.recover());
    expect(h.result.current.canContinue).toBe(false);
  });
});
describe("Confirmed Need local draft and safety", () => {
  it("prioritizes lines needing review above healthy lines", async () => {
    const h = await ready();
    Object.assign(h.fixture.batch.lines[5]!, {
      confirmation_state: "CHANGED",
      current_decision_id: null,
    });
    await act(() => h.result.current.recover());
    expect(h.result.current.visibleLines[0]!.confirmed_need_line_id).toBe(
      "line-5",
    );
  });
  it("navigates only the selected day when another daily authority is loaded", async () => {
    const h = await ready();
    const p = reviewPreflight();
    p.period_start = p.period_end = "2026-09-08";
    h.preflightRead.mockResolvedValue(reviewSuccess({ preflight: p }));
    const b = structuredClone(h.fixture.batch);
    b.service_period = { period_start: "2026-09-08", period_end: "2026-09-08" };
    b.lines.forEach((l) => {
      l.service_date = "2026-09-08";
    });
    h.read.mockResolvedValue(reviewSuccess({ workbench: b }));
    act(() => h.result.current.transition({ date: "2026-09-08" }));
    await waitFor(() => expect(h.result.current.canContinue).toBe(true));
    act(() => h.result.current.continueAllocation());
    expect(h.navigate).toHaveBeenCalledWith({
      start: "2026-09-08",
      end: "2026-09-08",
    });
    expect(h.navigate).not.toHaveBeenCalledWith(reviewDate);
  });
  it("blocks duplicate Save clicks while the first command is pending", async () => {
    const h = await ready("needs_review");
    let finish!: (r: ReturnType<typeof reviewSuccess>) => void;
    h.save.mockImplementation(
      () =>
        new Promise((resolve) => {
          finish = resolve;
        }),
    );
    let pending!: Promise<void>;
    act(() => {
      pending = h.result.current.save();
      void h.result.current.save();
    });
    expect(h.save).toHaveBeenCalledTimes(1);
    expect(h.result.current.canContinue).toBe(false);
    await act(async () => {
      finish(reviewSuccess({}));
      await pending;
    });
    expect(h.result.current.lock).toBe("unknown");
  });
  it("searches without accents and filters locally without reads", async () => {
    const h = await ready("carried");
    const count = h.read.mock.calls.length;
    act(() => h.result.current.setSearch("gao thom"));
    expect(h.result.current.visibleLines).toHaveLength(1);
    act(() => h.result.current.setFilter("carried_forward"));
    expect(h.result.current.visibleLines).toHaveLength(1);
    act(() => h.result.current.setFilter("needs_review"));
    expect(h.result.current.visibleLines).toHaveLength(0);
    expect(h.read).toHaveBeenCalledTimes(count);
  });
  it.each(["12,5", "12.5"])(
    "saves exact %s changed line with expected revision and adopts authority",
    async (value) => {
      const h = await ready();
      act(() =>
        h.result.current.edit("line-0", {
          exact_quantity: value,
          quantity_entered: true,
          reason_code: "OTHER",
          reason_note: "Bếp yêu cầu",
        }),
      );
      expect(h.result.current.canSave).toBe(true);
      await act(() => h.result.current.save());
      expect(h.save.mock.calls[0]![0]).toMatchObject({
        contract_version: "RMVP-05.v2",
        expected_version: 4,
        payload: {
          confirmed_need_batch_id: "batch-current",
          lines: [
            {
              confirmed_need_line_id: "line-0",
              expected_current_revision_id: "revision-0",
              expected_current_decision_id: "decision-0",
              proposed_confirmed_quantity: "12.5",
              reason_code: "OTHER",
              reason_note: "Bếp yêu cầu",
            },
          ],
        },
      });
      expect(h.result.current.drafts["line-0"].exact_quantity).toBe(
        "12.500000",
      );
      expect(h.result.current.dirty).toBe(false);
    },
  );
  it.each(["-1", "10,123", "1e3", ""])(
    "blocks invalid entry %s",
    async (quantity) => {
      const h = await ready();
      act(() =>
        h.result.current.edit("line-0", {
          exact_quantity: quantity,
          quantity_entered: true,
        }),
      );
      expect(h.result.current.errors["line-0"]).toContain("bước 0,25 kg");
      expect(h.result.current.canSave).toBe(false);
    },
  );
  it("uses H1A only as the human confirmation quantum", async () => {
    const h = await ready();
    h.fixture.batch.lines[0]!.proposed_confirmed_quantity = "1.500000";
    h.fixture.batch.lines[0]!.proposal_rounding_step = "0.500000";
    h.fixture.batch.lines[0]!.confirmed_quantity_after = "1.500000";
    h.fixture.batch.lines[0]!.effective_policy!.planning_step = "0.010000";
    await act(() => h.result.current.recover());
    act(() =>
      h.result.current.edit("line-0", {
        exact_quantity: "1.370000",
        quantity_entered: true,
        reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT",
        reason_note: "Bếp yêu cầu",
      }),
    );
    expect(h.result.current.dirty).toBe(true);
    expect(h.result.current.errors).toEqual({});
    expect(h.result.current.canSave).toBe(true);
    act(() =>
      h.result.current.edit("line-0", {
        exact_quantity: "1.375000",
        quantity_entered: true,
      }),
    );
    expect(h.result.current.errors["line-0"]).toContain("bước 0,01 kg");
    expect(h.result.current.canSave).toBe(false);
  });
  it("keeps COUNT human confirmation on H1A rather than the proposal step", async () => {
    const h = await ready();
    h.fixture.batch.lines[0]!.controlled_unit.code = "Chai";
    h.fixture.batch.lines[0]!.proposed_confirmed_quantity = "18.000000";
    h.fixture.batch.lines[0]!.proposal_rounding_step = "6.000000";
    h.fixture.batch.lines[0]!.confirmed_quantity_after = "18.000000";
    h.fixture.batch.lines[0]!.effective_policy!.planning_step = "1.000000";
    await act(() => h.result.current.recover());
    act(() =>
      h.result.current.edit("line-0", {
        exact_quantity: "17",
        quantity_entered: true,
        reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT",
        reason_note: "Bếp yêu cầu",
      }),
    );
    expect(h.result.current.errors).toEqual({});
    expect(h.result.current.canSave).toBe(true);
    act(() =>
      h.result.current.edit("line-0", {
        exact_quantity: "17.5",
        quantity_entered: true,
      }),
    );
    expect(h.result.current.errors["line-0"]).toContain("bước 1 Chai");
    expect(h.result.current.canSave).toBe(false);
  });
  it("accepts proposed quantities for new lines using Save", async () => {
    const h = await ready("needs_review");
    expect(h.result.current.canSave).toBe(true);
    await act(() => h.result.current.save());
    expect(h.save.mock.calls[0]![0].payload.lines[0]).toMatchObject({
      proposed_confirmed_quantity: "10.250000",
      reason_code: "PROPOSAL_ACCEPTED",
    });
  });
  it("requires adjustment reason and explanatory saved-decision note", async () => {
    const h = await ready();
    act(() =>
      h.result.current.edit("line-0", {
        exact_quantity: "12",
        quantity_entered: true,
      }),
    );
    expect(h.result.current.errors["line-0"]).toContain("chọn lý do");
    act(() =>
      h.result.current.edit("line-0", {
        reason_code: "PLANNING_STEP_ADJUSTMENT",
      }),
    );
    expect(h.result.current.errors["line-0"]).toContain("đã lưu cần ghi chú");
  });
  it.each(["OTHER", "OPERATIONAL_QUANTITY_ADJUSTMENT"] as const)(
    "requires note for %s",
    async (reason_code) => {
      const h = await ready("needs_review");
      act(() =>
        h.result.current.edit("line-0", {
          exact_quantity: "12",
          quantity_entered: true,
          reason_code,
        }),
      );
      expect(h.result.current.errors["line-0"]).toContain("cần ghi chú");
    },
  );
  it.each([
    { date: "2026-09-08" },
    { week: "2026-09-14" },
    { schoolIds: ["school-1"] },
    { refresh: true },
  ])("protects dirty context %j", async (change) => {
    const h = await ready();
    act(() =>
      h.result.current.edit("line-0", {
        exact_quantity: "12,5",
        quantity_entered: true,
      }),
    );
    act(() => h.result.current.transition(change));
    expect(h.result.current.pendingTransition).not.toBeNull();
    act(() => h.result.current.cancelTransition());
    expect(h.result.current.drafts["line-0"].exact_quantity).toBe("12,5");
    act(() => h.result.current.transition(change));
    await act(() => h.result.current.discardTransition());
    expect(h.result.current.pendingTransition).toBeNull();
    expect(h.result.current.drafts["line-0"]?.exact_quantity).not.toBe("12,5");
  });
  it("retains hidden dirty rows in the full Save set", async () => {
    const h = await ready();
    act(() =>
      h.result.current.edit("line-0", {
        exact_quantity: "12.5",
        quantity_entered: true,
        reason_code: "OTHER",
        reason_note: "Bếp yêu cầu",
      }),
    );
    act(() => h.result.current.setSearch("thit"));
    expect(h.result.current.hiddenDirtyCount).toBe(1);
    expect(h.result.current.pendingTransition).toBeNull();
    await act(() => h.result.current.save());
    expect(
      h.save.mock.calls[0]![0].payload.lines[0]!.confirmed_need_line_id,
    ).toBe("line-0");
  });
  it.each(["stale", "unknown", "missing_readback", "recovery_failed"] as const)(
    "locks %s and recovers only from authority",
    async (scenario) => {
      const h = await ready(scenario);
      act(() =>
        h.result.current.edit("line-0", {
          exact_quantity: "12.5",
          quantity_entered: true,
          reason_code: "OTHER",
          reason_note: "Bếp yêu cầu",
        }),
      );
      await act(() => h.result.current.save());
      expect(h.result.current.lock).toBe(
        scenario === "stale" ? "stale" : "unknown",
      );
      expect(h.result.current.canContinue).toBe(false);
      await act(() => h.result.current.save());
      expect(h.save).toHaveBeenCalledTimes(1);
      await act(() => h.result.current.recover());
      if (scenario === "recovery_failed") {
        expect(h.result.current.lock).toBe("unknown");
        expect(h.result.current.readError).toBeTruthy();
      } else expect(h.result.current.lock).toBeNull();
    },
  );
  it("keeps definite no-commit failure retryable without unknown classification", async () => {
    const h = await ready("needs_review");
    h.save.mockResolvedValue(
      reviewFailure("RETRYABLE_CONCURRENCY_FAILURE", "NO_COMMITTED_CHANGE"),
    );
    await act(() => h.result.current.save());
    expect(h.result.current.lock).toBeNull();
    expect(h.result.current.canSave).toBe(true);
  });
  it.each(["normal", "released"] as const)(
    "navigates %s directly with selected date and zero writes",
    async (scenario) => {
      const h = await ready(scenario);
      expect(h.result.current.canContinue).toBe(true);
      act(() => h.result.current.continueAllocation());
      expect(h.navigate).toHaveBeenCalledWith({
        start: reviewDate,
        end: reviewDate,
      });
      expect(h.save).not.toHaveBeenCalled();
      expect(h.execute).not.toHaveBeenCalled();
    },
  );
});

describe("long-running generation interaction", () => {
  it("shows a rolled-back zero invariant as a deterministic business error", async () => {
    const h = await ready("not_generated");
    const failure = reviewFailure(
      "ZERO_ACTIVE_CONTRIBUTION_POLICY_REQUIRED",
      "NO_COMMITTED_CHANGE",
    );
    if (failure.kind === "backend_error") failure.error.retryable = false;
    h.execute.mockResolvedValue(failure);
    await act(() => h.result.current.generate());
    expect(h.result.current.operation.status).toBe("FAILED");
    expect(h.result.current.notice).toBe(
      "Dữ liệu nhu cầu không hợp lệ: đóng góp bằng 0 không được đưa vào nhu cầu mua hàng.",
    );
    expect(h.result.current.lock).toBeNull();
    expect(JSON.stringify(h.result.current.operation)).not.toContain(
      "Chưa xác định được kết quả",
    );
    expect(h.result.current.canGenerate).toBe(true);
  });
  it("adopts authoritative no-demand generation without a Confirmed Need batch", async () => {
    const h = await ready("not_generated");
    const p = {
      ...reviewPreflight(),
      demand_state: "NO_DEMAND",
      current_need: {
        ...reviewPreflight().current_need!,
        need_generation_release_snapshot_id: "snapshot-current",
      },
    };
    p.current_need = {
      ...p.current_need!,
      confirmed_need_batch_id: null,
      confirmed_need_batch_status: null,
      confirmed_need_batch_version: null,
    } as unknown as typeof p.current_need;
    const need = structuredClone(h.fixture.need);
    need.materialization.confirmed_need_batch_id = null;
    need.selected_run!.release_snapshot_id = "snapshot-current";
    need.grouped_requirements = [];
    h.execute.mockResolvedValue(
      reviewSuccess({
        authoritative_readback: { preflight: p, need_generation: need },
      }),
    );
    await act(() => h.result.current.generate());
    expect(h.result.current.operation.status).toBe("SUCCEEDED");
    expect(h.result.current.notice).toContain("Không có nhu cầu");
    expect(h.result.current.lock).toBeNull();
    expect(h.result.current.workbench).toBeNull();
    expect(h.result.current.canContinue).toBe(false);
    expect(h.result.current.canGenerate).toBe(false);
    expect(h.read).not.toHaveBeenCalled();
    h.preflightRead.mockResolvedValue(reviewSuccess({ preflight: p }));
    await act(() => h.result.current.recover());
    expect(h.result.current.lock).toBeNull();
    expect(h.result.current.readError).toBeNull();
  });
  it.each([
    "null-run",
    "missing-release",
    "wrong-release",
    "wrong-version",
    "positive-group",
    "missing-source",
    "contradictory-source",
    "blocking-count",
    "released-batch",
    "partial-batch",
  ])("locks malformed no-demand success: %s", async (invalid) => {
    const h = await ready("not_generated");
    const p = {
      ...reviewPreflight(),
      demand_state: "NO_DEMAND",
      current_need: {
        ...reviewPreflight().current_need!,
        confirmed_need_batch_id: null as string | null,
        confirmed_need_batch_status: null as string | null,
        confirmed_need_batch_version: null as number | null,
        need_generation_release_snapshot_id: "snapshot-current",
      },
    };
    const need = structuredClone(h.fixture.need);
    need.materialization.confirmed_need_batch_id = null;
    need.selected_run!.release_snapshot_id = "snapshot-current";
    if (invalid !== "positive-group") need.grouped_requirements = [];
    if (invalid === "null-run") {
      p.current_need.need_generation_run_id = null as unknown as string;
      need.selected_run!.need_generation_run_id = null as unknown as string;
    }
    if (invalid === "missing-release")
      delete need.selected_run!.release_snapshot_id;
    if (invalid === "wrong-release")
      need.selected_run!.release_snapshot_id = "other-snapshot";
    if (invalid === "wrong-version") need.selected_run!.version++;
    if (invalid === "blocking-count") p.blocking_issue_count = 1;
    if (invalid === "partial-batch")
      p.current_need.confirmed_need_batch_id = "batch-current";
    if (invalid === "released-batch") {
      p.current_need.confirmed_need_batch_id = "batch-current";
      p.current_need.confirmed_need_batch_status =
        "RELEASED_FOR_PURCHASE_HANDOFF";
      p.current_need.confirmed_need_batch_version = 5;
    }
    if (invalid === "contradictory-source") {
      p.issues = [
        {
          issue_code: "NO_NEED_SOURCE_FOR_SERVICE_DATE",
          severity: "BLOCKING",
          message: "Không có nhu cầu",
          input_type: "NEED_GENERATION",
          school_id: null,
          service_date: reviewDate,
        },
      ];
    }
    if (invalid === "missing-source") {
      Reflect.deleteProperty(p, "demand_state");
      p.issues = [
        {
          issue_code: "NO_NEED_SOURCE_FOR_SERVICE_DATE",
          severity: "BLOCKING",
          message: "Không có nhu cầu",
          input_type: "NEED_GENERATION",
          school_id: null,
          service_date: reviewDate,
        },
      ];
      p.current_need.confirmed_need_batch_id = "batch-current";
      need.materialization.confirmed_need_batch_id = "batch-current";
      h.read.mockResolvedValue(reviewSuccess({}));
    }

    h.execute.mockResolvedValue(
      reviewSuccess({
        authoritative_readback: { preflight: p, need_generation: need },
      }),
    );
    await act(() => h.result.current.generate());
    expect(h.result.current.operation.status).toBe("UNKNOWN_OUTCOME");
    expect(h.result.current.lock).toBe("unknown");
    expect(h.result.current.canGenerate).toBe(false);
  });
  it("keeps an unclassified backend response locked until reload", async () => {
    const h = await ready("not_generated");
    h.execute.mockResolvedValue(
      reviewFailure("UNEXPECTED_RESPONSE", "UNKNOWN"),
    );
    await act(() => h.result.current.generate());
    expect(h.result.current.operation.status).toBe("UNKNOWN_OUTCOME");
    expect(h.result.current.lock).toBe("unknown");
    await act(() => h.result.current.generate());
    expect(h.execute).toHaveBeenCalledTimes(1);
  });

  it("keeps the operation running through readback, blocks duplicates and then shows authoritative success", async () => {
    const h = await ready("not_generated");
    let finish!: () => void;
    let finishRead!: () => void;
    h.read.mockImplementation(async () => {
      await new Promise<void>((resolve) => {
        finishRead = resolve;
      });
      return reviewSuccess({ workbench: h.fixture.batch });
    });
    h.execute.mockRestore();
    const original = h.fixture.needGenerationApi.execute.bind(
      h.fixture.needGenerationApi,
    );
    const call = vi
      .spyOn(h.fixture.needGenerationApi, "execute")
      .mockImplementation(async (request) => {
        await new Promise<void>((resolve) => {
          finish = resolve;
        });
        return original(request);
      });
    let pending!: Promise<void>;
    act(() => {
      pending = h.result.current.generate();
      void h.result.current.generate();
    });
    expect(h.result.current.operation.status).toBe("RUNNING");
    expect(h.result.current.canGenerate).toBe(false);
    expect(call).toHaveBeenCalledTimes(1);
    const event = new Event("beforeunload", { cancelable: true });
    window.dispatchEvent(event);
    expect(event.defaultPrevented).toBe(true);
    await act(async () => {
      finish();
    });
    expect(h.read).toHaveBeenCalledTimes(1);
    expect(h.result.current.operation.status).toBe("RUNNING");
    expect(h.result.current.canGenerate).toBe(false);
    await act(async () => {
      finishRead();
      await pending;
    });
    expect(h.result.current.operation.status).toBe("SUCCEEDED");
    expect(
      "message" in h.result.current.operation &&
        h.result.current.operation.message,
    ).toContain("6 dòng");
    expect(h.read).toHaveBeenCalledTimes(1);
    expect(h.result.current.workbench?.lines).toHaveLength(6);
  });
  it("locks unknown generation until authoritative recovery and never resubmits", async () => {
    const h = await ready("not_generated");
    h.execute.mockRejectedValue(new Error("connection lost"));
    await act(() => h.result.current.generate());
    expect(h.result.current.operation.status).toBe("UNKNOWN_OUTCOME");
    await act(() => h.result.current.generate());
    expect(h.execute).toHaveBeenCalledTimes(1);
    expect(h.result.current.canGenerate).toBe(false);
    await act(() => h.result.current.recover());
    expect(h.preflightRead).toHaveBeenCalledTimes(2);
    expect(h.result.current.operation.status).toBe("IDLE");
    expect(h.result.current.canGenerate).toBe(true);
  });
  it("shows a known retryable failure without retrying", async () => {
    const h = await ready("not_generated");
    h.execute.mockResolvedValue(
      reviewFailure("RETRYABLE_CONCURRENCY_FAILURE", "NO_COMMITTED_CHANGE"),
    );
    await act(() => h.result.current.generate());
    expect(h.result.current.operation.status).toBe("FAILED");
    expect(
      h.result.current.operation.status === "FAILED" &&
        h.result.current.operation.failureKind,
    ).toBe("retryable");
    expect(h.execute).toHaveBeenCalledTimes(1);
  });
  it("shows a deterministic business failure and preserves eligibility recovery", async () => {
    const h = await ready("not_generated");
    const failure = reviewFailure("CAPABILITY_DENIED", "NO_BUSINESS_WRITE");
    if (failure.kind === "backend_error") failure.error.retryable = false;
    h.execute.mockResolvedValue(failure);
    await act(() => h.result.current.generate());
    expect(h.result.current.operation.status).toBe("FAILED");
    expect(
      h.result.current.operation.status === "FAILED" &&
        h.result.current.operation.failureKind,
    ).toBe("business");
    expect(h.result.current.lock).toBe("eligibility");
    expect(h.execute).toHaveBeenCalledTimes(1);
  });
});

it("blocks eight dates without reads and preserves daily drafts when selecting a loaded day", async () => {
  const h = await ready();
  h.preflightRead.mockImplementation(async (_a, _c, day) => {
    const p = structuredClone(h.fixture.preflight);
    p.period_start = day;
    p.period_end = day;
    p.current_need!.confirmed_need_batch_id = `batch-${day}`;
    return reviewSuccess({ preflight: p });
  });
  h.read.mockImplementation(async (_a, _c, batch, filters) => {
    const b = structuredClone(h.fixture.batch);
    b.confirmed_need_batch_id = batch;
    b.service_period = {
      period_start: filters.service_date!,
      period_end: filters.service_date!,
    };
    b.lines.forEach((l) => {
      l.service_date = filters.service_date!;
      l.confirmed_need_line_id += filters.service_date;
    });
    return reviewSuccess({ workbench: b });
  });
  const calls = h.preflightRead.mock.calls.length;
  act(() =>
    h.result.current.changeRange({ start: reviewDate, end: "2026-09-14" }),
  );
  expect(h.result.current.rangeError).toBe("Chọn tối đa 7 ngày.");
  expect(h.preflightRead).toHaveBeenCalledTimes(calls);
  act(() =>
    h.result.current.changeRange({ start: reviewDate, end: "2026-09-08" }),
  );
  await waitFor(() => expect(h.result.current.rangeBusy).toBe(false));
  act(() =>
    h.result.current.edit("line-0", {
      exact_quantity: "12,5",
      quantity_entered: true,
    }),
  );
  const drafts = h.result.current.drafts;
  act(() => h.result.current.selectDay("2026-09-08"));
  act(() => h.result.current.selectDay(reviewDate));
  expect(h.result.current.drafts).toEqual(drafts);
  expect(h.result.current.dirty).toBe(true);
  expect(h.save).not.toHaveBeenCalled();
});

function multiDayHook(start = "2026-09-07", ungenerated?: string) {
  const fixture = createConfirmedNeedReviewFixture();
  const dayData = (date: string) => {
    const replace = <T,>(value: T): T =>
      JSON.parse(
        JSON.stringify(value)
          .replaceAll(reviewDate, date)
          .replaceAll("batch-current", `batch-${date}`)
          .replaceAll('"line-', `"${date}-line-`),
      );
    return {
      batch: replace(fixture.batch),
      preflight: replace(fixture.preflight),
      need: replace(fixture.need),
    };
  };
  const generated = new Set<string>();
  const preflightRead = vi
    .spyOn(fixture.preflightApi, "preflight")
    .mockImplementation(async (_a, _c, date) => {
      const { preflight } = dayData(date);
      if (date === ungenerated && !generated.has(date)) {
        preflight.current_need = null;
        preflight.downstream_currentness = "NOT_GENERATED";
      }
      return reviewSuccess({ preflight });
    });
  const read = vi
    .spyOn(fixture.confirmedNeedApi, "getReview")
    .mockImplementation(async (_a, _c, _b, filters) =>
      reviewSuccess({ workbench: dayData(filters.service_date!).batch }),
    );
  const save = vi
    .spyOn(fixture.confirmedNeedApi, "save")
    .mockImplementation(async (request) => {
      const date = request.payload.confirmed_need_batch_id.slice(6);
      const b = dayData(date).batch;
      b.batch_version++;
      return reviewSuccess({ authoritative_readback: b });
    });
  const execute = vi
    .spyOn(fixture.needGenerationApi, "execute")
    .mockImplementation(async (request) => {
      const date = request.payload.service_date;
      generated.add(date);
      const data = dayData(date);
      return reviewSuccess({
        authoritative_readback: {
          preflight: data.preflight,
          need_generation: data.need,
        },
      });
    });
  const hook = renderHook(() =>
    useConfirmedNeedWorkbench({
      ...fixture,
      authSubject: "operator",
      initialServiceDate: start,
    }),
  );
  return { ...hook, fixture, preflightRead, read, save, execute, dayData };
}
it.each([1, 2, 7])(
  "loads %i exact daily authorities across a week boundary",
  async (count) => {
    const h = multiDayHook("2026-09-12");
    await waitFor(() => expect(h.result.current.busy).toBe(false));
    const end = `2026-09-${11 + count}`;
    act(() => h.result.current.changeRange({ start: "2026-09-12", end }));
    await waitFor(() => expect(h.result.current.rangeBusy).toBe(false));
    expect(h.result.current.days).toHaveLength(count);
    expect(
      h.result.current.days.every(
        (d) =>
          d.workbench && d.workbench.service_period.period_start === d.date,
      ),
    ).toBe(true);
    expect(h.preflightRead.mock.calls.every((c) => c[2] === c[3])).toBe(true);
    expect(h.save).not.toHaveBeenCalled();
    expect(h.execute).not.toHaveBeenCalled();
  },
);
it("partitions one atomic local import across dates and saves only the active batch", async () => {
  const h = multiDayHook();
  await waitFor(() => expect(h.result.current.busy).toBe(false));
  act(() =>
    h.result.current.changeRange({ start: reviewDate, end: "2026-09-08" }),
  );
  await waitFor(() => expect(h.result.current.rangeBusy).toBe(false));
  const drafts = structuredClone(h.result.current.shoppingRangeContext.drafts);
  const changed = [`${reviewDate}-line-0`, "2026-09-08-line-0"];
  for (const id of changed)
    Object.assign(drafts[id]!, {
      exact_quantity: "12,5",
      quantity_entered: true,
      reason_code: "OTHER",
      reason_note: "Bếp yêu cầu",
    });
  act(() =>
    h.result.current.captureShoppingListImport()({
      drafts,
      changedLineIds: changed,
    }),
  );
  expect(h.result.current.days.filter((d) => d.dirty)).toHaveLength(2);
  expect(h.save).not.toHaveBeenCalled();
  expect(h.execute).not.toHaveBeenCalled();
  act(() => h.result.current.selectDay("2026-09-08"));
  expect(
    h.result.current.changedLines.map((l) => l.confirmed_need_line_id),
  ).toEqual([changed[1]]);
  await act(() => h.result.current.save());
  expect(h.save).toHaveBeenCalledTimes(1);
  expect(h.save.mock.calls[0]![0].payload.confirmed_need_batch_id).toBe(
    "batch-2026-09-08",
  );
  expect(
    h.save.mock.calls[0]![0].payload.lines.map((l) => l.confirmed_need_line_id),
  ).toEqual([changed[1]]);
  act(() => h.result.current.selectDay(reviewDate));
  expect(h.result.current.dirty).toBe(true);
  expect(h.result.current.drafts[changed[0]!]!.exact_quantity).toBe("12,5");
});
it("generates only the active date within a multi-day range", async () => {
  const h = multiDayHook(reviewDate, "2026-09-08");
  await waitFor(() => expect(h.result.current.busy).toBe(false));
  act(() =>
    h.result.current.changeRange({ start: reviewDate, end: "2026-09-08" }),
  );
  await waitFor(() => expect(h.result.current.rangeBusy).toBe(false));
  act(() => h.result.current.selectDay("2026-09-08"));
  expect(h.result.current.canGenerate).toBe(true);
  await act(() => h.result.current.generate());
  expect(h.execute).toHaveBeenCalledTimes(1);
  expect(h.execute.mock.calls[0]![0].payload.service_date).toBe("2026-09-08");
  expect(h.result.current.workbench?.service_period.period_start).toBe(
    "2026-09-08",
  );
  expect(h.save).not.toHaveBeenCalled();
});
it("ignores an obsolete background day read after changing range", async () => {
  const h = multiDayHook();
  await waitFor(() => expect(h.result.current.busy).toBe(false));
  let finish!: (r: ReturnType<typeof reviewSuccess>) => void;
  h.preflightRead.mockImplementationOnce(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      }),
  );
  act(() =>
    h.result.current.changeRange({ start: reviewDate, end: "2026-09-08" }),
  );
  act(() =>
    h.result.current.changeRange({ start: reviewDate, end: reviewDate }),
  );
  await act(async () =>
    finish(reviewSuccess({ preflight: h.dayData("2026-09-08").preflight })),
  );
  expect(h.result.current.days.map((d) => d.date)).toEqual([reviewDate]);
  expect(h.result.current.rangeBusy).toBe(false);
  expect(h.result.current.workbench?.service_period.period_start).toBe(
    reviewDate,
  );
});
it("guards leaving a dirty inactive date and preserves it when the operator cancels", async () => {
  const h = multiDayHook();
  await waitFor(() => expect(h.result.current.busy).toBe(false));
  act(() =>
    h.result.current.changeRange({ start: reviewDate, end: "2026-09-08" }),
  );
  await waitFor(() => expect(h.result.current.rangeBusy).toBe(false));
  act(() =>
    h.result.current.edit(`${reviewDate}-line-0`, {
      exact_quantity: "12,5",
      quantity_entered: true,
    }),
  );
  act(() => h.result.current.selectDay("2026-09-08"));
  const exit = vi.fn();
  act(() => h.result.current.requestExit(exit));
  expect(exit).not.toHaveBeenCalled();
  expect(h.result.current.pendingTransition).not.toBeNull();
  act(() => h.result.current.cancelTransition());
  act(() =>
    h.result.current.changeRange({ start: "2026-09-08", end: "2026-09-08" }),
  );
  expect(h.result.current.range.start).toBe(reviewDate);
  act(() => h.result.current.cancelTransition());
  act(() => h.result.current.selectDay(reviewDate));
  expect(h.result.current.dirty).toBe(true);
});

it("discards only dirty dates leaving the range and retains drafts inside it", async () => {
  const h = multiDayHook();
  await waitFor(() => expect(h.result.current.busy).toBe(false));
  act(() =>
    h.result.current.changeRange({ start: reviewDate, end: "2026-09-08" }),
  );
  await waitFor(() => expect(h.result.current.rangeBusy).toBe(false));
  act(() =>
    h.result.current.edit(`${reviewDate}-line-0`, {
      exact_quantity: "12,5",
      quantity_entered: true,
    }),
  );
  act(() => h.result.current.selectDay("2026-09-08"));
  act(() =>
    h.result.current.edit("2026-09-08-line-0", {
      exact_quantity: "13",
      quantity_entered: true,
    }),
  );
  act(() =>
    h.result.current.changeRange({ start: "2026-09-08", end: "2026-09-08" }),
  );
  expect(h.result.current.pendingTransition).not.toBeNull();
  act(() => h.result.current.discardTransition());
  expect(h.result.current.range).toEqual({
    start: "2026-09-08",
    end: "2026-09-08",
  });
  expect(h.result.current.drafts["2026-09-08-line-0"]!.exact_quantity).toBe(
    "13",
  );
  expect(h.result.current.dirty).toBe(true);
});

it("loads a shifted seven-day range and enables navigation from its first day", async () => {
  const h = multiDayHook();
  await waitFor(() => expect(h.result.current.busy).toBe(false));
  act(() =>
    h.result.current.changeRange({ start: "2026-09-10", end: "2026-09-16" }),
  );
  await waitFor(() =>
    expect(h.result.current.busy || h.result.current.rangeBusy).toBe(false),
  );
  expect(h.result.current.date).toBe("2026-09-10");
  expect(h.result.current.workbench?.service_period.period_start).toBe(
    "2026-09-10",
  );
  expect(h.result.current.editable).toBe(true);
  expect(h.result.current.days).toHaveLength(7);
});

it.each(["normal", "not_generated"] as const)(
  "blocks all old-scope commands and reads after an invalid range in %s",
  async (scenario) => {
    const h = await ready(scenario);
    if (scenario === "normal")
      act(() =>
        h.result.current.edit("line-0", {
          exact_quantity: "12,5",
          quantity_entered: true,
          reason_code: "OTHER",
          reason_note: "Bếp yêu cầu",
        }),
      );
    const before = h.result.current.workbench;
    const readCalls = h.read.mock.calls.length,
      preflightCalls = h.preflightRead.mock.calls.length;
    act(() =>
      h.result.current.changeRange({ start: reviewDate, end: "2026-09-14" }),
    );
    expect(h.result.current.rangeError).toBe("Chọn tối đa 7 ngày.");
    expect(h.result.current.editable).toBe(false);
    expect(h.result.current.canSave).toBe(false);
    expect(h.result.current.canGenerate).toBe(false);
    expect(h.result.current.canContinue).toBe(false);
    expect(h.result.current.shoppingRangeContext.isCurrent()).toBe(false);
    await act(async () => {
      await h.result.current.save();
      await h.result.current.generate();
      await h.result.current.recover();
      h.result.current.transition({ refresh: true });
      h.result.current.continueAllocation();
    });
    expect(h.read).toHaveBeenCalledTimes(readCalls);
    expect(h.preflightRead).toHaveBeenCalledTimes(preflightCalls);
    expect(h.save).not.toHaveBeenCalled();
    expect(h.execute).not.toHaveBeenCalled();
    expect(h.navigate).not.toHaveBeenCalled();
    expect(h.result.current.workbench).toBe(before);
    act(() =>
      h.result.current.changeRange({ start: reviewDate, end: reviewDate }),
    );
    expect(h.result.current.rangeError).toBeNull();
    expect(
      scenario === "normal"
        ? h.result.current.canSave
        : h.result.current.canGenerate,
    ).toBe(true);
  },
);

describe("released correction within the existing owner", () => {
  async function editing() {
    const h = await ready("released");
    act(() => h.result.current.openCorrection("line-0"));
    act(() =>
      h.result.current.updateCorrection({
        quantity: "12.500001",
        reason_code: "OTHER",
        reason_note: "Bếp yêu cầu",
      }),
    );
    return h;
  }
  async function reviewed() {
    const h = await editing();
    await act(() => h.result.current.previewCorrection());
    expect(h.result.current.correction?.preview).not.toBeNull();
    return h;
  }
  it("preserves ordinary released guard and sends one atomic correction followed by fresh read", async () => {
    const h = await reviewed(),
      command = vi.spyOn(h.fixture.confirmedNeedApi, "correct");
    const reads = h.read.mock.calls.length;
    await act(() => h.result.current.saveCorrection());
    expect(command).toHaveBeenCalledTimes(1);
    expect(h.save).not.toHaveBeenCalled();
    expect(h.read).toHaveBeenCalledTimes(reads + 1);
    expect(h.result.current.workbench?.lines[0]?.confirmed_quantity_after).toBe(
      "12.500001",
    );
    expect(h.result.current.workbench?.lines[1]?.current_revision_id).toBe(
      "revision-1",
    );
    expect(h.result.current.correction).toBeNull();
    expect(h.result.current.notice).toContain("Đã lưu điều chỉnh");
  });
  it("keeps full input and exact command while UNKNOWN locks context/close/exit", async () => {
    const h = await reviewed(),
      api = h.fixture.confirmedNeedApi,
      original = api.correct,
      call = vi
        .spyOn(api, "correct")
        .mockRejectedValueOnce(new Error("response lost"));
    await act(() => h.result.current.saveCorrection());
    const request = structuredClone(call.mock.calls[0]![0]);
    expect(h.result.current.lock).toBe("unknown");
    const exit = vi.fn();
    act(() => {
      h.result.current.updateCorrection({ quantity: "99" });
      h.result.current.closeCorrection();
      h.result.current.transition({ date: "2026-09-08" });
      h.result.current.requestExit(exit);
    });
    expect(exit).not.toHaveBeenCalled();
    expect(h.result.current.date).toBe(reviewDate);
    expect(h.result.current.correction?.quantity).toBe("12.500001");
    call.mockImplementation(original);
    await act(() => h.result.current.retryCorrection());
    expect(call.mock.calls[1]![0]).toEqual(request);
    expect(h.result.current.lock).toBeNull();
    expect(h.result.current.correction).toBeNull();
  });
  it("does not emit success or discard a committed request on readback failure, and recovers without another write", async () => {
    const h = await reviewed(),
      command = vi.spyOn(h.fixture.confirmedNeedApi, "correct");
    h.read.mockResolvedValueOnce(reviewFailure());
    await act(() => h.result.current.saveCorrection());
    expect(h.result.current.correction?.status).toBe("READBACK");
    expect(h.result.current.notice ?? "").not.toContain("Đã lưu điều chỉnh");
    expect(h.result.current.lock).toBe("unknown");
    await act(() => h.result.current.recover());
    expect(command).toHaveBeenCalledTimes(1);
    expect(h.result.current.correction).toBeNull();
  });
  it("accepts fresh later current data after replay instead of its frozen response", async () => {
    const h = await reviewed(),
      api = h.fixture.confirmedNeedApi,
      original = api.correct;
    const command = vi
      .spyOn(api, "correct")
      .mockImplementationOnce(async (request) => {
        await original(request);
        const line = h.fixture.batch.lines[0]!;
        await api.save(
          confirmedNeedSaveV2Request(
            "operator",
            "later",
            h.fixture.batch.confirmed_need_batch_id,
            h.fixture.batch.batch_version,
            [
              {
                confirmed_need_line_id: line.confirmed_need_line_id,
                expected_current_revision_id: line.current_revision_id,
                expected_current_decision_id: line.current_decision_id,
                proposed_confirmed_quantity: "13.000000",
                reason_code: "OTHER",
                reason_note: "Lưu thông thường sau điều chỉnh",
              },
            ],
          ),
        );
        throw new Error("committed response lost");
      });
    await act(() => h.result.current.saveCorrection());
    expect(h.result.current.correction?.status).toBe("UNKNOWN");
    const request = structuredClone(command.mock.calls[0]![0]);
    command.mockImplementation(original);
    await act(() => h.result.current.retryCorrection());
    expect(command.mock.calls[1]![0]).toEqual(request);
    expect(h.result.current.workbench?.batch_version).toBe(7);
    expect(h.result.current.workbench?.lines[0]?.confirmed_quantity_after).toBe(
      "13.000000",
    );
  });
  it("invalidates a proposal on edits and ignores a late preview", async () => {
    const h = await editing(),
      api = h.fixture.confirmedNeedApi;
    let resolve!: (result: ReturnType<typeof reviewSuccess>) => void;
    const original = api.previewCorrection,
      spy = vi.spyOn(api, "previewCorrection").mockImplementationOnce(
        () =>
          new Promise((r) => {
            resolve = r;
          }),
      );
    let pending!: Promise<void>;
    act(() => {
      pending = h.result.current.previewCorrection();
    });
    const delayed = await original(spy.mock.calls[0]![0]);
    act(() =>
      h.result.current.updateCorrection({
        reason_note: "Thay đổi sau xem trước",
      }),
    );
    await act(async () => {
      resolve(delayed as ReturnType<typeof reviewSuccess>);
      await pending;
    });
    expect(h.result.current.correction?.preview).toBeNull();
    expect(h.result.current.correction?.reason_note).toBe(
      "Thay đổi sau xem trước",
    );
  });
  it("guards dirty School/date/module transitions with Cancel and explicit discard", async () => {
    const h = await editing(),
      exit = vi.fn();
    act(() => h.result.current.transition({ schoolIds: ["school-1"] }));
    expect(h.result.current.pendingTransition).not.toBeNull();
    act(() => h.result.current.cancelTransition());
    expect(h.result.current.correction?.quantity).toBe("12.500001");
    expect(h.result.current.schoolIds).toEqual([]);
    act(() => h.result.current.requestExit(exit));
    act(() => h.result.current.discardTransition());
    expect(exit).toHaveBeenCalledTimes(1);
    expect(h.result.current.correction).toBeNull();
  });
  it("retains stale input, clears proposal and requires fresh authoritative refresh/review", async () => {
    const h = await reviewed();
    vi.spyOn(h.fixture.confirmedNeedApi, "correct").mockResolvedValueOnce(
      reviewFailure("STALE_CORRECTION_PROPOSAL", "NO_COMMITTED_CHANGE"),
    );
    await act(() => h.result.current.saveCorrection());
    expect(h.result.current.correction?.status).toBe("STALE");
    expect(h.result.current.correction?.preview).toBeNull();
    expect(h.result.current.correction?.quantity).toBe("12.500001");
    await act(() => h.result.current.recover());
    expect(h.result.current.correction?.status).toBe("EDITING");
    expect(h.result.current.correction?.preview).toBeNull();
  });
  it("keeps known retry exact and reports authority/reason denial without a write", async () => {
    const h = await reviewed(),
      spy = vi
        .spyOn(h.fixture.confirmedNeedApi, "correct")
        .mockResolvedValueOnce(
          reviewFailure("RETRYABLE_CONCURRENCY_FAILURE", "NO_COMMITTED_CHANGE"),
        );
    await act(() => h.result.current.saveCorrection());
    expect(h.result.current.correction?.status).toBe("RETRYABLE");
    const request = spy.mock.calls[0]![0];
    await act(() => h.result.current.retryCorrection());
    expect(spy.mock.calls[1]![0]).toEqual(request);
    const denied = await editing();
    vi.spyOn(
      denied.fixture.confirmedNeedApi,
      "previewCorrection",
    ).mockResolvedValueOnce(reviewFailure("CAPABILITY_DENIED", "NO_WRITE"));
    await act(() => denied.result.current.previewCorrection());
    expect(denied.result.current.correction?.preview).toBeNull();
    expect(denied.result.current.correction?.error).toBeTruthy();
  });
  it("returns focus only after completed fresh readback", async () => {
    const h = await ready("released"),
      trigger = document.createElement("button");
    document.body.append(trigger);
    act(() => h.result.current.openCorrection("line-0", trigger));
    act(() =>
      h.result.current.updateCorrection({
        quantity: "11",
        reason_note: "Bếp yêu cầu",
      }),
    );
    await act(() => h.result.current.previewCorrection());
    await act(() => h.result.current.saveCorrection());
    await waitFor(() => expect(document.activeElement).toBe(trigger));
    trigger.remove();
  });
  it("reason-code-only changes are dirty and incomplete reasons never invoke preview", async () => {
    const h = await ready("released"),
      spy = vi.spyOn(h.fixture.confirmedNeedApi, "previewCorrection");
    act(() => h.result.current.openCorrection("line-0"));
    act(() => h.result.current.updateCorrection({ reason_code: "OTHER" }));
    expect(h.result.current.allDirty).toBe(true);
    await act(() => h.result.current.previewCorrection());
    expect(spy).not.toHaveBeenCalled();
    expect(h.result.current.correction?.error).toBeTruthy();
  });
  it("guards correction during range and loaded-day navigation, retaining input on Cancel", async () => {
    const h = await ready("released");
    act(() =>
      h.result.current.changeRange({ start: reviewDate, end: "2026-09-08" }),
    );
    await waitFor(() => expect(h.result.current.rangeBusy).toBe(false));
    act(() => h.result.current.openCorrection("line-0"));
    act(() =>
      h.result.current.updateCorrection({
        quantity: "12",
        reason_note: "Bếp yêu cầu",
      }),
    );
    act(() => h.result.current.selectDay("2026-09-08"));
    expect(h.result.current.pendingTransition).not.toBeNull();
    expect(h.result.current.date).toBe(reviewDate);
    act(() => h.result.current.cancelTransition());
    expect(h.result.current.correction?.quantity).toBe("12");
    act(() =>
      h.result.current.changeRange({ start: reviewDate, end: reviewDate }),
    );
    expect(h.result.current.pendingTransition).not.toBeNull();
    expect(h.result.current.range.end).toBe("2026-09-08");
    act(() => h.result.current.discardTransition());
    expect(h.result.current.range.end).toBe(reviewDate);
    expect(h.result.current.correction).toBeNull();
  });
  it("ignores a preview returned after explicit dirty context discard", async () => {
    const h = await editing(),
      api = h.fixture.confirmedNeedApi,
      original = api.previewCorrection;
    let resolve!: (v: Awaited<ReturnType<typeof original>>) => void;
    const spy = vi
      .spyOn(api, "previewCorrection")
      .mockImplementationOnce(() => new Promise((r) => (resolve = r)));
    let pending!: Promise<void>;
    act(() => {
      pending = h.result.current.previewCorrection();
    });
    const result = await original(spy.mock.calls[0]![0]);
    act(() => h.result.current.transition({ schoolIds: ["school-1"] }));
    act(() => h.result.current.discardTransition());
    await act(async () => {
      resolve(result);
      await pending;
    });
    expect(h.result.current.correction).toBeNull();
    expect(h.result.current.schoolIds).toEqual(["school-1"]);
  });
  it("keeps a committed request locked when fresh read belongs to the wrong batch", async () => {
    const h = await reviewed();
    const wrong = structuredClone(h.fixture.batch);
    wrong.confirmed_need_batch_id = "other";
    h.read.mockResolvedValueOnce(reviewSuccess({ workbench: wrong }));
    await act(() => h.result.current.saveCorrection());
    expect(h.result.current.correction?.status).toBe("READBACK");
    expect(h.result.current.lock).toBe("unknown");
    await act(() => h.result.current.recover());
    expect(h.result.current.correction).toBeNull();
  });
});
