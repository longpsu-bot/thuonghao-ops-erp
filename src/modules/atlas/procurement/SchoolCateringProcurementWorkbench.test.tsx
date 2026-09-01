import "@testing-library/jest-dom/vitest";
import {
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
import { SchoolCateringProcurementWorkbench } from "./SchoolCateringProcurementWorkbench";
import {
  createReviewProcurementWorkbenchFixture,
  createReviewSchoolCateringProcurementApi,
} from "./reviewSchoolCateringProcurementApi";

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
