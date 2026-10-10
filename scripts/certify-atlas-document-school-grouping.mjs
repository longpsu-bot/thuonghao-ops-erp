// Fixture-only production-export specimens. No database connection or write.
import fs from "node:fs/promises";
import path from "node:path";
import assert from "node:assert/strict";
import ExcelJS from "exceljs";
import { createServer } from "vite";

const output = path.resolve(
  process.argv[2] ?? "docs/testing/artifacts/atlas-document-school-grouping-02",
);
await fs.mkdir(output, { recursive: true });
const server = await createServer({
  configFile: false,
  optimizeDeps: { noDiscovery: true, include: [] },
  server: { hmr: false, middlewareMode: true, watch: null },
  appType: "custom",
});
const load = (file) => server.ssrLoadModule("/src/modules/atlas/" + file);
const manifest = { fixtureOnly: true, files: [] };
try {
  const po = await load("procurement/purchaseOrderExports.ts");
  const { createReviewPurchaseOrdersFixture } = await load(
    "procurement/reviewSchoolCateringProcurementApi.ts",
  );
  const { measuredSchoolRowHeight, actualVisibleWidthPoints } = await load(
    "documents/schoolRowMeasurement.ts",
  );
  const order =
    createReviewPurchaseOrdersFixture("released_po").purchase_orders[0];
  const line = order.lines[0];
  order.lines = [line];
  const base = line.school_breakdown[0];
  const baseline = new ExcelJS.Workbook();
  await baseline.xlsx.load(
    await po.createPurchaseOrderXlsx(order, "details_school"),
  );
  const geometry = baseline.worksheets[0];
  const automatic = [];
  for (const lines of [2, 3, 4, 5]) {
    let label = "TRƯỜNG ĐO CHIỀU CAO VIỆT NAM";
    while (
      measuredSchoolRowHeight(label, geometry, 1, 6) <
      28 + 16 * (lines - 1)
    )
      label += " PHÂN HIỆU THƯỢNG HẢO";
    assert.equal(
      measuredSchoolRowHeight(label, geometry, 1, 6),
      28 + 16 * (lines - 1),
    );
    automatic.push(label);
  }
  const labels = [
    "PHẠM VĂN CỘI",
    "LÊ VĂN THẾ",
    "VĨNH TÂN",
    "VĨNH TÂN - PHÂN HIỆU",
    "CHUYÊN HÙNG VƯƠNG (Chiều Mặn 2)",
    ...automatic,
    "W".repeat(140),
    "DÒNG MỘT\nDÒNG HAI\nDÒNG BA\nDÒNG BỐN",
  ];
  line.ordered_quantity = `${labels.length}.000000`;
  line.school_breakdown = labels.map((name, index) => ({
    ...base,
    school_id: `fixture-school-${index}`,
    school_name: name,
    school_display_order: index,
    ordered_quantity: "1.000000",
    cooking_location_id: index < 5 ? "fixture-location" : null,
    cooking_location_kind:
      index === 4 ? "COMPANY" : index < 5 ? "SCHOOL" : null,
    cooking_location_host_school_id:
      index === 0 || index === 2
        ? `fixture-school-${index}`
        : index < 4
          ? "fixture-host"
          : null,
    cooking_location_name:
      index === 4
        ? "Công ty Thượng Hảo"
        : index < 2
          ? "PHẠM VĂN CỘI"
          : index < 4
            ? "VĨNH TÂN"
            : null,
    dispatch_group_id: null,
    dispatch_group_name: null,
  }));
  async function save(name, bytes) {
    const b = new ExcelJS.Workbook();
    await b.xlsx.load(bytes);
    const sheets = b.worksheets
      .filter((s) => s.state === "visible")
      .map((sheet) => {
        const cells = [];
        const schoolRows = [];
        const headerRows = [];
        sheet.eachRow((row) =>
          row.eachCell((cell) => {
            if (
              cell.value === null ||
              cell.value === undefined ||
              (cell.isMerged && cell.address !== cell.master.address)
            )
              return;
            if (typeof cell.value === "string")
              cells.push({
                address: cell.address,
                value: cell.value,
                hidden: sheet.getColumn(cell.col).hidden,
                quantity:
                  cell.col === 5 &&
                  cell.numFmt === "@" &&
                  /^\d+(\.\d+)?$/.test(cell.text),
              });
            const dispatchHeader =
              name.startsWith("Dispatch-") && cell.address === "A6";
            if (name.startsWith("Dispatch-") && cell.address === "A5") {
              headerRows.push({
                address: cell.address,
                text: cell.text,
                height: row.height,
                firstColumn: 1,
                lastColumn: 5,
                precedingText: sheet.getCell("A4").text,
                precedingLastColumn: 8,
                followingText: sheet.getCell("A6").text,
                followingLastColumn: 8,
              });
            }
            if (
              typeof cell.value === "string" &&
              (dispatchHeader ||
                (cell.col === 1 &&
                  sheet.name.endsWith("Theo trường") &&
                  row.number >= 10 &&
                  row.getCell(1).isMerged) ||
                (cell.col === 3 &&
                  sheet.name.endsWith("Theo hàng") &&
                  row.number >= 11 &&
                  !sheet.getColumn(3).hidden &&
                  typeof row.getCell(1).value === "number"))
            ) {
              const first = dispatchHeader || cell.col === 1 ? 1 : 3,
                last = dispatchHeader ? 8 : cell.col === 1 ? 6 : 3,
                bold = !dispatchHeader && cell.col === 1;
              schoolRows.push({
                address: cell.address,
                text: cell.text,
                height: row.height,
                widthPoints: actualVisibleWidthPoints(sheet, first, last),
                bold,
                measuredHeight: measuredSchoolRowHeight(
                  cell.text,
                  sheet,
                  first,
                  last,
                  bold,
                ),
                firstColumn: first,
                lastColumn: last,
                boundaryKind: dispatchHeader
                  ? "adjacent-header-text"
                  : "cell-borders",
                ...(dispatchHeader
                  ? {
                      precedingText: sheet.getCell("A5").text,
                      precedingLastColumn: 5,
                      followingText: sheet.getCell("A7").text,
                      followingLastColumn: 8,
                    }
                  : {}),
              });
            }
          }),
        );
        return { name: sheet.name, cells, schoolRows, headerRows };
      });
    const hiddenSheets = b.worksheets
      .filter((s) => s.state === "veryHidden")
      .map((sheet) => {
        const cells = [];
        sheet.eachRow((row) =>
          row.eachCell((cell) => {
            if (typeof cell.value === "string")
              cells.push({ address: cell.address, value: cell.value });
          }),
        );
        return { name: sheet.name, cells };
      });
    await fs.writeFile(path.join(output, name), bytes);
    manifest.files.push({ name, sheets, hiddenSheets });
  }
  await save(
    "PO-School-measured-rows.xlsx",
    await po.createPurchaseOrderXlsx(order),
  );
  const { createReviewSchoolDispatchDocument } = await load(
    "dispatch/reviewSchoolDispatchReleaseApi.ts",
  );
  const pxk = await load("dispatch/schoolDispatchReleaseExports.ts");
  const docs = ["VĨNH TÂN", "VĨNH TÂN - PHÂN HIỆU"].map((name, i) => {
    const d = createReviewSchoolDispatchDocument("RELEASED");
    Object.assign(d, {
      school_id: `vt-${i}`,
      school_name: name,
      school_dispatch_release_id: `vt-release-${i}`,
      document_number: `PXK-VT-${i}`,
      dispatch_group_id: "vt",
      dispatch_group_name: "VĨNH TÂN",
    });
    d.lines[0].quantity = "0.100001";
    d.lines[0].school_dispatch_release_line_id = `vt-line-${i}`;
    return d;
  });
  await save(
    "Dispatch-explicit-Vinh-Tan.xlsx",
    await pxk.createGroupedSchoolDispatchXlsx(docs),
  );
  const longSchool = createReviewSchoolDispatchDocument("RELEASED");
  Object.assign(longSchool, {
    school_id: "fixture-unrelated-long-school",
    school_name:
      "TRƯỜNG ĐO CHIỀU CAO VIỆT NAM " +
      "PHÂN HIỆU THƯỢNG HẢO ".repeat(24).trim(),
    school_dispatch_release_id: "fixture-long-school-release",
    document_number: "PXK-LONG-SCHOOL-HEADER",
    dispatch_group_id: null,
    dispatch_group_name: null,
    cooking_group_id: null,
    cooking_group_name: null,
  });
  await save(
    "Dispatch-long-school-header.xlsx",
    await pxk.createSchoolDispatchXlsx(longSchool),
  );
  const hungVuongNames = [
    "CHUYÊN HÙNG VƯƠNG (Sáng)",
    "CHUYÊN HÙNG VƯƠNG (Trưa)",
    "CHUYÊN HÙNG VƯƠNG (Trưa Mặn 2)",
    "CHUYÊN HÙNG VƯƠNG (Chiều)",
    "CHUYÊN HÙNG VƯƠNG (Chiều Mặn 2)",
  ];
  const hungVuongDocs = hungVuongNames.map((name, i) => {
    const d = createReviewSchoolDispatchDocument("RELEASED");
    Object.assign(d, {
      school_id: `hv-${i}`,
      school_name: name,
      school_dispatch_release_id: `hv-release-${i}`,
      document_number: `PXK-20260924-260000000000400${i}`,
      dispatch_group_id: "hv",
      dispatch_group_name: "CHUYÊN HÙNG VƯƠNG",
    });
    d.lines[0].quantity = "0.100001";
    d.lines[0].school_dispatch_release_line_id = `hv-line-${i}`;
    return d;
  });
  await save(
    "Dispatch-Hung-Vuong-five-numbers.xlsx",
    await pxk.createGroupedSchoolDispatchXlsx(hungVuongDocs),
  );
  await fs.writeFile(
    path.join(output, "manifest.json"),
    JSON.stringify(manifest, null, 2) + "\n",
  );
  console.log(
    "Generated 4 fixture-only workbooks; measured School bands include 1–5+ lines, narrower Theo hàng cells, short/long PXK School headers and all five grouped Hùng Vương release numbers.",
  );
} finally {
  await server.close();
}
