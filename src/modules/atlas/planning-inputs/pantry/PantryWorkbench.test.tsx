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
import type { AtlasAuthState } from "../../connection/authSession";
import type { AtlasRpcResult } from "../../connection/atlasRpc";
import {
  PlanningRailActionHost,
  PlanningRailActionProvider,
} from "../PlanningRailActionPortal";
import { PantryWorkbench } from "./PantryWorkbench";
import { pantryRowsForWrite, type PantryDraftRow } from "./pantryModel";
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

function renderPantry(
  api = createReviewPantryApi("ready"),
  schoolScopeIds: string[] = [],
) {
  render(
    <PlanningRailActionProvider>
      <PlanningRailActionHost />
      <PantryWorkbench
        authState={authState}
        api={api}
        weekStart="2026-08-03"
        schoolScopeIds={schoolScopeIds}
      />
    </PlanningRailActionProvider>,
  );
  return api;
}

function pantryApiWithHiddenFirstRow() {
  const api = createReviewPantryApi("ready");
  const getWorkbench = api.getWorkbench.bind(api);
  api.getWorkbench = async (...args) => {
    const result = await getWorkbench(...args);
    if (result.kind === "success" && result.response.workbench) {
      const workbench = result.response.workbench as never as {
        batch: { active_lines: Array<Record<string, unknown>> };
      };
      const visible = workbench.batch.active_lines[0]!;
      workbench.batch.active_lines.unshift({
        ...visible,
        pantry_need_line_id: "review-pantry-line-hidden",
        school_id: "review-planning-school-3",
        school_code: "TH003",
        school_name: "Trường Mầm non Hoa Hồng",
        delivery_location_id: "review-planning-location-3",
        delivery_location_code: "KITCHEN-TH003",
        delivery_location_name: "Bếp chính Hoa Hồng",
        requested_quantity: "7.000000",
        source_row_reference: "review:hidden:row",
      });
    }
    return result;
  };
  return api;
}

describe("PLANNING-UX-01C Nhu cầu bổ sung", () => {
  it("uses the three canonical Planning review schools", async () => {
    renderPantry();

    const school = await screen.findByRole("combobox", {
      name: "Trường dòng 1",
    });
    expect(school).toHaveTextContent("TH001 · Trường Tiểu học Nguyễn Du");
    expect(school).toHaveTextContent("TH002 · Trường Tiểu học Trần Quốc Toản");
    expect(school).toHaveTextContent("TH003 · Trường Mầm non Hoa Hồng");
  });

  it("filters rows visually while preserving original indexes and complete preview/save rows", async () => {
    const api = pantryApiWithHiddenFirstRow();
    const preview = vi.spyOn(api, "preview");
    const save = vi.spyOn(api, "saveCompleted");
    renderPantry(api, ["review-planning-school-1"]);

    expect(await screen.findByText("Bếp chính Nguyễn Du")).toBeVisible();
    expect(screen.queryByText("Bếp chính Hoa Hồng")).not.toBeInTheDocument();
    const visibleQuantity = screen.getByRole("spinbutton", {
      name: "Số lượng dòng 2",
    });
    fireEvent.change(visibleQuantity, { target: { value: "13.5" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));

    await waitFor(() => expect(preview).toHaveBeenCalledTimes(1));
    expect(preview.mock.calls[0]?.[4]).toEqual([
      expect.objectContaining({
        school_id: "review-planning-school-3",
        requested_quantity: "7.000000",
      }),
      expect.objectContaining({
        school_id: "review-planning-school-1",
        requested_quantity: "13.5",
      }),
    ]);
    await screen.findByLabelText("Xem thay đổi Nhu cầu bổ sung");
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await waitFor(() => expect(save).toHaveBeenCalledTimes(1));
    expect(save.mock.calls[0]?.[0].payload.rows).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ school_id: "review-planning-school-3" }),
        expect.objectContaining({ school_id: "review-planning-school-1" }),
      ]),
    );
  });

  it("defaults a new row to the first school in an explicit display scope", async () => {
    renderPantry(createReviewPantryApi("ready"), [
      "review-planning-school-2",
      "review-planning-school-3",
    ]);
    await screen.findByRole("heading", { name: "Nhu cầu bổ sung" });
    fireEvent.click(screen.getByRole("button", { name: "Thêm dòng" }));

    expect(screen.getByRole("combobox", { name: "Trường dòng 2" })).toHaveValue(
      "review-planning-school-2",
    );
  });

  it("states that zero additions is a whole-week command", async () => {
    renderPantry();
    expect(
      await screen.findByRole("checkbox", {
        name: "Xác nhận toàn tuần không có bổ sung",
      }),
    ).toBeVisible();
  });

  it("uses the business job name and plain Review-before-Save actions", async () => {
    renderPantry();

    expect(
      await screen.findByRole("heading", { name: "Nhu cầu bổ sung" }),
    ).toBeVisible();
    expect(screen.queryByText(/^Pantry$/)).not.toBeInTheDocument();
    const actionHost = screen.getByLabelText("Hành động bước hiện tại");
    expect(
      within(actionHost).getByRole("button", { name: "Xem thay đổi" }),
    ).toBeVisible();
    expect(
      within(actionHost).queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
    const localToolbar = screen.getByLabelText("Nhập Nhu cầu bổ sung");
    expect(
      within(localToolbar).queryByRole("button", { name: "Xem thay đổi" }),
    ).not.toBeInTheDocument();
    expect(
      within(localToolbar).queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
    expect(
      screen.getByRole("region", { name: "Bảng nhu cầu bổ sung" }),
    ).toHaveClass("planning-dense-table-surface");
    expect(screen.queryByText("Bản nháp cục bộ")).not.toBeInTheDocument();
  });

  it("keeps Location and Unit server-derived and performs one v2 Save", async () => {
    const api = createReviewPantryApi("ready");
    const preview = vi.spyOn(api, "preview");
    const completed = vi.spyOn(api, "saveCompleted");
    const draft = vi.spyOn(api, "save");
    const validate = vi.spyOn(api, "validate");
    const approve = vi.spyOn(api, "approve");
    renderPantry(api);

    expect(await screen.findByText("Bếp chính Nguyễn Du")).toHaveAttribute(
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
    fireEvent.change(screen.getByRole("textbox", { name: "Ghi chú dòng 1" }), {
      target: { value: "   " },
    });
    expect(screen.queryByRole("button", { name: "Lưu" })).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await screen.findByLabelText("Xem thay đổi Nhu cầu bổ sung");
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    await waitFor(() => expect(completed).toHaveBeenCalledTimes(1));
    const request = completed.mock.calls[0]?.[0];
    expect(preview.mock.calls[0]?.[4]?.[0]).toMatchObject({ note: null });
    expect(request?.contract_version).toBe("PANTRY-02.v2");
    expect(request?.payload.rows[0]).toMatchObject({ note: null });
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

  it("normalizes meaningful Pantry notes and maps blank notes to null", () => {
    const row = {
      service_date: "2026-08-03",
      school_id: "school",
      ingredient_id: "ingredient",
      pantry_need_purpose_id: "purpose",
      requested_quantity: "1",
      note: "  Yêu cầu bổ sung có chủ đích.  ",
      source_request_reference: "request",
      source_row_reference: "row",
    } satisfies PantryDraftRow;

    expect(pantryRowsForWrite([row])[0]).toMatchObject({
      note: "Yêu cầu bổ sung có chủ đích.",
    });
    expect(pantryRowsForWrite([{ ...row, note: " \t " }])[0]).toMatchObject({
      note: null,
    });
  });

  it("saves explicit no-additions completion with zero rows", async () => {
    const api = createReviewPantryApi("ready");
    const completed = vi.spyOn(api, "saveCompleted");
    vi.spyOn(window, "confirm").mockReturnValue(true);
    renderPantry(api);

    fireEvent.click(
      await screen.findByRole("checkbox", {
        name: "Xác nhận toàn tuần không có bổ sung",
      }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await screen.findByLabelText("Xem thay đổi Nhu cầu bổ sung");
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

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
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await screen.findByLabelText("Xem thay đổi Nhu cầu bổ sung");
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    await waitFor(() =>
      expect(
        screen.queryByText(/Có thay đổi chưa lưu/),
      ).not.toBeInTheDocument(),
    );
    expect(screen.getByText("ĐÃ LƯU")).toBeInTheDocument();
  });

  it("invalidates Review when a material value changes", async () => {
    renderPantry();
    const quantity = await screen.findByRole("spinbutton", {
      name: "Số lượng dòng 1",
    });
    fireEvent.change(quantity, { target: { value: "4" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await screen.findByLabelText("Xem thay đổi Nhu cầu bổ sung");
    expect(screen.getByRole("button", { name: "Lưu" })).toBeEnabled();

    fireEvent.change(quantity, { target: { value: "4.5" } });

    expect(
      screen.queryByLabelText("Xem thay đổi Nhu cầu bổ sung"),
    ).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Lưu" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeEnabled();
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
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await screen.findByLabelText("Xem thay đổi Nhu cầu bổ sung");
    const save = screen.getByRole("button", { name: "Lưu" });
    fireEvent.click(save);

    await screen.findByText(/Cần tải lại dữ liệu mới nhất/);
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
      <PlanningRailActionProvider>
        <PlanningRailActionHost />
        <PantryWorkbench
          authState={authState}
          api={api}
          weekStart={initialWeek}
        />
      </PlanningRailActionProvider>,
    );
    view.rerender(
      <PlanningRailActionProvider>
        <PlanningRailActionHost />
        <PantryWorkbench authState={authState} api={api} weekStart={nextWeek} />
      </PlanningRailActionProvider>,
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
