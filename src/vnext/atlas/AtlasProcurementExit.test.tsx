import "@testing-library/jest-dom/vitest";
import { createRef } from "react";
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  within,
} from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import type { AtlasModuleExitHandle } from "./AtlasModuleExit";
import { ProcurementWorkbench } from "./procurement/ProcurementWorkbench";
import {
  createProcurementReviewFixture,
  reviewDate,
} from "./procurement/procurementReviewFixtures";
afterEach(cleanup);
it("Procurement application exit uses its split discard dialog", async () => {
  const fixture = createProcurementReviewFixture("manual_split");
  const exitRef = createRef<AtlasModuleExitHandle>();
  const exit = vi.fn();
  render(
    <AtlasVNextProvider>
      <ProcurementWorkbench
        {...fixture}
        authSubject="operator"
        initialServiceDate={reviewDate}
        exitRef={exitRef}
      />
    </AtlasVNextProvider>,
  );
  fireEvent.click(
    await screen.findByRole("button", {
      name: /^(Phân bổ NCC|Xem phân bổ) Gạo thơm$/,
    }),
  );
  fireEvent.change(
    screen.getByRole("textbox", { name: "Phân bổ NCC An Phú" }),
    { target: { value: "20" } },
  );
  expect(exitRef.current).not.toBeNull();
  act(() => exitRef.current!.requestExit(exit));
  expect(exit).not.toHaveBeenCalled();
  const dialog = await screen.findByRole("dialog");
  fireEvent.click(
    within(dialog).getByRole("button", { name: "Tiếp tục chỉnh sửa" }),
  );
  expect(exit).not.toHaveBeenCalled();
  act(() => exitRef.current!.requestExit(exit));
  fireEvent.click(
    within(await screen.findByRole("dialog")).getByRole("button", {
      name: "Bỏ thay đổi và đóng",
    }),
  );
  expect(exit).toHaveBeenCalledOnce();
});
