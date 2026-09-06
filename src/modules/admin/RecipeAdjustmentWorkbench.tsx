import {
  Badge,
  Box,
  Button,
  Checkbox,
  Divider,
  Drawer,
  Group,
  Modal,
  NativeSelect,
  Paper,
  Radio,
  Select,
  SimpleGrid,
  Stack,
  Table,
  Text,
  Textarea,
  TextInput,
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
  effectiveTargetContextFromResult,
  effectiveCompositionFromResult,
  emptyRecipeAdjustmentWorkbench,
  type AdjustmentReference,
  type EffectiveCompositionLine,
  type EffectiveCompositionResult,
  type EffectiveTargetContext,
  type RecipeAdjustmentAction,
  type RecipeAdjustmentOperatorRecord,
  type RecipeAdjustmentOperatorRevision,
  type RecipeAdjustmentOperatorContent,
  type RecipeAdjustmentPreview,
  type RecipeAdjustmentScope,
  type RecipeAdjustmentTemporalState,
  type RecipeAdjustmentWorkbenchData,
} from "../atlas/recipe-adjustments/recipeAdjustmentModel";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";

type LoadState = {
  status: "idle" | "loading" | "ready" | "error";
  data: RecipeAdjustmentWorkbenchData;
  authSubject?: string;
  message?: string;
};

type AdjustmentDraft = {
  action: RecipeAdjustmentAction | "";
  scope: RecipeAdjustmentScope;
  schoolId: string;
  dishId: string;
  schoolTypeId: string;
  targetIngredientId: string;
  targetRecipeLineId: string;
  targetAdjustmentLineId: string;
  substituteIngredientId: string;
  quantity: string;
  replaceQuantity: boolean;
  effectiveFrom: string;
  effectiveTo: string;
  reason: string;
  previewSchoolId: string;
  previewDishId: string;
};

type AdjustmentBusinessObject = "RECIPE" | "INGREDIENT";
type AdjustmentAuthority = "ALL_SCHOOLS" | "ONE_SCHOOL";

const ACTIONS_BY_SCOPE: Record<
  RecipeAdjustmentScope,
  RecipeAdjustmentAction[]
> = {
  SYSTEM_INGREDIENT: ["REPLACE"],
  SYSTEM_DISH: ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"],
  SCHOOL: ["REPLACE", "REMOVE"],
  SCHOOL_DISH: ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"],
};

const businessObjectLabel: Record<AdjustmentBusinessObject, string> = {
  RECIPE: "Công thức của một món",
  INGREDIENT: "Một nguyên liệu",
};

const authorityLabel: Record<AdjustmentAuthority, string> = {
  ALL_SCHOOLS: "Tất cả trường",
  ONE_SCHOOL: "Một trường",
};

function businessObjectFromScope(
  scope: RecipeAdjustmentScope,
): AdjustmentBusinessObject {
  return scope === "SYSTEM_DISH" || scope === "SCHOOL_DISH"
    ? "RECIPE"
    : "INGREDIENT";
}

function authorityFromScope(scope: RecipeAdjustmentScope): AdjustmentAuthority {
  return scope === "SYSTEM_DISH" || scope === "SYSTEM_INGREDIENT"
    ? "ALL_SCHOOLS"
    : "ONE_SCHOOL";
}

function scopeFromDecisions(
  businessObject: AdjustmentBusinessObject,
  authority: AdjustmentAuthority,
): RecipeAdjustmentScope {
  if (businessObject === "RECIPE")
    return authority === "ALL_SCHOOLS" ? "SYSTEM_DISH" : "SCHOOL_DISH";
  return authority === "ALL_SCHOOLS" ? "SYSTEM_INGREDIENT" : "SCHOOL";
}

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

export function vietnamLocalDate(value: Date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Ho_Chi_Minh",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(value);
  const part = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((item) => item.type === type)?.value ?? "";
  return `${part("year")}-${part("month")}-${part("day")}`;
}

function formatDate(value: string | null | undefined) {
  if (!value) return "—";
  const [year, month, day] = value.slice(0, 10).split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

function formatIssuedAt(value: string | null | undefined) {
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

function schoolTypeIdForSchool(
  data: RecipeAdjustmentWorkbenchData,
  schoolId: string,
) {
  return (
    data.schools.find((school) => school.school_id === schoolId)
      ?.school_type_id ?? ""
  );
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

function emptyDraft(): AdjustmentDraft {
  return {
    action: "",
    scope: "SYSTEM_DISH",
    schoolId: "",
    dishId: "",
    schoolTypeId: "",
    targetIngredientId: "",
    targetRecipeLineId: "",
    targetAdjustmentLineId: "",
    substituteIngredientId: "",
    quantity: "",
    replaceQuantity: false,
    effectiveFrom: vietnamLocalDate(),
    effectiveTo: "",
    reason: "",
    previewSchoolId: "",
    previewDishId: "",
  };
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

type PendingMutation = {
  authSubject: string;
  outcome: "in_flight" | "unknown" | "committed" | "denied";
  adjustmentId: string;
  revisionId: string;
  predecessorRevisionId: string | null;
};

function hasMutationEvidence(
  data: RecipeAdjustmentWorkbenchData,
  pending: PendingMutation,
) {
  const row = data.operator_rows.find(
    (candidate) => candidate.adjustment_id === pending.adjustmentId,
  );
  if (!row) return false;
  const revisionIds = new Set([
    row.current_revision_id,
    ...row.history.map((revision) => revision.revision_id),
  ]);
  return (
    revisionIds.has(pending.revisionId) &&
    (!pending.predecessorRevisionId ||
      revisionIds.has(pending.predecessorRevisionId))
  );
}

function formatEffectivePeriod(from: string, to: string | null | undefined) {
  return `${formatDate(from)}${to ? ` – đến trước ${formatDate(to)}` : " trở đi"}`;
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
  const [referenceDate, setReferenceDate] = useState(vietnamLocalDate());
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
  const [draft, setDraft] = useState<AdjustmentDraft>(() => emptyDraft());
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
  const [modalStep, setModalStep] = useState<"EDIT" | "REVIEW">("EDIT");
  const [cancelTarget, setCancelTarget] =
    useState<RecipeAdjustmentOperatorRecord | null>(null);
  const [cancelDate, setCancelDate] = useState(vietnamLocalDate());
  const [cancelReason, setCancelReason] = useState("");
  const [resolution, setResolution] =
    useState<EffectiveCompositionResult | null>(null);
  const [effectiveSchoolId, setEffectiveSchoolId] = useState("");
  const [effectiveDishId, setEffectiveDishId] = useState("");
  const [effectiveDate, setEffectiveDate] = useState(vietnamLocalDate());
  const [reviewScenario, setReviewScenario] = useState("precedence");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const [mutationLocked, setMutationLocked] = useState(false);
  const [targetContext, setTargetContext] =
    useState<EffectiveTargetContext | null>(null);
  const [targetContextStatus, setTargetContextStatus] = useState<
    "idle" | "loading" | "ready" | "error"
  >("idle");
  const [targetContextMessage, setTargetContextMessage] = useState("");
  const generation = useRef(0);
  const targetGeneration = useRef(0);
  const previewGeneration = useRef(0);
  const effectiveGeneration = useRef(0);
  const pendingMutation = useRef<PendingMutation | null>(null);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;
  const authSubjectRef = useRef(authSubject);
  authSubjectRef.current = authSubject;
  const authorityOwned =
    !!authSubject &&
    load.authSubject === authSubject &&
    load.status !== "error";
  const authorityReady = authorityOwned && load.status === "ready";
  const effectiveIntent = JSON.stringify({
    authSubject,
    effectiveDate,
    effectiveSchoolId,
    effectiveDishId,
    reviewScenario: mode === "review" ? reviewScenario : null,
  });
  const effectiveIntentRef = useRef(effectiveIntent);
  effectiveIntentRef.current = effectiveIntent;

  useEffect(() => {
    generation.current += 1;
    targetGeneration.current += 1;
    previewGeneration.current += 1;
    effectiveGeneration.current += 1;
    setLoad({ status: "idle", data: emptyRecipeAdjustmentWorkbench() });
    setTargetContext(null);
    setTargetContextStatus("idle");
    setPreview(null);
    setPreviewFingerprint("");
    setResolution(null);
    setCreateOpened(false);
    setDetail(null);
    setEditing(null);
    setCancelTarget(null);
    setDraft(emptyDraft());
    setNotice("");
    setBusy(false);
    setMutationLocked(pendingMutation.current !== null);
  }, [authSubject]);

  // Refresh current operation automatically at the Vietnam business-day boundary.
  // The separate effective-inspection date never controls the current ledger.
  useEffect(() => {
    const updateDate = () => setReferenceDate(vietnamLocalDate());
    const nextMidnight =
      Date.parse(`${vietnamLocalDate()}T00:00:00+07:00`) + 86_400_000;
    const timer = window.setTimeout(
      updateDate,
      Math.max(1, nextMidnight - Date.now() + 50),
    );
    window.addEventListener("focus", updateDate);
    return () => {
      window.clearTimeout(timer);
      window.removeEventListener("focus", updateDate);
    };
  }, [referenceDate]);

  const refresh = useCallback(
    async (expectedAuthSubject = authSubject) => {
      if (
        !api ||
        !expectedAuthSubject ||
        authSubjectRef.current !== expectedAuthSubject
      )
        return false;
      const current = ++generation.current;
      const requestedReferenceDate = vietnamLocalDate();
      setLoad((state) => ({ ...state, status: "loading", message: undefined }));
      const result = await api.getOperatorWorkbench(
        expectedAuthSubject,
        correlationId,
        requestedReferenceDate,
      );
      if (
        current !== generation.current ||
        authSubjectRef.current !== expectedAuthSubject
      )
        return false;
      const data = adjustmentWorkbenchFromResult(result);
      if (
        !data ||
        data.reference_date !== requestedReferenceDate ||
        vietnamLocalDate() !== requestedReferenceDate
      ) {
        setLoad({
          data: emptyRecipeAdjustmentWorkbench(),
          status: "error",
          message:
            result.kind === "success"
              ? "Dữ liệu tham chiếu điều chỉnh không hợp lệ. Hãy tải lại."
              : adjustmentResultMessage(result),
        });
        return false;
      }
      setLoad({ status: "ready", data, authSubject: expectedAuthSubject });
      setEffectiveSchoolId(
        (value) => value || firstId(data.schools, "school_id"),
      );
      setEffectiveDishId((value) => value || firstId(data.dishes, "dish_id"));
      const pending = pendingMutation.current;
      if (
        pending &&
        pending.authSubject === expectedAuthSubject &&
        (pending.outcome === "denied" || hasMutationEvidence(data, pending))
      ) {
        pendingMutation.current = null;
        setMutationLocked(false);
        setBusy(false);
        setCreateOpened(false);
        setEditing(null);
        setPreview(null);
        setPreviewFingerprint("");
        setCancelTarget(null);
        setCancelReason("");
      }
      return true;
    },
    [api, authSubject, correlationId],
  );

  useEffect(() => {
    if (authSubject && api) void refresh();
  }, [api, authSubject, refresh, referenceDate]);

  const selectedRecipeSchoolTypeId =
    draft.scope === "SYSTEM_DISH"
      ? draft.schoolTypeId
      : draft.scope === "SCHOOL_DISH"
        ? schoolTypeIdForSchool(load.data, draft.schoolId)
        : "";
  const selectedRecipeSchoolTypeName =
    draft.scope === "SCHOOL_DISH" && !draft.schoolId
      ? "Chọn trường để xác định"
      : referenceName(
          load.data.school_types,
          selectedRecipeSchoolTypeId,
          "school_type_id",
          "school_type_name",
        );
  const lineOptions = targetContext?.effective_lines ?? [];

  useEffect(() => {
    const recipeScope =
      draft.scope === "SYSTEM_DISH" || draft.scope === "SCHOOL_DISH";
    const shouldLoad =
      !!api &&
      !!authSubject &&
      authorityOwned &&
      createOpened &&
      recipeScope &&
      draft.action !== "" &&
      draft.action !== "ADD" &&
      !!draft.dishId &&
      !!draft.effectiveFrom &&
      (draft.scope === "SYSTEM_DISH" ? !!draft.schoolTypeId : !!draft.schoolId);
    const requestNumber = ++targetGeneration.current;
    if (!shouldLoad) {
      setTargetContext(null);
      setTargetContextStatus("idle");
      setTargetContextMessage("");
      return;
    }
    const context =
      draft.scope === "SYSTEM_DISH"
        ? ({ kind: "system", schoolTypeId: draft.schoolTypeId } as const)
        : ({ kind: "school", schoolId: draft.schoolId } as const);
    setTargetContext(null);
    setTargetContextStatus("loading");
    setTargetContextMessage("");
    void api
      .getEffectiveTargetContext(
        authSubject,
        correlationId,
        draft.effectiveFrom,
        draft.dishId,
        context,
      )
      .then((result) => {
        if (
          requestNumber !== targetGeneration.current ||
          authSubjectRef.current !== authSubject
        )
          return;
        const parsed = effectiveTargetContextFromResult(result);
        const matches =
          parsed?.as_of_date === draft.effectiveFrom &&
          parsed.dish_id === draft.dishId &&
          (context.kind === "system"
            ? parsed.school_id === null &&
              parsed.school_type_id === context.schoolTypeId
            : parsed.school_id === context.schoolId &&
              parsed.school_type_id ===
                schoolTypeIdForSchool(load.data, context.schoolId));
        if (!parsed || !matches) {
          setTargetContextStatus("error");
          setTargetContextMessage(
            `Không thể tải mục tiêu hiệu lực. ${adjustmentResultMessage(result)}`,
          );
          return;
        }
        setTargetContext(parsed);
        setTargetContextStatus("ready");
      });
  }, [
    api,
    authSubject,
    authorityOwned,
    correlationId,
    createOpened,
    draft.action,
    draft.dishId,
    draft.effectiveFrom,
    draft.schoolId,
    draft.schoolTypeId,
    draft.scope,
    load.data,
  ]);

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
      const schoolType = referenceName(
        load.data.school_types,
        row.school_type_id,
        "school_type_id",
        "school_type_name",
      );
      const ingredient = targetName(row);
      switch (row.scope_kind) {
        case "SYSTEM_INGREDIENT":
          return `${ingredient} · ${scopeLabel[row.scope_kind]}`;
        case "SYSTEM_DISH":
          return `${dish} · ${schoolType} · ${scopeLabel[row.scope_kind]}`;
        case "SCHOOL":
          return `${school} · ${scopeLabel[row.scope_kind]}`;
        case "SCHOOL_DISH":
          return `${dish} · ${school}`;
      }
    },
    [load.data.dishes, load.data.school_types, load.data.schools, targetName],
  );

  const changeSummary = useCallback(
    (
      row: RecipeAdjustmentOperatorRecord,
      revision: RecipeAdjustmentOperatorContent = row.content_revision,
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
    previewGeneration.current += 1;
    setDraft((value) => ({ ...value, ...patch }));
    setPreview(null);
    setPreviewFingerprint("");
    setModalStep("EDIT");
  }

  function resetDraftIdentity() {
    setDraftIds({
      adjustmentId: crypto.randomUUID(),
      revisionId: crypto.randomUUID(),
      adjustmentLineId: crypto.randomUUID(),
    });
  }

  function openCreate() {
    if (
      authSubjectRef.current !== authSubject ||
      !authorityReady ||
      busy ||
      mutationLocked
    )
      return;
    setEditing(null);
    setPreview(null);
    setPreviewFingerprint("");
    setModalStep("EDIT");
    setDraft(emptyDraft());
    resetDraftIdentity();
    setCreateOpened(true);
  }

  function openCorrection(row: RecipeAdjustmentOperatorRecord) {
    if (
      authSubjectRef.current !== authSubject ||
      !authorityReady ||
      busy ||
      mutationLocked
    )
      return;
    const revision = row.command_revision;
    const schoolId = row.school_id ?? firstId(load.data.schools, "school_id");
    const schoolTypeId =
      row.scope_kind === "SYSTEM_DISH"
        ? (row.school_type_id ?? "")
        : row.scope_kind === "SCHOOL_DISH"
          ? schoolTypeIdForSchool(load.data, schoolId)
          : "";
    setDetail(null);
    setEditing(row);
    setPreview(null);
    setPreviewFingerprint("");
    setModalStep("EDIT");
    setDraft({
      action: row.action_kind,
      scope: row.scope_kind,
      schoolId,
      dishId: row.dish_id ?? firstId(load.data.dishes, "dish_id"),
      schoolTypeId,
      targetIngredientId: row.target_ingredient_id ?? "",
      targetRecipeLineId: row.target_recipe_line_id ?? "",
      targetAdjustmentLineId: row.adjustment_line_id ?? "",
      substituteIngredientId: revision.substitute_ingredient_id ?? "",
      quantity: revision.quantity_per_basis?.toString() ?? "",
      replaceQuantity:
        row.action_kind === "REPLACE" && revision.quantity_per_basis !== null,
      effectiveFrom: revision.effective_from,
      effectiveTo: revision.effective_to ?? "",
      reason: "",
      previewSchoolId: row.scope_kind === "SYSTEM_DISH" ? "" : schoolId,
      previewDishId: row.dish_id ?? firstId(load.data.dishes, "dish_id"),
    });
    setDraftIds({
      adjustmentId: row.adjustment_id,
      revisionId: crypto.randomUUID(),
      adjustmentLineId: row.adjustment_line_id ?? crypto.randomUUID(),
    });
    setCreateOpened(true);
  }

  const draftBusinessObject = businessObjectFromScope(draft.scope);
  const draftAuthority = authorityFromScope(draft.scope);
  const allowedActions = ACTIONS_BY_SCOPE[draft.scope];

  function changeBusinessObject(businessObject: AdjustmentBusinessObject) {
    const authority: AdjustmentAuthority = "ALL_SCHOOLS";
    const scope = scopeFromDecisions(businessObject, authority);
    updateDraft({
      action: "",
      scope,
      schoolId: "",
      dishId: "",
      schoolTypeId: "",
      targetIngredientId: "",
      targetRecipeLineId: "",
      targetAdjustmentLineId: "",
      substituteIngredientId: "",
      quantity: "",
      replaceQuantity: false,
      previewSchoolId: "",
      previewDishId: "",
    });
  }

  function changeAuthority(authority: AdjustmentAuthority) {
    const scope = scopeFromDecisions(draftBusinessObject, authority);
    const nextAllowedActions = ACTIONS_BY_SCOPE[scope];
    updateDraft({
      action:
        draft.action && nextAllowedActions.includes(draft.action)
          ? draft.action
          : "",
      scope,
      schoolId: "",
      dishId: "",
      schoolTypeId: "",
      targetIngredientId: "",
      targetRecipeLineId: "",
      targetAdjustmentLineId: "",
      substituteIngredientId: "",
      quantity: "",
      replaceQuantity: false,
      previewSchoolId: "",
      previewDishId: "",
    });
  }

  function changeAction(action: RecipeAdjustmentAction) {
    const ingredientScope =
      draft.scope === "SYSTEM_INGREDIENT" || draft.scope === "SCHOOL";
    updateDraft({
      action,
      targetIngredientId: ingredientScope ? draft.targetIngredientId : "",
      targetRecipeLineId: "",
      targetAdjustmentLineId: "",
      substituteIngredientId: "",
      quantity: "",
      replaceQuantity: false,
    });
  }

  function changeTarget(patch: Partial<AdjustmentDraft>) {
    updateDraft({
      ...patch,
      targetIngredientId: "",
      targetRecipeLineId: "",
      targetAdjustmentLineId: "",
      substituteIngredientId: "",
      quantity: "",
      replaceQuantity: false,
    });
  }

  function changeSchool(schoolId: string) {
    changeTarget({
      schoolId,
      schoolTypeId:
        draft.scope === "SCHOOL_DISH"
          ? schoolTypeIdForSchool(load.data, schoolId)
          : "",
      previewSchoolId: schoolId,
      previewDishId: "",
      dishId: draft.scope === "SCHOOL_DISH" ? "" : draft.dishId,
    });
  }

  function changeDish(dishId: string) {
    changeTarget({ dishId, previewDishId: "" });
  }

  function changeRecipeSchoolType(schoolTypeId: string) {
    changeTarget({
      schoolTypeId,
      previewSchoolId: "",
      previewDishId: "",
    });
  }

  const previewSchoolId =
    draft.scope === "SCHOOL" || draft.scope === "SCHOOL_DISH"
      ? draft.schoolId
      : draft.previewSchoolId;
  const previewDishId =
    draft.scope === "SYSTEM_DISH" || draft.scope === "SCHOOL_DISH"
      ? draft.dishId
      : draft.previewDishId;
  const selectedTargetIngredient = load.data.ingredients.find(
    (ingredient) => ingredient.ingredient_id === draft.targetIngredientId,
  );
  const selectedSubstituteIngredient = load.data.ingredients.find(
    (ingredient) => ingredient.ingredient_id === draft.substituteIngredientId,
  );
  const selectedTargetLine = lineOptions.find(
    (line) =>
      (line.target_recipe_line_id ?? "") === draft.targetRecipeLineId &&
      (line.adjustment_line_id ?? "") === draft.targetAdjustmentLineId,
  );
  const purchaseUnitIngredient =
    draft.action === "ADD"
      ? selectedTargetIngredient
      : draft.action === "REPLACE" && draft.replaceQuantity
        ? selectedSubstituteIngredient
        : undefined;
  const proposalUnitId = purchaseUnitIngredient?.purchase_unit_id ?? "";
  const draftUnitName =
    draft.action === "ADJUST_QUANTITY"
      ? (selectedTargetLine?.unit_name ?? "—")
      : (purchaseUnitIngredient?.purchase_unit_name ?? "—");
  const requiresPurchaseUnit =
    draft.action === "ADD" ||
    (draft.action === "REPLACE" && draft.replaceQuantity);
  const missingPurchaseUnit =
    requiresPurchaseUnit && !!purchaseUnitIngredient && !proposalUnitId;
  const missingPurchaseUnitMessage = missingPurchaseUnit
    ? "Nguyên liệu đã chọn chưa có đơn vị mua. Hãy cập nhật danh mục nguyên liệu trước khi xem ảnh hưởng."
    : undefined;

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
        : !ingredientTarget && draft.targetAdjustmentLineId
          ? draft.targetAdjustmentLineId
          : null,
      substitute_ingredient_id:
        draft.action === "REPLACE" ? draft.substituteIngredientId : null,
      quantity_per_basis: carriesQuantity ? Number(draft.quantity) : null,
      unit_id: carriesUnit ? proposalUnitId : null,
      effective_from: draft.effectiveFrom,
      effective_to: draft.effectiveTo || null,
      reason_code: editing ? "RULE_CORRECTION" : "OPERATOR_RULE",
      reason_note: draft.reason.trim(),
      source_evidence: { source_kind: "ATLAS_OPERATOR" },
    };
  }

  const materialFingerprint = JSON.stringify({
    draft,
    proposalUnitId,
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
    authorityReady &&
    !mutationLocked &&
    !!draft.action &&
    !!previewSchoolId &&
    !!previewDishId &&
    !!draft.effectiveFrom &&
    (!draft.effectiveTo || draft.effectiveTo > draft.effectiveFrom) &&
    !!draft.reason.trim() &&
    draft.scope !== "SYSTEM_DISH" &&
    (draft.scope !== "SCHOOL_DISH" || !!selectedRecipeSchoolTypeId) &&
    (!needsRecipeLine ||
      (targetContextStatus === "ready" && !!selectedTargetLine)) &&
    (!needsIngredientTarget || !!draft.targetIngredientId) &&
    (draft.action !== "REPLACE" || !!draft.substituteIngredientId) &&
    (!quantityRequired || Number(draft.quantity) > 0) &&
    (!requiresPurchaseUnit || (!!proposalUnitId && !missingPurchaseUnit));

  async function runPreview() {
    if (
      !api ||
      !authSubject ||
      authSubjectRef.current !== authSubject ||
      !canPreview ||
      busy
    )
      return;
    const requestGeneration = ++previewGeneration.current;
    const requestFingerprint = materialFingerprint;
    const proposedAdjustment = proposal();
    const requestedSchoolId = previewSchoolId;
    const requestedDishId = previewDishId;
    const requestedDate = draft.effectiveFrom;
    setBusy(true);
    setNotice("");
    const result = await api.preview(authSubject, correlationId, {
      as_of_date: requestedDate,
      school_id: requestedSchoolId,
      dish_id: requestedDishId,
      replaces_adjustment_id: editing?.adjustment_id ?? null,
      proposed_adjustment: proposedAdjustment,
    });
    if (authSubjectRef.current !== authSubject) return;
    if (requestGeneration !== previewGeneration.current) {
      setBusy(false);
      return;
    }
    const parsed = adjustmentPreviewFromResult(result);
    const matches =
      parsed?.as_of_date === requestedDate &&
      parsed.school_id === requestedSchoolId &&
      parsed.dish_id === requestedDishId &&
      parsed.before.as_of_date === requestedDate &&
      parsed.before.school_id === requestedSchoolId &&
      parsed.before.dish_id === requestedDishId &&
      parsed.after.as_of_date === requestedDate &&
      parsed.after.school_id === requestedSchoolId &&
      parsed.after.dish_id === requestedDishId &&
      JSON.stringify(parsed.proposed_adjustment) ===
        JSON.stringify(proposedAdjustment);
    setPreview(matches ? parsed : null);
    setPreviewFingerprint(matches ? requestFingerprint : "");
    if (matches) {
      setModalStep("REVIEW");
    }
    setNotice(
      matches
        ? "Đã cập nhật phần xem ảnh hưởng."
        : parsed
          ? "Kết quả xem ảnh hưởng không khớp bối cảnh đã gửi. Vui lòng xem lại."
          : adjustmentResultMessage(result),
    );
    setBusy(false);
  }

  async function finishMutation(
    result: AtlasRpcResult,
    pending: PendingMutation,
    message: string,
  ) {
    // An exact readback may have reconciled this command while its response was in flight.
    if (pendingMutation.current !== pending) return;
    pending.outcome =
      result.kind === "success"
        ? "committed"
        : hasUnknownWriteOutcome(result)
          ? "unknown"
          : "denied";
    // Retain the old account's result for its own recovery without applying it to another account.
    if (authSubjectRef.current !== pending.authSubject) return;
    setNotice(
      result.kind === "success" ? message : adjustmentResultMessage(result),
    );
    if (pending.outcome === "denied") {
      pendingMutation.current = null;
      setMutationLocked(false);
      setBusy(false);
    } else if (result.kind === "success") {
      await refresh(pending.authSubject);
      if (authSubjectRef.current !== pending.authSubject) return;
      if (pendingMutation.current === pending) {
        setNotice(
          "Đã nhận kết quả nhưng chưa đọc lại được đúng phiên bản. Không gửi lại thao tác.",
        );
      }
    }
    setBusy(false);
  }

  async function saveAdjustment() {
    if (
      !api ||
      !authSubject ||
      authSubjectRef.current !== authSubject ||
      !authorityReady ||
      busy ||
      mutationLocked ||
      !preview?.can_save ||
      previewFingerprint !== materialFingerprint
    )
      return;
    setBusy(true);
    const proposedAdjustment = proposal();
    const payload = {
      ...proposedAdjustment,
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
    const pending: PendingMutation = {
      authSubject,
      outcome: "in_flight",
      adjustmentId: String(proposedAdjustment.adjustment_id),
      revisionId: String(proposedAdjustment.revision_id),
      predecessorRevisionId:
        typeof payload.predecessor_revision_id === "string"
          ? payload.predecessor_revision_id
          : null,
    };
    pendingMutation.current = pending;
    setMutationLocked(true);
    const result = editing
      ? await api.supersede(request)
      : await api.create(request);
    await finishMutation(result, pending, "Đã lưu điều chỉnh.");
  }

  function openCancellation(row: RecipeAdjustmentOperatorRecord) {
    if (
      authSubjectRef.current !== authSubject ||
      !authorityReady ||
      busy ||
      mutationLocked
    )
      return;
    const from = row.command_revision.effective_from;
    const localDate = vietnamLocalDate();
    setDetail(null);
    setCancelTarget(row);
    setCancelDate(localDate < from ? from : localDate);
    setCancelReason("");
  }

  async function cancelAdjustment() {
    if (
      !api ||
      !authSubject ||
      authSubjectRef.current !== authSubject ||
      !authorityReady ||
      busy ||
      !cancelTarget ||
      !cancelDate ||
      !cancelReason.trim() ||
      mutationLocked
    )
      return;
    setBusy(true);
    const revisionId = crypto.randomUUID();
    const predecessorRevisionId = cancelTarget.current_revision_id;
    const request = recipeAdjustmentCommandRequest(
      authSubject,
      correlationId,
      cancelTarget.version,
      "RULE_CANCELLATION",
      cancelReason.trim(),
      {
        adjustment_id: cancelTarget.adjustment_id,
        predecessor_revision_id: predecessorRevisionId,
        revision_id: revisionId,
        effective_from: cancelDate,
      },
    );
    const pending: PendingMutation = {
      authSubject,
      outcome: "in_flight",
      adjustmentId: cancelTarget.adjustment_id,
      revisionId,
      predecessorRevisionId,
    };
    pendingMutation.current = pending;
    setMutationLocked(true);
    const result = await api.cancel(request);
    await finishMutation(
      result,
      pending,
      "Đã ghi nhận hủy điều chỉnh theo ngày đã chọn.",
    );
  }

  async function resolveEffectiveComposition() {
    if (
      !api ||
      !authSubject ||
      authSubjectRef.current !== authSubject ||
      !authorityReady ||
      busy ||
      !effectiveSchoolId ||
      !effectiveDishId
    )
      return;
    const requestGeneration = ++effectiveGeneration.current;
    const requestIntent = effectiveIntent;
    const requestedDate = effectiveDate;
    const requestedSchoolId = effectiveSchoolId;
    const requestedDishId = effectiveDishId;
    const requestedReviewScenario = mode === "review" ? reviewScenario : null;
    setBusy(true);
    setNotice("");
    const result = await api.resolve(authSubject, correlationId, {
      as_of_date: requestedDate,
      school_id: requestedSchoolId,
      dish_id: requestedDishId,
      review_scenario: requestedReviewScenario,
    });
    if (authSubjectRef.current !== authSubject) return;
    if (
      requestGeneration !== effectiveGeneration.current ||
      requestIntent !== effectiveIntentRef.current
    ) {
      setBusy(false);
      return;
    }
    const parsed = effectiveCompositionFromResult(result);
    const matches =
      parsed?.as_of_date === requestedDate &&
      parsed.school_id === requestedSchoolId &&
      parsed.dish_id === requestedDishId;
    setResolution(matches ? parsed : null);
    setNotice(
      matches
        ? "Đã cập nhật công thức hiệu lực."
        : parsed
          ? "Kết quả công thức không khớp bối cảnh đã chọn. Vui lòng xem lại."
          : adjustmentResultMessage(result),
    );
    setBusy(false);
  }

  function invalidateEffectiveComposition() {
    effectiveGeneration.current += 1;
    setResolution(null);
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
    if (!line) return "—";
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
        <span>Không có dữ liệu từ OPS v1</span>
        <small>Không có dữ liệu từ OPS v1</small>
      </>
    ) : (
      <>
        <span>{formatIssuedAt(revision.issued_at)}</span>
        <small>{revision.issued_by_actor_name ?? "—"}</small>
      </>
    );
  }

  const draftTargetName = needsIngredientTarget
    ? referenceName(
        load.data.ingredients,
        draft.targetIngredientId,
        "ingredient_id",
        "ingredient_name",
      )
    : (selectedTargetLine?.ingredient_name ?? "—");
  const draftSubstituteName = referenceName(
    load.data.ingredients,
    draft.substituteIngredientId,
    "ingredient_id",
    "ingredient_name",
  );
  const draftChangeText = (() => {
    switch (draft.action) {
      case "REPLACE":
        return `${draftTargetName} → ${draftSubstituteName}${
          draft.replaceQuantity
            ? ` · ${formatQuantity(Number(draft.quantity))} ${draftUnitName}`
            : ""
        }`;
      case "ADJUST_QUANTITY":
        return `${draftTargetName} → ${formatQuantity(Number(draft.quantity))} ${draftUnitName}`;
      case "ADD":
        return `${draftTargetName} · ${formatQuantity(Number(draft.quantity))} ${draftUnitName}`;
      case "REMOVE":
        return draftTargetName;
      default:
        return "—";
    }
  })();
  const draftSchoolName = referenceName(
    load.data.schools,
    draft.schoolId,
    "school_id",
    "school_name",
  );
  const draftDishName = referenceName(
    load.data.dishes,
    draft.dishId,
    "dish_id",
    "dish_name",
  );
  const draftRecipeText = `${draftDishName} · ${selectedRecipeSchoolTypeName}`;
  const draftAuthorityText =
    draftAuthority === "ALL_SCHOOLS"
      ? authorityLabel[draftAuthority]
      : draftSchoolName;
  const previewContextText = [
    referenceName(
      load.data.schools,
      previewSchoolId,
      "school_id",
      "school_name",
    ),
    referenceName(load.data.dishes, previewDishId, "dish_id", "dish_name"),
  ].join(" · ");
  const alignedPreviewRows = preview ? previewRows(preview) : [];

  function mutationRecoveryNotice() {
    const differentAccount =
      pendingMutation.current?.authSubject !== authSubject;
    return (
      <div className="operator-notice warning" role="alert">
        {differentAccount
          ? "Thao tác đang chờ đối soát thuộc phiên đăng nhập trước. Phiên hiện tại không thể dùng dữ liệu đọc lại để gỡ chặn."
          : "Chưa xác định điều chỉnh đã được ghi nhận hay chưa. Không gửi lại thao tác. Hãy tải lại dữ liệu trước khi tiếp tục."}
        <Button
          ml="sm"
          variant="outline"
          disabled={busy || differentAccount}
          onClick={() => void refresh()}
        >
          Tải lại dữ liệu
        </Button>
      </div>
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
      {mutationLocked &&
        !createOpened &&
        !cancelTarget &&
        mutationRecoveryNotice()}

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
                disabled={!authorityReady || busy || mutationLocked}
                onClick={openCreate}
              >
                Tạo điều chỉnh
              </Button>
            </div>
          </div>

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
                  <Text size="xs" c="dimmed">
                    {row.is_effective_now
                      ? "Có trong BOM hiệu lực"
                      : "Không có trong BOM hiệu lực"}
                  </Text>
                </td>
                <td>{scopeSummary(row)}</td>
                <td>{actionLabel[row.action_kind]}</td>
                <td>{changeSummary(row)}</td>
                <td>
                  {formatEffectivePeriod(
                    row.display_revision.effective_from,
                    row.display_revision.effective_to,
                  )}
                </td>
                <td>
                  {row.display_revision.issuance_kind === "LEGACY_UNATTRIBUTED"
                    ? "Không có dữ liệu từ OPS v1"
                    : formatIssuedAt(row.display_revision.issued_at)}
                </td>
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
              Xem tại ngày
              <input
                type="date"
                value={effectiveDate}
                onChange={(event) => {
                  setEffectiveDate(event.target.value);
                  invalidateEffectiveComposition();
                }}
              />
            </label>
            <label>
              Trường
              <select
                value={effectiveSchoolId}
                onChange={(event) => {
                  setEffectiveSchoolId(event.target.value);
                  invalidateEffectiveComposition();
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
                  invalidateEffectiveComposition();
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
                    invalidateEffectiveComposition();
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
              disabled={
                !authorityReady ||
                busy ||
                !effectiveSchoolId ||
                !effectiveDishId
              }
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
        title={
          modalStep === "REVIEW"
            ? "Thay đổi dự kiến"
            : editing
              ? "Điều chỉnh lại"
              : "Tạo điều chỉnh"
        }
        size="1000px"
        centered
        xOffset="20px"
        yOffset="20px"
        styles={{
          content: { maxHeight: "86dvh", overflowX: "hidden" },
          body: {
            maxHeight: "calc(86dvh - 64px)",
            overflowY: "auto",
            overflowX: "hidden",
          },
        }}
        closeOnClickOutside={!busy}
      >
        <Stack gap="md">
          {mutationLocked && mutationRecoveryNotice()}
          {modalStep === "EDIT" ? (
            <>
              {editing ? (
                <Paper
                  withBorder
                  radius="md"
                  p="md"
                  aria-label="Bối cảnh điều chỉnh cố định"
                >
                  <Text fw={700} mb="sm">
                    Bối cảnh điều chỉnh
                  </Text>
                  <SimpleGrid cols={{ base: 1, sm: 4 }}>
                    <Box>
                      <Text size="xs" c="dimmed">
                        Đối tượng điều chỉnh
                      </Text>
                      <Text fw={600}>
                        {businessObjectLabel[draftBusinessObject]}
                      </Text>
                    </Box>
                    {draftBusinessObject === "RECIPE" && (
                      <Box>
                        <Text size="xs" c="dimmed">
                          Công thức
                        </Text>
                        <Text fw={600}>{draftRecipeText}</Text>
                      </Box>
                    )}
                    <Box>
                      <Text size="xs" c="dimmed">
                        Phạm vi áp dụng
                      </Text>
                      <Text fw={600}>{draftAuthorityText}</Text>
                    </Box>
                    <Box>
                      <Text size="xs" c="dimmed">
                        Loại thay đổi
                      </Text>
                      <Text fw={600}>
                        {draft.action ? actionLabel[draft.action] : "—"}
                      </Text>
                    </Box>
                  </SimpleGrid>
                </Paper>
              ) : (
                <>
                  <Stack
                    component="section"
                    gap="xs"
                    aria-labelledby="adjustment-object-heading"
                  >
                    <Text
                      component="h3"
                      id="adjustment-object-heading"
                      fw={700}
                      size="sm"
                      m={0}
                    >
                      Đối tượng điều chỉnh
                    </Text>
                    <Radio.Group
                      value={draftBusinessObject}
                      label="Bạn muốn điều chỉnh gì?"
                      onChange={(value) =>
                        changeBusinessObject(value as AdjustmentBusinessObject)
                      }
                    >
                      <SimpleGrid cols={{ base: 1, sm: 2 }} mt="xs">
                        {(
                          ["RECIPE", "INGREDIENT"] as AdjustmentBusinessObject[]
                        ).map((businessObject) => (
                          <Radio.Card
                            key={businessObject}
                            value={businessObject}
                            aria-label={businessObjectLabel[businessObject]}
                            p="sm"
                            radius="md"
                            withBorder
                          >
                            <Group wrap="nowrap">
                              <Radio.Indicator />
                              <Text fw={500}>
                                {businessObjectLabel[businessObject]}
                              </Text>
                            </Group>
                          </Radio.Card>
                        ))}
                      </SimpleGrid>
                    </Radio.Group>
                  </Stack>

                  <Stack
                    component="section"
                    gap="xs"
                    aria-labelledby="adjustment-authority-heading"
                  >
                    <Text
                      component="h3"
                      id="adjustment-authority-heading"
                      fw={700}
                      size="sm"
                      m={0}
                    >
                      Phạm vi áp dụng
                    </Text>
                    <Radio.Group
                      value={draftAuthority}
                      label="Áp dụng tại đâu?"
                      onChange={(value) =>
                        changeAuthority(value as AdjustmentAuthority)
                      }
                    >
                      <SimpleGrid cols={{ base: 1, sm: 2 }} mt="xs">
                        {(
                          ["ALL_SCHOOLS", "ONE_SCHOOL"] as AdjustmentAuthority[]
                        ).map((authority) => (
                          <Radio.Card
                            key={authority}
                            value={authority}
                            aria-label={authorityLabel[authority]}
                            p="sm"
                            radius="md"
                            withBorder
                          >
                            <Group wrap="nowrap">
                              <Radio.Indicator />
                              <Text fw={500}>{authorityLabel[authority]}</Text>
                            </Group>
                          </Radio.Card>
                        ))}
                      </SimpleGrid>
                    </Radio.Group>
                  </Stack>
                </>
              )}

              <Stack
                component="section"
                gap="md"
                aria-labelledby="adjustment-target-heading"
              >
                <Text
                  component="h3"
                  id="adjustment-target-heading"
                  fw={700}
                  size="sm"
                  m={0}
                >
                  Mục tiêu điều chỉnh
                </Text>

                {(draft.scope === "SCHOOL" ||
                  draft.scope === "SCHOOL_DISH") && (
                  <NativeSelect
                    label="Trường"
                    value={draft.schoolId}
                    disabled={!!editing}
                    data={[
                      { value: "", label: "Chọn trường" },
                      ...load.data.schools.map((school) => ({
                        value: school.school_id ?? "",
                        label: school.school_name ?? "",
                      })),
                    ]}
                    onChange={(event) => changeSchool(event.target.value)}
                  />
                )}

                {(draft.scope === "SYSTEM_DISH" ||
                  draft.scope === "SCHOOL_DISH") && (
                  <>
                    {draft.scope === "SCHOOL_DISH" && (
                      <Paper
                        withBorder
                        radius="md"
                        p="sm"
                        aria-label="Loại công thức xác định từ trường"
                      >
                        <Text size="xs" c="dimmed">
                          Loại công thức
                        </Text>
                        <Text fw={600}>{selectedRecipeSchoolTypeName}</Text>
                      </Paper>
                    )}
                    <Select
                      label="Món"
                      searchable
                      allowDeselect={false}
                      placeholder="Chọn món"
                      nothingFoundMessage="Không tìm thấy món"
                      value={draft.dishId || null}
                      disabled={!!editing}
                      data={load.data.dishes.map((dish) => ({
                        value: dish.dish_id ?? "",
                        label: dish.dish_name ?? "",
                      }))}
                      onChange={(value) => changeDish(value ?? "")}
                    />
                  </>
                )}

                {draft.scope === "SYSTEM_DISH" && (
                  <>
                    <NativeSelect
                      label="Loại công thức"
                      required
                      value={draft.schoolTypeId}
                      disabled={!!editing}
                      data={[
                        { value: "", label: "Chọn loại công thức" },
                        ...load.data.school_types.map((schoolType) => ({
                          value: schoolType.school_type_id ?? "",
                          label: schoolType.school_type_name ?? "",
                        })),
                      ]}
                      onChange={(event) =>
                        changeRecipeSchoolType(event.target.value)
                      }
                    />
                    {!draft.schoolTypeId && (
                      <Text size="sm" c="red" role="alert">
                        Chưa có loại công thức phù hợp để tạo điều chỉnh.
                      </Text>
                    )}
                  </>
                )}

                {(draft.scope === "SYSTEM_INGREDIENT" ||
                  draft.scope === "SCHOOL") && (
                  <NativeSelect
                    label={
                      draft.action === "REMOVE"
                        ? "Nguyên liệu cần bỏ"
                        : draft.action === "REPLACE"
                          ? "Nguyên liệu hiện tại"
                          : "Nguyên liệu điều chỉnh"
                    }
                    value={draft.targetIngredientId}
                    disabled={!!editing}
                    data={[
                      { value: "", label: "Chọn nguyên liệu" },
                      ...load.data.ingredients.map((ingredient) => ({
                        value: ingredient.ingredient_id ?? "",
                        label: ingredient.ingredient_name ?? "",
                      })),
                    ]}
                    onChange={(event) =>
                      updateDraft({ targetIngredientId: event.target.value })
                    }
                  />
                )}
              </Stack>

              {!editing && (
                <Stack
                  component="section"
                  gap="xs"
                  aria-labelledby="adjustment-action-heading"
                >
                  <Text
                    component="h3"
                    id="adjustment-action-heading"
                    fw={700}
                    size="sm"
                    m={0}
                  >
                    Loại thay đổi
                  </Text>
                  <Radio.Group
                    value={draft.action}
                    label="Bạn muốn thay đổi như thế nào?"
                    onChange={(value) =>
                      changeAction(value as RecipeAdjustmentAction)
                    }
                  >
                    <SimpleGrid cols={{ base: 1, sm: 2 }} mt="xs">
                      {allowedActions.map((action) => (
                        <Radio.Card
                          key={action}
                          value={action}
                          aria-label={actionLabel[action]}
                          p="sm"
                          radius="md"
                          withBorder
                        >
                          <Group wrap="nowrap">
                            <Radio.Indicator />
                            <Text fw={500}>{actionLabel[action]}</Text>
                          </Group>
                        </Radio.Card>
                      ))}
                    </SimpleGrid>
                  </Radio.Group>
                </Stack>
              )}

              {draft.action && (
                <Stack
                  component="section"
                  gap="md"
                  aria-labelledby="adjustment-content-heading"
                >
                  <Text
                    component="h3"
                    id="adjustment-content-heading"
                    fw={700}
                    size="sm"
                    m={0}
                  >
                    Nội dung điều chỉnh
                  </Text>

                  {draft.action === "ADD" && (
                    <NativeSelect
                      label="Nguyên liệu thêm"
                      value={draft.targetIngredientId}
                      disabled={!!editing}
                      data={[
                        { value: "", label: "Chọn nguyên liệu" },
                        ...load.data.ingredients.map((ingredient) => ({
                          value: ingredient.ingredient_id ?? "",
                          label: ingredient.ingredient_name ?? "",
                        })),
                      ]}
                      onChange={(event) =>
                        updateDraft({ targetIngredientId: event.target.value })
                      }
                    />
                  )}

                  {needsRecipeLine && (
                    <>
                      <NativeSelect
                        label={
                          draft.action === "REMOVE"
                            ? "Nguyên liệu cần bỏ"
                            : "Nguyên liệu trong công thức"
                        }
                        value={selectedTargetLine?.target_id ?? ""}
                        disabled={!!editing || targetContextStatus !== "ready"}
                        data={[
                          { value: "", label: "Chọn nguyên liệu trong món" },
                          ...lineOptions.map((line) => ({
                            value: line.target_id,
                            label: `${line.ingredient_name} · ${formatQuantity(
                              line.quantity_per_basis,
                            )} ${line.unit_name}`,
                          })),
                        ]}
                        onChange={(event) => {
                          const line = lineOptions.find(
                            (candidate) =>
                              candidate.target_id === event.target.value,
                          );
                          updateDraft({
                            targetRecipeLineId:
                              line?.target_recipe_line_id ?? "",
                            targetAdjustmentLineId:
                              line?.adjustment_line_id ?? "",
                          });
                        }}
                      />
                      {targetContextStatus === "loading" && (
                        <Text size="sm" c="dimmed">
                          Đang tải mục tiêu hiệu lực…
                        </Text>
                      )}
                      {targetContextStatus === "error" && (
                        <Text size="sm" c="red" role="alert">
                          {targetContextMessage}
                        </Text>
                      )}
                    </>
                  )}

                  {draft.action === "REPLACE" && (
                    <>
                      <NativeSelect
                        label="Thay bằng"
                        value={draft.substituteIngredientId}
                        data={[
                          { value: "", label: "Chọn nguyên liệu mới" },
                          ...load.data.ingredients.map((ingredient) => ({
                            value: ingredient.ingredient_id ?? "",
                            label: ingredient.ingredient_name ?? "",
                          })),
                        ]}
                        onChange={(event) =>
                          updateDraft({
                            substituteIngredientId: event.target.value,
                          })
                        }
                      />
                      <Checkbox
                        label="Đổi cả định lượng"
                        checked={draft.replaceQuantity}
                        onChange={(event) =>
                          updateDraft({
                            replaceQuantity: event.target.checked,
                            quantity: event.target.checked
                              ? draft.quantity
                              : "",
                          })
                        }
                      />
                    </>
                  )}

                  {quantityRequired && (
                    <SimpleGrid cols={{ base: 1, sm: 2 }}>
                      <TextInput
                        label={
                          draft.action === "ADD"
                            ? "Định lượng"
                            : "Định lượng mới"
                        }
                        type="number"
                        min="0.000001"
                        step="0.000001"
                        value={draft.quantity}
                        onChange={(event) =>
                          updateDraft({ quantity: event.target.value })
                        }
                      />
                      <TextInput
                        label="Đơn vị"
                        value={draftUnitName}
                        readOnly
                        error={missingPurchaseUnitMessage}
                      />
                    </SimpleGrid>
                  )}

                  <SimpleGrid cols={{ base: 1, sm: 2 }}>
                    <TextInput
                      label="Hiệu lực từ"
                      type="date"
                      value={draft.effectiveFrom}
                      onChange={(event) =>
                        updateDraft({ effectiveFrom: event.target.value })
                      }
                    />
                    <TextInput
                      label="Hiệu lực đến"
                      description="Không bắt buộc"
                      type="date"
                      value={draft.effectiveTo}
                      onChange={(event) =>
                        updateDraft({ effectiveTo: event.target.value })
                      }
                    />
                  </SimpleGrid>

                  <Textarea
                    label="Lý do"
                    minRows={3}
                    value={draft.reason}
                    onChange={(event) =>
                      updateDraft({ reason: event.target.value })
                    }
                  />

                  <Divider label="Xem ảnh hưởng tại" labelPosition="left" />
                  <Text size="sm" c="dimmed">
                    Đây là bối cảnh dùng để xem trước; phạm vi áp dụng vẫn theo
                    lựa chọn ở trên.
                  </Text>

                  {draft.scope === "SYSTEM_INGREDIENT" && (
                    <SimpleGrid cols={{ base: 1, sm: 2 }}>
                      <NativeSelect
                        label="Trường đại diện"
                        value={draft.previewSchoolId}
                        data={[
                          { value: "", label: "Chọn trường" },
                          ...load.data.schools.map((school) => ({
                            value: school.school_id ?? "",
                            label: school.school_name ?? "",
                          })),
                        ]}
                        onChange={(event) =>
                          updateDraft({ previewSchoolId: event.target.value })
                        }
                      />
                      <Select
                        label="Món đại diện"
                        searchable
                        allowDeselect={false}
                        placeholder="Chọn món"
                        nothingFoundMessage="Không tìm thấy món"
                        value={draft.previewDishId || null}
                        data={load.data.dishes.map((dish) => ({
                          value: dish.dish_id ?? "",
                          label: dish.dish_name ?? "",
                        }))}
                        onChange={(value) =>
                          updateDraft({ previewDishId: value ?? "" })
                        }
                      />
                    </SimpleGrid>
                  )}

                  {draft.scope === "SYSTEM_DISH" && (
                    <Text size="sm" c="red" role="alert">
                      Atlas chưa hỗ trợ xem và lưu điều chỉnh cho toàn bộ loại
                      trường trong hợp đồng hiện tại.
                    </Text>
                  )}

                  {draft.scope === "SCHOOL" && (
                    <Select
                      label="Món dùng để xem"
                      searchable
                      allowDeselect={false}
                      placeholder="Chọn món"
                      nothingFoundMessage="Không tìm thấy món"
                      value={draft.previewDishId || null}
                      data={load.data.dishes.map((dish) => ({
                        value: dish.dish_id ?? "",
                        label: dish.dish_name ?? "",
                      }))}
                      onChange={(value) =>
                        updateDraft({ previewDishId: value ?? "" })
                      }
                    />
                  )}

                  {draft.scope === "SCHOOL_DISH" && (
                    <Text size="sm">
                      Trường và món đã được xác định trong phạm vi điều chỉnh.
                    </Text>
                  )}
                </Stack>
              )}

              <Group
                justify="space-between"
                style={{
                  position: "sticky",
                  bottom: 0,
                  zIndex: 1,
                  background: "var(--mantine-color-body)",
                  paddingTop: "var(--mantine-spacing-sm)",
                }}
              >
                <Button
                  type="button"
                  variant="subtle"
                  color="gray"
                  disabled={busy}
                  onClick={() => setCreateOpened(false)}
                >
                  Hủy
                </Button>
                <Button
                  type="button"
                  disabled={busy || !canPreview}
                  onClick={() => void runPreview()}
                >
                  {busy ? "Đang xem…" : "Xem ảnh hưởng"}
                </Button>
              </Group>
            </>
          ) : (
            <>
              <Paper
                withBorder
                radius="md"
                p="md"
                aria-label="Tóm tắt điều chỉnh"
              >
                <Stack gap="xs">
                  <Group justify="space-between" align="flex-start">
                    <Box>
                      <Text size="sm" c="dimmed">
                        Loại điều chỉnh
                      </Text>
                      <Text fw={600}>
                        {draft.action ? actionLabel[draft.action] : "—"}
                      </Text>
                      <Text>{draftChangeText}</Text>
                    </Box>
                    <Badge
                      color={
                        mutationLocked
                          ? "yellow"
                          : preview?.can_save
                            ? "green"
                            : "red"
                      }
                    >
                      {mutationLocked
                        ? "Đang xác minh"
                        : preview?.can_save
                          ? "Có thể lưu"
                          : "Cần kiểm tra"}
                    </Badge>
                  </Group>
                  <Divider />
                  <SimpleGrid cols={{ base: 1, sm: 2 }}>
                    <Box>
                      <Text size="sm" c="dimmed">
                        {draftBusinessObject === "RECIPE"
                          ? "Công thức"
                          : "Phạm vi áp dụng"}
                      </Text>
                      <Text>
                        {draftBusinessObject === "RECIPE"
                          ? draftRecipeText
                          : draftAuthorityText}
                      </Text>
                    </Box>
                    {draftBusinessObject === "RECIPE" && (
                      <Box>
                        <Text size="sm" c="dimmed">
                          Phạm vi
                        </Text>
                        <Text>{draftAuthorityText}</Text>
                      </Box>
                    )}
                    <Box>
                      <Text size="sm" c="dimmed">
                        Hiệu lực
                      </Text>
                      <Text>
                        {formatEffectivePeriod(
                          draft.effectiveFrom,
                          draft.effectiveTo,
                        )}
                      </Text>
                    </Box>
                    <Box>
                      <Text size="sm" c="dimmed">
                        Xem ảnh hưởng tại
                      </Text>
                      <Text>{previewContextText}</Text>
                      {draftBusinessObject === "INGREDIENT" && (
                        <Text size="xs" c="dimmed" mt={4}>
                          Đây là bối cảnh dùng để xem trước; phạm vi áp dụng vẫn
                          theo lựa chọn ở trên.
                        </Text>
                      )}
                    </Box>
                    <Box>
                      <Text size="sm" c="dimmed">
                        Lý do
                      </Text>
                      <Text>{draft.reason}</Text>
                    </Box>
                  </SimpleGrid>
                </Stack>
              </Paper>

              {preview?.blockers.map((blocker) => (
                <p className="operator-notice warning" key={blocker.code}>
                  {blocker.message}
                </p>
              ))}

              <section aria-label="Ảnh hưởng điều chỉnh">
                <Text fw={700} mb="sm">
                  Công thức trước và sau điều chỉnh
                </Text>
                <Table
                  aria-label="So sánh công thức trước và sau"
                  withTableBorder
                  withColumnBorders
                  verticalSpacing="sm"
                  horizontalSpacing="sm"
                  layout="fixed"
                  style={{ minWidth: 0 }}
                >
                  <Table.Thead>
                    <Table.Tr>
                      <Table.Th w="46%">Công thức trước</Table.Th>
                      <Table.Th w="8%" aria-label="Thay đổi" />
                      <Table.Th w="46%">Công thức sau</Table.Th>
                    </Table.Tr>
                  </Table.Thead>
                  <Table.Tbody>
                    {alignedPreviewRows.map(
                      ({ key, before, after, changed }) => (
                        <Table.Tr
                          key={key}
                          data-changed={changed || undefined}
                          style={{
                            background: changed
                              ? "var(--mantine-color-blue-light)"
                              : undefined,
                          }}
                        >
                          <Table.Td>
                            <Text
                              fw={changed ? 600 : 400}
                              c={changed ? undefined : "dimmed"}
                            >
                              {compositionText(before)}
                            </Text>
                          </Table.Td>
                          <Table.Td ta="center">
                            <Text
                              fw={700}
                              aria-label={changed ? "Có thay đổi" : undefined}
                            >
                              {changed ? "→" : ""}
                            </Text>
                          </Table.Td>
                          <Table.Td>
                            <Text
                              fw={changed ? 600 : 400}
                              c={changed ? undefined : "dimmed"}
                            >
                              {compositionText(after)}
                            </Text>
                          </Table.Td>
                        </Table.Tr>
                      ),
                    )}
                  </Table.Tbody>
                </Table>
              </section>

              <Group
                justify="space-between"
                style={{
                  position: "sticky",
                  bottom: 0,
                  zIndex: 1,
                  background: "var(--mantine-color-body)",
                  paddingTop: "var(--mantine-spacing-sm)",
                }}
              >
                <Button
                  type="button"
                  variant="outline"
                  disabled={busy}
                  onClick={() => setModalStep("EDIT")}
                >
                  Quay lại
                </Button>
                <Button
                  type="button"
                  disabled={
                    !authorityReady ||
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
            </>
          )}
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
                {formatEffectivePeriod(
                  detail.display_revision.effective_from,
                  detail.display_revision.effective_to,
                )}
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
                  <Text>
                    {revision.business_event_kind === "CANCELLED"
                      ? "Hủy điều chỉnh"
                      : changeSummary(detail, revision)}
                  </Text>
                  <Text size="sm">
                    Hiệu lực{" "}
                    {formatEffectivePeriod(
                      revision.effective_from,
                      revision.effective_to,
                    )}
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
                  disabled={!authorityReady || busy || mutationLocked}
                  onClick={() => openCorrection(detail)}
                >
                  Điều chỉnh lại
                </Button>
              )}
              {detail.can_cancel && (
                <Button
                  color="red"
                  variant="outline"
                  disabled={!authorityReady || busy || mutationLocked}
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
          {mutationLocked && mutationRecoveryNotice()}
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
                !authorityReady ||
                busy ||
                mutationLocked ||
                !cancelDate ||
                !cancelReason.trim()
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
