import { describe, expect, it } from "vitest";
import { proposalProfiles } from "./profile-local-need-proposal.mjs";

describe("executed Need proposal profile", () => {
  it("reads nested plans and quoted JSON without counting unrelated scans", () => {
    const plan = {
      "Query Text": "with proposal_resolution as (select '\"}') insert",
      Plan: {
        "Shared Hit Blocks": 50,
        Plans: [
          {
            "Relation Name": "need_generation_release_snapshot_lines",
            "Actual Loops": 304,
            "Actual Rows": 1,
            "Rows Removed by Filter": 2,
          },
          { "Relation Name": "other", "Actual Loops": 100, "Actual Rows": 100 },
        ],
      },
    };
    expect(
      proposalProfiles(
        `NOTICE: duration: 12.5 ms plan: ${JSON.stringify(plan)}\nnoise`,
      ),
    ).toEqual([
      {
        proposal_ms: 12.5,
        shared_hits: 50,
        release_member_scans: 304,
        release_member_visits: 912,
        source_members: 304,
        retained_source_members: 304,
      },
    ]);
  });
  it("fails closed when actual proposal or membership evidence is missing", () => {
    expect(() => proposalProfiles("no executed plans")).toThrow(
      "must be present",
    );
    expect(() =>
      proposalProfiles(
        'NOTICE: duration: 1 ms plan: {"Query Text":"with proposal_resolution","Plan":{}}',
      ),
    ).toThrow("must actually read");
  });
  it("includes retained prior days when bounding repeated source reads", () => {
    const statement = (loops) =>
      `NOTICE: duration: 1 ms plan: ${JSON.stringify({
        "Query Text": "with released_contributions as materialized",
        Plan: {
          "Relation Name": "need_generation_release_snapshot_lines",
          "Actual Loops": loops,
          "Actual Rows": 1,
        },
      })}`;
    const observations = proposalProfiles(
      statement(304) + "\n" + statement(608),
    );
    expect(observations.map((p) => p.retained_source_members)).toEqual([
      304, 608,
    ]);
    expect(
      observations.every(
        (p) => p.release_member_scans <= p.retained_source_members,
      ),
    ).toBe(true);
    const fanout = proposalProfiles(statement(75392));
    expect(
      fanout.every((p) => p.release_member_scans <= p.retained_source_members),
    ).toBe(false);
  });
});
