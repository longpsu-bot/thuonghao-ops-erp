import "@testing-library/jest-dom/vitest";
import { MantineProvider } from "@mantine/core";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { atlasTheme } from "../../../theme";
import { createReviewAuthState } from "../review/reviewMode";
import type {
  AtlasRpcResult,
  AtlasSuccessEnvelope,
} from "../connection/atlasRpc";
import { createReviewSchoolFulfilmentReconciliationApi } from "./reviewSchoolFulfilmentReconciliationApi";
import { SchoolFulfilmentReconciliationWorkbench } from "./SchoolFulfilmentReconciliationWorkbench";
import type { SchoolFulfilmentReconciliationApi } from "./schoolFulfilmentReconciliationApi";
import type { SchoolFulfilmentWorkbenchData } from "./schoolFulfilmentReconciliationModel";

afterEach(cleanup);

async function reviewData() {
  const result =
    await createReviewSchoolFulfilmentReconciliationApi().getWorkbench({});
  if (result.kind !== "success") throw new Error("review evidence unavailable");
  return structuredClone(
    result.response,
  ) as unknown as SchoolFulfilmentWorkbenchData;
}

function renderWorkbench(api: SchoolFulfilmentReconciliationApi) {
  return render(
    <MantineProvider theme={atlasTheme} env="test">
      <SchoolFulfilmentReconciliationWorkbench
        authState={createReviewAuthState("ready")}
        api={api}
        initialDateStart="2026-09-24"
        initialDateEnd="2026-09-24"
      />
    </MantineProvider>,
  );
}

function apiFor(
  data: SchoolFulfilmentWorkbenchData,
): SchoolFulfilmentReconciliationApi {
  return {
    async getWorkbench() {
      return {
        kind: "success",
        response: data as unknown as AtlasSuccessEnvelope,
      };
    },
  };
}

describe("School fulfilment reconciliation workbench", () => {
  it("renders exact strings with comparison and operations separated", async () => {
    renderWorkbench(createReviewSchoolFulfilmentReconciliationApi());
    expect(
      await screen.findByRole("heading", {
        name: "Đối chiếu PO / Phiếu xuất kho",
      }),
    ).toBeVisible();
    expect(
      await screen.findByText(
        "kg: PO 100.000000 / PXK 100.000000 / Δ 0.000000",
      ),
    ).toBeVisible();
    expect(screen.getByText("Khớp")).toBeVisible();
    expect(screen.getByText("Phiếu hiện hành")).toBeVisible();
    expect(screen.getByText("Không có thao tác ghi")).toBeVisible();
    expect(
      screen.queryByRole("button", { name: /phát hành|lưu|duyệt/i }),
    ).toBeNull();
  });

  it.each([
    ["OK", "Khớp"],
    ["NO_PO", "Chưa có PO"],
    ["NO_PXK", "Chưa có PXK"],
    ["INGREDIENT_CHANGED", "Khác nguyên liệu"],
    ["MISMATCH", "Lệch số lượng"],
  ] as const)("renders %s", async (status, label) => {
    const data = await reviewData();
    data.rows[0].comparison_status = status;
    renderWorkbench(apiFor(data));
    expect(await screen.findByText(label)).toBeVisible();
  });

  it("keeps mixed units separate and operational blockers distinct", async () => {
    const data = await reviewData();
    data.rows[0].quantity_totals_by_unit = [
      {
        unit_id: "kg",
        unit_code: "kg",
        po_quantity: "10",
        pxk_quantity: "20",
        delta_quantity: "-10",
      },
      {
        unit_id: "piece",
        unit_code: "cái",
        po_quantity: "20",
        pxk_quantity: "10",
        delta_quantity: "10",
      },
    ];
    data.rows[0].comparison_status = "MISMATCH";
    data.rows[0].pxk_state = "BLOCKED";
    data.rows[0].blockers = ["PROCUREMENT_NOT_CURRENT"];
    renderWorkbench(apiFor(data));
    expect(await screen.findByText("kg: PO 10 / PXK 20 / Δ -10")).toBeVisible();
    expect(screen.getByText("cái: PO 20 / PXK 10 / Δ 10")).toBeVisible();
    expect(screen.queryByText(/tổng.*30/i)).toBeNull();
    expect(screen.getByText("Lệch số lượng")).toBeVisible();
    expect(screen.getByText(/Kế hoạch mua hàng chưa khớp/i)).toBeVisible();
  });

  it("ignores a stale async response after a newer filter result", async () => {
    const older = await reviewData();
    const newer = await reviewData();
    older.rows[0].school_name = "Trường cũ";
    newer.rows[0].school_name = "Trường mới";
    let resolveOlder: (value: AtlasRpcResult) => void = () => {};
    let resolveNewer: (value: AtlasRpcResult) => void = () => {};
    const getWorkbench = vi
      .fn()
      .mockImplementationOnce(
        () =>
          new Promise((resolve) => {
            resolveOlder = resolve;
          }),
      )
      .mockImplementationOnce(
        () =>
          new Promise((resolve) => {
            resolveNewer = resolve;
          }),
      );
    renderWorkbench({ getWorkbench });
    await waitFor(() => expect(getWorkbench).toHaveBeenCalledTimes(1));
    fireEvent.change(screen.getByRole("textbox", { name: "Tìm kiếm" }), {
      target: { value: "mới" },
    });
    await waitFor(() => expect(getWorkbench).toHaveBeenCalledTimes(2));
    resolveNewer({
      kind: "success",
      response: newer as unknown as AtlasSuccessEnvelope,
    });
    expect(await screen.findByText("Trường mới")).toBeVisible();
    resolveOlder({
      kind: "success",
      response: older as unknown as AtlasSuccessEnvelope,
    });
    await waitFor(() => expect(screen.queryByText("Trường cũ")).toBeNull());
  });
});
