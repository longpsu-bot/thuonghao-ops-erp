import { describe, expect, it } from "vitest";
import {
  schoolDefaultsBulkCommandRequest,
  type SchoolDefaultsBulkChange,
  type SchoolMasterData,
} from "./schoolMasterData";

describe("School master-data bridge", () => {
  it("exposes the reviewed bulk request builder without aggregate version metadata", () => {
    const school = {
      school_id: "school-1",
      version: 7,
    } as SchoolMasterData;
    const changes: SchoolDefaultsBulkChange[] = [
      {
        school_id: school.school_id,
        expected_version: school.version,
        default_student_portions: 420,
        default_teacher_portions: 32,
      },
    ];

    const request = schoolDefaultsBulkCommandRequest(
      "operator-1",
      "correlation-1",
      changes,
    );

    expect(request).toMatchObject({
      contract_version: "RMVP-01.v2",
      requested_by_auth_subject: "operator-1",
      reason_code: "SCHOOL_PORTION_DEFAULTS_BULK_UPDATE",
      payload: { changes },
    });
    expect(request).not.toHaveProperty("expected_version");
  });
});
