import {
  Badge,
  Button,
  Divider,
  Drawer,
  Group,
  Modal,
  Stack,
  Text,
} from "@mantine/core";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { AtlasAuthState } from "../atlas/connection/authSession";
import type { AtlasRpcResult, JsonValue } from "../atlas/connection/atlasRpc";
import {
  recipeAdjustmentCommandRequest,
  type RecipeAdjustmentApi,
} from "../atlas/recipe-adjustments/recipeAdjustmentApi";
import {
  adjustmentPreviewFromResult,
  adjustmentResultMessage,
  adjustmentWorkbenchFromResult,
  effectiveCompositionFromResult,
  emptyRecipeAdjustmentWorkbench,
  type AdjustmentReference,
  type EffectiveCompositionLine,
  type EffectiveCompositionResult,
  type RecipeAdjustmentAction,
  type RecipeAdjustmentOperatorRecord,
  type RecipeAdjustmentOperatorRevision,
  type RecipeAdjustmentPreview,
  type RecipeAdjustmentScope,
  type RecipeAdjustmentTemporalState,
  type RecipeAdjustmentWorkbenchData,
} from "../atlas/recipe-adjustments/recipeAdjustmentModel";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";

type LoadState = {
  status: "idle" | "loading" | "ready" | "error";
  data: RecipeAdjustmentWorkbenchData;
  message?: string;
};

type AdjustmentDraft = {
  action: RecipeAdjustmentAction;
  scope: RecipeAdjustmentScope;
  schoolId: string;
  dishId: string;
  schoolTypeId: string;
  targetIngredientId: string;
  targetRecipeLineId: string;
  substituteIngredientId: string;
  quantity: string;
  unitId: string;
  replaceQuantity: boolean;
  effectiveFrom: string;
  effectiveTo: string;
  reason: string;
  previewSchoolId: string;
  previewDishId: string;
};

const ACTIONS_BY_SCOPE: Record<
  RecipeAdjustmentScope,
  RecipeAdjustmentAction[]
> = {
  SYSTEM_INGREDIENT: ["REPLACE"],
  SYSTEM_DISH: ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"],
  SCHOOL: ["REPLACE", "REMOVE"],
  SCHOOL_DISH: ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"],
};

const actionLabel: Record<RecipeAdjustmentAction, string> = {
  REPLACE: "Thay nguyên liệu",
  ADJUST_QUANTITY: "Đổi định lượng",
  ADD: "Thêm nguyên liệu",
  REMOVE: "Bỏ nguyên liệu",
};

const scopeLabel: Record<RecipeAdjustmentScope, string> = {
  SYSTEM_INGREDIENT: "Mọi món có nguyên liệu này",
  SYSTEM_DISH: "Một món tại các trường",
  SCHOOL: "Mọi món của một trường",
  SCHOOL_DISH: "Một món của một trường",
};

const temporalLabel: Record<RecipeAdjustmentTemporalState, string> = {
  ACTIVE: "Đang hiệu lực",
  SCHEDULED: "Sắp hiệu lực",
  ACTIVE_CHANGE_SCHEDULED: "Đang hiệu lực · có thay đổi sắp tới",
  ACTIVE_CANCELLATION_SCHEDULED: "Đang hiệu lực · đã lên lịch hủy",
  ACTIVE_RESUMED: "Đang hiệu lực · nội dung trước được áp dụng lại",
  EXPIRED: "Hết hiệu lực",
  CANCELLED: "Đã hủy",
};

const today = () => new Date().toISOString().slice(0, 10);

function formatDate(value: string | null | undefined) {
  if (!value) return "—";
  const [year, month, day] = value.slice(0, 10).split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

function formatIssuedAt(value: string | undefined) {
  if (!value) return "—";
  return new Intl.DateTimeFormat("vi-VN", {
    dateStyle: "short",
    timeStyle: "short",
    timeZone: "Asia/Ho_Chi_Minh",
  }).format(new Date(value));
}

function formatQuantity(value: number | null | undefined) {
  if (value === null || value === undefined) return "—";
  return new Intl.NumberFormat("vi-VN", { maximumFractionDigits: 6 }).format(
    value,
  );
}

function firstId(
  records: AdjustmentReference[],
  key: keyof AdjustmentReference,
) {
  const value = records[0]?.[key];
  return typeof value === "string" ? value : "";
}

function referenceName(
  records: AdjustmentReference[],
  id: string | null | undefined,
  idKey: keyof AdjustmentReference,
  nameKey: keyof AdjustmentReference,
) {
  if (!id) return "—";
  const value = records.find((record) => record[idKey] === id)?.[nameKey];
  return typeof value === "string" ? value : "—";
}

function emptyDraft(data: RecipeAdjustmentWorkbenchData): AdjustmentDraft {
  return {
    action: "REPLACE",
    scope: "SYSTEM_INGREDIENT",
    schoolId: firstId(data.schools, "school_id"),
    dishId: firstId(data.dishes, "dish_id"),
    schoolTypeId: "",
    targetIngredientId: "",
    targetRecipeLineId: "",
    substituteIngredientId: "",
    quantity: "",
    unitId: firstId(data.units, "unit_id"),
    replaceQuantity: false,
    effectiveFrom: today(),
    effectiveTo: "",
    reason: "",
    previewSchoolId: firstId(data.schools, "school_id"),
    previewDishId: firstId(data.dishes, "dish_id"),
  };
}

function availableScopes(action: RecipeAdjustmentAction) {
  return (Object.keys(ACTIONS_BY_SCOPE) as RecipeAdjustmentScope[]).filter(
    (scope) => ACTIONS_BY_SCOPE[scope].includes(action),
  );
}

function temporalText(row: RecipeAdjustmentOperatorRecord) {
  const date = formatDate(row.temporal_state_date);
  switch (row.temporal_state) {
    case "SCHEDULED":
      return `Sắp hiệu lực từ ${date}`;
    case "ACTIVE_CHANGE_SCHEDULED":
      return `Đang hiệu lực · thay đổi từ ${date}`;
    case "ACTIVE_CANCELLATION_SCHEDULED":
      return `Đang hiệu lực · hủy từ ${date}`;
    default:
      return temporalLabel[row.temporal_state];
  }
}

function temporalTone(row: RecipeAdjustmentOperatorRecord) {
  if (row.temporal_state === "CANCELLED") return "red";
  if (row.temporal_state === "EXPIRED") return "gray";
  if (
    row.temporal_state === "SCHEDULED" ||
    row.temporal_state.includes("SCHEDULED")
  )
    return "yellow";
  return "green";
}

function hasUnknownWriteOutcome(result: AtlasRpcResult) {
  return result.kind === "transport_error";
}

export function RecipeAdjustmentWorkbench({
  authState,
  api,
  view,
  mode,
}: {
  authState: AtlasAuthState;
  api?: RecipeAdjustmentApi;
  view: "rules" | "effective";
  mode: "connected" | "review";
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [referenceDate, setReferenceDate] = useState(today());
  const [load, setLoad] = useState<LoadState>({
    status: "idle",
    data: emptyRecipeAdjustmentWorkbench(),
  });
  const [query, setQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [scopeFilter, setScopeFilter] = useState("");
  const [createOpened, setCreateOpened] = useState(false);
  const [detail, setDetail] = useState<RecipeAdjustmentOperatorRecord | null>(
    null,
  );
  const [editing, setEditing] = useState<RecipeAdjustmentOperatorRecord | null>(
    null,
  );
  const [draft, setDraft] = useState<AdjustmentDraft>(() =>
    emptyDraft(emptyRecipeAdjustmentWorkbench()),
  );
  const [draftIds, setDraftIds] = useState<{
    adjustmentId: string;
    revisionId: string;
    adjustmentLineId: string;
  }>(() => ({
    adjustmentId: crypto.randomUUID(),
    revisionId: crypto.randomUUID(),
    adjustmentLineId: crypto.randomUUID(),
  }));
  const [preview, setPreview] = useState<RecipeAdjustmentPreview | null>(null);
  const [previewFingerprint, setPreviewFingerprint] = useState("");
  const [cancelTarget, setCancelTarget] =
    useState<RecipeAdjustmentOperatorRecord | null>(null);
  const [cancelDate, setCancelDate] = useState(today());
  const [cancelReason, setCancelReason] = useState("");
  const [resolution, setResolution] =
    useState<EffectiveCompositionResult | null>(null);
  const [effectiveSchoolId, setEffectiveSchoolId] = useState("");
  const [effectiveDishId, setEffectiveDishId] = useState("");
  const [effectiveDate, setEffectiveDate] = useState(today());
  const [reviewScenario, setReviewScenario] = useState("precedence");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const [mutationLocked, setMutationLocked] = useState(false);
  const generation = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;

  const refresh = useCallback(async () => {
    if (!api || !authSubject) return false;
    const current = ++generation.current;
    setLoad((state) => ({ ...state, status: "loading", message: undefined }));
    const result = await api.getOperatorWorkbench(
      authSubject,
      correlationId,
      referenceDate,
    );
    if (current !== generation.current) return false;
    const data = adjustmentWorkbenchFromResult(result);
    if (!data) {
      setLoad((state) => ({
        ...state,
        status: "error",
        message: adjustmentResultMessage(result),
      }));
      return false;
    }
    setLoad({ status: "ready", data });
    setEffectiveSchoolId(
      (value) => value || firstId(data.schools, "school_id"),
    );
    setEffectiveDishId((value) => value || firstId(data.dishes, "dish_id"));
    setMutationLocked(false);
    return true;
  }, [api, authSubject, correlationId, referenceDate]);

  useEffect(() => {
    if (authSubject && api) void refresh();
  }, [api, authSubject, refresh]);

  const lineOptions = useMemo(
    () =>
      load.data.recipe_lines.filter(
        (line) => !draft.dishId || line.dish_id === draft.dishId,
      ),
    [draft.dishId, load.data.recipe_lines],
  );

  const targetLine = useCallback(
    (row: RecipeAdjustmentOperatorRecord) =>
      load.data.recipe_lines.find(
        (line) => line.recipe_line_id === row.target_recipe_line_id,
      ),
    [load.data.recipe_lines],
  );

  const targetName = useCallback(
    (row: RecipeAdjustmentOperatorRecord) => {
      if (row.target_ingredient_id)
        return referenceName(
          load.data.ingredients,
          row.target_ingredient_id,
          "ingredient_id",
          "ingredient_name",
        );
      return targetLine(row)?.ingredient_name ?? "Dòng công thức";
    },
    [load.data.ingredients, targetLine],
  );

  const scopeSummary = useCallback(
    (row: RecipeAdjustmentOperatorRecord) => {
      const school = referenceName(
        load.data.schools,
        row.school_id,
        "school_id",
        "school_name",
      );
      const dish = referenceName(
        load.data.dishes,
        row.dish_id,
        "dish_id",
        "dish_name",
      );
      const ingredient = targetName(row);
      switch (row.scope_kind) {
        case "SYSTEM_INGREDIENT":
          return `${ingredient} · ${scopeLabel[row.scope_kind]}`;
        case "SYSTEM_DISH":
          return `${dish} · ${scopeLabel[row.scope_kind]}`;
        case "SCHOOL":
          return `${school} · ${scopeLabel[row.scope_kind]}`;
        case "SCHOOL_DISH":
          return `${dish} · ${school}`;
      }
    },
    [load.data.dishes, load.data.schools, targetName],
  );

  const changeSummary = useCallback(
    (
      row: RecipeAdjustmentOperatorRecord,
      revision: RecipeAdjustmentOperatorRevision = row.display_revision,
    ) => {
      const target = targetName(row);
      const substitute = referenceName(
        load.data.ingredients,
        revision.substitute_ingredient_id,
        "ingredient_id",
        "ingredient_name",
      );
      const unit = referenceName(
        load.data.units,
        revision.unit_id ?? targetLine(row)?.unit_id,
        "unit_id",
        "unit_name",
      );
      switch (row.action_kind) {
        case "REPLACE":
          return `${target} → ${substitute}`;
        case "ADJUST_QUANTITY":
          return `${target} → ${formatQuantity(revision.quantity_per_basis)} ${unit}`;
        case "ADD":
          return `${target} · ${formatQuantity(revision.quantity_per_basis)} ${unit}`;
        case "REMOVE":
          return target;
      }
    },
    [load.data.ingredients, load.data.units, targetLine, targetName],
  );

  const filteredRows = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase("vi");
    return load.data.operator_rows.filter((row) => {
      const haystack = [
        scopeSummary(row),
        changeSummary(row),
        actionLabel[row.action_kind],
        scopeLabel[row.scope_kind],
        row.display_revision.reason_note,
      ]
        .join(" ")
        .toLocaleLowerCase("vi");
      return (
        (!normalized || haystack.includes(normalized)) &&
        (!statusFilter || row.temporal_state === statusFilter) &&
        (!scopeFilter || row.scope_kind === scopeFilter)
      );
    });
  }, [
    changeSummary,
    load.data.operator_rows,
    query,
    scopeFilter,
    scopeSummary,
    statusFilter,
  ]);

  function updateDraft(patch: Partial<AdjustmentDraft>) {
    setDraft((value) => ({ ...value, ...patch }));
    setPreview(null);
    setPreviewFingerprint("");
  }

  function resetDraftIdentity() {
    setDraftIds({
      adjustmentId: crypto.randomUUID(),
      revisionId: crypto.randomUUID(),
      adjustmentLineId: crypto.randomUUID(),
    });
  }

  function openCreate() {
    setEditing(null);
    setPreview(null);
    setPreviewFingerprint("");
    setDraft(emptyDraft(load.data));
    resetDraftIdentity();
    setCreateOpened(true);
  }

  function openCorrection(row: RecipeAdjustmentOperatorRecord) {
    const revision = row.command_revision;
    setDetail(null);
    setEditing(row);
    setPreview(null);
    setPreviewFingerprint("");
    setDraft({
      action: row.action_kind,
      scope: row.scope_kind,
      schoolId: row.school_id ?? firstId(load.data.schools, "school_id"),
      dishId: row.dish_id ?? firstId(load.data.dishes, "dish_id"),
      schoolTypeId: row.school_type_id ?? "",
      targetIngredientId: row.target_ingredient_id ?? "",
      targetRecipeLineId: row.target_recipe_line_id ?? "",
      substituteIngredientId: revision.substitute_ingredient_id ?? "",
      quantity: revision.quantity_per_basis?.toString() ?? "",
      unitId: revision.unit_id ?? firstId(load.data.units, "unit_id"),
      replaceQuantity:
        row.action_kind === "REPLACE" && revision.quantity_per_basis !== null,
      effectiveFrom: revision.effective_from,
      effectiveTo: revision.effective_to ?? "",
      reason: "",
      previewSchoolId: row.school_id ?? firstId(load.data.schools, "school_id"),
      previewDishId: row.dish_id ?? firstId(load.data.dishes, "dish_id"),
    });
    setDraftIds({
      adjustmentId: row.adjustment_id,
      revisionId: crypto.randomUUID(),
      adjustmentLineId: row.adjustment_line_id ?? crypto.randomUUID(),
    });
    setCreateOpened(true);
  }

  const previewSchoolId =
    draft.scope === "SCHOOL" || draft.scope === "SCHOOL_DISH"
      ? draft.schoolId
      : draft.previewSchoolId;
  const previewDishId =
    draft.scope === "SYSTEM_DISH" || draft.scope === "SCHOOL_DISH"
      ? draft.dishId
      : draft.previewDishId;

  function proposal(): Record<string, JsonValue> {
    const isAdd = draft.action === "ADD";
    const ingredientTarget =
      draft.scope === "SYSTEM_INGREDIENT" || draft.scope === "SCHOOL" || isAdd;
    const carriesUnit =
      isAdd || (draft.action === "REPLACE" && draft.replaceQuantity);
    const carriesQuantity =
      isAdd ||
      draft.action === "ADJUST_QUANTITY" ||
      (draft.action === "REPLACE" && draft.replaceQuantity);
    return {
      adjustment_id: editing?.adjustment_id ?? draftIds.adjustmentId,
      revision_id: draftIds.revisionId,
      revision_number: editing ? editing.current_revision_number + 1 : 1,
      scope_kind: draft.scope,
      action_kind: draft.action,
      school_id:
        draft.scope === "SCHOOL" || draft.scope === "SCHOOL_DISH"
          ? draft.schoolId
          : null,
      dish_id:
        draft.scope === "SYSTEM_DISH" || draft.scope === "SCHOOL_DISH"
          ? draft.dishId
          : null,
      school_type_id:
        draft.scope === "SYSTEM_DISH" && draft.schoolTypeId
          ? draft.schoolTypeId
          : null,
      target_ingredient_id: ingredientTarget ? draft.targetIngredientId : null,
      target_recipe_line_id:
        !ingredientTarget && draft.targetRecipeLineId
          ? draft.targetRecipeLineId
          : null,
      adjustment_line_id: isAdd
        ? (editing?.adjustment_line_id ?? draftIds.adjustmentLineId)
        : null,
      substitute_ingredient_id:
        draft.action === "REPLACE" ? draft.substituteIngredientId : null,
      quantity_per_basis: carriesQuantity ? Number(draft.quantity) : null,
      unit_id: carriesUnit ? draft.unitId : null,
      effective_from: draft.effectiveFrom,
      effective_to: draft.effectiveTo || null,
      reason_code: editing ? "RULE_CORRECTION" : "OPERATOR_RULE",
      reason_note: draft.reason.trim(),
      source_evidence: { source_kind: "ATLAS_OPERATOR" },
    };
  }

  const materialFingerprint = JSON.stringify({
    draft,
    previewSchoolId,
    previewDishId,
  });

  const needsRecipeLine =
    (draft.scope === "SYSTEM_DISH" || draft.scope === "SCHOOL_DISH") &&
    draft.action !== "ADD";
  const needsIngredientTarget =
    draft.scope === "SYSTEM_INGREDIENT" ||
    draft.scope === "SCHOOL" ||
    draft.action === "ADD";
  const quantityRequired =
    draft.action === "ADD" ||
    draft.action === "ADJUST_QUANTITY" ||
    (draft.action === "REPLACE" && draft.replaceQuantity);
  const canPreview =
    !!previewSchoolId &&
    !!previewDishId &&
    !!draft.effectiveFrom &&
    (!draft.effectiveTo || draft.effectiveTo > draft.effectiveFrom) &&
    !!draft.reason.trim() &&
    (!needsRecipeLine || !!draft.targetRecipeLineId) &&
    (!needsIngredientTarget || !!draft.targetIngredientId) &&
    (draft.action !== "REPLACE" || !!draft.substituteIngredientId) &&
    (!quantityRequired || Number(draft.quantity) > 0) &&
    (!(draft.action === "ADD" || draft.replaceQuantity) || !!draft.unitId);

  async function runPreview() {
    if (!api || !authSubject || !canPreview) return;
    setBusy(true);
    setNotice("");
    const result = await api.preview(authSubject, correlationId, {
      as_of_date: draft.effectiveFrom,
      school_id: previewSchoolId,
      dish_id: previewDishId,
      replaces_adjustment_id: editing?.adjustment_id ?? null,
      proposed_adjustment: proposal(),
    });
    const parsed = adjustmentPreviewFromResult(result);
    setPreview(parsed);
    setPreviewFingerprint(parsed ? materialFingerprint : "");
    setNotice(
      parsed
        ? "Đã cập nhật phần xem ảnh hưởng."
        : adjustmentResultMessage(result),
    );
    setBusy(false);
  }

  async function saveAdjustment() {
    if (
      !api ||
      !authSubject ||
      mutationLocked ||
      !preview?.can_save ||
      previewFingerprint !== materialFingerprint
    )
      return;
    setBusy(true);
    const payload = {
      ...proposal(),
      as_of_date: draft.effectiveFrom,
      preview_school_id: previewSchoolId,
      preview_dish_id: previewDishId,
      predecessor_revision_id: editing?.current_revision_id ?? null,
    };
    const request = recipeAdjustmentCommandRequest(
      authSubject,
      correlationId,
      editing?.version ?? 1,
      editing ? "RULE_CORRECTION" : "OPERATOR_RULE",
      draft.reason.trim(),
      payload,
    );
    const result = editing
      ? await api.supersede(request)
      : await api.create(request);
    setNotice(
      result.kind === "success"
        ? "Đã lưu điều chỉnh."
        : adjustmentResultMessage(result),
    );
    if (hasUnknownWriteOutcome(result)) setMutationLocked(true);
    if (result.kind === "success") {
      setCreateOpened(false);
      setEditing(null);
      setPreview(null);
      setPreviewFingerprint("");
      await refresh();
    }
    setBusy(false);
  }

  function openCancellation(row: RecipeAdjustmentOperatorRecord) {
    const from = row.command_revision.effective_from;
    setDetail(null);
    setCancelTarget(row);
    setCancelDate(referenceDate < from ? from : referenceDate);
    setCancelReason("");
  }

  async function cancelAdjustment() {
    if (
      !api ||
      !authSubject ||
      !cancelTarget ||
      !cancelDate ||
      !cancelReason.trim() ||
      mutationLocked
    )
      return;
    setBusy(true);
    const result = await api.cancel(
      recipeAdjustmentCommandRequest(
        authSubject,
        correlationId,
        cancelTarget.version,
        "RULE_CANCELLATION",
        cancelReason.trim(),
        {
          adjustment_id: cancelTarget.adjustment_id,
          predecessor_revision_id: cancelTarget.current_revision_id,
          revision_id: crypto.randomUUID(),
          effective_from: cancelDate,
        },
      ),
    );
    setNotice(
      result.kind === "success"
        ? "Đã ghi nhận hủy điều chỉnh theo ngày đã chọn."
        : adjustmentResultMessage(result),
    );
    if (hasUnknownWriteOutcome(result)) setMutationLocked(true);
    if (result.kind === "success") {
      setCancelTarget(null);
      setCancelReason("");
      await refresh();
    }
    setBusy(false);
  }

  async function resolveEffectiveComposition() {
    if (!api || !authSubject || !effectiveSchoolId || !effectiveDishId) return;
    setBusy(true);
    setNotice("");
    const result = await api.resolve(authSubject, correlationId, {
      as_of_date: effectiveDate,
      school_id: effectiveSchoolId,
      dish_id: effectiveDishId,
      review_scenario: mode === "review" ? reviewScenario : null,
    });
    const parsed = effectiveCompositionFromResult(result);
    setResolution(parsed);
    setNotice(
      parsed
        ? "Đã cập nhật công thức hiệu lực."
        : adjustmentResultMessage(result),
    );
    setBusy(false);
  }

  function previewLineKey(line: EffectiveCompositionLine) {
    return (
      line.base_recipe_line_id ?? line.adjustment_line_id ?? line.line_code
    );
  }

  function previewRows(previewData: RecipeAdjustmentPreview) {
    const keys = new Set([
      ...previewData.before.lines.map(previewLineKey),
      ...previewData.after.lines.map(previewLineKey),
    ]);
    return [...keys].map((key) => {
      const before = previewData.before.lines.find(
        (line) => previewLineKey(line) === key,
      );
      const after = previewData.after.lines.find(
        (line) => previewLineKey(line) === key,
      );
      const changed =
        before?.final_ingredient_id !== after?.final_ingredient_id ||
        before?.final_quantity_per_basis !== after?.final_quantity_per_basis ||
        before?.final_unit_id !== after?.final_unit_id ||
        before?.final_disposition !== after?.final_disposition;
      return { key, before, after, changed };
    });
  }

  function compositionText(line: EffectiveCompositionLine | undefined) {
    if (!line) return "Không có";
    if (line.final_disposition === "REMOVED") return "Đã bỏ";
    return `${referenceName(
      load.data.ingredients,
      line.final_ingredient_id,
      "ingredient_id",
      "ingredient_name",
    )} · ${formatQuantity(line.final_quantity_per_basis)} ${referenceName(
      load.data.units,
      line.final_unit_id,
      "unit_id",
      "unit_name",
    )}`;
  }

  function issuance(revision: RecipeAdjustmentOperatorRevision) {
    return revision.issuance_kind === "LEGACY_UNATTRIBUTED" ? (
      <>
        <span>{formatIssuedAt(revision.issued_at)}</span>
        <small>Không có dữ liệu từ OPS v1</small>
      </>
    ) : (
      <>
        <span>{formatIssuedAt(revision.issued_at)}</span>
        <small>{revision.issued_by_actor_name ?? "—"}</small>
      </>
    );
  }

  if (authState.status !== "authenticated")
    return (
      <Panel
        title={view === "rules" ? "ĐIỀU CHỈNH CÔNG THỨC" : "Công thức hiệu lực"}
      >
        <p className="operator-notice warning">
          Phiên làm việc đã mất. Vui lòng đăng nhập lại.
        </p>
      </Panel>
    );

  if (!api)
    return (
      <Panel
        title={view === "rules" ? "ĐIỀU CHỈNH CÔNG THỨC" : "Công thức hiệu lực"}
      >
        <p className="operator-notice warning">
          Kết nối Atlas chưa sẵn sàng. Hãy thử lại sau khi cấu hình.
        </p>
      </Panel>
    );

  return (
    <Panel
      title={view === "rules" ? "ĐIỀU CHỈNH CÔNG THỨC" : "Công thức hiệu lực"}
      description={
        view === "rules"
          ? "Thay đổi công thức đã khóa bằng điều chỉnh có ngày hiệu lực và lịch sử được giữ nguyên."
          : "Xem thành phần đang áp dụng theo ngày, trường và món đã chọn."
      }
      status={
        mode === "review" ? (
          <Chip tone="warning">Dữ liệu xem thử · không lưu</Chip>
        ) : undefined
      }
    >
      {load.status === "loading" && (
        <p className="operator-notice">Đang tải danh sách điều chỉnh…</p>
      )}
      {load.status === "error" && (
        <p className="operator-notice warning">
          {load.message}{" "}
          <button type="button" onClick={() => void refresh()}>
            Tải lại
          </button>
        </p>
      )}
      {notice && <p className="operator-notice">{notice}</p>}
      {mutationLocked && (
        <div className="operator-notice warning" role="alert">
          Chưa xác định điều chỉnh đã được ghi nhận hay chưa. Không gửi lại thao
          tác. Hãy tải lại dữ liệu trước khi tiếp tục.
          <Button ml="sm" variant="outline" onClick={() => void refresh()}>
            Tải lại dữ liệu
          </Button>
        </div>
      )}

      {view === "rules" ? (
        <section aria-label="Danh sách điều chỉnh công thức">
          <div className="adjustment-filter-grid">
            <label>
              Tìm kiếm
              <input
                type="search"
                value={query}
                placeholder="Tìm món, trường hoặc nguyên liệu..."
                onChange={(event) => setQuery(event.target.value)}
              />
            </label>
            <label>
              Ngày tham chiếu
              <input
                type="date"
                value={referenceDate}
                onChange={(event) => setReferenceDate(event.target.value)}
              />
            </label>
            <label>
              Trạng thái hiện tại
              <select
                value={statusFilter}
                onChange={(event) => setStatusFilter(event.target.value)}
              >
                <option value="">Tất cả</option>
                {(
                  Object.keys(temporalLabel) as RecipeAdjustmentTemporalState[]
                ).map((state) => (
                  <option key={state} value={state}>
                    {temporalLabel[state]}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Phạm vi
              <select
                value={scopeFilter}
                onChange={(event) => setScopeFilter(event.target.value)}
              >
                <option value="">Tất cả</option>
                {(Object.keys(scopeLabel) as RecipeAdjustmentScope[]).map(
                  (scope) => (
                    <option key={scope} value={scope}>
                      {scopeLabel[scope]}
                    </option>
                  ),
                )}
              </select>
            </label>
            <div className="table-actions">
              <Button
                type="button"
                disabled={load.status !== "ready" || mutationLocked}
                onClick={openCreate}
              >
                Tạo điều chỉnh
              </Button>
            </div>
          </div>

          <Text size="sm" c="dimmed" mb="sm">
            Trạng thái được tính tại ngày tham chiếu{" "}
            {formatDate(load.data.reference_date)}.
          </Text>

          <CompactTable
            headers={[
              "Trạng thái",
              "Món / phạm vi ảnh hưởng",
              "Loại thay đổi",
              "Nội dung thay đổi",
              "Hiệu lực",
              "Ngày ban hành",
              "Người ban hành",
              "Xem",
            ]}
          >
            {filteredRows.map((row) => (
              <tr key={row.adjustment_id}>
                <td>
                  <Badge color={temporalTone(row)} variant="light">
                    {temporalText(row)}
                  </Badge>
                </td>
                <td>{scopeSummary(row)}</td>
                <td>{actionLabel[row.action_kind]}</td>
                <td>{changeSummary(row)}</td>
                <td>
                  {formatDate(row.display_revision.effective_from)}
                  {row.display_revision.effective_to
                    ? ` – ${formatDate(row.display_revision.effective_to)}`
                    : ""}
                </td>
                <td>{formatIssuedAt(row.display_revision.issued_at)}</td>
                <td>
                  {row.display_revision.issuance_kind === "LEGACY_UNATTRIBUTED"
                    ? "Không có dữ liệu từ OPS v1"
                    : row.display_revision.issued_by_actor_name}
                </td>
                <td>
                  <Button
                    type="button"
                    variant="subtle"
                    onClick={() => setDetail(row)}
                  >
                    Xem
                  </Button>
                </td>
              </tr>
            ))}
          </CompactTable>
          {load.status === "ready" && filteredRows.length === 0 && (
            <p className="operator-notice">
              Không tìm thấy điều chỉnh phù hợp.
            </p>
          )}
        </section>
      ) : (
        <section className="effective-bom-workbench">
          <div className="adjustment-context-bar">
            <label>
              Ngày xem
              <input
                type="date"
                value={effectiveDate}
                onChange={(event) => {
                  setEffectiveDate(event.target.value);
                  setResolution(null);
                }}
              />
            </label>
            <label>
              Trường
              <select
                value={effectiveSchoolId}
                onChange={(event) => {
                  setEffectiveSchoolId(event.target.value);
                  setResolution(null);
                }}
              >
                <option value="">Chọn trường</option>
                {load.data.schools.map((school) => (
                  <option key={school.school_id} value={school.school_id}>
                    {school.school_name}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Món
              <select
                value={effectiveDishId}
                onChange={(event) => {
                  setEffectiveDishId(event.target.value);
                  setResolution(null);
                }}
              >
                <option value="">Chọn món</option>
                {load.data.dishes.map((dish) => (
                  <option key={dish.dish_id} value={dish.dish_id}>
                    {dish.dish_name}
                  </option>
                ))}
              </select>
            </label>
            {mode === "review" && (
              <label>
                Tình huống xem thử
                <select
                  value={reviewScenario}
                  onChange={(event) => {
                    setReviewScenario(event.target.value);
                    setResolution(null);
                  }}
                >
                  <option value="precedence">Nhiều lớp điều chỉnh</option>
                  <option value="replacement_chain">
                    Chuỗi thay nguyên liệu
                  </option>
                  <option value="removed">Có dòng đã bỏ</option>
                  <option value="duplicate">Trùng nguyên liệu</option>
                  <option value="cycle">Chuỗi thay thế vòng tròn</option>
                </select>
              </label>
            )}
            <Button
              type="button"
              disabled={busy || !effectiveSchoolId || !effectiveDishId}
              onClick={() => void resolveEffectiveComposition()}
            >
              {busy ? "Đang xem…" : "Xem công thức"}
            </Button>
          </div>

          {resolution && (
            <Stack gap="md">
              <Group>
                <Badge color={resolution.status === "READY" ? "green" : "red"}>
                  {resolution.status === "READY" ? "Sẵn sàng" : "Cần kiểm tra"}
                </Badge>
                <Text>
                  {resolution.selected_recipe?.selection_scope === "SCHOOL_TYPE"
                    ? "Công thức theo loại trường"
                    : "Công thức chung"}
                  {resolution.selected_recipe
                    ? ` · ${resolution.selected_recipe.basis_portions} suất`
                    : ""}
                </Text>
              </Group>
              {resolution.blockers.map((blocker) => (
                <p className="operator-notice warning" key={blocker.code}>
                  {blocker.message}
                </p>
              ))}
              <CompactTable
                headers={["Nguyên liệu", "Định lượng", "Tình trạng"]}
              >
                {resolution.lines.map((line) => (
                  <tr key={previewLineKey(line)}>
                    <td>
                      {referenceName(
                        load.data.ingredients,
                        line.final_ingredient_id,
                        "ingredient_id",
                        "ingredient_name",
                      )}
                    </td>
                    <td>
                      {formatQuantity(line.final_quantity_per_basis)}{" "}
                      {referenceName(
                        load.data.units,
                        line.final_unit_id,
                        "unit_id",
                        "unit_name",
                      )}
                    </td>
                    <td>
                      {line.final_disposition === "REMOVED"
                        ? "Đã bỏ"
                        : "Đang dùng"}
                    </td>
                  </tr>
                ))}
              </CompactTable>
              <details>
                <summary>Chi tiết kỹ thuật</summary>
                <p>
                  Atlas đã áp dụng các điều chỉnh theo thứ tự thẩm quyền đã được
                  phê duyệt. Thông tin này chỉ dành cho hỗ trợ và kiểm tra.
                </p>
                <ul>
                  {resolution.lines.map((line) => (
                    <li key={`technical:${previewLineKey(line)}`}>
                      {line.line_code ?? "Dòng được thêm"}:{" "}
                      {line.lineage.length} lần điều chỉnh được áp dụng.
                    </li>
                  ))}
                </ul>
              </details>
            </Stack>
          )}
          {!resolution && load.status === "ready" && (
            <p className="operator-notice">
              Chọn ngày, trường và món để xem công thức đang áp dụng.
            </p>
          )}
        </section>
      )}

      <Modal
        opened={createOpened}
        onClose={() => !busy && setCreateOpened(false)}
        title={editing ? "Điều chỉnh lại" : "Tạo điều chỉnh"}
        size="lg"
        centered
        closeOnClickOutside={!busy}
      >
        <Stack gap="md">
          <fieldset>
            <legend>Bạn muốn thay đổi gì?</legend>
            <div className="adjustment-choice-grid">
              {(
                [
                  "REPLACE",
                  "ADJUST_QUANTITY",
                  "ADD",
                  "REMOVE",
                ] as RecipeAdjustmentAction[]
              ).map((action) => (
                <label key={action}>
                  <input
                    type="radio"
                    name="adjustment-action"
                    value={action}
                    checked={draft.action === action}
                    disabled={!!editing}
                    onChange={() => {
                      const scopes = availableScopes(action);
                      updateDraft({
                        action,
                        scope: scopes[0],
                        targetIngredientId: "",
                        targetRecipeLineId: "",
                        substituteIngredientId: "",
                        quantity: "",
                        replaceQuantity: false,
                      });
                    }}
                  />
                  {actionLabel[action]}
                </label>
              ))}
            </div>
          </fieldset>

          <fieldset>
            <legend>Áp dụng ở đâu?</legend>
            <div className="adjustment-choice-grid">
              {availableScopes(draft.action).map((scope) => (
                <label key={scope}>
                  <input
                    type="radio"
                    name="adjustment-scope"
                    value={scope}
                    checked={draft.scope === scope}
                    disabled={!!editing}
                    onChange={() =>
                      updateDraft({
                        scope,
                        schoolTypeId: "",
                        targetIngredientId: "",
                        targetRecipeLineId: "",
                      })
                    }
                  />
                  {scopeLabel[scope]}
                </label>
              ))}
            </div>
          </fieldset>

          {(draft.scope === "SCHOOL" || draft.scope === "SCHOOL_DISH") && (
            <label>
              Trường áp dụng
              <select
                value={draft.schoolId}
                disabled={!!editing}
                onChange={(event) =>
                  updateDraft({ schoolId: event.target.value })
                }
              >
                <option value="">Chọn trường</option>
                {load.data.schools.map((school) => (
                  <option key={school.school_id} value={school.school_id}>
                    {school.school_name}
                  </option>
                ))}
              </select>
            </label>
          )}

          {(draft.scope === "SYSTEM_DISH" || draft.scope === "SCHOOL_DISH") && (
            <label>
              Món áp dụng
              <select
                value={draft.dishId}
                disabled={!!editing}
                onChange={(event) =>
                  updateDraft({
                    dishId: event.target.value,
                    targetRecipeLineId: "",
                  })
                }
              >
                <option value="">Chọn món</option>
                {load.data.dishes.map((dish) => (
                  <option key={dish.dish_id} value={dish.dish_id}>
                    {dish.dish_name}
                  </option>
                ))}
              </select>
            </label>
          )}

          {draft.scope === "SYSTEM_DISH" && (
            <label>
              Loại trường (không bắt buộc)
              <select
                value={draft.schoolTypeId}
                disabled={!!editing}
                onChange={(event) =>
                  updateDraft({ schoolTypeId: event.target.value })
                }
              >
                <option value="">Tất cả loại trường</option>
                {load.data.school_types.map((schoolType) => (
                  <option
                    key={schoolType.school_type_id ?? "school-type"}
                    value={schoolType.school_type_id ?? ""}
                  >
                    {schoolType.school_type_name}
                  </option>
                ))}
              </select>
            </label>
          )}

          {needsIngredientTarget && (
            <label>
              {draft.action === "ADD"
                ? "Nguyên liệu thêm"
                : "Nguyên liệu cần thay đổi"}
              <select
                value={draft.targetIngredientId}
                disabled={!!editing}
                onChange={(event) =>
                  updateDraft({ targetIngredientId: event.target.value })
                }
              >
                <option value="">Chọn nguyên liệu</option>
                {load.data.ingredients.map((ingredient) => (
                  <option
                    key={ingredient.ingredient_id}
                    value={ingredient.ingredient_id}
                  >
                    {ingredient.ingredient_name}
                  </option>
                ))}
              </select>
            </label>
          )}

          {needsRecipeLine && (
            <label>
              Nguyên liệu trong công thức
              <select
                value={draft.targetRecipeLineId}
                disabled={!!editing}
                onChange={(event) =>
                  updateDraft({ targetRecipeLineId: event.target.value })
                }
              >
                <option value="">Chọn nguyên liệu trong món</option>
                {lineOptions.map((line) => (
                  <option key={line.recipe_line_id} value={line.recipe_line_id}>
                    {line.ingredient_name} ·{" "}
                    {formatQuantity(line.quantity_per_basis)} {line.unit_name}
                  </option>
                ))}
              </select>
            </label>
          )}

          {draft.action === "REPLACE" && (
            <>
              <label>
                Nguyên liệu mới
                <select
                  value={draft.substituteIngredientId}
                  onChange={(event) =>
                    updateDraft({ substituteIngredientId: event.target.value })
                  }
                >
                  <option value="">Chọn nguyên liệu mới</option>
                  {load.data.ingredients.map((ingredient) => (
                    <option
                      key={ingredient.ingredient_id}
                      value={ingredient.ingredient_id}
                    >
                      {ingredient.ingredient_name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={draft.replaceQuantity}
                  onChange={(event) =>
                    updateDraft({
                      replaceQuantity: event.target.checked,
                      quantity: event.target.checked ? draft.quantity : "",
                    })
                  }
                />{" "}
                Đổi cả định lượng
              </label>
            </>
          )}

          {quantityRequired && (
            <label>
              Định lượng mới
              <input
                type="number"
                min="0.000001"
                step="0.000001"
                value={draft.quantity}
                onChange={(event) =>
                  updateDraft({ quantity: event.target.value })
                }
              />
            </label>
          )}

          {(draft.action === "ADD" || draft.replaceQuantity) && (
            <label>
              Đơn vị
              <select
                value={draft.unitId}
                onChange={(event) =>
                  updateDraft({ unitId: event.target.value })
                }
              >
                <option value="">Chọn đơn vị</option>
                {load.data.units.map((unit) => (
                  <option key={unit.unit_id} value={unit.unit_id}>
                    {unit.unit_name}
                  </option>
                ))}
              </select>
            </label>
          )}

          <div className="adjustment-period-grid">
            <label>
              Hiệu lực từ
              <input
                type="date"
                value={draft.effectiveFrom}
                onChange={(event) =>
                  updateDraft({ effectiveFrom: event.target.value })
                }
              />
            </label>
            <label>
              Hiệu lực đến (không bắt buộc)
              <input
                type="date"
                value={draft.effectiveTo}
                onChange={(event) =>
                  updateDraft({ effectiveTo: event.target.value })
                }
              />
            </label>
          </div>

          <label>
            Lý do
            <textarea
              value={draft.reason}
              onChange={(event) => updateDraft({ reason: event.target.value })}
            />
          </label>

          <Divider
            label="Bối cảnh dùng để xem ảnh hưởng"
            labelPosition="left"
          />
          <Text size="sm" c="dimmed">
            Bối cảnh này dùng để hiển thị thành phần công thức hiệu lực sau điều
            chỉnh. Với phạm vi rộng, đây là một bối cảnh đại diện, không phải
            danh sách toàn bộ món bị ảnh hưởng.
          </Text>

          {draft.scope === "SYSTEM_INGREDIENT" && (
            <>
              <label>
                Trường đại diện
                <select
                  value={draft.previewSchoolId}
                  onChange={(event) =>
                    updateDraft({ previewSchoolId: event.target.value })
                  }
                >
                  <option value="">Chọn trường</option>
                  {load.data.schools.map((school) => (
                    <option key={school.school_id} value={school.school_id}>
                      {school.school_name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Món đại diện
                <select
                  value={draft.previewDishId}
                  onChange={(event) =>
                    updateDraft({ previewDishId: event.target.value })
                  }
                >
                  <option value="">Chọn món</option>
                  {load.data.dishes.map((dish) => (
                    <option key={dish.dish_id} value={dish.dish_id}>
                      {dish.dish_name}
                    </option>
                  ))}
                </select>
              </label>
            </>
          )}

          {draft.scope === "SYSTEM_DISH" && (
            <label>
              Trường dùng để xem
              <select
                value={draft.previewSchoolId}
                onChange={(event) =>
                  updateDraft({ previewSchoolId: event.target.value })
                }
              >
                <option value="">Chọn trường</option>
                {load.data.schools.map((school) => (
                  <option key={school.school_id} value={school.school_id}>
                    {school.school_name}
                  </option>
                ))}
              </select>
            </label>
          )}

          {draft.scope === "SCHOOL" && (
            <label>
              Món dùng để xem
              <select
                value={draft.previewDishId}
                onChange={(event) =>
                  updateDraft({ previewDishId: event.target.value })
                }
              >
                <option value="">Chọn món</option>
                {load.data.dishes.map((dish) => (
                  <option key={dish.dish_id} value={dish.dish_id}>
                    {dish.dish_name}
                  </option>
                ))}
              </select>
            </label>
          )}

          {draft.scope === "SCHOOL_DISH" && (
            <Text size="sm">
              Trường và món đã được xác định trong phạm vi điều chỉnh.
            </Text>
          )}

          {preview && (
            <section
              className="adjustment-preview-card"
              aria-label="Ảnh hưởng điều chỉnh"
            >
              <Group justify="space-between">
                <Text fw={700}>Trước điều chỉnh → Sau điều chỉnh</Text>
                <Badge color={preview.can_save ? "green" : "red"}>
                  {preview.can_save ? "Có thể lưu" : "Cần kiểm tra"}
                </Badge>
              </Group>
              {preview.blockers.map((blocker) => (
                <p className="operator-notice warning" key={blocker.code}>
                  {blocker.message}
                </p>
              ))}
              <CompactTable
                headers={[
                  "Dòng ảnh hưởng",
                  "Trước điều chỉnh",
                  "Sau điều chỉnh",
                ]}
              >
                {previewRows(preview).map(({ key, before, after, changed }) => (
                  <tr
                    key={key}
                    className={changed ? "adjustment-preview-changed" : ""}
                  >
                    <td>
                      {after?.line_code ??
                        before?.line_code ??
                        "Nguyên liệu được thêm"}
                    </td>
                    <td>{compositionText(before)}</td>
                    <td>{compositionText(after)}</td>
                  </tr>
                ))}
              </CompactTable>
            </section>
          )}

          <Group justify="flex-end">
            <Button
              type="button"
              variant="outline"
              disabled={busy || !canPreview}
              onClick={() => void runPreview()}
            >
              {busy ? "Đang xem…" : "Xem ảnh hưởng"}
            </Button>
            <Button
              type="button"
              disabled={
                busy ||
                mutationLocked ||
                !preview?.can_save ||
                previewFingerprint !== materialFingerprint
              }
              onClick={() => void saveAdjustment()}
            >
              Lưu điều chỉnh
            </Button>
          </Group>
        </Stack>
      </Modal>

      <Drawer
        opened={!!detail}
        onClose={() => setDetail(null)}
        title="Chi tiết điều chỉnh"
        position="right"
        size="lg"
      >
        {detail && (
          <Stack gap="md">
            <Badge color={temporalTone(detail)} variant="light">
              {temporalText(detail)}
            </Badge>
            <div>
              <Text size="sm" c="dimmed">
                Phạm vi
              </Text>
              <Text fw={600}>{scopeSummary(detail)}</Text>
              <Text>{scopeLabel[detail.scope_kind]}</Text>
            </div>
            <div>
              <Text size="sm" c="dimmed">
                Nội dung thay đổi
              </Text>
              <Text fw={600}>{actionLabel[detail.action_kind]}</Text>
              <Text>{changeSummary(detail)}</Text>
            </div>
            <div>
              <Text size="sm" c="dimmed">
                Hiệu lực
              </Text>
              <Text>
                {formatDate(detail.display_revision.effective_from)}
                {detail.display_revision.effective_to
                  ? ` – ${formatDate(detail.display_revision.effective_to)}`
                  : " trở đi"}
              </Text>
            </div>
            <div>
              <Text size="sm" c="dimmed">
                Lý do
              </Text>
              <Text>{detail.display_revision.reason_note}</Text>
            </div>
            <div>
              <Text size="sm" c="dimmed">
                Thông tin ban hành
              </Text>
              <Text component="div">{issuance(detail.display_revision)}</Text>
            </div>
            <Divider label="Lịch sử điều chỉnh" labelPosition="left" />
            <ol className="adjustment-history-list">
              {detail.history.map((revision) => (
                <li key={revision.revision_id}>
                  <Text fw={600}>
                    {revision.business_event_kind === "CANCELLED"
                      ? "Hủy điều chỉnh"
                      : revision.business_event_kind === "CREATED"
                        ? "Tạo điều chỉnh"
                        : "Điều chỉnh lại"}
                  </Text>
                  <Text>{changeSummary(detail, revision)}</Text>
                  <Text size="sm">
                    Hiệu lực từ {formatDate(revision.effective_from)}
                    {revision.effective_to
                      ? ` đến ${formatDate(revision.effective_to)}`
                      : ""}
                  </Text>
                  <Text size="sm">{revision.reason_note}</Text>
                  <Text size="sm" component="div">
                    {issuance(revision)}
                  </Text>
                </li>
              ))}
            </ol>
            <Group>
              {detail.can_correct && (
                <Button
                  disabled={mutationLocked}
                  onClick={() => openCorrection(detail)}
                >
                  Điều chỉnh lại
                </Button>
              )}
              {detail.can_cancel && (
                <Button
                  color="red"
                  variant="outline"
                  disabled={mutationLocked}
                  onClick={() => openCancellation(detail)}
                >
                  Hủy điều chỉnh
                </Button>
              )}
            </Group>
          </Stack>
        )}
      </Drawer>

      <Modal
        opened={!!cancelTarget}
        onClose={() => !busy && setCancelTarget(null)}
        title="Hủy điều chỉnh"
        centered
      >
        <Stack gap="md">
          <Text>Lịch sử điều chỉnh được giữ nguyên.</Text>
          <label>
            Hiệu lực hủy từ
            <input
              type="date"
              value={cancelDate}
              onChange={(event) => setCancelDate(event.target.value)}
            />
          </label>
          <label>
            Lý do
            <textarea
              value={cancelReason}
              onChange={(event) => setCancelReason(event.target.value)}
            />
          </label>
          <Group justify="flex-end">
            <Button variant="subtle" onClick={() => setCancelTarget(null)}>
              Quay lại
            </Button>
            <Button
              color="red"
              disabled={
                busy || mutationLocked || !cancelDate || !cancelReason.trim()
              }
              onClick={() => void cancelAdjustment()}
            >
              Xác nhận hủy
            </Button>
          </Group>
        </Stack>
      </Modal>
    </Panel>
  );
}
