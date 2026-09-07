import type { AtlasSuccessEnvelope } from "../connection/atlasRpc";
import type { SchoolFulfilmentReconciliationApi } from "./schoolFulfilmentReconciliationApi";
import type { SchoolFulfilmentWorkbenchData } from "./schoolFulfilmentReconciliationModel";

export function createReviewSchoolFulfilmentReconciliationApi(): SchoolFulfilmentReconciliationApi {
  return {
    async getWorkbench() {
      const response: SchoolFulfilmentWorkbenchData = {
        success: true,
        contract_version: "SCHOOL-FULFILMENT-RECONCILIATION.v1",
        date_start: "2026-09-24",
        date_end: "2026-09-24",
        rows: [
          {
            service_date: "2026-09-24",
            school_id: "26000000-0000-4000-8000-000000000001",
            school_name: "Trường Tiểu học Nguyễn Du",
            delivery_location_id: "26000000-0000-4000-8000-000000000002",
            delivery_location_name: "Bếp chính Nguyễn Du",
            comparison_status: "OK",
            quantity_totals_by_unit: [
              {
                unit_id: "26000000-0000-4000-8000-000000000003",
                unit_code: "kg",
                po_quantity: "100.000000",
                pxk_quantity: "100.000000",
                delta_quantity: "0.000000",
              },
            ],
            purchase_order_numbers: ["PO-20260924-001"],
            purchase_order_ids: [],
            pxk_document_number: "PXK-20260924-001",
            school_dispatch_release_id: null,
            pxk_state: "CURRENT",
            blockers: [],
            warnings: [],
            history: [],
            details: [
              {
                ingredient_id: "26000000-0000-4000-8000-000000000004",
                ingredient_name: "Gạo thơm",
                unit_id: "26000000-0000-4000-8000-000000000003",
                unit_code: "kg",
                po_quantity: "100.000000",
                pxk_quantity: "100.000000",
                delta_quantity: "0.000000",
              },
            ],
          },
        ],
        warnings: [],
        blockers: [],
      };
      return {
        kind: "success",
        response: response as unknown as AtlasSuccessEnvelope,
      };
    },
  };
}
