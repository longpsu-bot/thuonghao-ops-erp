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
import { AtlasApp } from "./AtlasApp";
import { ATLAS_REVIEW_NOTICE } from "./review/reviewMode";

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

  it("shows the three active RMVP pages and marks later modules unavailable", () => {
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

    for (const label of [
      /^Tổng quan/,
      /^Kế hoạch nhu cầu/,
      /^Thu mua/,
      /^Kho/,
    ]) {
      expect(
        within(navigation).getByRole("button", { name: label }),
      ).toBeDisabled();
    }
  });

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
      screen.queryByText("Trường Tiểu học Nguyễn Du"),
    ).not.toBeInTheDocument();
  });
});
