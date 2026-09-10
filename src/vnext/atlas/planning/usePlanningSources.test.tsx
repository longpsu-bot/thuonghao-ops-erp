import { act, cleanup, renderHook, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { usePlanningSources } from "./usePlanningSources";
import {
  createPlanningReviewFixture,
  reviewWeek,
  success,
  unknown,
  stale,
  safeImpact,
} from "./planningReviewFixtures";
afterEach(cleanup);
async function setup() {
  const fixture = createPlanningReviewFixture();
  const props = {
    ...fixture,
    authSubject: "operator",
    initialWeek: reviewWeek,
  };
  const hook = renderHook(() => usePlanningSources(props));
  await waitFor(() => expect(hook.result.current.data).not.toBeNull());
  return { ...hook, fixture };
}
describe("Planning source safety", () => {
  it("retains the authoritative default Attendance source metadata", async () => {
    const { result, fixture } = await setup();
    fixture.planning.attendance = null;
    act(() => result.current.transition({ job: "attendance" }));
    const save = vi.spyOn(fixture.api, "saveCompletedAttendance");
    await act(() => result.current.previewChanges());
    await act(() => result.current.save());
    expect(save).toHaveBeenCalledWith(
      expect.objectContaining({
        payload: expect.objectContaining({
          source_type: "SCHOOL_DEFAULTS",
          source_name: "Mặc định theo Thực đơn tuần",
        }),
      }),
    );
  });
  it.each(["inline", "paste"])(
    "retains legacy Attendance source metadata for %s",
    async (mode) => {
      const { result, fixture } = await setup();
      const save = vi.spyOn(fixture.api, "saveCompletedAttendance");
      act(() => result.current.transition({ job: "attendance" }));
      if (mode === "paste")
        act(() => result.current.pasteAttendance("TH001\t2026-09-07\t0\t12"));
      else act(() => result.current.editAttendance(0, "student_portions", "0"));
      await act(() => result.current.previewChanges());
      await act(() => result.current.save());
      expect(save).toHaveBeenCalledWith(
        expect.objectContaining({
          payload: expect.objectContaining({
            source_type: mode === "paste" ? "BULK_PASTE" : "MANUAL",
            source_name:
              mode === "paste"
                ? "Dán hàng loạt Atlas"
                : "Chỉnh sửa trực tiếp Atlas",
          }),
        }),
      );
    },
  );
  it("treats malformed success envelopes as unavailable authority, never as a saved result", async () => {
    const { result, fixture } = await setup();
    fixture.api.previewMenu = async () => success({});
    await act(() => result.current.syncGoogle("google-1"));
    await act(() => result.current.previewChanges());
    expect(result.current.outcome).not.toContain("Đã hoàn tất");
    expect(result.current.locked).toBe(true);
  });
  it.each(["menu", "pantry"])(
    "protects all context transitions for %s",
    async (job) => {
      const { result } = await setup();
      act(() => result.current.transition({ job }));
      if (job === "menu")
        await act(() => result.current.syncGoogle("google-1"));
      else act(() => result.current.requestNoAdditions(true));
      for (const next of [
        { job: "attendance" },
        { week: "2026-09-14" },
        { date: "2026-09-08" },
        { schoolIds: ["school-1"] },
        { refresh: true },
      ]) {
        act(() => result.current.transition(next));
        expect(result.current.pending).toEqual(next);
        act(() => result.current.cancelTransition());
        expect(result.current.dirty).toBe(true);
        expect(result.current.week).toBe(reviewWeek);
      }
    },
  );
  it("suppresses an obsolete Google response after context changes", async () => {
    const { result, fixture } = await setup();
    let resolve!: (r: ReturnType<typeof success>) => void;
    const response = await fixture.api.syncMenuFromGoogle();
    fixture.api.syncMenuFromGoogle = () =>
      new Promise((r) => {
        resolve = r;
      });
    let pending!: Promise<void>;
    act(() => {
      pending = result.current.syncGoogle("google-1");
    });
    act(() => result.current.transition({ date: "2026-09-08" }));
    await act(async () => {
      resolve(response);
      await pending;
    });
    expect(result.current.menuRows[0].dish_id).toBe("dish-1");
    expect(result.current.dirty).toBe(false);
  });
  it("does not let an older read overwrite a later refresh", async () => {
    const { result, fixture } = await setup();
    let resolve!: (r: ReturnType<typeof success>) => void;
    fixture.api.getWorkbench = () =>
      new Promise((r) => {
        resolve = r;
      });
    act(() => result.current.transition({ refresh: true }));
    const newer = structuredClone(fixture.planning);
    newer.schools[0].school_name = "Trường mới";
    fixture.api.getWorkbench = async () => success({ workbench: newer });
    await act(() => result.current.recover());
    await act(async () => resolve(success({ workbench: fixture.planning })));
    expect(result.current.data?.schools[0].school_name).toBe("Trường mới");
  });
  it("saves Attendance through v2 with exact preview rows and adopts readback", async () => {
    const { result, fixture } = await setup();
    const save = vi.spyOn(fixture.api, "saveCompletedAttendance");
    act(() => result.current.transition({ job: "attendance" }));
    act(() => result.current.editAttendance(0, "student_portions", "0"));
    await act(() => result.current.previewChanges());
    await act(() => result.current.save());
    expect(save).toHaveBeenCalledWith(
      expect.objectContaining({
        contract_version: "RMVP-03A.v2",
        expected_version: 3,
        payload: expect.objectContaining({
          source_signature: "attendance-preview",
          expected_source_signature: "attendance-authority",
          rows: [
            expect.objectContaining({
              student_portions: 0,
              teacher_portions: 12,
            }),
          ],
        }),
      }),
    );
    expect(result.current.attendanceRows[0].student_portions).toBe("100");
    expect(result.current.dirty).toBe(false);
  });
  it("saves exact Pantry quantities and one School/date mode through v3", async () => {
    const { result, fixture } = await setup();
    const save = vi.spyOn(fixture.pantryApi, "saveCompleted");
    const preview = vi.spyOn(fixture.pantryApi, "preview");
    act(() => result.current.transition({ job: "pantry" }));
    act(() => result.current.addPantryRow("school-0"));
    act(() => result.current.addPantryRow("school-0"));
    act(() =>
      result.current.editPantryRow(0, {
        ingredient_id: "ingredient-1",
        pantry_need_purpose_id: "purpose-1",
        requested_quantity: "123456789.123456",
        note: "Bữa phụ",
      }),
    );
    act(() => result.current.removePantryRow(1));
    act(() => result.current.setMode("school-0", "COMPLETE"));
    expect(result.current.modes).toEqual([
      {
        school_id: "school-0",
        service_date: reviewWeek,
        direct_need_mode: "COMPLETE",
      },
    ]);
    await act(() => result.current.previewChanges());
    await act(() => result.current.save());
    expect(preview).toHaveBeenCalled();
    expect(save).toHaveBeenCalledWith(
      expect.objectContaining({
        contract_version: "PANTRY-02.v3",
        payload: expect.objectContaining({
          no_additions_confirmed: false,
          rows: expect.arrayContaining([
            expect.objectContaining({ requested_quantity: "123456789.123456" }),
          ]),
          school_date_modes: [
            {
              school_id: "school-0",
              service_date: reviewWeek,
              direct_need_mode: "COMPLETE",
            },
          ],
        }),
      }),
    );
    expect(result.current.pantryRows).toEqual([]);
    expect(result.current.dirty).toBe(false);
  });
  it.each(["menu", "attendance", "pantry"])(
    "honors correction authority for %s and re-previews after preparation",
    async (job) => {
      const { result, fixture } = await setup();
      act(() => result.current.transition({ job }));
      if (job === "menu")
        await act(() => result.current.syncGoogle("google-1"));
      if (job === "attendance")
        act(() => result.current.editAttendance(0, "student_portions", "0"));
      if (job === "pantry") act(() => result.current.requestNoAdditions(true));
      const api = job === "pantry" ? fixture.pantryApi : fixture.api;
      const chain = {
        need_generation_run_id: "chain-1",
        need_generation_run_version: 7,
        run_status: "COMPLETED",
        period_start: reviewWeek,
        period_end: reviewWeek,
        is_legacy_range: false,
        confirmed_need_batch_id: "confirmed-1",
        confirmed_need_batch_version: 8,
        confirmed_need_status: "RELEASED_FOR_PURCHASE_HANDOFF",
        planning_release_occurred: true,
        active_purchase_handoff_exists: false,
        later_downstream_commitment_exists: false,
      };
      api.getCorrectionImpact = async () =>
        success({
          impact: {
            ...safeImpact,
            save_allowed: false,
            date_impacts: [
              {
                service_date: reviewWeek,
                correction_policy: "PLANNING_RELEASE_CORRECTION_REQUIRED",
                operator_message: "Cần mở lại cam kết.",
                chains: [chain],
              },
            ],
          },
        });
      const prepare = vi
        .spyOn(api, "prepareCorrection")
        .mockImplementation(async () => {
          api.getCorrectionImpact = async () => success({ impact: safeImpact });
          return success({});
        });
      await act(() => result.current.previewChanges());
      expect(result.current.impact?.save_allowed).toBe(false);
      await act(() => result.current.prepareCorrection(chain));
      expect(prepare).toHaveBeenCalledWith(
        "operator",
        expect.any(String),
        chain,
        expect.any(String),
      );
      expect(result.current.impact?.save_allowed).toBe(true);
    },
  );
  it.each(["attendance", "pantry"])(
    "locks %s unknown writes until explicit successful recovery",
    async (job) => {
      const { result, fixture } = await setup();
      act(() => result.current.transition({ job }));
      if (job === "attendance") {
        act(() => result.current.editAttendance(0, "student_portions", "0"));
        fixture.api.saveCompletedAttendance = async () => unknown;
      } else {
        act(() => result.current.requestNoAdditions(true));
        fixture.pantryApi.saveCompleted = async () => unknown;
      }
      await act(() => result.current.previewChanges());
      await act(() => result.current.save());
      expect(result.current.locked).toBe(true);
      act(() => result.current.transition({ refresh: true }));
      await waitFor(() => expect(result.current.pending).not.toBeNull());
      act(() => result.current.discardTransition());
      await waitFor(() => expect(result.current.loading).toBe(false));
      expect(result.current.locked).toBe(true);
      await act(() => result.current.recover());
      expect(result.current.locked).toBe(false);
    },
  );
  it("normalizes week and keeps service date inside it", async () => {
    const { result } = await setup();
    act(() => result.current.transition({ week: "2026-09-17" }));
    expect(result.current.week).toBe("2026-09-14");
    expect(result.current.date).toBe("2026-09-14");
  });
  it.each([
    { job: "menu" },
    { week: "2026-09-14" },
    { date: "2026-09-08" },
    { schoolIds: ["school-1"] },
    { refresh: true },
  ])("protects and discards attendance edits for %o", async (next) => {
    const { result } = await setup();
    act(() => result.current.transition({ job: "attendance" }));
    act(() => result.current.editAttendance(0, "student_portions", "0"));
    act(() => result.current.transition(next));
    expect(result.current.pending).not.toBeNull();
    act(() => result.current.cancelTransition());
    expect(result.current.attendanceRows[0].student_portions).toBe("0");
    expect(result.current.job).toBe("attendance");
    act(() => result.current.transition(next));
    act(() => result.current.discardTransition());
    expect(result.current.dirty).toBe(false);
  });
  it("fetches Google into a local candidate, previews and saves exact canonical authority", async () => {
    const { result, fixture } = await setup();
    const save = vi.spyOn(fixture.api, "saveCompletedMenu");
    await act(() => result.current.syncGoogle("google-1"));
    expect(result.current.dirty).toBe(true);
    expect(save).not.toHaveBeenCalled();
    await act(() => result.current.previewChanges());
    await act(() => result.current.save());
    expect(save).toHaveBeenCalledWith(
      expect.objectContaining({
        expected_version: 4,
        contract_version: "RMVP-03A.v2",
        payload: expect.objectContaining({
          source_signature: "menu-preview",
          expected_source_signature: "menu-authority",
          source_type: "GOOGLE_SHEET",
          rows: [
            expect.objectContaining({
              dish_id: "dish-2",
              source_row_reference: "official:4",
            }),
          ],
        }),
      }),
    );
    expect(result.current.menuRows[0].dish_id).toBe("dish-1");
    expect(result.current.dirty).toBe(false);
  });
  it.each([unknown, stale, success({})])(
    "locks uncertain/stale/missing readback and retains failed recovery",
    async (response) => {
      const { result, fixture } = await setup();
      fixture.api.saveCompletedMenu = async () => response;
      await act(() => result.current.syncGoogle("google-1"));
      await act(() => result.current.previewChanges());
      await act(() => result.current.save());
      expect(result.current.locked).toBe(true);
      fixture.api.getWorkbench = async () => unknown;
      await act(() => result.current.recover());
      expect(result.current.locked).toBe(true);
      expect(result.current.readError).toBeTruthy();
      fixture.api.getWorkbench = async () =>
        success({ workbench: fixture.planning });
      await act(() => result.current.recover());
      expect(result.current.locked).toBe(false);
    },
  );
  it("preserves zero, rejects malformed counts, and keeps unresolved paste errors", async () => {
    const { result } = await setup();
    act(() => result.current.transition({ job: "attendance" }));
    act(() => result.current.editAttendance(0, "student_portions", "oops"));
    expect(result.current.errors.length).toBeGreaterThan(0);
    act(() => result.current.editAttendance(0, "student_portions", "0"));
    expect(result.current.errors).toEqual([]);
    act(() => result.current.pasteAttendance("Unknown\t2026-09-07\tx\t0"));
    expect(result.current.errors.length).toBeGreaterThan(0);
  });
  it("requires an explicit whole-week no-additions decision and protects existing rows", async () => {
    const { result } = await setup();
    act(() => result.current.transition({ job: "pantry" }));
    expect(result.current.noAdditions).toBe(false);
    act(() => result.current.addPantryRow("school-0"));
    act(() => result.current.requestNoAdditions(true));
    expect(result.current.pending).not.toBeNull();
    act(() => result.current.cancelTransition());
    expect(result.current.pantryRows).toHaveLength(1);
    act(() => result.current.requestNoAdditions(true));
    act(() => result.current.discardTransition());
    expect(result.current.noAdditions).toBe(true);
    expect(result.current.pantryRows).toEqual([]);
  });
});
