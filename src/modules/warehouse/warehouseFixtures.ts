import { RecordSupplierConfirmation } from "../procurement/procurementDomain";
import { releasedPurchaseOrderFixture } from "../procurement/procurementFixtures";
import { CreateReceivingSessionFromSupplierConfirmedPO } from "./warehouseDomain";
export const supplierConfirmedPurchaseOrderFixture = RecordSupplierConfirmation(
  releasedPurchaseOrderFixture,
  {
    confirmationStatus: "ACCEPTED",
    confirmedBy: "supplier-contact",
    at: "2026-07-14T02:35:00.000Z",
    confirmedLineIds: releasedPurchaseOrderFixture.lines.map(
      (x) => x.purchaseOrderLineId,
    ),
  },
).purchaseOrder!;
export const receivingSessionFixture =
  CreateReceivingSessionFromSupplierConfirmedPO(
    supplierConfirmedPurchaseOrderFixture,
    "warehouse-mai",
    "2026-07-14T03:00:00.000Z",
  ).value!;
