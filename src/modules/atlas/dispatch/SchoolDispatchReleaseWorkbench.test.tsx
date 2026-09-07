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
import type { AtlasRpcResult } from "../connection/atlasRpc";
import { createReviewAuthState } from "../review/reviewMode";
import {
  createReviewSchoolDispatchReleaseApi,
  createReviewSchoolDispatchWorkbench,
} from "./reviewSchoolDispatchReleaseApi";
import { SchoolDispatchReleaseWorkbench } from "./SchoolDispatchReleaseWorkbench";

const authState = createReviewAuthState("ready");

afterEach(cleanup);

function renderWorkbench(
  api = createReviewSchoolDispatchReleaseApi("ready"),
  exports = {
    onExportXlsx: vi.fn(),
    onExportPdf: vi.fn(),
  },
) {
  return {
    ...exports,
    ...render(
      <MantineProvider theme={atlasTheme} env="test">
        <SchoolDispatchReleaseWorkbench
          authState={authState}
          api={api}
          initialDateStart="2026-09-24"
          initialDateEnd="2026-09-24"
          {...exports}
        />
      </MantineProvider>,
    ),
  };
}

describe("School dispatch release workbench", () => {
  it("shows a read-only School PXK preview with no draft lifecycle", async () => {
    renderWorkbench();
    expect(
      await screen.findByRole("heading", { name: "Phiếu xuất kho" }),
    ).toBeInTheDocument();
    expect(screen.getByText(/bản xem trước chỉ đọc/i)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /lưu nháp/i })).toBeNull();
    expect(
      screen.getAllByText("Trường Tiểu học Nguyễn Du").length,
    ).toBeGreaterThan(0);
    expect(screen.getByText("Gạo thơm")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Phát hành phiếu xuất kho" }),
    ).toBeEnabled();
  });

  it("releases explicitly, reloads authoritative state, and exports the official document", async () => {
    const reviewApi = createReviewSchoolDispatchReleaseApi("ready");
    const releaseDocument = vi.fn(reviewApi.releaseDocument);
    const rendered = renderWorkbench({ ...reviewApi, releaseDocument });
    fireEvent.change(
      await screen.findByRole("textbox", {
        name: "Ghi chú trên phiếu (không bắt buộc)",
      }),
      { target: { value: "Giao tại cổng phụ trước 06:00" } },
    );
    fireEvent.click(
      await screen.findByRole("button", { name: "Phát hành phiếu xuất kho" }),
    );
    expect(
      await screen.findByText(/Đã phát hành Phiếu xuất kho/i),
    ).toBeVisible();
    expect(
      await screen.findByText("PXK-20260924-2600000000004000"),
    ).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Xuất Excel" }));
    fireEvent.click(screen.getByRole("button", { name: "Xuất PDF" }));
    expect(releaseDocument).toHaveBeenCalledWith(
      expect.objectContaining({
        reason_note: "Giao tại cổng phụ trước 06:00",
      }),
    );
    expect(rendered.onExportXlsx).toHaveBeenCalledOnce();
    expect(rendered.onExportPdf).toHaveBeenCalledOnce();
  });

  it("uses a distinct explicit action for a required successor PXK", async () => {
    renderWorkbench(
      createReviewSchoolDispatchReleaseApi("replacement_required"),
    );
    expect(
      await screen.findByRole("button", { name: "Phát hành phiếu thay thế" }),
    ).toBeEnabled();
    expect(screen.getByText(/phiếu cũ vẫn được lưu/i)).toBeVisible();
  });

  it("blocks PXK when a removed supplier commitment needs resolution", async () => {
    renderWorkbench(
      createReviewSchoolDispatchReleaseApi("cancellation_required"),
    );
    expect(await screen.findByText(/cam kết nhà cung ứng cũ/i)).toBeVisible();
    expect(
      screen.queryByRole("button", { name: /phát hành phiếu/i }),
    ).toBeNull();
    expect(screen.getByText(/không tự hủy đơn mua/i)).toBeVisible();
  });

  it("locks further release after an unknown outcome until a successful reload", async () => {
    const ready = createReviewSchoolDispatchWorkbench("ready");
    const getWorkbench = vi
      .fn()
      .mockResolvedValue({ kind: "success", response: ready });
    const unknown: AtlasRpcResult = {
      kind: "transport_error",
      diagnostic: {
        code: "NETWORK_FAILURE",
        safeMessage: "Không xác định được kết quả phát hành.",
      },
    };
    const api = {
      getWorkbench,
      releaseDocument: vi.fn().mockResolvedValue(unknown),
    };
    renderWorkbench(api);
    fireEvent.click(
      await screen.findByRole("button", { name: "Phát hành phiếu xuất kho" }),
    );
    expect(await screen.findByText(/kết quả chưa rõ/i)).toBeVisible();
    expect(
      screen.getByRole("button", { name: "Phát hành phiếu xuất kho" }),
    ).toBeDisabled();
    fireEvent.click(
      screen.getByRole("button", { name: "Tải lại để xác nhận" }),
    );
    await waitFor(() => expect(getWorkbench).toHaveBeenCalledTimes(2));
    expect(
      screen.getByRole("button", { name: "Phát hành phiếu xuất kho" }),
    ).toBeEnabled();
  });
});
