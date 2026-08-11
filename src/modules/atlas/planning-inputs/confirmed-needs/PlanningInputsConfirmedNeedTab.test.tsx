import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import type { AtlasAuthState } from "../../connection/authSession";
import { PlanningInputsWorkbench } from "../PlanningInputsWorkbench";
import { createReviewNeedGenerationApi } from "../need-generation/reviewNeedGenerationApi";
import { createReviewPlanningInputReadinessApi } from "../readiness/reviewPlanningInputReadinessApi";
import { createReviewConfirmedNeedApi } from "./reviewConfirmedNeedApi";

afterEach(cleanup);

const authState = {
  status: "authenticated",
  authSubject: "review-only-atlas-operator",
  user: { id: "review-only-atlas-operator" },
  session: { user: { id: "review-only-atlas-operator" } },
} as unknown as AtlasAuthState;

describe("Planning Inputs Confirmed Need tab", () => {
  it("keeps Xác nhận nhu cầu as the first downstream review tab", async () => {
    render(
      <PlanningInputsWorkbench
        authState={authState}
        readinessApi={createReviewPlanningInputReadinessApi("ready")}
        confirmedNeedApi={createReviewConfirmedNeedApi("ready")}
        mode="review"
      />,
    );
    const tabs = screen.getAllByRole("tab");
    expect(tabs).toHaveLength(5);
    expect(tabs[4]).toHaveTextContent("Xác nhận nhu cầu");
    fireEvent.click(tabs[4]!);
    expect(
      await screen.findByText("Chưa có nhu cầu cho tuần đã chọn."),
    ).toBeVisible();
    expect(
      screen.queryByLabelText("Mã lô Confirmed Need"),
    ).not.toBeInTheDocument();
  });

  it("loads the current need from the selected week's preflight without batch knowledge", async () => {
    render(
      <PlanningInputsWorkbench
        authState={authState}
        readinessApi={createReviewPlanningInputReadinessApi("ready", {
          currentNeed: true,
        })}
        confirmedNeedApi={createReviewConfirmedNeedApi("ready")}
        mode="review"
      />,
    );
    const confirmedNeedTab = screen.getByRole("tab", {
      name: "Xác nhận nhu cầu",
    });
    fireEvent.click(confirmedNeedTab);
    await waitFor(() =>
      expect(confirmedNeedTab).toHaveAttribute("aria-selected", "true"),
    );
    expect(await screen.findByText("Gạo thơm")).toBeVisible();
    expect(screen.getByLabelText("Trường")).toHaveDisplayValue("Tất cả trường");
    expect(screen.queryByText(/UUID|Mã lô|Tải lô/i)).not.toBeInTheDocument();
  });

  it("shows a simple message when preflight denies access", async () => {
    render(
      <PlanningInputsWorkbench
        authState={authState}
        readinessApi={createReviewPlanningInputReadinessApi(
          "permission_denied",
        )}
        confirmedNeedApi={createReviewConfirmedNeedApi("ready")}
        mode="review"
      />,
    );
    const confirmedNeedTab = screen.getByRole("tab", {
      name: "Xác nhận nhu cầu",
    });
    fireEvent.click(confirmedNeedTab);
    await waitFor(() =>
      expect(confirmedNeedTab).toHaveAttribute("aria-selected", "true"),
    );
    expect(
      await screen.findByText("Bạn không có quyền xem dữ liệu này."),
    ).toBeVisible();
  });

  it("opens the batch returned by RMVP-04 materialization", async () => {
    render(
      <PlanningInputsWorkbench
        authState={authState}
        needGenerationApi={createReviewNeedGenerationApi("ready")}
        readinessApi={createReviewPlanningInputReadinessApi("ready")}
        confirmedNeedApi={createReviewConfirmedNeedApi("ready")}
        mode="review"
      />,
    );
    fireEvent.click(screen.getAllByRole("tab")[3]!);
    fireEvent.click(
      await screen.findByRole("button", { name: /Tạo nhu cầu$/ }),
    );
    fireEvent.click(
      await screen.findByRole("button", { name: "Mở Xác nhận nhu cầu" }),
    );
    await waitFor(() =>
      expect(
        screen.getByRole("tab", { name: "Xác nhận nhu cầu" }),
      ).toHaveAttribute("aria-selected", "true"),
    );
    expect(await screen.findByText("Gạo thơm")).toBeVisible();
    expect(
      screen.queryByLabelText("Mã lô Confirmed Need"),
    ).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Xuất Excel" })).toBeDisabled();
    expect(screen.queryByText("Nhập Excel")).not.toBeInTheDocument();
  });
});
