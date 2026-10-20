// Complete exact-day authority reads and local range context. No UI or workbook IO.
import type { ConfirmedNeedApi } from "./confirmedNeedApi";
import { confirmedNeedReadRequest } from "./confirmedNeedApi";
import {
  confirmedNeedWorkbenchFromResult,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedWorkbenchData,
} from "./confirmedNeedModel";
import {
  shoppingAssert,
  shoppingListContract as contract,
} from "./shoppingListContract";
import type { AtlasRpcResult } from "../../connection/atlasRpc";

export type ShoppingListRangeContext = {
  range: { start: string; end: string };
  workbenches: ConfirmedNeedWorkbenchData[];
  drafts: Record<string, ConfirmedNeedDraftLine>;
  onSkippedDates?: (dates: string[]) => void;
  isCurrent?: () => boolean;
};
export function shoppingListRangeDates(range: {
  start: string;
  end: string;
}): string[] {
  const start = Date.parse(`${range.start}T00:00:00Z`);
  const end = Date.parse(`${range.end}T00:00:00Z`);
  const count = (end - start) / 86400000 + 1;
  shoppingAssert(
    Number.isInteger(count) &&
      count >= 1 &&
      count <= 7 &&
      new Date(start).toISOString().slice(0, 10) === range.start &&
      new Date(end).toISOString().slice(0, 10) === range.end,
    "INVALID_DATE_RANGE",
  );
  return Array.from({ length: count }, (_, i) =>
    new Date(start + i * 86400000).toISOString().slice(0, 10),
  );
}

export type ConfirmedNeedAuthorityReader = Pick<ConfirmedNeedApi, "getReview"> &
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
    correction: b.need_correction_authority,
  });
}
export async function loadCompleteConfirmedNeedReview(
  api: ConfirmedNeedAuthorityReader,
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
