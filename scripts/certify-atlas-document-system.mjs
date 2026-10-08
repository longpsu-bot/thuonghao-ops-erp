// Safe fixture specimens through production builders. No connection or business write.
import fs from "node:fs/promises";
import path from "node:path";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import ExcelJS from "exceljs";
import { createServer } from "vite";
import { JSDOM } from "jsdom";

const output = path.resolve(
  process.argv[2] ?? "docs/testing/artifacts/atlas-document-system-01",
);
await fs.mkdir(output, { recursive: true });
const previous = process.argv.includes("--verify-determinism")
  ? JSON.parse(await fs.readFile(path.join(output, "manifest.json"), "utf8"))
  : null;
globalThis.DOMParser = new JSDOM().window.DOMParser;
const server = await createServer({
  configFile: false,
  optimizeDeps: { noDiscovery: true, include: [] },
  server: { hmr: false, middlewareMode: true },
  appType: "custom",
});
const root = "/src/modules/atlas/";
const load = (file) => server.ssrLoadModule(root + file);
const manifest = {
  fixtureOnly: true,
  generatedAt: "2026-10-08T00:00:00Z",
  files: [],
  shoppingImport: null,
};
try {
  const po = await load("procurement/purchaseOrderExports.ts");
  const pxk = await load("dispatch/schoolDispatchReleaseExports.ts");
  const preliminary = await load(
    "procurement/generatedPurchaseReviewExport.ts",
  );
  const attendance = await load("documents/attendanceImportTemplate.ts");
  const { createReviewPurchaseOrdersFixture } = await load(
    "procurement/reviewSchoolCateringProcurementApi.ts",
  );
  const { createReviewSchoolDispatchDocument } = await load(
    "dispatch/reviewSchoolDispatchReleaseApi.ts",
  );
  const { shoppingFixture } = await load(
    "planning-inputs/confirmed-needs/shoppingListTestFixtures.ts",
  );
  const shopping = await load(
    "planning-inputs/confirmed-needs/confirmedNeedShoppingList.ts",
  );
  const packageCodec = await load(
    "planning-inputs/confirmed-needs/shoppingListPackage.ts",
  );

  async function saveXlsx(name, bytes) {
    const book = new ExcelJS.Workbook();
    await book.xlsx.load(bytes);
    const sheets = book.worksheets
      .filter((s) => s.state !== "veryHidden")
      .map((sheet) => {
        const cells = [];
        sheet.eachRow((row) =>
          row.eachCell((cell) => {
            if (!cell.isMerged || cell.address === cell.master.address) {
              if (cell.value !== null && cell.value !== undefined)
                cells.push({
                  address: cell.address,
                  value: cell.value,
                  hidden: sheet.getColumn(cell.col).hidden,
                });
            }
          }),
        );
        assert.equal(sheet.pageSetup.paperSize, 9);
        assert(sheet.pageSetup.printArea);
        assert(sheet.pageSetup.printTitlesRow);
        return {
          name: sheet.name,
          orientation: sheet.pageSetup.orientation,
          cells,
        };
      });
    // Fixed ZIP timestamps only for review artifacts; production bytes are untouched.
    const parts = await packageCodec.readShoppingListPackage(
      new Uint8Array(bytes),
    );
    if (name === "Shopping-list-APlus-preserved") {
      // The accepted Shopping builder leaves package modified-time to ExcelJS.
      // Fix only this fixture metadata; no production codec/layout change.
      packageCodec.setPackageText(
        parts,
        "docProps/core.xml",
        packageCodec
          .packageText(parts, "docProps/core.xml")
          .replace(
            /(<dcterms:modified[^>]*>)[^<]*(<\/dcterms:modified>)/,
            `$1${manifest.generatedAt}$2`,
          ),
      );
    }
    const stable = packageCodec.writeShoppingListPackage(parts);
    await fs.writeFile(path.join(output, name + ".xlsx"), stable);
    manifest.files.push({
      name: name + ".xlsx",
      sha256: crypto.createHash("sha256").update(stable).digest("hex"),
      sheets,
    });
  }
  async function savePo(name, order) {
    await saveXlsx(name, await po.createPurchaseOrderXlsx(order));
    await savePdf(
      name,
      await po.createPurchaseOrderPdf(order),
      po.buildPurchaseOrderPdfDefinition(order),
    );
  }
  async function savePdf(name, bytes, definition) {
    await fs.writeFile(path.join(output, name + ".pdf"), bytes);
    const strings = [];
    const visit = (value) => {
      if (typeof value === "string") strings.push(value);
      else if (Array.isArray(value)) value.forEach(visit);
      else if (value && typeof value === "object") {
        if (typeof value.text === "string") strings.push(value.text);
        for (const key of ["content", "stack", "columns", "table", "body"])
          if (value[key]) visit(value[key]);
      }
    };
    visit(definition.content);
    manifest.files.push({
      name: name + ".pdf",
      sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
      visibleStrings: strings.filter((value) => value.length > 7),
    });
  }
  const order =
    createReviewPurchaseOrdersFixture("released_po").purchase_orders[0];
  order.current_revision.released_at = "2026-09-02T02:00:00Z";
  const single = structuredClone(order);
  single.lines = single.lines.slice(0, 1);
  await savePo("PO-one-school", single);
  order.lines[0].supplier_note = "Giao trước 05:30; hàng nguyên bao.";
  await savePo("PO-multiple-schools", order);
  const second = structuredClone(single);
  second.supplier.supplier_id = "fixture-supplier-b";
  second.purchase_order_id = "fixture-po-b";
  second.current_revision.supplier_name_snapshot = "Nhà cung ứng B — mẫu thử";
  second.document_number = "PO-FIXTURE-B";
  await savePo("PO-second-supplier", second);
  const historical = structuredClone(order);
  historical.status = "SUPERSEDED";
  historical.replaced_by_purchase_order_id =
    "25000000-0000-4000-8000-000000000054";
  await savePo("PO-superseded", historical);
  const multiline = structuredClone(order);
  multiline.lines[0].supplier_note = "BEGINQA" + "A\n".repeat(240) + "ENDQA";
  await savePo("PO-multiline-note", multiline);
  const many = structuredClone(order);
  many.lines = Array.from({ length: 60 }, (_, i) => {
    const line = structuredClone(order.lines[i % 2]);
    line.purchase_order_line_revision_id = `fixture-line-${String(i).padStart(3, "0")}`;
    line.ingredient.ingredient_id = `fixture-ingredient-${String(i).padStart(3, "0")}`;
    line.ingredient.ingredient_name =
      i === 0
        ? "Nguyên liệu tên dài cần đọc rõ: thịt bò thái lát dùng chế biến món ăn tại trường"
        : "Nguyên liệu mẫu " + String(i).padStart(3, "0");
    line.supplier_note =
      i === 1
        ? "Kiểm tra bao bì, giao hàng tại cổng phụ trước 05:30. "
            .repeat(9)
            .trim()
        : null;
    line.ordered_quantity = i === 0 ? "99999999999999.123456" : "1.234567";
    line.school_breakdown[0].ordered_quantity = line.ordered_quantity;
    if (i % 2 === 0)
      line.school_breakdown[0].school_name =
        "Trường Tiểu học mẫu với tên dài cần đọc đầy đủ khi giao hàng";
    return line;
  });
  await savePo("PO-multipage-precision", many);

  const document = createReviewSchoolDispatchDocument("RELEASED");
  document.released_at = "2026-09-24T02:00:00Z";
  await saveXlsx(
    "PXK-one-school",
    await pxk.createSchoolDispatchXlsx(document),
  );
  await savePdf(
    "PXK-one-school",
    await pxk.createSchoolDispatchPdf(document),
    pxk.buildSchoolDispatchPdfDefinition(document),
  );
  const long = structuredClone(document);
  long.status = "SUPERSEDED";
  long.predecessor_release_id = "fixture-predecessor";
  long.school_name =
    "Trường Tiểu học mẫu với tên dài cần đọc đầy đủ khi giao hàng";
  long.delivery_address =
    "Số 123, đường nội bộ khu dân cư, phường mẫu, cổng phụ trường học, khu vực giao thực phẩm buổi sáng.";
  long.note = "Giao tại cổng phụ; giữ nguyên số lượng đã phát hành.";
  long.lines = Array.from({ length: 60 }, (_, i) => ({
    ...document.lines[0],
    ingredient_id: `fixture-${i}`,
    ingredient_name:
      i === 0
        ? "Nguyên liệu có tên dài cần xuống dòng rõ ràng khi giao nhận"
        : "Thực phẩm mẫu " + String(i).padStart(3, "0"),
    quantity: i === 0 ? "99999999999999.123456" : "1.234567",
  }));
  await saveXlsx(
    "PXK-multipage-superseded",
    await pxk.createSchoolDispatchXlsx(long),
  );
  await savePdf(
    "PXK-multipage-superseded",
    await pxk.createSchoolDispatchPdf(long),
    pxk.buildSchoolDispatchPdfDefinition(long),
  );
  const other = structuredClone(document);
  other.school_dispatch_release_id = "fixture-other-release";
  other.delivery_location_id = "fixture-other-location";
  other.document_number = "PXK-FIXTURE-B";
  other.delivery_location_name = "Bếp phụ — điểm giao riêng";
  await saveXlsx(
    "Dispatch-grouped-distinct-destinations",
    await pxk.createGroupedSchoolDispatchXlsx([long, other, document]),
  );

  // Optional owner reference files stay read-only and outside the repository.
  const referenceArg = process.argv.indexOf("--v1-reference-dir");
  if (referenceArg !== -1) {
    const referenceDir = process.argv[referenceArg + 1];
    const references = [];
    for (const name of [
      "3F_20-04-2026_ALL_GROUPED.xlsx",
      "Dispatch_GROUPED_20-04-2026.xlsx",
    ]) {
      const bytes = await fs.readFile(path.join(referenceDir, name));
      const book = new ExcelJS.Workbook();
      await book.xlsx.load(bytes);
      references.push(book);
      (manifest.ownerReferences ??= []).push({
        name,
        sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
      });
    }
    const equivalent = structuredClone(order);
    equivalent.service_date = "2026-04-20";
    equivalent.document_number = "PO-V1-COMPARISON-3F";
    equivalent.current_revision.supplier_name_snapshot = "3F";
    equivalent.lines = [];
    const ingredients = new Map();
    const summaryReference = references[0].worksheets[2];
    for (let row = 11; row <= 14; row++) {
      ingredients.set(
        summaryReference.getCell(`C${row}`).text +
          "|" +
          summaryReference.getCell(`D${row}`).text,
        row - 11,
      );
    }
    const source = references[0].worksheets[1];
    let school = "",
      schoolIndex = 0;
    for (let row = 10; row <= source.rowCount; row++) {
      const current = source.getRow(row);
      if (
        current.getCell(1).text &&
        typeof current.getCell(3).value !== "number"
      ) {
        school = current.getCell(1).text;
        schoolIndex++;
      }
      if (typeof current.getCell(3).value !== "number") continue;
      assert(school, "Reference detail must belong to a School band");
      const name = current.getCell(4).text,
        unit = current.getCell(5).text;
      const key = name + "|" + unit;
      if (!ingredients.has(key)) ingredients.set(key, ingredients.size);
      const line = structuredClone(order.lines[0]);
      line.purchase_order_line_revision_id = `v1-fixture-line-${row}`;
      line.ingredient = {
        ingredient_id: `v1-fixture-ingredient-${ingredients.get(key)}`,
        ingredient_name: name,
      };
      line.unit = { unit_id: `v1-fixture-unit-${unit}`, unit_code: unit };
      // Reference detail quantities are small decimal facts. Summary's IEEE
      // 39.700000000000003 artifact is deliberately recomputed by the exact builder.
      line.ordered_quantity = Number(current.getCell(6).value).toFixed(6);
      line.supplier_note = null;
      line.delivery_location = {
        delivery_location_id: `v1-fixture-location-${schoolIndex}`,
        location_name: school,
      };
      line.school_breakdown = [
        {
          school_id: `v1-fixture-school-${schoolIndex}`,
          school_name: school,
          school_display_order: schoolIndex,
          delivery_location_id: line.delivery_location.delivery_location_id,
          delivery_location_name: school,
          ordered_quantity: line.ordered_quantity,
        },
      ];
      equivalent.lines.push(line);
    }
    assert.equal(equivalent.lines.length, 23);
    assert.equal(schoolIndex, 18);
    await savePo("V1-equivalent-3F-all", equivalent);
    for (const mode of ["details_ing", "details_school", "sum"]) {
      await saveXlsx(
        `V1-equivalent-3F-${mode}`,
        await po.createPurchaseOrderXlsx(equivalent, mode),
      );
      await savePdf(
        `V1-equivalent-3F-${mode}`,
        await po.createPurchaseOrderPdf(equivalent, mode),
        po.buildPurchaseOrderPdfDefinition(equivalent, mode),
      );
    }
    const inspection = structuredClone(document);
    const reference = references[1].worksheets[0];
    inspection.service_date = "2026-04-20";
    inspection.document_number = "PXK-V1-COMPARISON-13";
    inspection.document_issuer_name = reference.getCell("B1").text;
    inspection.document_issuer_address = reference
      .getCell("B2")
      .text.replace(/^ĐC:\s*/, "");
    inspection.school_name = reference
      .getCell("A6")
      .text.replace(/^Trường:\s*/, "");
    inspection.delivery_location_name = inspection.school_name;
    inspection.delivery_address = reference
      .getCell("A7")
      .text.replace(/^Địa chỉ:\s*/, "");
    inspection.lines = Array.from({ length: 13 }, (_, i) => ({
      ...document.lines[0],
      ingredient_id: `v1-inspection-item-${i}`,
      ingredient_name: reference.getCell(`B${11 + i}`).text,
      unit_code: reference.getCell(`C${11 + i}`).text,
      quantity: Number(reference.getCell(`D${11 + i}`).value).toFixed(6),
    }));
    await saveXlsx(
      "V1-equivalent-PXK-13",
      await pxk.createSchoolDispatchXlsx(inspection),
    );
    await savePdf(
      "V1-equivalent-PXK-13",
      await pxk.createSchoolDispatchPdf(inspection),
      pxk.buildSchoolDispatchPdfDefinition(inspection),
    );
    for (const [name, bytes] of [
      [
        "PO-supplier-date-all.zip",
        await po.createPurchaseOrderZip([equivalent, second], "all"),
      ],
      [
        "Dispatch-date.zip",
        await pxk.createSchoolDispatchZip([inspection, other], "date"),
      ],
      [
        "Dispatch-entity.zip",
        await pxk.createSchoolDispatchZip([inspection, other], "entity"),
      ],
    ]) {
      await fs.writeFile(path.join(output, name), bytes);
      manifest.files.push({
        name,
        sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
      });
    }
    manifest.equivalentFixtureFacts = {
      PO: "23 contributions, 18 School/location fixtures, 4 items from owner details; legacy codes intentionally unavailable in released contract",
      PXK: "same 13 items/Units/quantities, issuer, School/address; synthetic official numbers, no copied historical signers",
    };
  }

  const review = {
    success: true,
    contract_version: "PURCHASE-REVIEW.v1",
    service_date: "2026-09-07",
    document_label: "DỰ KIẾN — CHƯA XÁC NHẬN",
    blockers: [],
    warnings: [],
    rows: [],
  };
  review.rows = Array.from({ length: 40 }, (_, i) => ({
    service_date: review.service_date,
    school_id: `fixture-school-${i % 2}`,
    school_name: `Trường mẫu ${i % 2}`,
    delivery_location_id: `fixture-location-${i % 2}`,
    location_name: `Bếp mẫu ${i % 2}`,
    ingredient_id: `fixture-ingredient-${i}`,
    ingredient_name:
      i === 0
        ? "Nguyên liệu tên dài cần xuống dòng khi kiểm tra đề xuất nhà cung ứng"
        : "Nguyên liệu mẫu " + i,
    unit_id: i % 2 ? "unit-kg" : "unit-box",
    unit_code: i % 2 ? "kg" : "Hộp",
    family_quantity: i === 0 ? "99999999999999.123456" : "1.234567",
    eligible_suppliers: [
      {
        supplier_id: `supplier-${i % 3}`,
        supplier_name: `NCC mẫu ${i % 3}`,
        priority: 1,
      },
    ],
    recommendation:
      i % 3 === 2
        ? null
        : {
            supplier_id: `supplier-${i % 3}`,
            allocated_quantity: i === 0 ? "99999999999999.123456" : "1.234567",
            split_ratio: "1.000000000000",
          },
    warnings: i % 3 === 2 ? ["NO_ELIGIBLE_SUPPLIER"] : [],
  }));
  await saveXlsx(
    "Purchase-review-preliminary",
    await preliminary.createGeneratedPurchaseReviewXlsx(review),
  );
  const schools = [0, 1].map((i) => ({
    school_id: `fixture-school-${i}`,
    school_code: `TH00${i + 1}`,
    school_name: `Trường mẫu ${i + 1}`,
    school_status: "ACTIVE",
    display_order: i + 1,
    school_type_id: null,
    default_student_portions: 100,
    default_teacher_portions: 10,
  }));
  await saveXlsx(
    "Attendance-import-template",
    await attendance.createAttendanceImportTemplate("2026-09-07", schools),
  );

  const fixture = shoppingFixture();
  const shoppingBytes = await shopping.createConfirmedNeedShoppingListXlsx(
    [fixture],
    new Date(manifest.generatedAt),
    "00000000-0000-4000-8000-000000000001",
  );
  await saveXlsx("Shopping-list-APlus-preserved", shoppingBytes);
  const parsed = await shopping.parseConfirmedNeedShoppingListXlsx(
    new Uint8Array(shoppingBytes),
    [fixture.workbench],
    fixture.drafts,
  );
  assert.deepEqual(parsed.changedLineIds, []);
  manifest.shoppingImport = "PASS — no changes on clean V2/A+ import";
  if (previous) {
    const shoppingName = "Shopping-list-APlus-preserved.xlsx";
    const hashes = (files) =>
      files
        .filter(({ name }) => name !== shoppingName)
        .map(({ name, sha256 }) => ({ name, sha256 }));
    assert.deepEqual(hashes(manifest.files), hashes(previous.files));
    // Existing worksheet protection intentionally uses random cryptographic salts.
    // Preserve it and compare Shopping's captured cells/geometry, not random bytes.
    assert.deepEqual(
      manifest.files.find(({ name }) => name === shoppingName).sheets,
      previous.files.find(({ name }) => name === shoppingName).sheets,
    );
    await fs.writeFile(
      path.join(output, "determinism-report.json"),
      JSON.stringify(
        {
          fixtureOnly: true,
          result: "PASS",
          specimens: hashes(manifest.files),
          shopping:
            "PASS — identical cells/print geometry; accepted randomized protection untouched",
          normalization:
            "XLSX ZIP timestamps; Shopping fixture modified-time only. Production renderers unchanged by normalization.",
        },
        null,
        2,
      ) + "\n",
    );
  }
  await fs.writeFile(
    path.join(output, "manifest.json"),
    JSON.stringify(manifest, null, 2) + "\n",
  );
  console.log(
    `Generated ${manifest.files.length} recorded safe specimens in ${output}; Shopping List clean round trip PASS.`,
  );
} finally {
  await server.close();
}
