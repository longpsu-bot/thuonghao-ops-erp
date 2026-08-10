import "@testing-library/jest-dom/vitest";
import {
  act,
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
import { ConfirmedNeedReviewWorkbench } from "./ConfirmedNeedReviewWorkbench";
import { createConfirmedNeedWorkbookBlob } from "./confirmedNeedWorkbook";
import { initialConfirmedNeedDraft } from "./confirmedNeedModel";
import {
  createReviewConfirmedNeedApi,
  createReviewConfirmedNeedFixture,
} from "./reviewConfirmedNeedApi";

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

const batchId = "c4500000-0000-0000-0000-000000000001";

function renderReview(
  api = createReviewConfirmedNeedApi("ready"),
  onDirtyChange?: (dirty: boolean) => void,
) {
  return render(
    <ConfirmedNeedReviewWorkbench
      authState={authState}
      api={api}
      initialBatchId={batchId}
      mode="review"
      onDirtyChange={onDirtyChange}
    />,
  );
}

function nextActionButton() {
  return within(screen.getByLabelText("Hành động tiếp theo")).queryByRole(
    "button",
  );
}

async function preparePreview(api = createReviewConfirmedNeedApi("ready")) {
  renderReview(api);
  const carrot = await screen.findByLabelText("Số lượng xác nhận Cà rốt");
  fireEvent.change(carrot, { target: { value: "5.250000" } });
  fireEvent.change(screen.getByLabelText("Lý do Cà rốt"), {
    target: { value: "PLANNING_STEP_ADJUSTMENT" },
  });
  fireEvent.click(nextActionButton()!);
  await screen.findByLabelText("Kiểm tra lần cuối");
  return api;
}

async function confirmAll(api = createReviewConfirmedNeedApi("ready")) {
  await preparePreview(api);
  fireEvent.click(screen.getByRole("button", { name: "Xác nhận" }));
  await waitFor(() =>
    expect(nextActionButton()).toHaveTextContent("Hoàn tất xác nhận"),
  );
  return api;
}

async function workbookFile(quantity = "5.250000") {
  const workbench = createReviewConfirmedNeedFixture();
  const drafts = Object.fromEntries(
    workbench.lines.map((line) => [
      line.confirmed_need_line_id,
      initialConfirmedNeedDraft(line),
    ]),
  );
  const carrot = workbench.lines[1]!;
  drafts[carrot.confirmed_need_line_id] = {
    selected: true,
    exact_quantity: quantity,
    reason_code: "PLANNING_STEP_ADJUSTMENT",
    reason_note: "",
  };
  const blob = await createConfirmedNeedWorkbookBlob(workbench, drafts);
  return new File([blob], "confirmed-needs.xlsx", { type: blob.type });
}

describe("UI-QUALITY-02C-B Confirmed Need workflow", () => {
  it("loads the full batch into a dense quantity table with plain Vietnamese state and Planning step", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const getReview = vi.spyOn(api, "getReview");
    renderReview(api);
    expect(await screen.findByText("Gạo thơm")).toBeVisible();
    expect(screen.getAllByText("Chưa xác nhận").length).toBeGreaterThanOrEqual(
      2,
    );
    expect(screen.getAllByText(/Bước gợi ý:/)).toHaveLength(2);
    expect(
      screen.queryByLabelText("Mã lô Confirmed Need"),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Tải lô" }),
    ).not.toBeInTheDocument();
    expect(screen.getByLabelText("Trường đang xem")).toHaveValue("");
    expect(screen.getByText("Excel (không bắt buộc)")).toBeVisible();
    expect(
      screen.getAllByText("Đang xác nhận số lượng").length,
    ).toBeGreaterThan(0);
    expect(getReview).toHaveBeenCalledWith(
      expect.anything(),
      expect.anything(),
      batchId,
      expect.anything(),
      0,
      250,
    );
    expect(nextActionButton()).toHaveTextContent("Xác nhận số lượng");
    expect(
      screen.queryByRole("button", { name: "Hoàn tất xác nhận" }),
    ).not.toBeInTheDocument();
  });

  it("shows a plain access-denied message only when the backend rejects access", async () => {
    renderReview(createReviewConfirmedNeedApi("permission_denied"));
    expect(
      await screen.findByText(
        "Bạn không có quyền truy cập nhu cầu xác nhận này.",
      ),
    ).toBeVisible();
    expect(
      screen.queryByText(/capability|hợp đồng|UUID/i),
    ).not.toBeInTheDocument();
  });

  it("preserves exact direct input, never rounds to the Planning step and invalidates preview after edits", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const preview = vi.spyOn(api, "preview");
    renderReview(api);
    const carrot = await screen.findByLabelText("Số lượng xác nhận Cà rốt");
    fireEvent.change(carrot, { target: { value: "10.234" } });
    fireEvent.change(screen.getByLabelText("Lý do Cà rốt"), {
      target: { value: "PLANNING_STEP_ADJUSTMENT" },
    });
    fireEvent.click(nextActionButton()!);
    await screen.findByLabelText("Kiểm tra lần cuối");
    const requestLine = preview.mock.calls[0]?.[0].payload.lines.find(
      (line) =>
        line.confirmed_need_line_id === "c4520000-0000-0000-0000-000000000002",
    );
    expect(requestLine?.proposed_confirmed_quantity).toBe("10.234");
    expect(carrot).toHaveValue("10.234");
    fireEvent.change(carrot, { target: { value: "10.235" } });
    expect(
      screen.queryByLabelText("Kiểm tra lần cuối"),
    ).not.toBeInTheDocument();
  });

  it("makes direct edit and XLSX apply converge on the same RMVP-05 request shape", async () => {
    const directApi = createReviewConfirmedNeedApi("ready");
    const directPreview = vi.spyOn(directApi, "preview");
    await preparePreview(directApi);
    const directLine = directPreview.mock.calls[0]![0].payload.lines.find(
      (line) => line.confirmed_need_line_id.endsWith("000002"),
    );
    cleanup();

    const excelApi = createReviewConfirmedNeedApi("ready");
    const excelPreview = vi.spyOn(excelApi, "preview");
    const confirm = vi.spyOn(excelApi, "confirm");
    renderReview(excelApi);
    await screen.findByText("Gạo thơm");
    fireEvent.change(screen.getByLabelText("Nhập Excel"), {
      target: { files: [await workbookFile()] },
    });
    expect(await screen.findByLabelText("Đã đọc file Excel")).toBeVisible();
    expect(screen.getByText("Dòng thay đổi").parentElement).toHaveTextContent(
      "1",
    );
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng vào bảng" }));
    expect(screen.getByLabelText("Số lượng xác nhận Cà rốt")).toHaveValue(
      "5.250000",
    );
    expect(
      screen.getByText(
        /Thay đổi từ Excel mới chỉ nằm trong bảng trên màn hình/,
      ),
    ).toBeVisible();
    expect(confirm).not.toHaveBeenCalled();
    fireEvent.click(nextActionButton()!);
    await waitFor(() => expect(excelPreview).toHaveBeenCalledOnce());
    const excelLine = excelPreview.mock.calls[0]![0].payload.lines.find(
      (line) => line.confirmed_need_line_id.endsWith("000002"),
    );
    expect(excelLine).toEqual(directLine);
  });

  it("keeps import review explicit, local-only, whole-workbook and invalidates an old preview", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const confirm = vi.spyOn(api, "confirm");
    await preparePreview(api);
    fireEvent.change(screen.getByLabelText("Nhập Excel"), {
      target: { files: [await workbookFile()] },
    });
    expect(
      screen.queryByLabelText("Kiểm tra lần cuối"),
    ).not.toBeInTheDocument();
    const review = await screen.findByLabelText("Đã đọc file Excel");
    expect(
      within(review).getByText("Tổng số dòng").parentElement,
    ).toHaveTextContent("2");
    expect(
      within(review).getByText("Dòng lỗi").parentElement,
    ).toHaveTextContent("0");
    expect(confirm).not.toHaveBeenCalled();
    fireEvent.click(
      within(review).getByRole("button", { name: "Áp dụng vào bảng" }),
    );
    expect(confirm).not.toHaveBeenCalled();
  });

  it("rejects a stale workbook without changing the existing local draft", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    renderReview(api);
    const carrot = await screen.findByLabelText("Số lượng xác nhận Cà rốt");
    fireEvent.change(carrot, { target: { value: "7.125" } });
    const stale = await workbookFile();
    const original = api.getReview.bind(api);
    api.getReview = vi.fn(async (...args: Parameters<typeof original>) => {
      const result = await original(...args);
      if (result.kind === "success") {
        const workbench = result.response.workbench as unknown as {
          batch_version: number;
        };
        workbench.batch_version = 2;
      }
      return result;
    });
    fireEvent.change(screen.getByLabelText("Nhập Excel"), {
      target: { files: [stale] },
    });
    expect(
      await screen.findByText(/Bản nháp hiện tại được giữ lại/),
    ).toBeVisible();
    expect(carrot).toHaveValue("7.125");
    expect(
      screen.queryByRole("button", { name: "Áp dụng vào bảng" }),
    ).not.toBeInTheDocument();
  });

  it("uses one next action through confirmation, completion, approval, release and final state", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const confirm = vi.spyOn(api, "confirm");
    const validate = vi.spyOn(api, "validate");
    const approve = vi.spyOn(api, "approve");
    const release = vi.spyOn(api, "release");
    await confirmAll(api);
    expect(confirm).toHaveBeenCalledOnce();
    expect(validate).not.toHaveBeenCalled();

    fireEvent.click(nextActionButton()!);
    await waitFor(() =>
      expect(nextActionButton()).toHaveTextContent("Phê duyệt"),
    );
    expect(validate).toHaveBeenCalledOnce();
    expect(approve).not.toHaveBeenCalled();
    expect(screen.getAllByText("Đã hoàn tất xác nhận").length).toBeGreaterThan(
      0,
    );

    fireEvent.click(nextActionButton()!);
    expect(
      screen.getAllByText(/Phê duyệt toàn bộ số lượng đã hoàn tất xác nhận/)
        .length,
    ).toBeGreaterThan(0);
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận phê duyệt" }));
    await waitFor(() =>
      expect(nextActionButton()).toHaveTextContent("Phát hành"),
    );
    expect(approve).toHaveBeenCalledOnce();
    expect(release).not.toHaveBeenCalled();

    fireEvent.click(nextActionButton()!);
    expect(
      screen.getByText(/không chọn nhà cung cấp.*không tạo.*đơn mua/i),
    ).toBeVisible();
    expect(
      screen.getByText(/SL xác nhận không nhất thiết là SL đặt mua/),
    ).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận phát hành" }));
    await waitFor(() => expect(nextActionButton()).toBeNull());
    expect(release).toHaveBeenCalledOnce();
    expect(
      screen.getAllByText("Đã phát hành sang bước lên đơn").length,
    ).toBeGreaterThan(0);
    expect(screen.getByText(/mọi làm tròn mua hàng sau này/)).toBeVisible();
  });

  it("reveals correction fields only after a quantity is adjusted", async () => {
    renderReview();
    const carrot = await screen.findByLabelText("Số lượng xác nhận Cà rốt");
    expect(screen.queryByLabelText("Lý do Cà rốt")).not.toBeInTheDocument();
    expect(screen.getAllByText("Chấp nhận đề xuất")).toHaveLength(2);
    fireEvent.change(carrot, { target: { value: "5.25" } });
    expect(screen.getByLabelText("Lý do Cà rốt")).toHaveValue("");
    expect(screen.getByLabelText("Ghi chú Cà rốt")).toBeVisible();
    expect(screen.getByText(/cần chọn một lý do điều chỉnh/)).toBeVisible();
  });

  it("never auto-chains more than 250 decisions", async () => {
    const api = createReviewConfirmedNeedApi("ready", { lineCount: 251 });
    const preview = vi.spyOn(api, "preview");
    const confirm = vi.spyOn(api, "confirm");
    renderReview(api);
    expect(await screen.findByText(/Có 251 quyết định/)).toBeVisible();
    fireEvent.click(nextActionButton()!);
    await waitFor(() => expect(preview).toHaveBeenCalledOnce());
    expect(preview.mock.calls[0]![0].payload.lines).toHaveLength(250);
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận" }));
    await waitFor(() => expect(confirm).toHaveBeenCalledOnce());
    expect(preview).toHaveBeenCalledOnce();
    expect(nextActionButton()).toHaveTextContent("Xác nhận số lượng");
  }, 90_000);

  it("keeps exact retry manual and uses refresh-only recovery for unknown lifecycle outcomes", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const originalConfirm = api.confirm.bind(api);
    api.confirm = vi
      .fn()
      .mockResolvedValueOnce({
        kind: "transport_error",
        diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Chưa chắc chắn" },
      } satisfies AtlasRpcResult)
      .mockImplementation(originalConfirm);
    await preparePreview(api);
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận" }));
    const retry = await screen.findByRole("button", {
      name: "Thử lưu lại",
    });
    expect(api.confirm).toHaveBeenCalledOnce();
    fireEvent.click(retry);
    await waitFor(() => expect(api.confirm).toHaveBeenCalledTimes(2));
    expect(vi.mocked(api.confirm).mock.calls[1]![0]).toBe(
      vi.mocked(api.confirm).mock.calls[0]![0],
    );
  });

  it("protects direct/import/preview work with dirty callback and beforeunload", async () => {
    const dirty = vi.fn();
    renderReview(createReviewConfirmedNeedApi("ready"), dirty);
    const carrot = await screen.findByLabelText("Số lượng xác nhận Cà rốt");
    fireEvent.change(carrot, { target: { value: "5.25" } });
    await waitFor(() => expect(dirty).toHaveBeenLastCalledWith(true));
    const event = new Event("beforeunload", { cancelable: true });
    window.dispatchEvent(event);
    expect(event.defaultPrevented).toBe(true);
  });

  it("discards a late preview after a newer exact draft intent", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const originalPreview = api.preview.bind(api);
    let resolve!: (result: AtlasRpcResult) => void;
    api.preview = vi.fn(
      () =>
        new Promise<AtlasRpcResult>((next) => {
          resolve = next;
        }),
    );
    renderReview(api);
    const carrot = await screen.findByLabelText("Số lượng xác nhận Cà rốt");
    fireEvent.change(carrot, { target: { value: "5.25" } });
    fireEvent.change(screen.getByLabelText("Lý do Cà rốt"), {
      target: { value: "PLANNING_STEP_ADJUSTMENT" },
    });
    fireEvent.click(nextActionButton()!);
    await waitFor(() => expect(api.preview).toHaveBeenCalledOnce());
    const request = vi.mocked(api.preview).mock.calls[0]![0];
    fireEvent.change(carrot, { target: { value: "5.5" } });
    await act(async () => resolve(await originalPreview(request)));
    expect(carrot).toHaveValue("5.5");
    expect(
      screen.queryByLabelText("Kiểm tra lần cuối"),
    ).not.toBeInTheDocument();
  });
});
