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
import { ConfirmedNeedReviewWorkbench } from "./ConfirmedNeedReviewWorkbench";
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

function renderReview(api = createReviewConfirmedNeedApi("ready")) {
  render(
    <ConfirmedNeedReviewWorkbench
      authState={authState}
      api={api}
      initialBatchId={batchId}
      mode="review"
    />,
  );
  return api;
}

function renderAuthoritativeFixture(
  mutate: (
    workbench: ReturnType<typeof createReviewConfirmedNeedFixture>,
  ) => void,
) {
  const api = createReviewConfirmedNeedApi("ready");
  const workbench = createReviewConfirmedNeedFixture();
  mutate(workbench);
  vi.spyOn(api, "getReview").mockResolvedValue({
    kind: "success",
    response: { success: true, workbench },
  } as never);
  renderReview(api);
  return api;
}

async function saveAll(api = createReviewConfirmedNeedApi("ready")) {
  renderReview(api);
  await screen.findByText("Gạo thơm");
  fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
  await screen.findByText("Đã lưu thay đổi.");
  return api;
}

describe("Confirmed Need two-action workbench", () => {
  it("uses all three canonical Planning review schools", () => {
    const fixture = createReviewConfirmedNeedFixture(3);

    expect(fixture.lines.map((line) => line.school)).toEqual([
      {
        id: "review-planning-school-1",
        name: "Trường Tiểu học Nguyễn Du",
      },
      {
        id: "review-planning-school-2",
        name: "Trường Tiểu học Trần Quốc Toản",
      },
      {
        id: "review-planning-school-3",
        name: "Trường Mầm non Hoa Hồng",
      },
    ]);
  });

  it("shows the current work context in first-time operator language", async () => {
    renderReview();
    await screen.findByText("Gạo thơm");
    expect(
      screen.getByRole("heading", { name: "Xác nhận nhu cầu" }),
    ).toBeVisible();
    expect(screen.getByText("Tuần 03/08/2026–09/08/2026")).toBeVisible();
    expect(screen.getAllByText("Tất cả trường").length).toBeGreaterThan(0);
    expect(screen.getByText("2 dòng")).toBeVisible();
    expect(screen.getAllByText("Chưa lưu").length).toBeGreaterThan(0);
  });

  it.each([
    ["ingredient", "cà rốt", "Cà rốt"],
    ["school", "nguyễn du", "Trường Tiểu học Nguyễn Du"],
    ["delivery location", "bếp phụ", "Bếp phụ"],
  ])("searches loaded %s fields", async (_kind, query, expected) => {
    renderReview();
    await screen.findByText("Gạo thơm");
    fireEvent.change(
      screen.getByPlaceholderText("Tìm theo nguyên liệu, trường, điểm giao…"),
      { target: { value: query } },
    );
    expect(
      screen
        .getAllByText(expected)
        .some((element) => element.tagName !== "OPTION"),
    ).toBe(true);
    expect(screen.getByText("Hiển thị 1/2 dòng")).toBeVisible();
  });

  it("keeps School and date filters as presentation-only filters", async () => {
    renderReview();
    await screen.findByText("Gạo thơm");
    const toolbar = screen.getByRole("region", { name: "Tìm và lọc" });
    fireEvent.change(within(toolbar).getByLabelText("Trường"), {
      target: { value: "review-planning-school-1" },
    });
    expect(screen.getByText("Hiển thị 1/2 dòng")).toBeVisible();
    fireEvent.change(within(toolbar).getByLabelText("Ngày"), {
      target: { value: "2026-08-04" },
    });
    expect(screen.getByText("Hiển thị 0/2 dòng")).toBeVisible();
  });

  it("exposes Save and Release but no validation, completion, or approval ceremony", async () => {
    renderReview();
    await screen.findByText("Gạo thơm");
    expect(screen.getByRole("button", { name: "Lưu" })).toBeVisible();
    expect(
      screen.getByRole("button", { name: "Chuyển sang lên đơn" }),
    ).toBeVisible();
    expect(
      screen.queryByRole("button", {
        name: /Hoàn tất xác nhận|Phê duyệt|Phát hành/,
      }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByText(/250|API|capability|batch ID|phiên bản/i),
    ).not.toBeInTheDocument();
  });

  it("saves through one v2 command and does not release", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const save = vi.spyOn(api, "save");
    const release = vi.spyOn(api, "releaseSaved");
    await saveAll(api);
    expect(save).toHaveBeenCalledTimes(1);
    expect(save.mock.calls[0]?.[0].payload.lines).toHaveLength(2);
    expect(release).not.toHaveBeenCalled();
    expect(screen.getAllByText("Đã lưu").length).toBeGreaterThan(0);
  });

  it("presents backend continuity states and omits untouched carried lines from Save", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const workbench = createReviewConfirmedNeedFixture();
    const carried = workbench.lines[0]!;
    carried.current_decision_id = "c4520000-0000-0000-0000-000000000091";
    carried.current_decision_number = 1;
    carried.current_decision_kind = "ADJUSTED_QUANTITY_CONFIRMED";
    carried.confirmed_quantity_after = "10.000000";
    carried.confirmation_state = "CARRIED_FORWARD";
    workbench.lines[1]!.confirmation_state = "CHANGED";
    workbench.line_counts = {
      total: 2,
      unreviewed: 1,
      confirmed: 1,
      adjusted: 1,
      carried_forward: 1,
      needs_review: 1,
      changed: 1,
      new: 0,
      removed: 0,
    };
    vi.spyOn(api, "getReview").mockResolvedValue({
      kind: "success",
      response: { success: true, workbench },
    } as never);
    const save = vi.spyOn(api, "save");
    renderReview(api);

    await screen.findByText("Gạo thơm");
    expect(screen.getByText("1 cần rà soát")).toBeVisible();
    expect(screen.getByText("1 giữ nguyên")).toBeVisible();
    expect(screen.getAllByText("Giữ nguyên").length).toBeGreaterThan(1);
    expect(screen.getAllByText("Cần rà soát").length).toBeGreaterThan(1);
    fireEvent.change(screen.getByLabelText("Tình trạng"), {
      target: { value: "carried_forward" },
    });
    expect(screen.getByText("Hiển thị 1/2 dòng")).toBeVisible();
    fireEvent.change(screen.getByLabelText("Tình trạng"), {
      target: { value: "" },
    });

    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await waitFor(() => expect(save).toHaveBeenCalledTimes(1));
    expect(save.mock.calls[0]?.[0].payload.lines).toEqual([
      expect.objectContaining({
        confirmed_need_line_id: "c4520000-0000-0000-0000-000000000002",
      }),
    ]);
  });

  it("does not promote Save when authoritative readback denies it", async () => {
    const api = renderAuthoritativeFixture((workbench) => {
      workbench.allowed_actions.save_confirmed_needs = false;
      workbench.disabled_reason_codes.save_confirmed_needs =
        "SAVE_CAPABILITY_REQUIRED";
      workbench.disabled_reasons.save_confirmed_needs =
        "Bạn chưa có quyền lưu thay đổi này.";
    });
    await screen.findByText("Gạo thơm");
    const save = screen.getByRole("button", { name: "Lưu" });
    const saveRequest = vi.spyOn(api, "save");
    expect(save).toBeDisabled();
    expect(save).not.toHaveClass("primary");
    expect(save).toHaveAttribute(
      "title",
      "Bạn chưa có quyền lưu thay đổi này.",
    );
    fireEvent.click(save);
    expect(saveRequest).not.toHaveBeenCalled();
  });

  it("does not promote Release when authoritative readback denies it", async () => {
    renderAuthoritativeFixture((workbench) => {
      workbench.lines = workbench.lines.map((line, index) => ({
        ...line,
        current_decision_id: `c4520000-0000-0000-0000-00000000000${index + 1}`,
        current_decision_number: 1,
        confirmed_quantity_after: line.proposed_confirmed_quantity,
      }));
      workbench.line_counts = {
        total: workbench.lines.length,
        unreviewed: 0,
        confirmed: workbench.lines.length,
        adjusted: 0,
        carried_forward: 0,
        needs_review: 0,
        changed: 0,
        new: 0,
        removed: 0,
      };
      workbench.allowed_actions.release_confirmed_needs = false;
      workbench.disabled_reason_codes.release_confirmed_needs =
        "RELEASE_CAPABILITY_REQUIRED";
      workbench.disabled_reasons.release_confirmed_needs =
        "Bạn chưa có quyền thực hiện bước này.";
    });
    await screen.findByText("Gạo thơm");
    const release = screen.getByRole("button", {
      name: "Chuyển sang lên đơn",
    });
    expect(release).toBeDisabled();
    expect(release).not.toHaveClass("primary");
    expect(release).toHaveAttribute(
      "title",
      "Bạn chưa có quyền thực hiện bước này.",
    );
  });

  it("uses backend eligibility as a ceiling and local validity as a stricter gate", async () => {
    renderReview();
    await screen.findByText("Gạo thơm");
    const save = screen.getByRole("button", { name: "Lưu" });
    expect(save).toBeEnabled();
    expect(save).toHaveClass("primary");
    fireEvent.change(screen.getByLabelText("Số lượng xác nhận Gạo thơm"), {
      target: { value: "không hợp lệ" },
    });
    expect(save).toBeDisabled();
    expect(save).not.toHaveClass("primary");
  });

  it("releases only after a current complete save and concise confirmation", async () => {
    const api = await saveAll();
    const release = vi.spyOn(api, "releaseSaved");
    const releaseButton = screen.getByRole("button", {
      name: "Chuyển sang lên đơn",
    });
    expect(releaseButton).toBeEnabled();
    expect(releaseButton).toHaveClass("primary");
    fireEvent.click(releaseButton);
    const dialog = screen.getByRole("dialog", {
      name: "Xác nhận chuyển sang lên đơn",
    });
    expect(dialog).toHaveTextContent("chưa phân bổ nhà cung cấp");
    expect(dialog).toHaveTextContent("chưa tạo Bàn giao mua hàng");
    expect(dialog).toHaveTextContent("chưa tạo Đơn mua hàng");
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận chuyển" }));
    await screen.findByText("Đã chuyển sang lên đơn.");
    expect(release).toHaveBeenCalledTimes(1);
    expect(
      screen.getAllByText("Đã chuyển sang lên đơn").length,
    ).toBeGreaterThan(0);
    expect(screen.getByLabelText("Số lượng xác nhận Cà rốt")).toBeDisabled();
  });

  it("requires authoritative refresh after an unknown Save outcome without automatic retry", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const save = vi.spyOn(api, "save").mockResolvedValue({
      kind: "transport_error",
      diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Mất kết nối." },
    });
    renderReview(api);
    await screen.findByText("Gạo thơm");
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    expect(await screen.findByText(/Atlas sẽ không tự gửi lại/)).toBeVisible();
    expect(save).toHaveBeenCalledTimes(1);
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled(),
    );
    expect(screen.getByRole("button", { name: "Làm mới" })).toBeEnabled();
  });

  it("keeps Excel and PDF as disabled placeholders without file generation", async () => {
    renderReview();
    await screen.findByText("Gạo thơm");
    expect(screen.getByRole("button", { name: "Xuất Excel" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Xuất PDF" })).toBeDisabled();
    expect(
      screen.getByText(
        "Chức năng xuất file sẽ được hoàn thiện sau khi mẫu dữ liệu được chốt.",
      ),
    ).toBeVisible();
    expect(screen.queryByText("Nhập Excel")).not.toBeInTheDocument();
  });

  it("uses readable human-scale controls at desktop and mobile breakpoints", async () => {
    renderReview();
    await screen.findByText("Gạo thơm");
    const { readFileSync } = await vi.importActual<{
      readFileSync(path: string | URL, encoding: "utf8"): string;
    }>("node:fs");
    const styles = readFileSync("src/styles.css", "utf8");
    expect(styles).toContain("font-size: clamp(22px, 2vw, 26px)");
    expect(styles).toContain("min-height: 40px");
    expect(styles).toContain("@media (max-width: 900px)");
    expect(styles).toContain("@media (max-width: 520px)");
    expect(styles).toContain("min-height: 44px");
  });
});
