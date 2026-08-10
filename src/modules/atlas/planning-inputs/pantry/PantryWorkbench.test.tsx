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
import type { AtlasRpcResult } from "../../connection/atlasRpc";
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
  session: { user: { id: "review-only-atlas-operator" } },
} as unknown as AtlasAuthState;

function renderPantry(api = createReviewPantryApi("ready")) {
  render(
    <PantryWorkbench authState={authState} api={api} weekStart="2026-08-03" />,
  );
  return api;
}

describe("UI-QUALITY-02AB-UX Pantry cutover", () => {
  it("keeps Location and Unit server-derived and performs one v2 Save", async () => {
    const api = createReviewPantryApi("ready");
    const completed = vi.spyOn(api, "saveCompleted");
    const draft = vi.spyOn(api, "save");
    const validate = vi.spyOn(api, "validate");
    const approve = vi.spyOn(api, "approve");
    renderPantry(api);

    expect(await screen.findByText("Bếp chính Minh Khai")).toHaveAttribute(
      "data-derived",
      "delivery-location",
    );
    expect(screen.getByText("Kilôgam")).toHaveAttribute(
      "data-derived",
      "purchase-unit",
    );
    fireEvent.change(
      screen.getByRole("spinbutton", { name: "Số lượng dòng 1" }),
      {
        target: { value: "3.5" },
      },
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Xem trước có thẩm quyền" }),
    );
    await screen.findByLabelText("Xem trước Pantry");
    fireEvent.click(
      screen.getByRole("button", { name: "Lưu nhu cầu bổ sung" }),
    );

    await waitFor(() => expect(completed).toHaveBeenCalledTimes(1));
    const request = completed.mock.calls[0]?.[0];
    expect(request?.contract_version).toBe("PANTRY-02.v2");
    expect(request?.payload.rows[0]).not.toHaveProperty("delivery_location_id");
    expect(request?.payload.rows[0]).not.toHaveProperty("unit_id");
    expect(draft).not.toHaveBeenCalled();
    expect(validate).not.toHaveBeenCalled();
    expect(approve).not.toHaveBeenCalled();
    expect(screen.getByText(/Đã lưu nhu cầu bổ sung\./)).toHaveTextContent(
      "Dữ liệu này sẽ được dùng khi tạo nhu cầu.",
    );
    expect(screen.queryByText(/trong một giao dịch/i)).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Xác thực" }),
    ).not.toBeInTheDocument();
  });

  it("saves explicit no-additions completion with zero rows", async () => {
    const api = createReviewPantryApi("ready");
    const completed = vi.spyOn(api, "saveCompleted");
    vi.spyOn(window, "confirm").mockReturnValue(true);
    renderPantry(api);

    fireEvent.click(
      await screen.findByRole("checkbox", {
        name: "Xác nhận tuần này không có bổ sung",
      }),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Xem trước có thẩm quyền" }),
    );
    await screen.findByLabelText("Xem trước Pantry");
    fireEvent.click(
      screen.getByRole("button", { name: "Lưu nhu cầu bổ sung" }),
    );

    await waitFor(() => expect(completed).toHaveBeenCalledTimes(1));
    expect(completed.mock.calls[0]?.[0].payload).toMatchObject({
      no_additions_confirmed: true,
      rows: [],
    });
  });

  it("adopts authoritative completion readback and clears local dirty state", async () => {
    renderPantry();
    const quantity = await screen.findByRole("spinbutton", {
      name: "Số lượng dòng 1",
    });
    fireEvent.change(quantity, { target: { value: "4" } });
    expect(screen.getByText(/Có thay đổi chưa lưu/)).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Xem trước có thẩm quyền" }),
    );
    await screen.findByLabelText("Xem trước Pantry");
    fireEvent.click(
      screen.getByRole("button", { name: "Lưu nhu cầu bổ sung" }),
    );

    await waitFor(() =>
      expect(
        screen.queryByText(/Có thay đổi chưa lưu/),
      ).not.toBeInTheDocument(),
    );
    expect(screen.getByText("ĐÃ LƯU")).toBeInTheDocument();
  });

  it("requires authoritative refresh after an unknown Save outcome", async () => {
    const api = createReviewPantryApi("ready");
    vi.spyOn(api, "saveCompleted").mockResolvedValue({
      kind: "transport_error",
      diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Mất kết nối" },
    });
    renderPantry(api);

    fireEvent.change(
      await screen.findByRole("spinbutton", { name: "Số lượng dòng 1" }),
      { target: { value: "5" } },
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Xem trước có thẩm quyền" }),
    );
    await screen.findByLabelText("Xem trước Pantry");
    const save = screen.getByRole("button", { name: "Lưu nhu cầu bổ sung" });
    fireEvent.click(save);

    await screen.findByText(/Cần tải lại dữ liệu có thẩm quyền/);
    expect(save).toBeDisabled();
  });

  it("ignores a late Pantry read from the prior week", async () => {
    const api = createReviewPantryApi("ready");
    const original = api.getWorkbench;
    const initialWeek = "2026-08-03";
    const nextWeek = addIsoCalendarDays(initialWeek, 7);
    let resolvePrior!: (result: AtlasRpcResult) => void;
    const priorRead = new Promise<AtlasRpcResult>((resolve) => {
      resolvePrior = resolve;
    });
    vi.spyOn(api, "getWorkbench").mockImplementation(async (...args) => {
      if (args[2] === initialWeek) return priorRead;
      return original(...args);
    });

    const view = render(
      <PantryWorkbench
        authState={authState}
        api={api}
        weekStart={initialWeek}
      />,
    );
    view.rerender(
      <PantryWorkbench authState={authState} api={api} weekStart={nextWeek} />,
    );

    expect(await screen.findByLabelText("Ngày phục vụ dòng 1")).toHaveValue(
      nextWeek,
    );
    resolvePrior(
      await original(
        "review-only-atlas-operator",
        crypto.randomUUID(),
        initialWeek,
      ),
    );
    await waitFor(() =>
      expect(screen.getByLabelText("Ngày phục vụ dòng 1")).toHaveValue(
        nextWeek,
      ),
    );
  });
});

function addIsoCalendarDays(isoDate: string, days: number) {
  const [year, month, day] = isoDate.split("-").map(Number);
  const shifted = new Date(Date.UTC(year, month - 1, day + days));
  return shifted.toISOString().slice(0, 10);
}
