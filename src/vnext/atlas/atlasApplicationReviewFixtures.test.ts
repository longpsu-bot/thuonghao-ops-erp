import { describe, expect, it } from "vitest";
import {
  confirmedAllocationFromResult,
  confirmedAllocationReadRequest,
} from "./bridges/procurement";
import {
  applicationReviewDate,
  createAtlasApplicationFixture,
} from "./atlasApplicationReviewFixtures";

describe("Atlas application review fixtures", () => {
  it("assembles a coherent ready Procurement scenario on request", async () => {
    const apis = createAtlasApplicationFixture("ready");
    const result = await apis.purchaseReview.getConfirmedAllocations(
      confirmedAllocationReadRequest("fixture-operator", "fixture-ready", {
        date_start: applicationReviewDate,
        date_end: applicationReviewDate,
        school_ids: [],
        states: [],
        search: null,
      }),
    );
    const workbench = confirmedAllocationFromResult(result);

    expect(workbench?.preparation).toMatchObject({
      ready: true,
      allowed: true,
      blockers: [],
    });
    expect(workbench?.rows.some((row) => row.state === "BALANCED")).toBe(true);
  });
});
