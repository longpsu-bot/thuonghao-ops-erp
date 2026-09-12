import "@testing-library/jest-dom/vitest";
import {
  act,
  cleanup,
  fireEvent,
  render,
  renderHook,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import readXlsxFile from "read-excel-file/browser";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { DishRecipeWorkbench } from "./DishRecipeWorkbench";
import {
  createRecipeReviewFixture,
  fixtureError,
} from "./recipeReviewFixtures";
import { useDishRecipeWorkbench } from "./useDishRecipeWorkbench";
vi.mock("read-excel-file/browser", () => ({ default: vi.fn() }));
afterEach(cleanup);
function sheets(invalid = false) {
  return [
    {
      sheet: "Công thức",
      data: [
        ["Tên món", "Loại công thức", "Tên công thức"],
        ["Món nhập", "Khối nhỏ", "Mẫu"],
      ],
    },
    {
      sheet: "Định lượng",
      data: [
        [
          "Tên món",
          "Loại công thức",
          "Tên nguyên liệu",
          "Định lượng/100 suất",
          "Đơn vị mua (tham khảo)",
        ],
        [
          "Món nhập",
          "Khối nhỏ",
          invalid ? "Không có" : "Bí đỏ",
          "0,5",
          "Kilôgam",
        ],
      ],
    },
  ];
}
const file = () => new File(["local workbook"], "recipes.xlsx");
describe("existing workbook import utility", () => {
  it("keeps generated import identities out of duplicate-row errors", async () => {
    const duplicate = sheets();
    duplicate[1].data.push(duplicate[1].data[1]);
    vi.mocked(readXlsxFile).mockResolvedValue(duplicate);
    const fixture = createRecipeReviewFixture();
    render(
      <AtlasVNextProvider>
        <DishRecipeWorkbench
          api={fixture.api}
          authSubject="operator"
          initialDate="2026-09-12"
        />
      </AtlasVNextProvider>,
    );
    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Nhập workbook" }),
      ).toBeEnabled(),
    );
    fireEvent.click(screen.getByRole("button", { name: "Nhập workbook" }));
    fireEvent.change(screen.getByLabelText("Chọn workbook .xlsx"), {
      target: { files: [file()] },
    });
    await screen.findByText(/Kết quả kiểm tra:/);
    expect(screen.queryByText(/ops-v1:/)).not.toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Áp dụng workbook" }),
    ).toBeDisabled();
  });
  it("recovers an unknown import only when every workbook Recipe is present in authoritative evidence", async () => {
    vi.mocked(readXlsxFile).mockResolvedValue(sheets());
    const fixture = createRecipeReviewFixture();
    const original = fixture.api.applyImport;
    fixture.api.applyImport = async (request) => {
      await original(request);
      return {
        kind: "transport_error",
        diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Unknown" },
      };
    };
    const h = renderHook(() =>
      useDishRecipeWorkbench({
        api: fixture.api,
        authSubject: "operator",
        initialDate: "2026-09-12",
      }),
    );
    await waitFor(() => expect(h.result.current.canCommand).toBe(true));
    act(() => h.result.current.transition({ kind: "import" }));
    await act(() => h.result.current.parseWorkbook(file()));
    await act(() => h.result.current.applyImport("Đã kiểm tra"));
    expect(h.result.current.lock).toBe("unknown");
    await act(() => h.result.current.recover());
    expect(h.result.current.lock).toBeNull();
    expect(h.result.current.notice).toContain("Đã nhập workbook");
  });
  it.each([false, true])(
    "uses the existing parser and displays validation (invalid=%s) without writing",
    async (invalid) => {
      vi.mocked(readXlsxFile).mockResolvedValue(sheets(invalid));
      const fixture = createRecipeReviewFixture();
      const apply = vi.spyOn(fixture.api, "applyImport");
      render(
        <AtlasVNextProvider>
          <DishRecipeWorkbench
            api={fixture.api}
            authSubject="operator"
            initialDate="2026-09-12"
          />
        </AtlasVNextProvider>,
      );
      await waitFor(() =>
        expect(
          screen.getByRole("button", { name: "Nhập workbook" }),
        ).toBeEnabled(),
      );
      fireEvent.click(screen.getByRole("button", { name: "Nhập workbook" }));
      fireEvent.change(screen.getByLabelText("Chọn workbook .xlsx"), {
        target: { files: [file()] },
      });
      await screen.findByText(/Kết quả kiểm tra:/);
      expect(readXlsxFile).toHaveBeenCalled();
      expect(apply).not.toHaveBeenCalled();
      expect(screen.queryByText(/[a-f0-9]{64}/)).not.toBeInTheDocument();
      fireEvent.change(screen.getByLabelText("Lý do nhập workbook"), {
        target: { value: "Đã kiểm tra" },
      });
      if (invalid) {
        expect(
          screen.getByRole("button", { name: "Áp dụng workbook" }),
        ).toBeDisabled();
        expect(
          screen.getByText(/Trang Định lượng, dòng 2/),
        ).toBeInTheDocument();
      } else {
        expect(
          screen.getByText("Số món: 1 · Số công thức: 1"),
        ).toBeInTheDocument();
        fireEvent.click(
          screen.getByRole("button", { name: "Áp dụng workbook" }),
        );
        await screen.findByText(/Đã nhập workbook và tải lại/);
        expect(apply).toHaveBeenCalledTimes(1);
        expect(apply.mock.calls[0][0]).toMatchObject({
          expected_version: 1,
          reason_code: "RECIPE_WORKBOOK_IMPORT",
          payload: {
            workbook_checksum: expect.stringMatching(/^[a-f0-9]{64}$/),
          },
        });
      }
    },
  );
  it.each(["IMPORT_UNKNOWN", "SAVE_SUCCESS_READBACK_FAILURE"] as const)(
    "requires readback and never automatically resends %s",
    async (scenario) => {
      vi.mocked(readXlsxFile).mockResolvedValue(sheets());
      const fixture = createRecipeReviewFixture(scenario);
      const h = renderHook(() =>
        useDishRecipeWorkbench({
          api: fixture.api,
          authSubject: "operator",
          initialDate: "2026-09-12",
        }),
      );
      await waitFor(() => expect(h.result.current.canCommand).toBe(true));
      act(() => h.result.current.transition({ kind: "import" }));
      await act(() => h.result.current.parseWorkbook(file()));
      const apply = vi.spyOn(fixture.api, "applyImport");
      if (scenario !== "IMPORT_UNKNOWN")
        fixture.api.getWorkbench = async () =>
          fixtureError("INTERNAL_READ_FAILURE");
      await act(() => h.result.current.applyImport("Đã kiểm tra"));
      expect(h.result.current.lock).toBe(
        scenario === "IMPORT_UNKNOWN" ? "unknown" : "readback",
      );
      await act(() => h.result.current.applyImport("Đã kiểm tra"));
      await act(() => h.result.current.recover());
      expect(apply).toHaveBeenCalledTimes(1);
      expect(h.result.current.lock).not.toBeNull();
    },
  );
});
