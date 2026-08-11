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

async function saveAll(api = createReviewConfirmedNeedApi("ready")) {
  renderReview(api);
  await screen.findByText("Gạo thơm");
  fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
  await screen.findByText("Đã lưu thay đổi.");
  return api;
}

describe("Confirmed Need two-action workbench", () => {
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
    ["school", "hoa sen", "Trường Mầm non Hoa Sen"],
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
      target: { value: "a1100000-0000-0000-0000-000000000002" },
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

  it("releases only after a current complete save and concise confirmation", async () => {
    const api = await saveAll();
    const release = vi.spyOn(api, "releaseSaved");
    fireEvent.click(
      screen.getByRole("button", { name: "Chuyển sang lên đơn" }),
    );
    expect(
      screen.getByRole("dialog", { name: "Xác nhận chuyển sang lên đơn" }),
    ).toHaveTextContent("chưa chọn nhà cung cấp");
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
    expect(screen.getByRole("button", { name: "Tải lại" })).toBeEnabled();
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
