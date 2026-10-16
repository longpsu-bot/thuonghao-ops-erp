import { describe, it, expect } from "vitest";
import { createConfirmedNeedReviewFixture } from "./confirmedNeedReviewFixtures";
import {
  confirmedNeedCorrectionPreviewRequest,
  confirmedNeedCorrectionCommandRequest,
  confirmedNeedCorrectionPreviewFromResult,
  confirmedNeedSaveV2Request,
  confirmedNeedWorkbenchFromResult,
} from "../bridges/confirmedNeed";
function requestFor(
  fixture: ReturnType<typeof createConfirmedNeedReviewFixture>,
) {
  const b = fixture.batch,
    l = b.lines[0]!;
  return confirmedNeedCorrectionPreviewRequest("actor", "correlation", {
    need_generation_run_id: b.need_generation_source.run_id,
    expected_need_generation_run_version: b.need_generation_source.run_version,
    confirmed_need_batch_id: b.confirmed_need_batch_id,
    expected_confirmed_need_batch_version: b.batch_version,
    confirmed_need_line_id: l.confirmed_need_line_id,
    expected_current_revision_id: l.current_revision_id,
    expected_current_decision_id: l.current_decision_id!,
    proposed_confirmed_quantity: "12.500001",
    reason_code: "OTHER",
    reason_note: "Bếp điều chỉnh",
  });
}
describe("dated correction review adapter", () => {
  it("uses internal dated identities and keeps full family School membership despite presentation filters", async () => {
    const f = createConfirmedNeedReviewFixture("released", "2026-10-12"),
      other = createConfirmedNeedReviewFixture("released", "2026-10-13");
    f.batch.lines[1]!.ingredient = structuredClone(
      f.batch.lines[0]!.ingredient,
    );
    f.batch.lines[1]!.delivery_location = structuredClone(
      f.batch.lines[0]!.delivery_location,
    );
    const request = requestFor(f),
      preview = confirmedNeedCorrectionPreviewFromResult(
        await f.confirmedNeedApi.previewCorrection(request),
        request.payload,
      );
    expect(preview?.family.service_date).toBe("2026-10-12");
    expect(preview?.family.contributions.map((l) => l.school_id)).toEqual([
      "school-0",
      "school-1",
    ]);
    expect(preview?.display.schools).toHaveLength(2);
    const denied = await other.confirmedNeedApi.previewCorrection(request);
    expect(denied.kind).toBe("backend_error");
    expect(other.batch.lines[0]!.confirmed_quantity_after).toBe("10.250000");
  });
  it("appends only the selected line and replays original success after an ordinary later Save", async () => {
    const f = createConfirmedNeedReviewFixture("released", "2026-10-12"),
      request = requestFor(f),
      old = f.batch.lines.map((l) => ({
        r: l.current_revision_id,
        d: l.current_decision_id,
      }));
    const preview = confirmedNeedCorrectionPreviewFromResult(
      await f.confirmedNeedApi.previewCorrection(request),
      request.payload,
    )!;
    const command = confirmedNeedCorrectionCommandRequest(
        "actor",
        "correlation",
        preview.target,
        preview.proposal_fingerprint,
      ),
      answer = await f.confirmedNeedApi.correct(command);
    expect(
      f.batch.lines
        .slice(1)
        .map((l) => ({ r: l.current_revision_id, d: l.current_decision_id })),
    ).toEqual(old.slice(1));
    expect(
      f.batch.lines[0]!.decision_history.at(-1)?.predecessor_decision_id,
    ).toBe(old[0]!.d);
    const line = f.batch.lines[0]!;
    await f.confirmedNeedApi.save(
      confirmedNeedSaveV2Request(
        "actor",
        "later",
        f.batch.confirmed_need_batch_id,
        f.batch.batch_version,
        [
          {
            confirmed_need_line_id: line.confirmed_need_line_id,
            expected_current_revision_id: line.current_revision_id,
            expected_current_decision_id: line.current_decision_id,
            proposed_confirmed_quantity: "13.000000",
            reason_code: "OTHER",
            reason_note: "Sau điều chỉnh",
          },
        ],
      ),
    );
    expect(await f.confirmedNeedApi.correct(command)).toEqual(answer);
    const read = confirmedNeedWorkbenchFromResult(
      await f.confirmedNeedApi.getReview(
        "actor",
        "read",
        f.batch.confirmed_need_batch_id,
        {
          service_date: "2026-10-12",
          school_id: null,
          delivery_location_id: null,
          ingredient_id: null,
          decision_state: null,
        },
      ),
    );
    expect(read?.batch_version).toBe(7);
    expect(read?.lines[0]?.confirmed_quantity_after).toBe("13.000000");
    expect(read?.service_period.period_start).toBe("2026-10-12");
  });
  it.each([
    "correction_shared",
    "correction_authority",
    "correction_unknown",
    "correction_readback",
    "correction_pending",
  ] as const)(
    "keeps %s date-aligned full-family review and exact recovery",
    async (scenario) => {
      const f = createConfirmedNeedReviewFixture(scenario, "2026-10-12");
      const request = requestFor(f);
      const result = await f.confirmedNeedApi.previewCorrection(request);
      const preview = confirmedNeedCorrectionPreviewFromResult(
        result,
        request.payload,
      );
      expect(preview?.family.service_date).toBe("2026-10-12");
      expect(preview?.family.contributions).toHaveLength(2);
      expect(preview?.allowed_actions.correct).toBe(
        scenario !== "correction_authority",
      );
      if (scenario === "correction_authority") return;
      const command = confirmedNeedCorrectionCommandRequest(
        "actor",
        "correlation",
        request.payload,
        preview!.proposal_fingerprint,
      );
      const write = await f.confirmedNeedApi.correct(command);
      expect(write.kind).toBe(
        scenario === "correction_unknown" ? "transport_error" : "success",
      );
      const replay = await f.confirmedNeedApi.correct(command);
      expect(replay.kind).toBe("success");
      if (scenario === "correction_readback")
        expect(
          (
            await f.confirmedNeedApi.getReview(
              "actor",
              "correlation",
              f.batch.confirmed_need_batch_id,
              {
                service_date: "2026-10-12",
                school_id: null,
                delivery_location_id: null,
                ingredient_id: null,
                decision_state: null,
              },
            )
          ).kind,
        ).toBe("backend_error");
      expect(f.batch.authoritative_batch_status).toBe("REOPENED");
      expect(f.batch.lines[0]!.confirmed_quantity_after).toBe("12.500001");
      expect(f.batch.lines[6]!.current_revision_id).toBe(
        "revision-6-2026-10-12",
      );
    },
  );
});
