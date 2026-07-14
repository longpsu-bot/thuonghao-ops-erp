import { describe, expect, it } from "vitest";
import {
  AssignSchoolType,
  CreateSchool,
  SchoolAdminWorkbench,
  SchoolPlanningReference,
  SetSchoolDeliveryLocation,
  SetSchoolDisplayOrder,
  SetSchoolServiceRule,
  SetSchoolStatus,
} from "./schoolAdminDomain";
import { schoolAdminFixture } from "./schoolAdminFixtures";

const at = "2026-07-14T05:00:00.000Z";
const actorId = "admin-lan";
const active = schoolAdminFixture.schools[0];

describe("School Admin foundation", () => {
  it("blocks missing school names and duplicate active identities", () => {
    const missing = CreateSchool(schoolAdminFixture, {
      ...active,
      schoolId: "school-new",
      schoolName: " ",
      actorId,
      at,
      reason: "Create",
    });
    expect(missing.accepted).toBe(false);
    expect(missing.blockers.map((issue) => issue.issueCode)).toContain(
      "SCHOOL_NAME_MISSING",
    );
    const duplicate = CreateSchool(schoolAdminFixture, {
      ...active,
      schoolId: "school-duplicate",
      schoolName: `  ${active.schoolName}  `,
      actorId,
      at,
      reason: "Create",
    });
    expect(duplicate.accepted).toBe(false);
    expect(duplicate.blockers.map((issue) => issue.issueCode)).toContain(
      "DUPLICATE_ACTIVE_SCHOOL",
    );
  });
  it("identifies missing planning type and fulfilment delivery location", () => {
    const inactive = SchoolAdminWorkbench(schoolAdminFixture).schools.find(
      (school) => school.schoolId === "school-minh-an",
    )!;
    expect(inactive.issues.map((issue) => issue.issueCode)).toEqual(
      expect.arrayContaining([
        "SCHOOL_TYPE_MISSING",
        "DELIVERY_LOCATION_MISSING",
      ]),
    );
  });
  it("blocks inactive schools for new Planning unless explicit override evidence exists", () => {
    expect(
      SchoolPlanningReference(schoolAdminFixture.schools[1]).accepted,
    ).toBe(false);
    expect(
      SchoolPlanningReference(
        schoolAdminFixture.schools[1],
        "approved exception-17",
      ).accepted,
    ).toBe(true);
  });
  it("records explicit and auditable status, display order, and service rule changes", () => {
    const reordered = SetSchoolDisplayOrder(schoolAdminFixture, {
      schoolId: active.schoolId,
      displayOrder: 99,
      actorId,
      at,
      reason: "Sort review",
    });
    expect(
      reordered.state.schools[0].masterDataChanges.at(-1)?.changeType,
    ).toBe("SchoolDisplayOrderChanged");
    const service = SetSchoolServiceRule(reordered.state, {
      schoolId: active.schoolId,
      serviceCalendarId: "weekday-morning",
      actorId,
      at,
      reason: "Service review",
    });
    expect(service.state.schools[0].masterDataChanges.at(-1)?.changeType).toBe(
      "SchoolServiceRuleChanged",
    );
    const status = SetSchoolStatus(service.state, {
      schoolId: active.schoolId,
      status: "INACTIVE",
      actorId,
      at,
      reason: "Temporary pause",
    });
    expect(status.state.schools[0].statusChanges).toHaveLength(1);
    expect(status.state.schools[0].masterDataChanges.at(-1)?.changeType).toBe(
      "SchoolDeactivated",
    );
  });
  it("keeps Admin edits local and does not introduce downstream or integration behavior", () => {
    const before = JSON.stringify(schoolAdminFixture);
    const typed = AssignSchoolType(schoolAdminFixture, {
      schoolId: active.schoolId,
      schoolTypeId: "kindergarten",
      actorId,
      at,
      reason: "Profile correction",
    });
    const located = SetSchoolDeliveryLocation(typed.state, {
      schoolId: active.schoolId,
      deliveryLocationId: "nd-central-kitchen",
      actorId,
      at,
      reason: "Location correction",
    });
    expect(located.accepted).toBe(true);
    expect(JSON.stringify(schoolAdminFixture)).toBe(before);
    for (const forbidden of [
      "planning",
      "procurement",
      "warehouse",
      "dispatch",
      "qa",
      "finance",
      "supabase",
      "retool",
      "backend",
      "credential",
      "productionData",
    ])
      expect(forbidden in located.state.schools[0]).toBe(false);
  });
});
