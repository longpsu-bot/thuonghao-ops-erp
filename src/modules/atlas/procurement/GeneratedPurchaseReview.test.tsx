import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { GeneratedPurchaseReview } from "./GeneratedPurchaseReview";
import ExcelJS from "exceljs";
import { createGeneratedPurchaseReviewXlsx } from "./generatedPurchaseReviewExport";
import {
  createPurchaseReviewApi,
  type GeneratedPurchaseReview as ReviewData,
} from "./purchaseReviewApi";

afterEach(cleanup);
const review: ReviewData = {
  success: true,
  contract_version: "PURCHASE-REVIEW.v1",
  service_date: "2026-11-02",
  document_label: "DỰ KIẾN — CHƯA XÁC NHẬN",
  blockers: [],
  warnings: [],
  rows: [
    {
      service_date: "2026-11-02",
      school_id: "school",
      school_name: "Trường An Bình",
      delivery_location_id: "location",
      location_name: "Bếp An Bình",
      ingredient_id: "rice",
      ingredient_name: "Gạo",
      unit_id: "kg",
      unit_code: "kg",
      family_quantity: "100.000000",
      eligible_suppliers: [
        { supplier_id: "A", supplier_name: "Nhà cung ứng A", priority: 1 },
      ],
      recommendation: {
        supplier_id: "A",
        allocated_quantity: "100.000000",
        split_ratio: "1.000000000000",
      },
      warnings: [],
    },
  ],
};
describe("generated purchase review worksheet", () => {
  it("reads generated evidence, labels it preliminary, and exports without commands", async () => {
    const invoke = vi
      .fn()
      .mockResolvedValue({ kind: "success", response: review });
    const onExport = vi.fn();
    render(
      <GeneratedPurchaseReview
        api={createPurchaseReviewApi({ invoke })}
        authSubject="actor"
        serviceDate="2026-11-02"
        onExport={onExport}
      />,
    );
    fireEvent.click(screen.getByRole("button", { name: "In bản dự kiến" }));
    expect(await screen.findByText("DỰ KIẾN — CHƯA XÁC NHẬN")).toBeVisible();
    expect(screen.getByText("100.000000 kg")).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Tải XLSX dự kiến" }));
    await waitFor(() => expect(onExport).toHaveBeenCalledWith(review));
    expect(invoke).toHaveBeenCalledTimes(1);
    expect(invoke.mock.calls[0]![0]).toBe(
      "atlas_api.get_generated_purchase_review",
    );
  });
  it("uses the Retool v1 print layout without inventing a supplier or official number", async () => {
    const bytes = await createGeneratedPurchaseReviewXlsx({
      ...review,
      rows: [
        {
          ...review.rows[0]!,
          recommendation: null,
          warnings: ["AMBIGUOUS_SUPPLIER_PRIORITY"],
        },
      ],
    });
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(bytes);
    expect(workbook.worksheets.map((sheet) => sheet.name)).toEqual([
      "Tổng",
      "Chi tiết",
    ]);
    const text = JSON.stringify(workbook.model);
    expect(text).toContain("DỰ KIẾN — CHƯA XÁC NHẬN");
    expect(text).toContain("Chưa xác định NCC");
    expect(text).toContain("Điều chỉnh thủ công");
    expect(text).not.toContain("Số đơn");
    expect(text).not.toContain("PHIẾU ĐẶT HÀNG");
    for (const sheet of workbook.worksheets) {
      expect(sheet.pageSetup).toMatchObject({
        paperSize: 9,
        orientation: "portrait",
        fitToWidth: 1,
        fitToHeight: 0,
        printTitlesRow: "1:9",
      });
      expect(sheet.getCell("A4").value).toBe(review.document_label);
      expect(sheet.getCell("A4").font).toMatchObject({
        name: "Times New Roman",
        size: 16,
        bold: true,
      });
    }
    expect(workbook.getWorksheet("Tổng")!.getRow(9).values).toEqual([
      undefined,
      "STT",
      "Mã hàng",
      "Tên hàng",
      "Đơn vị",
      "Số lượng",
      "Ghi chú",
    ]);
    expect(text).toContain("Trường An Bình");
    expect(text).toContain("Bếp An Bình");
    expect(workbook.getWorksheet("Tổng")!.getCell("B12").value).toBeNull();
    expect(workbook.getWorksheet("Tổng")!.getCell("F12").value).toBeNull();
    if (process.env.PURCHASE_REVIEW_QA_XLSX) {
      const { writeFile } = await import("node:fs/promises");
      await writeFile(
        process.env.PURCHASE_REVIEW_QA_XLSX,
        new Uint8Array(bytes),
      );
    }
  });
  it("focuses the review heading and returns focus to its trigger on close", async () => {
    const invoke = vi
      .fn()
      .mockResolvedValue({ kind: "success", response: review });
    render(
      <GeneratedPurchaseReview
        api={createPurchaseReviewApi({ invoke })}
        authSubject="actor"
        serviceDate={review.service_date}
      />,
    );
    const trigger = screen.getByRole("button", { name: "In bản dự kiến" });
    fireEvent.click(trigger);
    expect(
      await screen.findByRole("heading", { name: review.document_label }),
    ).toHaveFocus();
    fireEvent.click(screen.getByRole("button", { name: "Đóng bản dự kiến" }));
    expect(trigger).toHaveFocus();
  });
  it("shows authoritative blockers and prevents exporting a blocked snapshot", async () => {
    const invoke = vi.fn().mockResolvedValue({
      kind: "success",
      response: { ...review, blockers: ["Nguồn chưa sẵn sàng."] },
    });
    render(
      <GeneratedPurchaseReview
        api={createPurchaseReviewApi({ invoke })}
        authSubject="actor"
        serviceDate={review.service_date}
      />,
    );
    fireEvent.click(screen.getByRole("button", { name: "In bản dự kiến" }));
    expect(await screen.findByText("Nguồn chưa sẵn sàng.")).toBeVisible();
    expect(
      screen.getByRole("button", { name: "Tải XLSX dự kiến" }),
    ).toBeDisabled();
  });
  it("aggregates only identical supplier/ingredient/unit keys and preserves decimal evidence", async () => {
    const bytes = await createGeneratedPurchaseReviewXlsx({
      ...review,
      rows: [
        { ...review.rows[0]!, family_quantity: "99999999999999.000001" },
        {
          ...review.rows[0]!,
          school_id: "second",
          school_name: "Trường Hai",
          family_quantity: "0.000001",
        },
      ],
    });
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(bytes);
    const text = JSON.stringify(workbook.model);
    expect(text).toContain("99999999999999.000002");
    expect(text).toContain("99999999999999.000001");
    expect(text).toContain("0.000001");
    expect(workbook.getWorksheet("Tổng")!.getCell("E11").value).toBe(
      "99999999999999.000002",
    );
  });
  it("rejects mixed dates or invalid exact quantities before exporting", async () => {
    await expect(
      createGeneratedPurchaseReviewXlsx({
        ...review,
        rows: [{ ...review.rows[0]!, service_date: "2026-11-03" }],
      }),
    ).rejects.toThrow("current generated");
    await expect(
      createGeneratedPurchaseReviewXlsx({
        ...review,
        rows: [{ ...review.rows[0]!, family_quantity: "0.0000001" }],
      }),
    ).rejects.toThrow("current generated");
  });
});
