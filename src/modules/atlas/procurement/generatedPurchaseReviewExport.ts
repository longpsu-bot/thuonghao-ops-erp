import type { Row, Worksheet } from "exceljs";
import type {
  GeneratedPurchaseReview,
  GeneratedPurchaseReviewRow,
} from "./purchaseReviewApi";
import { downloadBytes } from "./purchaseOrderExports";

export function generatedSupplierLabel(row: GeneratedPurchaseReviewRow) {
  if (!row.recommendation) return "Chưa xác định NCC";
  return (
    row.eligible_suppliers.find(
      (supplier) => supplier.supplier_id === row.recommendation?.supplier_id,
    )?.supplier_name ?? "Chưa xác định NCC"
  );
}
export function generatedReviewWarning(code: string) {
  return (
    (
      {
        NO_ELIGIBLE_SUPPLIER: "Chưa có NCC đủ điều kiện.",
        NO_PRIORITIZED_SUPPLIER: "Chưa có thứ tự ưu tiên NCC.",
        AMBIGUOUS_SUPPLIER_PRIORITY:
          "Các NCC đồng ưu tiên; cần kiểm tra thủ công.",
      } as Record<string, string>
    )[code] ?? "Cần kiểm tra đề xuất nhà cung ứng."
  );
}
const scale = 1_000_000n;
function quantity(value: string) {
  const [whole, fraction = ""] = value.split(".");
  return BigInt(whole!) * scale + BigInt(fraction.padEnd(6, "0"));
}
function exact(value: bigint) {
  return `${value / scale}.${String(value % scale).padStart(6, "0")}`;
}
function groupBy<T>(rows: T[], key: (row: T) => string) {
  const groups = new Map<string, T[]>();
  for (const row of rows) {
    const id = key(row);
    const group = groups.get(id) ?? [];
    group.push(row);
    groups.set(id, group);
  }
  return [...groups.values()];
}
function border(row: Row, columns: number, shaded = false) {
  for (let column = 1; column <= columns; column++) {
    const cell = row.getCell(column);
    cell.font = { name: "Times New Roman", size: 14 };
    cell.alignment = { vertical: "middle", wrapText: true };
    cell.border = {
      top: { style: "thin", color: { argb: "FF000000" } },
      bottom: { style: "thin", color: { argb: "FF000000" } },
      left: { style: "thin", color: { argb: "FF000000" } },
      right: { style: "thin", color: { argb: "FF000000" } },
    };
    if (shaded)
      cell.fill = {
        type: "pattern",
        pattern: "solid",
        fgColor: { argb: "FFF2F2F2" },
      };
  }
  row.height = 44;
}
function band(
  sheet: Worksheet,
  columns: number,
  label: string,
  supplier = false,
) {
  const row = sheet.addRow([label]);
  border(row, columns);
  sheet.mergeCells(row.number, 1, row.number, columns);
  row.getCell(1).font = { name: "Times New Roman", size: 14, bold: true };
  row.getCell(1).fill = {
    type: "pattern",
    pattern: "solid",
    fgColor: { argb: supplier ? "FFE8E8E8" : "FFDCDCDC" },
  };
  row.height = label.length > 70 ? 44 : 28;
}

// Print geometry follows Retool v1 lib/js_exportPOZip.js (2026-02-27 snapshot).
// This is a single review workbook, not its official per-supplier PO ZIP.
function prepare(
  sheet: Worksheet,
  widths: number[],
  review: GeneratedPurchaseReview,
  detail: boolean,
) {
  const end = detail ? "G" : "F";
  widths.forEach((width, index) => {
    sheet.getColumn(index + 1).width = width;
  });
  sheet.properties.defaultRowHeight = 20;
  sheet.views = [{ state: "frozen", ySplit: 9, showGridLines: false }];
  sheet.pageSetup = {
    paperSize: 9,
    orientation: "portrait",
    fitToPage: true,
    fitToWidth: 1,
    fitToHeight: 0,
    margins: {
      left: 0.3,
      right: 0.3,
      top: 0.4,
      bottom: 0.5,
      header: 0.2,
      footer: 0.2,
    },
    printTitlesRow: "1:9",
  };
  sheet.headerFooter.oddFooter = `&C${review.document_label}&R&P / &N`;
  const companyColumn = detail ? "B" : "C";
  sheet.mergeCells(`${companyColumn}1:${end}1`);
  sheet.getCell(`${companyColumn}1`).value =
    "CÔNG TY TNHH MTV TM - DV THƯỢNG HẢO";
  sheet.getCell(`${companyColumn}1`).font = {
    name: "Times New Roman",
    size: 14,
    bold: true,
  };
  sheet.getCell(`${companyColumn}1`).alignment = {
    horizontal: "center",
    vertical: "middle",
    wrapText: true,
  };
  sheet.getRow(1).height = 40;
  sheet.mergeCells(`${companyColumn}2:${end}2`);
  sheet.getCell(`${companyColumn}2`).value =
    "BẢN RÀ SOÁT NHU CẦU · ĐỀ XUẤT NHÀ CUNG ỨNG";
  sheet.getCell(`${companyColumn}2`).font = {
    name: "Times New Roman",
    size: 11,
  };
  sheet.getCell(`${companyColumn}2`).alignment = {
    horizontal: "center",
    wrapText: true,
  };
  sheet.getRow(2).height = 30;
  sheet.mergeCells(`A4:${end}4`);
  sheet.getCell("A4").value = review.document_label;
  sheet.getCell("A4").font = { name: "Times New Roman", size: 16, bold: true };
  sheet.getCell("A4").alignment = { horizontal: "center", vertical: "middle" };
  sheet.getRow(4).height = 30;
  sheet.mergeCells(`A5:${end}5`);
  sheet.getCell("A5").value =
    `Ngày phục vụ: ${review.service_date.split("-").reverse().join("/")}`;
  sheet.mergeCells(`A6:${end}6`);
  sheet.getCell("A6").value = detail
    ? "CHI TIẾT THEO TRƯỜNG / ĐIỂM GIAO"
    : "TỔNG HỢP THEO NCC ĐỀ XUẤT";
  sheet.mergeCells(`A7:${end}7`);
  sheet.getCell("A7").value =
    "Đề xuất chưa được lưu thành phân bổ. Không phải đơn mua chính thức.";
  sheet.mergeCells(`A8:${end}8`);
  sheet.getCell("A8").value =
    "Điều chỉnh thủ công: ghi vào phần trống / Ghi chú sau khi rà soát.";
  for (const index of [5, 6, 7, 8]) {
    sheet.getRow(index).height = index >= 7 ? 28 : 22;
    sheet.getCell(`A${index}`).font = {
      name: "Times New Roman",
      size: index >= 7 ? 11 : 12,
      bold: index === 6,
    };
    sheet.getCell(`A${index}`).alignment = {
      vertical: "middle",
      wrapText: true,
    };
  }
  const header = sheet.getRow(9);
  header.values = detail
    ? [
        "Trường / điểm giao",
        null,
        "STT",
        "Tên hàng",
        "Đơn vị",
        "Số lượng",
        null,
      ]
    : ["STT", "Mã hàng", "Tên hàng", "Đơn vị", "Số lượng", "Ghi chú"];
  border(header, widths.length);
  if (detail) {
    sheet.mergeCells("A9:B9");
    sheet.mergeCells("F9:G9");
  }
  header.eachCell((cell) => {
    cell.font = { name: "Times New Roman", size: 12, bold: true };
    cell.alignment = {
      horizontal: "center",
      vertical: "middle",
      wrapText: true,
    };
  });
}

export async function createGeneratedPurchaseReviewXlsx(
  review: GeneratedPurchaseReview,
) {
  if (
    review.contract_version !== "PURCHASE-REVIEW.v1" ||
    review.document_label !== "DỰ KIẾN — CHƯA XÁC NHẬN" ||
    review.blockers.length > 0 ||
    review.rows.some(
      (row) =>
        row.service_date !== review.service_date ||
        !/^\d+(\.\d{1,6})?$/.test(row.family_quantity),
    )
  ) {
    throw new Error(
      "A current generated purchase-review read model is required.",
    );
  }
  const ExcelJS = (await import("exceljs")).default;
  const workbook = new ExcelJS.Workbook();
  workbook.creator = "Atlas · Thượng Hảo";
  workbook.title = `Bản dự kiến · ${review.service_date}`;
  const summary = workbook.addWorksheet("Tổng");
  const detail = workbook.addWorksheet("Chi tiết");
  prepare(summary, [7, 12, 36, 9, 18, 20], review, false);
  prepare(detail, [15, 13, 8, 34, 11, 12, 12], review, true);
  const suppliers = groupBy(
    review.rows,
    (row) => row.recommendation?.supplier_id ?? "unresolved",
  ).sort((a, b) =>
    generatedSupplierLabel(a[0]!).localeCompare(
      generatedSupplierLabel(b[0]!),
      "vi",
    ),
  );
  for (const rows of suppliers) {
    const supplier = `NCC đề xuất: ${generatedSupplierLabel(rows[0]!)}`;
    band(summary, 6, supplier, true);
    band(detail, 7, supplier, true);
    const warnings = [...new Set(rows.flatMap((row) => row.warnings))]
      .map(generatedReviewWarning)
      .join(" ");
    if (warnings) {
      band(summary, 6, warnings);
      band(detail, 7, warnings);
    }
    const ingredients = groupBy(
      rows,
      (row) => `${row.ingredient_id}:${row.unit_id}`,
    );
    ingredients.forEach((items, index) => {
      const first = items[0]!;
      const total = exact(
        items.reduce((sum, item) => sum + quantity(item.family_quantity), 0n),
      );
      // No business item code in this read contract: leave its v1 column blank.
      const row = summary.addRow([
        index + 1,
        null,
        first.ingredient_name,
        first.unit_code,
        total,
        null,
      ]);
      border(row, 6, index % 2 === 1);
      row.getCell(5).alignment = {
        horizontal: "right",
        vertical: "middle",
        wrapText: true,
      };
      row.getCell(5).numFmt = "@";
      row.getCell(5).note =
        "Exact generated quantity; text preserves six decimal places without Excel rounding.";
    });
    for (const schoolRows of groupBy(
      rows,
      (row) => `${row.school_id}:${row.delivery_location_id}`,
    )) {
      const first = schoolRows[0]!;
      band(
        detail,
        7,
        `${first.school_name ?? "Trường chưa xác định"} · ${first.location_name}`,
      );
      schoolRows.forEach((item, index) => {
        const row = detail.addRow([
          null,
          null,
          index + 1,
          item.ingredient_name,
          item.unit_code,
          item.family_quantity,
          null,
        ]);
        border(row, 7, index % 2 === 1);
        detail.mergeCells(row.number, 6, row.number, 7);
        row.getCell(6).numFmt = "@";
        row.getCell(6).alignment = {
          horizontal: "right",
          vertical: "middle",
          wrapText: true,
        };
      });
      band(
        detail,
        7,
        "Điều chỉnh thủ công: ______________________________________________",
      );
      detail.addRow([]).height = 10;
    }
    summary.addRow([]).height = 10;
  }
  for (const sheet of [summary, detail]) {
    const end = sheet === summary ? "F" : "G";
    band(
      sheet,
      sheet === summary ? 6 : 7,
      "Người rà soát: ____________________    Ngày: ____________",
    );
    sheet.pageSetup.printArea = `A1:${end}${sheet.rowCount}`;
  }
  return workbook.xlsx.writeBuffer();
}

export async function downloadGeneratedPurchaseReview(
  review: GeneratedPurchaseReview,
) {
  const bytes = await createGeneratedPurchaseReviewXlsx(review);
  downloadBytes(
    bytes,
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    `ban-du-kien-${review.service_date}.xlsx`,
  );
}
