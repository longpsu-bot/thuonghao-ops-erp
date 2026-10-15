import type {
  AllocationFamilyRow,
  SupplierAllocationBulkPreview,
  AtlasRpcResult,
  AtlasSuccessEnvelope,
  ConfirmedAllocationWorkbench,
  ProcurementSchoolOption,
  PurchaseOrdersData,
  PurchaseReviewApi,
  SchoolCateringProcurementApi,
  SchoolCateringPurchaseOrder,
} from "../bridges/procurement";

export type ProcurementReviewScenario =
  | "normal"
  | "oct12_recommendations"
  | "manual_split"
  | "rebalance"
  | "needs_reallocation"
  | "blocked"
  | "empty"
  | "read_failure"
  | "retryable_failure"
  | "unknown"
  | "unknown_recovery_failure"
  | "ready"
  | "po_draft"
  | "po_stale"
  | "po_released"
  | "replacement_required"
  | "cancellation_required"
  | "superseded";
export const reviewDate = "2026-09-10";
export const oct12ReviewDate = "2026-10-12";
export const reviewSchools: ProcurementSchoolOption[] = Array.from(
  { length: 33 },
  (_, index) => ({
    school_id: `school-${index}`,
    school_name:
      index === 0
        ? "Trường Tiểu học Nguyễn Du"
        : index === 1
          ? "Trường Tiểu học Lê Lợi"
          : `Trường học ${String(index + 1).padStart(2, "0")}`,
  }),
);
export const oct12ReviewSchools: ProcurementSchoolOption[] = [
  { school_id: "school-an-phu", school_name: "AN PHÚ (BD)" },
  {
    school_id: "school-binh-my",
    school_name: "BÌNH MỸ - BÌNH DƯƠNG",
  },
  { school_id: "school-phu-cuong", school_name: "PHÚ CƯỜNG" },
  { school_id: "school-tan-dinh", school_name: "TÂN ĐỊNH" },
];
export function reviewSuccess(value: object = {}): AtlasRpcResult {
  return {
    kind: "success",
    response: { success: true, ...value } as AtlasSuccessEnvelope,
  };
}
export function reviewFailure(
  code = "STALE_VERSION",
  retryable = false,
): AtlasRpcResult {
  return {
    kind: "backend_error",
    error: {
      success: false,
      error_code: code,
      retryable,
      safe_message: retryable
        ? "Hệ thống đang bận. Có thể thử lại thao tác."
        : "Dữ liệu đã thay đổi; hãy tải lại trước khi tiếp tục.",
    },
  };
}
export const reviewUnknown: AtlasRpcResult = {
  kind: "transport_error",
  diagnostic: {
    code: "NETWORK_FAILURE",
    safeMessage: "Kết nối bị gián đoạn. Chưa xác nhận thao tác đã hoàn tất.",
  },
};

export function reviewFamily(
  scenario: ProcurementReviewScenario = "normal",
): AllocationFamilyRow {
  const isOct12Review = scenario === "oct12_recommendations";
  const serviceDate = isOct12Review ? oct12ReviewDate : reviewDate;
  const school = isOct12Review ? oct12ReviewSchools[0]! : reviewSchools[0]!;
  const saved = [
    "manual_split",
    "rebalance",
    "needs_reallocation",
    "ready",
  ].includes(scenario);
  return {
    family: {
      source_kind: "CONFIRMED_NEED",
      source_confirmed_need_batch_id: "private-batch",
      source_confirmed_need_batch_version: 3,
      service_date: serviceDate,
      delivery_location_id: "location-0",
      ingredient_id: "ingredient-0",
      unit_id: "unit-kg",
      family_id: saved ? "private-family" : null,
      version: saved ? 2 : 0,
      source_fingerprint: "private-fingerprint",
    },
    service_date: serviceDate,
    delivery_location_id: "location-0",
    location_name: isOct12Review ? school.school_name : "Bếp chính Nguyễn Du",
    school_id: school.school_id,
    school_name: school.school_name,
    schools: [school],
    ingredient_id: "ingredient-0",
    ingredient_name: isOct12Review ? "Cà rốt" : "Gạo thơm",
    unit_id: "unit-kg",
    unit_code: "kg",
    family_quantity:
      scenario === "blocked"
        ? null
        : scenario === "rebalance"
          ? "120.000000"
          : isOct12Review
            ? "12.000000"
            : "100.000000",
    complete: scenario !== "blocked",
    contributions: [],
    contribution_count: 2,
    splits: saved
      ? [
          {
            supplier_split_id: "private-split-a",
            supplier_id: "supplier-a",
            supplier_name: "NCC An Phú",
            allocated_quantity: "60.000000",
            supplier_note: null,
            split_ratio: "0.600000000000",
          },
          {
            supplier_split_id: "private-split-b",
            supplier_id: "supplier-b",
            supplier_name: "NCC Bình Minh",
            allocated_quantity: "40.000000",
            supplier_note: null,
            split_ratio: "0.400000000000",
          },
        ]
      : [],
    eligible_suppliers: [
      {
        supplier_id: "supplier-a",
        supplier_name: isOct12Review ? "AN THÀNH ĐÔ" : "NCC An Phú",
        priority: 1,
      },
      ...(scenario === "needs_reallocation"
        ? []
        : [
            {
              supplier_id: "supplier-b",
              supplier_name: isOct12Review ? "MM MEGA MARKET" : "NCC Bình Minh",
              priority: 2,
            },
          ]),
      {
        supplier_id: "supplier-c",
        supplier_name: "NCC Thành Công",
        priority: 3,
      },
    ],
    state:
      scenario === "rebalance"
        ? "STALE_REBALANCE_AVAILABLE"
        : scenario === "needs_reallocation"
          ? "NEEDS_REALLOCATION"
          : scenario === "blocked"
            ? "BLOCKED"
            : saved
              ? "BALANCED"
              : "UNALLOCATED",
    recommendation:
      saved || scenario === "blocked"
        ? null
        : {
            supplier_id: "supplier-a",
            allocated_quantity: isOct12Review ? "12.000000" : "100.000000",
            split_ratio: "1.000000000000",
          },
    rebalance_proposal:
      scenario === "rebalance"
        ? [
            {
              supplier_id: "supplier-a",
              allocated_quantity: "72.000000",
              split_ratio: "0.6",
            },
            {
              supplier_id: "supplier-b",
              allocated_quantity: "48.000000",
              split_ratio: "0.4",
            },
          ]
        : null,
    allowed_actions: {
      save_allocation: scenario !== "blocked",
      confirm_recommendation: false,
    },
    disabled_reasons: [],
    blockers:
      scenario === "blocked"
        ? ["Hoàn tất xác nhận nhu cầu trước khi phân bổ NCC."]
        : [],
    warnings: [],
  };
}
export function reviewOrder(
  scenario: ProcurementReviewScenario = "po_draft",
): SchoolCateringPurchaseOrder {
  const serviceDate =
    scenario === "oct12_recommendations" ? oct12ReviewDate : reviewDate;
  const released = [
    "po_released",
    "replacement_required",
    "cancellation_required",
    "superseded",
  ].includes(scenario);
  return {
    purchase_order_id: "private-order",
    supplier: {
      supplier_id: "supplier-a",
      supplier_name: "NCC An Phú",
      supplier_status: "ACTIVE",
    },
    service_date: serviceDate,
    status:
      scenario === "superseded"
        ? "SUPERSEDED"
        : released
          ? "RELEASED_TO_SUPPLIER"
          : "DRAFT",
    version: 4,
    document_number: released ? "PO-20260910-ANPHU" : null,
    replaces_purchase_order_id: null,
    replaced_by_purchase_order_id:
      scenario === "superseded" ? "private-successor" : null,
    commitment_state:
      scenario === "po_stale"
        ? "DRAFT_STALE"
        : scenario === "replacement_required"
          ? "REPLACEMENT_REQUIRED"
          : scenario === "cancellation_required"
            ? "CANCELLATION_REQUIRED"
            : scenario === "superseded"
              ? "SUPERSEDED"
              : released
                ? "CURRENT"
                : "DRAFT_CURRENT",
    current_revision: {
      purchase_order_revision_id: "private-order-revision",
      revision_number: 2,
      revision_kind: "BASE",
      revision_status: released ? "RELEASED" : "DRAFT",
      predecessor_revision_id: null,
      supplier_name_snapshot: released ? "NCC An Phú" : null,
      supplier_document_code_snapshot: released ? "53" : null,
      delivery_location_snapshot: null,
      released_by_actor_id: null,
      released_at: null,
      reason_note: null,
    },
    lines: [
      {
        purchase_order_line_revision_id: "private-line-revision",
        purchase_order_line_id: "private-line",
        ingredient: {
          ingredient_id: "ingredient-0",
          ingredient_name: "Gạo thơm",
        },
        ordered_quantity: "60.000001",
        supplier_note: null,
        ingredient_document_code_snapshot: released ? "1082" : null,
        ingredient_name_snapshot: released ? "Gạo thơm" : null,
        unit_code_snapshot: released ? "kg" : null,
        unit: { unit_id: "unit-kg", unit_code: "kg" },
        delivery_location: {
          delivery_location_id: "location-0",
          location_name: "Bếp chính Nguyễn Du",
        },
        service_date: serviceDate,
        school_breakdown: released
          ? [
              {
                school_id: "school-0",
                school_name: "Trường Nguyễn Du",
                school_display_order: 1,
                delivery_location_id: "location-0",
                delivery_location_name: "Bếp chính Nguyễn Du",
                ordered_quantity: "60.000001",
              },
            ]
          : [],
        source: {
          family_id: "private-family",
          family_revision_id: "private-family-revision",
          supplier_split_id: "private-split",
        },
      },
    ],
    stale: scenario === "po_stale",
    release_eligible: !released && scenario !== "po_stale",
    export_ready: released,
    document_snapshot_complete: released,
    blockers:
      scenario === "cancellation_required"
        ? ["CANCELLATION_REQUIRED"]
        : scenario === "po_stale"
          ? ["PO_DRAFT_STALE"]
          : scenario === "replacement_required"
            ? ["PO_REPLACEMENT_REQUIRED"]
            : [],
    warnings: [],
    allowed_actions: {
      release: !released && scenario !== "po_stale",
      export: released,
      create_replacement: scenario === "replacement_required",
    },
    disabled_reasons:
      scenario === "replacement_required"
        ? ["PO_REPLACEMENT_REQUIRED", "PO_ALREADY_RELEASED"]
        : [],
  };
}

/** Explicit in-memory review projection; never used by the connected transport. */
export function reviewBulkPreview(
  rows: AllocationFamilyRow[],
): SupplierAllocationBulkPreview {
  const families = rows.map((row) => {
    const kind =
      row.complete !== false &&
      row.family_quantity &&
      row.allowed_actions.save_allocation
        ? row.state === "UNALLOCATED" && row.recommendation
          ? ("DEFAULT" as const)
          : row.state === "STALE_REBALANCE_AVAILABLE" && row.rebalance_proposal
            ? ("REBALANCE" as const)
            : null
        : null;
    const proposed =
      kind === "DEFAULT"
        ? [row.recommendation!]
        : (row.rebalance_proposal ?? []);
    return {
      ...structuredClone(row),
      unit_label: row.unit_code === "kg" ? "Kilôgam" : "Chưa có tên đơn vị",
      schools: row.schools ?? [],
      decision_origin: row.splits.length ? "MANUAL" : null,
      candidate: kind
        ? {
            family: {
              service_date: row.service_date,
              delivery_location_id: row.delivery_location_id,
              ingredient_id: row.ingredient_id,
              unit_id: row.unit_id,
              source_kind: row.family.source_kind ?? "PURCHASE_HANDOFF",
              expected_family_version: row.family.version,
              expected_source_fingerprint: row.family.source_fingerprint,
              ...(row.family.source_kind === "CONFIRMED_NEED"
                ? {
                    expected_source_batch_id:
                      row.family.source_confirmed_need_batch_id,
                    expected_source_batch_version:
                      row.family.source_confirmed_need_batch_version,
                  }
                : {}),
            },
            proposal_kind: kind,
            proposal_fingerprint: `review:${row.family.source_fingerprint}:${row.family.version}:${kind}`,
            proposed_splits: proposed.map((p) => ({
              supplier_id: p.supplier_id,
              allocated_quantity: p.allocated_quantity,
              supplier_note:
                row.splits.find((s) => s.supplier_id === p.supplier_id)
                  ?.supplier_note ?? null,
            })),
          }
        : null,
      exclusion_reason: kind
        ? null
        : row.state === "BALANCED"
          ? "EXISTING_DECISION_PRESERVED"
          : "CONFIRMED_NEED_INCOMPLETE",
      purchase_order_impact: {
        coverage: "AUTHORIZED_DOCUMENTS_ONLY" as const,
        documents: [],
      },
    };
  });
  return {
    families,
    total_count: families.length,
    applicable_count: families.filter((r) => r.candidate).length,
    excluded_count: families.filter((r) => !r.candidate).length,
    allowed: true,
  };
}

/** Explicit review snapshots only. No hosted adapter and no backend derivation. */
export function createProcurementReviewFixture(
  scenario: ProcurementReviewScenario = "normal",
  dateOverride?: string,
) {
  const serviceDate =
    dateOverride ??
    (scenario === "oct12_recommendations" ? oct12ReviewDate : reviewDate);
  const preparationReady = ["ready", "oct12_recommendations"].includes(
    scenario,
  );
  const fixture = {
    allocation: {
      success: true,
      contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
      date_start: serviceDate,
      date_end: serviceDate,
      rows:
        scenario === "empty"
          ? []
          : [
              (() => {
                const row = reviewFamily(scenario);
                return {
                  ...row,
                  service_date: serviceDate,
                  family: { ...row.family, service_date: serviceDate },
                };
              })(),
            ],
      warnings: [],
      blockers: [],
      preparation: {
        service_date: serviceDate,
        confirmed_need_batch_id: "private-batch",
        expected_version: 3,
        ready: preparationReady,
        allowed: preparationReady,
        blockers: preparationReady ? [] : ["ALLOCATION_IMBALANCED"],
      },
    } as ConfirmedAllocationWorkbench,
    orders: {
      success: true,
      contract_version: "SCHOOL-CATERING-PROCUREMENT.v1",
      date_start: serviceDate,
      date_end: serviceDate,
      purchase_orders: scenario === "empty" ? [] : [reviewOrder(scenario)],
      procurement_current: true,
      blockers: [],
      warnings: [],
    } as PurchaseOrdersData,
    commandResult: ["unknown", "unknown_recovery_failure"].includes(scenario)
      ? reviewUnknown
      : scenario === "retryable_failure"
        ? reviewFailure("RETRYABLE_CONCURRENCY_FAILURE", true)
        : reviewSuccess({ safe_operator_message: "Đã lưu theo yêu cầu." }),
  };
  const command = async () => fixture.commandResult;
  let allocationReads = 0;
  const purchaseReviewApi: PurchaseReviewApi = {
    getGeneratedReview: async () => reviewFailure("NOT_AVAILABLE"),
    getConfirmedAllocations: async (request) => {
      allocationReads += 1;
      if (scenario === "unknown_recovery_failure" && allocationReads === 2) {
        return {
          kind: "backend_error",
          error: {
            success: false,
            error_code: "ACCESS_DENIED",
            retryable: false,
            safe_message: "Bạn không có quyền xem dữ liệu này.",
          },
        };
      }
      const payload =
        request.payload &&
        typeof request.payload === "object" &&
        !Array.isArray(request.payload)
          ? request.payload
          : {};
      const schools = Array.isArray(payload.school_ids)
        ? payload.school_ids
        : [];
      const previewRows = fixture.allocation.rows.filter(
        (row) =>
          row.service_date >= String(payload.date_start) &&
          row.service_date <= String(payload.date_end) &&
          (!schools.length ||
            row.schools?.some((s) => schools.includes(s.school_id))),
      );
      return scenario === "read_failure"
        ? reviewFailure("ACCESS_DENIED")
        : reviewSuccess({
            ...fixture.allocation,
            ...(request.payload &&
            typeof request.payload === "object" &&
            !Array.isArray(request.payload) &&
            request.payload.include_bulk_preview
              ? { bulk_preview: reviewBulkPreview(previewRows) }
              : {}),
          });
    },
    applyAllocationBatch: async (request) => {
      if (fixture.commandResult.kind !== "success")
        return fixture.commandResult;
      const preview = reviewBulkPreview(fixture.allocation.rows);
      const selected = request.payload.candidates;
      if (
        !selected.length ||
        selected.some(
          (c) =>
            !preview.families.some(
              (r) => JSON.stringify(r.candidate) === JSON.stringify(c),
            ),
        )
      )
        return reviewFailure("STALE_BULK_PROPOSAL");
      for (const candidate of selected) {
        const row = fixture.allocation.rows.find(
          (r) =>
            r.service_date === candidate.family.service_date &&
            r.ingredient_id === candidate.family.ingredient_id &&
            r.delivery_location_id === candidate.family.delivery_location_id &&
            r.unit_id === candidate.family.unit_id,
        )!;
        row.splits = candidate.proposed_splits.map((p) => ({
          ...p,
          supplier_note: p.supplier_note ?? null,
          supplier_split_id: `review-${p.supplier_id}`,
          supplier_name: row.eligible_suppliers.find(
            (s) => s.supplier_id === p.supplier_id,
          )!.supplier_name,
          split_ratio:
            row.rebalance_proposal?.find((s) => s.supplier_id === p.supplier_id)
              ?.split_ratio ?? "1.000000000000",
        }));
        row.state = "BALANCED";
        row.family.version += 1;
        row.recommendation = null;
        row.rebalance_proposal = null;
      }
      return reviewSuccess({
        contract_version: "SUPPLIER-ALLOCATION-BATCH.v1",
        applied_count: selected.length,
      });
    },
    saveConfirmedAllocation: command,
    preparePurchaseOrders: command,
  };
  const procurementApi: SchoolCateringProcurementApi = {
    getWorkbench: async () => reviewFailure("NOT_AVAILABLE"),
    saveAllocation: command,
    confirmRecommendations: async () => reviewFailure("NOT_AVAILABLE"),
    getPurchaseOrders: async () =>
      scenario === "read_failure"
        ? reviewFailure("ACCESS_DENIED")
        : reviewSuccess(fixture.orders),
    createPurchaseOrderDrafts: command,
    createPurchaseOrderReplacement: command,
    releasePurchaseOrder: command,
  };
  return Object.assign(fixture, { purchaseReviewApi, procurementApi });
}
