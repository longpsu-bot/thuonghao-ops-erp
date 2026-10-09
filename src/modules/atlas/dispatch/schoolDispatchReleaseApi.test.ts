import { describe, expect, it, vi } from "vitest";
import {
  createSchoolDispatchReleaseApi,
  releaseSchoolDispatchDocumentRequest,
  schoolDispatchReleaseReadRequest,
  schoolDispatchWorkbenchFromResult,
} from "./schoolDispatchReleaseApi";
import { createReviewSchoolDispatchWorkbench } from "./reviewSchoolDispatchReleaseApi";
import { buildSchoolDispatchPdfDefinition } from "./schoolDispatchReleaseExports";

describe("School dispatch release API", () => {
  it("exports historical captured grouping after current membership changes or disappears", () => {
    const response = createReviewSchoolDispatchWorkbench("current");
    Object.assign(response.rows[0]!.preview, {
      cooking_group_id: "group-y",
      cooking_group_name: "Bếp Y hiện tại",
    });
    Object.assign(response.rows[0]!.current_release!, {
      cooking_group_id: "group-x",
      cooking_group_name: "Bếp X lúc phát hành",
    });
    const legacy = structuredClone(response.rows[0]!.current_release!);
    delete legacy.cooking_group_id;
    delete legacy.cooking_group_name;
    response.rows[0]!.history.push(legacy);
    const parsed = schoolDispatchWorkbenchFromResult({
      kind: "success",
      response: JSON.parse(JSON.stringify(response)),
    })!;
    const historical = JSON.stringify(
      buildSchoolDispatchPdfDefinition(parsed.rows[0]!.current_release!),
    );
    expect(historical).toContain("NẤU TẠI: Bếp X lúc phát hành");
    expect(historical).not.toContain("Bếp Y hiện tại");
    expect(
      JSON.stringify(
        buildSchoolDispatchPdfDefinition(parsed.rows[0]!.history[1]!),
      ),
    ).not.toContain("NẤU TẠI:");
    Object.assign(response.rows[0]!.preview, {
      cooking_group_id: null,
      cooking_group_name: null,
    });
    const removed = schoolDispatchWorkbenchFromResult({
      kind: "success",
      response: JSON.parse(JSON.stringify(response)),
    })!;
    expect(
      JSON.stringify(
        buildSchoolDispatchPdfDefinition(removed.rows[0]!.current_release!),
      ),
    ).toContain("NẤU TẠI: Bếp X lúc phát hành");
  });
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
