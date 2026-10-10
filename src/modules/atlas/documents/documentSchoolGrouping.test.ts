import ExcelJS from "exceljs";
import JSZip from "jszip";
import { describe, expect, it } from "vitest";
import { createReviewPurchaseOrdersFixture } from "../procurement/reviewSchoolCateringProcurementApi";
import { createPurchaseOrderXlsx } from "../procurement/purchaseOrderExports";
import { createReviewSchoolDispatchDocument } from "../dispatch/reviewSchoolDispatchReleaseApi";
import {
  createGroupedSchoolDispatchXlsx,
  createSchoolDispatchZip,
} from "../dispatch/schoolDispatchReleaseExports";
import { measuredSchoolRowHeight } from "./schoolRowMeasurement";

async function book(bytes: ExcelJS.Buffer) {
  const result = new ExcelJS.Workbook();
  await result.xlsx.load(bytes);
  return result;
}
function dispatch(index: number, name: string, group: string | null = null) {
  const d = createReviewSchoolDispatchDocument("RELEASED");
  Object.assign(d, {
    school_id: `school-${index}`,
    school_name: name,
    school_display_order: index,
    school_dispatch_release_id: `release-${index}`,
    document_number: `PXK-${index}`,
    dispatch_group_id: group,
    dispatch_group_name: group,
    cooking_group_id: "shared-kitchen",
    cooking_group_name: "Shared kitchen",
  });
  d.lines[0]!.school_dispatch_release_line_id = `line-${index}`;
  d.lines[0]!.quantity = "0.100001";
  return d;
}
const visible = (b: ExcelJS.Workbook) =>
  b.worksheets.filter((s) => s.state === "visible");

describe("Owner independent School cooking and Dispatch evidence", () => {
  it("keeps every original PXK number readable when five documents combine", async () => {
    const docs = Array.from({ length: 5 }, (_, i) =>
      dispatch(i, `School ${i}`, "CHUYÊN HÙNG VƯƠNG"),
    );
    for (const [i, doc] of docs.entries())
      doc.document_number = `PXK-20260924-260000000000400${i}`;
    const sheet = visible(
      await book(await createGroupedSchoolDispatchXlsx(docs)),
    )[0]!;
    for (const doc of docs)
      expect(sheet.getCell("A5").text).toContain(doc.document_number);
    expect(sheet.getRow(5).height).toBeGreaterThan(22);
  });
  it("measures PXK School headers across actual visible columns without a cap", async () => {
    const doc = dispatch(1, "TRƯỜNG " + "PHÂN HIỆU THƯỢNG HẢO ".repeat(24));
    const sheet = visible(
      await book(await createGroupedSchoolDispatchXlsx([doc])),
    )[0]!;
    expect(sheet.getRow(6).height).toBe(
      measuredSchoolRowHeight(sheet.getCell("A6").text, sheet, 1, 8, false),
    );
    expect(sheet.getRow(6).height).toBeGreaterThan(120);
    expect(sheet.getCell("A6").font).toMatchObject({
      name: "Times New Roman",
      size: 14,
    });
    expect(sheet.getCell("A6").alignment.wrapText).toBe(true);
  });
  it.each([
    [
      "Unresolved legacy location",
      null,
      null,
      "Captured kitchen",
      "Unresolved legacy location",
    ],
    [
      "Unresolved School host",
      "SCHOOL",
      null,
      "Captured kitchen",
      "Unresolved School host",
    ],
    ["PHẠM VĂN CỘI", "SCHOOL", "self", "PHẠM VĂN CỘI", "PHẠM VĂN CỘI"],
    [
      "LÊ VĂN THẾ",
      "SCHOOL",
      "host",
      "PHẠM VĂN CỘI",
      "LÊ VĂN THẾ (Nấu tại: PHẠM VĂN CỘI)",
    ],
    ["VĨNH TÂN", "SCHOOL", "self", "VĨNH TÂN", "VĨNH TÂN"],
    [
      "VĨNH TÂN - PHÂN HIỆU",
      "SCHOOL",
      "host",
      "VĨNH TÂN",
      "VĨNH TÂN - PHÂN HIỆU (Nấu tại: VĨNH TÂN)",
    ],
    [
      "CHUYÊN HÙNG VƯƠNG (Chiều Mặn 2)",
      "COMPANY",
      null,
      "Công ty Thượng Hảo",
      "CHUYÊN HÙNG VƯƠNG (Chiều Mặn 2) (Nấu tại: Công ty Thượng Hảo)",
    ],
    [
      "Same name",
      "SCHOOL",
      "host",
      "Same name",
      "Same name (Nấu tại: Same name)",
    ],
  ])(
    "prints ID-based PO label %s",
    async (name, kind, host, location, expected) => {
      const order =
        createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
      const s = order.lines[0]!.school_breakdown[0]!;
      Object.assign(s, {
        school_name: name,
        cooking_location_id: "location",
        cooking_location_name: location,
        cooking_location_kind: kind,
        cooking_location_host_school_id: host === "self" ? s.school_id : host,
        dispatch_group_id: "irrelevant",
        dispatch_group_name: "Not a kitchen",
      });
      const b = await book(
        await createPurchaseOrderXlsx(order, "details_school"),
      );
      expect(b.worksheets[0]!.getCell("A10").text).toBe(expected);
      expect(b.worksheets[0]!.getRow(10).font).toMatchObject({
        name: "Times New Roman",
        size: 14,
        bold: true,
      });
      expect(b.worksheets[0]!.getRow(10).height).toBe(28);
    },
  );
  it("keeps two PO School sections at the same Cooking Location and same Ingredient", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    const first = order.lines[0]!;
    order.lines = [first];
    first.school_breakdown = [
      {
        ...first.school_breakdown[0]!,
        school_name: "VĨNH TÂN",
        school_id: "main",
        ordered_quantity: "30.000000",
      },
      {
        ...first.school_breakdown[0]!,
        school_name: "VĨNH TÂN - PHÂN HIỆU",
        school_id: "branch",
        school_display_order: 2,
        ordered_quantity: "30.000000",
      },
    ];
    first.ordered_quantity = "60.000000";
    for (const s of first.school_breakdown)
      Object.assign(s, {
        cooking_location_id: "vt",
        cooking_location_name: "VĨNH TÂN",
        cooking_location_kind: "SCHOOL",
        cooking_location_host_school_id: "main",
      });
    const b = await book(
      await createPurchaseOrderXlsx(order, "details_school"),
    );
    expect(b.worksheets[0]!.getCell("A10").text).toBe("VĨNH TÂN");
    expect(b.worksheets[0]!.getCell("A13").text).toBe(
      "VĨNH TÂN - PHÂN HIỆU (Nấu tại: VĨNH TÂN)",
    );
    expect([
      b.worksheets[0]!.getCell("E11").text,
      b.worksheets[0]!.getCell("E14").text,
    ]).toEqual(["30", "30"]);
  });
  it.each([
    ["VĨNH TÂN", ["VĨNH TÂN", "VĨNH TÂN - PHÂN HIỆU"], "0.200002"],
    [
      "CHUYÊN HÙNG VƯƠNG",
      ["Sáng", "Trưa", "Trưa Mặn 2", "Chiều", "Chiều Mặn 2"],
      "0.500005",
    ],
    ["PHÚ HOÀ ĐÔNG 1", ["main", "PH1", "PH2"], "0.300003"],
  ])(
    "combines explicit %s members exactly with plural lineage",
    async (group, members, total) => {
      const docs = members.map((n, i) => dispatch(i, n, group));
      const b = await book(await createGroupedSchoolDispatchXlsx(docs));
      expect(visible(b)).toHaveLength(1);
      expect(visible(b)[0]!.getCell("A6").text).toBe(`NHÓM DISPATCH: ${group}`);
      expect(visible(b)[0]!.getCell("D11").text).toBe(total);
      expect(visible(b)[0]!.getCell("B12").text).toBe("");
      const meta = b.getWorksheet("_ATLAS_META")!;
      const records = meta
        .getSheetValues()
        .slice(3)
        .filter(Boolean) as unknown[][];
      expect(
        records
          .filter((r) => r[1] === "DOCUMENT")
          .map((r) => r[2])
          .sort(),
      ).toEqual(docs.map((d) => d.school_dispatch_release_id).sort());
      expect(
        records
          .filter((r) => r[1] === "ROW_SOURCE")
          .map((r) => r[2])
          .sort(),
      ).toEqual(docs.map((d) => d.school_dispatch_release_id).sort());
      for (const d of docs)
        expect(JSON.stringify(records)).toContain(
          d.lines[0]!.school_dispatch_release_line_id,
        );
    },
  );
  it("leaves PH3 and shared cooking without Dispatch membership separate", async () => {
    const docs = [
      dispatch(1, "main", "PHÚ HOÀ ĐÔNG 1"),
      dispatch(2, "PH1", "PHÚ HOÀ ĐÔNG 1"),
      dispatch(3, "PH2", "PHÚ HOÀ ĐÔNG 1"),
      dispatch(4, "PH3"),
    ];
    expect(
      visible(await book(await createGroupedSchoolDispatchXlsx(docs))),
    ).toHaveLength(2);
    const unrelated = [dispatch(5, "School A"), dispatch(6, "School B")];
    const z = await JSZip.loadAsync(
      await createSchoolDispatchZip(unrelated, "entity"),
    );
    expect(Object.values(z.files).filter((f) => !f.dir)).toHaveLength(2);
    expect(
      visible(await book(await createGroupedSchoolDispatchXlsx(unrelated))),
    ).toHaveLength(2);
  });
  it.each(["note", "unit", "ingredient", "date"] as const)(
    "never merges differing %s in one captured Dispatch group",
    async (dimension) => {
      const a = dispatch(1, "A", "group");
      const b = dispatch(2, "B", "group");
      if (dimension === "note") b.note = "Separate instructions";
      if (dimension === "unit") b.lines[0]!.unit_id = "another-unit";
      if (dimension === "ingredient")
        b.lines[0]!.ingredient_id = "another-item";
      if (dimension === "date") b.service_date = "2026-09-25";
      const result = await book(await createGroupedSchoolDispatchXlsx([a, b]));
      if (dimension === "date") expect(visible(result)).toHaveLength(2);
      else {
        expect(visible(result)).toHaveLength(1);
        expect([
          visible(result)[0]!.getCell("D11").text,
          visible(result)[0]!.getCell("D12").text,
        ]).toEqual(["0.100001", "0.100001"]);
      }
    },
  );
});
