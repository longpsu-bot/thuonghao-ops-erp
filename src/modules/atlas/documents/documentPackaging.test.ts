import { describe, expect, it } from "vitest";
import JSZip from "jszip";
import ExcelJS from "exceljs";
import { createReviewPurchaseOrdersFixture } from "../procurement/reviewSchoolCateringProcurementApi";
import { createPurchaseOrderZip } from "../procurement/purchaseOrderExports";
import { createReviewSchoolDispatchDocument } from "../dispatch/reviewSchoolDispatchReleaseApi";
import { createSchoolDispatchZip } from "../dispatch/schoolDispatchReleaseExports";

async function entries(bytes: Uint8Array) {
  return Object.values((await JSZip.loadAsync(bytes)).files).filter(
    (file) => !file.dir,
  );
}
describe("presentation-only released document packaging", () => {
  it("keeps official PO commitments separate and selects V1 sheets", async () => {
    const a =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    const b = structuredClone(a);
    b.purchase_order_id = "another-order";
    b.document_number = "PO-ANOTHER";
    b.status = "SUPERSEDED";
    const files = await entries(await createPurchaseOrderZip([b, a], "sum"));
    expect(files).toHaveLength(2);
    expect(files.map((f) => f.name).join()).toContain("PO-ANOTHER");
    for (const file of files) {
      const book = new ExcelJS.Workbook();
      await book.xlsx.load(await file.async("arraybuffer"));
      expect(book.worksheets.map((s) => s.name)).toEqual(["02-09-2026 - Tổng"]);
    }
    a.allowed_actions.export = false;
    await expect(createPurchaseOrderZip([a], "all")).rejects.toThrow();
    await expect(createPurchaseOrderZip([], "all")).rejects.toThrow();
  });
  it("groups Dispatch by date or captured School/location identity, never equal labels", async () => {
    const a = createReviewSchoolDispatchDocument("RELEASED");
    const b = structuredClone(a);
    b.school_dispatch_release_id = "different-release";
    b.document_number = "PXK-B";
    b.delivery_location_id = "different-location";
    expect(
      await entries(await createSchoolDispatchZip([b, a], "date")),
    ).toHaveLength(1);
    expect(
      await entries(await createSchoolDispatchZip([b, a], "entity")),
    ).toHaveLength(2);
    const c = structuredClone(a);
    c.school_dispatch_release_id = "later-release";
    c.document_number = "PXK-C";
    c.service_date = "2026-09-25";
    const file = (
      await entries(await createSchoolDispatchZip([c, a], "entity"))
    )[0]!;
    const book = new ExcelJS.Workbook();
    await book.xlsx.load(await file.async("arraybuffer"));
    expect(book.worksheets).toHaveLength(2);
    a.export_ready = false;
    await expect(createSchoolDispatchZip([a], "date")).rejects.toThrow();
    await expect(createSchoolDispatchZip([], "date")).rejects.toThrow();
    await expect(createSchoolDispatchZip([b, b], "entity")).rejects.toThrow();
  });
});
