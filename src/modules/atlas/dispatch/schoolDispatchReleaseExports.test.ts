import ExcelJS from "exceljs";
import { describe, expect, it } from "vitest";
import { createReviewSchoolDispatchDocument } from "./reviewSchoolDispatchReleaseApi";
import {
  buildSchoolDispatchExportData,
  buildSchoolDispatchPdfDefinition,
  createGroupedSchoolDispatchXlsx,
  createSchoolDispatchXlsx,
} from "./schoolDispatchReleaseExports";

describe("School dispatch release exports", () => {
  it.each(["RELEASED", "SUPERSEDED"] as const)(
    "keeps an immutable %s PXK exportable",
    (status) => {
      const document = createReviewSchoolDispatchDocument(status);
      expect(buildSchoolDispatchExportData(document)).toMatchObject({
        documentNumber: "PXK-20260924-2600000000004000",
        schoolName: "Trường Tiểu học Nguyễn Du",
        issuerName: "CƠ SỞ CUNG CẤP THỰC PHẨM THƯỢNG HẢO",
        lines: [
          {
            ingredientName: "Gạo thơm",
            quantity: "100.000000",
            unitCode: "kg",
          },
        ],
      });
      expect(
        JSON.stringify(buildSchoolDispatchPdfDefinition(document)),
      ).toContain("PHIẾU XUẤT KHO");
    },
  );

  it("creates a workbook with the official PXK identity and exact quantity", async () => {
    const bytes = await createSchoolDispatchXlsx(
      createReviewSchoolDispatchDocument("RELEASED"),
    );
    expect(bytes.byteLength).toBeGreaterThan(1000);
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(bytes);
    const sheet = workbook.worksheets[0]!;
    expect(sheet.pageSetup).toMatchObject({
      paperSize: 9,
      orientation: "portrait",
    });
    expect(sheet.getColumn(1).width).toBeCloseTo(13, 1);
    expect(sheet.getColumn(2).width).toBeCloseTo(37.43, 1);
    expect(sheet.getColumn(7).width).toBe(14);
    expect(sheet.getCell("A1").alignment.horizontal).toBe("center");
    expect(sheet.getCell("A2").alignment.horizontal).toBe("center");
    expect(sheet.getCell("A9").value).toBe("Stt");
    expect(sheet.getCell("A5").value).toBe(
      "Số phiếu: PXK-20260924-2600000000004000",
    );
    expect(sheet.getCell("E9").value).toBe("Tình trạng cảm quan");
    expect(sheet.getCell("E10").value).toBe("Đạt");
    expect(sheet.getCell("F10").value).toBe("K Đạt");
    expect(sheet.getCell("G9").value).toBe("Biện pháp xử lý");
    expect(sheet.getCell("D11").value).toBe(100);
    expect(workbook.model.media).toHaveLength(1);
    expect(sheet.getRow(11).height).toBe(30);
    expect(JSON.stringify(sheet.getSheetValues())).toContain("Người nhận hàng");
    expect(JSON.stringify(sheet.getSheetValues())).toContain("Người giao hàng");
    expect(JSON.stringify(sheet.getSheetValues())).toContain("Người lập phiếu");
  });

  it("includes a relevant immutable release note in the export snapshot", () => {
    const document = createReviewSchoolDispatchDocument("RELEASED");
    document.note = "Giao tại cổng phụ trước 06:00";

    expect(buildSchoolDispatchExportData(document)).toMatchObject({
      note: "Giao tại cổng phụ trước 06:00",
    });
    expect(
      JSON.stringify(buildSchoolDispatchPdfDefinition(document)),
    ).toContain("Giao tại cổng phụ trước 06:00");
  });

  it("groups released snapshots by service date and immutable School order", async () => {
    const laterSchool = createReviewSchoolDispatchDocument("SUPERSEDED");
    laterSchool.school_name = "Trường B";
    laterSchool.school_display_order = 2;
    laterSchool.document_number = "PXK-B";
    const firstSchool = createReviewSchoolDispatchDocument("RELEASED");
    firstSchool.school_name = "Trường A";
    firstSchool.school_display_order = 1;
    firstSchool.document_number = "PXK-A";

    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(
      await createGroupedSchoolDispatchXlsx([laterSchool, firstSchool]),
    );

    expect(workbook.worksheets).toHaveLength(2);
    expect(workbook.worksheets[0]!.getCell("A6").value).toContain("Trường A");
    expect(workbook.worksheets[1]!.getCell("A6").value).toContain("Trường B");
  });
});
