import "@testing-library/jest-dom/vitest";
import { createRef } from "react";
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import type { AtlasModuleExitHandle } from "./AtlasModuleExit";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { RecipeCapability } from "./recipes/RecipeCapability";
import { createRecipeReviewFixture } from "./recipes/recipeReviewFixtures";
import { createChangeOrderFixture } from "./recipes/changeOrderReviewFixtures";
import { ProcurementWorkbench } from "./procurement/ProcurementWorkbench";
import {
  createProcurementReviewFixture,
  reviewDate,
} from "./procurement/procurementReviewFixtures";
import { useSchoolPxkWorkbench } from "./dispatch/useSchoolPxkWorkbench";
import { createSchoolPxkReviewFixture } from "./dispatch/schoolPxkReviewFixtures";
import { renderHook } from "@testing-library/react";
afterEach(cleanup);
it("Recipe UNKNOWN keeps its recovery context when the application requests exit", async () => {
  const exitRef = createRef<AtlasModuleExitHandle>();
  const exit = vi.fn();
  render(
    <AtlasVNextProvider>
      <RecipeCapability
        exitRef={exitRef}
        authSubject="operator"
        recipeApi={createRecipeReviewFixture("SAVE_UNKNOWN").api}
        adjustmentApi={createChangeOrderFixture().api}
        initialDate="2026-09-12"
      />
    </AtlasVNextProvider>,
  );
  fireEvent.click(
    await screen.findByRole("button", {
      name: "Xem công thức Canh bí đỏ thịt bằm",
    }),
  );
  fireEvent.change(await screen.findByLabelText("Định lượng Bí đỏ"), {
    target: { value: "2,25" },
  });
  fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
  fireEvent.click(screen.getByRole("button", { name: "Lưu công thức" }));
  await screen.findByRole("button", { name: "Tải lại để xác nhận" });
  act(() => exitRef.current!.requestExit(exit));
  expect(exit).not.toHaveBeenCalled();
  expect(
    screen.getByRole("button", { name: "Tải lại để xác nhận" }),
  ).toBeInTheDocument();
}, 15000);
it.each(["unknown", "retryable_failure"] as const)(
  "Procurement %s blocks application exit",
  async (scenario) => {
    const fixture = createProcurementReviewFixture(scenario);
    const exitRef = createRef<AtlasModuleExitHandle>();
    const exit = vi.fn();
    render(
      <AtlasVNextProvider>
        <ProcurementWorkbench
          {...fixture}
          exitRef={exitRef}
          authSubject="operator"
          initialServiceDate={reviewDate}
        />
      </AtlasVNextProvider>,
    );
    fireEvent.click(
      await screen.findByRole("button", {
        name: /^(Phân bổ NCC|Xem phân bổ) Gạo thơm$/,
      }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Dùng đề xuất" }));
    fireEvent.click(screen.getByRole("button", { name: "Lưu phân bổ" }));
    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Lưu phân bổ" }),
      ).toBeDisabled(),
    );
    act(() => exitRef.current!.requestExit(exit));
    expect(exit).not.toHaveBeenCalled();
  },
  15000,
);
it("PXK UNKNOWN blocks exit and retains its exact recovery state", async () => {
  const api = createSchoolPxkReviewFixture("UNKNOWN_RELEASE");
  const exit = vi.fn();
  const h = renderHook(() =>
    useSchoolPxkWorkbench({
      api,
      authSubject: "operator",
      initialServiceDate: reviewDate,
    }),
  );
  await waitFor(() => expect(h.result.current.loading).toBe(false));
  act(() =>
    h.result.current.transition({
      selectedKey: h.result.current.key(h.result.current.rows[0]!),
    }),
  );
  await act(() => h.result.current.release());
  expect(h.result.current.lock).toBe("unknown");
  act(() => h.result.current.requestExit(exit));
  expect(exit).not.toHaveBeenCalled();
});
