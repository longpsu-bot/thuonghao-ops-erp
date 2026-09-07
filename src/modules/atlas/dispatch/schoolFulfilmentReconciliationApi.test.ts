import { describe, expect, it, vi } from "vitest";
import {
  createSchoolFulfilmentReconciliationApi,
  schoolFulfilmentReadRequest,
} from "./schoolFulfilmentReconciliationApi";

describe("School fulfilment reconciliation API", () => {
  it("builds the exact bounded read request", () => {
    expect(
      schoolFulfilmentReadRequest("subject-1", "correlation-1", {
        date_start: "2026-09-24",
        date_end: "2026-09-30",
        school_ids: ["school-1"],
        search: "PO-1",
      }),
    ).toEqual({
      contract_version: "SCHOOL-FULFILMENT-RECONCILIATION.v1",
      requested_by_auth_subject: "subject-1",
      correlation_id: "correlation-1",
      payload: {
        date_start: "2026-09-24",
        date_end: "2026-09-30",
        school_ids: ["school-1"],
        search: "PO-1",
      },
    });
  });
  it("invokes only the reviewed read route", async () => {
    const invoke = vi
      .fn()
      .mockResolvedValue({ kind: "success", response: { success: true } });
    const request = schoolFulfilmentReadRequest("s", "c", {
      date_start: "2026-09-24",
      date_end: "2026-09-24",
      school_ids: [],
      search: null,
    });
    await createSchoolFulfilmentReconciliationApi({ invoke }).getWorkbench(
      request,
    );
    expect(invoke).toHaveBeenCalledWith(
      "atlas_api.get_school_fulfilment_reconciliation_workbench",
      request,
    );
  });
});
