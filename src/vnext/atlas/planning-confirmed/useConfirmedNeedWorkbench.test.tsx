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
      10000,
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
    expect(h.navigate).toHaveBeenCalledWith("2026-09-08");
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
      expect(h.result.current.errors["line-0"]).toContain("2 chữ số");
      expect(h.result.current.canSave).toBe(false);
    },
  );
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
      expect(h.navigate).toHaveBeenCalledWith(reviewDate);
      expect(h.save).not.toHaveBeenCalled();
      expect(h.execute).not.toHaveBeenCalled();
    },
  );
});
