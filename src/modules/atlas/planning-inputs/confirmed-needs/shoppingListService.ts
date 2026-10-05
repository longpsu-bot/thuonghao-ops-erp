import type { ConfirmedNeedApi } from "./confirmedNeedApi";
import { confirmedNeedReadRequest } from "./confirmedNeedApi";
import {
  confirmedNeedWorkbenchFromResult,
  confirmedNeedDraftMatchesSaved,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedWorkbenchData,
} from "./confirmedNeedModel";
import type { createPlanningInputReadinessApi } from "../readiness/planningInputReadinessApi";
import { planningInputPreflightFromResult } from "../readiness/planningInputReadinessModel";
import {
  downloadConfirmedNeedShoppingList,
  type ShoppingListDailyBatch,
} from "./confirmedNeedShoppingList";
import {
  readShoppingListEnvelope,
  validateShoppingListEnvelope,
} from "./shoppingListImport";
import {
  ShoppingListError,
  shoppingAssert,
  shoppingListContract as contract,
} from "./shoppingListContract";
import type { AtlasRpcResult } from "../../connection/atlasRpc";

type Reader = Pick<ConfirmedNeedApi, "getReview"> &
  Partial<Pick<ConfirmedNeedApi, "getShoppingListExport">>;
function coherent(b: ConfirmedNeedWorkbenchData) {
  return JSON.stringify({
    id: b.confirmed_need_batch_id,
    version: b.batch_version,
    source: b.need_generation_source,
    period: b.service_period,
    total: b.line_counts,
    paginationTotal: b.pagination.total_lines,
    status: b.batch_status,
    editing: b.editing_allowed,
    actions: b.allowed_actions,
    blockers: b.blockers,
  });
}
export async function loadCompleteConfirmedNeedReview(
  api: Reader,
  subject: string,
  batchId: string,
  date: string,
  forExport = false,
): Promise<
  ConfirmedNeedWorkbenchData & { supplierAdvice: Record<string, string> }
> {
  let offset = 0,
    first: ConfirmedNeedWorkbenchData | null = null;
  const lines: ConfirmedNeedWorkbenchData["lines"] = [],
    seen = new Set<string>(),
    supplierAdvice: Record<string, string> = {};
  const correlation = crypto.randomUUID();
  while (true) {
    shoppingAssert(
      offset <= contract.resourceLimits.dataLines,
      "RESOURCE_LIMIT",
    );
    let result: AtlasRpcResult;
    if (forExport) {
      shoppingAssert(api.getShoppingListExport, "MISSING_EXPORT_RPC");
      result = await api.getShoppingListExport(
        confirmedNeedReadRequest(
          subject,
          correlation,
          batchId,
          {
            service_date: date,
            school_id: null,
            delivery_location_id: null,
            ingredient_id: null,
            decision_state: null,
          },
          offset,
          1000,
        ),
      );
    } else
      result = await api.getReview(
        subject,
        correlation,
        batchId,
        {
          service_date: date,
          school_id: null,
          delivery_location_id: null,
          ingredient_id: null,
          decision_state: null,
        },
        offset,
        1000,
      );
    const page = confirmedNeedWorkbenchFromResult(result);
    shoppingAssert(
      page &&
        page.confirmed_need_batch_id === batchId &&
        page.service_period.period_start === date &&
        page.service_period.period_end === date &&
        page.pagination.offset === offset &&
        page.pagination.total_lines > 0 &&
        page.pagination.total_lines <= contract.resourceLimits.dataLines &&
        page.line_counts.total === page.pagination.total_lines,
      "INCOMPLETE_AUTHORITY",
    );
    shoppingAssert(
      !first || coherent(first) === coherent(page),
      "INCONSISTENT_PAGINATION",
    );
    first ??= page;
    shoppingAssert(
      page.lines.length > 0 &&
        page.lines.length <= page.pagination.limit &&
        offset + page.lines.length <= page.pagination.total_lines,
    );
    for (const line of page.lines) {
      shoppingAssert(
        line.service_date === date && !seen.has(line.confirmed_need_line_id),
      );
      seen.add(line.confirmed_need_line_id);
      lines.push(line);
    }
    if (forExport) {
      shoppingAssert(result.kind === "success");
      const advice = result.response.shopping_list_supplier_advice;
      shoppingAssert(
        advice &&
          typeof advice === "object" &&
          !Array.isArray(advice) &&
          Object.keys(advice).length === page.lines.length,
        "MISSING_SUPPLIER_READ",
      );
      for (const l of page.lines) {
        const name = advice[l.confirmed_need_line_id];
        shoppingAssert(typeof name === "string");
        supplierAdvice[l.confirmed_need_line_id] = name;
      }
    }
    offset += page.lines.length;
    shoppingAssert(
      page.pagination.has_more === offset < page.pagination.total_lines,
      "INCONSISTENT_PAGINATION",
    );
    if (!page.pagination.has_more) break;
  }
  shoppingAssert(first && lines.length === first.pagination.total_lines);
  return {
    ...first,
    lines,
    pagination: {
      offset: 0,
      limit: lines.length,
      total_lines: lines.length,
      has_more: false,
    },
    supplierAdvice,
  };
}
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
    b.editing_allowed &&
      b.allowed_actions.save_confirmed_needs &&
      ![b.batch_status, b.authoritative_batch_status].includes(
        "RELEASED_FOR_PURCHASE_HANDOFF",
      ),
    "READ_ONLY_WORKBENCH",
  );
}
export function createConnectedShoppingListService(
  api: Reader,
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
  return {
    async export(workbench: ConfirmedNeedWorkbenchData) {
      requireEditable(workbench);
      const date = workbench.service_period.period_start,
        b = await read(workbench.confirmed_need_batch_id, date, true);
      requireEditable(b);
      shoppingAssert(
        b.batch_version === workbench.batch_version,
        "STALE_AUTHORITY",
      );
      const daily: ShoppingListDailyBatch = {
        workbench: b,
        supplierAdvice: b.supplierAdvice,
      };
      await downloadConfirmedNeedShoppingList([daily]);
    },
    async import(
      file: File,
      workbench: ConfirmedNeedWorkbenchData,
      drafts: Record<string, ConfirmedNeedDraftLine>,
    ) {
      requireEditable(workbench);
      shoppingAssert(cleanLocal(workbench, drafts), "DIRTY_WORKBENCH");
      const envelope = await readShoppingListEnvelope(await file.arrayBuffer());
      const date = workbench.service_period.period_start;
      if (envelope.daily.length !== 1)
        throw new ShoppingListError(
          "MULTI_DATE_UI_DEFERRED_BY_EXACT_DAY_WORKBENCH",
          "Phiếu đi chợ có nhiều ngày hợp lệ. Màn hình này chỉ nhập ngày đang mở; hãy dùng Phiếu đi chợ cho một ngày.",
        );
      shoppingAssert(
        envelope.daily[0]!.service_date === date &&
          envelope.daily[0]!.confirmed_need_batch_id ===
            workbench.confirmed_need_batch_id,
        "WORKBENCH_DATE_MISMATCH",
      );
      const fresh = await read(workbench.confirmed_need_batch_id, date);
      shoppingAssert(
        fresh.batch_version === workbench.batch_version,
        "STALE_AUTHORITY",
      );
      return validateShoppingListEnvelope(envelope, [fresh], drafts);
    },
  };
}
