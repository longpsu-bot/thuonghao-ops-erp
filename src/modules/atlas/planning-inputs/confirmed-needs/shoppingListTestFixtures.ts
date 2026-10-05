import { initialConfirmedNeedDraft } from "./confirmedNeedModel";
import { reviewBatch } from "../../../../vnext/atlas/planning-confirmed/confirmedNeedReviewFixtures";
export function shoppingFixture(date = "2026-09-07", day = 1) {
  const workbench = reviewBatch();
  const id = (n: number) =>
    `00000000-0000-4000-8000-${String(day * 1000 + n).padStart(12, "0")}`;
  workbench.confirmed_need_batch_id = id(1);
  workbench.need_generation_source.run_id = id(2);
  workbench.need_generation_source.release_snapshot_id = id(3);
  workbench.service_period = { period_start: date, period_end: date };
  workbench.lines.forEach((line, i) => {
    line.service_date = date;
    line.confirmed_need_line_id = id(100 + i);
    line.current_revision_id = id(200 + i);
    line.current_decision_id = id(300 + i);
    line.school.id = id(10 + (i % 2));
    line.delivery_location.id = id(20 + (i % 2));
    line.ingredient.id = id(400 + i);
    line.controlled_unit.id = id(30);
    line.controlled_unit.name = "kg";
    line.controlled_unit.code = "v1-unit-technical";
  });
  const drafts = Object.fromEntries(
    workbench.lines.map((l) => [
      l.confirmed_need_line_id,
      initialConfirmedNeedDraft(l),
    ]),
  );
  const supplierAdvice = Object.fromEntries(
    workbench.lines.map((l) => [l.confirmed_need_line_id, "NCC An Bình"]),
  );
  return { workbench, drafts, supplierAdvice };
}
