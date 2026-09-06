import type {
  AtlasRpcResult,
  AtlasSafeBackendError,
  AtlasSuccessEnvelope,
  JsonValue,
} from "../connection/atlasRpc";
import type { AtlasReviewScenario } from "../review/reviewMode";
import type {
  RecipeAdjustmentApi,
  RecipeAdjustmentCommandRequest,
} from "./recipeAdjustmentApi";
import type {
  EffectiveCompositionLine,
  EffectiveCompositionResult,
  RecipeAdjustmentAction,
  RecipeAdjustmentOperatorRecord,
  RecipeAdjustmentOperatorDisplayRevision,
  RecipeAdjustmentOperatorHistoryRevision,
  RecipeAdjustmentRecord,
  RecipeAdjustmentScope,
  RecipeAdjustmentWorkbenchData,
} from "./recipeAdjustmentModel";

type ReviewWorkbenchData = RecipeAdjustmentWorkbenchData & {
  adjustments: RecipeAdjustmentRecord[];
};

const now = "2026-07-27T02:00:00.000Z";
const actor = "00000000-0000-4000-8000-000000000001";
const ids = {
  school: "11000000-0000-4000-8000-000000000001",
  secondarySchool: "11000000-0000-4000-8000-000000000002",
  sameTypeSchool: "11000000-0000-4000-8000-000000000003",
  schoolType: "12000000-0000-4000-8000-000000000001",
  secondarySchoolType: "12000000-0000-4000-8000-000000000002",
  dish: "13000000-0000-4000-8000-000000000001",
  recipe: "14000000-0000-4000-8000-000000000001",
  secondaryRecipe: "14000000-0000-4000-8000-000000000002",
  version: "15000000-0000-4000-8000-000000000001",
  secondaryVersion: "15000000-0000-4000-8000-000000000002",
  line1: "16000000-0000-4000-8000-000000000001",
  line2: "16000000-0000-4000-8000-000000000002",
  line3: "16000000-0000-4000-8000-000000000003",
  line4: "16000000-0000-4000-8000-000000000004",
  ingredient1: "17000000-0000-4000-8000-000000000001",
  ingredient2: "17000000-0000-4000-8000-000000000002",
  ingredient3: "17000000-0000-4000-8000-000000000003",
  ingredient4: "17000000-0000-4000-8000-000000000004",
  ingredient5: "17000000-0000-4000-8000-000000000005",
  unit: "18000000-0000-4000-8000-000000000001",
  gram: "18000000-0000-4000-8000-000000000002",
};

const clone = <T>(value: T): T => structuredClone(value);
const success = (data: Record<string, JsonValue>): AtlasRpcResult => ({
  kind: "success",
  response: { success: true, ...data } as AtlasSuccessEnvelope,
});
const backendError = (errorCode: string): AtlasRpcResult => ({
  kind: "backend_error",
  error: {
    success: false,
    error_code: errorCode,
    safe_message: "Yêu cầu xem thử đã bị từ chối an toàn.",
  } as AtlasSafeBackendError,
});

function revision(
  adjustmentId: string,
  number: number,
  lifecycle: "ACTIVE" | "SUPERSEDED" | "CANCELLED",
  action: RecipeAdjustmentAction,
): RecipeAdjustmentRecord["revisions"][number] {
  return {
    revision_id: `${adjustmentId.slice(0, -1)}${number}`,
    revision_number: number,
    predecessor_revision_id:
      number === 1 ? null : `${adjustmentId.slice(0, -1)}${number - 1}`,
    lifecycle_status: lifecycle,
    effective_from: "2026-07-01",
    effective_to: null,
    substitute_ingredient_id:
      lifecycle !== "CANCELLED" && action === "REPLACE"
        ? ids.ingredient3
        : null,
    quantity_per_basis:
      lifecycle !== "CANCELLED" &&
      (action === "ADD" || action === "ADJUST_QUANTITY")
        ? 12.5
        : null,
    unit_id: lifecycle !== "CANCELLED" && action === "ADD" ? ids.unit : null,
    reason_code: "REVIEW_SCENARIO",
    reason_note: "Tình huống xác định để xem xét giao diện.",
    source_evidence: { source_kind: "REVIEW_FIXTURE" },
    created_by_actor_id: actor,
    created_by_actor_name: "Nguyễn Điều hành",
    created_at: now,
  };
}

function rule(
  index: number,
  scope: RecipeAdjustmentScope,
  action: RecipeAdjustmentAction,
  lifecycle: "ACTIVE" | "CANCELLED" = "ACTIVE",
): RecipeAdjustmentRecord {
  const adjustmentId = `19000000-0000-4000-8000-${index
    .toString()
    .padStart(12, "0")}`;
  const hasLine =
    (scope === "SYSTEM_DISH" || scope === "SCHOOL_DISH") && action !== "ADD";
  const hasIngredient =
    scope === "SYSTEM_INGREDIENT" || scope === "SCHOOL" || action === "ADD";
  const revisions =
    lifecycle === "CANCELLED"
      ? [
          revision(adjustmentId, 1, "SUPERSEDED", action),
          revision(adjustmentId, 2, "CANCELLED", action),
        ]
      : index === 3
        ? [
            revision(adjustmentId, 1, "SUPERSEDED", action),
            revision(adjustmentId, 2, "ACTIVE", action),
          ]
        : [revision(adjustmentId, 1, "ACTIVE", action)];
  const current = revisions.at(-1)!;
  if (index === 1) {
    revisions[0].reason_code = "LEGACY_IMPORT";
    revisions[0].source_evidence = {
      source_system: "OPS_V1",
      historical_actor_approval_claimed: false,
    };
  }
  return {
    adjustment_id: adjustmentId,
    scope_kind: scope,
    action_kind: action,
    school_id:
      scope === "SCHOOL" || scope === "SCHOOL_DISH" ? ids.school : null,
    dish_id:
      scope === "SYSTEM_DISH" || scope === "SCHOOL_DISH" ? ids.dish : null,
    school_type_id: scope === "SYSTEM_DISH" ? ids.schoolType : null,
    target_ingredient_id: hasIngredient ? ids.ingredient1 : null,
    target_recipe_line_id: hasLine ? ids.line1 : null,
    adjustment_line_id:
      action === "ADD"
        ? `1a000000-0000-4000-8000-${index.toString().padStart(12, "0")}`
        : null,
    current_revision_id: current.revision_id,
    current_revision_number: current.revision_number,
    lifecycle_status: lifecycle,
    version: current.revision_number,
    legacy_source: index === 1 ? "OPS_V1_INGREDIENT_CHANGE_ORDER" : null,
    legacy_record_id: index === 1 ? "legacy-ingredient-1" : null,
    created_by_actor_id: actor,
    created_by_actor_name: "Nguyễn Điều hành",
    created_at: now,
    updated_by_actor_id: actor,
    updated_by_actor_name: "Nguyễn Điều hành",
    updated_at: now,
    revisions,
  };
}

function commandRevision(
  request: RecipeAdjustmentCommandRequest,
  number: number,
  lifecycle: "ACTIVE" | "CANCELLED",
): RecipeAdjustmentRecord["revisions"][number] {
  const payload = request.payload;
  return {
    ...revision(
      String(payload.adjustment_id),
      number,
      lifecycle,
      String(payload.action_kind ?? "REPLACE") as RecipeAdjustmentAction,
    ),
    revision_id: String(payload.revision_id),
    predecessor_revision_id:
      typeof payload.predecessor_revision_id === "string"
        ? payload.predecessor_revision_id
        : null,
    effective_from: String(payload.effective_from),
    effective_to:
      typeof payload.effective_to === "string" ? payload.effective_to : null,
    substitute_ingredient_id:
      typeof payload.substitute_ingredient_id === "string"
        ? payload.substitute_ingredient_id
        : null,
    quantity_per_basis:
      typeof payload.quantity_per_basis === "number"
        ? payload.quantity_per_basis
        : null,
    unit_id: typeof payload.unit_id === "string" ? payload.unit_id : null,
    reason_code: request.reason_code,
    reason_note: request.reason_note,
    source_evidence:
      typeof payload.source_evidence === "object" &&
      payload.source_evidence !== null &&
      !Array.isArray(payload.source_evidence)
        ? payload.source_evidence
        : {},
  };
}

function ruleFromCommand(request: RecipeAdjustmentCommandRequest) {
  const payload = request.payload;
  const scope = String(payload.scope_kind) as RecipeAdjustmentScope;
  const action = String(payload.action_kind) as RecipeAdjustmentAction;
  const record = rule(90, scope, action);
  const current = commandRevision(request, 1, "ACTIVE");
  return {
    ...record,
    adjustment_id: String(payload.adjustment_id),
    school_id: typeof payload.school_id === "string" ? payload.school_id : null,
    dish_id: typeof payload.dish_id === "string" ? payload.dish_id : null,
    school_type_id:
      typeof payload.school_type_id === "string"
        ? payload.school_type_id
        : null,
    target_ingredient_id:
      typeof payload.target_ingredient_id === "string"
        ? payload.target_ingredient_id
        : null,
    target_recipe_line_id:
      typeof payload.target_recipe_line_id === "string"
        ? payload.target_recipe_line_id
        : null,
    adjustment_line_id:
      typeof payload.adjustment_line_id === "string"
        ? payload.adjustment_line_id
        : null,
    current_revision_id: current.revision_id,
    current_revision_number: 1,
    version: 1,
    revisions: [current],
  } satisfies RecipeAdjustmentRecord;
}

function operatorRevision(
  item: RecipeAdjustmentRecord,
  revisionItem: RecipeAdjustmentRecord["revisions"][number],
): RecipeAdjustmentOperatorDisplayRevision &
  RecipeAdjustmentOperatorHistoryRevision {
  const isLegacy =
    item.legacy_source !== null &&
    revisionItem.reason_code.startsWith("LEGACY");
  return {
    revision_id: revisionItem.revision_id,
    revision_status: revisionItem.lifecycle_status,
    business_event_kind:
      revisionItem.lifecycle_status === "CANCELLED"
        ? "CANCELLED"
        : revisionItem.revision_number === 1
          ? "CREATED"
          : "CORRECTED",
    effective_from: revisionItem.effective_from,
    effective_to: revisionItem.effective_to,
    substitute_ingredient_id: revisionItem.substitute_ingredient_id,
    quantity_per_basis: revisionItem.quantity_per_basis,
    unit_id: revisionItem.unit_id,
    reason_note: revisionItem.reason_note,
    issued_at: isLegacy ? null : revisionItem.created_at,
    issuance_kind: isLegacy ? "LEGACY_UNATTRIBUTED" : "ATLAS_NATIVE",
    issued_by_actor_name: isLegacy ? null : revisionItem.created_by_actor_name,
  };
}

function operatorRow(
  item: RecipeAdjustmentRecord,
): RecipeAdjustmentOperatorRecord {
  const current = item.revisions.at(-1)!;
  const { business_event_kind: _displayEvent, ...display } = operatorRevision(
    item,
    current,
  );
  const contentItem =
    current.lifecycle_status === "CANCELLED"
      ? item.revisions
          .slice()
          .reverse()
          .find(
            (revisionItem) => revisionItem.lifecycle_status !== "CANCELLED",
          )!
      : current;
  const { business_event_kind: _contentEvent, ...content } = operatorRevision(
    item,
    contentItem,
  );
  const {
    revision_status: _commandStatus,
    issued_at: _issuedAt,
    issuance_kind: _issuanceKind,
    issued_by_actor_name: _issuedBy,
    ...command
  } = display;
  const temporalState =
    item.lifecycle_status === "CANCELLED"
      ? "CANCELLED"
      : item.revisions.length > 1
        ? "ACTIVE_CHANGE_SCHEDULED"
        : "ACTIVE";
  return {
    adjustment_id: item.adjustment_id,
    version: item.version,
    current_revision_id: item.current_revision_id,
    current_revision_number: item.current_revision_number,
    can_correct: item.lifecycle_status === "ACTIVE",
    can_cancel: item.lifecycle_status === "ACTIVE",
    scope_kind: item.scope_kind,
    action_kind: item.action_kind,
    school_id: item.school_id,
    dish_id: item.dish_id,
    school_type_id: item.school_type_id,
    target_ingredient_id: item.target_ingredient_id,
    target_recipe_line_id: item.target_recipe_line_id,
    adjustment_line_id: item.adjustment_line_id,
    temporal_state: temporalState,
    temporal_state_date:
      item.revisions.length > 1 ? current.effective_from : null,
    is_effective_now: temporalState !== "CANCELLED",
    display_revision: display,
    content_revision: content,
    command_revision: command,
    history: item.revisions
      .map((revisionItem) => {
        const { revision_status: _status, ...history } = operatorRevision(
          item,
          revisionItem,
        );
        return history;
      })
      .reverse(),
  };
}

function fixtures(): ReviewWorkbenchData {
  const catalog: [RecipeAdjustmentScope, RecipeAdjustmentAction[]][] = [
    ["SYSTEM_INGREDIENT", ["REPLACE"]],
    ["SYSTEM_DISH", ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"]],
    ["SCHOOL", ["REPLACE", "REMOVE"]],
    ["SCHOOL_DISH", ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"]],
  ];
  let index = 1;
  const adjustments = catalog.flatMap(([scope, actions]) =>
    actions.map((action) =>
      rule(
        index++,
        scope,
        action,
        (scope === "SCHOOL" && (action === "REPLACE" || action === "REMOVE")) ||
          (scope === "SCHOOL_DISH" && action === "ADD")
          ? "CANCELLED"
          : "ACTIVE",
      ),
    ),
  );
  const schoolAdd = rule(12, "SCHOOL_DISH", "ADD");
  const schoolDishReplacement = adjustments.find(
    (item) =>
      item.scope_kind === "SCHOOL_DISH" && item.action_kind === "REPLACE",
  );
  if (schoolDishReplacement) {
    schoolDishReplacement.target_recipe_line_id = null;
    schoolDishReplacement.adjustment_line_id = schoolAdd.adjustment_line_id;
  }
  adjustments.push(schoolAdd);
  return {
    reference_date: "2026-07-27",
    scope_catalog: catalog.map(([scope_kind, actions]) => ({
      scope_kind,
      actions,
    })),
    precedence: [
      "RELEASED_RECIPE_VERSION",
      "SYSTEM_INGREDIENT",
      "SYSTEM_DISH",
      "SCHOOL",
      "SCHOOL_DISH",
    ],
    schools: [
      {
        school_id: ids.school,
        school_code: "truong-minh-khai",
        school_name: "Trường Tiểu học Minh Khai",
        school_type_id: ids.schoolType,
        school_status: "ACTIVE",
      },
      {
        school_id: ids.secondarySchool,
        school_code: "truong-tran-phu",
        school_name: "Trường Trung học Trần Phú",
        school_type_id: ids.secondarySchoolType,
        school_status: "ACTIVE",
      },
      {
        school_id: ids.sameTypeSchool,
        school_code: "truong-nguyen-du",
        school_name: "Trường Tiểu học Nguyễn Du",
        school_type_id: ids.schoolType,
        school_status: "ACTIVE",
      },
    ],
    dishes: [
      {
        dish_id: ids.dish,
        dish_code: "canh-bi-do",
        dish_name: "Canh bí đỏ",
        dish_status: "ACTIVE",
        requires_need_generation: true,
      },
    ],
    school_types: [
      {
        school_type_id: ids.schoolType,
        school_type_name: "TIỂU HỌC",
        school_type_status: "ACTIVE",
      },
      {
        school_type_id: ids.secondarySchoolType,
        school_type_name: "TRUNG HỌC",
        school_type_status: "ACTIVE",
      },
    ],
    ingredients: (
      [
        [ids.ingredient1, "bi-do", "Bí đỏ", ids.unit, "Kilôgam"],
        [ids.ingredient2, "thit-heo", "Thịt heo", ids.gram, "Gam"],
        [ids.ingredient3, "ca-rot", "Cà rốt", ids.unit, "Kilôgam"],
        [ids.ingredient4, "khoai-tay", "Khoai tây", ids.unit, "Kilôgam"],
        [
          ids.ingredient5,
          "gia-vi-thieu-don-vi",
          "Gia vị thiếu đơn vị",
          null,
          null,
        ],
      ] as const
    ).map(
      ([
        ingredient_id,
        ingredient_code,
        ingredient_name,
        purchase_unit_id,
        purchase_unit_name,
      ]) => ({
        ingredient_id,
        ingredient_code,
        ingredient_name,
        ingredient_status: "ACTIVE",
        purchase_unit_id,
        purchase_unit_name,
      }),
    ),
    units: [
      {
        unit_id: ids.unit,
        unit_code: "kg",
        unit_name: "Kilôgam",
        unit_status: "ACTIVE",
      },
      {
        unit_id: ids.gram,
        unit_code: "g",
        unit_name: "Gam",
        unit_status: "ACTIVE",
      },
    ],
    recipe_lines: [
      {
        recipe_line_id: ids.line1,
        recipe_id: ids.recipe,
        dish_id: ids.dish,
        school_type_id: ids.schoolType,
        line_code: "bi-do",
        ingredient_id: ids.ingredient1,
        ingredient_name: "Bí đỏ",
        quantity_per_basis: 20,
        unit_id: ids.unit,
        unit_name: "Kilôgam",
      },
      {
        recipe_line_id: ids.line2,
        recipe_id: ids.recipe,
        dish_id: ids.dish,
        school_type_id: ids.schoolType,
        line_code: "thit-heo",
        ingredient_id: ids.ingredient2,
        ingredient_name: "Thịt heo",
        quantity_per_basis: 8,
        unit_id: ids.unit,
        unit_name: "Kilôgam",
      },
      {
        recipe_line_id: ids.line3,
        recipe_id: ids.secondaryRecipe,
        dish_id: ids.dish,
        school_type_id: ids.secondarySchoolType,
        line_code: "bi-do-trung-hoc",
        ingredient_id: ids.ingredient1,
        ingredient_name: "Bí đỏ",
        quantity_per_basis: 25,
        unit_id: ids.unit,
        unit_name: "Kilôgam",
      },
      {
        recipe_line_id: ids.line4,
        recipe_id: ids.secondaryRecipe,
        dish_id: ids.dish,
        school_type_id: ids.secondarySchoolType,
        line_code: "thit-heo-trung-hoc",
        ingredient_id: ids.ingredient2,
        ingredient_name: "Thịt heo",
        quantity_per_basis: 10,
        unit_id: ids.unit,
        unit_name: "Kilôgam",
      },
    ],
    operator_rows: adjustments.map(operatorRow),
    adjustments,
  };
}

function lineage(
  scope: RecipeAdjustmentScope,
  action: RecipeAdjustmentAction,
  index: number,
) {
  return {
    adjustment_id: `29000000-0000-4000-8000-${index
      .toString()
      .padStart(12, "0")}`,
    revision_id: `2a000000-0000-4000-8000-${index
      .toString()
      .padStart(12, "0")}`,
    revision_number: 1,
    scope_kind: scope,
    action_kind: action,
    before: { ingredient_id: ids.ingredient1, quantity_per_basis: 20 },
    after: { ingredient_id: ids.ingredient3, quantity_per_basis: 24 },
    reason_code: "REVIEW_SCENARIO",
    reason_note: "Bằng chứng lớp nguồn cho xem xét.",
    effective_from: "2026-07-01",
    effective_to: null,
    is_preview: false,
  };
}

function baseLine(
  lineId: string,
  ingredientId: string,
  lineCode: string,
  recipeId = ids.recipe,
  versionId = ids.version,
  quantity = lineId === ids.line1 ? 20 : 8,
): EffectiveCompositionLine {
  return {
    selected_dish_id: ids.dish,
    selected_recipe_id: recipeId,
    selected_recipe_version_id: versionId,
    basis_portions: 100,
    base_recipe_line_id: lineId,
    base_recipe_line_revision_id: `${lineId.slice(0, -1)}9`,
    adjustment_line_id: null,
    line_code: lineCode,
    base_ingredient_id: ingredientId,
    base_quantity_per_basis: quantity,
    base_unit_id: ids.unit,
    base_disposition: "PRESENT",
    final_ingredient_id: ingredientId,
    final_quantity_per_basis: quantity,
    final_unit_id: ids.unit,
    final_disposition: "PRESENT",
    source_layer: "RELEASED_RECIPE_VERSION",
    applied_adjustment_ids: [],
    applied_revision_ids: [],
    lineage: [],
  };
}

function addedLine(
  adjustmentLineId: string,
  ingredientId: string,
  quantity: number,
  sourceLayer: "SYSTEM_DISH" | "SCHOOL_DISH",
): EffectiveCompositionLine {
  return {
    ...baseLine(
      "1b000000-0000-4000-8000-000000000001",
      ingredientId,
      "dòng-thêm",
    ),
    base_recipe_line_id: null,
    base_recipe_line_revision_id: null,
    adjustment_line_id: adjustmentLineId,
    line_code: null,
    base_ingredient_id: null,
    base_quantity_per_basis: null,
    base_unit_id: null,
    base_disposition: null,
    final_quantity_per_basis: quantity,
    source_layer: sourceLayer,
  };
}

function addPriorEffectiveLines(
  resolution: EffectiveCompositionResult,
  schoolId: string | null,
) {
  resolution.lines.push(
    addedLine(
      "1a000000-0000-4000-8000-000000000002",
      ids.ingredient5,
      1.25,
      "SYSTEM_DISH",
    ),
  );
  if (schoolId === ids.school) {
    resolution.lines.push(
      addedLine(
        "1a000000-0000-4000-8000-000000000012",
        ids.ingredient3,
        0.75,
        "SCHOOL_DISH",
      ),
    );
  }
  return resolution;
}

function resolutionScenario(
  name = "precedence",
  schoolId = ids.school,
): EffectiveCompositionResult {
  const secondary = schoolId === ids.secondarySchool;
  const recipeId = secondary ? ids.secondaryRecipe : ids.recipe;
  const versionId = secondary ? ids.secondaryVersion : ids.version;
  const first = baseLine(
    secondary ? ids.line3 : ids.line1,
    ids.ingredient1,
    secondary ? "bi-do-trung-hoc" : "bi-do",
    recipeId,
    versionId,
    secondary ? 25 : 20,
  );
  const second = baseLine(
    secondary ? ids.line4 : ids.line2,
    ids.ingredient2,
    secondary ? "thit-heo-trung-hoc" : "thit-heo",
    recipeId,
    versionId,
    secondary ? 10 : 8,
  );
  const blockers: EffectiveCompositionResult["blockers"] = [];
  if (name === "precedence") {
    first.final_ingredient_id = ids.ingredient4;
    first.final_quantity_per_basis = 24;
    first.source_layer = "SCHOOL_DISH";
    first.lineage = [
      lineage("SYSTEM_INGREDIENT", "REPLACE", 1),
      lineage("SYSTEM_DISH", "ADJUST_QUANTITY", 2),
      lineage("SCHOOL", "REPLACE", 3),
      lineage("SCHOOL_DISH", "REPLACE", 4),
    ];
  } else if (name === "system") {
    first.final_ingredient_id = ids.ingredient3;
    first.final_quantity_per_basis = 22;
    first.source_layer = "SYSTEM_DISH";
    first.lineage = [
      lineage("SYSTEM_INGREDIENT", "REPLACE", 1),
      lineage("SYSTEM_DISH", "ADJUST_QUANTITY", 2),
    ];
  } else if (name === "replacement_chain") {
    first.final_ingredient_id = ids.ingredient3;
    first.source_layer = "SYSTEM_INGREDIENT";
    first.lineage = [
      lineage("SYSTEM_INGREDIENT", "REPLACE", 1),
      lineage("SYSTEM_INGREDIENT", "REPLACE", 2),
    ];
  } else if (name === "removed") {
    first.final_quantity_per_basis = 0;
    first.final_disposition = "REMOVED";
    first.source_layer = "SCHOOL";
    first.lineage = [lineage("SCHOOL", "REMOVE", 1)];
  } else if (name === "duplicate") {
    second.final_ingredient_id = ids.ingredient1;
    second.source_layer = "SCHOOL_DISH";
    blockers.push({
      code: "DUPLICATE_EFFECTIVE_INGREDIENT",
      message: "Hai dòng hiệu lực cùng trỏ tới Bí đỏ.",
    });
  } else if (name === "cycle") {
    blockers.push({
      code: "REPLACEMENT_CYCLE",
      message: "Chuỗi thay thế Bí đỏ → Cà rốt → Bí đỏ tạo chu trình.",
    });
  }
  first.applied_adjustment_ids = first.lineage.map(
    (step) => step.adjustment_id,
  );
  first.applied_revision_ids = first.lineage.map((step) => step.revision_id);
  return {
    status: blockers.length ? "BLOCKED" : "READY",
    as_of_date: "2026-07-27",
    school_id: schoolId,
    school_type_id: secondary ? ids.secondarySchoolType : ids.schoolType,
    dish_id: ids.dish,
    historical: false,
    selected_recipe: {
      dish_id: ids.dish,
      recipe_id: recipeId,
      recipe_version_id: versionId,
      selection_scope: "SCHOOL_TYPE",
      basis_portions: 100,
    },
    lines: [first, second],
    warnings: [],
    blockers,
  };
}

export function createReviewRecipeAdjustmentApi(
  scenario: AtlasReviewScenario = "ready",
): RecipeAdjustmentApi {
  let data =
    scenario === "empty" ? { ...fixtures(), adjustments: [] } : fixtures();
  const blockedRead = () => {
    if (scenario === "permission_denied")
      return backendError("CAPABILITY_DENIED");
    if (scenario === "session_lost")
      return backendError("AUTHENTICATION_REQUIRED");
    if (scenario === "server_error")
      return backendError("INTERNAL_READ_FAILURE");
    return null;
  };
  const blockedWrite = () =>
    scenario === "stale" ? backendError("STALE_VERSION") : blockedRead();
  const saved = () =>
    success({
      safe_operator_message:
        "Đã cập nhật dữ liệu xem thử. Thay đổi không được lưu ra ngoài trình duyệt.",
      authoritative_readback: clone(data) as unknown as JsonValue,
    });

  return {
    getWorkbench() {
      if (scenario === "loading")
        return new Promise<AtlasRpcResult>(() => undefined);
      const blocked = blockedRead();
      const {
        operator_rows: _rows,
        reference_date: _date,
        ...referenceData
      } = data;
      return Promise.resolve(
        blocked ??
          success({
            workbench: clone(referenceData) as unknown as JsonValue,
          }),
      );
    },
    getOperatorWorkbench(_auth, _correlation, asOfDate) {
      if (scenario === "loading")
        return new Promise<AtlasRpcResult>(() => undefined);
      const blocked = blockedRead();
      const { adjustments: _adjustments, ...operatorData } = data;
      operatorData.reference_date = asOfDate;
      operatorData.operator_rows = data.adjustments.map(operatorRow);
      return Promise.resolve(
        blocked ??
          success({
            workbench: clone(operatorData) as unknown as JsonValue,
          }),
      );
    },
    resolve(_auth, _correlation, payload) {
      const blocked = blockedRead();
      const resolution = resolutionScenario(
        String(payload.review_scenario ?? "precedence"),
        String(payload.school_id ?? ids.school),
      );
      resolution.as_of_date = String(payload.as_of_date);
      resolution.school_id = String(payload.school_id);
      resolution.dish_id = String(payload.dish_id);
      return Promise.resolve(
        blocked ??
          success({
            resolution: resolution as unknown as JsonValue,
            safe_operator_message: "Đã phân giải BOM hiệu lực xem thử.",
          }),
      );
    },
    resolveSystem(_auth, _correlation, asOfDate, dishId, schoolTypeId) {
      const blocked = blockedRead();
      const schoolId =
        schoolTypeId === ids.secondarySchoolType
          ? ids.secondarySchool
          : ids.school;
      const resolution = resolutionScenario(
        "precedence",
        schoolId,
      ) as EffectiveCompositionResult;
      resolution.school_id = null;
      resolution.school_type_id = schoolTypeId;
      resolution.as_of_date = asOfDate;
      resolution.dish_id = dishId;
      return Promise.resolve(
        blocked ??
          success({
            resolution: resolution as unknown as JsonValue,
            safe_operator_message: "Đã phân giải BOM hệ thống xem thử.",
          }),
      );
    },
    getEffectiveTargetContext(_auth, _correlation, asOfDate, dishId, context) {
      const blocked = blockedRead();
      const selectedSchoolId =
        context.kind === "school" ? context.schoolId : null;
      const resolutionSchoolId =
        selectedSchoolId ??
        (context.kind === "system" &&
        context.schoolTypeId === ids.secondarySchoolType
          ? ids.secondarySchool
          : ids.school);
      const resolution = addPriorEffectiveLines(
        resolutionScenario(
          selectedSchoolId === ids.school ? "precedence" : "system",
          resolutionSchoolId,
        ),
        selectedSchoolId,
      );
      const schoolTypeId =
        context.kind === "system"
          ? context.schoolTypeId
          : context.schoolId === ids.secondarySchool
            ? ids.secondarySchoolType
            : ids.schoolType;
      return Promise.resolve(
        blocked ??
          success({
            target_context: {
              as_of_date: asOfDate,
              dish_id: dishId,
              school_id: context.kind === "school" ? context.schoolId : null,
              school_type_id: schoolTypeId,
              selected_recipe: resolution.selected_recipe,
              basis_portions:
                resolution.selected_recipe?.basis_portions ?? null,
              effective_lines: resolution.lines
                .filter((line) => line.final_disposition === "PRESENT")
                .map((line) => {
                  const adjustmentLineId = line.adjustment_line_id;
                  const recipeLineId = line.base_recipe_line_id;
                  const targetKind = adjustmentLineId
                    ? "ADJUSTMENT_LINE"
                    : "RECIPE_LINE";
                  const ingredient = data.ingredients.find(
                    (item) => item.ingredient_id === line.final_ingredient_id,
                  );
                  return {
                    ingredient_id: line.final_ingredient_id,
                    ingredient_name: ingredient?.ingredient_name ?? "—",
                    quantity_per_basis: line.final_quantity_per_basis,
                    unit_id: line.final_unit_id,
                    unit_name:
                      data.units.find(
                        (unit) => unit.unit_id === line.final_unit_id,
                      )?.unit_name ?? "—",
                    target_kind: targetKind,
                    target_recipe_line_id: recipeLineId,
                    adjustment_line_id: adjustmentLineId,
                    target_id: adjustmentLineId ?? recipeLineId ?? "",
                    source_layer: line.source_layer,
                  };
                }),
              warnings: resolution.warnings,
              blockers: resolution.blockers,
            },
          }),
      );
    },
    preview(_auth, _correlation, payload) {
      const blocked = blockedWrite();
      if (blocked) return Promise.resolve(blocked);
      const proposal = payload.proposed_adjustment as Record<string, JsonValue>;
      const systemContext = proposal.scope_kind === "SYSTEM_DISH";
      const previewSchoolId = systemContext ? null : String(payload.school_id);
      const previewSchoolTypeId = systemContext
        ? String(payload.school_type_id)
        : null;
      const resolutionSchoolId: string = systemContext
        ? previewSchoolTypeId === ids.secondarySchoolType
          ? ids.secondarySchool
          : ids.school
        : (previewSchoolId ?? ids.school);
      const before = addPriorEffectiveLines(
        resolutionScenario(
          systemContext
            ? "system"
            : resolutionSchoolId === ids.school
              ? "precedence"
              : "system",
          resolutionSchoolId,
        ),
        previewSchoolId,
      );
      const after = clone(before);
      before.as_of_date = String(payload.as_of_date);
      before.school_id = previewSchoolId;
      before.school_type_id =
        previewSchoolTypeId ??
        (resolutionSchoolId === ids.secondarySchool
          ? ids.secondarySchoolType
          : ids.schoolType);
      before.dish_id = String(payload.dish_id);
      after.as_of_date = String(payload.as_of_date);
      after.school_id = previewSchoolId;
      after.school_type_id = before.school_type_id;
      after.dish_id = String(payload.dish_id);
      const action = String(proposal.action_kind);
      const scope = String(proposal.scope_kind);
      const target =
        action === "ADD"
          ? undefined
          : scope === "SYSTEM_INGREDIENT" || scope === "SCHOOL"
            ? after.lines.find(
                (line) =>
                  line.final_ingredient_id ===
                    String(proposal.target_ingredient_id) ||
                  line.base_ingredient_id ===
                    String(proposal.target_ingredient_id),
              )
            : after.lines.find((line) =>
                proposal.target_recipe_line_id
                  ? line.base_recipe_line_id ===
                    String(proposal.target_recipe_line_id)
                  : line.adjustment_line_id ===
                    String(proposal.adjustment_line_id),
              );
      const blockers =
        target || action === "ADD"
          ? []
          : [
              {
                code: "REVIEW_TARGET_NOT_FOUND",
                message:
                  "Không tìm thấy nguyên liệu cần điều chỉnh trong công thức xem thử.",
              },
            ];

      if (target && action === "REMOVE") {
        target.final_disposition = "REMOVED";
        target.final_quantity_per_basis = 0;
      } else if (target && action === "REPLACE") {
        target.final_ingredient_id = String(proposal.substitute_ingredient_id);
        if (proposal.quantity_per_basis !== null) {
          target.final_quantity_per_basis = Number(proposal.quantity_per_basis);
          target.final_unit_id = String(proposal.unit_id);
        }
      } else if (target && action === "ADJUST_QUANTITY") {
        target.final_quantity_per_basis = Number(proposal.quantity_per_basis);
      } else if (action === "ADD") {
        after.lines.push({
          ...baseLine(
            "1b000000-0000-4000-8000-000000000001",
            String(proposal.target_ingredient_id),
            "dòng-thêm",
          ),
          base_recipe_line_id: null,
          base_recipe_line_revision_id: null,
          adjustment_line_id: String(proposal.adjustment_line_id),
          base_ingredient_id: null,
          base_quantity_per_basis: null,
          base_unit_id: null,
          base_disposition: null,
          final_quantity_per_basis: Number(proposal.quantity_per_basis),
          source_layer: String(proposal.scope_kind),
        });
      }
      if (target) target.source_layer = String(proposal.scope_kind);
      return Promise.resolve(
        success({
          preview: {
            as_of_date: String(payload.as_of_date),
            school_id: previewSchoolId,
            school_type_id: previewSchoolTypeId,
            dish_id: String(payload.dish_id),
            proposed_adjustment: proposal,
            before,
            after,
            affected_line_count: blockers.length ? 0 : 1,
            can_save: blockers.length === 0,
            warnings: [],
            blockers,
          } as unknown as JsonValue,
          safe_operator_message:
            "Đã xem trước có thẩm quyền trong chế độ không lưu.",
        }),
      );
    },
    create(request: RecipeAdjustmentCommandRequest) {
      const blocked = blockedWrite();
      if (blocked) return Promise.resolve(blocked);
      data.adjustments.push(ruleFromCommand(request));
      return Promise.resolve(saved());
    },
    supersede(request: RecipeAdjustmentCommandRequest) {
      const blocked = blockedWrite();
      if (blocked) return Promise.resolve(blocked);
      const record = data.adjustments.find(
        (item) => item.adjustment_id === request.payload.adjustment_id,
      );
      if (!record) return Promise.resolve(backendError("NOT_FOUND"));
      const current = record.revisions.at(-1)!;
      current.lifecycle_status = "SUPERSEDED";
      const next = commandRevision(
        request,
        current.revision_number + 1,
        "ACTIVE",
      );
      record.revisions.push(next);
      record.current_revision_id = next.revision_id;
      record.current_revision_number = next.revision_number;
      record.version += 1;
      return Promise.resolve(saved());
    },
    cancel(request: RecipeAdjustmentCommandRequest) {
      const blocked = blockedWrite();
      if (blocked) return Promise.resolve(blocked);
      const record = data.adjustments.find(
        (item) => item.adjustment_id === request.payload.adjustment_id,
      );
      if (!record) return Promise.resolve(backendError("NOT_FOUND"));
      record.revisions.at(-1)!.lifecycle_status = "SUPERSEDED";
      const cancelled = commandRevision(
        request,
        record.current_revision_number + 1,
        "CANCELLED",
      );
      record.revisions.push(cancelled);
      record.current_revision_id = cancelled.revision_id;
      record.current_revision_number = cancelled.revision_number;
      record.lifecycle_status = "CANCELLED";
      record.version += 1;
      return Promise.resolve(saved());
    },
  };
}
