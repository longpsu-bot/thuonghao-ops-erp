import assert from "node:assert/strict";
import { test } from "vitest";
import { reachReadyToReview } from "./staging-planning-browser.mjs";

test("corrected resume reaches review with zero Generate clicks", async () => {
  let clicks = 0;
  const review = {
    confirmed_need_batch_id: "a0311e0a-a4de-48b9-a529-fe7464a3352b",
    batch_version: 2,
    source_kind: "NEED_GENERATION",
    editing_allowed: true,
    blockers: [],
    pagination: { has_more: false },
    service_period: {
      period_start: "2026-09-17",
      period_end: "2026-09-17",
    },
    lines: Array.from({ length: 248 }, (_, index) => ({
      confirmed_need_line_id: `line-${index}`,
      current_decision_id: null,
      decision_history: [],
    })),
  };
  const result = await reachReadyToReview({
    mode: "D046_CORRECTED_RESUME",
    expectedBatchId: review.confirmed_need_batch_id,
    interval: 0,
    timeout: 100,
    evaluate: async (expression) =>
      expression.includes("rendered_rows:root?.querySelectorAll")
        ? { rendered_rows: 248, week_enabled: true, refresh_ready: true }
        : {
            week_value: "14/09/2026 – 20/09/2026",
            week_enabled: true,
            refresh_ready: true,
            loading: false,
            service_date: "2026-09-17",
            service_options: [
              "2026-09-14",
              "2026-09-15",
              "2026-09-16",
              "2026-09-17",
              "2026-09-18",
              "2026-09-19",
              "2026-09-20",
            ],
            service_enabled: true,
            generate_present: false,
            update_present: false,
            rendered_rows: 248,
          },
    readReview: async () => review,
    clickOnce: async () => {
      clicks += 1;
    },
  });
  assert.equal(result.generateClicks, 0);
  assert.equal(result.before, review);
  assert.equal(clicks, 0);
});
