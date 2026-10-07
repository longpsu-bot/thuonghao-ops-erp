import {
  confirmedNeedInputDisplay,
  confirmedNeedQuantityMatchesStep,
  exactDecimalEqual,
  normalizeConfirmedNeedEntry,
  normalizeConfirmedNeedQuantity,
  confirmedNeedDraftMatchesSaved,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedWorkbenchData,
} from "./confirmedNeedModel";
import type { ConfirmedNeedShoppingListImport } from "./confirmedNeedShoppingList";
import {
  savedShoppingListQuantity,
  shoppingListDateTitle,
} from "./confirmedNeedShoppingList";
import {
  ShoppingListError,
  shoppingAssert,
  shoppingListUnitDisplay,
  shoppingListContract as contract,
  uuidPattern,
  validServiceDate,
  shoppingListGeometries,
  type ShoppingListGeometry,
} from "./shoppingListContract";
import { shoppingListPages } from "./shoppingListLayout";
import {
  packageText,
  parsePackageXml,
  readShoppingListPackage,
  xmlElements,
  type ShoppingListPackage,
} from "./shoppingListPackage";

type Cell = { text: string; type: string };
type DailyRecord = {
  service_date: string;
  confirmed_need_batch_id: string;
  batch_version: number;
  need_generation_run_id: string;
  release_snapshot_id: string;
};
export type ShoppingListEnvelope = {
  marker: string;
  daily: DailyRecord[];
  sheets: Map<string, Cell[][]>;
  geometry: ShoppingListGeometry;
  heights: Map<string, number[]>;
  breaks: Map<string, number[]>;
};
const main = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
function internalTarget(base: string, target: string) {
  shoppingAssert(
    !target.includes("\\") &&
      !target.includes(":") &&
      !target.includes("?") &&
      !target.includes("#"),
  );
  const parts = (
    target.startsWith("/") ? target.slice(1) : `${base}/${target}`
  ).split("/");
  const out: string[] = [];
  for (const p of parts) {
    if (!p || p === ".") continue;
    if (p === "..") {
      shoppingAssert(out.length);
      out.pop();
    } else out.push(p);
  }
  return out.join("/");
}
function relationships(files: ShoppingListPackage, path: string, base: string) {
  const doc = parsePackageXml(packageText(files, path));
  const result = new Map<string, { path: string; type: string }>();
  for (const rel of xmlElements(doc, "Relationship")) {
    const id = rel.getAttribute("Id")!,
      target = rel.getAttribute("Target")!,
      type = rel.getAttribute("Type")!;
    shoppingAssert(
      id &&
        target &&
        type &&
        !result.has(id) &&
        rel.getAttribute("TargetMode") !== "External",
    );
    const resolved = internalTarget(base, target);
    shoppingAssert(files.has(resolved));
    result.set(id, { path: resolved, type });
  }
  return result;
}
function exactXmlNumber(text: string) {
  const match = /^(\d+)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$/.exec(text);
  if (!match) return null;
  const exponent = Number(match[3] ?? 0);
  if (!Number.isSafeInteger(exponent) || Math.abs(exponent) > 30) return null;
  const digits = match[1]! + (match[2] ?? ""),
    point = match[1]!.length + exponent;
  let decimal =
    point <= 0
      ? `0.${"0".repeat(-point)}${digits}`
      : point >= digits.length
        ? digits + "0".repeat(point - digits.length)
        : `${digits.slice(0, point)}.${digits.slice(point)}`;
  decimal = decimal.replace(/^0+(?=\d)/, "");
  if (decimal.includes("."))
    decimal = decimal.replace(/0+$/, "").replace(/\.$/, "");
  return normalizeConfirmedNeedQuantity(decimal);
}
function readCells(
  doc: Document,
  shared: string[],
  badQuantityStyles: Set<number>,
) {
  shoppingAssert(
    doc.documentElement.namespaceURI === main &&
      doc.documentElement.localName === "worksheet",
  );
  const cells = new Map<string, Cell>();
  shoppingAssert(
    !xmlElements(doc, "f").length &&
      !xmlElements(doc, "hyperlink").length &&
      !xmlElements(doc, "drawing").length,
  );
  for (const row of xmlElements(doc, "row")) {
    const rowId = Number(row.getAttribute("r"));
    shoppingAssert(
      Number.isSafeInteger(rowId) && rowId > 0 && rowId <= 1048576,
    );
    for (const cell of Array.from(row.children)) {
      shoppingAssert(cell.localName === "c");
      const address = cell.getAttribute("r")!,
        type = cell.getAttribute("t") ?? "n",
        style = Number(cell.getAttribute("s") ?? 0);
      shoppingAssert(
        /^[A-Z]+[1-9]\d*$/.test(address) &&
          Number(address.match(/\d+$/)![0]) === rowId &&
          !cells.has(address) &&
          Number.isSafeInteger(style),
      );
      const vs = xmlElements(cell, "v"),
        texts = xmlElements(cell, "t");
      shoppingAssert(vs.length <= 1);
      let text = "";
      if (type === "s") {
        const index = Number(vs[0]?.textContent);
        shoppingAssert(
          vs.length === 1 &&
            Number.isSafeInteger(index) &&
            index >= 0 &&
            index < shared.length,
        );
        text = shared[index]!;
      } else if (type === "inlineStr")
        text = texts.map((t) => t.textContent ?? "").join("");
      else if (type === "n") text = vs[0]?.textContent ?? "";
      else if (type === "str") text = vs[0]?.textContent ?? "";
      else if (
        address.startsWith("E") &&
        rowId >= 4 &&
        ["b", "e", "d"].includes(type)
      )
        text = vs[0]?.textContent ?? "";
      else shoppingAssert(false);
      if (
        address.startsWith("D") &&
        rowId >= 4 &&
        type === "n" &&
        text !== ""
      ) {
        shoppingAssert(!badQuantityStyles.has(style), "INVALID_QUANTITY");
        const normalized = exactXmlNumber(text);
        shoppingAssert(normalized, "INVALID_QUANTITY");
        text = normalized;
      }
      cells.set(address, { text, type });
    }
  }
  return cells;
}
function text(cells: Map<string, Cell>, address: string) {
  const cell = cells.get(address);
  shoppingAssert(!cell || cell.type !== "n" || cell.text === "");
  return cell?.text ?? "";
}
function allowCells(
  cells: Map<string, Cell>,
  allowed: (address: string) => boolean,
) {
  for (const [address, cell] of cells)
    shoppingAssert(!cell.text || allowed(address), "OUTSIDE_ENVELOPE");
}

export async function readShoppingListEnvelope(
  bytes: ArrayBuffer | Uint8Array,
): Promise<ShoppingListEnvelope> {
  try {
    const files = await readShoppingListPackage(bytes);
    const permitted =
      /^(?:\[Content_Types\]\.xml|_rels\/\.rels|docProps\/(?:app|core)\.xml|xl\/(?:workbook\.xml|styles\.xml|sharedStrings\.xml|calcChain\.xml|_rels\/workbook\.xml\.rels|theme\/theme\d+\.xml|worksheets\/sheet\d+\.xml|worksheets\/_rels\/sheet\d+\.xml\.rels|tables\/table\d+\.xml|printerSettings\/printerSettings\d+\.bin))$/;
    for (const [path, data] of files) {
      if (path.endsWith("/")) {
        shoppingAssert(!data.length);
        continue;
      }
      shoppingAssert(permitted.test(path), "UNSUPPORTED_PART");
      if (/\.(xml|rels)$/.test(path)) {
        const doc = parsePackageXml(new TextDecoder().decode(data));
        shoppingAssert(
          [
            "f",
            "calculatedColumnFormula",
            "totalsRowFormula",
            "formula1",
            "formula2",
          ].every((tag) => !xmlElements(doc, tag).length),
        );
        if (path.endsWith(".rels"))
          for (const rel of xmlElements(doc, "Relationship")) {
            shoppingAssert(
              rel.getAttribute("TargetMode") !== "External" &&
                !/externalLink|vbaProject|oleObject|image|drawing|customXml|control|signature/i.test(
                  rel.getAttribute("Type") ?? "",
                ),
            );
          }
      }
    }
    const contentTypes = parsePackageXml(
      packageText(files, "[Content_Types].xml"),
    );
    shoppingAssert(
      !xmlElements(contentTypes, "Override").some((e) =>
        /macroEnabled|vbaProject|externalLink/i.test(
          e.getAttribute("ContentType") ?? "",
        ),
      ),
    );
    const styles = parsePackageXml(packageText(files, "xl/styles.xml"));
    const formats = new Map(
      xmlElements(styles, "numFmt").map((e) => [
        Number(e.getAttribute("numFmtId")),
        e.getAttribute("formatCode") ?? "",
      ]),
    );
    const xfs = xmlElements(styles, "cellXfs")[0];
    shoppingAssert(xfs);
    const badStyles = new Set<number>();
    Array.from(xfs.children).forEach((xf, i) => {
      const id = Number(xf.getAttribute("numFmtId") ?? 0),
        format = formats.get(id) ?? "";
      if (
        (id >= 9 && id <= 22) ||
        (id >= 27 && id <= 36) ||
        (id >= 50 && id <= 58) ||
        (id >= 45 && id <= 47) ||
        /%|[ymdhis]|\[/i.test(format.replace(/"[^"]*"/g, ""))
      )
        badStyles.add(i);
    });
    const shared = files.has("xl/sharedStrings.xml")
      ? xmlElements(
          parsePackageXml(packageText(files, "xl/sharedStrings.xml")),
          "si",
        ).map((si) =>
          xmlElements(si, "t")
            .map((t) => t.textContent ?? "")
            .join(""),
        )
      : [];
    const wb = parsePackageXml(packageText(files, "xl/workbook.xml"));
    shoppingAssert(wb.documentElement.namespaceURI === main);
    const wbRels = relationships(files, "xl/_rels/workbook.xml.rels", "xl");
    const sheets = xmlElements(wb, "sheet");
    shoppingAssert(sheets.length >= 2 && sheets.length <= 8);
    const names = sheets.map((s) => s.getAttribute("name")!);
    shoppingAssert(
      new Set(names).size === names.length &&
        names.at(-1) === contract.metadataSheet,
    );
    const dates = names.slice(0, -1);
    shoppingAssert(
      dates.every(validServiceDate) &&
        dates.every((d, i) => i === 0 || d > dates[i - 1]!),
    );
    const documents = new Map<
      string,
      { doc: Document; path: string; cells: Map<string, Cell> }
    >();
    const representedPaths = new Set<string>();
    for (const sheet of sheets) {
      const name = sheet.getAttribute("name")!,
        rel = wbRels.get(
          sheet.getAttributeNS(
            "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
            "id",
          )!,
        );
      shoppingAssert(
        rel &&
          rel.type.endsWith("/worksheet") &&
          !representedPaths.has(rel.path),
      );
      representedPaths.add(rel.path);
      shoppingAssert(
        name === contract.metadataSheet
          ? sheet.getAttribute("state") === "veryHidden"
          : !sheet.getAttribute("state") ||
              sheet.getAttribute("state") === "visible",
      );
      const doc = parsePackageXml(packageText(files, rel.path));
      documents.set(name, {
        doc,
        path: rel.path,
        cells: readCells(doc, shared, badStyles),
      });
    }
    shoppingAssert(
      [...files.keys()].filter((p) => /^xl\/worksheets\/sheet\d+\.xml$/.test(p))
        .length === documents.size,
    );
    const meta = documents.get(contract.metadataSheet)!;
    shoppingAssert(!xmlElements(meta.doc, "tablePart").length);
    shoppingAssert(
      text(meta.cells, "B1") === contract.contractName &&
        text(meta.cells, "B2") === contract.contractVersion,
      "UNSUPPORTED_CONTRACT",
    );
    contract.metadataKeys.forEach((key, i) =>
      shoppingAssert(text(meta.cells, `A${i + 1}`) === key),
    );
    const marker = text(meta.cells, "B3"),
      exportedAt = text(meta.cells, "B4");
    const geometry = text(meta.cells, "B7") as ShoppingListGeometry;
    shoppingAssert(
      Object.hasOwn(shoppingListGeometries, geometry),
      "UNSUPPORTED_GEOMETRY",
    );
    shoppingAssert(
      uuidPattern.test(marker) &&
        /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/.test(
          exportedAt,
        ) &&
        Number.isFinite(Date.parse(exportedAt)),
    );
    shoppingAssert(
      text(meta.cells, "B5") === dates[0] &&
        text(meta.cells, "B6") === dates.at(-1),
    );
    contract.dailyKeys.forEach((key, c) =>
      shoppingAssert(
        text(meta.cells, `${String.fromCharCode(65 + c)}8`) === key,
      ),
    );
    const daily = dates.map((date, i) => {
      const values = [0, 1, 2, 3, 4].map((c) =>
        text(meta.cells, `${String.fromCharCode(65 + c)}${i + 9}`),
      );
      shoppingAssert(
        values[0] === date &&
          [values[1], values[3], values[4]].every((id) =>
            uuidPattern.test(id!),
          ) &&
          /^[1-9]\d*$/.test(values[2]!),
      );
      const version = Number(values[2]);
      shoppingAssert(Number.isSafeInteger(version));
      return {
        service_date: date,
        confirmed_need_batch_id: values[1]!,
        batch_version: version,
        need_generation_run_id: values[3]!,
        release_snapshot_id: values[4]!,
      };
    });
    shoppingAssert(
      new Set(daily.map((d) => d.confirmed_need_batch_id)).size ===
        daily.length,
    );
    allowCells(
      meta.cells,
      (address) =>
        /^[AB][1-7]$/.test(address) ||
        /^[A-E]8$/.test(address) ||
        (/^[A-E]\d+$/.test(address) &&
          Number(address.slice(1)) >= 9 &&
          Number(address.slice(1)) < 9 + dates.length),
    );
    const rowsByDate = new Map<string, Cell[][]>();
    const heights = new Map<string, number[]>(),
      breaks = new Map<string, number[]>();
    let total = 0;
    let dataTotal = 0;
    const tablePaths = new Set<string>();
    for (const date of dates) {
      const sheet = documents.get(date)!,
        parts = xmlElements(sheet.doc, "tablePart");
      shoppingAssert(parts.length === 1);
      const slash = sheet.path.lastIndexOf("/"),
        base = sheet.path.slice(0, slash),
        filename = sheet.path.slice(slash + 1);
      const rels = relationships(files, `${base}/_rels/${filename}.rels`, base);
      const rel = rels.get(
        parts[0]!.getAttributeNS(
          "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
          "id",
        )!,
      );
      shoppingAssert(
        rel && rel.type.endsWith("/table") && !tablePaths.has(rel.path),
      );
      tablePaths.add(rel.path);
      const table = parsePackageXml(
          packageText(files, rel.path),
        ).documentElement,
        name = `AtlasNeed_${date.replaceAll("-", "")}`;
      shoppingAssert(
        table.namespaceURI === main &&
          table.localName === "table" &&
          table.getAttribute("name") === name &&
          table.getAttribute("displayName") === name &&
          table.getAttribute("headerRowCount") !== "0" &&
          (!table.getAttribute("totalsRowCount") ||
            table.getAttribute("totalsRowCount") === "0"),
      );
      const range = /^A3:Q([4-9]|[1-9]\d+)$/.exec(
        table.getAttribute("ref") ?? "",
      );
      shoppingAssert(range);
      const end = Number(range[1]);
      shoppingAssert(
        xmlElements(sheet.doc, "mergeCell").every(
          (cell) => cell.getAttribute("ref") === "A1:E1",
        ),
        "MERGED_TABLE_CELLS",
      );
      total += end - 3;
      shoppingAssert(
        total <= contract.resourceLimits.dataLines * 3,
        "RESOURCE_LIMIT",
      );
      const headers = [...contract.visibleHeaders, ...contract.hiddenHeaders];
      const columns = xmlElements(table, "tableColumn");
      shoppingAssert(
        columns.length === headers.length &&
          columns.every((col, i) => col.getAttribute("name") === headers[i]),
      );
      headers.forEach((h, i) =>
        shoppingAssert(
          text(sheet.cells, `${String.fromCharCode(65 + i)}3`) === h,
        ),
      );
      shoppingAssert(text(sheet.cells, "A1") === shoppingListDateTitle(date));
      allowCells(
        sheet.cells,
        (address) =>
          address === "A1" ||
          (/^[A-Q]\d+$/.test(address) &&
            Number(address.slice(1)) >= 3 &&
            Number(address.slice(1)) <= end),
      );
      const rows: Cell[][] = [];
      for (let r = 4; r <= end; r++) {
        const cells = Array.from(
          { length: headers.length },
          (_, c) =>
            sheet.cells.get(`${String.fromCharCode(65 + c)}${r}`) ?? {
              text: "",
              type: "inlineStr",
            },
        );
        shoppingAssert(
          cells.every(
            (cell, c) =>
              c === 3 || c === 4 || cell.type !== "n" || cell.text === "",
          ),
        );
        rows.push(cells);
      }
      rowsByDate.set(date, rows);
      dataTotal += rows.filter((r) => r[15]?.text === "DATA_LINE").length;
      shoppingAssert(
        dataTotal <= contract.resourceLimits.dataLines,
        "RESOURCE_LIMIT",
      );
      const physicalRows = new Map(
        xmlElements(sheet.doc, "row").map((r) => [
          Number(r.getAttribute("r")),
          Number(r.getAttribute("ht")),
        ]),
      );
      heights.set(
        date,
        rows.map((_, i) => physicalRows.get(i + 4) ?? 0),
      );
      const rowBreaks = xmlElements(sheet.doc, "rowBreaks")[0];
      breaks.set(
        date,
        rowBreaks
          ? xmlElements(rowBreaks, "brk").map((r) =>
              Number(r.getAttribute("id")),
            )
          : [],
      );
    }
    shoppingAssert(
      [...files.keys()].filter((p) => /^xl\/tables\/table\d+\.xml$/.test(p))
        .length === tablePaths.size,
    );
    return { marker, daily, sheets: rowsByDate, geometry, heights, breaks };
  } catch (error) {
    if (error instanceof ShoppingListError && error.code !== "RESOURCE_LIMIT")
      throw error;
    throw new ShoppingListError(
      "IMPORT_FAILED",
      "Không thể đọc Phiếu đi chợ. Hãy chọn file XLSX V2 hợp lệ hoặc xuất một file mới.",
    );
  }
}
export function validateShoppingListEnvelope(
  envelope: ShoppingListEnvelope,
  batches: ConfirmedNeedWorkbenchData[],
  currentDrafts: Record<string, ConfirmedNeedDraftLine>,
): ConfirmedNeedShoppingListImport {
  shoppingAssert(batches.length === envelope.daily.length);
  const byBatch = new Map(batches.map((b) => [b.confirmed_need_batch_id, b]));
  shoppingAssert(byBatch.size === batches.length);
  const next = structuredClone(currentDrafts),
    changedLineIds: string[] = [],
    globalSeen = new Set<string>();
  for (const daily of envelope.daily) {
    const b = byBatch.get(daily.confirmed_need_batch_id);
    shoppingAssert(
      b &&
        b.batch_version === daily.batch_version &&
        b.need_generation_source.run_id === daily.need_generation_run_id &&
        b.need_generation_source.release_snapshot_id ===
          daily.release_snapshot_id &&
        b.service_period.period_start === daily.service_date &&
        b.service_period.period_end === daily.service_date,
      "STALE_AUTHORITY",
    );
    shoppingAssert(
      b.source_kind === "NEED_GENERATION" &&
        b.editing_allowed &&
        b.allowed_actions.save_confirmed_needs &&
        b.authoritative_batch_status !== "RELEASED_FOR_PURCHASE_HANDOFF" &&
        b.batch_status !== "RELEASED_FOR_PURCHASE_HANDOFF" &&
        !b.blockers.length &&
        !b.pagination.has_more &&
        b.pagination.offset === 0 &&
        b.pagination.total_lines === b.lines.length &&
        b.line_counts.total === b.lines.length,
      "INELIGIBLE_AUTHORITY",
    );
    const rows = envelope.sheets.get(daily.service_date)!;
    shoppingAssert(
      rows.filter((c) => c[15]?.text === "DATA_LINE").length === b.lines.length,
      "LINE_SET_MISMATCH",
    );
    const byLine = new Map(b.lines.map((l) => [l.confirmed_need_line_id, l]));
    shoppingAssert(byLine.size === b.lines.length);
    const schools = new Map(b.lines.map((l) => [l.school.id, l.school.name]));
    const seen = new Set<string>(),
      labelledSchools = new Set<string>();
    let activeSchool: string | null = null,
      awaitingData = false;
    const dataHeights: { schoolId: string; height: number }[] = [];
    const p = shoppingListGeometries[envelope.geometry];
    for (const [rowIndex, cells] of rows.entries()) {
      const v = cells.map((c) => c.text),
        id = v[6]!;
      shoppingAssert(
        v[15] === "SCHOOL_BAND" || v[15] === "DATA_LINE",
        "ROW_STRUCTURE_INVALID",
      );
      if (v[15] === "SCHOOL_BAND") {
        shoppingAssert(
          [6, 7, 8, 11, 12, 13, 14].every((c) => v[c] === ""),
          "LINE_SET_MISMATCH",
        );
        shoppingAssert(
          schools.has(v[10]!) &&
            v[5] === envelope.marker &&
            v[9] === daily.service_date,
          "STALE_IDENTITY",
        );
        const following = rows[rowIndex + 1];
        shoppingAssert(
          following?.[15]?.text === "DATA_LINE",
          "SCHOOL_GROUP_INVALID",
        );
        const followingLine = byLine.get(following[6]!.text);
        shoppingAssert(followingLine, "LINE_SET_MISMATCH");
        // Band identity comes from the next authoritative business line, never
        // from a displayed name. Retargeting to any existing School is stale too.
        shoppingAssert(v[10] === followingLine.school.id, "STALE_IDENTITY");
        const name = schools.get(v[10]!)!;
        const continuation = v[0] === `${name} (tiếp)`;
        shoppingAssert(
          v[16] === name && (v[0] === name || continuation),
          "REFERENCE_CHANGED",
        );
        shoppingAssert(
          v.slice(1, 5).every((s) => s === "") && !awaitingData,
          "SCHOOL_GROUP_INVALID",
        );
        shoppingAssert(
          continuation
            ? activeSchool === v[10] && labelledSchools.has(v[10]!)
            : !labelledSchools.has(v[10]!),
          "SCHOOL_GROUP_INVALID",
        );
        if (!continuation) labelledSchools.add(v[10]!);
        activeSchool = v[10]!;
        awaitingData = true;
        // Native Excel on this host quantizes stored row heights by <=0.1 pt.
        // Allow 0.15 pt representation drift, never a different height class.
        shoppingAssert(
          Math.abs(
            envelope.heights.get(daily.service_date)![rowIndex]! - p.bandRowPt,
          ) <= 0.15,
          "PRINT_STRUCTURE_CHANGED",
        );
        continue;
      }
      const line = byLine.get(id);
      shoppingAssert(
        line &&
          !seen.has(id) &&
          !globalSeen.has(id) &&
          !line.source_stale &&
          !line.blockers.length,
        "LINE_SET_MISMATCH",
      );
      seen.add(id);
      globalSeen.add(id);
      const expected = [
        envelope.marker,
        id,
        line.current_revision_id,
        line.current_decision_id ?? "",
        daily.service_date,
        line.school.id,
        line.delivery_location.id,
        line.ingredient.id,
        line.controlled_unit.id,
      ];
      shoppingAssert(
        v.slice(5, 14).every((value, i) => value === expected[i]) &&
          line.service_date === daily.service_date,
        "STALE_IDENTITY",
      );
      shoppingAssert(
        v[16] === line.school.name && v[0] === "",
        "REFERENCE_CHANGED",
      );
      shoppingAssert(activeSchool === line.school.id, "SCHOOL_GROUP_INVALID");
      awaitingData = false;
      const storedHeight = envelope.heights.get(daily.service_date)![rowIndex]!;
      const height = [p.normalRowPt, p.wrappedRowPt].find(
        (h) => Math.abs(storedHeight - h) <= 0.15,
      );
      shoppingAssert(height !== undefined, "PRINT_STRUCTURE_CHANGED");
      dataHeights.push({ schoolId: line.school.id, height });
      shoppingAssert(
        v[1] === line.ingredient.name &&
          v[2] === shoppingListUnitDisplay(line.controlled_unit) &&
          line.controlled_unit.status === "ACTIVE",
        "REFERENCE_CHANGED",
      );
      const baseline = normalizeConfirmedNeedQuantity(v[14]!);
      shoppingAssert(
        baseline &&
          baseline === v[14] &&
          exactDecimalEqual(baseline, savedShoppingListQuantity(line)),
        "STALE_QUANTITY",
      );
      const existing = currentDrafts[id];
      shoppingAssert(existing, "MISSING_LOCAL_LINE");
      shoppingAssert(
        confirmedNeedDraftMatchesSaved(line, existing),
        "DIRTY_WORKBENCH",
      );
      const quantity = normalizeConfirmedNeedQuantity(v[3]!);
      shoppingAssert(quantity, "INVALID_QUANTITY");
      if (exactDecimalEqual(quantity, baseline)) continue;
      shoppingAssert(
        normalizeConfirmedNeedEntry(v[3]!) &&
          line.effective_policy &&
          line.effective_policy.status === "ACTIVE" &&
          line.effective_policy.effective_from <= daily.service_date &&
          (!line.effective_policy.effective_to ||
            line.effective_policy.effective_to > daily.service_date) &&
          confirmedNeedQuantityMatchesStep(
            quantity,
            line.effective_policy.planning_step,
          ),
        "INVALID_QUANTITY",
      );
      next[id] = {
        ...existing,
        exact_quantity: confirmedNeedInputDisplay(quantity),
        quantity_entered: true,
      };
      changedLineIds.push(id);
    }
    shoppingAssert(seen.size === b.lines.length, "LINE_SET_MISMATCH");
    shoppingAssert(
      !awaitingData && labelledSchools.size === schools.size,
      "SCHOOL_GROUP_INVALID",
    );
    const planned = shoppingListPages(dataHeights, envelope.geometry);
    shoppingAssert(
      planned.body.length === rows.length &&
        planned.body.every(
          (r, i) =>
            rows[i]![15]!.text === r.kind &&
            (r.kind !== "SCHOOL_BAND" ||
              rows[i]![0]!.text ===
                `${schools.get(dataHeights[r.index]!.schoolId)}${r.continuation ? " (tiếp)" : ""}`),
        ) &&
        JSON.stringify(planned.breaks) ===
          JSON.stringify(envelope.breaks.get(daily.service_date)),
      "PRINT_STRUCTURE_CHANGED",
    );
  }
  return { drafts: next, changedLineIds };
}
export async function parseConfirmedNeedShoppingListXlsx(
  bytes: ArrayBuffer | Uint8Array,
  batches: ConfirmedNeedWorkbenchData[],
  currentDrafts: Record<string, ConfirmedNeedDraftLine>,
) {
  return validateShoppingListEnvelope(
    await readShoppingListEnvelope(bytes),
    batches,
    currentDrafts,
  );
}
