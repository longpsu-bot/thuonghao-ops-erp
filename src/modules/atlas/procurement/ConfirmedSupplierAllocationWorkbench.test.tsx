import "@testing-library/jest-dom/vitest";
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import { createReviewAuthState } from "../review/reviewMode";
import { SchoolCateringProcurementWorkbench } from "./SchoolCateringProcurementWorkbench";
import {
  createReviewProcurementWorkbenchFixture,
  createReviewSchoolCateringProcurementApi,
} from "./reviewSchoolCateringProcurementApi";
import { createPurchaseReviewApi } from "./purchaseReviewApi";

afterEach(cleanup);
function setup(ready = false, complete = true) {
  const data = createReviewProcurementWorkbenchFixture("manual_split");
  const row = data.rows[0]!;
  row.complete = complete;
  row.family.source_kind = "CONFIRMED_NEED";
  row.family.source_confirmed_need_batch_id = "batch";
  row.family.source_confirmed_need_batch_version = 7;
  row.allowed_actions.confirm_recommendation = false;
  row.allowed_actions.save_allocation = complete;
  if (!complete) {
    row.state = "BLOCKED";
    row.blockers = ["Hoàn tất xác nhận nhu cầu trước khi phân bổ NCC."];
  }
  const invoke = vi.fn().mockImplementation(async (name: string) =>
    name.includes("get_confirmed")
      ? {
          kind: "success",
          response: {
            ...data,
            contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
            date_start: "2026-09-02",
            date_end: "2026-09-02",
            preparation: {
              service_date: "2026-09-02",
              confirmed_need_batch_id: "batch",
              expected_version: 7,
              allowed: true,
              ready,
              blockers: ready
                ? []
                : ["Phân bổ nhà cung ứng chưa khớp với nhu cầu đã xác nhận."],
            },
          },
        }
      : { kind: "success", response: { success: true } },
  );
  const legacy = createReviewSchoolCateringProcurementApi("empty");
  const legacySave = vi.spyOn(legacy, "saveAllocation");
  const legacyDraft = vi.spyOn(legacy, "createPurchaseOrderDrafts");
  render(
    <SchoolCateringProcurementWorkbench
      authState={createReviewAuthState("ready")}
      api={legacy}
      purchaseReviewApi={createPurchaseReviewApi({ invoke })}
      initialDateStart="2026-09-02"
      initialDateEnd="2026-09-02"
    />,
  );
  return { invoke, legacySave, legacyDraft, row, legacy };
}
it("saves pre-Handoff exact splits with source batch/version and authoritative readback", async () => {
  const { invoke, legacySave, row } = setup();
  fireEvent.click(
    await screen.findByRole("button", { name: /^(Xem phân bổ|Phân bổ NCC)$/ }),
  );
  expect(screen.getByText("Nhu cầu đã xác nhận:")).toBeVisible();
  expect(
    screen.queryByRole("button", { name: "Xác nhận phân bổ đề xuất" }),
  ).not.toBeInTheDocument();
  fireEvent.click(screen.getByRole("button", { name: "Lưu phân bổ" }));
  await waitFor(() => expect(invoke).toHaveBeenCalledTimes(3));
  expect(invoke.mock.calls[1]![0]).toBe(
    "atlas_api.save_confirmed_supplier_allocation",
  );
  expect(invoke.mock.calls[1]![1].payload.family).toMatchObject({
    expected_source_batch_id: "batch",
    expected_source_batch_version: 7,
    expected_source_fingerprint: row.family.source_fingerprint,
  });
  expect(invoke.mock.calls[1]![1].payload.splits[0].allocated_quantity).toBe(
    "60.000000",
  );
  expect(legacySave).not.toHaveBeenCalled();
});
it.each([
  "UNALLOCATED",
  "STALE_REBALANCE_AVAILABLE",
  "NEEDS_REALLOCATION",
  "BLOCKED",
] as const)(
  "blocks continuation for backend allocation state %s",
  async (state) => {
    const { row, invoke } = setup(false, state !== "BLOCKED");
    row.state = state;
    const proceed = await screen.findByRole("button", {
      name: "Tiếp tục lên đơn",
    });
    expect(proceed).toBeDisabled();
    fireEvent.click(proceed);
    expect(invoke).toHaveBeenCalledTimes(1);
  },
);
it("prepares through one backend command then reads official drafts", async () => {
  const { invoke, legacyDraft, legacy } = setup(true);
  const readOrders = vi.spyOn(legacy, "getPurchaseOrders");
  const release = vi.spyOn(legacy, "releasePurchaseOrder");
  const proceed = await screen.findByRole("button", {
    name: "Tiếp tục lên đơn",
  });
  expect(proceed).toBeEnabled();
  expect(
    screen.getAllByRole("button", { name: "Tiếp tục lên đơn" }),
  ).toHaveLength(1);
  fireEvent.click(proceed);
  await screen.findByRole("heading", { name: "Đơn mua", level: 1 });
  expect(
    screen.getByRole("heading", { name: "Đơn mua", level: 1 }),
  ).toHaveFocus();
  expect(invoke.mock.calls[1]![0]).toBe(
    "atlas_api.prepare_school_catering_purchase_orders",
  );
  expect(invoke.mock.calls[1]![1]).toMatchObject({
    contract_version: "PURCHASE-COMMITMENT.v1",
    reason_code: "PURCHASE_ORDERS_PREPARED",
    expected_version: 7,
    payload: { service_date: "2026-09-02", confirmed_need_batch_id: "batch" },
  });
  expect(readOrders).toHaveBeenCalled();
  expect(readOrders.mock.calls[0]![0].payload).toMatchObject({
    date_start: "2026-09-02",
    date_end: "2026-09-02",
  });
  expect(screen.getByLabelText("Ngày phục vụ")).toHaveValue("2026-09-02");
  expect(screen.getByRole("table", { name: "Đơn mua" })).toHaveTextContent(
    "Bản nháp",
  );
  expect(release).not.toHaveBeenCalled();
  fireEvent.click(screen.getByRole("button", { name: "Xem đơn" }));
  const commit = screen.getByRole("button", { name: "Phát hành cho NCC" });
  expect(commit).toBeEnabled();
  expect(release).not.toHaveBeenCalled();
  fireEvent.click(commit);
  await waitFor(() => expect(release).toHaveBeenCalledOnce());
  await waitFor(() =>
    expect(screen.getByRole("table", { name: "Đơn mua" })).toHaveTextContent(
      "Đã phát hành",
    ),
  );
  expect(legacyDraft).not.toHaveBeenCalled();
});
it("retries exactly the retained preparation request while its scope is current", async () => {
  const { invoke } = setup(true);
  const prepare = await screen.findByRole("button", {
    name: "Tiếp tục lên đơn",
  });
  invoke.mockResolvedValueOnce({
    kind: "backend_error",
    error: {
      success: false,
      error_code: "RETRYABLE_CONCURRENCY_FAILURE",
      safe_message: "Thử lại",
      retryable: true,
    },
  });
  fireEvent.click(prepare);
  const retry = await screen.findByRole("button", { name: "Thử lại thao tác" });
  const request = invoke.mock.calls[1]![1];
  expect(prepare).toBeDisabled();
  expect(
    [prepare, retry].filter(
      (button) => !(button as HTMLButtonElement).disabled,
    ),
  ).toHaveLength(1);
  fireEvent.click(retry);
  await screen.findByRole("heading", { name: "Đơn mua", level: 1 });
  expect(invoke.mock.calls[2]![1]).toEqual(request);
});
it("discards preparation retry when the working date changes", async () => {
  const { invoke } = setup(true);
  const prepare = await screen.findByRole("button", {
    name: "Tiếp tục lên đơn",
  });
  invoke.mockResolvedValueOnce({
    kind: "backend_error",
    error: {
      success: false,
      error_code: "RETRYABLE_CONCURRENCY_FAILURE",
      safe_message: "Thử lại",
      retryable: true,
    },
  });
  fireEvent.click(prepare);
  await screen.findByRole("button", { name: "Thử lại thao tác" });
  fireEvent.change(screen.getByLabelText("Ngày phục vụ"), {
    target: { value: "2026-09-03" },
  });
  await waitFor(() =>
    expect(
      invoke.mock.calls.filter((call) => call[0].includes("get_confirmed")),
    ).toHaveLength(2),
  );
  expect(
    screen.queryByRole("button", { name: "Thử lại thao tác" }),
  ).not.toBeInTheDocument();
  expect(
    invoke.mock.calls.filter((call) => call[0].includes("prepare_school")),
  ).toHaveLength(1);
});
it("locks preparation after successful command but failed official readback", async () => {
  const { legacy } = setup(true);
  vi.spyOn(legacy, "getPurchaseOrders").mockResolvedValue({
    kind: "transport_error",
    diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Mất kết nối" },
  });
  fireEvent.click(
    await screen.findByRole("button", { name: "Tiếp tục lên đơn" }),
  );
  expect(
    await screen.findByText(/Chưa tải được đơn mua sau khi xử lý/),
  ).toBeVisible();
  expect(
    screen.getByRole("button", { name: "Tiếp tục lên đơn" }),
  ).toBeDisabled();
});
it("discards old preparation readback after a new date's allocation read has completed", async () => {
  const { legacy, invoke } = setup(true);
  let resolveOld!: (
    value: Awaited<ReturnType<typeof legacy.getPurchaseOrders>>,
  ) => void;
  const read = vi.spyOn(legacy, "getPurchaseOrders").mockImplementationOnce(
    () =>
      new Promise((resolve) => {
        resolveOld = resolve;
      }),
  );
  fireEvent.click(
    await screen.findByRole("button", { name: "Tiếp tục lên đơn" }),
  );
  await waitFor(() => expect(read).toHaveBeenCalledOnce());
  expect(
    screen.getByRole("heading", { name: "Phân bổ nhà cung ứng", level: 1 }),
  ).toBeVisible();
  expect(
    screen.queryByRole("heading", { name: "Đơn mua", level: 1 }),
  ).not.toBeInTheDocument();
  fireEvent.change(screen.getByLabelText("Ngày phục vụ"), {
    target: { value: "2026-09-03" },
  });
  await waitFor(() =>
    expect(
      invoke.mock.calls.filter((call) => call[0].includes("get_confirmed")),
    ).toHaveLength(2),
  );
  await waitFor(() =>
    expect(
      screen.getByRole("button", { name: "Tiếp tục lên đơn" }),
    ).toBeEnabled(),
  );
  await act(async () =>
    resolveOld({
      kind: "transport_error",
      diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Old date failed" },
    }),
  );
  expect(screen.getByLabelText("Ngày phục vụ")).toHaveValue("2026-09-03");
  expect(
    screen.queryByText(/Chưa tải được đơn mua sau khi xử lý/),
  ).not.toBeInTheDocument();
  expect(
    screen.getByRole("button", { name: "Tiếp tục lên đơn" }),
  ).toBeEnabled();
});
it("keeps exact retry as the only write action after a retryable allocation Save", async () => {
  const { invoke } = setup();
  fireEvent.click(
    await screen.findByRole("button", { name: /^(Xem phân bổ|Phân bổ NCC)$/ }),
  );
  invoke.mockResolvedValueOnce({
    kind: "backend_error",
    error: {
      success: false,
      error_code: "RETRYABLE_CONCURRENCY_FAILURE",
      safe_message: "Thử lại",
      retryable: true,
    },
  });
  fireEvent.click(screen.getByRole("button", { name: "Lưu phân bổ" }));
  expect(
    await screen.findByRole("button", { name: "Thử lại thao tác" }),
  ).toBeEnabled();
  expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
});
it("shows incomplete Need without presenting a generated fallback as confirmed zero", async () => {
  setup(false, false);
  fireEvent.click(
    await screen.findByRole("button", { name: /^(Xem phân bổ|Phân bổ NCC)$/ }),
  );
  expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
  expect(
    screen.getAllByText("Hoàn tất xác nhận nhu cầu trước khi phân bổ NCC.")
      .length,
  ).toBeGreaterThan(0);
  expect(
    screen.getByText("Nhu cầu đã xác nhận:").parentElement,
  ).toHaveTextContent("— kg");
});
