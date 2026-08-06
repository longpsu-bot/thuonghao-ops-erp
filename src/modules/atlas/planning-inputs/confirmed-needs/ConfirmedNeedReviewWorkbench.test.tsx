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
import type { AtlasRpcResult } from "../../connection/atlasRpc";
import { ConfirmedNeedReviewWorkbench } from "./ConfirmedNeedReviewWorkbench";
import { createReviewConfirmedNeedApi } from "./reviewConfirmedNeedApi";

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
const lifecycleMessages = [
  "Đã kiểm tra; chờ phê duyệt",
  "Đã phê duyệt; chờ phát hành",
  "Đã phát hành sang bước lên đơn",
];

function expectOnlyLifecycleMessage(expected: string) {
  const displayed = lifecycleMessages.flatMap((message) =>
    screen.queryAllByText(message).map(() => message),
  );
  expect(displayed).toEqual([expected]);
}

function deferred<T>() {
  let resolve!: (value: T | PromiseLike<T>) => void;
  const promise = new Promise<T>((next) => {
    resolve = next;
  });
  return { promise, resolve };
}

function renderReview(api = createReviewConfirmedNeedApi("ready")) {
  return render(
    <ConfirmedNeedReviewWorkbench
      authState={authState}
      api={api}
      initialBatchId={batchId}
      mode="review"
    />,
  );
}

async function prepareMixedPreview(
  api = createReviewConfirmedNeedApi("ready"),
) {
  renderReview(api);
  const carrot = await screen.findByLabelText("Số lượng xác nhận Cà rốt");
  fireEvent.change(carrot, { target: { value: "5.250000" } });
  fireEvent.change(screen.getByLabelText("Lý do Cà rốt"), {
    target: { value: "PLANNING_STEP_ADJUSTMENT" },
  });
  fireEvent.click(screen.getByRole("button", { name: "Xem trước xác nhận" }));
  await screen.findByLabelText("Bản xem trước xác nhận");
  return api;
}

async function confirmFixture(api = createReviewConfirmedNeedApi("ready")) {
  await prepareMixedPreview(api);
  fireEvent.click(
    screen.getByLabelText("Tôi xác nhận đúng bản xem trước có thẩm quyền này"),
  );
  fireEvent.click(screen.getByRole("button", { name: "Xác nhận số lượng" }));
  await screen.findByText("ADJUSTED_QUANTITY_CONFIRMED");
  return api;
}

describe("RMVP-05 Confirmed Need review workbench", () => {
  it("loads an explicit batch and distinguishes theoretical, proposed and authoritative quantities", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const getReview = vi.spyOn(api, "getReview");
    renderReview(api);
    expect(await screen.findByText("Gạo thơm")).toBeVisible();
    expect(
      screen
        .getAllByRole("cell")
        .filter((cell) => cell.textContent?.includes("10,25")),
    ).toHaveLength(2);
    expect(screen.getAllByText(/Chưa có quyết định/)).toHaveLength(2);
    expect(getReview).toHaveBeenCalledWith(
      expect.anything(),
      expect.anything(),
      batchId,
      expect.anything(),
    );
  });

  it("preserves exact decimal strings, applies local rules and invalidates preview after edits", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const preview = vi.spyOn(api, "preview");
    await prepareMixedPreview(api);
    expect(preview.mock.calls[0]?.[0].payload.lines[1]).toHaveProperty(
      "proposed_confirmed_quantity",
      "5.250000",
    );
    expect(screen.getByText(/21 bước × 0.250000/)).toBeVisible();
    fireEvent.change(screen.getByLabelText("Số lượng xác nhận Cà rốt"), {
      target: { value: "5.500000" },
    });
    expect(
      screen.queryByLabelText("Bản xem trước xác nhận"),
    ).not.toBeInTheDocument();
  });

  it("discards a late preview after the operator edits the active Draft", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const originalPreview = api.preview.bind(api);
    const pending = deferred<AtlasRpcResult>();
    api.preview = vi.fn(() => pending.promise);
    renderReview(api);
    const quantity = await screen.findByLabelText("Số lượng xác nhận Cà rốt");
    fireEvent.change(quantity, { target: { value: "5.250000" } });
    fireEvent.change(screen.getByLabelText("Lý do Cà rốt"), {
      target: { value: "PLANNING_STEP_ADJUSTMENT" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Xem trước xác nhận" }));
    await waitFor(() => expect(api.preview).toHaveBeenCalledOnce());
    const request = vi.mocked(api.preview).mock.calls[0]![0];

    fireEvent.change(quantity, { target: { value: "5.500000" } });
    await act(async () => {
      pending.resolve(await originalPreview(request));
    });

    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Xem trước xác nhận" }),
      ).not.toBeDisabled(),
    );
    expect(quantity).toHaveValue("5.500000");
    expect(
      screen.queryByLabelText("Bản xem trước xác nhận"),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Xác nhận số lượng" }),
    ).not.toBeInTheDocument();
  });

  it("discards a late preview after the active review is reloaded", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const originalGetReview = api.getReview.bind(api);
    const originalPreview = api.preview.bind(api);
    const pending = deferred<AtlasRpcResult>();
    let readCount = 0;
    api.getReview = vi.fn(
      async (...args: Parameters<typeof originalGetReview>) => {
        const result = await originalGetReview(...args);
        readCount += 1;
        if (readCount > 1 && result.kind === "success") {
          const workbench = result.response.workbench as unknown as {
            batch_version: number;
          };
          workbench.batch_version = 2;
        }
        return result;
      },
    );
    api.preview = vi.fn(() => pending.promise);
    renderReview(api);
    const quantity = await screen.findByLabelText("Số lượng xác nhận Cà rốt");
    fireEvent.change(quantity, { target: { value: "5.250000" } });
    fireEvent.change(screen.getByLabelText("Lý do Cà rốt"), {
      target: { value: "PLANNING_STEP_ADJUSTMENT" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Xem trước xác nhận" }));
    await waitFor(() => expect(api.preview).toHaveBeenCalledOnce());
    const request = vi.mocked(api.preview).mock.calls[0]![0];

    fireEvent.click(screen.getByRole("button", { name: "Làm mới" }));
    await waitFor(() => expect(api.getReview).toHaveBeenCalledTimes(2));
    expect(
      screen.getByText("Phiên bản", { exact: false }).querySelector("b"),
    ).toHaveTextContent("2");
    await act(async () => {
      pending.resolve(await originalPreview(request));
    });

    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Xem trước xác nhận" }),
      ).not.toBeDisabled(),
    );
    expect(
      screen.queryByLabelText("Bản xem trước xác nhận"),
    ).not.toBeInTheDocument();
    expect(
      screen.getByText("Phiên bản", { exact: false }).querySelector("b"),
    ).toHaveTextContent("2");
  });

  it("requires governed reasons and notes before preview", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const preview = vi.spyOn(api, "preview");
    renderReview(api);
    const carrot = await screen.findByLabelText("Số lượng xác nhận Cà rốt");
    fireEvent.change(carrot, { target: { value: "5.250000" } });
    fireEvent.change(screen.getByLabelText("Lý do Cà rốt"), {
      target: { value: "OTHER" },
    });
    expect(screen.getByText("Lý do này cần ghi chú.")).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Xem trước xác nhận" }));
    expect(preview).not.toHaveBeenCalled();
  });

  it("confirms mixed unchanged and adjusted lines and renders authoritative readback", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const confirm = vi.spyOn(api, "confirm");
    await prepareMixedPreview(api);
    fireEvent.click(
      screen.getByLabelText(
        "Tôi xác nhận đúng bản xem trước có thẩm quyền này",
      ),
    );
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận số lượng" }));
    await waitFor(() => expect(confirm).toHaveBeenCalledOnce());
    expect(
      await screen.findByText("ADJUSTED_QUANTITY_CONFIRMED"),
    ).toBeVisible();
    expect(screen.getByText("UNCHANGED_PROPOSAL_ACCEPTED")).toBeVisible();
  });

  it("discards late confirmation readback after a newer Draft edit", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const originalConfirm = api.confirm.bind(api);
    const pending = deferred<AtlasRpcResult>();
    await prepareMixedPreview(api);
    api.confirm = vi.fn(() => pending.promise);
    fireEvent.click(
      screen.getByLabelText(
        "Tôi xác nhận đúng bản xem trước có thẩm quyền này",
      ),
    );
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận số lượng" }));
    await waitFor(() => expect(api.confirm).toHaveBeenCalledOnce());
    const request = vi.mocked(api.confirm).mock.calls[0]![0];

    const quantity = screen.getByLabelText("Số lượng xác nhận Cà rốt");
    fireEvent.change(quantity, { target: { value: "5.500000" } });
    await act(async () => {
      pending.resolve(await originalConfirm(request));
    });

    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Xem trước xác nhận" }),
      ).not.toBeDisabled(),
    );
    expect(quantity).toHaveValue("5.500000");
    expect(
      screen.queryByLabelText("Bản xem trước xác nhận"),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByText("ADJUSTED_QUANTITY_CONFIRMED"),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", {
        name: "Gửi lại đúng lệnh chưa chắc chắn",
      }),
    ).not.toBeInTheDocument();
  });

  it("renders blockers before warnings", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const original = api.getReview.bind(api);
    api.getReview = vi.fn(async (...args: Parameters<typeof original>) => {
      const result = await original(...args);
      if (result.kind === "success") {
        const workbench = result.response.workbench as Record<string, unknown>;
        workbench.blockers = [
          { code: "BLOCK", message: "Lỗi chặn từ backend" },
        ];
        workbench.warnings = [{ code: "WARN", message: "Cảnh báo từ backend" }];
      }
      return result;
    });
    renderReview(api);
    const blocker = await screen.findByText("Lỗi chặn từ backend");
    const warning = screen.getByText("Cảnh báo từ backend");
    expect(
      blocker.compareDocumentPosition(warning) &
        Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
  });

  it("refreshes stale preview state while retaining local Draft values", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const getReview = vi.spyOn(api, "getReview");
    api.preview = vi.fn().mockResolvedValue({
      kind: "backend_error",
      error: {
        success: false,
        error_code: "STALE_CONFIRMED_NEED_BATCH",
        safe_message: "stale",
      },
    } satisfies AtlasRpcResult);
    renderReview(api);
    const quantity = await screen.findByLabelText("Số lượng xác nhận Cà rốt");
    fireEvent.change(quantity, { target: { value: "5.250000" } });
    fireEvent.change(screen.getByLabelText("Lý do Cà rốt"), {
      target: { value: "PLANNING_STEP_ADJUSTMENT" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Xem trước xác nhận" }));
    await waitFor(() => expect(getReview.mock.calls.length).toBeGreaterThan(1));
    expect(screen.getByLabelText("Số lượng xác nhận Cà rốt")).toHaveValue(
      "5.250000",
    );
  });

  it("never retries automatically and reuses the exact uncertain command on demand", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const original = api.confirm.bind(api);
    const confirm = vi
      .fn()
      .mockResolvedValueOnce({
        kind: "transport_error",
        diagnostic: {
          code: "NETWORK_FAILURE",
          safeMessage: "Chưa chắc chắn",
        },
      } satisfies AtlasRpcResult)
      .mockImplementation(original);
    api.confirm = confirm;
    await prepareMixedPreview(api);
    fireEvent.click(
      screen.getByLabelText(
        "Tôi xác nhận đúng bản xem trước có thẩm quyền này",
      ),
    );
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận số lượng" }));
    const retry = await screen.findByRole("button", {
      name: "Gửi lại đúng lệnh chưa chắc chắn",
    });
    expect(confirm).toHaveBeenCalledOnce();
    const exact = confirm.mock.calls[0]?.[0];
    fireEvent.click(retry);
    await waitFor(() => expect(confirm).toHaveBeenCalledTimes(2));
    expect(confirm.mock.calls[1]?.[0]).toBe(exact);
  });

  it("persists and renders a blocked complete-batch validation with line markers", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const validate = vi.spyOn(api, "validate");
    renderReview(api);
    await screen.findByText("Gạo thơm");
    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra toàn bộ" }));
    await waitFor(() => expect(validate).toHaveBeenCalledOnce());
    expect(
      await screen.findAllByText("Chưa đạt điều kiện kiểm tra"),
    ).not.toHaveLength(0);
    expect(screen.getAllByText(/chưa có quyết định hiện hành/)).toHaveLength(4);
    const blocker = screen.getAllByText(/chưa có quyết định hiện hành/)[0]!;
    const warning = screen.getAllByText(
      "Cảnh báo thượng nguồn được giữ lại.",
    )[0]!;
    expect(
      blocker.compareDocumentPosition(warning) &
        Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
    expect(
      screen.getByRole("button", { name: "Kiểm tra toàn bộ" }),
    ).not.toBeDisabled();
    expect(
      screen.getByLabelText("Số lượng xác nhận Cà rốt"),
    ).not.toBeDisabled();
    expect(
      screen.getByRole("button", { name: "Xem trước xác nhận" }),
    ).not.toBeDisabled();
  });

  it("validates a fully confirmed batch and switches the review to read-only", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    await confirmFixture(api);
    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra toàn bộ" }));
    expect(await screen.findByText("Đã kiểm tra")).toBeVisible();
    expect(
      screen.getAllByText("Đã kiểm tra; chờ phê duyệt").length,
    ).toBeGreaterThan(0);
    expect(
      screen.getByRole("button", { name: "Kiểm tra toàn bộ" }),
    ).toBeDisabled();
    expect(screen.getByLabelText("Số lượng xác nhận Cà rốt")).toBeDisabled();
    expect(
      screen.getByRole("button", { name: "Xem trước xác nhận" }),
    ).toBeDisabled();
    expect(
      screen.getByText("Lô đã được kiểm tra; chờ phê duyệt."),
    ).toBeVisible();
    expect(
      screen.getByRole("button", { name: "Phê duyệt lô nhu cầu" }),
    ).toBeVisible();
    expect(
      screen.queryByRole("button", { name: /phát hành|bàn giao/i }),
    ).not.toBeInTheDocument();
  });

  it("renders warning-only successful validation without treating it as blocking", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    await confirmFixture(api);
    const original = api.validate.bind(api);
    api.validate = vi.fn(async (request) => {
      const result = await original(request);
      if (result.kind === "success") {
        const readback = result.response.authoritative_readback as unknown as {
          validation: {
            warning_count: number;
            grouped_issues: { warnings: unknown[] };
          };
        };
        readback.validation.warning_count = 1;
        readback.validation.grouped_issues.warnings = [
          {
            code: "ZERO_CONFIRMED_QUANTITY",
            message: "Số lượng đã xác nhận bằng không.",
            severity: "WARNING",
            sort_position: 1,
          },
        ];
      }
      return result;
    });
    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra toàn bộ" }));
    expect(
      await screen.findByText("Số lượng đã xác nhận bằng không."),
    ).toBeVisible();
    expect(screen.getByText("Đã kiểm tra")).toBeVisible();
    expect(screen.queryByText("Vấn đề cần xử lý (1)")).not.toBeInTheDocument();
  });

  it("approves and separately releases the authoritative batch with lifecycle evidence", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const approve = vi.spyOn(api, "approve");
    const release = vi.spyOn(api, "release");
    await confirmFixture(api);
    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra toàn bộ" }));

    fireEvent.click(
      await screen.findByRole("button", { name: "Phê duyệt lô nhu cầu" }),
    );
    expect(
      screen.getByText(
        "Phê duyệt toàn bộ tập dữ liệu đã kiểm tra chính xác này?",
      ),
    ).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận phê duyệt" }));
    await waitFor(() => expect(approve).toHaveBeenCalledOnce());
    expect(
      await screen.findByText("Đã phê duyệt; chờ phát hành"),
    ).toBeVisible();
    expect(screen.getAllByText("Lan").length).toBeGreaterThan(0);

    fireEvent.click(
      screen.getByRole("button", {
        name: "Phát hành sang bước lên đơn",
      }),
    );
    expect(
      screen.getByText(/không chọn nhà cung cấp và không tạo đơn mua hàng/),
    ).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận phát hành" }));
    await waitFor(() => expect(release).toHaveBeenCalledOnce());
    expect(
      await screen.findByText("Đã phát hành sang bước lên đơn"),
    ).toBeVisible();
    expect(
      screen.getByText(/Lịch sử kiểm tra, phê duyệt và phát hành/),
    ).toBeVisible();
    expect(
      screen.queryByRole("button", { name: "Phát hành sang bước lên đơn" }),
    ).not.toBeInTheDocument();
  });

  it("shows exactly one current lifecycle message for each authoritative lifecycle state", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    await confirmFixture(api);

    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra toàn bộ" }));
    await screen.findByRole("button", { name: "Phê duyệt lô nhu cầu" });
    expectOnlyLifecycleMessage("Đã kiểm tra; chờ phê duyệt");

    fireEvent.click(
      screen.getByRole("button", { name: "Phê duyệt lô nhu cầu" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận phê duyệt" }));
    await screen.findByRole("button", {
      name: "Phát hành sang bước lên đơn",
    });
    expectOnlyLifecycleMessage("Đã phê duyệt; chờ phát hành");

    fireEvent.click(
      screen.getByRole("button", {
        name: "Phát hành sang bước lên đơn",
      }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận phát hành" }));
    await waitFor(() =>
      expect(
        screen.queryByRole("button", {
          name: "Phát hành sang bước lên đơn",
        }),
      ).not.toBeInTheDocument(),
    );
    expectOnlyLifecycleMessage("Đã phát hành sang bước lên đơn");
  });

  it("requires an authoritative refresh after an unknown approval outcome", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    await confirmFixture(api);
    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra toàn bộ" }));
    await screen.findByRole("button", { name: "Phê duyệt lô nhu cầu" });
    api.approve = vi.fn().mockResolvedValue({
      kind: "transport_error",
      diagnostic: {
        code: "NETWORK_FAILURE",
        safeMessage: "Chưa chắc chắn lệnh phê duyệt đã hoàn tất.",
      },
    } satisfies AtlasRpcResult);

    fireEvent.click(
      screen.getByRole("button", { name: "Phê duyệt lô nhu cầu" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận phê duyệt" }));
    expect(
      await screen.findByText(/Cần làm mới dữ liệu có thẩm quyền/),
    ).toBeVisible();
    expect(api.approve).toHaveBeenCalledOnce();
    expect(
      screen.queryByRole("button", { name: "Phê duyệt lô nhu cầu" }),
    ).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Làm mới" }));
    expect(
      await screen.findByRole("button", { name: "Phê duyệt lô nhu cầu" }),
    ).toBeVisible();
    expect(api.approve).toHaveBeenCalledOnce();
  });

  it("discards a late validation response after the active batch is reloaded", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const getReview = vi.spyOn(api, "getReview");
    const original = api.validate.bind(api);
    const pending = deferred<AtlasRpcResult>();
    api.validate = vi.fn(() => pending.promise);
    renderReview(api);
    await screen.findByText("Gạo thơm");
    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra toàn bộ" }));
    await waitFor(() => expect(api.validate).toHaveBeenCalledOnce());
    const request = vi.mocked(api.validate).mock.calls[0]![0];
    fireEvent.click(screen.getByRole("button", { name: "Làm mới" }));
    await waitFor(() => expect(getReview).toHaveBeenCalledTimes(2));
    await act(async () => pending.resolve(await original(request)));
    expect(screen.getByText("Chưa kiểm tra")).toBeVisible();
    expect(
      screen.queryByText("Chưa đạt điều kiện kiểm tra"),
    ).not.toBeInTheDocument();
  });

  it("discards a late validation response after a batch change", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const original = api.validate.bind(api);
    const pending = deferred<AtlasRpcResult>();
    api.validate = vi.fn(() => pending.promise);
    renderReview(api);
    await screen.findByText("Gạo thơm");
    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra toàn bộ" }));
    await waitFor(() => expect(api.validate).toHaveBeenCalledOnce());
    const request = vi.mocked(api.validate).mock.calls[0]![0];
    fireEvent.change(screen.getByLabelText("Mã lô Confirmed Need"), {
      target: { value: "c4500000-0000-0000-0000-000000000099" },
    });
    await act(async () => pending.resolve(await original(request)));
    expect(screen.getByText("Chưa kiểm tra")).toBeVisible();
  });

  it("discards a late validation response after a newer operator intent", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const original = api.validate.bind(api);
    const pending = deferred<AtlasRpcResult>();
    api.validate = vi.fn(() => pending.promise);
    renderReview(api);
    const quantity = await screen.findByLabelText("Số lượng xác nhận Cà rốt");
    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra toàn bộ" }));
    await waitFor(() => expect(api.validate).toHaveBeenCalledOnce());
    const request = vi.mocked(api.validate).mock.calls[0]![0];
    fireEvent.change(quantity, { target: { value: "5.250000" } });
    await act(async () => pending.resolve(await original(request)));
    expect(quantity).toHaveValue("5.250000");
    expect(screen.getByText("Chưa kiểm tra")).toBeVisible();
  });

  it("does not automatically retry a validation authorization failure", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    api.validate = vi.fn().mockResolvedValue({
      kind: "backend_error",
      error: {
        success: false,
        error_code: "CAPABILITY_DENIED",
        safe_message: "Không có quyền kiểm tra lô.",
        retryable: false,
      },
    } satisfies AtlasRpcResult);
    renderReview(api);
    await screen.findByText("Gạo thơm");
    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra toàn bộ" }));
    expect(
      await screen.findByText("Không có quyền kiểm tra lô."),
    ).toBeVisible();
    expect(api.validate).toHaveBeenCalledOnce();
  });
});
