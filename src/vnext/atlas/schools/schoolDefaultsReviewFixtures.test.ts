import { describe, expect, it } from "vitest";
import {
  createSchoolDefaultsReviewFixture,
  schoolDefaultsFixtureSchools,
  type SchoolDefaultsScenario,
} from "./schoolDefaultsReviewFixtures";
import type { MasterDataBulkCommandRequest } from "../bridges/schoolMasterData";

const scenarios: SchoolDefaultsScenario[] = [
  "NORMAL",
  "MULTIPLE_SCHOOL_TYPES",
  "INACTIVE_SCHOOL",
  "DIRTY_ONE",
  "DIRTY_MANY",
  "DIRTY_HIDDEN_BY_SEARCH",
  "INVALID_BLANK",
  "INVALID_NEGATIVE",
  "INVALID_DECIMAL",
  "INVALID_OVERFLOW",
  "STALE_VERSION",
  "UNKNOWN_SAVE",
  "SUCCESS_THEN_READ_FAILURE",
  "PERMISSION_DENIED",
  "READ_FAILURE",
  "EMPTY",
  "AUTH_CHANGE_DELAYED_READ",
];

describe("School defaults review fixtures", () => {
  it("provides the complete deterministic scenario registry and 34-School context", () => {
    expect(scenarios).toHaveLength(17);
    expect(schoolDefaultsFixtureSchools).toHaveLength(34);
    expect(
      new Set(
        schoolDefaultsFixtureSchools.map((school) => school.school_type_name),
      ).size,
    ).toBeGreaterThan(2);
    expect(
      schoolDefaultsFixtureSchools.some(
        (school) => school.school_status === "INACTIVE",
      ),
    ).toBe(true);
  });

  it("returns explicit stale, unknown, permission, read-failure, and empty snapshots", async () => {
    const command = {
      contract_version: "RMVP-01.v2",
      command_id: "command-1",
      correlation_id: "correlation-1",
      idempotency_key: "key-1",
      requested_by_auth_subject: "operator-1",
      requested_at: "2026-09-12T00:00:00.000Z",
      reason_code: "SCHOOL_PORTION_DEFAULTS_BULK_UPDATE",
      reason_note: null,
      payload: { changes: [] },
    } satisfies MasterDataBulkCommandRequest;
    await expect(
      createSchoolDefaultsReviewFixture(
        "STALE_VERSION",
      ).updateSchoolDefaultsBulk(command),
    ).resolves.toMatchObject({
      kind: "backend_error",
      error: { error_code: "STALE_VERSION" },
    });
    await expect(
      createSchoolDefaultsReviewFixture(
        "UNKNOWN_SAVE",
      ).updateSchoolDefaultsBulk(command),
    ).resolves.toMatchObject({ kind: "transport_error" });
    await expect(
      createSchoolDefaultsReviewFixture(
        "PERMISSION_DENIED",
      ).updateSchoolDefaultsBulk(command),
    ).resolves.toMatchObject({
      kind: "backend_error",
      error: { error_code: "CAPABILITY_DENIED" },
    });
    await expect(
      createSchoolDefaultsReviewFixture("READ_FAILURE").getSchools(
        "operator-1",
        "correlation-1",
      ),
    ).resolves.toMatchObject({ kind: "transport_error" });
    await expect(
      createSchoolDefaultsReviewFixture("EMPTY").getSchools(
        "operator-1",
        "correlation-1",
      ),
    ).resolves.toMatchObject({ kind: "success", response: { schools: [] } });
  });
});
