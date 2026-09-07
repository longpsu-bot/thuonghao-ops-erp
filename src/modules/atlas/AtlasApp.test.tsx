import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render as testingLibraryRender,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasApp } from "./AtlasApp";
import { ATLAS_REVIEW_NOTICE } from "./review/reviewMode";
import { createReviewProcurementWorkbenchFixture } from "./procurement/reviewSchoolCateringProcurementApi";
import type { AtlasSupabaseClientResult } from "./connection/supabaseClient";
import type { ReactNode } from "react";

Object.defineProperty(window, "matchMedia", {
  writable: true,
  value: vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
});

function render(children: ReactNode) {
  return testingLibraryRender(children);
}

afterEach(cleanup);

describe("Atlas master-data shell", () => {
  it("carries saved 120 through Planning to supplier allocation and preserves the working date on return", async () => {
    render(<AtlasApp reviewMode initialPage="planning-inputs" />);
    const workingDate = (
      screen.getByLabelText("Ngày phục vụ") as HTMLInputElement
    ).value;
    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
    const quantity = await screen.findByLabelText("Số lượng xác nhận Gạo thơm");
    fireEvent.change(quantity, { target: { value: "120" } });
    fireEvent.change(screen.getByLabelText("Ghi chú Gạo thơm"), {
      target: { value: "Xác nhận số lượng thực tế" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await screen.findByText("Đã lưu thay đổi.");
    fireEvent.click(
      screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
    );
    const allocations = await screen.findByRole("table", {
      name: "Allocation Family",
    });
    expect(allocations).toHaveTextContent("120 kg");
    expect(allocations).not.toHaveTextContent("100 kg");
    expect(screen.getByLabelText("Ngày phục vụ")).toHaveValue(workingDate);
    expect(
      screen.getByRole("heading", { name: "Phân bổ nhà cung ứng", level: 1 }),
    ).toHaveFocus();
    expect(
      screen.getByRole("button", { name: "Tiếp tục lên đơn" }),
    ).toBeDisabled();
    fireEvent.click(
      within(
        screen.getByRole("navigation", { name: "Điều hướng Atlas" }),
      ).getByRole("button", { name: "Lập nhu cầu" }),
    );
    expect(screen.getByLabelText("Ngày phục vụ")).toHaveValue(workingDate);
    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
    expect(
      await screen.findByLabelText("Số lượng xác nhận Gạo thơm"),
    ).toHaveValue("120");
  });

  it("uses the explicit review adapter without constructing a Supabase connection", async () => {
    const connectionFactory = vi.fn(() => ({
      status: "configuration_error" as const,
      safeMessage: "Không dùng trong bản xem thử.",
    }));

    render(
      <AtlasApp
        reviewMode
        connectionFactory={connectionFactory}
        initialPage="customers-schools"
      />,
    );

    expect(connectionFactory).not.toHaveBeenCalled();
    expect(screen.getByText(ATLAS_REVIEW_NOTICE)).toBeInTheDocument();
    expect(
      await screen.findByText("Trường Tiểu học Nguyễn Du"),
    ).toBeInTheDocument();
    expect(document.body.textContent).not.toContain("Supabase");
    expect(document.body.textContent).not.toContain("Prototype");
  });

  it("enables the six active Atlas pages including Warehouse dispatch release", () => {
    render(<AtlasApp reviewMode />);

    const navigation = screen.getByRole("navigation", {
      name: "Điều hướng Atlas",
    });
    expect(
      within(navigation).getByRole("button", { name: "Trường học" }),
    ).toBeEnabled();
    expect(
      within(navigation).getByRole("button", {
        name: "Nguyên liệu và Nhà cung ứng",
      }),
    ).toBeEnabled();
    expect(
      within(navigation).getByRole("button", { name: "Công thức" }),
    ).toBeEnabled();
    expect(
      within(navigation).getByRole("button", { name: "Lập nhu cầu" }),
    ).toBeEnabled();
    expect(
      within(navigation).getByRole("button", { name: "Kế hoạch mua hàng" }),
    ).toBeEnabled();
    expect(
      within(navigation).getByRole("button", { name: "Phiếu xuất kho" }),
    ).toBeEnabled();
    expect(within(navigation).getByText("Kho")).toBeInTheDocument();
    expect(
      within(navigation).getByRole("button", { name: /^Tổng quan/ }),
    ).toBeDisabled();
  });

  it("opens the read-only PXK workbench from Kho navigation", async () => {
    render(<AtlasApp reviewMode />);
    fireEvent.click(screen.getByRole("button", { name: "Phiếu xuất kho" }));
    expect(
      await screen.findByRole("heading", { level: 1, name: "Phiếu xuất kho" }),
    ).toBeVisible();
    expect(screen.getByText(/Bản xem trước chỉ đọc/i)).toBeVisible();
  });

  it("renders the connected Procurement review workbench from Atlas navigation", async () => {
    render(<AtlasApp reviewMode initialPage="procurement" />);

    expect(
      screen.getByRole("heading", {
        level: 1,
        name: "Phân bổ nhà cung ứng",
      }),
    ).toBeVisible();
    expect(
      await screen.findByRole("table", { name: "Allocation Family" }),
    ).toBeVisible();
    expect(screen.getByText("Gạo thơm")).toBeVisible();
  });

  it("renders Procurement through the connected Atlas RPC transport", async () => {
    const session = {
      access_token: "test-only",
      refresh_token: "test-only",
      expires_in: 3600,
      expires_at: Math.floor(Date.now() / 1000) + 3600,
      token_type: "bearer",
      user: { id: "connected-procurement-operator" },
    };
    const getSession = vi.fn().mockResolvedValue({
      data: { session },
      error: null,
    });
    const rpc = vi.fn(() => ({
      retry: vi.fn().mockResolvedValue({
        data: {
          ...createReviewProcurementWorkbenchFixture("default"),
          contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
          preparation: null,
        },
        error: null,
      }),
    }));
    const connection = {
      status: "configured",
      environmentLabel: "Atlas connected test",
      client: {
        auth: {
          getSession,
          onAuthStateChange: vi.fn(() => ({
            data: { subscription: { unsubscribe: vi.fn() } },
          })),
          signInWithPassword: vi.fn(),
          signOut: vi.fn(),
        },
        schema: vi.fn(() => ({ rpc })),
      },
    } as unknown as AtlasSupabaseClientResult;

    render(
      <AtlasApp
        reviewMode={false}
        connection={connection}
        initialPage="procurement"
      />,
    );

    expect(
      screen.getByRole("heading", {
        level: 1,
        name: "Phân bổ nhà cung ứng",
      }),
    ).toBeVisible();
    expect(
      await screen.findByRole("table", { name: "Allocation Family" }),
    ).toBeVisible();
    await waitFor(() =>
      expect(rpc).toHaveBeenCalledWith(
        "get_confirmed_supplier_allocation_workbench",
        expect.any(Object),
      ),
    );
  });

  it("does not route Atlas through the dormant Procurement prototype", async () => {
    const { readFileSync } = await vi.importActual<{
      readFileSync(path: string | URL, encoding: "utf8"): string;
    }>("node:fs");
    const source = readFileSync("src/modules/atlas/AtlasApp.tsx", "utf8");
    expect(source).not.toContain("../procurement/ProcurementWorkbench");
    expect(source).not.toContain("modules/procurement/ProcurementWorkbench");
  });

  it("returns focus to the mobile navigation control after navigation", () => {
    render(<AtlasApp reviewMode />);

    const openNavigation = screen.getByRole("button", {
      name: "Mở điều hướng Atlas",
    });
    fireEvent.click(openNavigation);
    fireEvent.click(screen.getByRole("button", { name: "Lập nhu cầu" }));

    expect(
      screen.getByRole("button", { name: "Mở điều hướng Atlas" }),
    ).toHaveFocus();
  });

  it("keeps automatic readiness inside the four-task Planning workflow", async () => {
    render(<AtlasApp reviewMode initialPage="planning-inputs" />);

    expect(
      screen.getByRole("heading", {
        level: 1,
        name: "Thực đơn tuần",
      }),
    ).toBeVisible();
    expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);

    const navigation = screen.getByRole("navigation", {
      name: "Điều hướng Atlas",
    });
    expect(within(navigation).getAllByRole("button")).toHaveLength(7);
    expect(
      within(navigation).queryByRole("button", { name: "Sẵn sàng đầu vào" }),
    ).not.toBeInTheDocument();

    const tabs = await screen.findAllByRole("tab");
    expect(tabs.map((tab) => tab.getAttribute("aria-label"))).toEqual([
      "Thực đơn",
      "Sĩ số",
      "Bổ sung",
      "Xác nhận nhu cầu",
    ]);

    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
    expect(
      screen.queryByRole("navigation", {
        name: "Chọn ngày xác nhận nhu cầu",
      }),
    ).not.toBeInTheDocument();
    expect(
      await screen.findByRole("button", { name: "In bản dự kiến" }),
    ).toBeEnabled();
  });

  it("runs the connected review journey for consequential menu and attendance saves", async () => {
    render(<AtlasApp reviewMode initialPage="planning-inputs" />);

    expect(
      screen.getByRole("heading", { level: 1, name: "Thực đơn tuần" }),
    ).toBeInTheDocument();
    expect(
      (await screen.findAllByText("Canh bí đỏ thịt bằm")).length,
    ).toBeGreaterThan(0);
    expect(screen.getByRole("tab", { name: "Thực đơn" })).toHaveAttribute(
      "aria-selected",
      "true",
    );

    const sync = await screen.findByRole("button", {
      name: "Đồng bộ từ Google Sheet",
    });
    await waitFor(() => expect(sync).toBeEnabled());
    fireEvent.click(sync);
    await screen.findByText("Có bản đồng bộ chờ xác nhận");
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    expect(
      await screen.findByRole("region", { name: "Xem thay đổi thực đơn" }),
    ).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await waitFor(() =>
      expect(screen.getByText(/Đã lưu thực đơn\./)).toBeInTheDocument(),
    );

    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    expect(
      screen.getByRole("heading", { level: 1, name: "Sĩ số" }),
    ).toBeVisible();
    expect(
      screen.getByRole("searchbox", { name: "Tìm trong sĩ số" }),
    ).toBeVisible();
    const studentInput = screen.getAllByLabelText(/Suất học sinh ·/)[0];
    fireEvent.change(studentInput, { target: { value: "421" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await screen.findByRole("region", { name: "Xem thay đổi sĩ số" });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await waitFor(() =>
      expect(screen.getByText(/Đã lưu số suất ăn\./)).toBeInTheDocument(),
    );
  }, 15_000);

  it("renders Planning denial, stale, retryable, and session-loss states safely", async () => {
    render(<AtlasApp reviewMode initialPage="planning-inputs" />);
    const scenario = screen.getByLabelText("Tình huống xem thử");

    fireEvent.change(scenario, {
      target: { value: "menu_permission_denied" },
    });
    expect(
      await screen.findByText("Bạn không có quyền thực hiện thao tác này."),
    ).toBeInTheDocument();

    fireEvent.change(scenario, { target: { value: "menu_stale" } });
    await screen.findByRole("heading", { name: "Thực đơn tuần" });
    const sync = await screen.findByRole("button", {
      name: "Đồng bộ từ Google Sheet",
    });
    await waitFor(() => expect(sync).toBeEnabled());
    fireEvent.click(sync);
    await screen.findByText("Có bản đồng bộ chờ xác nhận");
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await screen.findByRole("region", { name: "Xem thay đổi thực đơn" });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    expect(
      await screen.findByText(
        "Dữ liệu đã thay đổi. Hãy tải lại trước khi lưu.",
      ),
    ).toBeInTheDocument();

    fireEvent.change(scenario, { target: { value: "menu_retryable" } });
    await screen.findByRole("heading", { name: "Thực đơn tuần" });
    const retrySync = await screen.findByRole("button", {
      name: "Đồng bộ từ Google Sheet",
    });
    await waitFor(() => expect(retrySync).toBeEnabled());
    fireEvent.click(retrySync);
    await screen.findByText("Có bản đồng bộ chờ xác nhận");
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await screen.findByRole("region", { name: "Xem thay đổi thực đơn" });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    expect(
      await screen.findByText(
        "Dữ liệu đang được cập nhật. Có thể thử lại đúng yêu cầu.",
      ),
    ).toBeInTheDocument();

    fireEvent.change(scenario, { target: { value: "menu_session_lost" } });
    expect(
      await screen.findByText(
        "Phiên làm việc đã hết. Vui lòng đăng nhập lại để tiếp tục.",
      ),
    ).toBeInTheDocument();
  });

  it("renders read-only Menu content and columns from review Dish Type fixtures", async () => {
    render(<AtlasApp reviewMode initialPage="planning-inputs" />);
    await screen.findAllByText("Canh bí đỏ thịt bằm");
    const grid = screen.getByLabelText("Lưới thực đơn");
    expect(grid).toHaveTextContent("Canh bí đỏ thịt bằm");
    expect(within(grid).queryByRole("combobox")).not.toBeInTheDocument();
    expect(
      screen.getByRole("columnheader", { name: "Nước" }),
    ).toBeInTheDocument();

    const scenario = screen.getByLabelText("Tình huống xem thử");
    fireEvent.change(scenario, { target: { value: "dish_types_renamed" } });
    expect(
      await screen.findByRole("columnheader", { name: "Canh trong ngày" }),
    ).toBeInTheDocument();

    fireEvent.change(scenario, { target: { value: "dish_types_reordered" } });
    await screen.findByRole("columnheader", { name: "Món mặn" });
    const headers = screen
      .getAllByRole("columnheader")
      .map((header) => header.textContent);
    expect(headers.indexOf("Món mặn")).toBeLessThan(
      headers.indexOf("Món canh"),
    );

    fireEvent.change(scenario, { target: { value: "dish_types_added" } });
    expect(
      await screen.findByRole("columnheader", { name: "Món trộn" }),
    ).toBeInTheDocument();
  });

  it("keeps Google sync explicit, preview-only, and request-free in review mode", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    render(<AtlasApp reviewMode initialPage="planning-inputs" />);
    const scenario = screen.getByLabelText("Tình huống xem thử");

    fireEvent.change(scenario, { target: { value: "google_source_missing" } });
    expect(
      await screen.findByText(/Chưa cấu hình nguồn Google Sheet/),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Đồng bộ từ Google Sheet" }),
    ).toBeDisabled();

    fireEvent.change(scenario, { target: { value: "google_fetch_success" } });
    const sync = await screen.findByRole("button", {
      name: "Đồng bộ từ Google Sheet",
    });
    await waitFor(() => expect(sync).toBeEnabled());
    fireEvent.click(sync);
    expect(
      await screen.findByText("Có bản đồng bộ chờ xác nhận"),
    ).toBeInTheDocument();
    await screen.findByText("Bằng chứng Google Sheet vừa tải");
    expect(
      screen.queryByRole("region", { name: "Xem thay đổi thực đơn" }),
    ).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    expect(
      await screen.findByRole("region", { name: "Xem thay đổi thực đơn" }),
    ).toBeInTheDocument();
    expect(fetchSpy).not.toHaveBeenCalled();
    fetchSpy.mockRestore();
  });

  it("renders safe Google source, empty, sheet, connector, denied, and retryable states", async () => {
    render(<AtlasApp reviewMode initialPage="planning-inputs" />);
    const scenario = screen.getByLabelText("Tình huống xem thử");
    const cases = [
      [
        "google_source_unavailable",
        "Nguồn Google Sheet không tồn tại hoặc đã ngừng hoạt động.",
      ],
      ["google_empty_sheet", "Trang tính của tuần đã chọn không có dữ liệu."],
      ["google_sheet_missing", "Không tìm thấy trang tính của tuần đã chọn."],
      [
        "google_connector_unavailable",
        "Bộ đồng bộ Google Sheet hiện không sẵn sàng.",
      ],
      ["google_permission_denied", "Bạn không có quyền đọc nguồn Kế hoạch."],
      [
        "google_retryable",
        "Google Sheets tạm thời không sẵn sàng. Có thể thử lại.",
      ],
    ] as const;
    for (const [value, message] of cases) {
      fireEvent.change(scenario, { target: { value } });
      const sync = await screen.findByRole("button", {
        name: "Đồng bộ từ Google Sheet",
      });
      await waitFor(() => expect(sync).toBeEnabled());
      fireEvent.click(sync);
      expect(await screen.findByText(message)).toBeInTheDocument();
    }

    fireEvent.change(scenario, { target: { value: "google_session_lost" } });
    expect(
      await screen.findByText(
        "Phiên làm việc đã hết. Vui lòng đăng nhập lại để tiếp tục.",
      ),
    ).toBeInTheDocument();
  }, 15_000);

  it("supports the owner school review journey including validation and save", async () => {
    render(<AtlasApp reviewMode initialPage="customers-schools" />);

    expect(
      screen.getByRole("heading", { name: "Trường học" }),
    ).toBeInTheDocument();
    expect(
      screen.getByText(
        "Quản lý thông tin vận hành và sĩ số mặc định của trường.",
      ),
    ).toBeInTheDocument();
    await screen.findByText("Trường Tiểu học Nguyễn Du");

    fireEvent.change(screen.getByLabelText("Tìm trường"), {
      target: { value: "Nguyễn Du" },
    });
    expect(screen.getByText("Trường Tiểu học Nguyễn Du")).toBeInTheDocument();

    expect(
      screen.queryByRole("button", { name: "Xem và sửa" }),
    ).not.toBeInTheDocument();
    const studentInput = screen.getByLabelText(
      "Học sinh mặc định — Trường Tiểu học Nguyễn Du",
    );
    const teacherInput = screen.getByLabelText(
      "Giáo viên mặc định — Trường Tiểu học Nguyễn Du",
    );
    const review = screen.getByRole("button", { name: "Xem thay đổi" });
    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();

    fireEvent.change(studentInput, {
      target: { value: "-1" },
    });
    expect(studentInput).toHaveAttribute("aria-invalid", "true");
    expect(review).toBeDisabled();

    fireEvent.change(studentInput, {
      target: { value: "512" },
    });
    fireEvent.change(teacherInput, {
      target: { value: "36" },
    });
    fireEvent.click(review);

    const dialog = await screen.findByRole("dialog", { name: "Xem thay đổi" });
    expect(
      within(dialog).getByText("Trường Tiểu học Nguyễn Du"),
    ).toBeInTheDocument();
    fireEvent.click(within(dialog).getByRole("button", { name: "Lưu" }));

    await waitFor(() => expect(studentInput).toHaveValue(512));
    expect(teacherInput).toHaveValue(36);
    expect(screen.getByText("Chưa có thay đổi")).toBeInTheDocument();
  });

  it("supports ingredient creation and a validated supplier-priority save", async () => {
    render(<AtlasApp reviewMode initialPage="ingredients-units" />);

    expect(
      screen.getByRole("heading", {
        name: "Nguyên liệu và Nhà cung ứng",
      }),
    ).toBeInTheDocument();
    expect(
      screen.getByText(
        "Quản lý thông tin mua hàng, trạng thái nguyên liệu và thứ tự ưu tiên nhà cung ứng.",
      ),
    ).toBeInTheDocument();
    await screen.findByText("Gạo Jasmine");

    fireEvent.click(screen.getByRole("button", { name: "Tạo nguyên liệu" }));
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeDisabled();
    expect(screen.queryByLabelText("Mã nguyên liệu")).not.toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Tên nguyên liệu"), {
      target: { value: "Bí đỏ hữu cơ" },
    });
    fireEvent.change(screen.getByLabelText("Đơn vị mua"), {
      target: { value: "unit-kg" },
    });
    fireEvent.change(screen.getByLabelText("Loại nguyên liệu"), {
      target: { value: "review-ingredient-type-rau_cu_qua" },
    });
    fireEvent.change(screen.getByLabelText("Nhóm đặt hàng"), {
      target: { value: "review-ingredient-order-group-daily_vegetable" },
    });
    fireEvent.change(screen.getByLabelText("Mức làm tròn khi đặt hàng"), {
      target: { value: "5" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    let dialog = await screen.findByRole("dialog", { name: "Xem thay đổi" });
    await waitFor(() =>
      expect(within(dialog).getByText("Nguyên liệu mới")).toBeVisible(),
    );
    fireEvent.click(within(dialog).getByRole("button", { name: "Lưu" }));
    await waitFor(
      () => expect(screen.getByText("Bí đỏ hữu cơ")).toBeInTheDocument(),
      { timeout: 10_000 },
    );

    fireEvent.change(screen.getByLabelText("Tìm nguyên liệu"), {
      target: { value: "NL0001" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Ưu tiên" }));
    fireEvent.change(screen.getByLabelText("Nhà cung ứng ưu tiên 2"), {
      target: { value: "review-supplier-01" },
    });
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeDisabled();
    expect(
      screen.getByText(
        "Tối đa sáu nhà cung ứng; nhà cung ứng và mức ưu tiên 1–6 không được trùng.",
      ),
    ).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText("Nhà cung ứng ưu tiên 2"), {
      target: { value: "review-supplier-05" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    dialog = await screen.findByRole("dialog", { name: "Xem thay đổi" });
    await waitFor(() =>
      expect(within(dialog).getByText("Sau thay đổi")).toBeVisible(),
    );
    fireEvent.click(within(dialog).getByRole("button", { name: "Lưu" }));
    await waitFor(() =>
      expect(
        screen.queryByLabelText("Sắp xếp ưu tiên nhà cung ứng"),
      ).not.toBeInTheDocument(),
    );
    expect(screen.getByText("Công ty Thực phẩm Hà Thành")).toBeInTheDocument();
  }, 60_000);

  it("renders review-only loading, empty, permission, session, and server outcomes", async () => {
    render(<AtlasApp reviewMode />);
    const scenario = screen.getByLabelText("Tình huống xem thử");

    fireEvent.change(scenario, { target: { value: "empty" } });
    expect(await screen.findByText("Chưa có trường học.")).toBeInTheDocument();

    fireEvent.change(scenario, { target: { value: "permission_denied" } });
    expect(
      await screen.findByText("Bạn không có quyền thực hiện thao tác này."),
    ).toBeInTheDocument();

    fireEvent.change(scenario, { target: { value: "session_lost" } });
    expect(
      await screen.findByText(
        "Phiên làm việc đã hết. Vui lòng đăng nhập lại để tiếp tục.",
      ),
    ).toBeInTheDocument();

    fireEvent.change(scenario, { target: { value: "server_error" } });
    expect(
      await screen.findByText(
        "Không thể kết nối để hoàn tất thao tác. Vui lòng thử lại.",
      ),
    ).toBeInTheDocument();

    fireEvent.change(scenario, { target: { value: "loading" } });
    expect(
      await screen.findByText("Đang tải dữ liệu trường học…"),
    ).toBeInTheDocument();
  });

  it("keeps the normal build on the connected session path", () => {
    const connectionFactory = vi.fn(() => ({
      status: "configuration_error" as const,
      safeMessage: "Thiếu cấu hình.",
    }));
    render(
      <AtlasApp reviewMode={false} connectionFactory={connectionFactory} />,
    );

    expect(connectionFactory).toHaveBeenCalledOnce();
    expect(screen.queryByText(ATLAS_REVIEW_NOTICE)).not.toBeInTheDocument();
    expect(
      screen.getByText("Chưa thể kết nối dữ liệu Atlas"),
    ).toBeInTheDocument();
    expect(
      screen.getByText("Atlas · lỗi cấu hình · non-production"),
    ).toBeInTheDocument();
    expect(
      screen.queryByText("Trường Tiểu học Nguyễn Du"),
    ).not.toBeInTheDocument();
  });
});
