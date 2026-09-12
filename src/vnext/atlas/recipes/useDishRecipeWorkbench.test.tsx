import { act, cleanup, renderHook, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  createRecipeReviewFixture,
  fixtureError,
} from "./recipeReviewFixtures";
import { useDishRecipeWorkbench } from "./useDishRecipeWorkbench";
afterEach(cleanup);
async function setup(
  scenario: Parameters<
    typeof createRecipeReviewFixture
  >[0] = "DISH_ACTIVE_EDITABLE",
) {
  const fixture = createRecipeReviewFixture(scenario);
  const hook = renderHook(
    ({ subject }) =>
      useDishRecipeWorkbench({
        api: fixture.api,
        authSubject: subject,
        initialDate: "2026-09-12",
      }),
    { initialProps: { subject: "operator" } },
  );
  await waitFor(() => expect(hook.result.current.loading).toBe(false));
  return { ...hook, ...fixture };
}
async function select(h: Awaited<ReturnType<typeof setup>>) {
  act(() => h.result.current.transition({ kind: "select", dishId: "dish-0" }));
  await waitFor(() => expect(h.result.current.effective).not.toBeNull());
}
describe("Recipe currentness and commands", () => {
  it("shows a safe permission denial and leaves creation unavailable", async () => {
    const h = await setup("PERMISSION_DENIED");
    expect(h.result.current.error).toContain("không có quyền");
    expect(h.result.current.canCommand).toBe(false);
  });
  it("rejects a retained Save callback immediately after context invalidation", async () => {
    const h = await setup();
    await select(h);
    const save = vi.spyOn(h.api, "saveRecipe");
    act(() => h.result.current.reviewRecipe());
    const oldSave = h.result.current.saveRecipe;
    await act(async () => {
      h.result.current.transition({ kind: "scope", schoolTypeId: "scope-1" });
      await oldSave();
    });
    expect(save).not.toHaveBeenCalled();
  });
  it("ignores an older delayed selection response", async () => {
    const h = await setup();
    const read = h.api.getEffectiveWorkbench;
    let finish!: () => void;
    h.api.getEffectiveWorkbench = async (...args) => {
      const result = await read(...args);
      if (args[3] === "dish-0")
        await new Promise<void>((resolve) => {
          finish = resolve;
        });
      return result;
    };
    act(() =>
      h.result.current.transition({ kind: "select", dishId: "dish-0" }),
    );
    await waitFor(() => expect(finish).toBeDefined());
    act(() =>
      h.result.current.transition({ kind: "select", dishId: "dish-1" }),
    );
    await waitFor(() =>
      expect(h.result.current.effective?.dish.dish_id).toBe("dish-1"),
    );
    await act(async () => finish());
    expect(h.result.current.effective?.dish.dish_id).toBe("dish-1");
  });
  it("does not promote backend false save permission", async () => {
    const h = await setup();
    const original = h.api.getWorkbench;
    h.api.getWorkbench = async (...args) => {
      const r = await original(...args);
      if (r.kind === "success") {
        const w = r.response.workbench as unknown as typeof h.data;
        w.selected_recipe.allowed_actions.save_recipe = false;
      }
      return r;
    };
    await select(h);
    expect(h.result.current.canEdit).toBe(false);
  });
  it.each(["VALIDATION_FAILED", "CONFLICT"])(
    "treats definite %s as rejection, preserving draft without uncertainty",
    async (code) => {
      const h = await setup();
      await select(h);
      h.api.saveRecipe = async () => fixtureError(code);
      act(() =>
        h.result.current.setRecipeDraft({
          ...h.result.current.recipeDraft!,
          basis: "120",
        }),
      );
      act(() => h.result.current.reviewRecipe());
      await act(() => h.result.current.saveRecipe());
      expect(h.result.current.lock).toBeNull();
      expect(h.result.current.recipeDraft?.basis).toBe("120");
      expect(h.result.current.notice).not.toContain("Đã lưu");
    },
  );
  it("locks retryable concurrency until explicit fresh read and review", async () => {
    const h = await setup();
    await select(h);
    h.api.saveRecipe = vi.fn(async () =>
      fixtureError("RETRYABLE_CONCURRENCY_FAILURE"),
    );
    act(() => h.result.current.reviewRecipe());
    await act(() => h.result.current.saveRecipe());
    expect(h.result.current.lock).toBe("stale");
    await act(() => h.result.current.recover());
    expect(h.result.current.lock).toBeNull();
    expect(h.result.current.review).toBe(false);
    expect(h.api.saveRecipe).toHaveBeenCalledTimes(1);
  });
  it("locks success with mismatched composition and read-only recovery never resends", async () => {
    const h = await setup();
    await select(h);
    h.api.saveRecipe = vi.fn(async () => ({
      kind: "success" as const,
      response: { success: true as const },
    }));
    act(() =>
      h.result.current.setRecipeDraft({
        ...h.result.current.recipeDraft!,
        basis: "120",
      }),
    );
    act(() => h.result.current.reviewRecipe());
    await act(() => h.result.current.saveRecipe());
    expect(h.result.current.lock).toBe("readback");
    await act(() => h.result.current.recover());
    expect(h.result.current.lock).toBe("readback");
    expect(h.api.saveRecipe).toHaveBeenCalledTimes(1);
  });
  it.each([
    "select",
    "scope",
    "date",
    "close",
    "refresh",
    "edit",
    "lifecycle",
    "copy",
    "import",
  ] as const)("protects a dirty Dish before %s", async (kind) => {
    const h = await setup();
    await select(h);
    act(() => h.result.current.transition({ kind: "edit" }));
    act(() =>
      h.result.current.setDishDraft({
        ...h.result.current.dishDraft!,
        name: "Chưa lưu",
      }),
    );
    const next =
      kind === "select"
        ? { kind, dishId: "dish-1" }
        : kind === "scope"
          ? { kind, schoolTypeId: "scope-1" }
          : kind === "date"
            ? { kind, date: "2026-09-13" }
            : { kind };
    act(() => h.result.current.transition(next));
    expect(h.result.current.discardOpen).toBe(true);
    act(() => h.result.current.cancelDiscard());
    expect(h.result.current.dishDraft?.name).toBe("Chưa lưu");
  });
  it("blocks same-source, unreasoned and ineligible copy without sending", async () => {
    const h = await setup();
    await select(h);
    const copy = vi.spyOn(h.api, "copyDishRecipes");
    act(() => h.result.current.transition({ kind: "copy" }));
    await act(() =>
      h.result.current.copyRecipes("dish-0", "2026-09-12", "Reason"),
    );
    await act(() => h.result.current.copyRecipes("dish-1", "2026-09-12", ""));
    expect(copy).not.toHaveBeenCalled();
  });
  it("copy UNKNOWN locks all writes and cannot recover from unrelated existing drafts", async () => {
    const h = await setup("COPY_UNKNOWN");
    await select(h);
    const copy = vi.spyOn(h.api, "copyDishRecipes");
    act(() => h.result.current.transition({ kind: "copy" }));
    await act(() =>
      h.result.current.copyRecipes("dish-1", "2026-09-12", "Reason"),
    );
    expect(h.result.current.lock).toBe("unknown");
    await act(() => h.result.current.recover());
    expect(h.result.current.lock).toBe("unknown");
    expect(copy).toHaveBeenCalledTimes(1);
  });
  it("loads both exact selected reads, and local filtering makes no requests", async () => {
    const h = await setup();
    const base = vi.spyOn(h.api, "getWorkbench"),
      eff = vi.spyOn(h.api, "getEffectiveWorkbench");
    await select(h);
    expect(base).toHaveBeenCalledWith("operator", expect.any(String), {
      dishId: "dish-0",
      schoolTypeId: "scope-0",
    });
    expect(eff).toHaveBeenCalledWith(
      "operator",
      expect.any(String),
      "2026-09-12",
      "dish-0",
      { kind: "system", schoolTypeId: "scope-0" },
    );
    act(() => h.result.current.setQuery("bi do"));
    expect(h.result.current.visibleDishes.length).toBeGreaterThan(0);
    expect(base).toHaveBeenCalledTimes(1);
    expect(eff).toHaveBeenCalledTimes(1);
  });
  it("requires effective permission and blocks operationally locked save", async () => {
    const h = await setup("DISH_ACTIVE_LOCKED");
    await select(h);
    expect(h.result.current.canEdit).toBe(false);
    const save = vi.spyOn(h.api, "saveRecipe");
    await act(() => h.result.current.saveRecipe());
    expect(save).not.toHaveBeenCalled();
  });
  it("fails closed on effective read failure", async () => {
    const h = await setup();
    h.api.getEffectiveWorkbench = async () =>
      fixtureError("INTERNAL_READ_FAILURE");
    act(() =>
      h.result.current.transition({ kind: "select", dishId: "dish-0" }),
    );
    await waitFor(() => expect(h.result.current.error).toBeTruthy());
    expect(h.result.current.canEdit).toBe(false);
  });
  it("submits only one modern Save with exact identity, basis, line facts and version then adopts readback", async () => {
    const h = await setup();
    await select(h);
    const save = vi.spyOn(h.api, "saveRecipe");
    act(() =>
      h.result.current.setRecipeDraft({
        ...h.result.current.recipeDraft!,
        basis: "120",
      }),
    );
    act(() => h.result.current.reviewRecipe());
    await act(() =>
      Promise.all([
        h.result.current.saveRecipe(),
        h.result.current.saveRecipe(),
      ]),
    );
    expect(save).toHaveBeenCalledTimes(1);
    expect(save.mock.calls[0][0]).toMatchObject({
      contract_version: "RMVP-02A.v2",
      expected_version: 3,
      reason_code: "RECIPE_SAVED",
      payload: {
        dish_id: "dish-0",
        school_type_id: "scope-0",
        recipe_version_id: "dish-0-scope-0-version",
        basis_portions: 120,
        lines: [
          {
            recipe_line_id: "dish-0-scope-0-line",
            ingredient_id: "ingredient-0",
            quantity_per_basis: 22.5,
            unit_id: "kg",
            operational_note: "Cắt miếng vừa",
          },
        ],
      },
    });
    expect(h.result.current.lock).toBeNull();
    expect(h.result.current.notice).toContain("Sẵn sàng");
    expect(h.result.current.dirty).toBe(false);
  });
  it.each([
    ["SAVE_UNKNOWN", "unknown"],
    ["SAVE_STALE", "stale"],
    ["SAVE_SUCCESS_READBACK_FAILURE", "readback"],
  ] as const)("locks %s with no resend", async (scenario, lock) => {
    const h = await setup(scenario);
    await select(h);
    const save = vi.spyOn(h.api, "saveRecipe");
    act(() =>
      h.result.current.setRecipeDraft({
        ...h.result.current.recipeDraft!,
        basis: "120",
      }),
    );
    act(() => h.result.current.reviewRecipe());
    await act(() => h.result.current.saveRecipe());
    expect(h.result.current.lock).toBe(lock);
    await act(() => h.result.current.saveRecipe());
    expect(save).toHaveBeenCalledTimes(1);
  });
  it("protects exact drafts on cancelled transitions and discards only explicitly", async () => {
    const h = await setup();
    await select(h);
    act(() =>
      h.result.current.setRecipeDraft({
        ...h.result.current.recipeDraft!,
        basis: "123",
      }),
    );
    act(() =>
      h.result.current.transition({ kind: "scope", schoolTypeId: "scope-1" }),
    );
    expect(h.result.current.discardOpen).toBe(true);
    act(() => h.result.current.cancelDiscard());
    expect(h.result.current.recipeDraft?.basis).toBe("123");
    act(() =>
      h.result.current.transition({ kind: "scope", schoolTypeId: "scope-1" }),
    );
    act(() => h.result.current.confirmDiscard());
    act(() => h.result.current.completeDiscardTransition());
    await waitFor(() =>
      expect(h.result.current.effective?.school_type_id).toBe("scope-1"),
    );
  });
  it("empty authorised catalogue permits create without an effective read; readback exposes canonical roots", async () => {
    const h = await setup("EMPTY_CATALOG");
    const eff = vi.spyOn(h.api, "getEffectiveWorkbench"),
      create = vi.spyOn(h.api, "createDish");
    expect(h.result.current.canCommand).toBe(true);
    expect(eff).not.toHaveBeenCalled();
    act(() => h.result.current.transition({ kind: "create" }));
    act(() =>
      h.result.current.setDishDraft({
        name: "Món mới",
        typeId: "type-0",
        category: "",
        notes: "",
      }),
    );
    await act(() => h.result.current.saveDish());
    expect(create.mock.calls[0][0].expected_version).toBe(1);
    expect(create.mock.calls[0][0].payload).not.toHaveProperty("dish_code");
    expect(h.result.current.dish?.dish_status).toBe("ACTIVE");
    expect(h.result.current.scopes).toHaveLength(2);
  });
  it("preserves hidden metadata and current Dish version on update and lifecycle", async () => {
    const h = await setup();
    await select(h);
    const update = vi.spyOn(h.api, "updateDish"),
      lifecycle = vi.spyOn(h.api, "setDishLifecycle");
    act(() => h.result.current.transition({ kind: "edit" }));
    act(() =>
      h.result.current.setDishDraft({
        ...h.result.current.dishDraft!,
        name: "Tên mới",
      }),
    );
    await act(() => h.result.current.saveDish());
    expect(update.mock.calls[0][0]).toMatchObject({
      expected_version: 7,
      payload: {
        dish_code: "hidden-dish-0",
        display_order: 0,
        requires_need_generation: true,
      },
    });
    act(() => h.result.current.transition({ kind: "lifecycle" }));
    await act(() => h.result.current.setLifecycle());
    expect(lifecycle.mock.calls[0][0]).toMatchObject({
      expected_version: 8,
      payload: { dish_status: "INACTIVE" },
    });
    expect(h.result.current.dish?.dish_status).toBe("INACTIVE");
  });
  it("copies both scopes by exact command and reads their persisted drafts", async () => {
    const h = await setup();
    await select(h);
    const copy = vi.spyOn(h.api, "copyDishRecipes");
    act(() => h.result.current.transition({ kind: "copy" }));
    await act(() =>
      h.result.current.copyRecipes(
        "dish-1",
        "2026-09-11",
        "Dùng định lượng mẫu",
      ),
    );
    expect(copy).toHaveBeenCalledTimes(1);
    expect(copy.mock.calls[0][0]).toMatchObject({
      contract_version: "RECIPE-EFFECTIVE.v1",
      expected_version: 7,
      payload: {
        source_dish_id: "dish-1",
        target_dish_id: "dish-0",
        as_of_date: "2026-09-11",
      },
    });
    expect(h.result.current.lock).toBeNull();
    expect(h.result.current.notice).toContain("từng loại");
  });
  it("auth change clears draft and ignores a delayed previous operator write", async () => {
    const h = await setup();
    await select(h);
    let finish!: (value: ReturnType<typeof fixtureError>) => void;
    h.api.saveRecipe = () =>
      new Promise((resolve) => {
        finish = resolve;
      });
    act(() =>
      h.result.current.setRecipeDraft({
        ...h.result.current.recipeDraft!,
        basis: "120",
      }),
    );
    act(() => h.result.current.reviewRecipe());
    let pending!: Promise<void>;
    act(() => {
      pending = h.result.current.saveRecipe();
    });
    h.rerender({ subject: "new-operator" });
    await act(async () => {
      finish(fixtureError("STALE_VERSION"));
      await pending;
    });
    expect(h.result.current.dish).toBeUndefined();
    expect(h.result.current.recipeDraft).toBeNull();
    expect(h.result.current.lock).toBeNull();
  });
});
