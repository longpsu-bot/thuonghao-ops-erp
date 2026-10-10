import type { PlanningSchool } from "../planning-inputs/planningInputsModel";
import { downloadBytes } from "../procurement/purchaseOrderExports";
import {
  applyDocumentFont,
  borderRow,
  companyName,
  finishDocumentSheet,
  initializeDocumentWorkbook,
  prepareDocumentSheet,
  wrappedRowHeight,
} from "./documentPresentation";

export async function createAttendanceImportTemplate(
  weekStart: string,
  schools: PlanningSchool[],
) {
  const ExcelJS = (await import("exceljs")).default;
  const workbook = new ExcelJS.Workbook();
  initializeDocumentWorkbook(workbook, `Mẫu nhập sĩ số · ${weekStart}`);
  const sheet = workbook.addWorksheet("Nhập sĩ số");
  prepareDocumentSheet(sheet);
  const headings = [
    companyName,
    "SĨ SỐ — MẪU NHẬP",
    "MẪU NHẬP — CHƯA LƯU",
    `Tuần bắt đầu: ${weekStart} · Ngày nhập: YYYY-MM-DD`,
    "Ô trống là chưa có dữ liệu; 0 là số suất bằng 0. Nhập tệp hoặc dán hàng, rà soát rồi Lưu tại Atlas.",
  ];
  headings.forEach((label, index) => {
    const row = sheet.getRow(index + 1);
    sheet.mergeCells(index + 1, 1, index + 1, 4);
    row.getCell(1).value = label;
    row.getCell(1).font = {
      name: "Times New Roman",
      size: index === 1 ? 18 : 12,
      bold: index < 3,
    };
    row.height = wrappedRowHeight(label, 104, 12);
  });
  sheet.getRow(6).values = [
    "Mã trường",
    "Ngày",
    "Số suất học sinh",
    "Số suất giáo viên",
  ];
  sheet.getRow(6).font = { name: "Times New Roman", size: 12, bold: true };
  sheet.getRow(6).height = 36;
  borderRow(sheet.getRow(6));
  [22, 24, 29, 29].forEach(
    (width, index) => (sheet.getColumn(index + 1).width = width),
  );
  for (let r = 7; r <= 30; r++) {
    const row = sheet.getRow(r);
    row.height = 30;
    for (let c = 1; c <= 4; c++) {
      const cell = row.getCell(c);
      cell.value = null;
      cell.numFmt = c <= 2 ? "@" : "0";
      cell.alignment = { horizontal: c <= 2 ? "left" : "right" };
      if (c >= 3)
        cell.dataValidation = {
          type: "whole",
          operator: "greaterThanOrEqual",
          allowBlank: true,
          formulae: [0],
          showErrorMessage: true,
          error: "Nhập số suất nguyên từ 0 trở lên.",
        };
    }
    borderRow(row);
  }
  applyDocumentFont(sheet);
  finishDocumentSheet(sheet, "D", 6, "MẪU NHẬP — CHƯA LƯU");
  const reference = workbook.addWorksheet("Mã trường");
  prepareDocumentSheet(reference);
  reference.addRow(["Mã trường", "Tên trường"]);
  reference.getRow(1).font = { name: "Times New Roman", size: 12, bold: true };
  reference.getColumn(1).width = 22;
  reference.getColumn(2).width = 68;
  for (const school of [...schools]
    .filter((s) => s.school_status === "ACTIVE")
    .sort(
      (a, b) =>
        a.display_order - b.display_order ||
        a.school_id.localeCompare(b.school_id),
    )) {
    const row = reference.addRow([school.school_code, school.school_name]);
    row.height = wrappedRowHeight(school.school_name, 68);
    borderRow(row);
  }
  applyDocumentFont(reference);
  finishDocumentSheet(
    reference,
    "B",
    1,
    "THAM KHẢO MÃ TRƯỜNG — KHÔNG PHẢI SĨ SỐ ĐÃ LƯU",
  );
  return workbook.xlsx.writeBuffer();
}

export async function downloadAttendanceImportTemplate(
  weekStart: string,
  schools: PlanningSchool[],
) {
  downloadBytes(
    await createAttendanceImportTemplate(weekStart, schools),
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    `SiSo_MauNhap_${weekStart}.xlsx`,
  );
}
