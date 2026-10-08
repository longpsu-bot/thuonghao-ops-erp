import type { Cell, Row, Workbook, Worksheet } from "exceljs";
import type { TDocumentDefinitions } from "pdfmake/interfaces";

export const documentFont = "Times New Roman";
export const companyName = "CÔNG TY TNHH MTV TM - DV THƯỢNG HẢO";
export const companyAddress =
  "ĐC: 96/3 KP. Thạnh Lợi, Phường Thuận An, Tp Hồ Chí Minh, Việt Nam";
export const releasedLabel = "ĐÃ PHÁT HÀNH — CHÍNH THỨC";
export const supersededLabel = "ĐÃ ĐƯỢC THAY THẾ — BẢN LƯU";

export function documentStatusLabel(status: string) {
  return status === "SUPERSEDED" ? supersededLabel : releasedLabel;
}

export function initializeDocumentWorkbook(
  workbook: Workbook,
  title: string,
  issuedAt = "2000-01-01T00:00:00Z",
) {
  workbook.creator = "Atlas · Thượng Hảo";
  workbook.title = title;
  workbook.created = new Date(issuedAt);
  workbook.modified = new Date(issuedAt);
}

export function borderRow(row: Row) {
  row.eachCell({ includeEmpty: true }, (cell) => {
    const side = { style: "thin" as const, color: { argb: "FF7F7F7F" } };
    cell.border = { top: side, left: side, bottom: side, right: side };
  });
}

export function formatExactDocumentQuantity(value: string) {
  if (!/^\d+(?:\.\d{1,6})?$/.test(value))
    throw new Error("Invalid exact document quantity.");
  const [whole, fraction = ""] = value.split(".");
  const meaningful = fraction.replace(/0+$/, "");
  return {
    text: meaningful ? `${whole}.${meaningful}` : whole!,
    precisionException: meaningful.length > 2,
  };
}

export function setExactQuantity(cell: Cell, value: string) {
  const printed = formatExactDocumentQuantity(value);
  cell.value = printed.text;
  if (printed.precisionException)
    cell.note = `PRECISION_EXCEPTION: ${value} requires more than two decimal places; retained exactly for Product review.`;
  cell.font = { name: documentFont, size: 12 };
  cell.numFmt = "@";
  cell.alignment = { vertical: "middle", horizontal: "right", wrapText: false };
}

export function prepareDocumentSheet(
  sheet: Worksheet,
  orientation: "portrait" | "landscape" = "portrait",
) {
  sheet.views = [{ showGridLines: false }];
  sheet.pageSetup = {
    paperSize: 9,
    orientation,
    fitToPage: true,
    fitToWidth: 1,
    fitToHeight: 0,
    margins: {
      left: 0.3,
      right: 0.3,
      top: 0.4,
      bottom: 0.5,
      header: 0.15,
      footer: 0.2,
    },
  };
  sheet.properties.defaultRowHeight = 20;
}

// ponytail: conservative character-width estimate; use measured font advances if native QA exposes clipping.
// Print allowance; explicit newlines and long tokens both consume lines.
export function wrappedRowHeight(
  value: string | null,
  width: number,
  size = 12,
  minimum = 30,
) {
  const capacity = Math.max(1, Math.floor((width * 5.25 - 6) / (size * 0.55)));
  const lines = (value ?? "")
    .split(/\r?\n/)
    .reduce(
      (sum, line) => sum + Math.max(1, Math.ceil(line.length / capacity)),
      0,
    );
  return Math.max(minimum, lines * (size + 3) + 8);
}

export function applyDocumentFont(sheet: Worksheet, size = 12) {
  sheet.eachRow((row) =>
    row.eachCell((cell) => {
      cell.font = { name: documentFont, size, ...cell.font };
      cell.alignment = {
        vertical: "middle",
        wrapText: true,
        ...cell.alignment,
      };
    }),
  );
}

export function finishDocumentSheet(
  sheet: Worksheet,
  lastColumn: string,
  headerEnd: number,
  identity: string,
) {
  sheet.pageSetup.printArea = `A1:${lastColumn}${sheet.rowCount}`;
  sheet.pageSetup.printTitlesRow = `1:${headerEnd}`;
  sheet.views = [{ state: "frozen", ySplit: headerEnd, showGridLines: false }];
  sheet.headerFooter.oddFooter = `&"Times New Roman,Regular"&8&L${identity.replaceAll("&", "&&")}&R&P / &N`;
  sheet.headerFooter.evenFooter = sheet.headerFooter.oddFooter;
  // Excel paginates bounded physical rows using the installed font and print
  // scaling. Manual height guesses waste paper and drift from native layout.
}

export function safeWorksheetName(value: string, used = new Set<string>()) {
  const stem =
    value
      .replace(/[\u0000-\u001f\\/*?:[\]]/g, " ")
      .trim()
      .replace(/^'+|'+$/g, "")
      .slice(0, 31)
      .replace(/'+$/g, "") || "Document";
  let name = stem,
    suffix = 2;
  while (used.has(name.toLowerCase())) {
    const tail = ` ${suffix++}`;
    name = stem.slice(0, 31 - tail.length) + tail;
  }
  used.add(name.toLowerCase());
  return name;
}

export function documentFilePart(value: string) {
  return (
    value
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/đ/gi, "d")
      .replace(/[^a-zA-Z0-9]+/g, "-")
      .replace(/^-|-$/g, "")
      .slice(0, 100) || "Atlas"
  );
}

export async function createDocumentZip(
  files: { name: string; bytes: ArrayBuffer | Uint8Array }[],
) {
  if (!files.length) throw new Error("No released documents to package.");
  const { default: JSZip } = await import("jszip");
  const zip = new JSZip();
  for (const file of files) {
    if (zip.file(file.name)) throw new Error("Duplicate document filename.");
    zip.file(file.name, file.bytes, { date: new Date("2000-01-01T00:00:00Z") });
  }
  return zip.generateAsync({ type: "uint8array", compression: "DEFLATE" });
}

export function documentPdfFooter(
  identity: string,
): TDocumentDefinitions["footer"] {
  return (page, pages) => ({
    columns: [
      { text: identity },
      { text: `${page} / ${pages}`, alignment: "right" },
    ],
    fontSize: 8,
    margin: [28, 12, 28, 0],
  });
}

export async function renderDocumentPdf(definition: TDocumentDefinitions) {
  const [pdfMake, pdfFonts] = await Promise.all([
    import("pdfmake/build/pdfmake"),
    import("pdfmake/build/vfs_fonts"),
  ]);
  const fontModule = pdfFonts as unknown as {
    default?: Record<string, string>;
    vfs?: Record<string, string>;
  };
  const virtualFonts = fontModule.default ?? fontModule.vfs;
  if (!virtualFonts) throw new Error("PDF font assets are unavailable.");
  return new Promise<Uint8Array>((resolve, reject) => {
    try {
      pdfMake
        .createPdf(definition, undefined, undefined, virtualFonts)
        .getBuffer((buffer) => resolve(new Uint8Array(buffer)));
    } catch (error) {
      reject(error);
    }
  });
}
