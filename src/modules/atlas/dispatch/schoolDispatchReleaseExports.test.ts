import ExcelJS from "exceljs";
import JSZip from "jszip";
import type { Node } from "pdfmake/interfaces";
import { describe, expect, it } from "vitest";
import { createReviewSchoolDispatchDocument } from "./reviewSchoolDispatchReleaseApi";
import {
  buildSchoolDispatchExportData,
  buildSchoolDispatchPdfDefinition,
  createGroupedSchoolDispatchXlsx,
  createSchoolDispatchXlsx,
} from "./schoolDispatchReleaseExports";

describe("School dispatch release exports", () => {
  it("prints one address prefix in PDF and Excel without changing the captured address", async () => {
    const document = createReviewSchoolDispatchDocument("RELEASED");
    document.document_issuer_address = "ĐC: Địa chỉ đã phát hành";
    const captured = JSON.stringify(document);
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(await createSchoolDispatchXlsx(document));
    expect(workbook.worksheets[0]!.getCell("B2").text).toBe(
      "ĐC: Địa chỉ đã phát hành",
    );
    const definition = JSON.stringify(
      buildSchoolDispatchPdfDefinition(document),
    );
    expect(definition).toContain("ĐC: Địa chỉ đã phát hành");
    expect(definition).not.toContain("ĐC: ĐC:");
    expect(JSON.stringify(document)).toBe(captured);
  });
  it("gives the unwrapped inspection header its measured Roboto15 width", () => {
    const definition = buildSchoolDispatchPdfDefinition(
      createReviewSchoolDispatchDocument("RELEASED"),
    );
    const table = (
      definition.content as { table?: { widths: (string | number)[] } }[]
    ).find((node) => node.table)!.table!;
    // The bundled bold Roboto15 measures Không đạt at 69.214pt, before padding.
    expect(table.widths[5]).toBeGreaterThanOrEqual(70);
    expect(definition.defaultStyle?.fontSize).toBe(15);
  });
  it.each([1, 2, 12])(
    "moves a %i-line document's final table when signatures would be orphaned, while allowing tall rows to paginate",
    (count) => {
      const document = createReviewSchoolDispatchDocument("RELEASED");
      document.lines = Array.from({ length: count }, (_, index) => ({
        ...document.lines[0]!,
        ingredient_name: `Thực phẩm ${index + 1}`,
      }));
      const definition = buildSchoolDispatchPdfDefinition(document);
      const content = definition.content as {
        id?: string;
        table?: { dontBreakRows?: boolean };
        unbreakable?: boolean;
      }[];
      const tail = content.filter((node) => node.table).at(-1)!;
      const signatures = content.find(
        (node) => node.id === "dispatch-signatures-end",
      )!;
      const positioned = (node: object, pages: number[]) =>
        ({ ...node, pageNumbers: pages }) as Node;
      expect(tail.unbreakable).not.toBe(true);
      expect(tail.table?.dontBreakRows).not.toBe(true);
      expect(signatures).toBeDefined();
      expect(
        definition.pageBreakBefore?.(
          positioned(tail, [1]),
          [],
          [positioned(signatures, [2])],
          [],
        ),
      ).toBe(true);
      expect(
        definition.pageBreakBefore?.(
          positioned(tail, [1]),
          [positioned(signatures, [1])],
          [],
          [],
        ),
      ).toBe(false);
      expect(
        definition.pageBreakBefore?.(
          positioned(tail, [1, 2]),
          [],
          [positioned(signatures, [2])],
          [],
        ),
      ).toBe(true);
      expect(
        definition.pageBreakBefore?.(positioned(tail, [1, 2, 3]), [], [], []),
      ).toBe(false);
      expect(JSON.stringify(content).match(/Thực phẩm \d+/g)).toHaveLength(
        count,
      );
    },
  );
  it("gives pdfmake independent continuation headers so its row-span layout cannot erase them", () => {
    const document = createReviewSchoolDispatchDocument("RELEASED");
    document.lines = Array.from({ length: 12 }, () => ({
      ...document.lines[0]!,
    }));
    const content = buildSchoolDispatchPdfDefinition(document).content as {
      table?: { widths: unknown; body: unknown[][] };
      stack?: { table?: { widths: unknown; body: unknown[][] } }[];
    }[];
    const first = content.find((node) => node.table)!.table!;
    const last = content.filter((node) => node.table).at(-1)!.table!;
    expect(last.widths).not.toBe(first.widths);
    for (let row = 0; row < 2; row++) {
      expect(last.body[row]).not.toBe(first.body[row]);
      for (let cell = 0; cell < 8; cell++)
        if (typeof first.body[row]![cell] === "object")
          expect(last.body[row]![cell]).not.toBe(first.body[row]![cell]);
    }
  });
  it("gives the native Excel inspection label enough width without changing its font", async () => {
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(
      await createSchoolDispatchXlsx(
        createReviewSchoolDispatchDocument("RELEASED"),
      ),
    );
    const sheet = workbook.worksheets[0]!;
    expect(sheet.getColumn(6).width).toBeGreaterThanOrEqual(14);
    expect(sheet.getCell("F10").font).toMatchObject({
      name: "Times New Roman",
      size: 16,
      bold: true,
    });
  });
  it("keeps native width fitting and breaks before final food rows rather than orphaning Excel signatures", async () => {
    const document = createReviewSchoolDispatchDocument("RELEASED");
    document.lines = Array.from({ length: 12 }, (_, index) => ({
      ...document.lines[0]!,
      ingredient_name: `Thực phẩm dài cần giữ nguyên ${index + 1}`,
    }));
    const workbook = new ExcelJS.Workbook();
    const bytes = await createSchoolDispatchXlsx(document);
    await workbook.xlsx.load(bytes);
    const sheet = workbook.worksheets[0]!;
    expect(sheet.pageSetup.fitToPage).toBe(true);
    expect(sheet.pageSetup.printTitlesRow).toBe("9:10");
    // ExcelJS does not restore rowBreaks on read; verify the actual workbook XML.
    const zip = await JSZip.loadAsync(bytes);
    const xml = await zip.file("xl/worksheets/sheet1.xml")!.async("string");
    expect(xml).toMatch(/<brk id="20"[^>]*man="1"/);
  });
  it("prints the frozen human Unit name and preserves legacy code-only history", () => {
    const document = createReviewSchoolDispatchDocument("RELEASED");
    document.lines[0]!.unit_code = "v1-unit-count";
    Object.assign(document.lines[0]!, { unit_name: "Trái" });
    expect(buildSchoolDispatchExportData(document).lines[0]!.unitCode).toBe(
      "Trái",
    );
    delete (document.lines[0]! as { unit_name?: string }).unit_name;
    expect(buildSchoolDispatchExportData(document).lines[0]!.unitCode).toBe(
      "v1-unit-count",
    );
  });
  it("allows short Vietnamese Unit labels to print whole at the accepted body font", () => {
    const document = createReviewSchoolDispatchDocument("RELEASED");
    document.lines = ["Cốc", "Quả"].map((unit_code) => ({
      ...document.lines[0]!,
      unit_code,
    }));
    const definition = buildSchoolDispatchPdfDefinition(document);
    const table = (
      definition.content as {
        table?: { widths: unknown[]; body: unknown[][] };
      }[]
    ).find((node) => node.table)!.table!;
    // These accepted Roboto15 labels need about28pt; allow padding/tone marks.
    expect(table.widths[2]).toBeGreaterThanOrEqual(32);
    expect(table.body.slice(2).map((row) => row[2])).toEqual(["Cốc", "Quả"]);
    expect(table.body.slice(2).map((row) => row.at(-1))).toEqual(["", ""]);
    expect(definition.pageOrientation).toBe("portrait");
  });
  it("prints captured cooking context with separate blank handwriting cells and one document note", async () => {
    const document = createReviewSchoolDispatchDocument("SUPERSEDED");
    Object.assign(document, {
      cooking_group_id: "group-x",
      cooking_group_name: "Bếp X khi phát hành",
    });
    document.note = "Giao tại cổng phụ trước 06:00";
    document.lines.push({ ...document.lines[0]!, ingredient_name: "Cà rốt" });
    const book = new ExcelJS.Workbook();
    await book.xlsx.load(await createSchoolDispatchXlsx(document));
    const sheet = book.worksheets[0]!;
    expect(sheet.getCell("A6").text).toBe(
      "TRƯỜNG: Trường Tiểu học Nguyễn Du\nNẤU TẠI: Bếp X khi phát hành",
    );
    expect(sheet.getCell("H9").text).toBe("Ghi chú");
    expect(sheet.getColumn(8).width).toBeGreaterThanOrEqual(20);
    for (const row of [11, 12]) {
      expect(sheet.getCell(row, 8).text).toBe("");
      expect(sheet.getRow(row).height).toBeGreaterThanOrEqual(30);
    }
    expect(sheet.getRow(9).values).not.toContain("Trường");
    expect(sheet.getCell("G9").text).toBe("Biện pháp xử lý");
    expect(sheet.getCell("E10").text).toBe("Đạt");
    expect(sheet.getCell("F10").text).toBe("Không đạt");
    const worksheetText: string[] = [];
    sheet.eachRow((row) =>
      row.eachCell((cell) => {
        if (!cell.isMerged || cell.address === cell.master.address)
          worksheetText.push(cell.text);
      }),
    );
    expect(worksheetText.join("\n").split(document.note)).toHaveLength(2);
    const definition = buildSchoolDispatchPdfDefinition(document);
    const text = JSON.stringify(definition);
    expect(text).toContain("NẤU TẠI: Bếp X khi phát hành");
    expect(text.split(document.note)).toHaveLength(2);
    const table = (
      definition.content as { table?: { body: unknown[][] } }[]
    ).find((node) => node.table)!.table!;
    expect(table.body[0]!.at(-1)).toMatchObject({ text: "Ghi chú" });
    expect(table.body.slice(2).map((row) => row.at(-1))).toEqual(["", ""]);
    expect(definition.pageOrientation).toBe("portrait");
  });

  it.each([
    {},
    { cooking_group_id: null, cooking_group_name: null },
    { cooking_group_name: "Tên từ ghi chú" },
  ])(
    "does not infer cooking grouping from missing or unpaired snapshot fields %j",
    async (group) => {
      const document = createReviewSchoolDispatchDocument("RELEASED");
      Object.assign(document, group);
      document.delivery_location_name = "Bếp tên giống nhóm";
      const book = new ExcelJS.Workbook();
      await book.xlsx.load(await createSchoolDispatchXlsx(document));
      expect(book.worksheets[0]!.getCell("A6").text).toBe(
        "TRƯỜNG: Trường Tiểu học Nguyễn Du",
      );
      expect(
        JSON.stringify(book.worksheets[0]!.getSheetValues()),
      ).not.toContain("NẤU TẠI:");
      expect(
        JSON.stringify(buildSchoolDispatchPdfDefinition(document)),
      ).not.toContain("NẤU TẠI:");
    },
  );
  it("preserves the V1 inspection purposes and adds handwriting notes for the same 13-item case", async () => {
    const document = createReviewSchoolDispatchDocument("RELEASED");
    document.lines = Array.from({ length: 13 }, (_, index) => ({
      ...document.lines[0]!,
      ingredient_id: `fixture-${index}`,
      ingredient_name: index === 0 ? "Cà rốt" : `Thực phẩm ${index + 1}`,
      quantity: "3.000000",
    }));
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(await createSchoolDispatchXlsx(document));
    const sheet = workbook.worksheets[0]!;
    expect(sheet.getCell("B1").value).toBe(document.document_issuer_name);
    expect(sheet.getCell("B2").value).toBe(
      `ĐC: ${document.document_issuer_address}`,
    );
    expect(sheet.getCell("A3").value).toBeNull();
    expect(sheet.getCell("A4").value).toBe("PHIẾU XUẤT KHO");
    expect(sheet.getCell("F5").value).toBe("Ngày:");
    expect(sheet.getCell("G5").value).toBe("24/09/2026");
    expect(sheet.getCell("A8").text).toContain("ĐÃ PHÁT HÀNH");
    expect(sheet.getColumn(5).width).toBe(7);
    expect(sheet.getColumn(6).width).toBe(14);
    expect(sheet.getColumn(7).width).toBe(19);
    expect(sheet.getCell("D23").value).toBe("3");
    expect(sheet.getCell("A29").value).toBe("Người nhận hàng");
    expect(sheet.getCell("C29").value).toBe("Người giao hàng");
    expect(sheet.getCell("F29").value).toBe("Người lập phiếu");
    expect(sheet.getCell("A30").value).toBe("(Ký, ghi họ tên)");
    expect(sheet.getRow(29).height).toBe(24);
    expect(sheet.getRow(30).height).toBe(24);
    expect(sheet.pageSetup.printArea).toBe("A1:H35");
    expect(JSON.stringify(sheet.getSheetValues())).not.toContain(
      "Bùi Thị Linh Trang",
    );
    expect(JSON.stringify(sheet.getSheetValues())).not.toContain(
      "Quách Thành Đạt",
    );
  });
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
    expect(sheet.getColumn(1).width).toBe(7);
    expect(sheet.getColumn(2).width).toBeGreaterThan(30);
    expect(sheet.getColumn(4).width).toBeLessThan(12.28515625);
    expect(sheet.getColumn(7).width).toBe(19);
    expect(sheet.getCell("B1").alignment.horizontal).toBe("center");
    expect(sheet.getCell("B2").alignment.horizontal).toBe("center");
    expect(sheet.getCell("A9").value).toBe("Stt");
    expect(sheet.getCell("A5").value).toBe(
      "Số phiếu: PXK-20260924-2600000000004000",
    );
    expect(sheet.getCell("E9").value).toBe("Tình trạng cảm quan");
    expect(sheet.getCell("E10").value).toBe("Đạt");
    expect(sheet.getCell("F10").value).toBe("Không đạt");
    expect(sheet.getCell("G9").value).toBe("Biện pháp xử lý");
    expect(sheet.getCell("D11").value).toBe("100");
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
    laterSchool.school_dispatch_release_id = "release-school-b";
    laterSchool.school_id = "school-b";
    const firstSchool = createReviewSchoolDispatchDocument("RELEASED");
    firstSchool.school_name = "Trường A";
    firstSchool.school_display_order = 1;
    firstSchool.document_number = "PXK-A";

    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(
      await createGroupedSchoolDispatchXlsx([laterSchool, firstSchool]),
    );

    expect(
      workbook.worksheets.filter((s) => s.state === "visible"),
    ).toHaveLength(2);
    expect(workbook.worksheets[0]!.getCell("A6").value).toContain("Trường A");
    expect(workbook.worksheets[1]!.getCell("A6").value).toContain("Trường B");
  });
});
