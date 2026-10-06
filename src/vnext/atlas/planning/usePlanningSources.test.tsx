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
  menuPreview,
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
  it("preserves invalid Menu cells through cancelled context/close changes and discards only on confirmation", async () => {
    const { result, fixture } = await setup();
    fixture.api.syncMenuFromGoogle = async () =>
      success({
        source: { source_name: "Google", sheet_name: "Tuần" },
        rows: [
          ["Tên trường", "Ngày", "Món mặn", "Món canh"],
          ["TH001", reviewWeek, "Món sai", "CANH2"],
          ["TH001", reviewWeek, "MAN1", "Canh sai"],
          ["Trường lạ", "31/02/2026", "MAN1", ""],
        ],
      });
    const preview = vi.spyOn(fixture.api, "previewMenu");
    const save = vi.spyOn(fixture.api, "saveCompletedMenu");
    await act(() => result.current.syncGoogle("google-1"));
    const rows = result.current.menuRows;
    const issues = result.current.menuSyncIssues;
    expect(issues.map((issue) => issue.code)).toEqual([
      "UNKNOWN_DISH",
      "UNKNOWN_DISH",
      "UNKNOWN_SCHOOL",
      "INVALID_SERVICE_DATE",
    ]);
    expect(preview).not.toHaveBeenCalled();
    const exit = vi.fn();
    act(() => result.current.requestExit(exit));
    expect(exit).not.toHaveBeenCalled();
    expect(result.current.pending?.exit).toBe(exit);
    act(() => result.current.cancelTransition());
    for (const next of [
      { week: "2026-09-14" },
      { date: "2026-09-08" },
      { schoolIds: ["school-1"] },
    ]) {
      act(() => result.current.transition(next));
      expect(result.current.pending).toEqual(next);
      act(() => result.current.cancelTransition());
      expect(result.current.menuRows).toEqual(rows);
      expect(result.current.menuSyncIssues).toEqual(issues);
      expect(result.current.dirty).toBe(true);
    }
    act(() => result.current.transition({ date: "2026-09-08" }));
    act(() => result.current.discardTransition());
    expect(result.current.date).toBe("2026-09-08");
    expect(result.current.dirty).toBe(false);
    expect(result.current.menuSyncIssues).toEqual([]);
    expect(result.current.menuRows).toEqual(
      fixture.planning.weekly_menu!.lines,
    );
    expect(save).not.toHaveBeenCalled();
  });
  it.each(["UNKNOWN_DISH", "AMBIGUOUS_DISH"])(
    "stops %s source identities before Preview and Save",
    async (code) => {
      const { result, fixture } = await setup();
      const name = "Món chưa rõ";
      if (code === "AMBIGUOUS_DISH")
        fixture.planning.dishes.push(
          ...["dup-1", "dup-2"].map((dish_id) => ({
            ...fixture.planning.dishes[0],
            dish_id,
            dish_code: dish_id,
            dish_name: name,
          })),
        );
      fixture.api.syncMenuFromGoogle = async () =>
        success({
          source: { source_name: "Google", sheet_name: "Tuần" },
          rows: [
            ["Tên trường", "Ngày", "Món mặn"],
            ["TH001", reviewWeek, name],
          ],
        });
      const preview = vi.spyOn(fixture.api, "previewMenu");
      const save = vi.spyOn(fixture.api, "saveCompletedMenu");
      await act(() => result.current.syncGoogle("google-1"));
      expect(preview).not.toHaveBeenCalled();
      expect(save).not.toHaveBeenCalled();
      expect(result.current.menuSyncIssues[0]).toMatchObject({
        code,
        source_value: name,
        menu_slot_name: "Món mặn",
        source_row_number: 4,
      });
      expect(result.current.menuNotification).toBeNull();
      expect(result.current.menuRows[0].dish_id).toBe(
        "unresolved:dish:món chưa rõ",
      );
      expect(result.current.dirty).toBe(true);
      expect(result.current.canEdit).toBe(true);
    },
  );
  it("retains valid neighbors and blocks programmatic review, Save and correction until a corrected resync", async () => {
    const { result, fixture } = await setup();
    const validSource = fixture.api.syncMenuFromGoogle;
    fixture.api.syncMenuFromGoogle = async () =>
      success({
        source: { source_name: "Google", sheet_name: "Tuần" },
        rows: [
          ["Tên trường", "Ngày", "Món mặn", "Món canh"],
          ["TH001", reviewWeek, "Món sai", "CANH2"],
        ],
      });
    const before = structuredClone(fixture.planning.weekly_menu);
    const preview = vi.spyOn(fixture.api, "previewMenu");
    const save = vi.spyOn(fixture.api, "saveCompletedMenu");
    const prepare = vi.spyOn(fixture.api, "prepareCorrection");
    await act(() => result.current.syncGoogle("google-1"));
    expect(result.current.menuRows.map((row) => row.dish_id)).toEqual([
      "unresolved:dish:món sai",
      "dish-2",
    ]);
    expect(result.current.menuSource.name).toBe("Google / Tuần");
    expect(result.current.dirty).toBe(true);
    expect(result.current.data?.weekly_menu).toEqual(before);
    await act(() => result.current.previewChanges());
    await act(() => result.current.save());
    await act(() =>
      result.current.prepareCorrection({
        need_generation_run_id: "unapproved-chain",
      } as never),
    );
    expect(preview).not.toHaveBeenCalled();
    expect(save).not.toHaveBeenCalled();
    expect(prepare).not.toHaveBeenCalled();
    for (const next of [
      { job: "attendance" },
      { week: "2026-09-14" },
      { refresh: true },
    ]) {
      act(() => result.current.transition(next));
      expect(result.current.pending).toEqual(next);
      act(() => result.current.cancelTransition());
      expect(result.current.dirty).toBe(true);
    }
    fixture.api.syncMenuFromGoogle = validSource;
    await act(() => result.current.syncGoogle("google-1"));
    expect(preview).toHaveBeenCalledOnce();
    expect(save).toHaveBeenCalledOnce();
    expect(save).toHaveBeenCalledWith(
      expect.objectContaining({
        contract_version: "RMVP-03A.v2",
        expected_version: 4,
        idempotency_key: expect.any(String),
        payload: expect.objectContaining({
          source_signature: "menu-preview",
          expected_source_signature: "menu-authority",
          rows: menuPreview().canonical_rows,
        }),
      }),
    );
    expect(result.current.menuRows).toEqual(menuPreview().canonical_rows);
    expect(result.current.data?.weekly_menu?.source_signature).toBe(
      "menu-preview",
    );
    expect(result.current.menuSyncIssues).toEqual([]);
    expect(result.current.errors).toEqual([]);
    expect(result.current.dirty).toBe(false);
  });
  it.each(["transport", "malformed", "structural"])(
    "preserves unresolved candidate and guards after a %s resync failure",
    async (failure) => {
      const { result, fixture } = await setup();
      fixture.api.syncMenuFromGoogle = async () =>
        success({
          source: { source_name: "Google", sheet_name: "Tuần" },
          rows: [
            ["Tên trường", "Ngày", "Món mặn", "Món canh"],
            ["TH001", reviewWeek, "Món sai", "CANH2"],
          ],
        });
      await act(() => result.current.syncGoogle("google-1"));
      const rows = result.current.menuRows;
      const issues = result.current.menuSyncIssues;
      fixture.api.syncMenuFromGoogle = async () =>
        failure === "transport"
          ? unknown
          : success(
              failure === "malformed"
                ? {}
                : {
                    source: { source_name: "Google", sheet_name: "Tuần" },
                    rows: [["Bad header"]],
                  },
            );
      const preview = vi.spyOn(fixture.api, "previewMenu");
      const save = vi.spyOn(fixture.api, "saveCompletedMenu");
      await act(() => result.current.syncGoogle("google-1"));
      expect(result.current.menuRows).toEqual(rows);
      expect(result.current.menuSyncIssues).toEqual(issues);
      expect(result.current.dirty).toBe(true);
      await act(() => result.current.previewChanges());
      await act(() => result.current.save());
      expect(preview).not.toHaveBeenCalled();
      expect(save).not.toHaveBeenCalled();
    },
  );
  it("retains a backend-blocked candidate with exact source evidence", async () => {
    const { result, fixture } = await setup();
    fixture.api.previewMenu = async () =>
      success({
        preview: {
          ...menuPreview(),
          can_save: false,
          issues: {
            warnings: [],
            blockers: [
              {
                code: "MISSING_RECIPE",
                message: "raw backend detail",
                source_row_reference: "Thực đơn chính thức:Tuần 37:row:4:soup",
              },
            ],
          },
        },
      });
    const save = vi.spyOn(fixture.api, "saveCompletedMenu");
    await act(() => result.current.syncGoogle("google-1"));
    expect(result.current.menuRows[0].dish_id).toBe("dish-2");
    expect(result.current.dirty).toBe(true);
    expect(result.current.menuSyncIssues[0]).toMatchObject({
      school_id: "school-0",
      service_date: reviewWeek,
      source_row_number: 4,
      source_value: "CANH2",
    });
    await act(() => result.current.previewChanges());
    await act(() => result.current.save());
    expect(save).not.toHaveBeenCalled();
  });
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
    expect(result.current.outcome).not.toContain("Đã hoàn tất");
    expect(result.current.locked).toBe(true);
  });
  it.each(["pantry"])(
    "protects all context transitions for dirty %s drafts",
    async (job) => {
      const { result } = await setup();
      act(() => result.current.transition({ job }));
      act(() => result.current.requestNoAdditions(true));
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
  it("ends Menu synchronization without a local dirty candidate", async () => {
    const { result } = await setup();
    await act(() => result.current.syncGoogle("google-1"));
    expect(result.current.dirty).toBe(false);
    expect(result.current.preview).toBeNull();
    act(() => result.current.transition({ job: "attendance" }));
    expect(result.current.pending).toBeNull();
    expect(result.current.job).toBe("attendance");
  });
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
  it("clears Google sync state when its response becomes obsolete without a replacement sync", async () => {
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
    expect(result.current.syncing).toBe(true);
    act(() => result.current.editAttendance(0, "student_portions", "0"));
    await act(async () => {
      resolve(response);
      await pending;
    });
    expect(result.current.syncing).toBe(false);
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
  it.each(["attendance", "pantry"])(
    "honors correction authority for %s and re-previews after preparation",
    async (job) => {
      const { result, fixture } = await setup();
      act(() => result.current.transition({ job }));
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
  it("exposes governed correction detail only after the Menu Save is rejected", async () => {
    const { result, fixture } = await setup();
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
    fixture.api.saveCompletedMenu = async () => ({
      kind: "backend_error",
      error: {
        success: false,
        error_code: "PLANNING_RELEASE_CORRECTION_REQUIRED",
        retryable: false,
        safe_message: "Cần chuẩn bị hiệu chỉnh.",
      },
    });
    const impact = vi
      .spyOn(fixture.api, "getCorrectionImpact")
      .mockResolvedValue(
        success({
          impact: {
            ...safeImpact,
            save_allowed: false,
            save_blocker_code: "PLANNING_RELEASE_CORRECTION_REQUIRED",
            date_impacts: [
              {
                service_date: reviewWeek,
                correction_policy: "PLANNING_RELEASE_CORRECTION_REQUIRED",
                operator_message: "Cần mở lại cam kết.",
                chains: [chain],
              },
            ],
          },
        }),
      );
    const prepare = vi.spyOn(fixture.api, "prepareCorrection");

    await act(() => result.current.syncGoogle("google-1"));
    expect(impact).toHaveBeenCalledOnce();
    expect(result.current.impact?.save_allowed).toBe(false);
    expect(result.current.menuRows[0].dish_id).toBe("dish-2");
    expect(result.current.data?.weekly_menu?.lines[0].dish_id).toBe("dish-1");
    expect(result.current.dirty).toBe(true);
    expect(result.current.menuNotification).toBeNull();
    await act(() => result.current.prepareCorrection(chain));
    expect(prepare).toHaveBeenCalledOnce();
    expect(result.current.impact).toBeNull();
    expect(result.current.outcome).toContain("Đã chuẩn bị hiệu chỉnh");
  });
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
  it("performs fetch, preview and canonical Save from one Google action", async () => {
    const { result, fixture } = await setup();
    const fetch = vi.spyOn(fixture.api, "syncMenuFromGoogle");
    const preview = vi.spyOn(fixture.api, "previewMenu");
    const save = vi.spyOn(fixture.api, "saveCompletedMenu");
    act(() => result.current.transition({ schoolIds: ["school-1"] }));
    await act(() => result.current.syncGoogle("google-1"));
    expect(fetch).toHaveBeenCalledOnce();
    expect(preview).toHaveBeenCalledOnce();
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
    expect(result.current.menuRows[0].dish_id).toBe("dish-2");
    expect(result.current.dirty).toBe(false);
    expect(result.current.preview).toBeNull();
  });
  it("stops parser and backend preview blockers before Save", async () => {
    const { result, fixture } = await setup();
    const preview = vi.spyOn(fixture.api, "previewMenu");
    const save = vi.spyOn(fixture.api, "saveCompletedMenu");
    fixture.api.syncMenuFromGoogle = async () =>
      success({
        source: { source_name: "Thực đơn chính thức", sheet_name: "Tuần 37" },
        rows: [["Không có tiêu đề hợp lệ"]],
      });
    await act(() => result.current.syncGoogle("google-1"));
    expect(preview).not.toHaveBeenCalled();
    expect(save).not.toHaveBeenCalled();

    fixture.api.syncMenuFromGoogle =
      createPlanningReviewFixture().api.syncMenuFromGoogle;
    fixture.api.previewMenu = async () =>
      success({
        preview: {
          ...menuPreview(),
          can_save: false,
          issues: {
            blockers: [
              { code: "UNKNOWN_DISH", message: "Món chưa nhận diện." },
            ],
            warnings: [],
          },
        },
      });
    await act(() => result.current.syncGoogle("google-1"));
    expect(save).not.toHaveBeenCalled();
    expect(result.current.errors).toContain(
      "Không tìm thấy món này trong danh mục Atlas.",
    );
  });
  it("keeps additions quiet and announces replacement/removal only after readback", async () => {
    const { result, fixture } = await setup();
    const before = fixture.planning.weekly_menu!.lines;
    const after = before
      .slice(1)
      .map((row, index) => (index === 0 ? { ...row, dish_id: "dish-2" } : row));
    fixture.api.previewMenu = async () =>
      success({
        preview: {
          ...menuPreview(),
          canonical_rows: after,
          row_count: after.length,
        },
      });
    const readback = structuredClone(fixture.planning);
    readback.weekly_menu!.lines = after;
    readback.weekly_menu!.source_signature = "menu-preview";
    fixture.api.saveCompletedMenu = async () =>
      success({ authoritative_readback: { planning_inputs: readback } });
    await act(() => result.current.syncGoogle("google-1"));
    expect(result.current.menuNotification?.description).toBe(
      "1 món đã được thay đổi · 1 món đã được bỏ.",
    );

    const added = [...after, { ...before[0], menu_slot_code: "main" }];
    fixture.api.previewMenu = async () =>
      success({
        preview: {
          ...menuPreview(),
          canonical_rows: added,
          row_count: added.length,
        },
      });
    const addedReadback = structuredClone(readback);
    addedReadback.weekly_menu!.lines = added;
    fixture.api.saveCompletedMenu = async () =>
      success({ authoritative_readback: { planning_inputs: addedReadback } });
    act(() => result.current.dismissMenuNotification());
    await act(() => result.current.syncGoogle("google-1"));
    expect(result.current.menuNotification).toBeNull();
  });
  it("saves an exact NO_CHANGE candidate without a popup", async () => {
    const { result, fixture } = await setup();
    fixture.api.previewMenu = async () =>
      success({
        preview: {
          ...menuPreview(),
          canonical_rows: fixture.planning.weekly_menu!.lines,
          row_count: fixture.planning.weekly_menu!.lines.length,
        },
      });
    const save = vi.spyOn(fixture.api, "saveCompletedMenu");
    await act(() => result.current.syncGoogle("google-1"));
    expect(save).toHaveBeenCalledOnce();
    expect(result.current.menuNotification).toBeNull();
    expect(result.current.menuSyncedAt).not.toBe("");
  });
  it.each([stale, success({})])(
    "locks stale or missing authoritative readback and retains failed recovery",
    async (response) => {
      const { result, fixture } = await setup();
      fixture.api.saveCompletedMenu = async () => response;
      await act(() => result.current.syncGoogle("google-1"));
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
  it("resolves an uncertain Save with one authoritative read and no blind retry", async () => {
    const { result, fixture } = await setup();
    fixture.api.saveCompletedMenu = async () => unknown;
    const save = vi.spyOn(fixture.api, "saveCompletedMenu");
    const read = vi.spyOn(fixture.api, "getWorkbench");
    await act(() => result.current.syncGoogle("google-1"));
    expect(save).toHaveBeenCalledOnce();
    expect(read).toHaveBeenCalledOnce();
    expect(result.current.locked).toBe(false);
    expect(result.current.outcome).toContain("chưa được xác nhận");
    expect(result.current.menuNotification).toBeNull();
  });
  it("keeps matching transport-uncertain readback quiet and never retries Save", async () => {
    const { result, fixture } = await setup();
    fixture.api.saveCompletedMenu = async () => unknown;
    const reconciled = structuredClone(fixture.planning);
    reconciled.weekly_menu!.lines = menuPreview().canonical_rows;
    fixture.api.getWorkbench = async () => success({ workbench: reconciled });
    const save = vi.spyOn(fixture.api, "saveCompletedMenu");
    await act(() => result.current.syncGoogle("google-1"));
    expect(save).toHaveBeenCalledOnce();
    expect(result.current.outcome).toContain("không tự lưu lần nữa");
    expect(result.current.menuNotification).toBeNull();
    expect(result.current.menuSyncedAt).toBe("");
  });
  it("does not request correction impact for unrelated Save failures", async () => {
    const { result, fixture } = await setup();
    fixture.api.saveCompletedMenu = async () => ({
      kind: "backend_error",
      error: {
        success: false,
        error_code: "PERMISSION_DENIED",
        retryable: false,
        safe_message: "Không có quyền lưu.",
      },
    });
    const impact = vi.spyOn(fixture.api, "getCorrectionImpact");
    await act(() => result.current.syncGoogle("google-1"));
    expect(impact).not.toHaveBeenCalled();
    expect(result.current.menuNotification).toBeNull();
  });
  it("treats a successful Save with mismatched readback as uncertain", async () => {
    const { result, fixture } = await setup();
    fixture.api.saveCompletedMenu = async () =>
      success({
        authoritative_readback: { planning_inputs: fixture.planning },
      });
    await act(() => result.current.syncGoogle("google-1"));
    expect(result.current.locked).toBe(true);
    expect(result.current.menuNotification).toBeNull();
    expect(result.current.outcome).toContain("không khớp");
  });
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
