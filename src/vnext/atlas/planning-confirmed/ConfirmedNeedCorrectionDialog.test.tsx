import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { ConfirmedNeedWorkbench } from "./ConfirmedNeedWorkbench";
import {
  createConfirmedNeedReviewFixture,
  reviewDate,
  reviewFailure,
} from "./confirmedNeedReviewFixtures";
const title = "Điều chỉnh nhu cầu";
beforeEach(() =>
  vi.stubGlobal(
    "ResizeObserver",
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  ),
);
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});
function show(
  prepare?: (f: ReturnType<typeof createConfirmedNeedReviewFixture>) => void,
  scenario: Parameters<typeof createConfirmedNeedReviewFixture>[0] = "released",
) {
  const f = createConfirmedNeedReviewFixture(scenario);
  prepare?.(f);
  const write = vi.spyOn(f.confirmedNeedApi, "correct"),
    read = vi.spyOn(f.confirmedNeedApi, "getReview"),
    ordinary = vi.spyOn(f.confirmedNeedApi, "save"),
    status = vi.fn();
  render(
    <AtlasVNextProvider>
      <ConfirmedNeedWorkbench
        {...f}
        authSubject="operator"
        initialServiceDate={reviewDate}
        onWorkspaceStatus={status}
      />
    </AtlasVNextProvider>,
  );
  return { f, write, read, ordinary, status };
}
async function open() {
  const trigger = await screen.findByRole("button", {
    name: "Điều chỉnh nhu cầu Gạo thơm — Trường Nguyễn Du",
  });
  fireEvent.click(trigger);
  const dialog = await screen.findByRole("dialog", { name: title });
  return { trigger, dialog };
}
async function edit(dialog: HTMLElement, value = "12.500001") {
  fireEvent.change(
    within(dialog).getByRole("textbox", { name: "Số lượng mới" }),
    { target: { value } },
  );
  fireEvent.change(
    within(dialog).getByRole("combobox", { name: "Lý do điều chỉnh" }),
    { target: { value: "OTHER" } },
  );
  fireEvent.change(
    within(dialog).getByRole("textbox", { name: "Ghi chú điều chỉnh" }),
    { target: { value: "Bếp yêu cầu" } },
  );
  fireEvent.click(
    within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
  );
  await within(dialog).findByRole("region", { name: "Ảnh hưởng điều chỉnh" });
}
async function exit(dialog: HTMLElement) {
  await waitFor(() => expect(dialog).toHaveAttribute("data-state", "closed"));
  fireEvent(dialog, new Event("animationcancel", { bubbles: true }));
  await waitFor(() => expect(dialog).not.toBeInTheDocument());
}
describe("released Need correction operator dialog", () => {
  it("keeps released inline read-only and explicitly saves then returns focus after real trigger unmount", async () => {
    const h = show();
    expect(
      await screen.findByRole("textbox", {
        name: "Số lượng xác nhận Gạo thơm",
      }),
    ).toBeDisabled();
    const { dialog, trigger } = await open();
    expect(dialog).toHaveTextContent("Gạo thơm · Trường Nguyễn Du");
    expect(dialog).toHaveTextContent("Đơn vị tính: Kilôgam");
    expect(dialog).toHaveTextContent("07/09/2026");
    expect(
      within(dialog).getByRole("button", { name: "Lưu điều chỉnh" }),
    ).toBeDisabled();
    await edit(dialog);
    expect(dialog).toHaveTextContent("+2,250001");
    expect(dialog).toHaveTextContent(
      "Chỉ hiển thị đơn mua trong phạm vi được phép xem",
    );
    expect(dialog).not.toHaveTextContent("Không có cam kết");
    const reads = h.read.mock.calls.length;
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Lưu điều chỉnh" }),
    );
    await screen.findByText(/Đã lưu điều chỉnh/);
    await exit(dialog);
    expect(h.write).toHaveBeenCalledTimes(1);
    expect(h.ordinary).not.toHaveBeenCalled();
    expect(h.read).toHaveBeenCalledTimes(reads + 1);
    expect(trigger).not.toBeInTheDocument();
    expect(
      screen.getByRole("region", { name: "Xác nhận nhu cầu" }),
    ).toHaveFocus();
  });
  it("shows the complete shared family and distinguishes selected zero from whole-family zero", async () => {
    show((f) => {
      const l = structuredClone(f.batch.lines[0]!);
      l.confirmed_need_line_id = "line-shared";
      l.school = {
        id: "school-shared",
        name: "Trường Bình An",
      };
      l.current_revision_id = "revision-shared";
      l.current_decision_id = "decision-shared";
      l.confirmed_quantity_after = "20.000000";
      f.batch.lines.push(l);
      f.batch.line_counts.total++;
      f.batch.pagination.total_lines++;
    });
    const { dialog } = await open();
    await edit(dialog, "0");
    const impact = within(dialog).getByRole("region", {
      name: "Ảnh hưởng điều chỉnh",
    });
    expect(impact).toHaveTextContent("Trường Bình An");
    expect(impact).toHaveTextContent("20");
    expect(impact).toHaveTextContent("Các trường khác vẫn có nhu cầu");
    expect(impact).not.toHaveTextContent("Toàn bộ nhóm nhu cầu bằng 0");
  });
  it("uses controlled Vietnamese authority feedback and never echoes English or technical codes", async () => {
    show((f) =>
      vi.spyOn(f.confirmedNeedApi, "previewCorrection").mockResolvedValueOnce({
        kind: "backend_error",
        error: {
          success: false,
          error_code: "CAPABILITY_DENIED",
          safe_message: "English backend detail",
          write_certainty: "NO_WRITE",
        },
      }),
    );
    const { dialog } = await open();
    fireEvent.change(
      within(dialog).getByRole("textbox", { name: "Số lượng mới" }),
      { target: { value: "12" } },
    );
    fireEvent.change(
      within(dialog).getByRole("textbox", { name: "Ghi chú điều chỉnh" }),
      { target: { value: "Bếp yêu cầu" } },
    );
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    await within(dialog).findByRole("alert");
    expect(dialog).toHaveTextContent("Không có quyền");
    expect(dialog).not.toHaveTextContent("English backend detail");
    expect(dialog).not.toHaveTextContent("CAPABILITY_DENIED");
  });
  it("keeps dirty Cancel input and Discard closes without a command", async () => {
    const h = show();
    const { dialog, trigger } = await open();
    fireEvent.change(
      within(dialog).getByRole("textbox", { name: "Số lượng mới" }),
      { target: { value: "12" } },
    );
    fireEvent.click(within(dialog).getByRole("button", { name: "Đóng" }));
    const dirty = await screen.findByRole("dialog", {
      name: /Có thay đổi chưa lưu/,
    });
    fireEvent.click(
      within(dirty).getByRole("button", { name: "Tiếp tục chỉnh sửa" }),
    );
    await exit(dirty);
    expect(
      within(dialog).getByRole("textbox", { name: "Số lượng mới" }),
    ).toHaveValue("12");
    fireEvent.click(within(dialog).getByRole("button", { name: "Đóng" }));
    const again = await screen.findByRole("dialog", {
      name: /Có thay đổi chưa lưu/,
    });
    fireEvent.click(within(again).getByRole("button", { name: "Bỏ thay đổi" }));
    await exit(again);
    await exit(dialog);
    expect(h.write).not.toHaveBeenCalled();
    expect(trigger).toHaveFocus();
  });
  it("retains all family Schools when the workbench is filtered to one School", async () => {
    show(undefined, "correction_shared");
    await screen.findByRole("button", {
      name: "Điều chỉnh nhu cầu Gạo thơm — Trường Nguyễn Du",
    });
    fireEvent.click(screen.getByRole("button", { name: "Bộ lọc" }));
    fireEvent.click(screen.getByRole("button", { name: "Tất cả trường" }));
    fireEvent.click(
      await screen.findByRole("button", { name: "Bỏ chọn tất cả" }),
    );
    const picker = screen.getByLabelText("Trường / điểm giao");
    const school = screen.getByRole("checkbox", { name: "Trường Nguyễn Du" });
    fireEvent.click(school);
    await waitFor(() => expect(school).toBeChecked());
    const apply = screen.getByRole("button", { name: "Áp dụng" });
    await waitFor(() => expect(apply).toBeEnabled());
    fireEvent.click(apply);
    await exit(picker);
    const { dialog } = await open();
    await edit(dialog);
    expect(
      within(dialog).getByRole("region", { name: "Ảnh hưởng điều chỉnh" }),
    ).toHaveTextContent("Trường Trần Quốc Toản");
    expect(dialog).toHaveTextContent("2 trường");
  });
  it("explains true whole-family zero without creating or releasing downstream documents", async () => {
    const h = show(undefined, "correction_zero");
    const { dialog } = await open();
    await edit(dialog, "0");
    expect(dialog).toHaveTextContent("Toàn bộ nhóm nhu cầu bằng 0");
    expect(dialog).toHaveTextContent("quy trình hủy hiện có");
    expect(h.write).not.toHaveBeenCalled();
    expect(dialog).not.toHaveTextContent("Các trường khác vẫn có nhu cầu");
  });
  it("safely displays optional authorized details and controls missing/technical human labels", async () => {
    const id = "11111111-1111-4111-8111-111111111111";
    show((f) => {
      const original = f.confirmedNeedApi.previewCorrection;
      vi.spyOn(f.confirmedNeedApi, "previewCorrection").mockImplementation(
        async (request) => {
          const r = await original(request);
          if (r.kind === "success") {
            (r.response.display as Record<string, unknown>).unit_name =
              "v1-unit-synthetic";
            r.response.procurement_details = [
              null,
              {
                supplier_splits: [
                  {
                    supplier_name: "ABC_Foods",
                    allocated_quantity: "10.250000",
                    supplier_note: "Giữ đúng hướng dẫn",
                  },
                  null,
                  {
                    supplier_name: id,
                    allocated_quantity: null,
                    supplier_note: { private: "not-text" },
                  },
                ],
              },
            ];
            r.response.purchase_orders = [
              null,
              {
                document_number: "PO-20261102-01",
                supplier_name: "Supplier label unavailable",
                purchase_order_status: "RAW_STATUS",
              },
            ];
          }
          return r;
        },
      );
    });
    const { dialog } = await open();
    await edit(dialog);
    expect(dialog).toHaveTextContent("ABC_Foods");
    expect(dialog).toHaveTextContent("Giữ đúng hướng dẫn");
    expect(dialog).toHaveTextContent("PO-20261102-01");
    expect(dialog).toHaveTextContent("Chưa có tên đơn vị tính");
    expect(dialog).toHaveTextContent("Chưa xác định");
    for (const value of [
      id,
      "v1-unit-synthetic",
      "RAW_STATUS",
      "Supplier label unavailable",
      "not-text",
    ])
      expect(dialog).not.toHaveTextContent(value);
  });
  it("shows preview-only authority denial and does not make PO visibility a new write prerequisite", async () => {
    const h = show(undefined, "correction_authority"),
      { dialog } = await open();
    await edit(dialog);
    expect(
      within(dialog).getByRole("button", { name: "Lưu điều chỉnh" }),
    ).toBeDisabled();
    expect(dialog).toHaveTextContent("Không có quyền lưu điều chỉnh");
    expect(h.write).not.toHaveBeenCalled();
  });
  it("locks UNKNOWN through close/context and retries the identical committed request", async () => {
    const h = show(undefined, "correction_unknown"),
      { dialog } = await open();
    await edit(dialog);
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Lưu điều chỉnh" }),
    );
    const retry = await within(dialog).findByRole("button", {
      name: "Thử lại đúng yêu cầu",
    });
    expect(within(dialog).getByRole("button", { name: "Đóng" })).toBeDisabled();
    expect(
      within(dialog).getByRole("textbox", { name: "Số lượng mới" }),
    ).toBeDisabled();
    await waitFor(() =>
      expect(h.status).toHaveBeenLastCalledWith(
        expect.objectContaining({ blocked: true }),
      ),
    );
    const request = structuredClone(h.write.mock.calls[0]![0]);
    fireEvent.click(retry);
    await screen.findByText(/Đã lưu điều chỉnh/);
    await exit(dialog);
    expect(h.write.mock.calls[1]![0]).toEqual(request);
  });
  it("holds the dialog on known-write readback failure and recovers with one read, no second write", async () => {
    const h = show(undefined, "correction_readback"),
      { dialog } = await open();
    await edit(dialog);
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Lưu điều chỉnh" }),
    );
    const recovery = await within(dialog).findByRole("button", {
      name: "Tải lại để xác nhận",
    });
    expect(within(dialog).getByRole("button", { name: "Đóng" })).toBeDisabled();
    expect(screen.queryByText(/Đã lưu điều chỉnh/)).not.toBeInTheDocument();
    const count = h.read.mock.calls.length;
    fireEvent.click(recovery);
    await screen.findByText(/Đã lưu điều chỉnh/);
    await exit(dialog);
    expect(h.write).toHaveBeenCalledTimes(1);
    expect(h.read).toHaveBeenCalledTimes(count + 1);
  });
  it("disables released correction with controlled guidance when loaded source is blocked", async () => {
    show((f) => {
      f.batch.lines[0]!.source_stale = true;
    });
    const trigger = await screen.findByRole("button", {
      name: "Điều chỉnh nhu cầu Gạo thơm — Trường Nguyễn Du",
    });
    expect(trigger).toBeDisabled();
    fireEvent.click(trigger);
    expect(
      screen.queryByRole("dialog", { name: title }),
    ).not.toBeInTheDocument();
    expect(
      screen.getByText(/Chưa thể điều chỉnh vì dữ liệu nhu cầu nguồn/),
    ).toBeVisible();
  });
  it("does not echo an unexpected English exception from correction preview", async () => {
    show((f) => {
      vi.spyOn(f.confirmedNeedApi, "previewCorrection").mockRejectedValueOnce(
        new Error("English thrown backend secret"),
      );
    });
    const { dialog } = await open();
    fireEvent.change(
      within(dialog).getByRole("textbox", { name: "Số lượng mới" }),
      { target: { value: "12" } },
    );
    fireEvent.change(
      within(dialog).getByRole("textbox", { name: "Ghi chú điều chỉnh" }),
      { target: { value: "Bếp yêu cầu" } },
    );
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    await within(dialog).findByRole("alert");
    expect(dialog).not.toHaveTextContent("English thrown backend secret");
    expect(dialog).toHaveTextContent("Chưa xem được ảnh hưởng");
  });
  it("uses the loaded human Unit initially but warns on an explicitly missing preview label", async () => {
    show((f) => {
      const original = f.confirmedNeedApi.previewCorrection;
      vi.spyOn(f.confirmedNeedApi, "previewCorrection").mockImplementation(
        async (request) => {
          const result = await original(request);
          if (result.kind === "success")
            (result.response.display as Record<string, unknown>).unit_name =
              null;
          return result;
        },
      );
    });
    const { dialog } = await open();
    expect(dialog).toHaveTextContent("Đơn vị tính: Kilôgam");
    await edit(dialog);
    expect(dialog).toHaveTextContent("Chưa có tên đơn vị tính");
    expect(dialog).not.toHaveTextContent("Kilôgam");
  });
});
