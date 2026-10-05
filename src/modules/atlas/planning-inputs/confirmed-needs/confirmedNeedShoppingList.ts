import ExcelJS from "exceljs";
import {
  normalizeConfirmedNeedQuantity,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedWorkbenchData,
} from "./confirmedNeedModel";
import {
  shoppingAssert,
  shoppingListContract as contract,
  uuidPattern,
  validServiceDate,
} from "./shoppingListContract";
import { shoppingListPages, shoppingListRowHeight } from "./shoppingListLayout";
import {
  packageText,
  readShoppingListPackage,
  setPackageText,
  writeShoppingListPackage,
} from "./shoppingListPackage";
export {
  parseConfirmedNeedShoppingListXlsx,
  readShoppingListEnvelope,
  validateShoppingListEnvelope,
} from "./shoppingListImport";
export type ConfirmedNeedShoppingListImport = {
  drafts: Record<string, ConfirmedNeedDraftLine>;
  changedLineIds: string[];
};
export type ShoppingListDailyBatch = {
  workbench: ConfirmedNeedWorkbenchData;
  supplierAdvice: Record<string, string>;
};
export function shoppingListDateTitle(date: string) {
  const days = [
    "Chủ Nhật",
    "Thứ Hai",
    "Thứ Ba",
    "Thứ Tư",
    "Thứ Năm",
    "Thứ Sáu",
    "Thứ Bảy",
  ];
  return `${days[new Date(`${date}T00:00:00Z`).getUTCDay()]} (${date.split("-").reverse().join("/")})`;
}
export function savedShoppingListQuantity(
  line: ConfirmedNeedWorkbenchData["lines"][number],
) {
  const q = line.confirmed_quantity_after ?? line.proposed_confirmed_quantity;
  shoppingAssert(normalizeConfirmedNeedQuantity(q) === q, "INVALID_AUTHORITY");
  return q;
}
export function shortestShoppingListQuantity(q: string) {
  return q.includes(".") ? q.replace(/0+$/, "").replace(/\.$/, "") : q;
}
function orderedLines(workbench: ConfirmedNeedWorkbenchData) {
  const groups = new Map<string, ConfirmedNeedWorkbenchData["lines"]>();
  for (const line of workbench.lines) {
    const group = groups.get(line.school.id) ?? [];
    group.push(line);
    groups.set(line.school.id, group);
  }
  return [...groups.values()].flat();
}
function validateExport(batch: ShoppingListDailyBatch) {
  const b = batch.workbench,
    date = b.service_period.period_start;
  shoppingAssert(
    validServiceDate(date) &&
      b.service_period.period_end === date &&
      b.lines.length > 0 &&
      !b.pagination.has_more &&
      b.pagination.offset === 0 &&
      b.pagination.total_lines === b.lines.length &&
      b.line_counts.total === b.lines.length,
    "INCOMPLETE_AUTHORITY",
  );
  shoppingAssert(
    b.source_kind === "NEED_GENERATION" &&
      b.lines.every(
        (l) => l.service_date === date && !l.source_stale && !l.blockers.length,
      ) &&
      !b.blockers.length,
    "STALE_AUTHORITY",
  );
  shoppingAssert(
    [
      b.confirmed_need_batch_id,
      b.need_generation_source.run_id,
      b.need_generation_source.release_snapshot_id,
    ].every((id) => uuidPattern.test(id)) &&
      Number.isSafeInteger(b.batch_version) &&
      b.batch_version > 0,
  );
  const seen = new Set<string>(),
    visible = new Map<string, string>();
  for (const l of b.lines) {
    shoppingAssert(
      [
        l.confirmed_need_line_id,
        l.current_revision_id,
        l.school.id,
        l.delivery_location.id,
        l.ingredient.id,
        l.controlled_unit.id,
      ].every((id) => uuidPattern.test(id)) &&
        (!l.current_decision_id || uuidPattern.test(l.current_decision_id)) &&
        !seen.has(l.confirmed_need_line_id),
    );
    seen.add(l.confirmed_need_line_id);
    shoppingAssert(
      l.school.name.trim() &&
        l.ingredient.name.trim() &&
        l.controlled_unit.name.trim() &&
        !/^v1-unit-/i.test(l.controlled_unit.name) &&
        l.controlled_unit.status === "ACTIVE",
      "INVALID_UNIT_DISPLAY",
    );
    shoppingAssert(
      Object.hasOwn(batch.supplierAdvice, l.confirmed_need_line_id) &&
        typeof batch.supplierAdvice[l.confirmed_need_line_id] === "string",
      "MISSING_SUPPLIER_READ",
    );
    const key = JSON.stringify([
        l.school.name,
        l.ingredient.name,
        l.controlled_unit.name,
      ]),
      identity = JSON.stringify([
        l.school.id,
        l.ingredient.id,
        l.controlled_unit.id,
      ]);
    shoppingAssert(
      !visible.has(key) || visible.get(key) === identity,
      "AMBIGUOUS_DISPLAY",
    );
    visible.set(key, identity);
  }
}
export async function createConfirmedNeedShoppingListXlsx(
  batches: ShoppingListDailyBatch[],
  exportedAt = new Date(),
  workbookMarker = crypto.randomUUID(),
) {
  shoppingAssert(
    batches.length >= 1 &&
      batches.length <= contract.maxServiceDates &&
      uuidPattern.test(workbookMarker),
  );
  batches.forEach(validateExport);
  const sorted = [...batches].sort((a, b) =>
    a.workbench.service_period.period_start.localeCompare(
      b.workbench.service_period.period_start,
    ),
  );
  const dates = sorted.map((b) => b.workbench.service_period.period_start);
  shoppingAssert(
    new Set(dates).size === dates.length &&
      new Set(sorted.map((b) => b.workbench.confirmed_need_batch_id)).size ===
        dates.length,
  );
  shoppingAssert(
    sorted.reduce((n, b) => n + b.workbench.lines.length, 0) <=
      contract.resourceLimits.dataLines,
    "RESOURCE_LIMIT",
  );
  const workbook = new ExcelJS.Workbook();
  workbook.creator = "OPS ERP - Project Atlas";
  workbook.created = exportedAt;
  const p = contract.print;
  for (const batch of sorted) {
    const b = batch.workbench,
      date = b.service_period.period_start,
      lines = orderedLines(b),
      end = lines.length + 3;
    const sheet = workbook.addWorksheet(date, {
      views: [{ showGridLines: false, state: "frozen", ySplit: 3 }],
      pageSetup: {
        paperSize: 9,
        orientation: "portrait",
        scale: p.scalePercent,
        fitToPage: false,
        printArea: `A1:E${end}`,
        printTitlesRow: "1:3",
        margins: {
          left: p.leftMarginIn,
          right: p.rightMarginIn,
          top: p.topMarginIn,
          bottom: p.bottomMarginIn,
          header: 0.12,
          footer: 0.12,
        },
      },
    });
    sheet.columns = [
      ...p.columnWidths.map((width) => ({ width })),
      ...contract.hiddenHeaders.map(() => ({ width: 1, hidden: true })),
    ];
    sheet.mergeCells("A1:E1");
    const title = sheet.getCell("A1");
    title.value = shoppingListDateTitle(date);
    title.font = { name: contract.font, size: p.titleFontPt, bold: true };
    title.alignment = { horizontal: "center", vertical: "middle" };
    sheet.getRow(1).height = p.titleRowPt;
    sheet.getRow(2).height = p.spacerRowPt;
    let previous: string | null = null;
    const rows = lines.map((line) => {
      const q = savedShoppingListQuantity(line),
        supplier = batch.supplierAdvice[line.confirmed_need_line_id]!;
      const first = previous !== line.school.id;
      previous = line.school.id;
      return {
        line,
        q,
        supplier,
        first,
        height: shoppingListRowHeight(
          line.school.name,
          line.ingredient.name,
          line.controlled_unit.name,
          shortestShoppingListQuantity(q),
          supplier,
          false,
          first,
        ),
      };
    });
    const pages = shoppingListPages(
      rows.map((r) => ({ schoolId: r.line.school.id, height: r.height })),
    );
    sheet.addTable({
      name: `AtlasNeed_${date.replaceAll("-", "")}`,
      ref: "A3",
      headerRow: true,
      totalsRow: false,
      style: {
        theme: "TableStyleLight1",
        showRowStripes: false,
        showColumnStripes: false,
      },
      columns: [...contract.visibleHeaders, ...contract.hiddenHeaders].map(
        (name) => ({ name, filterButton: false }),
      ),
      rows: rows.map((r, i) => [
        r.first
          ? r.line.school.name
          : pages.continuations.has(i)
            ? `${r.line.school.name} (tiếp)`
            : null,
        r.line.ingredient.name,
        r.line.controlled_unit.name,
        shortestShoppingListQuantity(r.q),
        r.supplier,
        workbookMarker,
        r.line.confirmed_need_line_id,
        r.line.current_revision_id,
        r.line.current_decision_id ?? "",
        date,
        r.line.school.id,
        r.line.delivery_location.id,
        r.line.ingredient.id,
        r.line.controlled_unit.id,
        r.q,
      ]),
    });
    const header = sheet.getRow(3);
    header.height = p.headerRowPt;
    header.font = { name: contract.font, size: p.headerFontPt, bold: true };
    header.alignment = {
      horizontal: "center",
      vertical: "middle",
      wrapText: true,
    };
    sheet.getCell("C3").alignment = {
      horizontal: "center",
      vertical: "middle",
      wrapText: false,
    };
    rows.forEach((r, i) => {
      const continued = pages.continuations.has(i);
      const row = sheet.getRow(i + 4);
      row.height = continued
        ? shoppingListRowHeight(
            r.line.school.name,
            r.line.ingredient.name,
            r.line.controlled_unit.name,
            shortestShoppingListQuantity(r.q),
            r.supplier,
            true,
          )
        : r.height;
      row.font = { name: contract.font, size: p.bodyFontPt };
      row.alignment = { vertical: "middle", wrapText: true };
      row.getCell(1).font = {
        name: contract.font,
        size: p.schoolFontPt,
        bold: true,
      };
      row.getCell(3).alignment = {
        horizontal: "center",
        vertical: "middle",
        wrapText: false,
      };
      row.getCell(4).alignment = {
        horizontal: "right",
        vertical: "middle",
        wrapText: false,
      };
      row.getCell(4).font = { name: contract.font, size: p.quantityFontPt };
      row.getCell(5).font = { name: contract.font, size: p.supplierFontPt };
      // Native Excel SaveAs can rewrite even <=15-digit decimal numerics.
      // Text preserves the exact value; imported numeric edits still use raw XML.
      row.getCell(4).numFmt = "@";
      row.getCell(4).protection = { locked: false };
      row.getCell(5).protection = { locked: false };
      for (let c = 1; c <= 15; c++) {
        const cell = row.getCell(c);
        if (c >= 6) cell.numFmt = "@";
        if (c <= 5)
          cell.border = {
            top: {
              style: r.first || continued ? "medium" : "thin",
              color: { argb: "FF000000" },
            },
            left: {
              style: c === 1 ? "medium" : "thin",
              color: { argb: "FF000000" },
            },
            right: {
              style: c === 5 ? "medium" : "thin",
              color: { argb: "FF000000" },
            },
            bottom: {
              style: i === rows.length - 1 ? "medium" : "thin",
              color: { argb: "FF000000" },
            },
          };
      }
    });
    for (let c = 1; c <= 5; c++)
      sheet.getCell(3, c).border = {
        top: { style: "medium" },
        bottom: { style: "medium" },
        left: { style: "thin" },
        right: { style: "thin" },
      };
    pages.breaks.forEach((r) => sheet.getRow(r).addPageBreak());
    await sheet.protect(contract.protectionPassword, {
      selectLockedCells: true,
      selectUnlockedCells: true,
      autoFilter: true,
      sort: false,
      spinCount: 1000,
    });
  }
  const meta = workbook.addWorksheet(contract.metadataSheet, {
    state: "veryHidden",
  });
  const values = [
    contract.contractName,
    contract.contractVersion,
    workbookMarker,
    exportedAt.toISOString(),
    dates[0]!,
    dates.at(-1)!,
  ];
  contract.metadataKeys.forEach((key, i) => {
    meta.getCell(i + 1, 1).value = key;
    meta.getCell(i + 1, 2).value = values[i]!;
  });
  meta.getRow(8).values = [...contract.dailyKeys];
  sorted.forEach(({ workbench: b }, i) => {
    meta.getRow(i + 9).values = [
      b.service_period.period_start,
      b.confirmed_need_batch_id,
      String(b.batch_version),
      b.need_generation_source.run_id,
      b.need_generation_source.release_snapshot_id,
    ];
  });
  await meta.protect(contract.protectionPassword, { spinCount: 1000 });
  const files = await readShoppingListPackage(
    new Uint8Array(await workbook.xlsx.writeBuffer()),
  );
  // Preserve the approved specimen's Normal style: Excel also uses it for
  // printed column geometry. Every populated visible cell has its own TNR font.
  setPackageText(
    files,
    "xl/styles.xml",
    packageText(files, "xl/styles.xml").replace(
      /(<fonts\b[^>]*>)<font>[\s\S]*?<\/font>/,
      '$1<font><sz val="11"/><color rgb="FF000000"/><name val="Carlito"/></font>',
    ),
  );
  for (let i = 1; i <= sorted.length; i++) {
    const tablePath = `xl/tables/table${i}.xml`;
    setPackageText(
      files,
      tablePath,
      packageText(files, tablePath).replace(
        /totalsRowShown="1"/,
        'totalsRowShown="0"',
      ),
    );
  }
  let wb = packageText(files, "xl/workbook.xml");
  wb = wb.replace(
    /<sheets>/,
    '<workbookProtection lockStructure="1"/><sheets>',
  );
  setPackageText(files, "xl/workbook.xml", wb);
  return writeShoppingListPackage(files).buffer as ArrayBuffer;
}
export async function downloadConfirmedNeedShoppingList(
  batches: ShoppingListDailyBatch[],
) {
  const bytes = await createConfirmedNeedShoppingListXlsx(batches),
    dates = batches.map((b) => b.workbench.service_period.period_start).sort();
  const url = URL.createObjectURL(
    new Blob([bytes as BlobPart], {
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    }),
  );
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `PhieuDiCho_${dates[0]}_${dates.at(-1)}_ATLAS_V1.xlsx`;
  anchor.click();
  URL.revokeObjectURL(url);
}
