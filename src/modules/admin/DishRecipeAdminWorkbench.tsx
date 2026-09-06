import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { AtlasAuthState } from "../atlas/connection/authSession";
import type { AtlasRpcResult, JsonValue } from "../atlas/connection/atlasRpc";
import type { RecipeApi } from "../atlas/recipes/recipeApi";
import {
  dishRecipeCopyRequest,
  recipeCommandRequest,
  recipeWorkflowCommandRequest,
  type DishRecipeCopyCommandRequest,
  type RecipeWorkflowCommandRequest,
} from "../atlas/recipes/recipeApi";
import type {
  RecipeAdjustmentApi,
  RecipeEffectiveContext,
} from "../atlas/recipe-adjustments/recipeAdjustmentApi";
import { adjustmentSchoolsFromResult } from "../atlas/recipe-adjustments/recipeAdjustmentModel";
import {
  dishRecipeCopyFromResult,
  dishRecipeOperatorWorkbenchFromResult,
  emptyRecipeWorkbench,
  ingredientLabel,
  recipeResultMessage,
  recipeWorkbenchFromResult,
  schoolScopeLabel,
  unitLabel,
  type DishRecipeCopyResult,
  type DishRecipeOperatorWorkbench,
  type RecipeCompositionLine,
  type RecipeWorkbenchData,
} from "../atlas/recipes/recipeModel";
import {
  reviewRecipeWorkbook,
  type RecipeWorkbookReview,
} from "../atlas/recipes/recipeWorkbook";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import {
  RecipeAdjustmentWorkbench,
  vietnamLocalDate,
} from "./RecipeAdjustmentWorkbench";

type Tab = "recipes" | "catalog" | "adjustments" | "effective" | "import";
type LoadState = {
  status: "idle" | "loading" | "ready" | "error";
  data: RecipeWorkbenchData;
  message?: string;
};
type EffectiveLoadState = {
  status: "idle" | "loading" | "ready" | "error";
  data: DishRecipeOperatorWorkbench | null;
  message?: string;
};
type EffectiveSelection = {
  dishId: string;
  asOfDate: string;
  context: RecipeEffectiveContext;
};
type DishDraft = {
  name: string;
  category: string;
  dishTypeId: string;
  notes: string;
};
type CopyDraft = {
  sourceDishId: string;
  asOfDate: string;
  reasonNote: string;
};

type CopyRecovery = {
  kind: "unknown" | "committed_unreadable" | "retryable";
  authSubject: string;
  request: DishRecipeCopyCommandRequest;
  result: DishRecipeCopyResult | null;
};
type SaveRecovery = {
  kind: "unknown" | "committed_unreadable";
  authSubject: string;
  request: RecipeWorkflowCommandRequest;
  selection: EffectiveSelection;
};

const canonicalSchoolTypeCodes = [
  "v1-school-type-1",
  "v1-school-type-2",
] as const;

function evidenceValue(
  evidence: Record<string, JsonValue>,
  key: string,
): string | null {
  return typeof evidence[key] === "string" ? evidence[key] : null;
}

function compositionIdentity(
  lines: Array<{
    ingredient_id: string;
    quantity_per_basis: number;
    unit_id: string;
    operational_note?: string | null;
  }>,
) {
  return lines
    .map((line) => ({
      ingredient_id: line.ingredient_id,
      quantity_per_basis: line.quantity_per_basis,
      unit_id: line.unit_id,
      operational_note: line.operational_note ?? null,
    }))
    .sort((left, right) =>
      left.ingredient_id.localeCompare(right.ingredient_id),
    );
}

const emptyDishDraft = (): DishDraft => ({
  name: "",
  category: "",
  dishTypeId: "",
  notes: "",
});
const statusLabel: Record<string, string> = {
  DRAFT: "Nháp",
  ACTIVE: "Đang dùng",
  INACTIVE: "Ngừng dùng",
  VALIDATED: "Đã xác thực",
  RELEASED_FOR_PLANNING: "Sẵn sàng cho Lập nhu cầu",
  LOCKED: "Đã khóa",
  PRESENT: "Có hiệu lực",
  REMOVED: "Đã loại bỏ",
};
const statusTone = (status: string) => {
  if (status === "ACTIVE" || status === "RELEASED_FOR_PLANNING")
    return "ok" as const;
  if (status === "INACTIVE" || status === "LOCKED") return "warning" as const;
  return "neutral" as const;
};
const recipeBusinessStatusLabel = {
  NOT_SAVED: "Chưa tạo",
  SAVED: "Đã lưu",
  AVAILABLE: "Sẵn sàng cho Lập nhu cầu",
  LOCKED: "Đã dùng trong thực đơn đã duyệt",
  NEEDS_ATTENTION: "Cần xử lý",
} as const;

export function DishRecipeAdminWorkbench({
  authState = { status: "unauthenticated" },
  api,
  adjustmentApi,
  mode = "connected",
}: {
  authState?: AtlasAuthState;
  api?: RecipeApi;
  adjustmentApi?: RecipeAdjustmentApi;
  mode?: "connected" | "review";
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [load, setLoad] = useState<LoadState>({
    status: "idle",
    data: emptyRecipeWorkbench(),
  });
  const [loadAuthSubject, setLoadAuthSubject] = useState<string | null>(null);
  const [effectiveLoad, setEffectiveLoad] = useState<EffectiveLoadState>({
    status: "idle",
    data: null,
  });
  const [effectiveLoadAuthSubject, setEffectiveLoadAuthSubject] = useState<
    string | null
  >(null);
  const [effectiveSelection, setEffectiveSelection] =
    useState<EffectiveSelection | null>(null);
  const [schools, setSchools] = useState<
    { school_id: string; school_name: string; school_code: string }[]
  >([]);
  const [schoolsAuthSubject, setSchoolsAuthSubject] = useState<string | null>(
    null,
  );
  const [tab, setTab] = useState<Tab>("catalog");
  const [adjustmentMounted, setAdjustmentMounted] = useState(false);
  const [adjustmentView, setAdjustmentView] = useState<"rules" | "effective">(
    "rules",
  );
  const [query, setQuery] = useState("");
  const [dishId, setDishId] = useState<string | null>(null);
  const [schoolTypeId, setSchoolTypeId] = useState<string | null>(null);
  const [ingredientQuery, setIngredientQuery] = useState("");
  const [ingredientTargetLineId, setIngredientTargetLineId] = useState<
    string | null
  >(null);
  const [dishEditorId, setDishEditorId] = useState<string | null>(null);
  const [dishDraft, setDishDraft] = useState<DishDraft>(emptyDishDraft);
  const [composition, setComposition] = useState<RecipeCompositionLine[]>([]);
  const [basisPortions, setBasisPortions] = useState("100");
  const [copyDraft, setCopyDraft] = useState<CopyDraft>({
    sourceDishId: "",
    asOfDate: vietnamLocalDate(),
    reasonNote: "Sao chép hai công thức theo loại trường đã xem xét.",
  });
  const [copyOpen, setCopyOpen] = useState(false);
  const [copyQuery, setCopyQuery] = useState("");
  const [workbook, setWorkbook] = useState<RecipeWorkbookReview | null>(null);
  const [importReason, setImportReason] = useState("");
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [writeUncertain, setWriteUncertain] = useState(false);
  const [writeUncertainAuthSubject, setWriteUncertainAuthSubject] = useState<
    string | null
  >(null);
  const [saveRecovery, setSaveRecovery] = useState<SaveRecovery | null>(null);
  const [copyRecovery, setCopyRecovery] = useState<CopyRecovery | null>(null);
  const generation = useRef(0);
  const effectiveGeneration = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;
  const authSubjectRef = useRef(authSubject);
  authSubjectRef.current = authSubject;
  const currentSchools = schoolsAuthSubject === authSubject ? schools : [];

  const loadEffective = useCallback(
    async (
      selection: EffectiveSelection,
      expectedAuthSubject = authSubject,
    ) => {
      if (
        !api ||
        !expectedAuthSubject ||
        authSubjectRef.current !== expectedAuthSubject
      )
        return false;
      const current = ++effectiveGeneration.current;
      setEffectiveLoad((state) => ({
        ...state,
        status: "loading",
        message: undefined,
      }));
      const result = await api.getEffectiveWorkbench(
        expectedAuthSubject,
        correlationId,
        selection.asOfDate,
        selection.dishId,
        selection.context,
      );
      if (
        current !== effectiveGeneration.current ||
        authSubjectRef.current !== expectedAuthSubject
      )
        return false;
      const data = dishRecipeOperatorWorkbenchFromResult(result);
      const matchesIntent =
        data?.dish.dish_id === selection.dishId &&
        data.as_of_date === selection.asOfDate &&
        (selection.context.kind === "system"
          ? data.context_kind === "SYSTEM_SCHOOL_TYPE" &&
            data.school_id === null &&
            data.school_type_id === selection.context.schoolTypeId
          : data.context_kind === "SCHOOL" &&
            data.school_id === selection.context.schoolId);
      if (!data || !matchesIntent) {
        setEffectiveLoadAuthSubject(null);
        setEffectiveLoad((state) => ({
          status: "error",
          data: null,
          message:
            result.kind === "success"
              ? "Atlas trả về ngữ cảnh công thức không khớp. Không thể cho phép thao tác ghi."
              : recipeResultMessage(result),
        }));
        return false;
      }
      setEffectiveLoadAuthSubject(expectedAuthSubject);
      setEffectiveLoad({ status: "ready", data });
      setEffectiveSelection(selection);
      setDishId(data.dish.dish_id);
      setSchoolTypeId(data.school_type_id);
      setComposition(structuredClone(data.base_authoring.composition));
      setBasisPortions(String(data.base_authoring.basis_portions));
      setIngredientQuery("");
      setIngredientTargetLineId(null);
      return true;
    },
    [api, authSubject, correlationId],
  );

  const refresh = useCallback(
    async (
      selection?: EffectiveSelection,
      expectedAuthSubject = authSubject,
    ) => {
      if (
        !api ||
        !expectedAuthSubject ||
        authSubjectRef.current !== expectedAuthSubject
      )
        return false;
      const current = ++generation.current;
      setLoadAuthSubject(null);
      setEffectiveLoadAuthSubject(null);
      setLoad((state) => ({ ...state, status: "loading", message: undefined }));
      const result = await api.getWorkbench(expectedAuthSubject, correlationId);
      if (
        current !== generation.current ||
        authSubjectRef.current !== expectedAuthSubject
      )
        return false;
      const data = recipeWorkbenchFromResult(result);
      if (!data) {
        setLoad({
          status: "error",
          data: emptyRecipeWorkbench(),
          message: recipeResultMessage(result),
        });
        setEffectiveLoad({
          status: "error",
          data: null,
          message: recipeResultMessage(result),
        });
        setEffectiveSelection(null);
        return false;
      }
      setLoadAuthSubject(expectedAuthSubject);
      setLoad({ status: "ready", data });
      const canonicalTypes = data.school_types.filter(
        (item) =>
          item.school_type_status === "ACTIVE" &&
          canonicalSchoolTypeCodes.includes(
            item.school_type_code as (typeof canonicalSchoolTypeCodes)[number],
          ),
      );
      const defaultType =
        canonicalTypes.find(
          (item) => item.school_type_code === "v1-school-type-1",
        ) ?? canonicalTypes[0];
      const selectedDishId =
        selection?.dishId ??
        data.selected_recipe.dish_id ??
        data.dishes[0]?.dish_id;
      if (canonicalTypes.length !== 2 || !defaultType) {
        setEffectiveLoad({
          status: "error",
          data: null,
          message:
            "Atlas chưa trả về đủ hai phạm vi loại trường chuẩn để xem công thức.",
        });
        setEffectiveSelection(null);
        return false;
      }
      if (!selectedDishId) {
        if (data.dishes.length === 0 && !selection) {
          setEffectiveLoad({ status: "idle", data: null });
          setEffectiveLoadAuthSubject(null);
          setEffectiveSelection(null);
          setDishId(null);
          setSchoolTypeId(defaultType.school_type_id);
          setComposition([]);
          setBasisPortions("100");
          return true;
        }
        setEffectiveLoad({
          status: "error",
          data: null,
          message: "Atlas không tìm thấy món ăn đã chọn để đọc công thức.",
        });
        setEffectiveSelection(null);
        return false;
      }
      const nextSelection =
        selection ??
        ({
          dishId: selectedDishId,
          asOfDate: vietnamLocalDate(),
          context: {
            kind: "system",
            schoolTypeId:
              canonicalTypes.some(
                (item) =>
                  item.school_type_id === data.selected_recipe.school_type_id,
              ) && data.selected_recipe.school_type_id
                ? data.selected_recipe.school_type_id
                : defaultType.school_type_id,
          },
        } satisfies EffectiveSelection);
      return loadEffective(nextSelection, expectedAuthSubject);
    },
    [api, authSubject, correlationId, loadEffective],
  );

  useEffect(() => {
    let cancelled = false;
    setSchools([]);
    setSchoolsAuthSubject(null);
    generation.current += 1;
    effectiveGeneration.current += 1;
    setLoadAuthSubject(null);
    setEffectiveLoadAuthSubject(null);
    setNotice(null);
    if (authSubject) {
      void refresh();
      if (adjustmentApi) {
        void adjustmentApi
          .getWorkbench(authSubject, correlationId)
          .then((result) => {
            if (cancelled || authSubjectRef.current !== authSubject) return;
            const data = adjustmentSchoolsFromResult(result);
            if (data) {
              setSchoolsAuthSubject(authSubject);
              setSchools(
                data.filter(
                  (
                    item,
                  ): item is {
                    school_id: string;
                    school_name: string;
                    school_code: string;
                  } =>
                    typeof item.school_id === "string" &&
                    typeof item.school_name === "string" &&
                    typeof item.school_code === "string" &&
                    item.school_status === "ACTIVE",
                ),
              );
            }
          });
      }
    } else {
      setLoad({ status: "idle", data: emptyRecipeWorkbench() });
      setEffectiveLoad({ status: "idle", data: null });
      setEffectiveSelection(null);
    }
    return () => {
      cancelled = true;
    };
  }, [adjustmentApi, authSubject, correlationId, refresh]);

  const catalogAuthorityReady =
    Boolean(authSubject) &&
    load.status === "ready" &&
    loadAuthSubject === authSubject;
  const effectiveAuthorityReady =
    catalogAuthorityReady &&
    effectiveLoad.status === "ready" &&
    effectiveLoadAuthSubject === authSubject;
  const catalogData = catalogAuthorityReady
    ? load.data
    : emptyRecipeWorkbench();
  const effectiveBelongsToCurrentSubject =
    Boolean(authSubject) && effectiveLoadAuthSubject === authSubject;
  const effectiveData = effectiveBelongsToCurrentSubject
    ? effectiveLoad.data
    : null;
  const currentEffectiveSelection = effectiveBelongsToCurrentSubject
    ? effectiveSelection
    : null;
  const dish = catalogData.dishes.find((item) => item.dish_id === dishId);
  const canonicalSchoolTypes = useMemo(
    () =>
      catalogData.school_types
        .filter(
          (item) =>
            item.school_type_status === "ACTIVE" &&
            canonicalSchoolTypeCodes.includes(
              item.school_type_code as (typeof canonicalSchoolTypeCodes)[number],
            ),
        )
        .sort((left, right) =>
          left.school_type_code.localeCompare(right.school_type_code),
        ),
    [catalogData.school_types],
  );
  const authoring =
    effectiveData?.base_authoring ?? emptyRecipeWorkbench().selected_recipe;
  const versions = useMemo(
    () =>
      catalogData.recipe_versions
        .filter((version) => version.recipe_id === authoring.recipe_id)
        .sort((left, right) => right.version_number - left.version_number),
    [authoring.recipe_id, catalogData.recipe_versions],
  );
  const command = async (
    action: (
      request: ReturnType<typeof recipeCommandRequest>,
    ) => Promise<Awaited<ReturnType<RecipeApi["getWorkbench"]>>>,
    expectedVersion: number,
    reasonCode: string,
    payload: Record<string, JsonValue>,
    reasonNote?: string,
  ) => {
    if (!authSubject || !catalogAuthorityReady) return false;
    const submittingAuthSubject = authSubject;
    setBusy(true);
    const result = await action(
      recipeCommandRequest(
        submittingAuthSubject,
        correlationId,
        expectedVersion,
        reasonCode,
        payload,
        reasonNote,
      ),
    );
    setBusy(false);
    if (authSubjectRef.current !== submittingAuthSubject) {
      if (result.kind === "success" || result.kind === "transport_error") {
        setWriteUncertain(true);
        setWriteUncertainAuthSubject(submittingAuthSubject);
        setNotice(null);
      }
      return null;
    }
    setNotice(recipeResultMessage(result));
    if (result.kind === "success") {
      return result;
    }
    if (result.kind === "transport_error") {
      setWriteUncertain(true);
      setWriteUncertainAuthSubject(submittingAuthSubject);
    }
    return null;
  };

  const selectRecipeContext = async (selection: EffectiveSelection) => {
    if (
      tab === "recipes" &&
      isDirty &&
      !window.confirm(
        "Bạn có thay đổi chưa lưu. Bỏ các thay đổi này và chuyển sang nội dung khác?",
      )
    )
      return;
    setNotice(null);
    await loadEffective(selection);
  };

  const reconcileSave = async (
    request: RecipeWorkflowCommandRequest,
    selection: EffectiveSelection,
    submittingAuthSubject: string,
  ) => {
    if (!api || authSubjectRef.current !== submittingAuthSubject) return false;
    const [catalogResult, effectiveResult] = await Promise.all([
      api.getWorkbench(submittingAuthSubject, correlationId),
      api.getEffectiveWorkbench(
        submittingAuthSubject,
        correlationId,
        selection.asOfDate,
        selection.dishId,
        selection.context,
      ),
    ]);
    if (authSubjectRef.current !== submittingAuthSubject) return false;
    const catalog = recipeWorkbenchFromResult(catalogResult);
    const effective = dishRecipeOperatorWorkbenchFromResult(effectiveResult);
    const requestedLines = Array.isArray(request.payload.lines)
      ? (request.payload.lines as unknown as RecipeCompositionLine[])
      : [];
    const matches =
      catalog &&
      effective?.dish.dish_id === selection.dishId &&
      effective.as_of_date === selection.asOfDate &&
      effective.context_kind === "SYSTEM_SCHOOL_TYPE" &&
      selection.context.kind === "system" &&
      effective.school_id === null &&
      effective.school_type_id === selection.context.schoolTypeId &&
      effective.base_authoring.dish_id === request.payload.dish_id &&
      effective.base_authoring.school_type_id ===
        request.payload.school_type_id &&
      effective.base_authoring.business_status === "AVAILABLE" &&
      effective.base_authoring.locked_for_normal_editing === false &&
      effective.base_authoring.basis_portions ===
        request.payload.basis_portions &&
      JSON.stringify(
        compositionIdentity(
          effective.base_authoring.composition.filter(
            (line) => line.line_disposition === "PRESENT",
          ),
        ),
      ) === JSON.stringify(compositionIdentity(requestedLines));
    if (!matches) return false;
    generation.current += 1;
    effectiveGeneration.current += 1;
    setLoadAuthSubject(submittingAuthSubject);
    setEffectiveLoadAuthSubject(submittingAuthSubject);
    setLoad({ status: "ready", data: catalog });
    setEffectiveLoad({ status: "ready", data: effective });
    setEffectiveSelection(selection);
    setDishId(effective.dish.dish_id);
    setSchoolTypeId(effective.school_type_id);
    setComposition(structuredClone(effective.base_authoring.composition));
    setBasisPortions(String(effective.base_authoring.basis_portions));
    setWriteUncertain(false);
    setWriteUncertainAuthSubject(null);
    setSaveRecovery(null);
    setNotice("Atlas đã đối soát công thức đã Lưu theo đúng nội dung yêu cầu.");
    return true;
  };

  const workflowCommand = async (
    expectedVersion: number,
    payload: Record<string, JsonValue>,
  ) => {
    if (
      !api ||
      !authSubject ||
      !effectiveAuthorityReady ||
      !currentEffectiveSelection ||
      currentEffectiveSelection.context.kind !== "system"
    )
      return false;
    const selection = currentEffectiveSelection;
    const submittingAuthSubject = authSubject;
    const request = recipeWorkflowCommandRequest(
      submittingAuthSubject,
      correlationId,
      expectedVersion,
      "save",
      payload,
    );
    setBusy(true);
    const result = await api.saveRecipe(request);
    if (authSubjectRef.current !== submittingAuthSubject) {
      setBusy(false);
      if (result.kind === "success" || result.kind === "transport_error") {
        setWriteUncertain(true);
        setWriteUncertainAuthSubject(submittingAuthSubject);
        setSaveRecovery({
          kind: result.kind === "success" ? "committed_unreadable" : "unknown",
          authSubject: submittingAuthSubject,
          request,
          selection,
        });
        setNotice(null);
      }
      return false;
    }
    setNotice(recipeResultMessage(result));
    if (result.kind === "transport_error") {
      setBusy(false);
      setWriteUncertain(true);
      setWriteUncertainAuthSubject(submittingAuthSubject);
      setSaveRecovery({
        kind: "unknown",
        authSubject: submittingAuthSubject,
        request,
        selection,
      });
      return false;
    }
    if (result.kind !== "success") {
      setBusy(false);
      return false;
    }
    const reconciled = await reconcileSave(
      request,
      selection,
      submittingAuthSubject,
    );
    setBusy(false);
    if (!reconciled) {
      setWriteUncertain(true);
      setWriteUncertainAuthSubject(submittingAuthSubject);
      setSaveRecovery({
        kind: "committed_unreadable",
        authSubject: submittingAuthSubject,
        request,
        selection,
      });
      setNotice(
        "Atlas đã ghi nhận Lưu nhưng chưa đọc lại được đúng ngữ cảnh. Hãy đối soát trước khi tiếp tục.",
      );
      return false;
    }
    return true;
  };

  const baseRecipesForDish = (targetDishId: string) =>
    catalogData.recipes
      .filter(
        (recipe) =>
          recipe.dish_id === targetDishId && recipe.recipe_status === "ACTIVE",
      )
      .map((recipe) => ({
        recipe,
        version: catalogData.recipe_versions
          .filter(
            (version) =>
              version.recipe_id === recipe.recipe_id &&
              version.recipe_version_status === "RELEASED_FOR_PLANNING",
          )
          .sort((left, right) => right.version_number - left.version_number)[0],
      }))
      .filter(
        (
          item,
        ): item is typeof item & {
          version: NonNullable<typeof item.version>;
        } => Boolean(item.version),
      );

  const shownDishes = catalogData.dishes.filter((item) => {
    const needle = query.trim().toLocaleLowerCase("vi");
    const baseIngredientNames = baseRecipesForDish(item.dish_id)
      .flatMap(({ version }) => version.composition)
      .filter((line) => line.line_disposition === "PRESENT")
      .map(
        (line) =>
          catalogData.ingredients.find(
            (ingredient) => ingredient.ingredient_id === line.ingredient_id,
          )?.ingredient_name ?? "",
      );
    return (
      !needle ||
      [
        item.dish_code,
        item.dish_name,
        item.dish_category,
        item.dish_type_name,
        ...baseIngredientNames,
      ].some((value) => (value ?? "").toLocaleLowerCase("vi").includes(needle))
    );
  });

  const shownIngredients = catalogData.ingredients
    .filter((item) => item.ingredient_status === "ACTIVE")
    .filter((item) => {
      const needle = ingredientQuery.trim().toLocaleLowerCase("vi");
      return (
        needle.length > 0 &&
        [item.ingredient_name, item.ingredient_code].some((value) =>
          value.toLocaleLowerCase("vi").includes(needle),
        ) &&
        !composition.some(
          (line) =>
            line.line_disposition === "PRESENT" &&
            line.recipe_line_id !== ingredientTargetLineId &&
            line.ingredient_id === item.ingredient_id,
        )
      );
    })
    .slice(0, 8);

  const presentComposition = composition.filter(
    (line) => line.line_disposition === "PRESENT",
  );
  const basis = Number(basisPortions);
  const compositionValid =
    Number.isInteger(basis) &&
    basis > 0 &&
    presentComposition.length > 0 &&
    presentComposition.every(
      (line) =>
        Boolean(line.ingredient_id) &&
        Boolean(line.unit_id) &&
        Number.isFinite(line.quantity_per_basis) &&
        line.quantity_per_basis > 0,
    ) &&
    new Set(presentComposition.map((line) => line.ingredient_id)).size ===
      presentComposition.length;
  const isDirty =
    basisPortions !== String(authoring.basis_portions) ||
    JSON.stringify(presentComposition) !==
      JSON.stringify(
        authoring.composition.filter(
          (line) => line.line_disposition === "PRESENT",
        ),
      );
  const authoringReadyToSubmit =
    isDirty || authoring.business_status === "SAVED";
  const visibleRecipeStatus =
    writeUncertain || saveRecovery
      ? "Cần xử lý"
      : isDirty
        ? "Có thay đổi chưa lưu"
        : recipeBusinessStatusLabel[authoring.business_status];
  const creationLocked = authoring.locked_for_normal_editing ?? false;
  const authoringReadOnly =
    creationLocked ||
    effectiveData?.is_editable === false ||
    authoring.allowed_actions.save_recipe === false ||
    currentEffectiveSelection?.context.kind === "school";
  const mutationBlocked =
    !catalogAuthorityReady ||
    effectiveLoad.status === "error" ||
    writeUncertain ||
    saveRecovery !== null ||
    copyRecovery !== null;
  const effectiveMutationBlocked = mutationBlocked || !effectiveAuthorityReady;
  const systemSelectionForDish = (
    targetDishId: string,
    targetSchoolTypeId = schoolTypeId ??
      canonicalSchoolTypes[0]?.school_type_id ??
      "",
  ): EffectiveSelection => ({
    dishId: targetDishId,
    asOfDate: currentEffectiveSelection?.asOfDate ?? vietnamLocalDate(),
    context: { kind: "system", schoolTypeId: targetSchoolTypeId },
  });
  const effectiveContextValue = currentEffectiveSelection
    ? currentEffectiveSelection.context.kind === "system"
      ? `system:${currentEffectiveSelection.context.schoolTypeId}`
      : `school:${currentEffectiveSelection.context.schoolId}`
    : "";
  const changeEffectiveContext = (value: string) => {
    if (!dish || !currentEffectiveSelection) return;
    const [kind, identity] = value.split(":", 2);
    const context =
      kind === "system" &&
      canonicalSchoolTypes.some((item) => item.school_type_id === identity)
        ? ({ kind: "system", schoolTypeId: identity } as const)
        : kind === "school" &&
            currentSchools.some((item) => item.school_id === identity)
          ? ({ kind: "school", schoolId: identity } as const)
          : null;
    if (!context) return;
    void selectRecipeContext({
      dishId: dish.dish_id,
      asOfDate: currentEffectiveSelection.asOfDate,
      context,
    });
  };
  const copySourceOptions = catalogData.dishes.filter((sourceDish) => {
    if (sourceDish.dish_id === dish?.dish_id) return false;
    const releasedScopeCodes = new Set(
      baseRecipesForDish(sourceDish.dish_id)
        .map(({ recipe }) =>
          catalogData.school_types.find(
            (item) => item.school_type_id === recipe.school_type_id,
          ),
        )
        .filter((item) => item?.school_type_status === "ACTIVE")
        .map((item) => item?.school_type_code),
    );
    if (!canonicalSchoolTypeCodes.every((code) => releasedScopeCodes.has(code)))
      return false;
    const needle = copyQuery.trim().toLocaleLowerCase("vi");
    if (!needle) return true;
    const ingredientNames = baseRecipesForDish(sourceDish.dish_id).flatMap(
      ({ version }) =>
        version.composition.map(
          (line) =>
            catalogData.ingredients.find(
              (item) => item.ingredient_id === line.ingredient_id,
            )?.ingredient_name ?? "",
        ),
    );
    return [
      sourceDish.dish_name,
      sourceDish.dish_code,
      ...ingredientNames,
    ].some((value) => value.toLocaleLowerCase("vi").includes(needle));
  });
  const copySource = catalogData.dishes.find(
    (item) => item.dish_id === copyDraft.sourceDishId,
  );
  const copySourceVersions = copySource
    ? baseRecipesForDish(copySource.dish_id)
        .filter(({ recipe }) =>
          canonicalSchoolTypes.some(
            (item) => item.school_type_id === recipe.school_type_id,
          ),
        )
        .sort((left, right) =>
          (left.recipe.school_type_id ?? "").localeCompare(
            right.recipe.school_type_id ?? "",
          ),
        )
    : [];

  useEffect(() => {
    if (!isDirty) return;
    const guard = (event: BeforeUnloadEvent) => {
      event.preventDefault();
    };
    window.addEventListener("beforeunload", guard);
    return () => window.removeEventListener("beforeunload", guard);
  }, [isDirty]);

  const navigateTab = (nextTab: Tab) => {
    if (
      tab === "recipes" &&
      nextTab !== "recipes" &&
      isDirty &&
      !window.confirm(
        "Bạn có thay đổi chưa lưu. Bỏ các thay đổi này và rời màn hình tạo món/công thức?",
      )
    )
      return;
    if (nextTab === "adjustments" || nextTab === "effective") {
      setAdjustmentMounted(true);
      setAdjustmentView(nextTab === "adjustments" ? "rules" : "effective");
    }
    setTab(nextTab);
  };

  const beginDish = () => {
    if (mutationBlocked) return;
    if (
      isDirty &&
      !window.confirm(
        "Bạn có thay đổi chưa lưu. Bỏ các thay đổi này và tạo món mới?",
      )
    )
      return;
    setNotice(null);
    setDishEditorId("NEW");
    setDishDraft({
      ...emptyDishDraft(),
      dishTypeId:
        catalogData.dish_types.find(
          (dishType) => dishType.dish_type_status === "ACTIVE",
        )?.dish_type_id ?? "",
    });
  };

  const saveDish = async () => {
    if (!api || !authSubject || !dishEditorId || mutationBlocked) return;
    const submittingAuthSubject = authSubject;
    if (!dishDraft.name.trim() || !dishDraft.dishTypeId) {
      setNotice("Tên món và Loại món là bắt buộc.");
      return;
    }
    const payload = {
      dish_name: dishDraft.name,
      dish_category: dishDraft.category,
      dish_type_id: dishDraft.dishTypeId,
      operational_notes: dishDraft.notes,
    };
    const saved = await command(api.createDish, 1, "DISH_CREATE", payload);
    if (!saved) return;
    const affected = saved.response.affected_aggregate_ids;
    const affectedDishId =
      typeof affected === "object" &&
      affected !== null &&
      !Array.isArray(affected) &&
      typeof affected.dish_id === "string"
        ? affected.dish_id
        : null;
    const returnedDishes = Array.isArray(saved.response.dishes)
      ? (saved.response.dishes as RecipeWorkbenchData["dishes"])
      : [];
    const newDishes = returnedDishes.filter(
      (item) =>
        !catalogData.dishes.some(
          (existing) => existing.dish_id === item.dish_id,
        ),
    );
    const createdDishId =
      affectedDishId ?? (newDishes.length === 1 ? newDishes[0].dish_id : null);
    const readBack = createdDishId
      ? await refresh(
          systemSelectionForDish(createdDishId),
          submittingAuthSubject,
        )
      : false;
    if (!readBack) {
      setWriteUncertain(true);
      setWriteUncertainAuthSubject(submittingAuthSubject);
      setNotice(
        "Atlas đã ghi nhận tạo món nhưng chưa đọc lại được đúng danh tính và hai phạm vi công thức. Hãy đối soát trước khi tiếp tục.",
      );
      return;
    }
    setDishEditorId(null);
    setQuery("");
    setTab("recipes");
  };

  const saveComposition = async () => {
    const selection = authoring;
    if (!dish || selection.expected_version === null || !compositionValid) {
      setNotice(
        "Công thức cần ít nhất một nguyên liệu, đơn vị và định lượng dương.",
      );
      return;
    }
    await workflowCommand(selection.expected_version, {
      dish_id: dish.dish_id,
      school_type_id: selection.school_type_id,
      recipe_version_id: selection.recipe_version_id,
      basis_portions: basis,
      lines: presentComposition.map((line) => ({
        recipe_line_id: line.recipe_line_id,
        ingredient_id: line.ingredient_id,
        quantity_per_basis: line.quantity_per_basis,
        unit_id: line.unit_id,
        operational_note: line.operational_note,
      })) as unknown as JsonValue,
    });
  };

  const chooseIngredient = (ingredientId: string) => {
    const ingredient = catalogData.ingredients.find(
      (item) => item.ingredient_id === ingredientId,
    );
    const unit = catalogData.units.find(
      (item) => item.unit_status === "ACTIVE",
    );
    if (!ingredient || !unit) {
      setNotice("Không tìm thấy nguyên liệu hoặc đơn vị đang hoạt động.");
      return;
    }
    if (ingredientTargetLineId) {
      setComposition((lines) =>
        lines.map((line) =>
          line.recipe_line_id === ingredientTargetLineId
            ? { ...line, ingredient_id: ingredient.ingredient_id }
            : line,
        ),
      );
    } else {
      setComposition((lines) => [
        ...lines,
        {
          recipe_line_id: crypto.randomUUID(),
          predecessor_recipe_line_revision_id: null,
          ingredient_id: ingredient.ingredient_id,
          quantity_per_basis: 1,
          unit_id: unit.unit_id,
          line_disposition: "PRESENT",
          operational_note: null,
          line_code: null,
        },
      ]);
    }
    setIngredientTargetLineId(null);
    setIngredientQuery("");
  };

  const removeLine = (line: RecipeCompositionLine) => {
    setComposition((lines) =>
      lines.filter((item) => item.recipe_line_id !== line.recipe_line_id),
    );
  };

  const reconcileCopy = async (
    request: DishRecipeCopyCommandRequest,
    result: DishRecipeCopyResult | null,
    submittingAuthSubject: string,
  ) => {
    if (!api || authSubjectRef.current !== submittingAuthSubject) return false;
    const catalogResult = await api.getWorkbench(
      submittingAuthSubject,
      correlationId,
    );
    if (authSubjectRef.current !== submittingAuthSubject) return false;
    const catalog = recipeWorkbenchFromResult(catalogResult);
    const targetDish = catalog?.dishes.find(
      (item) => item.dish_id === request.payload.target_dish_id,
    );
    const canonicalTypes = catalog?.school_types.filter(
      (item) =>
        item.school_type_status === "ACTIVE" &&
        canonicalSchoolTypeCodes.includes(
          item.school_type_code as (typeof canonicalSchoolTypeCodes)[number],
        ),
    );
    if (!catalog || !targetDish || canonicalTypes?.length !== 2) return false;

    const matchedDrafts = canonicalTypes.map((schoolType) => {
      const targetRecipe = catalog.recipes.find(
        (recipe) =>
          recipe.dish_id === targetDish.dish_id &&
          recipe.school_type_id === schoolType.school_type_id &&
          recipe.recipe_status === "ACTIVE",
      );
      if (!targetRecipe) return null;
      const resultScope = result?.scope_results.find(
        (scope) => scope.school_type_code === schoolType.school_type_code,
      );
      if (
        resultScope &&
        (resultScope.school_type_id !== schoolType.school_type_id ||
          resultScope.target_recipe_id !== targetRecipe.recipe_id)
      )
        return null;
      const candidates = catalog.recipe_versions.filter(
        (version) =>
          version.recipe_id === targetRecipe.recipe_id &&
          version.recipe_version_status === "DRAFT" &&
          evidenceValue(version.source_evidence, "source_kind") ===
            "RECIPE_EFFECTIVE_COPY" &&
          evidenceValue(version.source_evidence, "outer_command_id") ===
            request.command_id &&
          evidenceValue(version.source_evidence, "source_dish_id") ===
            request.payload.source_dish_id &&
          evidenceValue(version.source_evidence, "copy_as_of_date") ===
            request.payload.as_of_date &&
          (!resultScope ||
            version.recipe_version_id === resultScope.target_recipe_version_id),
      );
      if (candidates.length !== 1) return null;
      if (resultScope) {
        const sourceRecipe = catalog.recipes.find(
          (recipe) =>
            recipe.recipe_id === resultScope.source_recipe_id &&
            recipe.dish_id === request.payload.source_dish_id &&
            recipe.school_type_id === schoolType.school_type_id,
        );
        const sourceVersion = catalog.recipe_versions.find(
          (version) =>
            version.recipe_version_id ===
              resultScope.source_recipe_version_id &&
            version.recipe_id === sourceRecipe?.recipe_id,
        );
        if (!sourceRecipe || !sourceVersion) return null;
      }
      return { schoolType, recipe: targetRecipe, version: candidates[0] };
    });
    if (matchedDrafts.some((item) => item === null)) return false;

    const readbacks = await Promise.all(
      matchedDrafts.map((item) =>
        api.getEffectiveWorkbench(
          submittingAuthSubject,
          correlationId,
          request.payload.as_of_date,
          targetDish.dish_id,
          {
            kind: "system",
            schoolTypeId: item!.schoolType.school_type_id,
          },
        ),
      ),
    );
    if (authSubjectRef.current !== submittingAuthSubject) return false;
    const parsedReadbacks = readbacks.map(
      dishRecipeOperatorWorkbenchFromResult,
    );
    const readbackMatches = parsedReadbacks.every((readback, index) => {
      const matched = matchedDrafts[index]!;
      return (
        readback?.dish.dish_id === targetDish.dish_id &&
        readback.as_of_date === request.payload.as_of_date &&
        readback.context_kind === "SYSTEM_SCHOOL_TYPE" &&
        readback.school_id === null &&
        readback.school_type_id === matched.schoolType.school_type_id &&
        readback.base_authoring.dish_id === targetDish.dish_id &&
        readback.base_authoring.school_type_id ===
          matched.schoolType.school_type_id &&
        readback.base_authoring.recipe_id === matched.recipe.recipe_id &&
        readback.base_authoring.recipe_version_id ===
          matched.version.recipe_version_id &&
        readback.base_authoring.business_status === "SAVED" &&
        readback.base_authoring.locked_for_normal_editing === false &&
        readback.base_authoring.allowed_actions.save_recipe === true
      );
    });
    if (!readbackMatches) return false;

    const primary = parsedReadbacks[0]!;
    const selection: EffectiveSelection = {
      dishId: targetDish.dish_id,
      asOfDate: request.payload.as_of_date,
      context: {
        kind: "system",
        schoolTypeId: primary.school_type_id,
      },
    };
    generation.current += 1;
    effectiveGeneration.current += 1;
    setLoadAuthSubject(submittingAuthSubject);
    setEffectiveLoadAuthSubject(submittingAuthSubject);
    setLoad({ status: "ready", data: catalog });
    setEffectiveLoad({ status: "ready", data: primary });
    setEffectiveSelection(selection);
    setDishId(targetDish.dish_id);
    setSchoolTypeId(primary.school_type_id);
    setComposition(structuredClone(primary.base_authoring.composition));
    setBasisPortions(String(primary.base_authoring.basis_portions));
    setCopyRecovery(null);
    setCopyOpen(false);
    setCopyQuery("");
    setNotice(
      "Atlas đã lưu hai công thức NHÁP theo đúng hai loại trường. Hãy kiểm tra từng phạm vi và dùng Lưu riêng khi cần phát hành.",
    );
    return true;
  };

  const executeCopyRequest = async (
    request: DishRecipeCopyCommandRequest,
    submittingAuthSubject: string,
  ) => {
    if (!api || authSubjectRef.current !== submittingAuthSubject) return;
    setBusy(true);
    let rpcResult: AtlasRpcResult;
    try {
      rpcResult = await api.copyDishRecipes(request);
    } catch {
      rpcResult = {
        kind: "transport_error",
        diagnostic: {
          code: "RPC_TRANSPORT_FAILURE",
          safeMessage: "The copy request ended without a trusted response.",
          commandId: request.command_id,
          correlationId: request.correlation_id,
        },
      };
    }
    if (authSubjectRef.current !== submittingAuthSubject) {
      setBusy(false);
      setCopyOpen(false);
      setNotice(null);
      if (rpcResult.kind === "success") {
        const parsed = dishRecipeCopyFromResult(rpcResult);
        setCopyRecovery({
          kind: "committed_unreadable",
          authSubject: submittingAuthSubject,
          request,
          result:
            parsed?.command_id === request.command_id &&
            parsed.correlation_id === request.correlation_id
              ? parsed
              : null,
        });
      } else if (rpcResult.kind === "transport_error") {
        setCopyRecovery({
          kind: "unknown",
          authSubject: submittingAuthSubject,
          request,
          result: null,
        });
      } else if (
        rpcResult.kind === "backend_error" &&
        rpcResult.error.retryable === true
      ) {
        setCopyRecovery({
          kind: "retryable",
          authSubject: submittingAuthSubject,
          request,
          result: null,
        });
      }
      return;
    }
    if (rpcResult.kind === "backend_error") {
      const retryable = rpcResult.error.retryable === true;
      setCopyRecovery(
        retryable
          ? {
              kind: "retryable",
              authSubject: submittingAuthSubject,
              request,
              result: null,
            }
          : null,
      );
      setNotice(recipeResultMessage(rpcResult));
      setCopyOpen(false);
      const refreshSchoolTypeId =
        schoolTypeId ?? canonicalSchoolTypes[0]?.school_type_id;
      if (!retryable && refreshSchoolTypeId) {
        await refresh(
          {
            dishId: request.payload.target_dish_id,
            asOfDate: request.payload.as_of_date,
            context: {
              kind: "system",
              schoolTypeId: refreshSchoolTypeId,
            },
          },
          submittingAuthSubject,
        );
      }
      setBusy(false);
      return;
    }
    if (rpcResult.kind !== "success") {
      setBusy(false);
      setCopyRecovery({
        kind: "unknown",
        authSubject: submittingAuthSubject,
        request,
        result: null,
      });
      setNotice(null);
      setCopyOpen(false);
      return;
    }

    const parsed = dishRecipeCopyFromResult(rpcResult);
    const trusted =
      parsed?.command_id === request.command_id &&
      parsed.correlation_id === request.correlation_id
        ? parsed
        : null;
    const reconciled = await reconcileCopy(
      request,
      trusted,
      submittingAuthSubject,
    );
    setBusy(false);
    if (!reconciled) {
      setCopyRecovery({
        kind: "committed_unreadable",
        authSubject: submittingAuthSubject,
        request,
        result: trusted,
      });
      setNotice(null);
    }
  };

  const startCopy = async () => {
    if (
      !api ||
      !authSubject ||
      !dish ||
      !copySource ||
      copySource.dish_id === dish.dish_id ||
      creationLocked ||
      effectiveMutationBlocked ||
      !copyDraft.reasonNote.trim() ||
      !/^\d{4}-\d{2}-\d{2}$/.test(copyDraft.asOfDate)
    )
      return;
    if (
      isDirty &&
      !window.confirm(
        "Bạn có thay đổi chưa lưu. Sao chép sẽ tạo hai công thức NHÁP mới và bỏ các thay đổi này. Tiếp tục?",
      )
    )
      return;

    setBusy(true);
    const submittingAuthSubject = authSubject;
    const freshResult = await api.getWorkbench(
      submittingAuthSubject,
      correlationId,
    );
    if (authSubjectRef.current !== submittingAuthSubject) {
      setBusy(false);
      return;
    }
    const fresh = recipeWorkbenchFromResult(freshResult);
    const freshTarget = fresh?.dishes.find(
      (item) => item.dish_id === dish.dish_id,
    );
    if (!fresh || !freshTarget) {
      setBusy(false);
      setNotice(
        "Không đọc được phiên bản mới nhất của món đích. Atlas chưa gửi yêu cầu sao chép.",
      );
      return;
    }
    const commandId = crypto.randomUUID();
    const request = dishRecipeCopyRequest({
      authSubject,
      correlationId,
      commandId,
      idempotencyKey: `copy-dish-recipes:${commandId}`,
      requestedAt: new Date().toISOString(),
      expectedVersion: freshTarget.version,
      reasonCode: "COPY_DISH_RECIPES",
      reasonNote: copyDraft.reasonNote.trim(),
      sourceDishId: copySource.dish_id,
      targetDishId: freshTarget.dish_id,
      asOfDate: copyDraft.asOfDate,
    });
    setBusy(false);
    await executeCopyRequest(request, submittingAuthSubject);
  };

  const recoverCopy = async () => {
    if (!copyRecovery || authSubjectRef.current !== copyRecovery.authSubject)
      return;
    if (copyRecovery.kind === "retryable") {
      if (!effectiveAuthorityReady) return;
      await executeCopyRequest(copyRecovery.request, copyRecovery.authSubject);
      return;
    }
    setBusy(true);
    const reconciled = await reconcileCopy(
      copyRecovery.request,
      copyRecovery.result,
      copyRecovery.authSubject,
    );
    setBusy(false);
    if (!reconciled)
      setNotice(
        "Chưa đối soát được đủ hai công thức NHÁP. Không gửi lại yêu cầu sao chép; hãy kiểm tra kết nối rồi đối soát lại.",
      );
  };

  const parseWorkbook = async (file?: File) => {
    if (!file) return;
    setBusy(true);
    setNotice(null);
    try {
      setWorkbook(
        await reviewRecipeWorkbook(file, {
          schoolTypes: catalogData.school_types,
          ingredients: catalogData.ingredients,
          units: catalogData.units,
        }),
      );
    } catch {
      setWorkbook(null);
      setNotice("Không thể đọc cấu trúc tệp .xlsx này.");
    } finally {
      setBusy(false);
    }
  };

  const applyImport = async () => {
    if (
      !api ||
      !workbook ||
      workbook.errors.length ||
      !importReason.trim() ||
      mutationBlocked
    )
      return;
    if (
      !window.confirm(
        "Áp dụng workbook đã xem trước thành các phiên bản NHÁP mới?",
      )
    )
      return;
    const applied = await command(
      api.applyImport,
      1,
      "RECIPE_WORKBOOK_IMPORT",
      {
        canonical_json: workbook.canonicalJson,
        workbook_checksum: workbook.checksum,
      },
      importReason,
    );
    if (applied) await refresh();
  };

  const copyRecoveryUnavailable = Boolean(
    copyRecovery && copyRecovery.authSubject !== authSubject,
  );
  const copyRecoveryActionUnavailable = Boolean(
    copyRecoveryUnavailable ||
    (copyRecovery?.kind === "retryable" && !effectiveAuthorityReady),
  );
  const writeRecoveryAuthSubject =
    saveRecovery?.authSubject ?? writeUncertainAuthSubject;
  const writeRecoveryUnavailable = Boolean(
    writeRecoveryAuthSubject && writeRecoveryAuthSubject !== authSubject,
  );
  const copyRecoveryNotice = copyRecovery ? (
    <div className="operator-notice warning" role="alert">
      <p>
        {copyRecoveryUnavailable
          ? "Yêu cầu sao chép đang chờ đối soát thuộc phiên đăng nhập trước. Phiên hiện tại không thể gửi lại hoặc dùng dữ liệu đọc lại để gỡ chặn."
          : copyRecovery.kind === "unknown"
            ? "Atlas chưa xác định yêu cầu sao chép đã hoàn tất hay chưa. Không gửi lại yêu cầu này trước khi đối soát."
            : copyRecovery.kind === "retryable"
              ? "Atlas xác nhận yêu cầu cũ có thể thử lại an toàn với cùng mã chống trùng."
              : "Atlas đã ghi nhận sao chép nhưng chưa đọc lại được đủ hai công thức NHÁP."}
      </p>
      <button
        type="button"
        disabled={busy || copyRecoveryActionUnavailable}
        onClick={() => void recoverCopy()}
      >
        {copyRecovery.kind === "retryable"
          ? "Thử lại yêu cầu cũ"
          : "Đối soát kết quả sao chép"}
      </button>
      {copyRecovery.kind === "retryable" && (
        <button
          type="button"
          disabled={busy || copyRecoveryActionUnavailable}
          onClick={() => {
            setCopyRecovery(null);
            setNotice(
              "Đã bỏ yêu cầu cũ chưa được Atlas ghi nhận. Lần sao chép tiếp theo sẽ dùng một mã yêu cầu mới.",
            );
          }}
        >
          Bỏ yêu cầu cũ
        </button>
      )}
    </div>
  ) : null;

  const adjustmentSurface = adjustmentMounted ? (
    <div
      key="adjustment-workbench"
      hidden={
        Boolean(authSubject) && tab !== "adjustments" && tab !== "effective"
      }
    >
      <div className="recipe-secondary-tabs" role="tablist">
        <button
          type="button"
          role="tab"
          aria-selected={adjustmentView === "rules"}
          onClick={() => navigateTab("adjustments")}
        >
          Quy tắc điều chỉnh
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={adjustmentView === "effective"}
          onClick={() => navigateTab("effective")}
        >
          Công thức hiệu lực
        </button>
      </div>
      <RecipeAdjustmentWorkbench
        authState={authState}
        api={adjustmentApi}
        view={adjustmentView}
        mode={mode}
      />
    </div>
  ) : null;

  if (!authSubject) {
    return (
      <Panel
        title="Công thức món ăn"
        description="Tìm món ăn, xem nguyên liệu và cập nhật định lượng."
        status={<Chip tone="warning">Cần đăng nhập</Chip>}
      >
        <p className="operator-notice warning">
          {authState.status === "session_expired"
            ? "Phiên làm việc đã hết. Vui lòng đăng nhập lại."
            : "Đăng nhập để xem và cập nhật công thức món ăn."}
        </p>
        {adjustmentSurface}
      </Panel>
    );
  }

  return (
    <Panel
      title="Công thức món ăn"
      description="Tra cứu công thức hiện hành hoặc tạo món và công thức mới."
      status={
        <Chip tone={load.status === "error" ? "danger" : "ok"}>
          {mode === "review" ? "Dữ liệu xem thử" : "Kết nối Atlas"}
        </Chip>
      }
    >
      <div className="master-data-tabs" role="tablist">
        {(
          [
            ["catalog", "Danh sách"],
            ["recipes", "Tạo món & công thức"],
            ["adjustments", "Điều chỉnh"],
          ] as const
        ).map(([value, label]) => (
          <button
            type="button"
            role="tab"
            aria-selected={tab === value}
            className={tab === value ? "active" : ""}
            onClick={() => navigateTab(value)}
            key={value}
          >
            {label}
          </button>
        ))}
      </div>

      {load.status === "loading" && (
        <p className="operator-notice">Đang tải dữ liệu công thức…</p>
      )}
      {load.status === "error" && (
        <p className="operator-notice warning">
          {load.message}
          <button type="button" onClick={() => void refresh()}>
            Tải lại
          </button>
        </p>
      )}
      {notice && <p className="operator-notice">{notice}</p>}
      {writeUncertain && (
        <p className="operator-notice warning" role="alert">
          {writeRecoveryUnavailable
            ? "Thao tác đang chờ đối soát thuộc phiên đăng nhập trước. Phiên hiện tại không thể dùng dữ liệu đọc lại để gỡ chặn."
            : saveRecovery
              ? saveRecovery.kind === "unknown"
                ? "Chưa xác định thao tác Lưu vừa rồi đã hoàn tất hay chưa. Atlas sẽ chỉ gỡ chặn khi đọc lại đúng nội dung đã gửi."
                : "Atlas đã ghi nhận Lưu nhưng chưa đọc lại được đúng nội dung đã gửi."
              : "Chưa xác định thao tác vừa rồi đã hoàn tất hay chưa. Hãy tải lại trang và đối soát trước khi tiếp tục."}
          {saveRecovery && (
            <button
              type="button"
              disabled={busy || writeRecoveryUnavailable}
              onClick={() => {
                setBusy(true);
                void reconcileSave(
                  saveRecovery.request,
                  saveRecovery.selection,
                  saveRecovery.authSubject,
                ).then((matched) => {
                  setBusy(false);
                  if (!matched)
                    setNotice(
                      "Dữ liệu đọc lại chưa khớp nội dung Lưu. Atlas vẫn chặn thao tác ghi và giữ nguyên nội dung đang soạn.",
                    );
                });
              }}
            >
              Đối soát kết quả Lưu
            </button>
          )}
        </p>
      )}
      {!copyOpen && copyRecoveryNotice}
      {adjustmentSurface}

      {tab === "catalog" && (
        <>
          <div className="master-data-toolbar">
            <label className="evidence-field">
              Tìm món hoặc nguyên liệu trong công thức gốc
              <input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Tìm theo món, mã món hoặc nguyên liệu gốc…"
              />
            </label>
            <span />
            <button type="button" onClick={() => void refresh()}>
              Tải lại
            </button>
            <button
              type="button"
              className="primary-toolbar-action"
              onClick={() => navigateTab("recipes")}
            >
              Tạo món & công thức
            </button>
          </div>
          <div className="master-data-workspace with-detail">
            <div className="master-data-table-scroll">
              <CompactTable
                headers={[
                  "Tên món",
                  "Loại món",
                  "Công thức gốc đã phát hành",
                  "Tình trạng",
                  "",
                ]}
              >
                {shownDishes.map((item) => (
                  <tr key={item.dish_id}>
                    <td>
                      <strong>{item.dish_name}</strong>
                    </td>
                    <td>
                      {item.dish_type_name ?? (
                        <span className="operator-notice danger">Chưa gán</span>
                      )}
                    </td>
                    <td>
                      {baseRecipesForDish(item.dish_id).length ? (
                        baseRecipesForDish(item.dish_id).map(
                          ({ recipe, version }) => (
                            <small key={recipe.recipe_id}>
                              {schoolScopeLabel(
                                recipe,
                                catalogData.school_types,
                              )}
                              : {version.basis_portions} suất ·{" "}
                              {version.composition
                                .filter(
                                  (line) => line.line_disposition === "PRESENT",
                                )
                                .map((line) =>
                                  ingredientLabel(
                                    line.ingredient_id,
                                    catalogData.ingredients,
                                  ),
                                )
                                .join(", ") || "Chưa có nguyên liệu"}
                            </small>
                          ),
                        )
                      ) : (
                        <span>Chưa có công thức sẵn sàng</span>
                      )}
                    </td>
                    <td>
                      <Chip tone={statusTone(item.dish_status)}>
                        {statusLabel[item.dish_status]}
                      </Chip>
                    </td>
                    <td>
                      <div className="master-data-row-actions">
                        <button
                          className="inline-action"
                          onClick={() =>
                            void selectRecipeContext(
                              systemSelectionForDish(
                                item.dish_id,
                                canonicalSchoolTypes[0]?.school_type_id,
                              ),
                            )
                          }
                        >
                          Xem
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </CompactTable>
              {!shownDishes.length && (
                <p className="supporting-copy">
                  Chưa có món ăn phù hợp bộ lọc.
                </p>
              )}
            </div>
            <aside
              className="master-data-detail"
              aria-label="Chi tiết công thức hiệu lực"
            >
              <div className="master-data-detail-heading">
                <div>
                  <span>Công thức theo ngày và phạm vi áp dụng</span>
                  <h3>{dish?.dish_name ?? "Chọn một món"}</h3>
                </div>
              </div>
              {effectiveLoad.status === "error" &&
                (!dish || !currentEffectiveSelection) && (
                  <p className="operator-notice warning" role="alert">
                    {effectiveLoad.message}
                  </p>
                )}
              {dish && currentEffectiveSelection && (
                <>
                  <label className="evidence-field">
                    Ngày áp dụng
                    <input
                      aria-label="Ngày áp dụng"
                      type="date"
                      disabled={busy}
                      value={currentEffectiveSelection.asOfDate}
                      onChange={(event) =>
                        void selectRecipeContext({
                          ...currentEffectiveSelection,
                          asOfDate: event.target.value,
                        })
                      }
                    />
                  </label>
                  <label className="evidence-field">
                    Ngữ cảnh công thức
                    <select
                      aria-label="Ngữ cảnh công thức"
                      disabled={busy}
                      value={effectiveContextValue}
                      onChange={(event) =>
                        changeEffectiveContext(event.target.value)
                      }
                    >
                      {canonicalSchoolTypes.map((item) => (
                        <option
                          key={`system:${item.school_type_id}`}
                          value={`system:${item.school_type_id}`}
                        >
                          Hệ thống · {item.school_type_name}
                        </option>
                      ))}
                      {currentSchools.map((item) => (
                        <option
                          key={`school:${item.school_id}`}
                          value={`school:${item.school_id}`}
                        >
                          Trường · {item.school_name}
                        </option>
                      ))}
                    </select>
                  </label>
                  {effectiveLoad.status === "loading" && (
                    <p className="supporting-copy">
                      Đang tải công thức hiệu lực cho ngữ cảnh đã chọn…
                    </p>
                  )}
                  {effectiveLoad.status === "error" && (
                    <p className="operator-notice warning" role="alert">
                      {effectiveLoad.message}
                    </p>
                  )}
                  {effectiveData && (
                    <>
                      <h4>Công thức hiệu lực</h4>
                      <p className="supporting-copy">
                        {effectiveData.context_kind === "SCHOOL"
                          ? "Ngữ cảnh Trường, bao gồm ngoại lệ áp dụng."
                          : "Ngữ cảnh hệ thống, không bao gồm ngoại lệ Trường."}
                      </p>
                      {effectiveData.effective_readiness.status === "READY" ? (
                        <CompactTable
                          headers={["Nguyên liệu", "Định lượng", "Đơn vị"]}
                        >
                          {effectiveData.current_effective_bom.map((line) => (
                            <tr key={`${line.target_kind}:${line.target_id}`}>
                              <td>{line.ingredient_name}</td>
                              <td>{line.quantity_per_basis}</td>
                              <td>{line.unit_name}</td>
                            </tr>
                          ))}
                        </CompactTable>
                      ) : (
                        <div className="operator-notice warning" role="status">
                          <strong>Chưa sẵn sàng theo ngữ cảnh này</strong>
                          {effectiveData.effective_readiness.blockers.map(
                            (blocker) => (
                              <p key={blocker.code}>{blocker.message}</p>
                            ),
                          )}
                        </div>
                      )}
                      <p className="supporting-copy">
                        Ngoại lệ Trường đang đóng góp:{" "}
                        {effectiveData.school_exception_count}
                      </p>
                      <details className="recipe-history">
                        <summary>Lịch sử BOM hiệu lực</summary>
                        {!effectiveData.history_periods.length ? (
                          <p>Chưa có kỳ hiệu lực để hiển thị.</p>
                        ) : (
                          effectiveData.history_periods.map((period) => (
                            <section
                              key={`${period.period_from}:${period.period_to ?? "open"}`}
                            >
                              <h4>
                                Từ {period.period_from}
                                {period.period_to
                                  ? ` đến trước ${period.period_to}`
                                  : " trở đi"}
                              </h4>
                              {period.resolution_status === "READY" ? (
                                <CompactTable
                                  headers={[
                                    "Nguyên liệu",
                                    "Định lượng",
                                    "Đơn vị",
                                  ]}
                                >
                                  {period.effective_bom.map((line) => (
                                    <tr
                                      key={`${period.period_from}:${line.target_kind}:${line.target_id}`}
                                    >
                                      <td>{line.ingredient_name}</td>
                                      <td>{line.quantity_per_basis}</td>
                                      <td>{line.unit_name}</td>
                                    </tr>
                                  ))}
                                </CompactTable>
                              ) : (
                                period.blockers.map((blocker) => (
                                  <p key={blocker.code}>{blocker.message}</p>
                                ))
                              )}
                              {period.change_orders.map((changeOrder) => (
                                <dl
                                  className="master-data-detail-list"
                                  key={changeOrder.revision_id}
                                >
                                  <div>
                                    <dt>Sự kiện thay đổi</dt>
                                    <dd>
                                      {changeOrder.business_event_kind} ·{" "}
                                      {changeOrder.action_kind} · bản ghi{" "}
                                      {changeOrder.revision_number}
                                    </dd>
                                  </div>
                                  <div>
                                    <dt>Lý do ghi nhận</dt>
                                    <dd>
                                      {changeOrder.reason_code} ·{" "}
                                      {changeOrder.reason}
                                    </dd>
                                  </div>
                                  <div>
                                    <dt>Phạm vi và kỳ hiệu lực ghi nhận</dt>
                                    <dd>
                                      {changeOrder.scope_kind} · từ{" "}
                                      {changeOrder.effective_from}
                                      {changeOrder.effective_to
                                        ? ` đến trước ${changeOrder.effective_to}`
                                        : " trở đi"}
                                    </dd>
                                  </div>
                                  <div>
                                    <dt>Người ghi nhận trong dữ liệu</dt>
                                    <dd>
                                      {changeOrder.issuer ??
                                        "Không có thông tin người ban hành gốc"}
                                    </dd>
                                  </div>
                                  <div>
                                    <dt>Thời điểm ghi nhận trong dữ liệu</dt>
                                    <dd>
                                      {changeOrder.issued_at
                                        ? new Date(
                                            changeOrder.issued_at,
                                          ).toLocaleString("vi-VN")
                                        : "Không có thời điểm ban hành gốc"}
                                    </dd>
                                  </div>
                                </dl>
                              ))}
                              {period.change_orders.length > 0 && (
                                <p className="supporting-copy">
                                  Với dữ liệu nhập hoặc dữ liệu cũ, Atlas chưa
                                  có dấu hiệu tin cậy để xác nhận người và thời
                                  điểm ban hành gốc. Thông tin ghi nhận bên trên
                                  không được coi là thông tin ban hành gốc.
                                </p>
                              )}
                            </section>
                          ))
                        )}
                      </details>
                    </>
                  )}
                  <p className="supporting-copy">
                    Bảng danh sách dùng công thức gốc để hỗ trợ tìm kiếm. Chi
                    tiết bên trên hiển thị công thức áp dụng cho đúng ngày và
                    ngữ cảnh đã chọn.
                  </p>
                </>
              )}
            </aside>
          </div>
        </>
      )}

      {tab === "recipes" && (
        <>
          <div className="master-data-toolbar recipe-creation-toolbar">
            <div>
              <h2>Tạo món & công thức</h2>
              <p>
                Tạo món mới, nhập công thức ban đầu và lưu để sẵn sàng cho Lập
                nhu cầu.
              </p>
            </div>
            <button
              type="button"
              disabled={mutationBlocked}
              onClick={() => beginDish()}
            >
              Tạo món mới
            </button>
            <button
              type="button"
              disabled={!dish || creationLocked || effectiveMutationBlocked}
              onClick={() => setCopyOpen(true)}
            >
              Sao chép công thức
            </button>
            <button type="button" onClick={() => navigateTab("import")}>
              Nhập workbook
            </button>
          </div>
          <div className="recipe-first-user-layout">
            <aside
              className="recipe-dish-finder"
              aria-label="Chọn món đang tạo"
            >
              <label
                className="recipe-field-label"
                htmlFor="recipe-dish-search"
              >
                Chọn món đang tạo
              </label>
              <input
                id="recipe-dish-search"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Tìm theo tên món…"
              />
              <div className="recipe-dish-results" role="listbox">
                {shownDishes.map((item) => (
                  <button
                    type="button"
                    role="option"
                    aria-selected={item.dish_id === dishId}
                    className={item.dish_id === dishId ? "active" : ""}
                    key={item.dish_id}
                    onClick={() =>
                      void selectRecipeContext(
                        systemSelectionForDish(
                          item.dish_id,
                          canonicalSchoolTypes[0]?.school_type_id,
                        ),
                      )
                    }
                  >
                    <strong>{item.dish_name}</strong>
                    <span>
                      {item.dish_type_name ?? "Chưa xác định loại món"}
                    </span>
                  </button>
                ))}
                {!shownDishes.length && (
                  <p className="supporting-copy">
                    Không có món ăn phù hợp với nội dung tìm kiếm.
                  </p>
                )}
              </div>
            </aside>

            <section className="recipe-first-user-editor">
              {dishEditorId ? (
                <p className="supporting-copy">
                  Nhập thông tin món mới trong biểu mẫu. Sau khi lưu món, bạn có
                  thể tạo công thức ban đầu cho món đó.
                </p>
              ) : dish ? (
                <>
                  <header className="recipe-context-header">
                    <div>
                      <span>Món đang chọn</span>
                      <h3>{dish.dish_name}</h3>
                      <p>Loại món: {dish.dish_type_name ?? "Chưa xác định"}</p>
                    </div>
                    <Chip
                      tone={
                        visibleRecipeStatus === "Cần xử lý"
                          ? "warning"
                          : visibleRecipeStatus === "Sẵn sàng cho Lập nhu cầu"
                            ? "ok"
                            : "neutral"
                      }
                    >
                      {visibleRecipeStatus}
                    </Chip>
                  </header>

                  {creationLocked && (
                    <div className="operator-notice warning" role="alert">
                      <strong>Đã dùng trong thực đơn đã duyệt</strong>
                      <p>
                        {authoring.lock_reason ??
                          "Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh."}
                      </p>
                      <button
                        type="button"
                        onClick={() => navigateTab("adjustments")}
                      >
                        Đi đến Điều chỉnh
                      </button>
                    </div>
                  )}

                  {effectiveData?.effective_readiness.status === "BLOCKED" && (
                    <div className="operator-notice warning">
                      <strong>Công thức hiệu lực đang bị chặn</strong>
                      {effectiveData.effective_readiness.blockers.map(
                        (blocker) => (
                          <p key={blocker.code}>{blocker.message}</p>
                        ),
                      )}
                      <p>
                        Bạn vẫn có thể soạn công thức gốc cho loại trường này
                        khi quyền Lưu cho phép.
                      </p>
                    </div>
                  )}

                  <div className="recipe-scope-row">
                    <label className="recipe-field-label">
                      Áp dụng cho
                      <select
                        disabled={busy}
                        value={schoolTypeId ?? ""}
                        onChange={(event) =>
                          void selectRecipeContext(
                            systemSelectionForDish(
                              dish.dish_id,
                              event.target.value,
                            ),
                          )
                        }
                      >
                        {canonicalSchoolTypes.map((item) => (
                          <option
                            key={item.school_type_id}
                            value={item.school_type_id}
                          >
                            {item.school_type_name}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label className="recipe-field-label recipe-basis-field">
                      Định lượng cho
                      <span className="recipe-basis-control">
                        <input
                          disabled={authoringReadOnly}
                          aria-label="Số suất áp dụng cho định lượng"
                          type="number"
                          min="1"
                          step="1"
                          value={basisPortions}
                          onChange={(event) =>
                            setBasisPortions(event.target.value)
                          }
                        />
                        <span>suất</span>
                      </span>
                    </label>
                  </div>

                  <div className="recipe-section-heading">
                    <div>
                      <h3>Công thức</h3>
                      <p>
                        Thêm nguyên liệu, nhập định lượng và chọn đơn vị tương
                        ứng.
                      </p>
                    </div>
                  </div>

                  <div className="recipe-ingredient-picker">
                    <label
                      className="recipe-field-label"
                      htmlFor="recipe-ingredient-search"
                    >
                      {ingredientTargetLineId
                        ? "Chọn nguyên liệu thay thế"
                        : "Thêm nguyên liệu"}
                    </label>
                    <div className="recipe-ingredient-search-row">
                      <input
                        disabled={authoringReadOnly}
                        id="recipe-ingredient-search"
                        value={ingredientQuery}
                        onChange={(event) =>
                          setIngredientQuery(event.target.value)
                        }
                        placeholder="Tìm nguyên liệu để thêm…"
                      />
                      {ingredientTargetLineId && (
                        <button
                          type="button"
                          className="inline-action"
                          onClick={() => {
                            setIngredientTargetLineId(null);
                            setIngredientQuery("");
                          }}
                        >
                          Hủy đổi
                        </button>
                      )}
                    </div>
                    {ingredientQuery.trim() && (
                      <div className="recipe-ingredient-results" role="listbox">
                        {shownIngredients.map((item) => (
                          <button
                            type="button"
                            disabled={authoringReadOnly}
                            role="option"
                            aria-selected={false}
                            key={item.ingredient_id}
                            onClick={() => chooseIngredient(item.ingredient_id)}
                          >
                            <strong>{item.ingredient_name}</strong>
                          </button>
                        ))}
                        {!shownIngredients.length && (
                          <p>Không tìm thấy nguyên liệu phù hợp để thêm.</p>
                        )}
                      </div>
                    )}
                  </div>

                  <div className="master-data-table-scroll recipe-bom-table">
                    <CompactTable
                      headers={[
                        "Nguyên liệu",
                        "Định lượng",
                        "Đơn vị",
                        "Ghi chú",
                        "",
                      ]}
                    >
                      {presentComposition.map((line) => (
                        <tr key={line.recipe_line_id}>
                          <td>
                            <strong>
                              {ingredientLabel(
                                line.ingredient_id,
                                catalogData.ingredients,
                              )}
                            </strong>
                            <button
                              type="button"
                              disabled={authoringReadOnly}
                              className="inline-action recipe-change-ingredient"
                              onClick={() => {
                                setIngredientTargetLineId(line.recipe_line_id);
                                setIngredientQuery("");
                              }}
                            >
                              Đổi
                            </button>
                          </td>
                          <td>
                            <input
                              disabled={authoringReadOnly}
                              aria-label={`Định lượng ${ingredientLabel(
                                line.ingredient_id,
                                catalogData.ingredients,
                              )}`}
                              type="number"
                              min="0"
                              step="0.000001"
                              value={line.quantity_per_basis}
                              onChange={(event) =>
                                setComposition((lines) =>
                                  lines.map((item) =>
                                    item.recipe_line_id === line.recipe_line_id
                                      ? {
                                          ...item,
                                          quantity_per_basis: Number(
                                            event.target.value,
                                          ),
                                        }
                                      : item,
                                  ),
                                )
                              }
                            />
                          </td>
                          <td>
                            <select
                              disabled={authoringReadOnly}
                              aria-label={`Đơn vị ${ingredientLabel(
                                line.ingredient_id,
                                catalogData.ingredients,
                              )}`}
                              value={line.unit_id}
                              onChange={(event) =>
                                setComposition((lines) =>
                                  lines.map((item) =>
                                    item.recipe_line_id === line.recipe_line_id
                                      ? {
                                          ...item,
                                          unit_id: event.target.value,
                                        }
                                      : item,
                                  ),
                                )
                              }
                            >
                              {catalogData.units
                                .filter((item) => item.unit_status === "ACTIVE")
                                .map((item) => (
                                  <option
                                    value={item.unit_id}
                                    key={item.unit_id}
                                  >
                                    {item.unit_name}
                                  </option>
                                ))}
                            </select>
                          </td>
                          <td>
                            <input
                              disabled={authoringReadOnly}
                              aria-label={`Ghi chú ${ingredientLabel(
                                line.ingredient_id,
                                catalogData.ingredients,
                              )}`}
                              value={line.operational_note ?? ""}
                              onChange={(event) =>
                                setComposition((lines) =>
                                  lines.map((item) =>
                                    item.recipe_line_id === line.recipe_line_id
                                      ? {
                                          ...item,
                                          operational_note:
                                            event.target.value || null,
                                        }
                                      : item,
                                  ),
                                )
                              }
                            />
                          </td>
                          <td>
                            <button
                              type="button"
                              disabled={authoringReadOnly}
                              className="inline-action danger-action"
                              onClick={() => removeLine(line)}
                            >
                              Xóa
                            </button>
                          </td>
                        </tr>
                      ))}
                    </CompactTable>
                    {!presentComposition.length && (
                      <p className="recipe-empty-composition">
                        Chưa có nguyên liệu. Dùng ô tìm kiếm phía trên để thêm.
                      </p>
                    )}
                  </div>

                  {!compositionValid && presentComposition.length > 0 && (
                    <p className="operator-notice warning">
                      Kiểm tra lại định lượng, đơn vị và nguyên liệu trùng trước
                      khi lưu.
                    </p>
                  )}

                  <div className="recipe-action-area">
                    <div>
                      <strong>{visibleRecipeStatus}</strong>
                      <p>
                        Tạo/Lưu sẽ làm công thức sẵn sàng cho Lập nhu cầu. Bạn
                        có thể chỉnh sửa lại cho đến lần đầu món có trong thực
                        đơn đã duyệt.
                      </p>
                    </div>
                    <div className="workbench-actions">
                      <button
                        type="button"
                        className={
                          authoringReadyToSubmit && compositionValid
                            ? "primary"
                            : undefined
                        }
                        disabled={
                          busy ||
                          effectiveMutationBlocked ||
                          !api ||
                          !authoringReadyToSubmit ||
                          !compositionValid ||
                          authoringReadOnly ||
                          effectiveLoad.status !== "ready" ||
                          !authoring.allowed_actions.save_recipe
                        }
                        title={
                          authoring.disabled_reasons.save_recipe ?? undefined
                        }
                        onClick={() => void saveComposition()}
                      >
                        {authoring.recipe_id ? "Lưu" : "Tạo"}
                      </button>
                    </div>
                  </div>

                  {authoring.disabled_reasons.save_recipe && (
                    <p className="recipe-disabled-reason">
                      {authoring.disabled_reasons.save_recipe}
                    </p>
                  )}

                  <details className="recipe-history">
                    <summary>Lịch sử công thức</summary>
                    {!versions.length ? (
                      <p>Chưa có lịch sử cho phạm vi áp dụng này.</p>
                    ) : (
                      <ol>
                        {versions.map((item) => (
                          <li key={item.recipe_version_id}>
                            <div>
                              <strong>
                                {item.recipe_version_status ===
                                "RELEASED_FOR_PLANNING"
                                  ? "Sẵn sàng cho Lập nhu cầu"
                                  : item.recipe_version_status === "DRAFT"
                                    ? "Đã lưu để chỉnh sửa"
                                    : "Bản công thức trước đây"}
                              </strong>
                              <span>
                                {new Date(
                                  item.released_at ?? item.created_at,
                                ).toLocaleString("vi-VN")}
                              </span>
                            </div>
                            <details>
                              <summary>Chi tiết hỗ trợ</summary>
                              <p>
                                Số lưu trữ: {item.version_number} · Mã tham
                                chiếu: {item.recipe_version_id}
                              </p>
                            </details>
                          </li>
                        ))}
                      </ol>
                    )}
                  </details>
                </>
              ) : (
                <p className="supporting-copy">
                  Chọn một món ăn để xem hoặc tạo công thức.
                </p>
              )}
            </section>
          </div>
        </>
      )}

      {copyOpen && (
        <div className="recipe-copy-backdrop">
          <section
            className="recipe-copy-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="recipe-copy-title"
          >
            <header className="master-data-detail-heading">
              <div>
                <span>Hỗ trợ tạo công thức</span>
                <h3 id="recipe-copy-title">Sao chép công thức</h3>
              </div>
              <button
                type="button"
                aria-label="Đóng Sao chép công thức"
                onClick={() => setCopyOpen(false)}
              >
                ×
              </button>
            </header>
            <p className="drawer-guidance">
              Atlas chụp công thức hiệu lực của món nguồn tại ngày đã chọn và
              tạo đồng thời hai công thức NHÁP cho đúng hai loại trường chuẩn.
              Thao tác này chưa phát hành công thức.
            </p>
            {copyRecoveryNotice}
            <label className="evidence-field">
              Tìm món nguồn hoặc nguyên liệu trong công thức gốc
              <input
                value={copyQuery}
                onChange={(event) => setCopyQuery(event.target.value)}
                placeholder="Tìm món nguồn hoặc nguyên liệu gốc…"
              />
            </label>
            <label className="evidence-field">
              Món nguồn
              <select
                value={copyDraft.sourceDishId}
                onChange={(event) =>
                  setCopyDraft((draft) => ({
                    ...draft,
                    sourceDishId: event.target.value,
                  }))
                }
              >
                <option value="">Chọn món nguồn</option>
                {copySourceOptions.map((item) => {
                  return (
                    <option key={item.dish_id} value={item.dish_id}>
                      {item.dish_name}
                    </option>
                  );
                })}
              </select>
            </label>
            <label className="evidence-field">
              Ngày chụp công thức nguồn
              <input
                type="date"
                value={copyDraft.asOfDate}
                onChange={(event) =>
                  setCopyDraft((draft) => ({
                    ...draft,
                    asOfDate: event.target.value,
                  }))
                }
              />
            </label>
            <label className="evidence-field">
              Lý do sao chép
              <textarea
                required
                value={copyDraft.reasonNote}
                onChange={(event) =>
                  setCopyDraft((draft) => ({
                    ...draft,
                    reasonNote: event.target.value,
                  }))
                }
              />
            </label>
            <div className="recipe-copy-preview">
              <h4>Tham chiếu công thức gốc đã phát hành</h4>
              {!copySource ? (
                <p className="supporting-copy">
                  Chọn một món nguồn có đủ hai công thức chuẩn.
                </p>
              ) : (
                <CompactTable
                  headers={["Loại trường", "Nguyên liệu gốc", "Số suất"]}
                >
                  {copySourceVersions.map(({ recipe, version }) => (
                    <tr key={version.recipe_version_id}>
                      <td>
                        {schoolScopeLabel(recipe, catalogData.school_types)}
                      </td>
                      <td>
                        {version.composition
                          .filter((line) => line.line_disposition === "PRESENT")
                          .map((line) =>
                            ingredientLabel(
                              line.ingredient_id,
                              catalogData.ingredients,
                            ),
                          )
                          .join(", ")}
                      </td>
                      <td>{version.basis_portions}</td>
                    </tr>
                  ))}
                </CompactTable>
              )}
            </div>
            <div className="workbench-actions">
              <button type="button" onClick={() => setCopyOpen(false)}>
                Hủy
              </button>
              <button
                type="button"
                className="primary"
                disabled={
                  busy ||
                  !copySource ||
                  !dish ||
                  creationLocked ||
                  effectiveMutationBlocked ||
                  !copyDraft.reasonNote.trim() ||
                  !copyDraft.asOfDate
                }
                onClick={() => void startCopy()}
              >
                Sao chép hai công thức
              </button>
            </div>
          </section>
        </div>
      )}

      {tab === "import" && (
        <div className="recipe-operation-grid">
          <section>
            <h3>1. Chọn workbook OPS v1</h3>
            <p className="drawer-guidance">
              Chấp nhận .xlsx với các cột tiếng Việt đã duyệt. Atlas không tự
              tạo nguyên liệu, đơn vị hoặc loại trường còn thiếu.
            </p>
            <input
              aria-label="Workbook công thức .xlsx"
              type="file"
              accept=".xlsx"
              disabled={busy}
              onChange={(event) => void parseWorkbook(event.target.files?.[0])}
            />
            <label className="evidence-field">
              Lý do nhập dữ liệu
              <textarea
                value={importReason}
                onChange={(event) => setImportReason(event.target.value)}
                placeholder="Nêu nguồn và mục đích của lần nhập"
              />
            </label>
          </section>
          <section>
            <h3>2. Xem trước và đối soát</h3>
            {!workbook ? (
              <p className="supporting-copy">
                Chọn tệp để xem số lượng, lỗi cần xử lý và kết quả kiểm tra
                trước khi áp dụng.
              </p>
            ) : (
              <>
                <dl className="master-data-detail-list">
                  <div>
                    <dt>Tệp</dt>
                    <dd>{workbook.fileName}</dd>
                  </div>
                  <div>
                    <dt>Số món</dt>
                    <dd>{workbook.sourceCounts.dishes}</dd>
                  </div>
                  <div>
                    <dt>Số công thức</dt>
                    <dd>{workbook.sourceCounts.recipes}</dd>
                  </div>
                  <div>
                    <dt>Số dòng nguyên liệu</dt>
                    <dd>{workbook.sourceCounts.recipeLines}</dd>
                  </div>
                  <div>
                    <dt>Lỗi cần xử lý</dt>
                    <dd>{workbook.errors.length}</dd>
                  </div>
                  <div>
                    <dt>Kết quả kiểm tra</dt>
                    <dd>
                      {workbook.errors.length
                        ? "Cần sửa lỗi trước khi áp dụng"
                        : "Đã kiểm tra, có thể áp dụng"}
                    </dd>
                  </div>
                </dl>
                <details>
                  <summary>Chi tiết kỹ thuật</summary>
                  <dl className="master-data-detail-list">
                    <div>
                      <dt>Checksum</dt>
                      <dd>
                        <code>{workbook.checksum}</code>
                      </dd>
                    </div>
                    <div>
                      <dt>Cách Atlas lưu dữ liệu</dt>
                      <dd>{workbook.lifecycleInterpretation}</dd>
                    </div>
                  </dl>
                </details>
                {workbook.errors.length > 0 && (
                  <div className="command-outcome danger">
                    <h3>Lỗi chặn áp dụng</h3>
                    <ul className="blocker-list">
                      {workbook.errors.map((error) => (
                        <li key={error}>{error}</li>
                      ))}
                    </ul>
                  </div>
                )}
                {!workbook.errors.length && (
                  <div className="command-outcome ok">
                    <h3>Đủ điều kiện gửi lên Atlas</h3>
                    <p>
                      Backend sẽ kiểm tra lại toàn bộ tham chiếu, ghi mapping có
                      kiểu, đối soát nguồn/đích và áp dụng nguyên tử.
                    </p>
                  </div>
                )}
                <button
                  type="button"
                  disabled={
                    busy ||
                    mutationBlocked ||
                    !api ||
                    Boolean(workbook.errors.length) ||
                    !importReason.trim()
                  }
                  onClick={() => void applyImport()}
                >
                  Áp dụng thành bản nháp
                </button>
              </>
            )}
          </section>
        </div>
      )}

      {dishEditorId && (
        <aside className="master-data-drawer" aria-label="Biểu mẫu món ăn">
          <div className="master-data-detail-heading">
            <div>
              <span>Món ăn</span>
              <h3>Thêm món</h3>
            </div>
            <button
              onClick={() => {
                setDishEditorId(null);
                setNotice(null);
              }}
            >
              ×
            </button>
          </div>
          <div className="master-data-drawer-body master-data-detail-form">
            <label className="evidence-field">
              Tên món
              <input
                value={dishDraft.name}
                onChange={(event) =>
                  setDishDraft((state) => ({
                    ...state,
                    name: event.target.value,
                  }))
                }
              />
            </label>
            <label className="evidence-field">
              Loại món
              <select
                value={dishDraft.dishTypeId}
                onChange={(event) =>
                  setDishDraft((state) => ({
                    ...state,
                    dishTypeId: event.target.value,
                  }))
                }
              >
                <option value="">Chọn Loại món</option>
                {catalogData.dish_types.map((dishType) => (
                  <option
                    value={dishType.dish_type_id}
                    key={dishType.dish_type_id}
                    disabled={dishType.dish_type_status !== "ACTIVE"}
                  >
                    {dishType.dish_type_name}
                    {dishType.dish_type_status === "INACTIVE"
                      ? " — ngừng hoạt động"
                      : ""}
                  </option>
                ))}
              </select>
            </label>
            <label className="evidence-field">
              Nhóm mô tả (không bắt buộc)
              <input
                value={dishDraft.category}
                onChange={(event) =>
                  setDishDraft((state) => ({
                    ...state,
                    category: event.target.value,
                  }))
                }
              />
            </label>
            <label className="evidence-field">
              Ghi chú vận hành (không bắt buộc)
              <textarea
                value={dishDraft.notes}
                onChange={(event) =>
                  setDishDraft((state) => ({
                    ...state,
                    notes: event.target.value,
                  }))
                }
              />
            </label>
            <button
              type="button"
              disabled={busy || mutationBlocked || !api}
              onClick={() => void saveDish()}
            >
              Lưu món ăn
            </button>
          </div>
        </aside>
      )}
    </Panel>
  );
}
