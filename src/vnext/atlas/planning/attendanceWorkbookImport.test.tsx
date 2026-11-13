import "@testing-library/jest-dom/vitest";
import ExcelJS from "exceljs";
import readXlsxFile from "read-excel-file/browser";
import {
  act,
  cleanup,
  fireEvent,
  render,
  renderHook,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import type { PlanningInputsApi } from "../bridges/planning";
import { PlanningSourcesWorkbench } from "./PlanningSourcesWorkbench";
import { usePlanningSources } from "./usePlanningSources";
import {
  createPlanningReviewFixture,
  reviewWeek,
  unknown,
  stale,
} from "./planningReviewFixtures";

vi.mock("read-excel-file/browser", () => ({ default: vi.fn() }));
const reader = vi.mocked(readXlsxFile);
const actualReader = await vi.importActual<
  typeof import("read-excel-file/browser")
>("read-excel-file/browser");
const file = () => new File(["workbook"], "attendance.xlsx");
const workbook = (row: (string | number)[] = ["TH001", reviewWeek, 0, 12]) => [
  {
    sheet: "Sĩ số",
    data: [["Mã trường", "Ngày", "Số suất học sinh", "Số suất giáo viên"], row],
  },
];
beforeEach(() => {
  reader.mockReset();
  reader.mockResolvedValue(workbook());
  vi.stubGlobal(
    "ResizeObserver",
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  );
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});
async function setup() {
  const fixture = createPlanningReviewFixture();
  const hook = renderHook(
    ({ authSubject, freshnessRevision }) =>
      usePlanningSources({
        ...fixture,
        authSubject,
        freshnessRevision,
        initialWeek: reviewWeek,
        ownerJob: "attendance",
      }),
    { initialProps: { authSubject: "operator", freshnessRevision: 0 } },
  );
  await waitFor(() => expect(hook.result.current.canEdit).toBe(true));
  return { ...hook, fixture };
}
describe("Attendance XLSX operator import", () => {
  it("stages parsed zero with file evidence and saves only after canonical review and explicit Save", async () => {
    const book = new ExcelJS.Workbook();
    book.addWorksheet("Sĩ số").addRows(workbook()[0].data);
    const bytes = new Uint8Array(await book.xlsx.writeBuffer());
    const uploaded = new File([bytes], "attendance.xlsx");
    // jsdom File omits the browser Blob.arrayBuffer implementation.
    Object.defineProperty(uploaded, "arrayBuffer", {
      value: async () => bytes.buffer,
    });
    reader.mockImplementation(actualReader.default);
    const fixture = createPlanningReviewFixture();
    const preview = vi.spyOn(
      fixture.api as Pick<PlanningInputsApi, "previewAttendance">,
      "previewAttendance",
    );
    const save = vi.spyOn(
      fixture.api as Pick<PlanningInputsApi, "saveCompletedAttendance">,
      "saveCompletedAttendance",
    );
    render(
      <AtlasVNextProvider>
        <PlanningSourcesWorkbench
          {...fixture}
          authSubject="operator"
          initialWeek={reviewWeek}
          ownerJob="attendance"
        />
      </AtlasVNextProvider>,
    );
    const input = await screen.findByLabelText("Nhập sĩ số XLSX");
    const picker = screen.getByRole("button", { name: "Nhập sĩ số XLSX" });
    await waitFor(() => expect(input).toBeEnabled());
    expect(input).not.toBeVisible();
    const openPicker = vi.spyOn(input, "click");
    fireEvent.click(picker);
    expect(openPicker).toHaveBeenCalledOnce();
    fireEvent.change(input, { target: { files: [uploaded] } });
    await waitFor(() =>
      expect(
        screen.getByRole("textbox", { name: "Học sinh Trường Nguyễn Du" }),
      ).toHaveValue("0"),
    );
    expect(preview).not.toHaveBeenCalled();
    expect(save).not.toHaveBeenCalled();
    expect(input).toBeDisabled();
    expect(picker).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await waitFor(() => expect(preview).toHaveBeenCalledOnce());
    expect(preview.mock.calls[0][3]).toEqual([
      expect.objectContaining({
        student_portions: 0,
        source_row_reference: "attendance.xlsx:Sĩ số:row:2",
      }),
    ]);
    expect(save).not.toHaveBeenCalled();
    const saveButton = await screen.findByRole("button", { name: "Lưu" });
    await waitFor(() => expect(saveButton).toBeEnabled());
    fireEvent.click(saveButton);
    await waitFor(() => expect(save).toHaveBeenCalledOnce());
    expect(save.mock.calls[0][0]).toMatchObject({
      payload: {
        source_signature: "attendance-preview",
        source_type: "XLSX",
        source_name: "attendance.xlsx / Sĩ số",
      },
    });
  });
  it.each([
    ["unknown School", ["MISSING", reviewWeek, 1, 2]],
    ["wrong week", ["TH001", "2027-01-01", 1, 2]],
    ["blank count", ["TH001", reviewWeek, "", 2]],
    ["negative count", ["TH001", reviewWeek, -1, 2]],
    ["invalid date", ["TH001", "2026-09-99", 1, 2]],
  ])("rejects %s without replacing working rows", async (_, row) => {
    const { result } = await setup();
    const original = result.current.attendanceRows;
    reader.mockResolvedValue(workbook(row as (string | number)[]));
    await act(() => result.current.importAttendanceWorkbook(file()));
    expect(result.current.attendanceRows).toEqual(original);
    expect(result.current.outcome).toMatch(/Không thể nhập/);
  });
  it.each([
    "empty",
    "header only",
    "malformed",
    "unreadable",
    "wrong file type",
    "zero bytes",
  ])("rejects %s without replacing rows", async (kind) => {
    const { result } = await setup();
    const original = result.current.attendanceRows;
    if (kind === "empty")
      reader.mockResolvedValue([{ sheet: "Sheet1", data: [] }]);
    if (kind === "header only")
      reader.mockResolvedValue([
        { sheet: "Sheet1", data: [workbook()[0].data[0]] },
      ]);
    if (kind === "malformed")
      reader.mockResolvedValue([
        { sheet: "Sheet1", data: [["Tên trường", "Ngày"]] },
      ]);
    if (kind === "unreadable")
      reader.mockRejectedValue(new Error("private reader detail"));
    await act(() =>
      result.current.importAttendanceWorkbook(
        kind === "wrong file type"
          ? new File(["csv"], "attendance.csv")
          : kind === "zero bytes"
            ? new File([], "attendance.xlsx")
            : file(),
      ),
    );
    expect(result.current.attendanceRows).toEqual(original);
    expect(result.current.outcome).toMatch(/Không thể nhập/);
    expect(result.current.outcome).not.toContain("private reader detail");
  });
  it.each(["UNKNOWN", "STALE", "READ_FAILURE"])(
    "keeps %s recovery locked against file import",
    async (kind) => {
      const { result, fixture } = await setup();
      if (kind === "READ_FAILURE") {
        fixture.api.getWorkbench = async () => unknown;
        await act(() => result.current.recover());
      } else {
        fixture.api.saveCompletedAttendance = async () =>
          kind === "UNKNOWN" ? unknown : stale;
        act(() => result.current.editAttendance(0, "student_portions", "345"));
        await act(() => result.current.previewChanges());
        await act(() => result.current.save());
      }
      expect(result.current.canEdit).toBe(false);
      const original = result.current.attendanceRows;
      await act(() => result.current.importAttendanceWorkbook(file()));
      expect(reader).not.toHaveBeenCalled();
      expect(result.current.attendanceRows).toEqual(original);
    },
  );
  it("preserves dirty edits and does not start parsing a replacement", async () => {
    const { result } = await setup();
    act(() => result.current.editAttendance(0, "student_portions", "345"));
    await act(() => result.current.importAttendanceWorkbook(file()));
    expect(reader).not.toHaveBeenCalled();
    expect(result.current.attendanceRows[0].student_portions).toBe("345");
  });
  it.each(["edit", "week", "auth", "freshness"])(
    "discards late parsing after %s change",
    async (change) => {
      const { result, rerender } = await setup();
      let resolve!: (value: ReturnType<typeof workbook>) => void;
      reader.mockReturnValue(
        new Promise((done) => {
          resolve = done;
        }),
      );
      let importing!: Promise<void>;
      act(() => {
        importing = result.current.importAttendanceWorkbook(file());
      });
      if (change === "edit")
        act(() => result.current.editAttendance(0, "student_portions", "345"));
      if (change === "week")
        act(() => result.current.transition({ week: "2026-09-14" }));
      if (change === "auth")
        rerender({ authSubject: "other", freshnessRevision: 0 });
      if (change === "freshness")
        rerender({ authSubject: "operator", freshnessRevision: 1 });
      await act(async () => {
        resolve(workbook());
        await importing;
      });
      expect(
        result.current.attendanceRows.some((row) =>
          row.source_row_reference?.startsWith("attendance.xlsx:"),
        ),
      ).toBe(false);
      if (change === "edit")
        expect(result.current.attendanceRows[0].student_portions).toBe("345");
    },
  );
});
