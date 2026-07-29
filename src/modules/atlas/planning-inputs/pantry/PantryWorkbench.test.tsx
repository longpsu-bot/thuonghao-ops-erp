import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { AtlasAuthState } from "../../connection/authSession";
import { PantryWorkbench } from "./PantryWorkbench";
import { createReviewPantryApi } from "./reviewPantryApi";

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

const authState = {
  status: "authenticated",
  authSubject: "review-only-atlas-operator",
  user: { id: "review-only-atlas-operator" },
  session: {
    access_token: "review",
    refresh_token: "review",
    expires_in: 3600,
    token_type: "bearer",
    user: { id: "review-only-atlas-operator" },
  },
} as unknown as AtlasAuthState;

describe("PANTRY-02 workbench", () => {
  it("uses Purpose metadata and keeps location and unit backend-derived", async () => {
    render(
      <PantryWorkbench
        authState={authState}
        api={createReviewPantryApi("ready")}
        weekStart="2026-08-03"
        mode="review"
      />,
    );

    expect(
      await screen.findByText("Bổ sung theo yêu cầu của trường"),
    ).toBeInTheDocument();
    expect(screen.getByText("Bếp chính Minh Khai")).toHaveAttribute(
      "data-derived",
      "delivery-location",
    );
    expect(screen.getByText("Kilôgam")).toHaveAttribute(
      "data-derived",
      "purchase-unit",
    );
    expect(
      screen.queryByRole("combobox", { name: /Điểm giao nhận/ }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("combobox", { name: /Đơn vị/ }),
    ).not.toBeInTheDocument();
    expect(screen.getByLabelText("Số lượng dòng 1")).toHaveAttribute(
      "min",
      "0.000001",
    );
    expect(screen.getByLabelText("Ghi chú dòng 1")).toBeRequired();
    expect(
      screen
        .getAllByRole("option")
        .filter((option) =>
          option.getAttribute("value")?.startsWith("review-pantry-purpose"),
        )
        .map((option) => option.textContent),
    ).toEqual([
      "Bổ sung theo yêu cầu của trường",
      "Bổ sung do bộ phận Kế hoạch xác định",
    ]);
  });

  it("requires authoritative preview before save and follows backend actions", async () => {
    render(
      <PantryWorkbench
        authState={authState}
        api={createReviewPantryApi("ready")}
        weekStart="2026-08-03"
      />,
    );

    await screen.findByRole("combobox", { name: "Trường dòng 1" });
    const save = screen.getByRole("button", { name: "Lưu bản nháp" });
    expect(save).toBeDisabled();

    fireEvent.click(
      screen.getByRole("button", { name: "Xem trước có thẩm quyền" }),
    );
    await waitFor(() => expect(save).toBeEnabled());
    fireEvent.click(save);

    await waitFor(() =>
      expect(
        screen.getByText("Bản nháp Pantry xem thử đã cập nhật."),
      ).toBeInTheDocument(),
    );
    expect(screen.getByRole("button", { name: "Xác thực" })).toBeEnabled();
    expect(screen.getByRole("button", { name: "Phê duyệt" })).toBeDisabled();
  });

  it("uses explicit no-additions confirmation and still requires preview", async () => {
    vi.spyOn(window, "confirm").mockReturnValue(true);
    render(
      <PantryWorkbench
        authState={authState}
        api={createReviewPantryApi("ready")}
        weekStart="2026-08-03"
      />,
    );

    await screen.findByRole("combobox", { name: "Trường dòng 1" });
    fireEvent.click(
      screen.getByRole("checkbox", {
        name: "Xác nhận tuần này không có bổ sung",
      }),
    );
    expect(
      screen.queryByRole("combobox", { name: "Trường dòng 1" }),
    ).toBeNull();
    expect(
      screen.getByText(/Đã chọn xác nhận không có bổ sung/),
    ).toBeInTheDocument();
    const save = screen.getByRole("button", { name: "Lưu bản nháp" });
    expect(save).toBeDisabled();

    fireEvent.click(
      screen.getByRole("button", { name: "Xem trước có thẩm quyền" }),
    );
    await waitFor(() => expect(save).toBeEnabled());
    expect(screen.getByText(/Mới 0 · Thay đổi 0/)).toBeInTheDocument();
  });

  it("follows backend lifecycle actions and exposes approval and audit history", async () => {
    render(
      <PantryWorkbench
        authState={authState}
        api={createReviewPantryApi("ready")}
        weekStart="2026-08-03"
      />,
    );

    await screen.findByRole("combobox", { name: "Trường dòng 1" });
    fireEvent.click(screen.getByRole("button", { name: "Xác thực" }));
    await screen.findByText("VALIDATED");
    expect(screen.getByRole("button", { name: "Phê duyệt" })).toBeEnabled();
    expect(screen.getByLabelText("Số lượng dòng 1")).toBeDisabled();

    fireEvent.click(screen.getByRole("button", { name: "Phê duyệt" }));
    await screen.findByText("APPROVED");
    expect(screen.getByText("Lịch sử phê duyệt (1)")).toBeInTheDocument();
    expect(screen.getByText("Lịch sử thay đổi (3)")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Mở lại" })).toBeDisabled();
    fireEvent.change(screen.getByRole("textbox", { name: "Lý do mở lại" }), {
      target: { value: "Điều chỉnh số lượng đã duyệt." },
    });
    expect(screen.getByRole("button", { name: "Mở lại" })).toBeEnabled();
  });

  it("shows safe stale and transport states", async () => {
    const { unmount } = render(
      <PantryWorkbench
        authState={authState}
        api={createReviewPantryApi("stale")}
        weekStart="2026-08-03"
      />,
    );
    expect(
      await screen.findByText(/tuần Pantry đã thay đổi/i),
    ).toBeInTheDocument();
    unmount();

    render(
      <PantryWorkbench
        authState={authState}
        api={createReviewPantryApi("server_error")}
        weekStart="2026-08-03"
      />,
    );
    expect(
      await screen.findByText("Không thể kết nối dịch vụ Pantry."),
    ).toBeInTheDocument();
  });

  it("keeps review fixtures local and never invokes fetch", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    const api = createReviewPantryApi("ready");
    const result = await api.getWorkbench(
      "review-only-atlas-operator",
      "review-correlation",
      "2026-08-03",
    );

    expect(result.kind).toBe("success");
    expect(fetchSpy).not.toHaveBeenCalled();
  });
});
