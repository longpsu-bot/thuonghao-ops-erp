import { useEffect, useMemo, useRef, useState } from "react";
import {
  dishRecipeCopyRequest,
  dishRecipeOperatorWorkbenchFromResult,
  emptyRecipeWorkbench,
  recipeCommandRequest,
  recipeWorkbenchFromResult,
  recipeWorkflowCommandRequest,
  reviewRecipeWorkbook,
  type AtlasRpcResult,
  type DishRecipeApi,
  type DishRecipeOperatorWorkbench,
  type DishRecord,
  type JsonValue,
  type RecipeWorkbenchData,
  type RecipeWorkbookReview,
} from "../bridges/dishRecipe";
import { foldVietnameseSearch } from "../foldVietnameseSearch";
import {
  canonicalScopes,
  recipeDraftFor,
  recipePayload,
  sameComposition,
  validRecipeDraft,
  type RecipeDraft,
} from "./recipeDraftModel";

export type DishDraft = {
  name: string;
  typeId: string;
  category: string;
  notes: string;
};
type Context = { dishId: string; schoolTypeId: string; date: string };
export type RecipeTransition =
  | { kind: "select"; dishId: string }
  | { kind: "scope"; schoolTypeId: string }
  | { kind: "date"; date: string }
  | {
      kind:
        | "close"
        | "refresh"
        | "create"
        | "edit"
        | "lifecycle"
        | "copy"
        | "import";
    };
type Authority = {
  catalog: RecipeWorkbenchData;
  effective: DishRecipeOperatorWorkbench | null;
  context: Context | null;
};
type Recovery = {
  context: Context | null;
  verify: (authority: Authority) => Promise<boolean>;
  message: string;
};
type Lock = "unknown" | "stale" | "readback" | null;
const dishDraftFor = (dish?: DishRecord): DishDraft => ({
  name: dish?.dish_name ?? "",
  typeId: dish?.dish_type_id ?? "",
  category: dish?.dish_category ?? "",
  notes: dish?.operational_notes ?? "",
});
const readError =
  "Không tải được dữ liệu công thức chính thức. Hãy tải lại trước khi tiếp tục.";
const unknownMessage =
  "Atlas chưa thể xác nhận lần lưu công thức đã hoàn tất hay chưa.";
const readbackMessage =
  "Đã gửi lệnh lưu nhưng chưa tải lại được công thức chính thức.";
function safeError(result: AtlasRpcResult) {
  if (result.kind === "auth_error")
    return "Phiên làm việc không còn hợp lệ. Vui lòng đăng nhập lại.";
  if (result.kind !== "backend_error")
    return "Chưa thể thực hiện thao tác. Hãy tải lại dữ liệu.";
  const messages: Record<string, string> = {
    CAPABILITY_DENIED: "Bạn không có quyền thực hiện thao tác này.",
    SCOPE_DENIED: "Phạm vi được cấp không cho phép thao tác này.",
    CONFLICT:
      "Tên món hoặc dữ liệu mục tiêu đã tồn tại. Hãy kiểm tra và đổi tên nếu cần.",
    VALIDATION_FAILED:
      "Dữ liệu chưa hợp lệ. Hãy kiểm tra các trường và thử lại.",
    INVARIANT_VIOLATION: "Dữ liệu hiện tại chưa cho phép thao tác này.",
    RECIPE_OPERATIONALLY_LOCKED:
      "Món đã được sử dụng trong vận hành. Thành phần gốc không thể sửa trực tiếp.",
  };
  return (
    messages[result.error.error_code] ??
    "Atlas đã từ chối thao tác. Hãy tải lại dữ liệu hiện tại."
  );
}

export function useDishRecipeWorkbench({
  api,
  authSubject,
  initialDate = new Date().toLocaleDateString("en-CA"),
}: {
  api: DishRecipeApi;
  authSubject: string | null;
  initialDate?: string;
}) {
  const [owner, setOwner] = useState(authSubject);
  const identity = useRef({ subject: authSubject, api, generation: 0 });
  if (identity.current.subject !== authSubject || identity.current.api !== api)
    identity.current = {
      subject: authSubject,
      api,
      generation: identity.current.generation + 1,
    };
  const [authority, setAuthority] = useState<Authority>({
    catalog: emptyRecipeWorkbench(),
    effective: null,
    context: null,
  });
  const [context, setContext] = useState<Context | null>(null);
  const [date, setDate] = useState(initialDate);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const commandBusy = useRef(false);
  const [ready, setReady] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [lock, setLock] = useState<Lock>(null);
  const recovery = useRef<Recovery | null>(null);
  const [recipeDraft, setRecipeDraft] = useState<RecipeDraft | null>(null);
  const [dishDraft, setDishDraft] = useState<DishDraft | null>(null);
  const [surface, setSurface] = useState<
    "create" | "edit" | "lifecycle" | "copy" | "import" | null
  >(null);
  const [review, setReview] = useState(false);
  const [workbook, setWorkbook] = useState<RecipeWorkbookReview | null>(null);
  const [query, setQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [typeFilter, setTypeFilter] = useState("");
  const [discardOpen, setDiscardOpen] = useState(false);
  const pending = useRef<RecipeTransition | null>(null);
  const discardAccepted = useRef(false);
  const correlation = useRef(crypto.randomUUID());
  const sameOwner = owner === authSubject && Boolean(authSubject);
  const catalog = sameOwner ? authority.catalog : emptyRecipeWorkbench();
  const effective = sameOwner && ready ? authority.effective : null;
  const dish = catalog.dishes.find((d) => d.dish_id === context?.dishId);
  const scopes = canonicalScopes(catalog.school_types);
  const isCurrent = (generation: number) =>
    identity.current.subject === authSubject &&
    identity.current.api === api &&
    identity.current.generation === generation;
  const renderGeneration = identity.current.generation;

  async function read(
    selected: Context | null,
    onFailure?: (message: string) => void,
  ): Promise<Authority | null> {
    if (!authSubject) return null;
    try {
      const [baseResult, effectiveResult] = await Promise.all([
        api.getWorkbench(
          authSubject,
          correlation.current,
          selected
            ? { dishId: selected.dishId, schoolTypeId: selected.schoolTypeId }
            : undefined,
        ),
        selected
          ? api.getEffectiveWorkbench(
              authSubject,
              correlation.current,
              selected.date,
              selected.dishId,
              { kind: "system", schoolTypeId: selected.schoolTypeId },
            )
          : Promise.resolve(null),
      ]);
      const base = recipeWorkbenchFromResult(baseResult);
      if (!base) {
        if (
          baseResult.kind === "backend_error" &&
          ["CAPABILITY_DENIED", "SCOPE_DENIED"].includes(
            baseResult.error.error_code,
          )
        )
          onFailure?.(safeError(baseResult));
        return null;
      }
      if (!selected) return { catalog: base, effective: null, context: null };
      const eff =
        effectiveResult &&
        dishRecipeOperatorWorkbenchFromResult(effectiveResult);
      const authoring = eff?.base_authoring,
        fromBase = base.selected_recipe;
      if (
        !eff ||
        !authoring ||
        eff.dish.dish_id !== selected.dishId ||
        eff.school_type_id !== selected.schoolTypeId ||
        eff.as_of_date !== selected.date ||
        eff.context_kind !== "SYSTEM_SCHOOL_TYPE" ||
        eff.school_id !== null ||
        fromBase.dish_id !== selected.dishId ||
        fromBase.school_type_id !== selected.schoolTypeId ||
        fromBase.recipe_id !== authoring.recipe_id ||
        fromBase.recipe_version_id !== authoring.recipe_version_id ||
        fromBase.expected_version !== authoring.expected_version ||
        fromBase.basis_portions !== authoring.basis_portions ||
        !sameComposition(fromBase.composition, authoring.composition)
      )
        return null;
      return { catalog: base, effective: eff, context: selected };
    } catch {
      return null;
    }
  }
  function adopt(next: Authority) {
    setAuthority(next);
    setContext(next.context);
    if (next.context) setDate(next.context.date);
    setRecipeDraft(
      next.effective ? recipeDraftFor(next.effective.base_authoring) : null,
    );
    setDishDraft(null);
    setReview(false);
    setSurface(null);
    setWorkbook(null);
    setReady(true);
    setError(null);
  }
  async function load(selected: Context | null) {
    const generation = ++identity.current.generation;
    setContext(selected);
    setReady(false);
    setLoading(true);
    setError(null);
    setRecipeDraft(null);
    setNotice(null);
    let failure = readError;
    const next = await read(selected, (message) => {
      failure = message;
    });
    if (!isCurrent(generation)) return;
    setLoading(false);
    if (!next) {
      setError(failure);
      return;
    }
    adopt(next);
  }
  useEffect(() => {
    setOwner(authSubject);
    setReady(false);
    setContext(null);
    setDate(initialDate);
    setAuthority({
      catalog: emptyRecipeWorkbench(),
      effective: null,
      context: null,
    });
    setRecipeDraft(null);
    setDishDraft(null);
    setReview(false);
    setSurface(null);
    setWorkbook(null);
    setLock(null);
    setNotice(null);
    setError(null);
    setDiscardOpen(false);
    pending.current = null;
    recovery.current = null;
    commandBusy.current = false;
    setBusy(false);
    if (authSubject) void load(null);
    else {
      setLoading(false);
      setError("Vui lòng đăng nhập để xem công thức.");
    }
    return () => {
      identity.current.generation++;
    };
    // Auth/API identity owns this complete local session. Context reads are explicit.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [authSubject, api]);

  const canCommand = sameOwner && ready && !loading && !busy && !lock;
  const canEdit =
    canCommand &&
    Boolean(
      effective?.editable_state === "EDITABLE_BASE" &&
      effective.is_editable &&
      !effective.is_operationally_locked &&
      !effective.base_authoring.locked_for_normal_editing &&
      effective.base_authoring.allowed_actions.save_recipe &&
      catalog.selected_recipe.allowed_actions.save_recipe &&
      effective.base_authoring.expected_version !== null,
    );
  const dirty =
    sameOwner &&
    ((recipeDraft !== null &&
      authority.effective !== null &&
      JSON.stringify(recipeDraft) !==
        JSON.stringify(recipeDraftFor(authority.effective.base_authoring))) ||
      (dishDraft !== null &&
        JSON.stringify(dishDraft) !==
          JSON.stringify(
            dishDraftFor(surface === "create" ? undefined : dish),
          )));
  const validDraft =
    recipeDraft !== null && validRecipeDraft(recipeDraft, catalog);
  function perform(next: RecipeTransition) {
    setReview(false);
    setSurface(null);
    setDishDraft(null);
    setWorkbook(null);
    setNotice(null);
    if (authority.effective)
      setRecipeDraft(recipeDraftFor(authority.effective.base_authoring));
    if (next.kind === "select") {
      if (scopes[0])
        void load({
          dishId: next.dishId,
          schoolTypeId: scopes[0].school_type_id,
          date,
        });
    } else if (next.kind === "scope" && context)
      void load({ ...context, schoolTypeId: next.schoolTypeId });
    else if (next.kind === "date" && context) {
      setDate(next.date);
      void load({ ...context, date: next.date });
    } else if (next.kind === "close") {
      setContext(null);
      setAuthority({ ...authority, effective: null, context: null });
      setRecipeDraft(null);
    } else if (next.kind === "refresh") void load(context);
    else if (
      ["create", "edit", "lifecycle", "copy", "import"].includes(next.kind)
    ) {
      setSurface(next.kind as typeof surface);
      if (next.kind === "create" || next.kind === "edit")
        setDishDraft(dishDraftFor(next.kind === "edit" ? dish : undefined));
    }
  }
  function transition(next: RecipeTransition) {
    if (!sameOwner || busy || commandBusy.current || lock) return;
    if (dirty) {
      pending.current = next;
      setDiscardOpen(true);
      return;
    }
    perform(next);
  }
  function cancelDiscard() {
    pending.current = null;
    discardAccepted.current = false;
    setDiscardOpen(false);
  }
  function confirmDiscard() {
    discardAccepted.current = true;
    setDiscardOpen(false);
  }
  function completeDiscardTransition() {
    const next = pending.current;
    pending.current = null;
    if (discardAccepted.current && next) perform(next);
    discardAccepted.current = false;
  }

  async function execute(
    invoke: () => Promise<AtlasRpcResult>,
    prepare: (result: AtlasRpcResult) => Recovery,
    message: string,
  ) {
    if (!canCommand || commandBusy.current || !isCurrent(renderGeneration))
      return;
    commandBusy.current = true;
    setBusy(true);
    setNotice(null);
    const generation = identity.current.generation;
    let result: AtlasRpcResult;
    try {
      result = await invoke();
    } catch {
      result = {
        kind: "transport_error",
        diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Unknown" },
      };
    }
    if (!isCurrent(generation)) return;
    if (result.kind === "backend_error") {
      if (
        result.error.error_code === "STALE_VERSION" ||
        result.error.retryable ||
        result.error.error_code === "RETRYABLE_CONCURRENCY_FAILURE"
      ) {
        setLock("stale");
        setNotice(
          "Công thức đã được cập nhật ở nơi khác. Hãy tải lại dữ liệu hiện tại.",
        );
      } else setNotice(safeError(result));
    } else if (result.kind === "auth_error") {
      setReady(false);
      setError(safeError(result));
    } else {
      const plan = prepare(result);
      recovery.current = plan;
      if (result.kind !== "success") {
        setLock("unknown");
        setNotice(unknownMessage);
      } else {
        setReady(false);
        const next = await read(plan.context);
        let matches = false;
        try {
          matches = Boolean(next && (await plan.verify(next)));
        } catch {
          matches = false;
        }
        if (!isCurrent(generation)) return;
        if (next && matches) {
          adopt(next);
          recovery.current = null;
          setLock(null);
          setNotice(message);
        } else {
          setLock("readback");
          setNotice(readbackMessage);
        }
      }
    }
    commandBusy.current = false;
    setBusy(false);
  }
  async function recover() {
    if (!sameOwner || busy || commandBusy.current) return;
    if (!lock || lock === "stale") {
      setLock(null);
      recovery.current = null;
      await load(context);
      return;
    }
    const plan = recovery.current;
    if (!plan) return;
    const generation = ++identity.current.generation;
    setLoading(true);
    setReady(false);
    const next = await read(plan.context);
    let matches = false;
    try {
      matches = Boolean(next && (await plan.verify(next)));
    } catch {
      matches = false;
    }
    if (!isCurrent(generation)) return;
    setLoading(false);
    if (next && matches) {
      adopt(next);
      recovery.current = null;
      setLock(null);
      setNotice(plan.message);
    } else
      setNotice(
        "Chưa xác nhận được kết quả chính thức. Không gửi lại lệnh; hãy tải lại để xác nhận.",
      );
  }
  function reviewRecipe() {
    if (canEdit && validDraft) setReview(true);
  }
  async function saveRecipe() {
    if (
      !canEdit ||
      !validDraft ||
      !review ||
      !context ||
      !effective ||
      !recipeDraft
    )
      return;
    const payload = recipePayload(effective.base_authoring, recipeDraft);
    const request = recipeWorkflowCommandRequest(
      authSubject!,
      correlation.current,
      effective.base_authoring.expected_version!,
      "save",
      payload,
    );
    const message = "Đã lưu công thức · Sẵn sàng cho Lập nhu cầu";
    await execute(
      () => api.saveRecipe(request),
      () => ({
        context,
        message,
        verify: async (next) =>
          Boolean(
            next.effective?.base_authoring.business_status === "AVAILABLE" &&
            next.effective.base_authoring.basis_portions ===
              payload.basis_portions &&
            sameComposition(
              next.effective.base_authoring.composition.filter(
                (l) => l.line_disposition === "PRESENT",
              ),
              payload.lines,
            ),
          ),
      }),
      message,
    );
  }
  const dishValid = Boolean(
    dishDraft?.name.trim() &&
    catalog.dish_types.some(
      (t) =>
        t.dish_type_id === dishDraft.typeId && t.dish_type_status === "ACTIVE",
    ),
  );
  async function saveDish() {
    if (
      !canCommand ||
      !dishDraft ||
      !dishValid ||
      (surface !== "create" && surface !== "edit")
    )
      return;
    const creating = surface === "create";
    if (!creating && !dish) return;
    const payload: Record<string, JsonValue> = {
      dish_name: dishDraft.name.trim(),
      dish_type_id: dishDraft.typeId,
      dish_category: dishDraft.category.trim() || null,
      operational_notes: dishDraft.notes.trim() || null,
      ...(!creating && dish
        ? {
            dish_id: dish.dish_id,
            dish_code: dish.dish_code,
            display_order: dish.display_order,
            requires_need_generation: dish.requires_need_generation,
          }
        : {}),
    };
    const request = recipeCommandRequest(
      authSubject!,
      correlation.current,
      creating ? 1 : dish!.version,
      creating ? "DISH_CREATE" : "DISH_UPDATE",
      payload,
    );
    const message = creating
      ? "Đã tạo món. Chọn loại công thức để nhập thành phần."
      : "Đã lưu thông tin món.";
    await execute(
      () => (creating ? api.createDish(request) : api.updateDish(request)),
      (result) => {
        const id =
          result.kind === "success"
            ? result.response.affected_aggregate_ids?.dish_id
            : creating
              ? undefined
              : dish?.dish_id;
        return {
          context:
            typeof id === "string" && scopes[0]
              ? {
                  dishId: id,
                  schoolTypeId:
                    context?.schoolTypeId ?? scopes[0].school_type_id,
                  date,
                }
              : null,
          message,
          verify: async (next) => {
            const item = next.catalog.dishes.find((d) => d.dish_id === id);
            return Boolean(
              item &&
              item.dish_name === payload.dish_name &&
              item.dish_type_id === payload.dish_type_id &&
              (item.dish_category || null) === payload.dish_category &&
              (item.operational_notes || null) === payload.operational_notes &&
              (creating
                ? item.dish_status === "ACTIVE" &&
                  canonicalScopes(next.catalog.school_types).length === 2 &&
                  canonicalScopes(next.catalog.school_types).every(
                    (s) =>
                      next.catalog.recipes.filter(
                        (r) =>
                          r.dish_id === id &&
                          r.school_type_id === s.school_type_id &&
                          r.recipe_status === "ACTIVE",
                      ).length === 1,
                  )
                : item.dish_code === dish!.dish_code &&
                  item.version > request.expected_version),
            );
          },
        };
      },
      message,
    );
  }
  async function setLifecycle() {
    if (!canCommand || !dish || surface !== "lifecycle") return;
    const target = dish.dish_status === "ACTIVE" ? "INACTIVE" : "ACTIVE";
    const request = recipeCommandRequest(
      authSubject!,
      correlation.current,
      dish.version,
      "DISH_LIFECYCLE",
      { dish_id: dish.dish_id, dish_status: target },
    );
    const message =
      target === "ACTIVE"
        ? "Đã kích hoạt món."
        : "Đã ngừng dùng món; lịch sử được giữ nguyên.";
    await execute(
      () => api.setDishLifecycle(request),
      () => ({
        context,
        message,
        verify: async (next) =>
          next.catalog.dishes.some(
            (d) =>
              d.dish_id === dish.dish_id &&
              d.dish_status === target &&
              d.version > dish.version,
          ),
      }),
      message,
    );
  }
  const canCopy =
    canCommand &&
    Boolean(effective?.allowed_actions.includes("COPY_DISH_RECIPES"));
  async function copyRecipes(
    sourceId: string,
    snapshotDate: string,
    reason: string,
  ) {
    if (
      !canCopy ||
      !dish ||
      !context ||
      surface !== "copy" ||
      sourceId === dish.dish_id ||
      !catalog.dishes.some((d) => d.dish_id === sourceId) ||
      !/^\d{4}-\d{2}-\d{2}$/.test(snapshotDate) ||
      !reason.trim()
    )
      return;
    const commandId = crypto.randomUUID();
    const request = dishRecipeCopyRequest({
      authSubject: authSubject!,
      correlationId: correlation.current,
      commandId,
      idempotencyKey: `copy-dish-recipes:${commandId}`,
      requestedAt: new Date().toISOString(),
      expectedVersion: dish.version,
      reasonCode: "COPY_DISH_RECIPES",
      reasonNote: reason.trim(),
      sourceDishId: sourceId,
      targetDishId: dish.dish_id,
      asOfDate: snapshotDate,
    });
    const message =
      "Đã sao chép. Xem lại và lưu từng loại công thức trước khi dùng cho Lập nhu cầu.";
    await execute(
      () => api.copyDishRecipes(request),
      () => ({
        context,
        message,
        verify: async (next) => {
          const types = canonicalScopes(next.catalog.school_types);
          if (types.length !== 2) return false;
          const checks = await Promise.all(
            types.map(async (type) => {
              const root = next.catalog.recipes.find(
                (r) =>
                  r.dish_id === dish.dish_id &&
                  r.school_type_id === type.school_type_id &&
                  r.recipe_status === "ACTIVE",
              );
              const matches = next.catalog.recipe_versions.filter(
                (v) =>
                  v.recipe_id === root?.recipe_id &&
                  v.recipe_version_status === "DRAFT" &&
                  v.source_evidence.source_kind === "RECIPE_EFFECTIVE_COPY" &&
                  v.source_evidence.outer_command_id === request.command_id &&
                  v.source_evidence.source_dish_id === sourceId &&
                  v.source_evidence.copy_as_of_date === snapshotDate,
              );
              if (matches.length !== 1) return false;
              const scope = await read({
                dishId: dish.dish_id,
                schoolTypeId: type.school_type_id,
                date: snapshotDate,
              });
              return (
                scope?.effective?.base_authoring.recipe_version_id ===
                  matches[0].recipe_version_id &&
                scope.effective.base_authoring.business_status === "SAVED"
              );
            }),
          );
          return checks.every(Boolean);
        },
      }),
      message,
    );
  }
  async function parseWorkbook(file: File) {
    if (!canCommand || surface !== "import") return;
    const generation = identity.current.generation;
    setBusy(true);
    commandBusy.current = true;
    setWorkbook(null);
    try {
      const parsed = await reviewRecipeWorkbook(file, {
        schoolTypes: catalog.school_types,
        ingredients: catalog.ingredients,
        units: catalog.units,
      });
      if (isCurrent(generation)) setWorkbook(parsed);
    } catch {
      if (isCurrent(generation)) setNotice("Không thể đọc tệp workbook này.");
    } finally {
      if (isCurrent(generation)) {
        setBusy(false);
        commandBusy.current = false;
      }
    }
  }
  async function applyImport(reason: string) {
    if (
      !canCommand ||
      surface !== "import" ||
      !workbook ||
      workbook.errors.length ||
      !workbook.rows.length ||
      !reason.trim()
    )
      return;
    const request = recipeCommandRequest(
      authSubject!,
      correlation.current,
      1,
      "RECIPE_WORKBOOK_IMPORT",
      {
        canonical_json: workbook.canonicalJson,
        workbook_checksum: workbook.checksum,
      },
      reason.trim(),
    );
    const message =
      "Đã nhập workbook và tải lại dữ liệu. Xem lại các công thức đã nhập trước khi dùng cho Lập nhu cầu.";
    await execute(
      () => api.applyImport(request),
      () => ({
        context,
        message,
        verify: async (next) =>
          [...new Set(workbook.rows.map((row) => row.recipe_legacy_id))].every(
            (legacyId) => {
              const rows = workbook.rows.filter(
                (row) => row.recipe_legacy_id === legacyId,
              );
              const versions = next.catalog.recipe_versions.filter(
                (version) =>
                  version.source_evidence.source_kind === "WORKBOOK_IMPORT" &&
                  version.source_evidence.workbook_checksum ===
                    workbook.checksum &&
                  version.source_evidence.recipe_legacy_id === legacyId,
              );
              if (versions.length !== 1) return false;
              const version = versions[0],
                root = next.catalog.recipes.find(
                  (recipe) => recipe.recipe_id === version.recipe_id,
                );
              if (
                !root ||
                root.school_type_id !== rows[0].school_type_id ||
                !next.catalog.dishes.some(
                  (dish) =>
                    dish.dish_id === root.dish_id &&
                    dish.dish_name === rows[0].dish_name,
                ) ||
                version.basis_portions !== rows[0].basis_portions
              )
                return false;
              const facts = (
                lines: {
                  ingredient_id: string;
                  quantity_per_basis: number;
                  unit_id: string;
                  operational_note: string | null;
                }[],
              ) =>
                lines
                  .map((line) => [
                    line.ingredient_id,
                    String(line.quantity_per_basis),
                    line.unit_id,
                    line.operational_note?.trim() || null,
                  ])
                  .sort((a, b) => String(a[0]).localeCompare(String(b[0])));
              return (
                JSON.stringify(
                  facts(
                    version.composition.filter(
                      (line) => line.line_disposition === "PRESENT",
                    ),
                  ),
                ) === JSON.stringify(facts(rows))
              );
            },
          ),
      }),
      message,
    );
  }
  const visibleDishes = useMemo(() => {
    const term = foldVietnameseSearch(query);
    return catalog.dishes.filter((d) => {
      const roots = new Set(
        catalog.recipes
          .filter((r) => r.dish_id === d.dish_id)
          .map((r) => r.recipe_id),
      );
      const ingredients = new Set(
        catalog.recipe_versions
          .filter((v) => roots.has(v.recipe_id))
          .flatMap((v) =>
            v.composition
              .filter((l) => l.line_disposition === "PRESENT")
              .map((l) => l.ingredient_id),
          ),
      );
      return (
        (statusFilter === "ALL" || d.dish_status === statusFilter) &&
        (!typeFilter || d.dish_type_id === typeFilter) &&
        foldVietnameseSearch(
          [
            d.dish_name,
            d.dish_category,
            d.dish_type_name,
            ...catalog.ingredients
              .filter((i) => ingredients.has(i.ingredient_id))
              .map((i) => i.ingredient_name),
          ].join(" "),
        ).includes(term)
      );
    });
  }, [catalog, query, statusFilter, typeFilter]);
  return {
    catalog,
    effective,
    dish,
    scopes,
    context: sameOwner ? context : null,
    date,
    loading,
    busy,
    error,
    notice,
    lock,
    canCommand,
    canEdit,
    canCopy,
    dirty,
    validDraft,
    dishValid,
    recipeDraft: sameOwner ? recipeDraft : null,
    dishDraft: sameOwner ? dishDraft : null,
    surface: sameOwner ? surface : null,
    review: sameOwner && review,
    reviewBase: sameOwner ? authority.effective?.base_authoring : undefined,
    workbook: sameOwner ? workbook : null,
    query,
    setQuery,
    statusFilter,
    setStatusFilter,
    typeFilter,
    setTypeFilter,
    visibleDishes,
    setRecipeDraft: (draft: RecipeDraft) => {
      if (canEdit && !review) setRecipeDraft(draft);
    },
    setDishDraft: (draft: DishDraft) => {
      if (canCommand) setDishDraft(draft);
    },
    transition,
    discardOpen: sameOwner && discardOpen,
    cancelDiscard,
    confirmDiscard,
    completeDiscardTransition,
    reviewRecipe,
    backToRecipe: () => {
      if (!busy && !lock) setReview(false);
    },
    saveRecipe,
    saveDish,
    setLifecycle,
    copyRecipes,
    parseWorkbook,
    applyImport,
    recover,
    refreshDisabled: !canCommand || dirty || review || surface !== null,
  };
}
export type DishRecipeController = ReturnType<typeof useDishRecipeWorkbench>;
