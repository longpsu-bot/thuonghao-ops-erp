import "@testing-library/jest-dom/vitest";
import {
  act,
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

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((complete) => {
    resolve = complete;
  });
  return { promise, resolve };
}

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
    expect(screen.getByLabelText("Nhập và lưu Pantry")).toBeVisible();
    expect(screen.getByLabelText("Thao tác vòng đời Pantry")).toBeVisible();
    expect(
      screen.getByRole("button", { name: "Xem trước có thẩm quyền" }),
    ).toHaveAccessibleName("Xem trước có thẩm quyền");
    expect(
      screen.getByRole("button", { name: "Lưu bản nháp" }),
    ).toHaveAccessibleName("Lưu bản nháp");
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

  it("keeps Validate disabled through dirty preview until save readback", async () => {
    render(
      <PantryWorkbench
        authState={authState}
        api={createReviewPantryApi("ready")}
        weekStart="2026-08-03"
      />,
    );

    await screen.findByRole("combobox", { name: "Trường dòng 1" });
    const save = screen.getByRole("button", { name: "Lưu bản nháp" });
    const validate = screen.getByRole("button", { name: "Xác thực" });
    expect(save).toBeDisabled();
    expect(validate).toBeEnabled();

    fireEvent.change(screen.getByLabelText("Số lượng dòng 1"), {
      target: { value: "3.25" },
    });
    expect(validate).toBeDisabled();
    expect(
      screen.getByText(
        "Có thay đổi chưa lưu. Hãy xem trước và lưu trước khi xác thực.",
      ),
    ).toBeInTheDocument();

    fireEvent.click(
      screen.getByRole("button", { name: "Xem trước có thẩm quyền" }),
    );
    await waitFor(() => expect(save).toBeEnabled());
    expect(validate).toBeDisabled();
    fireEvent.click(save);

    await waitFor(() =>
      expect(
        screen.getByText("Bản nháp Pantry xem thử đã cập nhật."),
      ).toBeInTheDocument(),
    );
    expect(validate).toBeEnabled();
    expect(
      screen.queryByText(
        "Có thay đổi chưa lưu. Hãy xem trước và lưu trước khi xác thực.",
      ),
    ).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Phê duyệt" })).toBeDisabled();
  });

  it("reports dirty transitions and cancels back to the authoritative batch", async () => {
    const onDirtyChange = vi.fn();
    const { unmount } = render(
      <PantryWorkbench
        authState={authState}
        api={createReviewPantryApi("ready")}
        weekStart="2026-08-03"
        onDirtyChange={onDirtyChange}
      />,
    );

    const quantity = await screen.findByLabelText("Số lượng dòng 1");
    const originalValue = quantity.getAttribute("value");
    await waitFor(() => expect(onDirtyChange).toHaveBeenCalledWith(false));

    fireEvent.change(quantity, { target: { value: "3.25" } });
    await waitFor(() => expect(onDirtyChange).toHaveBeenLastCalledWith(true));
    expect(screen.getByRole("button", { name: "Hủy thay đổi" })).toBeEnabled();

    fireEvent.click(screen.getByRole("button", { name: "Hủy thay đổi" }));
    expect(quantity).toHaveAttribute("value", originalValue);
    expect(screen.getByRole("button", { name: "Lưu bản nháp" })).toBeDisabled();
    await waitFor(() => expect(onDirtyChange).toHaveBeenLastCalledWith(false));

    unmount();
    expect(onDirtyChange).toHaveBeenLastCalledWith(false);
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
    const validate = screen.getByRole("button", { name: "Xác thực" });
    expect(validate).toBeEnabled();
    fireEvent.click(
      screen.getByRole("checkbox", {
        name: "Xác nhận tuần này không có bổ sung",
      }),
    );
    expect(
      screen.queryByRole("combobox", { name: "Trường dòng 1" }),
    ).toBeNull();
    expect(screen.getByText(/Đã chọn xác nhận không có bổ sung/)).toHaveClass(
      "pantry-zero-state",
    );
    expect(validate).toBeDisabled();
    const save = screen.getByRole("button", { name: "Lưu bản nháp" });
    expect(save).toBeDisabled();

    fireEvent.click(
      screen.getByRole("button", { name: "Xem trước có thẩm quyền" }),
    );
    await waitFor(() => expect(save).toBeEnabled());
    expect(validate).toBeDisabled();
    expect(screen.getByText(/Mới 0 · Thay đổi 0/)).toBeInTheDocument();
  });

  it("treats removing a row as unsaved working state", async () => {
    render(
      <PantryWorkbench
        authState={authState}
        api={createReviewPantryApi("ready")}
        weekStart="2026-08-03"
      />,
    );

    await screen.findByRole("combobox", { name: "Trường dòng 1" });
    const validate = screen.getByRole("button", { name: "Xác thực" });
    expect(validate).toBeEnabled();

    fireEvent.click(screen.getByRole("button", { name: "Xóa dòng 1" }));

    expect(validate).toBeDisabled();
    expect(
      screen.getByText(
        "Có thay đổi chưa lưu. Hãy xem trước và lưu trước khi xác thực.",
      ),
    ).toBeInTheDocument();
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
    const reopen = screen.getByRole("button", { name: "Mở lại" });
    expect(reopen).toBeEnabled();
    fireEvent.click(reopen);

    await screen.findByText("REOPENED");
    fireEvent.change(screen.getByLabelText("Số lượng dòng 1"), {
      target: { value: "4" },
    });
    const validate = screen.getByRole("button", { name: "Xác thực" });
    expect(validate).toBeDisabled();

    fireEvent.click(
      screen.getByRole("button", { name: "Xem trước có thẩm quyền" }),
    );
    const save = screen.getByRole("button", { name: "Lưu bản nháp" });
    await waitFor(() => expect(save).toBeEnabled());
    fireEvent.click(save);

    await waitFor(() =>
      expect(screen.getByText("Lịch sử thay đổi (5)")).toBeInTheDocument(),
    );
    expect(screen.getByText("REOPENED")).toBeInTheDocument();
    expect(validate).toBeEnabled();
  });

  it("ignores a late workbench response from the previously selected week", async () => {
    const fixtureApi = createReviewPantryApi("ready");
    const weekA = "2026-08-03";
    const weekB = "2026-08-10";
    const responseA = await fixtureApi.getWorkbench(
      "review-only-atlas-operator",
      "fixture-a",
      weekA,
    );
    const responseB = await fixtureApi.getWorkbench(
      "review-only-atlas-operator",
      "fixture-b",
      weekB,
    );
    const pendingA = deferred<typeof responseA>();
    const pendingB = deferred<typeof responseB>();
    const api = {
      ...fixtureApi,
      getWorkbench: vi.fn(
        (
          _authSubject: string,
          _correlationId: string,
          requestedWeek: string,
        ) => (requestedWeek === weekA ? pendingA.promise : pendingB.promise),
      ),
    };
    const { rerender } = render(
      <PantryWorkbench authState={authState} api={api} weekStart={weekA} />,
    );

    await waitFor(() =>
      expect(api.getWorkbench).toHaveBeenCalledWith(
        "review-only-atlas-operator",
        expect.any(String),
        weekA,
      ),
    );
    rerender(
      <PantryWorkbench authState={authState} api={api} weekStart={weekB} />,
    );
    await waitFor(() =>
      expect(api.getWorkbench).toHaveBeenCalledWith(
        "review-only-atlas-operator",
        expect.any(String),
        weekB,
      ),
    );

    await act(async () => {
      pendingB.resolve(responseB);
      await pendingB.promise;
    });
    expect(
      await screen.findByText(/10\/08\/2026.*16\/08\/2026/),
    ).toBeInTheDocument();

    await act(async () => {
      pendingA.resolve(responseA);
      await pendingA.promise;
    });
    await waitFor(() =>
      expect(
        screen.getByText(/10\/08\/2026.*16\/08\/2026/),
      ).toBeInTheDocument(),
    );
    expect(screen.queryByText(/03\/08\/2026.*09\/08\/2026/)).toBeNull();
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
