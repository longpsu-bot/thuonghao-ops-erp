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

  it("shows the four active RMVP pages and marks later modules unavailable", () => {
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
      within(navigation).getByRole("button", { name: "Nguồn kế hoạch" }),
    ).toBeEnabled();

    for (const label of [/^Tổng quan/, /^Kế hoạch mua hàng/, /^Kho/]) {
      expect(
        within(navigation).getByRole("button", { name: label }),
      ).toBeDisabled();
    }
  });

  it("returns focus to the mobile navigation control after navigation", () => {
    render(<AtlasApp reviewMode />);

    const openNavigation = screen.getByRole("button", {
      name: "Mở điều hướng Atlas",
    });
    fireEvent.click(openNavigation);
    fireEvent.click(screen.getByRole("button", { name: "Nguồn kế hoạch" }));

    expect(
      screen.getByRole("button", { name: "Mở điều hướng Atlas" }),
    ).toHaveFocus();
  });

  it("keeps automatic readiness inside the five-tab Planning workflow", async () => {
    render(<AtlasApp reviewMode initialPage="planning-inputs" />);

    expect(
      screen.getByRole("heading", { level: 1, name: "Nguồn kế hoạch" }),
    ).toBeVisible();
    expect(
      screen.getByRole("heading", {
        level: 2,
        name: "Điều hành nguồn kế hoạch theo tuần",
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
    expect(tabs.map((tab) => tab.textContent)).toEqual([
      "Thực đơn tuần",
      "Sĩ số",
      "Pantry",
      "Tạo nhu cầu",
      "Xác nhận nhu cầu",
    ]);

    fireEvent.click(screen.getByRole("tab", { name: "Tạo nhu cầu" }));
    expect(
      await screen.findByText("Đầu vào đã sẵn sàng tạo nhu cầu"),
    ).toBeVisible();
    expect(screen.getByRole("button", { name: "Tạo nhu cầu" })).toBeVisible();
  });

  it("runs the connected review journey for consequential menu and attendance saves", async () => {
    render(<AtlasApp reviewMode initialPage="planning-inputs" />);

    expect(
      screen.getByRole("heading", { name: "Nguồn kế hoạch" }),
    ).toBeInTheDocument();
    expect(
      (await screen.findAllByText("Canh bí đỏ thịt bằm")).length,
    ).toBeGreaterThan(0);
    expect(screen.getByRole("tab", { name: "Thực đơn tuần" })).toHaveAttribute(
      "aria-selected",
      "true",
    );

    fireEvent.change(screen.getAllByLabelText(/Món canh ·/)[0], {
      target: { value: "review-planning-dish-3" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Xem trước" }));
    expect(
      await screen.findByText(/Xem trước có thẩm quyền/),
    ).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Lưu thực đơn" }));
    await waitFor(() => expect(screen.getByText("ĐÃ LƯU")).toBeInTheDocument());

    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    expect(
      screen.getByText(
        "Tạo từ mặc định theo đúng trường/ngày có thực đơn, nhập workbook hoặc dán hàng loạt; số 0 luôn là giá trị tường minh.",
      ),
    ).toBeInTheDocument();
    const studentInput = screen.getAllByLabelText(/Suất học sinh ·/)[0];
    fireEvent.change(studentInput, { target: { value: "421" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem trước" }));
    await screen.findByText(/Xem trước có thẩm quyền/);
    fireEvent.click(screen.getByRole("button", { name: "Lưu số suất ăn" }));
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
    fireEvent.change(screen.getAllByLabelText(/Món canh ·/)[0], {
      target: { value: "review-planning-dish-3" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Xem trước" }));
    await screen.findByText(/Xem trước có thẩm quyền/);
    fireEvent.click(screen.getByRole("button", { name: "Lưu thực đơn" }));
    expect(
      await screen.findByText(
        "Dữ liệu đã thay đổi. Hãy tải lại trước khi lưu.",
      ),
    ).toBeInTheDocument();

    fireEvent.change(scenario, { target: { value: "menu_retryable" } });
    await screen.findByRole("heading", { name: "Thực đơn tuần" });
    fireEvent.change(screen.getAllByLabelText(/Món canh ·/)[0], {
      target: { value: "review-planning-dish-3" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Xem trước" }));
    await screen.findByText(/Xem trước có thẩm quyền/);
    fireEvent.click(screen.getByRole("button", { name: "Lưu thực đơn" }));
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

  it("renders Menu columns and Dish choices only from review Dish Type fixtures", async () => {
    render(<AtlasApp reviewMode initialPage="planning-inputs" />);
    const soup = (await screen.findAllByLabelText(/^Món canh ·/))[0];
    expect(soup).toBeDefined();
    expect(
      within(soup!).getByRole("option", { name: "Canh bí đỏ thịt bằm" }),
    ).toBeInTheDocument();
    expect(
      within(soup!).queryByRole("option", { name: "Thịt lợn kho trứng" }),
    ).not.toBeInTheDocument();
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
      await screen.findByText("Nguồn thực đơn xem thử"),
    ).toBeInTheDocument();
    expect(
      await screen.findByText(/Xem trước có thẩm quyền/),
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

    fireEvent.click(
      screen.getByRole("button", {
        name: "Xem và sửa",
      }),
    );
    fireEvent.change(screen.getByLabelText("Suất học sinh mặc định"), {
      target: { value: "-1" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu thay đổi" }));
    expect(
      screen.getByText("Số suất mặc định phải là số nguyên không âm."),
    ).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText("Suất học sinh mặc định"), {
      target: { value: "512" },
    });
    fireEvent.change(screen.getByLabelText("Suất giáo viên mặc định"), {
      target: { value: "36" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu thay đổi" }));

    await waitFor(() =>
      expect(screen.queryByLabelText("Sửa số suất mặc định")).toBeNull(),
    );
    expect(screen.getByText("512 / 36")).toBeInTheDocument();
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
    fireEvent.click(screen.getByRole("button", { name: "Lưu thay đổi" }));
    expect(screen.getByText(/Điền đủ mã, tên, đơn vị mua/)).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Mã nguyên liệu"), {
      target: { value: "NL9001" },
    });
    fireEvent.change(screen.getByLabelText("Tên nguyên liệu"), {
      target: { value: "Bí đỏ hữu cơ" },
    });
    fireEvent.change(screen.getByLabelText("Đơn vị mua"), {
      target: { value: "unit-kg" },
    });
    fireEvent.change(screen.getByLabelText("Loại nguyên liệu"), {
      target: { value: "Rau củ" },
    });
    fireEvent.change(screen.getByLabelText("Cách mua"), {
      target: { value: "Mua theo kế hoạch" },
    });
    fireEvent.change(screen.getByLabelText("Bước đặt hàng"), {
      target: { value: "5" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu thay đổi" }));
    expect(await screen.findByText("Bí đỏ hữu cơ")).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText("Tìm nguyên liệu"), {
      target: { value: "NL0001" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Ưu tiên" }));
    fireEvent.change(screen.getByLabelText("Nhà cung ứng ưu tiên 2"), {
      target: { value: "review-supplier-01" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu thứ tự ưu tiên" }));
    expect(
      screen.getByText(
        "Tối đa sáu nhà cung cấp; nhà cung cấp và mức ưu tiên 1–6 không được trùng.",
      ),
    ).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText("Nhà cung ứng ưu tiên 2"), {
      target: { value: "review-supplier-05" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu thứ tự ưu tiên" }));
    await waitFor(() =>
      expect(
        screen.queryByLabelText("Sắp xếp ưu tiên nhà cung ứng"),
      ).not.toBeInTheDocument(),
    );
    expect(screen.getByText("Công ty Thực phẩm Hà Thành")).toBeInTheDocument();
  }, 15_000);

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
