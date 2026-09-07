import { describe, expect, it, vi } from "vitest";
import {
  createSchoolDispatchReleaseApi,
  releaseSchoolDispatchDocumentRequest,
  schoolDispatchReleaseReadRequest,
} from "./schoolDispatchReleaseApi";

describe("School dispatch release API", () => {
  it("builds the bounded School/date workbench request", () => {
    expect(
      schoolDispatchReleaseReadRequest("subject-1", "correlation-1", {
        date_start: "2026-09-24",
        date_end: "2026-09-30",
        school_ids: ["school-1"],
        search: "Nguyễn Du",
      }),
    ).toEqual({
      contract_version: "SCHOOL-DISPATCH-RELEASE.v1",
      requested_by_auth_subject: "subject-1",
      correlation_id: "correlation-1",
      payload: {
        date_start: "2026-09-24",
        date_end: "2026-09-30",
        school_ids: ["school-1"],
        search: "Nguyễn Du",
      },
    });
  });

  it("builds an explicit fingerprint-bound release and replacement request", () => {
    const request = releaseSchoolDispatchDocumentRequest(
      "subject-1",
      "correlation-1",
      1,
      {
        service_date: "2026-09-24",
        school_id: "school-1",
        delivery_location_id: "location-1",
        expected_source_fingerprint: "a".repeat(64),
        predecessor_release_id: "release-1",
      },
    );
    expect(request).toMatchObject({
      contract_version: "SCHOOL-DISPATCH-RELEASE.v1",
      expected_version: 1,
      reason_code: "SCHOOL_DISPATCH_DOCUMENT_RELEASED",
      reason_note: null,
      payload: {
        service_date: "2026-09-24",
        school_id: "school-1",
        delivery_location_id: "location-1",
        expected_source_fingerprint: "a".repeat(64),
        predecessor_release_id: "release-1",
      },
    });
    expect(request.command_id).toEqual(expect.any(String));
    expect(request.idempotency_key).toContain(request.command_id);
  });

  it("trims an optional immutable note into the release request", () => {
    const request = releaseSchoolDispatchDocumentRequest(
      "subject-1",
      "correlation-1",
      0,
      {
        service_date: "2026-09-24",
        school_id: "school-1",
        delivery_location_id: "location-1",
        expected_source_fingerprint: "a".repeat(64),
        predecessor_release_id: null,
      },
      "  Giao tại cổng phụ trước 06:00  ",
    );

    expect(request.reason_note).toBe("Giao tại cổng phụ trước 06:00");
  });

  it("invokes only the reviewed read and release routes", async () => {
    const invoke = vi.fn().mockResolvedValue({
      kind: "success",
      response: { success: true },
    });
    const api = createSchoolDispatchReleaseApi({ invoke });
    const read = schoolDispatchReleaseReadRequest("s", "c", {
      date_start: "2026-09-24",
      date_end: "2026-09-24",
      school_ids: [],
      search: null,
    });
    const release = releaseSchoolDispatchDocumentRequest("s", "c", 0, {
      service_date: "2026-09-24",
      school_id: "school-1",
      delivery_location_id: "location-1",
      expected_source_fingerprint: "b".repeat(64),
      predecessor_release_id: null,
    });
    await api.getWorkbench(read);
    await api.releaseDocument(release);
    expect(invoke).toHaveBeenNthCalledWith(
      1,
      "atlas_api.get_school_dispatch_release_workbench",
      read,
    );
    expect(invoke).toHaveBeenNthCalledWith(
      2,
      "atlas_api.release_school_dispatch_document",
      release,
    );
  });
});
