import { act, cleanup, renderHook, waitFor } from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import { usePlanningSources } from "./planning/usePlanningSources";
import {
  createPlanningReviewFixture,
  reviewWeek,
} from "./planning/planningReviewFixtures";
import { useSchoolPxkWorkbench } from "./dispatch/useSchoolPxkWorkbench";
import {
  createSchoolPxkReviewFixture,
  reviewDate,
} from "./dispatch/schoolPxkReviewFixtures";
import { useConfirmedNeedWorkbench } from "./planning-confirmed/useConfirmedNeedWorkbench";
import {
  createConfirmedNeedReviewFixture,
  reviewDate as confirmedDate,
} from "./planning-confirmed/confirmedNeedReviewFixtures";
import { useIngredientSupplierWorkbench } from "./master-data/useIngredientSupplierWorkbench";
import { createIngredientSupplierReviewFixture } from "./master-data/ingredientSupplierReviewFixtures";
import { useSchoolDefaultsWorkbench } from "./schools/useSchoolDefaultsWorkbench";
import { createSchoolDefaultsReviewFixture } from "./schools/schoolDefaultsReviewFixtures";
afterEach(cleanup);

it("Planning exit reuses the source discard transition", async () => {
  const fixture = createPlanningReviewFixture();
  const h = renderHook(() =>
    usePlanningSources({
      ...fixture,
      authSubject: "operator",
      initialWeek: reviewWeek,
    }),
  );
  await waitFor(() => expect(h.result.current.data).not.toBeNull());
  act(() => h.result.current.transition({ job: "attendance" }));
  act(() => h.result.current.editAttendance(0, "student_portions", "123"));
  const exit = vi.fn();
  act(() => h.result.current.requestExit(exit));
  expect(exit).not.toHaveBeenCalled();
  expect(h.result.current.pending).not.toBeNull();
  act(() => h.result.current.cancelTransition());
  expect(exit).not.toHaveBeenCalled();
  act(() => h.result.current.requestExit(exit));
  act(() => h.result.current.discardTransition());
  expect(exit).toHaveBeenCalledOnce();
});

it("PXK exit retains an unsent note until its existing discard is confirmed", async () => {
  const api = createSchoolPxkReviewFixture("READY");
  const h = renderHook(() =>
    useSchoolPxkWorkbench({
      api,
      authSubject: "operator",
      initialServiceDate: reviewDate,
    }),
  );
  await waitFor(() => expect(h.result.current.loading).toBe(false));
  act(() => h.result.current.setNote("Giao tại cổng phụ"));
  const exit = vi.fn();
  act(() => h.result.current.requestExit(exit));
  expect(exit).not.toHaveBeenCalled();
  act(() => h.result.current.cancelTransition());
  expect(h.result.current.note).toBe("Giao tại cổng phụ");
  act(() => h.result.current.requestExit(exit));
  act(() => h.result.current.discardTransition());
  expect(exit).toHaveBeenCalledOnce();
});

it("Confirmed Need exit protects edited quantities", async () => {
  const fixture = createConfirmedNeedReviewFixture();
  const h = renderHook(() =>
    useConfirmedNeedWorkbench({
      ...fixture,
      authSubject: "operator",
      initialServiceDate: confirmedDate,
    }),
  );
  await waitFor(() => expect(h.result.current.busy).toBe(false));
  act(() =>
    h.result.current.edit("line-0", {
      exact_quantity: "123",
      quantity_entered: true,
    }),
  );
  const exit = vi.fn();
  act(() => h.result.current.requestExit(exit));
  expect(exit).not.toHaveBeenCalled();
  act(() => h.result.current.cancelTransition());
  expect(exit).not.toHaveBeenCalled();
  act(() => h.result.current.requestExit(exit));
  act(() => h.result.current.discardTransition());
  expect(exit).toHaveBeenCalledOnce();
});

it("Ingredient exit reuses the controller discard interaction", async () => {
  const api = createIngredientSupplierReviewFixture();
  const h = renderHook(() =>
    useIngredientSupplierWorkbench({ api, authSubject: "operator" }),
  );
  await waitFor(() =>
    expect(h.result.current.ingredients.length).toBeGreaterThan(0),
  );
  act(() =>
    h.result.current.openIngredient(
      h.result.current.ingredients[0]!.ingredient_id,
    ),
  );
  act(() => h.result.current.setIngredientField("ingredientName", "Tên mới"));
  const exit = vi.fn();
  act(() => h.result.current.requestExit(exit));
  expect(h.result.current.discardOpen).toBe(true);
  expect(exit).not.toHaveBeenCalled();
  act(() => h.result.current.cancelDiscard());
  expect(exit).not.toHaveBeenCalled();
  act(() => h.result.current.requestExit(exit));
  act(() => h.result.current.confirmDiscard());
  expect(exit).toHaveBeenCalledOnce();
});

it("School drafts and a frozen review require explicit exit discard", async () => {
  const api = createSchoolDefaultsReviewFixture();
  const h = renderHook(() =>
    useSchoolDefaultsWorkbench({ api, authSubject: "operator" }),
  );
  await waitFor(() =>
    expect(h.result.current.schools.length).toBeGreaterThan(0),
  );
  act(() =>
    h.result.current.edit(h.result.current.schools[0]!, "student", "123"),
  );
  const exit = vi.fn();
  act(() => h.result.current.requestExit(exit));
  expect(h.result.current.exitPending).toBe(true);
  expect(exit).not.toHaveBeenCalled();
  act(() => h.result.current.cancelExit());
  expect(h.result.current.dirtyCount).toBe(1);
  act(() => h.result.current.requestExit(exit));
  act(() => h.result.current.discardExit());
  expect(exit).toHaveBeenCalledOnce();
});

it("Planning initializes and reports a selected service date within its week", async () => {
  const fixture = createPlanningReviewFixture();
  const changed = vi.fn();
  const h = renderHook(() =>
    usePlanningSources({
      ...fixture,
      authSubject: "operator",
      initialServiceDate: "2026-09-09",
      onServiceDateChange: changed,
    }),
  );
  await waitFor(() => expect(h.result.current.data).not.toBeNull());
  expect(h.result.current.date).toBe("2026-09-09");
  act(() => h.result.current.transition({ date: "2026-09-10" }));
  expect(changed).toHaveBeenLastCalledWith("2026-09-10");
});
