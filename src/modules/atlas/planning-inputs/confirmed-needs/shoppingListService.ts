import {
  loadCompleteConfirmedNeedReview,
  shoppingListRangeDates,
  type ShoppingListRangeContext,
  type ConfirmedNeedAuthorityReader,
} from "./confirmedNeedReadAuthority";
export {
  loadCompleteConfirmedNeedReview,
  shoppingListRangeDates,
} from "./confirmedNeedReadAuthority";
export type { ShoppingListRangeContext } from "./confirmedNeedReadAuthority";
import {
  confirmedNeedDraftMatchesSaved,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedWorkbenchData,
} from "./confirmedNeedModel";
import type { createPlanningInputReadinessApi } from "../readiness/planningInputReadinessApi";
import { planningInputPreflightFromResult } from "../readiness/planningInputReadinessModel";
import type { ShoppingListDailyBatch } from "./confirmedNeedShoppingList";
import { shoppingAssert } from "./shoppingListContract";

function cleanLocal(
  b: ConfirmedNeedWorkbenchData,
  drafts: Record<string, ConfirmedNeedDraftLine>,
) {
  return b.lines.every((line) => {
    const draft = drafts[line.confirmed_need_line_id];
    return draft && confirmedNeedDraftMatchesSaved(line, draft);
  });
}
function requireEditable(b: ConfirmedNeedWorkbenchData) {
  shoppingAssert(
    b.blockers.length === 0 &&
      b.lines.every(
        (line) => !line.source_stale && line.blockers.length === 0,
      ) &&
      b.editing_allowed &&
      b.allowed_actions.save_confirmed_needs &&
      ![b.batch_status, b.authoritative_batch_status].includes(
        "RELEASED_FOR_PURCHASE_HANDOFF",
      ),
    "READ_ONLY_WORKBENCH",
  );
}
export function createConnectedShoppingListService(
  api: ConfirmedNeedAuthorityReader,
  preflightApi: Pick<
    ReturnType<typeof createPlanningInputReadinessApi>,
    "preflight"
  >,
  subject: string,
) {
  async function current(batchId: string, date: string) {
    const result = await preflightApi.preflight(
      subject,
      crypto.randomUUID(),
      date,
      date,
    );
    const p = planningInputPreflightFromResult(result);
    shoppingAssert(
      p &&
        p.period_start === date &&
        p.period_end === date &&
        p.downstream_currentness === "CURRENT" &&
        p.readiness_state === "READY" &&
        !p.issues.some((issue) => issue.severity === "BLOCKING") &&
        p.current_need?.confirmed_need_batch_id === batchId,
      "STALE_AUTHORITY",
    );
    return p.current_need;
  }
  async function read(batchId: string, date: string, forExport = false) {
    const before = await current(batchId, date),
      b = await loadCompleteConfirmedNeedReview(
        api,
        subject,
        batchId,
        date,
        forExport,
      ),
      after = await current(batchId, date);
    shoppingAssert(
      JSON.stringify(before) === JSON.stringify(after) &&
        before.need_generation_run_id === b.need_generation_source.run_id &&
        before.confirmed_need_batch_version === b.batch_version,
      "STALE_AUTHORITY",
    );
    return b;
  }
  function scope(
    workbench: ConfirmedNeedWorkbenchData,
    context?: ShoppingListRangeContext,
  ) {
    const dates = shoppingListRangeDates(
      context?.range ?? {
        start: workbench.service_period.period_start,
        end: workbench.service_period.period_end,
      },
    );
    const batches = context?.workbenches ?? [workbench];
    for (const b of batches) {
      requireEditable(b);
      if (context)
        shoppingAssert(cleanLocal(b, context.drafts), "DIRTY_WORKBENCH");
    }
    shoppingAssert(
      !context?.isCurrent || context.isCurrent(),
      "STALE_AUTHORITY",
    );
    return { dates, batches };
  }
  return {
    async export(
      workbench: ConfirmedNeedWorkbenchData,
      context?: ShoppingListRangeContext,
    ) {
      const { dates, batches } = scope(workbench, context);
      const skipped: string[] = [];
      const daily: ShoppingListDailyBatch[] = [];
      // At most seven exact daily authorities; never infer missing reads as no demand.
      for (const date of dates) {
        const p = planningInputPreflightFromResult(
          await preflightApi.preflight(
            subject,
            crypto.randomUUID(),
            date,
            date,
          ),
        );
        shoppingAssert(
          p && p.period_start === date && p.period_end === date,
          "STALE_AUTHORITY",
        );
        if (
          !p.current_need &&
          p.downstream_currentness === "NOT_GENERATED" &&
          p.issues.some(
            (i) => i.issue_code === "NO_NEED_SOURCE_FOR_SERVICE_DATE",
          ) &&
          p.issues.every(
            (i) =>
              i.severity !== "BLOCKING" ||
              i.issue_code === "NO_NEED_SOURCE_FOR_SERVICE_DATE",
          )
        ) {
          skipped.push(date);
          continue;
        }
        const local = batches.find(
          (b) => b.service_period.period_start === date,
        );
        shoppingAssert(
          local &&
            p.downstream_currentness === "CURRENT" &&
            p.current_need?.confirmed_need_batch_id ===
              local.confirmed_need_batch_id,
          "STALE_AUTHORITY",
        );
        const b = await read(local.confirmed_need_batch_id, date, true);
        requireEditable(b);
        shoppingAssert(
          b.batch_version === local.batch_version,
          "STALE_AUTHORITY",
        );
        daily.push({ workbench: b, supplierAdvice: b.supplierAdvice });
      }
      shoppingAssert(
        !context?.isCurrent || context.isCurrent(),
        "STALE_AUTHORITY",
      );
      shoppingAssert(daily.length > 0, "NO_ELIGIBLE_DATES");
      const { downloadConfirmedNeedShoppingList } =
        await import("./confirmedNeedShoppingList");
      shoppingAssert(
        !context?.isCurrent || context.isCurrent(),
        "STALE_AUTHORITY",
      );
      await downloadConfirmedNeedShoppingList(daily);
      context?.onSkippedDates?.(skipped);
    },
    async import(
      file: File,
      workbench: ConfirmedNeedWorkbenchData,
      drafts: Record<string, ConfirmedNeedDraftLine>,
      context?: ShoppingListRangeContext,
    ) {
      const { dates, batches } = scope(workbench, context);
      shoppingAssert(cleanLocal(workbench, drafts), "DIRTY_WORKBENCH");
      const { readShoppingListEnvelope, validateShoppingListEnvelope } =
        await import("./shoppingListImport");
      const envelope = await readShoppingListEnvelope(await file.arrayBuffer());
      shoppingAssert(
        envelope.daily.length >= 1 &&
          envelope.daily.length <= 7 &&
          envelope.daily.every((d) => dates.includes(d.service_date)),
        "WORKBENCH_DATE_MISMATCH",
      );
      const fresh: ConfirmedNeedWorkbenchData[] = [];
      for (const day of envelope.daily) {
        const local = batches.find(
          (b) =>
            b.service_period.period_start === day.service_date &&
            b.confirmed_need_batch_id === day.confirmed_need_batch_id,
        );
        shoppingAssert(local, "WORKBENCH_DATE_MISMATCH");
        const b = await read(day.confirmed_need_batch_id, day.service_date);
        requireEditable(b);
        shoppingAssert(
          b.batch_version === local.batch_version,
          "STALE_AUTHORITY",
        );
        fresh.push(b);
      }
      shoppingAssert(
        !context?.isCurrent || context.isCurrent(),
        "STALE_AUTHORITY",
      );
      return validateShoppingListEnvelope(
        envelope,
        fresh,
        context?.drafts ?? drafts,
      );
    },
  };
}
