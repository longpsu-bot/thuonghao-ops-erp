import type {
  AtlasRpcRequest,
  AtlasRpcResult,
  AtlasSuccessEnvelope,
} from "../connection/atlasRpc";
import type { AtlasReviewScenario } from "../review/reviewMode";
import {
  createReviewConfirmedNeedApi,
  createReviewConfirmedNeedFixture,
} from "../planning-inputs/confirmed-needs/reviewConfirmedNeedApi";
import {
  confirmedNeedReleaseV2Request,
  confirmedNeedSaveV2Request,
} from "../planning-inputs/confirmed-needs/confirmedNeedApi";
import type { ConfirmedNeedWorkbenchData } from "../planning-inputs/confirmed-needs/confirmedNeedModel";
import { createReviewPlanningInputReadinessApi } from "../planning-inputs/readiness/reviewPlanningInputReadinessApi";
import {
  createReviewProcurementWorkbenchFixture,
  createReviewPurchaseOrdersFixture,
  createReviewSchoolCateringProcurementApi,
} from "./reviewSchoolCateringProcurementApi";
import type {
  AllocationFamilyRow,
  AllocationSupplierSplit,
  SchoolCateringPurchaseOrder,
} from "./schoolCateringProcurementModel";
import {
  confirmedAllocationFromResult,
  confirmedAllocationReadRequest,
  confirmedAllocationRequest,
  preparePurchaseOrdersRequest,
  type ConfirmedAllocationWorkbench,
  type GeneratedPurchaseReview,
  type PurchaseReviewApi,
} from "./purchaseReviewApi";
import { releasePurchaseOrderRequest } from "./schoolCateringProcurementApi";

const clone = structuredClone;
const scale = 1_000_000n;
function micros(value: string) {
  if (!/^\d+(\.\d{1,6})?$/.test(value))
    throw new Error("Invalid synthetic exact quantity");
  const [whole, fraction = ""] = value.split(".");
  return BigInt(whole!) * scale + BigInt(fraction.padEnd(6, "0"));
}
const exact = (value: bigint) =>
  `${value / scale}.${String(value % scale).padStart(6, "0")}`;
const payload = (request: AtlasRpcRequest) =>
  request.payload &&
  typeof request.payload === "object" &&
  !Array.isArray(request.payload)
    ? request.payload
    : {};
const success = (value: object): AtlasRpcResult => ({
  kind: "success",
  response: clone({ success: true, ...value }) as AtlasSuccessEnvelope,
});
const error = (code: string): AtlasRpcResult => ({
  kind: "backend_error",
  error: {
    success: false,
    error_code: code,
    safe_message:
      "Dữ liệu xem thử chưa sẵn sàng. Hãy tải lại dữ liệu hiện hành.",
  },
});
type SavedAllocation = {
  revision_id: string;
  source_kind: "CONFIRMED_NEED" | "PURCHASE_HANDOFF";
  fingerprint: string;
  quantity: string;
  splits: AllocationSupplierSplit[];
};

// Explicitly synthetic, in-memory session. No database, browser persistence or
// production supplier decisions. One saved source drives both review screens.
export function createReviewPurchaseJourney(
  scenario: AtlasReviewScenario,
  serviceDate: string,
) {
  let need = createReviewConfirmedNeedFixture(1);
  need.service_period = { period_start: serviceDate, period_end: serviceDate };
  const line = need.lines[0]!;
  Object.assign(line, {
    service_date: serviceDate,
    theoretical_quantity: "100.000000",
    proposed_confirmed_quantity: "100.000000",
    source_membership_count: 1,
  });
  const baseNeed = createReviewConfirmedNeedApi(scenario, {
    initialFixture: need,
  });
  const template = createReviewProcurementWorkbenchFixture().rows[0]!;
  const allocations: SavedAllocation[] = [];
  let orders: SchoolCateringPurchaseOrder[] = [];
  let committed = false;
  const receipts = new Map<
    string,
    { request: string; result: AtlasRpcResult }
  >();
  const fingerprint = () =>
    `${need.confirmed_need_batch_id}:${need.lines[0]!.current_revision_id}:${need.lines[0]!.current_decision_id}`;
  const unavailable = () =>
    scenario === "permission_denied"
      ? error("CAPABILITY_DENIED")
      : scenario === "server_error"
        ? error("INTERNAL_COMMAND_FAILURE")
        : null;
  const capture = (result: AtlasRpcResult) => {
    if (result.kind === "success" && result.response.authoritative_readback)
      need = clone(
        result.response.authoritative_readback,
      ) as unknown as ConfirmedNeedWorkbenchData;
    return result;
  };
  const inRange = (request: AtlasRpcRequest) => {
    const start = payload(request).date_start,
      end = payload(request).date_end;
    return (
      typeof start === "string" &&
      typeof end === "string" &&
      start <= serviceDate &&
      serviceDate <= end
    );
  };
  const replay = (request: AtlasRpcRequest) => {
    const prior = receipts.get(String(request.command_id));
    return prior
      ? prior.request === JSON.stringify(request)
        ? clone(prior.result)
        : error("IDEMPOTENCY_CONFLICT")
      : null;
  };
  const remember = (request: AtlasRpcRequest, result: AtlasRpcResult) => {
    receipts.set(String(request.command_id), {
      request: JSON.stringify(request),
      result: clone(result),
    });
    return result;
  };
  const row = (): AllocationFamilyRow => {
    const current = need.lines[0]!;
    const saved = allocations.at(-1);
    const complete = Boolean(current.current_decision_id);
    const quantity = complete
      ? exact(micros(current.confirmed_quantity_after!))
      : null;
    const stale = saved && saved.fingerprint !== fingerprint();
    let remaining = quantity ? micros(quantity) : 0n;
    const proposal =
      saved && stale
        ? saved.splits.map((split, i) => {
            const amount =
              i === saved.splits.length - 1
                ? remaining
                : (micros(quantity!) * micros(split.allocated_quantity)) /
                  micros(saved.quantity);
            remaining -= amount;
            return {
              supplier_id: split.supplier_id,
              allocated_quantity: exact(amount),
              split_ratio: split.split_ratio,
            };
          })
        : null;
    return {
      ...clone(template),
      complete,
      service_date: serviceDate,
      school_id: current.school.id,
      school_name: current.school.name,
      schools: [
        { school_id: current.school.id, school_name: current.school.name },
      ],
      delivery_location_id: current.delivery_location.id,
      location_name: current.delivery_location.name,
      ingredient_id: current.ingredient.id,
      ingredient_name: current.ingredient.name,
      unit_id: current.controlled_unit.id,
      unit_code: current.controlled_unit.code,
      family: {
        service_date: serviceDate,
        delivery_location_id: current.delivery_location.id,
        ingredient_id: current.ingredient.id,
        unit_id: current.controlled_unit.id,
        family_id: saved ? "review-shared-family" : null,
        version: allocations.length,
        source_fingerprint: fingerprint(),
        source_kind: committed ? "PURCHASE_HANDOFF" : "CONFIRMED_NEED",
        source_confirmed_need_batch_id: need.confirmed_need_batch_id,
        source_confirmed_need_batch_version: need.batch_version,
      },
      family_quantity: quantity,
      contribution_count: 1,
      contributions: [
        {
          contribution_quantity: quantity ?? "0.000000",
          ...(committed
            ? { purchase_handoff_line_revision_id: "review-handoff-line" }
            : {
                confirmed_need_line_revision_id: current.current_revision_id,
                confirmed_need_line_decision_id:
                  current.current_decision_id ?? undefined,
              }),
        },
      ],
      splits: clone(saved?.splits ?? []),
      state: !complete
        ? "BLOCKED"
        : stale
          ? "STALE_REBALANCE_AVAILABLE"
          : saved
            ? "BALANCED"
            : "UNALLOCATED",
      recommendation:
        complete && !saved
          ? {
              supplier_id: template.eligible_suppliers[0]!.supplier_id,
              allocated_quantity: quantity!,
              split_ratio: "1.000000000000",
            }
          : null,
      rebalance_proposal: proposal,
      allowed_actions: {
        save_allocation: complete && !committed,
        confirm_recommendation: false,
      },
      blockers: complete
        ? []
        : ["Hoàn tất xác nhận nhu cầu trước khi phân bổ NCC."],
      disabled_reasons: [],
      warnings: [],
    };
  };
  const generated: GeneratedPurchaseReview = {
    success: true,
    contract_version: "PURCHASE-REVIEW.v1",
    service_date: serviceDate,
    document_label: "DỰ KIẾN — CHƯA XÁC NHẬN",
    rows: [
      {
        ...row(),
        family_quantity: "100.000000",
        recommendation: clone(template.recommendation),
      },
    ],
    warnings: [],
    blockers: [],
  };
  const confirmedNeedApi = {
    ...baseNeed,
    async save(request: Parameters<typeof baseNeed.save>[0]) {
      const prior = replay(request);
      if (prior) return prior;
      if (committed) return error("SAVE_BATCH_NOT_EDITABLE");
      if (request.expected_version !== need.batch_version)
        return error("STALE_CONFIRMED_NEED_BATCH");
      return remember(request, capture(await baseNeed.save(request)));
    },
  };
  const purchaseReviewApi: PurchaseReviewApi = {
    async getGeneratedReview(request) {
      return (
        unavailable() ??
        success({
          ...generated,
          rows:
            payload(request).service_date === serviceDate &&
            scenario !== "empty"
              ? generated.rows
              : [],
        })
      );
    },
    async getConfirmedAllocations(request) {
      const current = row();
      const schoolIds = payload(request).school_ids;
      const visible =
        inRange(request) &&
        scenario !== "empty" &&
        (!Array.isArray(schoolIds) ||
          !schoolIds.length ||
          schoolIds.includes(current.school_id));
      const data: ConfirmedAllocationWorkbench = {
        success: true,
        contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
        date_start: String(payload(request).date_start),
        date_end: String(payload(request).date_end),
        rows: visible ? [current] : [],
        warnings: [],
        blockers: visible ? current.blockers : [],
        preparation: visible
          ? {
              service_date: serviceDate,
              confirmed_need_batch_id: need.confirmed_need_batch_id,
              expected_version: need.batch_version,
              allowed: true,
              ready: current.state === "BALANCED",
              blockers:
                current.state === "BALANCED"
                  ? []
                  : ["Phân bổ nhà cung ứng chưa khớp với nhu cầu đã xác nhận."],
            }
          : null,
      };
      return unavailable() ?? success(data);
    },
    async saveConfirmedAllocation(request) {
      const prior = replay(request);
      if (prior) return prior;
      const current = row();
      if (unavailable()) return unavailable()!;
      if (!current.complete || committed)
        return error("CONFIRMED_NEED_INCOMPLETE");
      if (
        request.expected_version !== allocations.length ||
        request.payload.family.expected_source_fingerprint !== fingerprint() ||
        request.payload.family.expected_source_batch_version !==
          need.batch_version
      )
        return error("SOURCE_CHANGED");
      const inputs = request.payload.splits;
      if (
        !inputs.length ||
        new Set(inputs.map((s) => s.supplier_id)).size !== inputs.length ||
        inputs.some(
          (s) =>
            !template.eligible_suppliers.some(
              (e) => e.supplier_id === s.supplier_id,
            ) ||
            !/^\d+(\.\d{1,6})?$/.test(s.allocated_quantity) ||
            micros(s.allocated_quantity) <= 0n,
        ) ||
        inputs.reduce((sum, s) => sum + micros(s.allocated_quantity), 0n) !==
          micros(current.family_quantity!)
      )
        return error("ALLOCATION_IMBALANCE");
      allocations.push({
        revision_id: crypto.randomUUID(),
        source_kind: "CONFIRMED_NEED",
        fingerprint: fingerprint(),
        quantity: current.family_quantity!,
        splits: inputs.map((s) => {
          const ratio =
            (micros(s.allocated_quantity) * 1_000_000_000_000n) /
            micros(current.family_quantity!);
          return {
            supplier_split_id: crypto.randomUUID(),
            supplier_id: s.supplier_id,
            supplier_name: template.eligible_suppliers.find(
              (e) => e.supplier_id === s.supplier_id,
            )!.supplier_name,
            allocated_quantity: exact(micros(s.allocated_quantity)),
            split_ratio: `${ratio / 1_000_000_000_000n}.${String(ratio % 1_000_000_000_000n).padStart(12, "0")}`,
          };
        }),
      });
      return remember(
        request,
        success({
          contract_version: request.contract_version,
          safe_operator_message: "Đã lưu phân bổ nhà cung ứng.",
          family: row().family,
        }),
      );
    },
    async preparePurchaseOrders(request) {
      const prior = replay(request);
      if (prior) return prior;
      if (unavailable()) return unavailable()!;
      if (
        request.payload.service_date !== serviceDate ||
        request.payload.confirmed_need_batch_id !==
          need.confirmed_need_batch_id ||
        request.expected_version !== need.batch_version ||
        row().state !== "BALANCED"
      )
        return error("SOURCE_CHANGED");
      if (!committed) {
        const released = capture(
          await baseNeed.releaseSaved(
            confirmedNeedReleaseV2Request(
              request.requested_by_auth_subject,
              request.correlation_id,
              need.confirmed_need_batch_id,
              need.batch_version,
            ),
          ),
        );
        if (released.kind !== "success") return released;
        committed = true;
        const saved = allocations.at(-1)!;
        allocations.push({
          ...clone(saved),
          revision_id: crypto.randomUUID(),
          source_kind: "PURCHASE_HANDOFF",
        });
        const current = row();
        orders = saved.splits.map((split) => {
          const po = createReviewPurchaseOrdersFixture().purchase_orders[0]!;
          return {
            ...po,
            purchase_order_id: crypto.randomUUID(),
            supplier: {
              ...po.supplier,
              supplier_id: split.supplier_id,
              supplier_name: split.supplier_name,
            },
            service_date: serviceDate,
            current_revision: {
              ...po.current_revision,
              purchase_order_revision_id: crypto.randomUUID(),
              supplier_name_snapshot: split.supplier_name,
            },
            lines: [
              {
                ...po.lines[0]!,
                purchase_order_line_id: crypto.randomUUID(),
                purchase_order_line_revision_id: crypto.randomUUID(),
                ingredient: {
                  ingredient_id: current.ingredient_id,
                  ingredient_name: current.ingredient_name,
                },
                ordered_quantity: split.allocated_quantity,
                unit: {
                  unit_id: current.unit_id,
                  unit_code: current.unit_code,
                },
                service_date: serviceDate,
                delivery_location: {
                  delivery_location_id: current.delivery_location_id,
                  location_name: current.location_name,
                },
                source: {
                  family_id: current.family.family_id!,
                  family_revision_id: allocations.at(-1)!.revision_id,
                  supplier_split_id: split.supplier_split_id,
                },
              },
            ],
          };
        });
      }
      return remember(
        request,
        success({
          contract_version: request.contract_version,
          safe_operator_message: "Đã chuẩn bị đơn mua.",
          purchase_order_ids: orders.map((po) => po.purchase_order_id),
        }),
      );
    },
  };
  const baseProcurement = createReviewSchoolCateringProcurementApi("empty");
  const procurementApi = {
    ...baseProcurement,
    async getPurchaseOrders(
      request: Parameters<typeof baseProcurement.getPurchaseOrders>[0],
    ) {
      return (
        unavailable() ??
        success({
          ...createReviewPurchaseOrdersFixture("empty"),
          date_start: payload(request).date_start,
          date_end: payload(request).date_end,
          purchase_orders: inRange(request) ? orders : [],
        })
      );
    },
    async createPurchaseOrderDrafts() {
      return error("CONFIRMED_ALLOCATION_REQUIRED");
    },
    async saveAllocation() {
      return error("REVIEW_COMMITTED_SOURCE_READ_ONLY");
    },
    async releasePurchaseOrder(
      request: Parameters<typeof baseProcurement.releasePurchaseOrder>[0],
    ) {
      const prior = replay(request);
      if (prior) return prior;
      const po = orders.find(
        (o) => o.purchase_order_id === request.payload.purchase_order_id,
      );
      if (
        !po ||
        po.status !== "DRAFT" ||
        po.version !== request.expected_version ||
        po.current_revision.purchase_order_revision_id !==
          request.payload.expected_purchase_order_revision_id
      )
        return error("STALE_VERSION");
      po.status = "RELEASED_TO_SUPPLIER";
      po.version += 1;
      po.document_number = `PO-${serviceDate.replaceAll("-", "")}-${po.purchase_order_id.slice(0, 8)}`;
      po.current_revision = {
        ...po.current_revision,
        predecessor_revision_id: po.current_revision.purchase_order_revision_id,
        purchase_order_revision_id: crypto.randomUUID(),
        revision_number: 2,
        revision_kind: "RELEASE",
        revision_status: "RELEASED_TO_SUPPLIER",
        released_by_actor_id: "review-operator",
        released_at: new Date().toISOString(),
      };
      po.allowed_actions = {
        release: false,
        export: true,
        create_replacement: false,
      };
      po.release_eligible = false;
      po.export_ready = true;
      return remember(
        request,
        success({
          safe_operator_message: "Đã phát hành đơn mua.",
          purchase_order_id: po.purchase_order_id,
        }),
      );
    },
  };
  const baseReadiness = createReviewPlanningInputReadinessApi(scenario);
  const readinessApi = {
    ...baseReadiness,
    async preflight(...args: Parameters<typeof baseReadiness.preflight>) {
      const result = await baseReadiness.preflight(...args);
      if (result.kind !== "success") return result;
      const current =
        args[2] === serviceDate &&
        args[3] === serviceDate &&
        scenario !== "empty";
      return success({
        ...result.response,
        preflight: {
          ...(result.response.preflight as object),
          downstream_currentness: current ? "CURRENT" : "NOT_GENERATED",
          current_need: current
            ? {
                confirmed_need_batch_id: need.confirmed_need_batch_id,
                confirmed_need_batch_status: need.batch_status,
                confirmed_need_batch_version: need.batch_version,
                need_generation_run_id: need.need_generation_source.run_id,
                need_generation_run_version:
                  need.need_generation_source.run_version,
                need_generation_run_status: "MATERIALIZED",
              }
            : null,
        },
      });
    },
  };
  return {
    confirmedNeedApi,
    purchaseReviewApi,
    procurementApi,
    readinessApi,
    inspect: () => clone({ need, allocations, orders, committed }),
  };
}

export type ReviewPurchasePhase =
  "generated" | "confirmed" | "allocated" | "stale" | "prepared" | "released";

// Story/test setup deliberately goes through the same synthetic API boundaries.
export async function seedReviewPurchaseJourney(
  phase: ReviewPurchasePhase,
  date = "2026-09-03",
) {
  const journey = createReviewPurchaseJourney("ready", date);
  const requireSuccess = (result: AtlasRpcResult) => {
    if (result.kind !== "success")
      throw new Error("Synthetic journey setup failed");
  };
  const read = async () =>
    confirmedAllocationFromResult(
      await journey.purchaseReviewApi.getConfirmedAllocations(
        confirmedAllocationReadRequest("review", "review", {
          date_start: date,
          date_end: date,
          school_ids: [],
          states: [],
          search: null,
        }),
      ),
    )!;
  const saveNeed = async (quantity: string) => {
    const need = journey.inspect().need;
    const line = need.lines[0]!;
    requireSuccess(
      await journey.confirmedNeedApi.save(
        confirmedNeedSaveV2Request(
          "review",
          "review",
          need.confirmed_need_batch_id,
          need.batch_version,
          [
            {
              confirmed_need_line_id: line.confirmed_need_line_id,
              expected_current_revision_id: line.current_revision_id,
              expected_current_decision_id: line.current_decision_id,
              proposed_confirmed_quantity: quantity,
              reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT",
              reason_note: "Rà soát trên bản dự kiến",
            },
          ],
        ),
      ),
    );
  };
  const saveSplit = async (a: string, b: string) => {
    const row = (await read()).rows[0]!;
    requireSuccess(
      await journey.purchaseReviewApi.saveConfirmedAllocation(
        confirmedAllocationRequest(
          "review",
          "review",
          row.family.version,
          {
            service_date: date,
            delivery_location_id: row.delivery_location_id,
            ingredient_id: row.ingredient_id,
            unit_id: row.unit_id,
            expected_source_fingerprint: row.family.source_fingerprint,
            expected_source_batch_id:
              row.family.source_confirmed_need_batch_id!,
            expected_source_batch_version:
              row.family.source_confirmed_need_batch_version!,
          },
          row.eligible_suppliers.map((s, i) => ({
            supplier_id: s.supplier_id,
            allocated_quantity: i ? b : a,
          })),
        ),
      ),
    );
  };
  if (phase !== "generated") await saveNeed("120.00");
  if (["allocated", "stale", "prepared", "released"].includes(phase))
    await saveSplit("72.00", "48.00");
  if (["stale", "prepared", "released"].includes(phase))
    await saveNeed("125.00");
  if (["prepared", "released"].includes(phase)) {
    await saveSplit("75.00", "50.00");
    requireSuccess(
      await journey.purchaseReviewApi.preparePurchaseOrders(
        preparePurchaseOrdersRequest(
          "review",
          "review",
          (await read()).preparation!,
        ),
      ),
    );
  }
  if (phase === "released")
    for (const po of journey.inspect().orders)
      requireSuccess(
        await journey.procurementApi.releasePurchaseOrder(
          releasePurchaseOrderRequest(
            "review",
            "review",
            po.version,
            po.purchase_order_id,
            po.current_revision.purchase_order_revision_id,
          ),
        ),
      );
  return journey;
}
