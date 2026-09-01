import "@testing-library/jest-dom/vitest";
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { AtlasAuthState } from "../connection/authSession";
import type { AtlasSuccessEnvelope } from "../connection/atlasRpc";
import { useState } from "react";
import { ConfirmedNeedReviewWorkbench } from "../planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench";
import { createReviewConfirmedNeedApi } from "../planning-inputs/confirmed-needs/reviewConfirmedNeedApi";
import {
  PlanningRailActionHost,
  PlanningRailActionProvider,
} from "../planning-inputs/PlanningRailActionPortal";
import { SchoolCateringProcurementWorkbench } from "./SchoolCateringProcurementWorkbench";
import {
  createReviewPurchaseOrdersFixture,
  createReviewProcurementWorkbenchFixture,
  createReviewSchoolCateringProcurementApi,
} from "./reviewSchoolCateringProcurementApi";

const confirmedNeedBatchId = "c4500000-0000-0000-0000-000000000001";

function reviewSuccess(response: Record<string, unknown>) {
  return {
    kind: "success" as const,
    response: response as unknown as AtlasSuccessEnvelope,
  };
}

function createCrossStageJourney() {
  const confirmedNeedApi = createReviewConfirmedNeedApi("ready");
  const procurementApi = createReviewSchoolCateringProcurementApi("empty");
  let handoff: "NONE" | "INITIAL_100" | "CORRECTED_120" = "NONE";
  let allocation: "NONE" | "INITIAL_60_40" | "CORRECTED_72_48" = "NONE";
  let purchaseOrder: "NONE" | "DRAFT" | "STALE" | "REGENERATED" | "RELEASED" =
    "NONE";

  confirmedNeedApi.releasePurchaseHandoff = async () => {
    handoff = "INITIAL_100";
    return reviewSuccess({
      success: true,
      safe_operator_message: "Đã tạo Bàn giao mua hàng 100 kg.",
    });
  };

  procurementApi.getWorkbench = async () => {
    if (handoff === "NONE")
      return reviewSuccess(createReviewProcurementWorkbenchFixture("empty"));
    if (handoff === "INITIAL_100" && allocation === "NONE")
      return reviewSuccess(createReviewProcurementWorkbenchFixture("default"));
    if (handoff === "INITIAL_100")
      return reviewSuccess(
        createReviewProcurementWorkbenchFixture("manual_split"),
      );
    if (allocation !== "CORRECTED_72_48")
      return reviewSuccess(
        createReviewProcurementWorkbenchFixture("rebalance"),
      );

    const corrected = createReviewProcurementWorkbenchFixture("manual_split");
    const row = corrected.rows[0]!;
    row.family_quantity = "120.000000";
    row.family.source_fingerprint = "review-source-120";
    row.splits[0]!.allocated_quantity = "72.000000";
    row.splits[1]!.allocated_quantity = "48.000000";
    return reviewSuccess(corrected);
  };

  procurementApi.saveAllocation = async (request) => {
    const quantities = request.payload.splits.map(
      (split) => split.allocated_quantity,
    );
    if (handoff === "INITIAL_100") {
      if (quantities.join("/") !== "60.000000/40.000000")
        throw new Error(
          "Initial family must persist the exact 60/40 snapshot.",
        );
      allocation = "INITIAL_60_40";
    } else {
      if (quantities.join("/") !== "72.000000/48.000000")
        throw new Error(
          "Corrected family must persist the backend 72/48 proposal.",
        );
      allocation = "CORRECTED_72_48";
    }
    return reviewSuccess({
      success: true,
      safe_operator_message: "Đã lưu phân bổ nhà cung ứng.",
      warnings: [],
      blockers: [],
    });
  };

  procurementApi.getPurchaseOrders = async () => {
    const fixture =
      purchaseOrder === "NONE"
        ? createReviewPurchaseOrdersFixture("empty")
        : purchaseOrder === "STALE"
          ? createReviewPurchaseOrdersFixture("stale_po")
          : purchaseOrder === "RELEASED"
            ? createReviewPurchaseOrdersFixture("released_po")
            : createReviewPurchaseOrdersFixture("po_draft");
    return reviewSuccess(fixture);
  };

  procurementApi.createPurchaseOrderDrafts = async () => {
    purchaseOrder = handoff === "CORRECTED_120" ? "REGENERATED" : "DRAFT";
    return reviewSuccess({
      success: true,
      safe_operator_message:
        handoff === "CORRECTED_120"
          ? "Đã tạo lại đơn cần cập nhật."
          : "Đã tạo đơn mua cho ngày sẵn sàng.",
      warnings: [],
      blockers: [],
    });
  };

  procurementApi.releasePurchaseOrder = async () => {
    purchaseOrder = "RELEASED";
    return reviewSuccess({
      success: true,
      safe_operator_message: "Đã phát hành đơn mua cho nhà cung cấp.",
      document_number: "PO-20260902-2500000000004000",
      warnings: [],
      blockers: [],
    });
  };

  return {
    confirmedNeedApi,
    procurementApi,
    invalidateForPlanningCorrection() {
      if (purchaseOrder === "RELEASED")
        return {
          kind: "backend_error" as const,
          error: {
            success: false as const,
            error_code: "DOWNSTREAM_SUPPLIER_COMMITMENT_EXISTS",
            safe_message:
              "Không thể sửa nhu cầu sau khi đơn đã phát hành cho nhà cung cấp.",
          },
        };
      handoff = "NONE";
      return reviewSuccess({
        success: true,
        safe_operator_message: "Đã vô hiệu Bàn giao cũ để sửa nhu cầu.",
      });
    },
    releaseCorrectedHandoff() {
      handoff = "CORRECTED_120";
      purchaseOrder = purchaseOrder === "DRAFT" ? "STALE" : purchaseOrder;
      return reviewSuccess({
        success: true,
        safe_operator_message: "Đã phát hành Bàn giao đã sửa 120 kg.",
      });
    },
  };
}

function CrossStageJourney({
  journey,
}: {
  journey: ReturnType<typeof createCrossStageJourney>;
}) {
  const [page, setPage] = useState<"planning" | "procurement">("planning");
  const [initialHandoffReleased, setInitialHandoffReleased] = useState(false);
  return (
    <>
      <nav aria-label="Điều hướng hành trình kiểm thử">
        <button type="button" onClick={() => setPage("planning")}>
          Lập nhu cầu
        </button>
        <button type="button" onClick={() => setPage("procurement")}>
          Kế hoạch mua hàng
        </button>
      </nav>
      {page === "planning" ? (
        initialHandoffReleased ? (
          <section aria-label="Điều chỉnh nhu cầu Planning">
            <h2>Điều chỉnh nhu cầu Planning</h2>
            <p>Bàn giao hiện tại sẽ bị vô hiệu trước khi phát hành bản sửa.</p>
          </section>
        ) : (
          <PlanningRailActionProvider>
            <PlanningRailActionHost />
            <ConfirmedNeedReviewWorkbench
              authState={authState}
              api={journey.confirmedNeedApi}
              initialBatchId={confirmedNeedBatchId}
              mode="review"
              onPurchaseHandoffReleased={() => {
                setInitialHandoffReleased(true);
                setPage("procurement");
              }}
            />
          </PlanningRailActionProvider>
        )
      ) : (
        <SchoolCateringProcurementWorkbench
          authState={authState}
          api={journey.procurementApi}
          initialDateStart="2026-09-01"
          initialDateEnd="2026-09-07"
          mode="review"
        />
      )}
    </>
  );
}

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

const authState = {
  status: "authenticated",
  authSubject: "review-only-atlas-operator",
  user: { id: "review-only-atlas-operator" },
  session: { user: { id: "review-only-atlas-operator" } },
} as unknown as AtlasAuthState;

function renderWorkbench(
  api = createReviewSchoolCateringProcurementApi("default"),
) {
  render(
    <SchoolCateringProcurementWorkbench
      authState={authState}
      api={api}
      initialDateStart="2026-09-01"
      initialDateEnd="2026-09-07"
      mode="review"
    />,
  );
  return api;
}

describe("school-catering Procurement allocation workbench", () => {
  it("renders one table row per Allocation Family with the exact operator columns", async () => {
    renderWorkbench();
    await screen.findByText("Gạo thơm");
    const table = screen.getByRole("table", { name: "Allocation Family" });
    expect(within(table).getAllByRole("row")).toHaveLength(2);
    for (const heading of [
      "Ngày giao",
      "Trường / điểm giao",
      "Nguyên liệu",
      "Nhu cầu",
      "Đã phân bổ",
      "Còn lại / chênh lệch",
      "NCC",
      "Trạng thái",
    ]) {
      expect(
        within(table).getByRole("columnheader", { name: heading }),
      ).toBeVisible();
    }
    expect(screen.getByText("2 nguồn bàn giao")).toBeVisible();
    expect(
      screen.queryByText("25000000-0000-4000-8000-000000000071"),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("toolbar", { name: /Gạo thơm/ }),
    ).not.toBeInTheDocument();
  });

  it("opens an attached split editor while keeping recommendation advisory", async () => {
    const api = renderWorkbench();
    const confirm = vi.spyOn(api, "confirmRecommendations");
    fireEvent.click(
      await screen.findByRole("button", { name: "Mở phân bổ Gạo thơm" }),
    );

    const panel = screen.getByRole("region", { name: "Phân bổ Gạo thơm" });
    expect(panel).toHaveTextContent("100");
    expect(panel).toHaveTextContent("kg");
    expect(panel).toHaveTextContent("Ưu tiên 1");
    expect(within(panel).getByLabelText("Phân bổ NCC An Phú")).toHaveValue(
      "100.000000",
    );
    expect(confirm).not.toHaveBeenCalled();
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeVisible();
  });

  it("submits the complete two-supplier family snapshot with exact strings", async () => {
    const api = createReviewSchoolCateringProcurementApi("manual_split");
    const save = vi.spyOn(api, "saveAllocation");
    renderWorkbench(api);
    fireEvent.click(
      await screen.findByRole("button", { name: "Mở phân bổ Gạo thơm" }),
    );
    fireEvent.change(screen.getByLabelText("Phân bổ NCC An Phú"), {
      target: { value: "70.000000" },
    });
    fireEvent.change(screen.getByLabelText("Phân bổ NCC Bình Minh"), {
      target: { value: "30.000000" },
    });
    expect(screen.getByText("Tổng đang nhập: 100 kg")).toBeVisible();
    expect(screen.getByText("Chênh lệch: 0 kg")).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Lưu phân bổ" }));

    await waitFor(() => expect(save).toHaveBeenCalledOnce());
    expect(save.mock.calls[0]?.[0]).toMatchObject({
      expected_version: 1,
      payload: {
        family: {
          service_date: "2026-09-02",
          delivery_location_id: "25000000-0000-4000-8000-000000000011",
          ingredient_id: "25000000-0000-4000-8000-000000000021",
          unit_id: "25000000-0000-4000-8000-000000000031",
          expected_source_fingerprint: "review-source-100",
        },
        splits: [
          {
            supplier_id: "25000000-0000-4000-8000-000000000041",
            allocated_quantity: "70.000000",
          },
          {
            supplier_id: "25000000-0000-4000-8000-000000000042",
            allocated_quantity: "30.000000",
          },
        ],
      },
    });
    expect(
      await screen.findByRole("region", { name: "Kết quả lệnh Procurement" }),
    ).toHaveTextContent("Đã lưu phân bổ nhà cung ứng.");
  });

  it("keeps authoritative decimal quantities exact in table arithmetic", async () => {
    const api = createReviewSchoolCateringProcurementApi("manual_split");
    const fixture = createReviewProcurementWorkbenchFixture("manual_split");
    fixture.rows[0]!.family_quantity = "9007199254740993.123456";
    fixture.rows[0]!.splits[0]!.allocated_quantity = "9007199254740992.123455";
    fixture.rows[0]!.splits[1]!.allocated_quantity = "1.000001";
    vi.spyOn(api, "getWorkbench").mockResolvedValue({
      kind: "success",
      response: fixture as unknown as AtlasSuccessEnvelope,
    });

    renderWorkbench(api);
    const table = await screen.findByRole("table", {
      name: "Allocation Family",
    });
    expect(
      within(table).getAllByText("9007199254740993.123456 kg"),
    ).toHaveLength(2);
    expect(within(table).getByText("0 kg")).toBeVisible();
  });

  it("bulk-confirms only explicitly selected current recommendations", async () => {
    const api = renderWorkbench();
    const confirm = vi.spyOn(api, "confirmRecommendations");
    await screen.findByText("Gạo thơm");
    expect(confirm).not.toHaveBeenCalled();
    fireEvent.click(
      screen.getByRole("checkbox", { name: "Chọn đề xuất Gạo thơm" }),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Xác nhận phân bổ đề xuất" }),
    );

    await waitFor(() => expect(confirm).toHaveBeenCalledOnce());
    expect(confirm.mock.calls[0]?.[0].payload.candidates).toEqual([
      {
        service_date: "2026-09-02",
        delivery_location_id: "25000000-0000-4000-8000-000000000011",
        ingredient_id: "25000000-0000-4000-8000-000000000021",
        unit_id: "25000000-0000-4000-8000-000000000031",
        expected_family_version: 0,
        expected_source_fingerprint: "review-source-100",
      },
    ]);
  });

  it("keeps technical identity and lineage behind disclosure", async () => {
    renderWorkbench();
    fireEvent.click(
      await screen.findByRole("button", { name: "Mở phân bổ Gạo thơm" }),
    );
    expect(screen.queryByText("review-source-100")).not.toBeInTheDocument();
    fireEvent.click(screen.getByText("Dữ liệu truy vết"));
    expect(screen.getByText("review-source-100")).toBeVisible();
    expect(
      screen.getByText("25000000-0000-4000-8000-000000000071"),
    ).toBeVisible();
  });

  it("shows stale-version recovery persistently and requires authoritative reload", async () => {
    const api = createReviewSchoolCateringProcurementApi("stale_version");
    renderWorkbench(api);
    fireEvent.click(
      await screen.findByRole("button", { name: "Mở phân bổ Gạo thơm" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Lưu phân bổ" }));

    const result = await screen.findByRole("region", {
      name: "Kết quả lệnh Procurement",
    });
    expect(result).toHaveTextContent("Dữ liệu đã thay đổi");
    expect(result).toHaveTextContent("STALE_VERSION");
    expect(
      screen.getByRole("button", { name: "Tải lại dữ liệu hiện tại" }),
    ).toBeEnabled();
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
  });

  it("locks further mutation after an unknown write outcome until readback", async () => {
    const api = createReviewSchoolCateringProcurementApi("default");
    vi.spyOn(api, "saveAllocation").mockResolvedValue({
      kind: "transport_error",
      diagnostic: {
        code: "NETWORK_FAILURE",
        safeMessage: "Mất kết nối khi gửi lệnh.",
      },
    });
    renderWorkbench(api);
    fireEvent.click(
      await screen.findByRole("button", { name: "Mở phân bổ Gạo thơm" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Lưu phân bổ" }));

    const result = await screen.findByRole("region", {
      name: "Kết quả lệnh Procurement",
    });
    expect(result).toHaveTextContent("Chưa xác định được kết quả lệnh");
    expect(result).toHaveTextContent("bắt buộc tải lại");
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
    fireEvent.click(
      screen.getByRole("button", { name: "Tải lại dữ liệu hiện tại" }),
    );
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeEnabled(),
    );
  });

  it("renders natural Vietnamese exception states without automatic redistribution", async () => {
    renderWorkbench(
      createReviewSchoolCateringProcurementApi("needs_reallocation"),
    );
    expect(await screen.findByText("Cần phân bổ lại")).toBeVisible();
    fireEvent.click(
      screen.getByRole("button", { name: "Mở phân bổ Gạo thơm" }),
    );
    expect(screen.getByText(/NCC Bình Minh.*không còn phù hợp/)).toBeVisible();
    expect(screen.queryByDisplayValue("100.000000")).not.toBeInTheDocument();
  });
});

describe("school-catering Procurement purchase-order stage", () => {
  it("keeps exactly two stages and renders supplier-date orders with multi-location detail", async () => {
    render(
      <SchoolCateringProcurementWorkbench
        authState={authState}
        api={createReviewSchoolCateringProcurementApi("po_draft")}
        initialDateStart="2026-09-01"
        initialDateEnd="2026-09-07"
        initialStage="orders"
        mode="review"
      />,
    );

    const stages = screen.getByRole("navigation", {
      name: "Các bước Procurement",
    });
    expect(within(stages).getAllByRole("button")).toHaveLength(2);
    const table = await screen.findByRole("table", { name: "Đơn mua" });
    expect(within(table).getByText("NCC An Phú")).toBeVisible();
    expect(within(table).getByText("02/09/2026")).toBeVisible();
    expect(within(table).getByText("2 dòng")).toBeVisible();
    fireEvent.click(
      within(table).getByRole("button", { name: "Mở đơn mua NCC An Phú" }),
    );
    const detail = screen.getByRole("region", {
      name: "Chi tiết đơn mua NCC An Phú",
    });
    expect(detail).toHaveTextContent("Bếp chính Nguyễn Du");
    expect(detail).toHaveTextContent("Bếp chính Trần Quốc Toản");
    const lines = within(detail).getByRole("table", {
      name: "Dòng đơn mua NCC An Phú",
    });
    expect(within(lines).getByText("60")).toBeVisible();
    expect(within(lines).getByText("40")).toBeVisible();
    expect(within(lines).getAllByText("kg")).toHaveLength(2);
    expect(within(detail).queryByRole("textbox")).not.toBeInTheDocument();
    expect(screen.queryByLabelText(/số đơn/i)).not.toBeInTheDocument();
  });

  it("materializes the selected date range and preserves blocked dates beside usable results", async () => {
    const api = createReviewSchoolCateringProcurementApi("po_draft");
    const createDrafts = vi.spyOn(api, "createPurchaseOrderDrafts");
    createDrafts.mockResolvedValueOnce({
      kind: "success",
      response: {
        success: true,
        safe_operator_message: "Đã tạo đơn cho ngày sẵn sàng.",
        ready_dates: ["2026-09-02"],
        skipped_dates: ["2026-09-03"],
        warnings: [],
        blockers: ["03/09/2026: nhu cầu chưa sẵn sàng"],
      },
    });
    render(
      <SchoolCateringProcurementWorkbench
        authState={authState}
        api={api}
        initialDateStart="2026-09-01"
        initialDateEnd="2026-09-07"
        initialStage="orders"
        mode="review"
      />,
    );

    fireEvent.click(await screen.findByRole("button", { name: "Tạo đơn mua" }));
    await waitFor(() => expect(createDrafts).toHaveBeenCalledOnce());
    expect(createDrafts.mock.calls[0]?.[0].payload).toEqual({
      date_start: "2026-09-01",
      date_end: "2026-09-07",
    });
    const outcome = await screen.findByRole("region", {
      name: "Kết quả lệnh Procurement",
    });
    expect(outcome).toHaveTextContent("03/09/2026: nhu cầu chưa sẵn sàng");
    expect(screen.getByRole("table", { name: "Đơn mua" })).toHaveTextContent(
      "NCC An Phú",
    );
  });

  it("disables stale draft release and regenerates through the approved materialization command", async () => {
    const api = createReviewSchoolCateringProcurementApi("stale_po");
    const createDrafts = vi.spyOn(api, "createPurchaseOrderDrafts");
    render(
      <SchoolCateringProcurementWorkbench
        authState={authState}
        api={api}
        initialDateStart="2026-09-01"
        initialDateEnd="2026-09-07"
        initialStage="orders"
        mode="review"
      />,
    );

    fireEvent.click(
      await screen.findByRole("button", { name: "Mở đơn mua NCC An Phú" }),
    );
    expect(
      screen.getByRole("button", { name: "Phát hành cho NCC" }),
    ).toBeDisabled();
    fireEvent.click(
      screen.getByRole("button", { name: "Tạo lại đơn cần cập nhật" }),
    );
    await waitFor(() => expect(createDrafts).toHaveBeenCalledOnce());
  });

  it("releases one PO independently and displays only the server-generated official number", async () => {
    const api = createReviewSchoolCateringProcurementApi("po_draft");
    const release = vi.spyOn(api, "releasePurchaseOrder");
    render(
      <SchoolCateringProcurementWorkbench
        authState={authState}
        api={api}
        initialDateStart="2026-09-01"
        initialDateEnd="2026-09-07"
        initialStage="orders"
        mode="review"
      />,
    );

    fireEvent.click(
      await screen.findByRole("button", { name: "Mở đơn mua NCC An Phú" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Phát hành cho NCC" }));
    await waitFor(() => expect(release).toHaveBeenCalledOnce());
    expect(release.mock.calls[0]?.[0]).toMatchObject({
      expected_version: 1,
      payload: {
        purchase_order_id: "25000000-0000-4000-8000-000000000051",
        expected_purchase_order_revision_id:
          "25000000-0000-4000-8000-000000000052",
      },
    });
    expect(
      await screen.findAllByText("PO-20260902-2500000000004000"),
    ).toHaveLength(2);
    expect(
      screen.queryByRole("button", { name: "Phát hành cho NCC" }),
    ).not.toBeInTheDocument();
    expect(screen.getByText("Đã phát hành")).toBeVisible();
  });

  it("renders an already released PO as read-only", async () => {
    render(
      <SchoolCateringProcurementWorkbench
        authState={authState}
        api={createReviewSchoolCateringProcurementApi("released_po")}
        initialDateStart="2026-09-01"
        initialDateEnd="2026-09-07"
        initialStage="orders"
        mode="review"
      />,
    );
    fireEvent.click(
      await screen.findByRole("button", { name: "Mở đơn mua NCC An Phú" }),
    );
    expect(screen.getAllByText("PO-20260902-2500000000004000")).toHaveLength(2);
    expect(screen.getByText("Đã phát hành")).toBeVisible();
    expect(
      screen.queryByRole("button", { name: "Phát hành cho NCC" }),
    ).not.toBeInTheDocument();
  });

  it("discards an earlier PO read after the operator changes stage", async () => {
    const api = createReviewSchoolCateringProcurementApi("po_draft");
    let resolveOrders!: (
      value: Awaited<ReturnType<typeof api.getPurchaseOrders>>,
    ) => void;
    vi.spyOn(api, "getPurchaseOrders").mockReturnValueOnce(
      new Promise((resolve) => {
        resolveOrders = resolve;
      }),
    );
    render(
      <SchoolCateringProcurementWorkbench
        authState={authState}
        api={api}
        initialDateStart="2026-09-01"
        initialDateEnd="2026-09-07"
        initialStage="orders"
        mode="review"
      />,
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Phân bổ nhà cung ứng" }),
    );
    resolveOrders({
      kind: "success",
      response: createReviewProcurementWorkbenchFixture(
        "default",
      ) as unknown as AtlasSuccessEnvelope,
    });
    await screen.findByRole("table", { name: "Allocation Family" });
    expect(
      screen.queryByRole("table", { name: "Đơn mua" }),
    ).not.toBeInTheDocument();
  });

  it("discards a mutation result that resolves after the operator changes stage", async () => {
    const api = createReviewSchoolCateringProcurementApi("default");
    let resolveSave!: (
      value: Awaited<ReturnType<typeof api.saveAllocation>>,
    ) => void;
    vi.spyOn(api, "saveAllocation").mockReturnValueOnce(
      new Promise((resolve) => {
        resolveSave = resolve;
      }),
    );
    renderWorkbench(api);
    fireEvent.click(
      await screen.findByRole("button", { name: "Mở phân bổ Gạo thơm" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Lưu phân bổ" }));
    fireEvent.click(screen.getByRole("button", { name: "Đơn mua" }));
    await screen.findByRole("table", { name: "Đơn mua" });

    await act(async () => {
      resolveSave(
        reviewSuccess({
          success: true,
          safe_operator_message: "Kết quả cũ không được hiển thị.",
          warnings: [],
          blockers: [],
        }),
      );
    });

    await waitFor(() =>
      expect(
        screen.queryByText("Kết quả cũ không được hiển thị."),
      ).not.toBeInTheDocument(),
    );
    expect(screen.getByRole("table", { name: "Đơn mua" })).toBeVisible();
  });
});

describe("Planning to school-catering Procurement propagation", () => {
  it("preserves correction, rebalance, stale-draft, release, and downstream commitment boundaries", async () => {
    const journey = createCrossStageJourney();
    render(<CrossStageJourney journey={journey} />);

    await screen.findByText("Gạo thơm");
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await screen.findByText("Đã lưu thay đổi.");
    fireEvent.click(
      screen.getByRole("button", { name: "Chuyển sang lên đơn" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận chuyển" }));

    expect(
      await screen.findByRole("heading", { name: "Kế hoạch mua hàng" }),
    ).toBeVisible();
    fireEvent.click(
      await screen.findByRole("button", { name: "Mở phân bổ Gạo thơm" }),
    );
    fireEvent.change(screen.getByLabelText("Phân bổ NCC An Phú"), {
      target: { value: "60.000000" },
    });
    fireEvent.change(screen.getByLabelText("Phân bổ NCC Bình Minh"), {
      target: { value: "40.000000" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu phân bổ" }));
    await screen.findByText("Đã lưu phân bổ nhà cung ứng.");

    fireEvent.click(screen.getByRole("button", { name: "Đơn mua" }));
    fireEvent.click(await screen.findByRole("button", { name: "Tạo đơn mua" }));
    expect(
      await screen.findByRole("table", { name: "Đơn mua" }),
    ).toHaveTextContent("Bản nháp");

    fireEvent.click(screen.getByRole("button", { name: "Lập nhu cầu" }));
    expect(
      await screen.findByRole("heading", {
        name: "Điều chỉnh nhu cầu Planning",
      }),
    ).toBeVisible();
    expect(journey.invalidateForPlanningCorrection()).toMatchObject({
      kind: "success",
    });
    expect(journey.releaseCorrectedHandoff()).toMatchObject({
      kind: "success",
      response: {
        safe_operator_message: "Đã phát hành Bàn giao đã sửa 120 kg.",
      },
    });

    fireEvent.click(screen.getByRole("button", { name: "Kế hoạch mua hàng" }));
    expect(await screen.findByText("Có thể cân bằng lại")).toBeVisible();
    fireEvent.click(
      screen.getByRole("button", { name: "Mở phân bổ Gạo thơm" }),
    );
    expect(screen.getByLabelText("Phân bổ NCC An Phú")).toHaveValue(
      "72.000000",
    );
    expect(screen.getByLabelText("Phân bổ NCC Bình Minh")).toHaveValue(
      "48.000000",
    );
    expect(screen.getByText("Tổng đang nhập: 120 kg")).toBeVisible();
    expect(screen.getByText("Chênh lệch: 0 kg")).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Lưu phân bổ" }));
    await screen.findByText("Đã lưu phân bổ nhà cung ứng.");
    const familyTable = screen.getByRole("table", {
      name: "Allocation Family",
    });
    expect(within(familyTable).getAllByText("120 kg")).toHaveLength(2);

    fireEvent.click(screen.getByRole("button", { name: "Đơn mua" }));
    expect(await screen.findByText("Cần cập nhật")).toBeVisible();
    fireEvent.click(
      screen.getByRole("button", { name: "Mở đơn mua NCC An Phú" }),
    );
    expect(
      screen.getByRole("button", { name: "Phát hành cho NCC" }),
    ).toBeDisabled();
    fireEvent.click(
      screen.getByRole("button", { name: "Tạo lại đơn cần cập nhật" }),
    );
    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Phát hành cho NCC" }),
      ).toBeEnabled(),
    );
    fireEvent.click(screen.getByRole("button", { name: "Phát hành cho NCC" }));
    expect(
      await screen.findAllByText("PO-20260902-2500000000004000"),
    ).toHaveLength(2);

    expect(journey.invalidateForPlanningCorrection()).toMatchObject({
      kind: "backend_error",
      error: {
        error_code: "DOWNSTREAM_SUPPLIER_COMMITMENT_EXISTS",
      },
    });
    expect(screen.getAllByText("PO-20260902-2500000000004000")).toHaveLength(2);
  }, 20_000);
});
