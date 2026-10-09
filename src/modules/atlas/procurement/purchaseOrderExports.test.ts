import { describe, expect, it } from "vitest";
import ExcelJS from "exceljs";
import { createReviewPurchaseOrdersFixture } from "./reviewSchoolCateringProcurementApi";
import {
  buildPurchaseOrderExportData,
  buildPurchaseOrderPdfDefinition,
  createPurchaseOrderPdf,
  createPurchaseOrderXlsx,
} from "./purchaseOrderExports";

describe("released purchase-order exports", () => {
  it("accounts for whole-word wrapping of wide supplier instructions", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    const note = "WWWWWWWWWWW ".repeat(41) + "WWWWWWWW";
    expect(note).toHaveLength(500);
    order.lines[0]!.supplier_note = note;
    const book = new ExcelJS.Workbook();
    await book.xlsx.load(await createPurchaseOrderXlsx(order, "sum"));
    const fragments: string[] = [];
    book.worksheets[0]!.eachRow((row, index) => {
      if (index <= 10 || !row.getCell(6).text) return;
      const fragment = row.getCell(6).text;
      fragments.push(fragment);
      // Each 11-W word is about125pt; two cannot share this physical note column.
      const words = fragment
        .trim()
        .split(/\s+/)
        .filter((word) => word.length >= 8).length;
      expect(row.height).toBeGreaterThanOrEqual(8 + words * 15);
      expect(row.height).toBeLessThanOrEqual(180);
    });
    expect(fragments.join("")).toBe(note);
  });
  it.each(["details_school", "details_ing", "sum"] as const)(
    "gives continuous wide 500-character notes enough native print height in %s",
    async (mode) => {
      const order =
        createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
      // Native TNR12 'W' is 11.33pt; a 32-character Excel column admits
      // at most 14 of them per line after padding. Average-glyph estimates clip.
      const note = "W".repeat(500);
      order.lines[0]!.supplier_note = note;
      const book = new ExcelJS.Workbook();
      await book.xlsx.load(await createPurchaseOrderXlsx(order, mode));
      const notes: string[] = [];
      const quantities: string[] = [];
      book.worksheets[0]!.eachRow((row, index) => {
        if (index <= (mode === "sum" ? 10 : 9) || row.getCell(1).isMerged)
          return;
        if (row.getCell(6).text) {
          const fragment = row.getCell(6).text;
          notes.push(fragment);
          expect(row.height).toBeGreaterThanOrEqual(
            8 + Math.ceil(fragment.length / 14) * 15,
          );
          expect(row.height).toBeLessThanOrEqual(180);
        }
        if (row.getCell(5).text) quantities.push(row.getCell(5).text);
      });
      expect(notes.join("")).toBe(note);
      expect(quantities).toEqual(["60", "40"]);
    },
  );
  it("uses frozen School cooking bands and a real note column in every detail mode", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    for (const line of order.lines) {
      Object.assign(line.school_breakdown[0]!, {
        cooking_group_id: "captured-group-x",
        cooking_group_name: "Bếp X lúc phát hành",
      });
    }
    order.lines[0]!.supplier_note = "Giao trước 05:30\nĐóng gói riêng";
    order.current_revision.reason_note = "Lý do nội bộ không phải ghi chú NCC";
    for (const mode of ["all", "details_school", "details_ing"] as const) {
      const workbook = new ExcelJS.Workbook();
      await workbook.xlsx.load(await createPurchaseOrderXlsx(order, mode));
      for (const sheet of workbook.worksheets.filter(
        (s) => !s.name.endsWith("Tổng"),
      )) {
        expect(sheet.getCell("F9").value).toBe("Ghi chú");
        expect(sheet.getCell("F11").value).toBe(
          "Giao trước 05:30\nĐóng gói riêng",
        );
        expect(sheet.getColumn(6).width).toBeGreaterThanOrEqual(28);
        expect(JSON.stringify(sheet.getSheetValues())).toContain(
          "NẤU TẠI: Bếp X lúc phát hành",
        );
        expect(sheet.pageSetup.orientation).toBe("portrait");
      }
      const schoolSheet = workbook.worksheets.find((s) =>
        s.name.endsWith("Theo trường"),
      );
      if (schoolSheet) {
        expect(schoolSheet.getRow(9).values).toEqual([
          undefined,
          "STT",
          "Mã hàng",
          "Tên hàng",
          "Đơn vị",
          "Số lượng",
          "Ghi chú",
        ]);
        expect(schoolSheet.getCell("A10").text).toContain(
          "TRƯỜNG: Trường Nguyễn Du",
        );
        expect(schoolSheet.getCell("C11").text).toBe("Gạo thơm");
        expect(schoolSheet.getCell("A13").text).toContain(
          "TRƯỜNG: Trường Trần Quốc Toản",
        );
        expect(schoolSheet.getCell("F14").text).toBe("");
      }
      const pdf = JSON.stringify(buildPurchaseOrderPdfDefinition(order, mode));
      expect(pdf).toContain("NẤU TẠI: Bếp X lúc phát hành");
      expect(pdf).toContain("Giao trước 05:30\\nĐóng gói riêng");
      expect(pdf).not.toContain("Lý do nội bộ");
    }
  });

  it.each([
    {},
    { cooking_group_id: null, cooking_group_name: null },
    { cooking_group_name: "Tên chưa có authority" },
  ])(
    "prints an ordinary School without inferring cooking context from %j",
    async (group) => {
      const order =
        createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
      Object.assign(order.lines[0]!.school_breakdown[0]!, group);
      order.lines[0]!.school_breakdown[0]!.delivery_location_name =
        "Bếp theo tên điểm giao";
      const book = new ExcelJS.Workbook();
      await book.xlsx.load(
        await createPurchaseOrderXlsx(order, "details_school"),
      );
      const text = JSON.stringify(book.worksheets[0]!.getSheetValues());
      expect(text).toContain("TRƯỜNG: Trường Nguyễn Du");
      expect(text).not.toContain("NẤU TẠI:");
      expect(
        JSON.stringify(
          buildPurchaseOrderPdfDefinition(order, "details_school"),
        ),
      ).not.toContain("NẤU TẠI:");
    },
  );

  it.each(["details_school", "details_ing", "sum"] as const)(
    "retains a 500-character multiline historical note in %s cells without repeating quantities",
    async (mode) => {
      const order =
        createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
      order.status = "SUPERSEDED";
      const note = "a\n".repeat(240) + "END" + "z".repeat(17);
      expect(note).toHaveLength(500);
      order.lines[0]!.supplier_note = note;
      const book = new ExcelJS.Workbook();
      await book.xlsx.load(await createPurchaseOrderXlsx(order, mode));
      const sheet = book.worksheets[0]!;
      const fragments: string[] = [];
      const quantities: string[] = [];
      sheet.eachRow((row, index) => {
        if (index > (mode === "sum" ? 10 : 9) && !row.getCell(1).isMerged) {
          if (row.getCell(6).text) {
            fragments.push(row.getCell(6).text);
            expect(row.height).toBeLessThanOrEqual(180);
          }
          if (row.getCell(5).text) quantities.push(row.getCell(5).text);
        }
      });
      expect(fragments.join("")).toBe(note);
      expect(quantities).toEqual(["60", "40"]);
      const pdf = buildPurchaseOrderPdfDefinition(order, mode);
      const tables = (
        pdf.content as { table?: { body: unknown[][] } }[]
      ).flatMap((item) => (item.table ? [item.table] : []));
      expect(
        tables
          .flatMap((table) =>
            table.body.slice(mode === "sum" ? 1 : 2).map((row) => row.at(-1)),
          )
          .filter((cell) => typeof cell === "string")
          .join(""),
      ).toBe(note);
    },
  );
  it("keeps distinct line notes with their exact quantities in XLSX and PDF", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.lines[0]!.supplier_note = "Loại 500g/gói";
    order.lines[1]!.supplier_note = "Giao trước 05:30";
    const data = buildPurchaseOrderExportData(order);
    expect(data.summaryLines).toHaveLength(2);
    expect(data.summaryLines.map((line) => line.supplierNote)).toEqual([
      "Loại 500g/gói",
      "Giao trước 05:30",
    ]);
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(await createPurchaseOrderXlsx(order));
    expect(
      workbook.getWorksheet("02-09-2026 - Tổng")!.getCell("F10").value,
    ).toBe("Ghi chú");
    expect(
      workbook.getWorksheet("02-09-2026 - Tổng")!.getCell("F11").value,
    ).toBe("Loại 500g/gói");
    expect(
      workbook.getWorksheet("02-09-2026 - Tổng")!.getCell("F12").value,
    ).toBe("Giao trước 05:30");
    expect(
      workbook.getWorksheet("02-09-2026 - Tổng")!.getCell("F11").alignment
        ?.wrapText,
    ).toBe(true);
    const definition = buildPurchaseOrderPdfDefinition(order);
    expect(JSON.stringify(definition)).toContain("Giao trước 05:30");
  });
  it("builds summary and school detail solely from the released PO snapshot", () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.supplier.supplier_name = "Tên NCC hiện tại đã đổi";
    order.current_revision.supplier_name_snapshot = "NCC An Phú lúc phát hành";
    const data = buildPurchaseOrderExportData(order);

    expect(data).toMatchObject({
      documentNumber: "PO-20260902-2500000000004000",
      supplierName: "NCC An Phú lúc phát hành",
      serviceDate: "02/09/2026",
      releasedRevision: 2,
      summaryLines: [
        {
          ingredientName: "Gạo thơm",
          orderedQuantity: "100.000000",
          unitCode: "kg",
          supplierNote: null,
        },
      ],
      schoolLines: [
        {
          schoolName: "Trường Nguyễn Du",
          schoolDisplayOrder: 1,
          ingredientName: "Gạo thơm",
          orderedQuantity: "60.000000",
          unitCode: "kg",
          supplierNote: null,
        },
        {
          schoolName: "Trường Trần Quốc Toản",
          schoolDisplayOrder: 2,
          ingredientName: "Gạo thơm",
          orderedQuantity: "40.000000",
          unitCode: "kg",
          supplierNote: null,
        },
      ],
    });
  });

  it("preserves exact six-decimal quantities beyond JavaScript safe integers", () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.lines[0]!.ordered_quantity = "9007199254740992.123455";
    order.lines[1]!.ordered_quantity = "1.000001";
    order.lines[0]!.school_breakdown[0]!.ordered_quantity =
      "9007199254740992.123455";
    order.lines[1]!.school_breakdown[0]!.ordered_quantity = "1.000001";

    expect(
      buildPurchaseOrderExportData(order).summaryLines[0]!.orderedQuantity,
    ).toBe("9007199254740993.123456");
  });

  it("includes official identity and released snapshot lines in the PDF definition", () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.supplier.supplier_name = "Tên NCC hiện tại đã đổi";
    order.current_revision.supplier_name_snapshot = "NCC An Phú lúc phát hành";
    const definition = buildPurchaseOrderPdfDefinition(order);
    const serialized = JSON.stringify(definition);

    expect(serialized).toContain("PHIẾU ĐẶT HÀNG");
    expect(serialized).toContain("PO-20260902-2500000000004000");
    expect(serialized).toContain("NCC An Phú lúc phát hành");
    expect(serialized).not.toContain("Tên NCC hiện tại đã đổi");
    expect(serialized).toContain("02/09/2026");
    expect(serialized).toContain("Gạo thơm");
    expect(serialized).toContain("Trường Nguyễn Du");
    expect(serialized).toContain('"text":"60"');
  });

  it("creates the default three-sheet PO workbook with exact text quantities", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.supplier.supplier_name = "Tên NCC hiện tại đã đổi";
    order.current_revision.supplier_name_snapshot = "NCC An Phú lúc phát hành";
    const bytes = await createPurchaseOrderXlsx(order);
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(bytes);

    expect(workbook.worksheets.map((sheet) => sheet.name)).toEqual([
      "02-09-2026 - Theo hàng",
      "02-09-2026 - Theo trường",
      "02-09-2026 - Tổng",
    ]);
    const summaryText = JSON.stringify(
      workbook.getWorksheet("02-09-2026 - Tổng")!.getSheetValues(),
    );
    const schoolText = JSON.stringify(
      workbook.getWorksheet("02-09-2026 - Theo trường")!.getSheetValues(),
    );
    const ingredientText = JSON.stringify(
      workbook.getWorksheet("02-09-2026 - Theo hàng")!.getSheetValues(),
    );
    expect(summaryText).toContain("PHIẾU ĐẶT HÀNG");
    expect(summaryText).toContain("PO-20260902-2500000000004000");
    expect(summaryText).toContain("NCC An Phú lúc phát hành");
    expect(summaryText).not.toContain("Tên NCC hiện tại đã đổi");
    expect(summaryText).toContain("02/09/2026");
    expect(summaryText).toContain("Mã hàng: bản phát hành chưa lưu mã");
    expect(summaryText).toContain("Mã NCC: bản phát hành chưa lưu mã");
    expect(schoolText).toContain("Trường Nguyễn Du");
    expect(ingredientText).toContain("Trường Trần Quốc Toản");
    expect(
      workbook.getWorksheet("02-09-2026 - Tổng")!.getCell("E11").value,
    ).toBe("100");
    expect(
      workbook.getWorksheet("02-09-2026 - Theo trường")!.getCell("A10").value,
    ).toContain("Trường Nguyễn Du");
    expect(
      workbook.getWorksheet("02-09-2026 - Theo trường")!.model.merges,
    ).toContain("A10:F10");
    expect(
      workbook.getWorksheet("02-09-2026 - Theo trường")!.model.merges,
    ).not.toContain("E11:F11");
    expect(
      workbook.getWorksheet("02-09-2026 - Theo trường")!.getCell("A13").value,
    ).toContain("Trường Trần Quốc Toản");
    expect(
      workbook.getWorksheet("02-09-2026 - Theo trường")!.getCell("E11").value,
    ).toBe("60");
    expect(
      workbook.getWorksheet("02-09-2026 - Theo trường")!.getCell("E11")
        .numFmt ?? "General",
    ).toBe("@");
    expect(workbook.model.media).toHaveLength(1);
    expect(
      workbook.getWorksheet("02-09-2026 - Theo trường")!.getCell("A9").fill,
    ).toMatchObject({
      type: "pattern",
      pattern: "solid",
    });
    expect(
      workbook.getWorksheet("02-09-2026 - Theo hàng")!.getCell("A10").value,
    ).toBe("Gạo thơm (kg)");
    expect(
      workbook.getWorksheet("02-09-2026 - Theo hàng")!.model.merges,
    ).toContain("A10:F10");
    expect(
      workbook.getWorksheet("02-09-2026 - Theo hàng")!.getCell("C11").value,
    ).toContain("Trường Nguyễn Du");
    expect(
      workbook.getWorksheet("02-09-2026 - Theo hàng")!.getRow(10).height,
    ).toBeGreaterThanOrEqual(24);
    expect(
      workbook.getWorksheet("02-09-2026 - Tổng")!.views[0]?.showGridLines,
    ).toBe(false);
    expect(
      workbook.getWorksheet("02-09-2026 - Tổng")!.pageSetup.orientation,
    ).toBe("portrait");
  });

  it("retains unsafe exact XLSX quantities as text instead of losing precision", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.lines[0]!.ordered_quantity = "9007199254740992.123455";
    order.lines[1]!.ordered_quantity = "1.000001";
    order.lines[0]!.school_breakdown[0]!.ordered_quantity =
      "9007199254740992.123455";
    order.lines[1]!.school_breakdown[0]!.ordered_quantity = "1.000001";

    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(await createPurchaseOrderXlsx(order));

    expect(
      workbook.getWorksheet("02-09-2026 - Tổng")!.getCell("E11").value,
    ).toBe("9007199254740993.123456");
    expect(
      workbook.getWorksheet("02-09-2026 - Theo trường")!.getCell("E11").value,
    ).toBe("9007199254740992.123455");
  });

  it("creates an actual PDF document from the same released snapshot", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    const bytes = await createPurchaseOrderPdf(order);
    expect(new TextDecoder().decode(bytes.slice(0, 5))).toBe("%PDF-");
    expect(bytes.byteLength).toBeGreaterThan(1_000);
  });

  it("keeps a superseded historical note exportable and wraps a bounded note", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.status = "SUPERSEDED";
    order.lines[0]!.supplier_note = "Giao trước 05:30; ".repeat(20).trim();
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(await createPurchaseOrderXlsx(order));
    const notes: string[] = [];
    workbook.getWorksheet("02-09-2026 - Tổng")!.eachRow((row, n) => {
      if (n >= 11 && typeof row.getCell(6).value === "string")
        notes.push(row.getCell(6).value as string);
    });
    expect(notes.join("")).toBe(order.lines[0]!.supplier_note);
    expect(
      workbook.getWorksheet("02-09-2026 - Tổng")!.getCell("F11").alignment
        ?.wrapText,
    ).toBe(true);
    expect(
      workbook.getWorksheet("02-09-2026 - Tổng")!.getRow(11).height,
    ).toBeGreaterThan(18);
    const pdf = buildPurchaseOrderPdfDefinition(order, "sum");
    const tables = (pdf.content as { table?: { body: unknown[][] } }[]).filter(
      (item) => item.table,
    );
    expect(
      tables[0]!
        .table!.body.slice(1)
        .map((row) => row.at(-1))
        .join(""),
    ).toBe(order.lines[0]!.supplier_note);
    expect(
      new TextDecoder().decode(
        (await createPurchaseOrderPdf(order)).slice(0, 5),
      ),
    ).toBe("%PDF-");
  });

  it("rejects output generation for a DRAFT snapshot", async () => {
    const order =
      createReviewPurchaseOrdersFixture("po_draft").purchase_orders[0]!;
    expect(() => buildPurchaseOrderExportData(order)).toThrow(
      /released PO snapshot/,
    );
    await expect(createPurchaseOrderXlsx(order)).rejects.toThrow(
      /released PO snapshot/,
    );
    await expect(createPurchaseOrderPdf(order)).rejects.toThrow(
      /released PO snapshot/,
    );
  });

  it("rejects a released export when its immutable supplier snapshot is missing", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.current_revision.supplier_name_snapshot = null;

    expect(() => buildPurchaseOrderExportData(order)).toThrow(
      /supplier snapshot/i,
    );
    await expect(createPurchaseOrderXlsx(order)).rejects.toThrow(
      /supplier snapshot/i,
    );
  });
});
