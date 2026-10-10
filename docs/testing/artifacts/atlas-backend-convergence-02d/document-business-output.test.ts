import { expect, it } from "vitest";
import type { TDocumentDefinitions } from "pdfmake/interfaces";
import { createReviewPurchaseOrdersFixture } from "../../../../src/modules/atlas/procurement/reviewSchoolCateringProcurementApi";
import {
  buildPurchaseOrderExportData,
  buildPurchaseOrderPdfDefinition,
} from "../../../../src/modules/atlas/procurement/purchaseOrderExports";
import { createReviewSchoolDispatchDocument } from "../../../../src/modules/atlas/dispatch/reviewSchoolDispatchReleaseApi";
import {
  buildSchoolDispatchExportData,
  buildSchoolDispatchPdfDefinition,
} from "../../../../src/modules/atlas/dispatch/schoolDispatchReleaseExports";

function evaluatedPdf(definition: TDocumentDefinitions) {
  const pageSize = {
    width: 595.28,
    height: 841.89,
    orientation: "portrait" as const,
  };
  return {
    ...definition,
    // Compare printed footer output, not the identity of a newly created callback.
    footer:
      typeof definition.footer === "function"
        ? [definition.footer(1, 2, pageSize), definition.footer(2, 2, pageSize)]
        : definition.footer,
  };
}

it("repeat PO document generation preserves the issued facts, exact quantity, Unit, note and School breakdown", () => {
  const order =
    createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
  order.lines[0]!.supplier_note = "Giao trước 05:30";
  const original = structuredClone(order);
  const first = buildPurchaseOrderExportData(order);
  const firstPdf = buildPurchaseOrderPdfDefinition(order);
  expect(buildPurchaseOrderExportData(order)).toEqual(first);
  expect(evaluatedPdf(buildPurchaseOrderPdfDefinition(order))).toEqual(
    evaluatedPdf(firstPdf),
  );
  expect(order).toEqual(original);
  expect(first.summaryLines[0]).toMatchObject({
    supplierNote: "Giao trước 05:30",
    orderedQuantity: order.lines[0]!.ordered_quantity,
    unitCode: order.lines[0]!.unit.unit_code,
  });
  expect(first.schoolLines).not.toHaveLength(0);
});

it("repeat PXK document generation preserves released School/location evidence", () => {
  const document = createReviewSchoolDispatchDocument("RELEASED");
  const original = structuredClone(document);
  const first = buildSchoolDispatchExportData(document);
  const firstPdf = buildSchoolDispatchPdfDefinition(document);
  expect(buildSchoolDispatchExportData(document)).toEqual(first);
  expect(evaluatedPdf(buildSchoolDispatchPdfDefinition(document))).toEqual(
    evaluatedPdf(firstPdf),
  );
  expect(document).toEqual(original);
  expect(first.lines[0]).toMatchObject({
    quantity: document.lines[0]!.quantity,
    unitCode: document.lines[0]!.unit_code,
  });
});
