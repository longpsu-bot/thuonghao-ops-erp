import { act, cleanup, renderHook, waitFor } from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import { usePlanningSources, type PlanningJob } from "./usePlanningSources";
import {
  createPlanningReviewFixture,
  reviewWeek,
  success,
  unknown,
  stale,
} from "./planningReviewFixtures";
afterEach(cleanup);

it.each(["menu", "attendance", "pantry"] as PlanningJob[])(
  "keeps %s actionable and confirms its save without sibling authority",
  async (job) => {
    const f = createPlanningReviewFixture();
    const sibling = job === "pantry" ? f.api : f.pantryApi;
    sibling.getWorkbench = async () => unknown;
    const { result } = renderHook(() =>
      usePlanningSources({
        ...f,
        authSubject: "operator",
        initialWeek: reviewWeek,
        initialJob: job,
      }),
    );
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.canEdit).toBe(true);
    expect(result.current.readError).toBe("");
    if (job === "menu") await act(() => result.current.syncGoogle("google-1"));
    else if (job === "attendance")
      act(() => result.current.editAttendance(0, "student_portions", "0"));
    else act(() => result.current.requestNoAdditions(true));
    expect(result.current.candidate).toBe(true);
    await act(() => result.current.previewChanges());
    expect(result.current.preview?.can_save).toBe(true);
    await act(() => result.current.save());
    expect(result.current.outcome).toBe("Đã lưu.");
    expect(result.current.locked).toBe(false);
    act(() =>
      result.current.transition({ job: job === "pantry" ? "menu" : "pantry" }),
    );
    expect(result.current.readError).not.toBe("");
    expect(result.current.canEdit).toBe(false);
  },
);

it("uses each job catalogue and preserves a subset through a sibling failure and recovery", async () => {
  const f = createPlanningReviewFixture();
  f.pantry.schools = f.pantry.schools.slice(0, 2);
  f.pantry.schools[0].school_name = "Pantry catalogue";
  f.pantryApi.getWorkbench = async () => unknown;
  const planningRead = vi.spyOn(f.api, "getWorkbench");
  const { result } = renderHook(() =>
    usePlanningSources({
      ...f,
      authSubject: "operator",
      initialWeek: reviewWeek,
    }),
  );
  await waitFor(() => expect(result.current.loading).toBe(false));
  act(() => result.current.transition({ schoolIds: ["school-0"] }));
  act(() => result.current.transition({ job: "pantry" }));
  expect(result.current.schoolIds).toEqual(["school-0"]);
  expect(result.current.recoveryKind).toBe("READ_FAILURE");
  f.pantryApi.getWorkbench = async () => success({ workbench: f.pantry });
  await act(() => result.current.recover());
  expect(planningRead).toHaveBeenCalledTimes(1);
  expect(result.current.schools[0].school_name).toBe("Pantry catalogue");
  expect(result.current.schoolIds).toEqual(["school-0"]);
  expect(result.current.canEdit).toBe(true);
  act(() => result.current.transition({ job: "menu" }));
  expect(result.current.schools[0].school_name).toBe(
    f.planning.schools[0].school_name,
  );
});

it.each(["menu", "pantry"] as PlanningJob[])(
  "suppresses older %s reads without waiting for the sibling",
  async (job) => {
    const f = createPlanningReviewFixture();
    const target = job === "pantry" ? f.pantryApi : f.api;
    const authority = job === "pantry" ? f.pantry : f.planning;
    let resolve!: (r: ReturnType<typeof success>) => void;
    target.getWorkbench = () =>
      new Promise((r) => {
        resolve = r;
      });
    const { result } = renderHook(() =>
      usePlanningSources({
        ...f,
        authSubject: "operator",
        initialWeek: reviewWeek,
        initialJob: job,
      }),
    );
    const newer = structuredClone(authority);
    newer.schools[0].school_name = "New authority";
    target.getWorkbench = async () => success({ workbench: newer });
    await act(() => result.current.recover());
    await act(async () => resolve(success({ workbench: authority })));
    expect(result.current.schools[0].school_name).toBe("New authority");
    expect(result.current.canEdit).toBe(true);
  },
);

it("guards the whole-week decision under a subset, including clearing it", async () => {
  const f = createPlanningReviewFixture();
  const { result } = renderHook(() =>
    usePlanningSources({
      ...f,
      authSubject: "operator",
      initialWeek: reviewWeek,
      initialJob: "pantry",
    }),
  );
  await waitFor(() => expect(result.current.canEdit).toBe(true));
  act(() => result.current.transition({ schoolIds: ["school-0"] }));
  act(() => result.current.requestNoAdditions(true));
  expect(result.current.noAdditions).toBe(false);
  expect(result.current.dirty).toBe(false);
  expect(result.current.pending).toBeNull();
  act(() => result.current.transition({ schoolIds: [] }));
  act(() => result.current.requestNoAdditions(true));
  expect(result.current.noAdditions).toBe(true);
});

it.each([
  ["REQUIRED", "   ", "Cần ghi chú cho mục đích này."],
  ["PROHIBITED", "Operator text", "Mục đích này không cho phép ghi chú."],
] as const)(
  "blocks %s notes without erasing text",
  async (rule, note, error) => {
    const f = createPlanningReviewFixture();
    f.pantry.purposes[0].note_rule = rule;
    const preview = vi.spyOn(f.pantryApi, "preview");
    const { result } = renderHook(() =>
      usePlanningSources({
        ...f,
        authSubject: "operator",
        initialWeek: reviewWeek,
        initialJob: "pantry",
      }),
    );
    await waitFor(() => expect(result.current.canEdit).toBe(true));
    act(() => result.current.addPantryRow("school-0"));
    expect(result.current.errors).toHaveLength(3);
    act(() =>
      result.current.editPantryRow(0, {
        ingredient_id: "ingredient-1",
        pantry_need_purpose_id: "purpose-1",
        requested_quantity: "1.000",
        note,
      }),
    );
    expect(result.current.errors.join()).toContain(error);
    await act(() => result.current.previewChanges());
    expect(preview).not.toHaveBeenCalled();
    expect(result.current.pantryRows[0].note).toBe(note);
    act(() =>
      result.current.editPantryRow(0, {
        note: rule === "REQUIRED" ? "Explicit note" : "",
      }),
    );
    expect(result.current.errors).toEqual([]);
    await act(() => result.current.previewChanges());
    expect(preview).toHaveBeenCalledTimes(1);
  },
);

it.each([
  [stale, "STALE"],
  [unknown, "UNKNOWN_OR_MISSING_READBACK"],
] as const)(
  "retains semantic recovery %s through failed reads and job changes",
  async (failure, reason) => {
    const f = createPlanningReviewFixture();
    const { result } = renderHook(() =>
      usePlanningSources({
        ...f,
        authSubject: "operator",
        initialWeek: reviewWeek,
      }),
    );
    await waitFor(() => expect(result.current.canEdit).toBe(true));
    await act(() => result.current.syncGoogle("google-1"));
    await act(() => result.current.previewChanges());
    f.api.saveCompletedMenu = async () => failure;
    await act(() => result.current.save());
    expect(result.current.recoveryKind).toBe(reason);
    f.api.getWorkbench = async () => unknown;
    await act(() => result.current.recover());
    expect(result.current.recoveryKind).toBe(reason);
    expect(result.current.readError).not.toBe("");
    act(() => result.current.transition({ job: "pantry" }));
    act(() => result.current.discardTransition());
    expect(result.current.canEdit).toBe(true);
    await act(() => result.current.recover());
    act(() => result.current.transition({ job: "menu" }));
    expect(result.current.recoveryKind).toBe(reason);
    expect(result.current.locked).toBe(true);
  },
);

it.each(["menu", "pantry"] as PlanningJob[])(
  "adopts %s while the sibling is still pending",
  async (job) => {
    const f = createPlanningReviewFixture();
    const sibling = job === "pantry" ? f.api : f.pantryApi;
    let resolve!: (r: ReturnType<typeof success>) => void;
    sibling.getWorkbench = () =>
      new Promise((r) => {
        resolve = r;
      });
    const { result } = renderHook(() =>
      usePlanningSources({
        ...f,
        authSubject: "operator",
        initialWeek: reviewWeek,
        initialJob: job,
      }),
    );
    await waitFor(() => expect(result.current.canEdit).toBe(true));
    expect(result.current.readError).toBe("");
    if (job === "menu") await act(() => result.current.syncGoogle("google-1"));
    else act(() => result.current.requestNoAdditions(true));
    await act(async () =>
      resolve(success({ workbench: job === "pantry" ? f.planning : f.pantry })),
    );
    expect(result.current.dirty).toBe(true);
    expect(result.current.canEdit).toBe(true);
  },
);

it("recovers Planning alone and normalizes only invalid IDs against Pantry", async () => {
  const f = createPlanningReviewFixture();
  f.api.getWorkbench = async () => unknown;
  const pantryRead = vi.spyOn(f.pantryApi, "getWorkbench");
  const { result } = renderHook(() =>
    usePlanningSources({
      ...f,
      authSubject: "operator",
      initialWeek: reviewWeek,
    }),
  );
  await waitFor(() => expect(result.current.recoveryKind).toBe("READ_FAILURE"));
  f.api.getWorkbench = async () => success({ workbench: f.planning });
  await act(() => result.current.recover());
  expect(result.current.canEdit).toBe(true);
  expect(pantryRead).toHaveBeenCalledTimes(1);
  act(() => result.current.transition({ schoolIds: ["school-0", "school-2"] }));
  f.pantry.schools = f.pantry.schools.filter((s) => s.school_id !== "school-2");
  act(() => result.current.transition({ job: "pantry" }));
  expect(result.current.schoolIds).toEqual(["school-0"]);
});

it("discards obsolete preview authority after successful uncertain-write recovery", async () => {
  const f = createPlanningReviewFixture();
  const { result } = renderHook(() =>
    usePlanningSources({
      ...f,
      authSubject: "operator",
      initialWeek: reviewWeek,
    }),
  );
  await waitFor(() => expect(result.current.canEdit).toBe(true));
  await act(() => result.current.syncGoogle("google-1"));
  await act(() => result.current.previewChanges());
  f.api.saveCompletedMenu = async () => unknown;
  await act(() => result.current.save());
  await act(() => result.current.recover());
  expect(result.current.locked).toBe(false);
  expect(result.current.preview).toBeNull();
  expect(result.current.impact).toBeNull();
  const save = vi.spyOn(f.api, "saveCompletedMenu");
  await act(() => result.current.save());
  expect(save).not.toHaveBeenCalled();
});
