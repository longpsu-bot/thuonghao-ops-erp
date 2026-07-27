import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { AtlasAuthState } from "../atlas/connection/authSession";
import type { JsonValue } from "../atlas/connection/atlasRpc";
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
  type EffectiveCompositionResult,
  type RecipeAdjustmentAction,
  type RecipeAdjustmentPreview,
  type RecipeAdjustmentRecord,
  type RecipeAdjustmentScope,
  type RecipeAdjustmentWorkbenchData,
} from "../atlas/recipe-adjustments/recipeAdjustmentModel";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";

type LoadState = {
  status: "idle" | "loading" | "ready" | "error";
  data: RecipeAdjustmentWorkbenchData;
  message?: string;
};

type RuleDraft = {
  scope: RecipeAdjustmentScope;
  action: RecipeAdjustmentAction;
  schoolId: string;
  dishId: string;
  schoolTypeId: string;
  targetIngredientId: string;
  targetRecipeLineId: string;
  substituteIngredientId: string;
  quantity: string;
  unitId: string;
  effectiveFrom: string;
  effectiveTo: string;
  reason: string;
};

const ACTIONS: Record<RecipeAdjustmentScope, RecipeAdjustmentAction[]> = {
  SYSTEM_INGREDIENT: ["REPLACE"],
  SYSTEM_DISH: ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"],
  SCHOOL: ["REPLACE", "REMOVE"],
  SCHOOL_DISH: ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"],
};

const scopeLabel: Record<RecipeAdjustmentScope, string> = {
  SYSTEM_INGREDIENT: "Toàn hệ thống · Nguyên liệu",
  SYSTEM_DISH: "Toàn hệ thống · Món ăn",
  SCHOOL: "Một trường · Mọi món",
  SCHOOL_DISH: "Một trường · Một món",
};
const actionLabel: Record<RecipeAdjustmentAction, string> = {
  ADD: "Thêm",
  REPLACE: "Thay thế",
  ADJUST_QUANTITY: "Điều chỉnh định lượng",
  REMOVE: "Loại bỏ",
};
const layerLabel: Record<string, string> = {
  RELEASED_RECIPE_VERSION: "BOM phát hành",
  SYSTEM_INGREDIENT: "Hệ thống · Nguyên liệu",
  SYSTEM_DISH: "Hệ thống · Món",
  SCHOOL: "Trường",
  SCHOOL_DISH: "Trường · Món",
};

const today = () => new Date().toISOString().slice(0, 10);
const emptyDraft = (): RuleDraft => ({
  scope: "SYSTEM_DISH",
  action: "ADD",
  schoolId: "",
  dishId: "",
  schoolTypeId: "",
  targetIngredientId: "",
  targetRecipeLineId: "",
  substituteIngredientId: "",
  quantity: "",
  unitId: "",
  effectiveFrom: today(),
  effectiveTo: "",
  reason: "",
});

function referenceLabel(
  records: RecipeAdjustmentWorkbenchData["ingredients"],
  id: string | null,
  idKey: "school_id" | "dish_id" | "ingredient_id" | "unit_id",
  nameKey: "school_name" | "dish_name" | "ingredient_name" | "unit_name",
) {
  if (!id) return "—";
  return (
    records.find((record) => record[idKey] === id)?.[nameKey]?.toString() ?? id
  );
}

function sourceTone(source: string) {
  if (source === "SCHOOL_DISH") return "danger" as const;
  if (source === "SCHOOL") return "warning" as const;
  if (source === "RELEASED_RECIPE_VERSION") return "neutral" as const;
  return "ok" as const;
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
  const [load, setLoad] = useState<LoadState>({
    status: "idle",
    data: emptyRecipeAdjustmentWorkbench(),
  });
  const [draft, setDraft] = useState<RuleDraft>(emptyDraft);
  const [previewIds, setPreviewIds] = useState<{
    adjustmentId: string;
    revisionId: string;
    adjustmentLineId: string;
  }>(() => ({
    adjustmentId: crypto.randomUUID(),
    revisionId: crypto.randomUUID(),
    adjustmentLineId: crypto.randomUUID(),
  }));
  const [editing, setEditing] = useState<RecipeAdjustmentRecord | null>(null);
  const [preview, setPreview] = useState<RecipeAdjustmentPreview | null>(null);
  const [resolution, setResolution] =
    useState<EffectiveCompositionResult | null>(null);
  const [filterScope, setFilterScope] = useState("");
  const [filterLifecycle, setFilterLifecycle] = useState("");
  const [filterDate, setFilterDate] = useState(today());
  const [query, setQuery] = useState("");
  const [contextSchoolId, setContextSchoolId] = useState("");
  const [contextDishId, setContextDishId] = useState("");
  const [contextDate, setContextDate] = useState(today());
  const [reviewScenario, setReviewScenario] = useState("precedence");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const generation = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;

  const refresh = useCallback(async () => {
    if (!api || !authSubject) return false;
    const current = ++generation.current;
    setLoad((state) => ({ ...state, status: "loading", message: undefined }));
    const result = await api.getWorkbench(authSubject, correlationId);
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
    const firstSchool = data.schools.find(
      (school) => school.school_status === "ACTIVE",
    );
    const firstDish = data.dishes.find(
      (dish) => dish.dish_status === "ACTIVE" && dish.requires_need_generation,
    );
    setContextSchoolId((value) => value || firstSchool?.school_id || "");
    setContextDishId((value) => value || firstDish?.dish_id || "");
    setDraft((value) => ({
      ...value,
      schoolId: value.schoolId || firstSchool?.school_id || "",
      dishId: value.dishId || firstDish?.dish_id || "",
    }));
    return true;
  }, [api, authSubject, correlationId]);

  useEffect(() => {
    if (authSubject && api) void refresh();
  }, [api, authSubject, refresh]);

  const filteredRules = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase("vi");
    return load.data.adjustments.filter((rule) => {
      const current = rule.revisions.find(
        (revision) => revision.revision_id === rule.current_revision_id,
      );
      const effective =
        !filterDate ||
        (!!current &&
          current.effective_from <= filterDate &&
          (!current.effective_to || filterDate < current.effective_to));
      const haystack = [
        referenceLabel(
          load.data.schools,
          rule.school_id,
          "school_id",
          "school_name",
        ),
        referenceLabel(load.data.dishes, rule.dish_id, "dish_id", "dish_name"),
        referenceLabel(
          load.data.ingredients,
          rule.target_ingredient_id,
          "ingredient_id",
          "ingredient_name",
        ),
        current?.reason_note ?? "",
      ]
        .join(" ")
        .toLocaleLowerCase("vi");
      return (
        (!filterScope || rule.scope_kind === filterScope) &&
        (!filterLifecycle || rule.lifecycle_status === filterLifecycle) &&
        effective &&
        (!normalized || haystack.includes(normalized))
      );
    });
  }, [filterDate, filterLifecycle, filterScope, load.data, query]);

  const lineOptions = useMemo(
    () =>
      load.data.recipe_lines.filter(
        (line) => !draft.dishId || line.dish_id === draft.dishId,
      ),
    [draft.dishId, load.data.recipe_lines],
  );

  function changeScope(scope: RecipeAdjustmentScope) {
    setPreview(null);
    setEditing(null);
    setDraft((value) => ({
      ...value,
      scope,
      action: ACTIONS[scope][0],
      schoolTypeId: "",
      targetIngredientId: "",
      targetRecipeLineId: "",
      substituteIngredientId: "",
      quantity: "",
      unitId: "",
    }));
    setPreviewIds({
      adjustmentId: crypto.randomUUID(),
      revisionId: crypto.randomUUID(),
      adjustmentLineId: crypto.randomUUID(),
    });
  }

  function proposal(): Record<string, JsonValue> {
    const isAdd = draft.action === "ADD";
    const ingredientTarget =
      draft.scope === "SYSTEM_INGREDIENT" || draft.scope === "SCHOOL" || isAdd;
    return {
      adjustment_id: editing?.adjustment_id ?? previewIds.adjustmentId,
      revision_id: previewIds.revisionId,
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
        ? (editing?.adjustment_line_id ?? previewIds.adjustmentLineId)
        : null,
      substitute_ingredient_id:
        draft.action === "REPLACE" ? draft.substituteIngredientId : null,
      quantity_per_basis:
        ["ADD", "ADJUST_QUANTITY"].includes(draft.action) ||
        (draft.action === "REPLACE" && draft.quantity)
          ? Number(draft.quantity)
          : null,
      unit_id:
        draft.action === "ADD" || (draft.action === "REPLACE" && draft.quantity)
          ? draft.unitId
          : null,
      effective_from: draft.effectiveFrom,
      effective_to: draft.effectiveTo || null,
      reason_code: editing ? "RULE_CORRECTION" : "OPERATOR_RULE",
      reason_note: draft.reason,
      source_evidence: { source_kind: "ATLAS_OPERATOR" },
    };
  }

  async function runPreview() {
    if (!api || !authSubject || !contextSchoolId || !contextDishId) return;
    setBusy(true);
    setNotice("");
    const result = await api.preview(authSubject, correlationId, {
      as_of_date: contextDate,
      school_id: contextSchoolId,
      dish_id: contextDishId,
      replaces_adjustment_id: editing?.adjustment_id ?? null,
      proposed_adjustment: proposal(),
    });
    const parsed = adjustmentPreviewFromResult(result);
    setPreview(parsed);
    setNotice(adjustmentResultMessage(result));
    setBusy(false);
  }

  async function saveRule() {
    if (!api || !authSubject || !preview?.can_save) return;
    if (
      !window.confirm(
        editing
          ? "Xác nhận tạo phiên bản kế nhiệm từ đúng kết quả xem trước?"
          : "Xác nhận lưu quy tắc từ đúng kết quả xem trước?",
      )
    )
      return;
    setBusy(true);
    const payload = {
      ...proposal(),
      as_of_date: contextDate,
      preview_school_id: contextSchoolId,
      preview_dish_id: contextDishId,
      predecessor_revision_id: editing?.current_revision_id ?? null,
    };
    const request = recipeAdjustmentCommandRequest(
      authSubject,
      correlationId,
      editing?.version ?? 1,
      editing ? "RULE_CORRECTION" : "OPERATOR_RULE",
      draft.reason,
      payload,
    );
    const result = editing
      ? await api.supersede(request)
      : await api.create(request);
    setNotice(adjustmentResultMessage(result));
    if (result.kind === "success") {
      setPreview(null);
      setEditing(null);
      setDraft(emptyDraft());
      setPreviewIds({
        adjustmentId: crypto.randomUUID(),
        revisionId: crypto.randomUUID(),
        adjustmentLineId: crypto.randomUUID(),
      });
      await refresh();
    }
    setBusy(false);
  }

  function editRule(rule: RecipeAdjustmentRecord) {
    const current = rule.revisions.find(
      (revision) => revision.revision_id === rule.current_revision_id,
    );
    if (!current) return;
    setEditing(rule);
    setPreview(null);
    setPreviewIds({
      adjustmentId: rule.adjustment_id,
      revisionId: crypto.randomUUID(),
      adjustmentLineId: rule.adjustment_line_id ?? crypto.randomUUID(),
    });
    setDraft({
      scope: rule.scope_kind,
      action: rule.action_kind,
      schoolId: rule.school_id ?? "",
      dishId: rule.dish_id ?? "",
      schoolTypeId: rule.school_type_id ?? "",
      targetIngredientId: rule.target_ingredient_id ?? "",
      targetRecipeLineId: rule.target_recipe_line_id ?? "",
      substituteIngredientId: current.substitute_ingredient_id ?? "",
      quantity: current.quantity_per_basis?.toString() ?? "",
      unitId: current.unit_id ?? "",
      effectiveFrom: current.effective_from,
      effectiveTo: current.effective_to ?? "",
      reason: "",
    });
  }

  async function cancelRule(rule: RecipeAdjustmentRecord) {
    if (!api || !authSubject) return;
    const reason = window.prompt(
      "Nhập lý do hủy quy tắc. Lịch sử sẽ được giữ nguyên.",
    );
    if (!reason?.trim()) return;
    if (!window.confirm("Xác nhận hủy quy tắc, không xóa lịch sử?")) return;
    setBusy(true);
    const result = await api.cancel(
      recipeAdjustmentCommandRequest(
        authSubject,
        correlationId,
        rule.version,
        "RULE_CANCELLATION",
        reason.trim(),
        {
          adjustment_id: rule.adjustment_id,
          predecessor_revision_id: rule.current_revision_id,
          revision_id: crypto.randomUUID(),
          effective_from: contextDate,
        },
      ),
    );
    setNotice(adjustmentResultMessage(result));
    if (result.kind === "success") await refresh();
    setBusy(false);
  }

  async function resolve() {
    if (!api || !authSubject || !contextSchoolId || !contextDishId) return;
    setBusy(true);
    setNotice("");
    const result = await api.resolve(authSubject, correlationId, {
      as_of_date: contextDate,
      school_id: contextSchoolId,
      dish_id: contextDishId,
      review_scenario: mode === "review" ? reviewScenario : null,
    });
    setResolution(effectiveCompositionFromResult(result));
    setNotice(adjustmentResultMessage(result));
    setBusy(false);
  }

  async function copyAudit() {
    if (!resolution) return;
    await navigator.clipboard?.writeText(JSON.stringify(resolution, null, 2));
    setNotice("Đã sao chép chi tiết kiểm toán BOM hiệu lực.");
  }

  if (authState.status !== "authenticated")
    return (
      <Panel
        title={view === "rules" ? "Quy tắc điều chỉnh" : "BOM hiệu lực"}
        description="Dữ liệu có thẩm quyền yêu cầu phiên Atlas hợp lệ."
      >
        <p className="operator-notice warning">
          Phiên làm việc đã mất. Vui lòng đăng nhập lại.
        </p>
      </Panel>
    );

  if (!api)
    return (
      <Panel title={view === "rules" ? "Quy tắc điều chỉnh" : "BOM hiệu lực"}>
        <p className="operator-notice warning">
          Kết nối Atlas chưa sẵn sàng. Có thể thử lại an toàn sau khi cấu hình.
        </p>
      </Panel>
    );

  return (
    <Panel
      title={view === "rules" ? "Quy tắc điều chỉnh" : "BOM hiệu lực"}
      description={
        view === "rules"
          ? "Một mô hình đóng cho bốn phạm vi, xem trước cùng bộ giải có thẩm quyền, sửa bằng kế nhiệm và không xóa cứng."
          : "So sánh BOM phát hành với thành phần hiệu lực theo đúng ngày, Trường và Món ăn."
      }
      status={
        mode === "review" ? (
          <Chip tone="warning">Dữ liệu xem thử · không lưu</Chip>
        ) : (
          <Chip tone="ok">Đã kết nối</Chip>
        )
      }
    >
      {load.status === "loading" && (
        <p className="operator-notice">Đang tải quy tắc điều chỉnh…</p>
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

      <div className="adjustment-context-bar">
        <label>
          Ngày hiệu lực
          <input
            type="date"
            value={contextDate}
            onChange={(event) => setContextDate(event.target.value)}
          />
        </label>
        <label>
          Trường
          <select
            value={contextSchoolId}
            onChange={(event) => {
              setContextSchoolId(event.target.value);
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
          Món ăn
          <select
            value={contextDishId}
            onChange={(event) => {
              setContextDishId(event.target.value);
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
        {mode === "review" && view === "effective" && (
          <label>
            Tình huống kiểm tra
            <select
              value={reviewScenario}
              onChange={(event) => setReviewScenario(event.target.value)}
            >
              <option value="precedence">Đủ năm lớp ưu tiên</option>
              <option value="replacement_chain">Chuỗi thay thế</option>
              <option value="removed">Dòng đã loại bỏ</option>
              <option value="duplicate">Chặn trùng nguyên liệu</option>
              <option value="cycle">Chặn chu trình</option>
            </select>
          </label>
        )}
      </div>

      {view === "rules" ? (
        <div className="adjustment-workbench-layout">
          <section className="adjustment-rule-list">
            <div className="adjustment-filter-grid">
              <label>
                Phạm vi
                <select
                  value={filterScope}
                  onChange={(event) => setFilterScope(event.target.value)}
                >
                  <option value="">Tất cả</option>
                  {Object.entries(scopeLabel).map(([value, label]) => (
                    <option key={value} value={value}>
                      {label}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Vòng đời
                <select
                  value={filterLifecycle}
                  onChange={(event) => setFilterLifecycle(event.target.value)}
                >
                  <option value="">Tất cả</option>
                  <option value="ACTIVE">Đang hiệu lực</option>
                  <option value="SUPERSEDED">Đã thay thế</option>
                  <option value="CANCELLED">Đã hủy</option>
                </select>
              </label>
              <label>
                Ngày lọc
                <input
                  type="date"
                  value={filterDate}
                  onChange={(event) => setFilterDate(event.target.value)}
                />
              </label>
              <label>
                Tìm trường, món hoặc nguyên liệu
                <input
                  value={query}
                  onChange={(event) => setQuery(event.target.value)}
                />
              </label>
            </div>
            {load.status === "ready" && filteredRules.length === 0 && (
              <p className="operator-notice">Chưa có quy tắc phù hợp bộ lọc.</p>
            )}
            {filteredRules.map((rule) => {
              const current = rule.revisions.find(
                (revision) => revision.revision_id === rule.current_revision_id,
              );
              return (
                <article
                  className="adjustment-rule-card"
                  key={rule.adjustment_id}
                >
                  <header>
                    <div>
                      <Chip
                        tone={
                          rule.lifecycle_status === "ACTIVE" ? "ok" : "warning"
                        }
                      >
                        {rule.lifecycle_status === "ACTIVE"
                          ? "Đang hiệu lực"
                          : rule.lifecycle_status === "CANCELLED"
                            ? "Đã hủy"
                            : "Đã thay thế"}
                      </Chip>
                      <strong>{scopeLabel[rule.scope_kind]}</strong>
                      <span>{actionLabel[rule.action_kind]}</span>
                    </div>
                    {rule.lifecycle_status === "ACTIVE" && (
                      <div className="table-actions">
                        <button type="button" onClick={() => editRule(rule)}>
                          Tạo bản kế nhiệm
                        </button>
                        <button
                          type="button"
                          disabled={busy}
                          onClick={() => void cancelRule(rule)}
                        >
                          Hủy
                        </button>
                      </div>
                    )}
                  </header>
                  <p>
                    {referenceLabel(
                      load.data.schools,
                      rule.school_id,
                      "school_id",
                      "school_name",
                    )}{" "}
                    ·{" "}
                    {referenceLabel(
                      load.data.dishes,
                      rule.dish_id,
                      "dish_id",
                      "dish_name",
                    )}{" "}
                    ·{" "}
                    {referenceLabel(
                      load.data.ingredients,
                      rule.target_ingredient_id,
                      "ingredient_id",
                      "ingredient_name",
                    )}
                  </p>
                  <small>
                    {current?.effective_from} →{" "}
                    {current?.effective_to ?? "không giới hạn"} ·{" "}
                    {current?.created_by_actor_name} · {current?.reason_note}
                  </small>
                  <details>
                    <summary>
                      {rule.revisions.length} phiên bản và quan hệ kế nhiệm
                    </summary>
                    <ol>
                      {rule.revisions.map((revision) => (
                        <li key={revision.revision_id}>
                          v{revision.revision_number} ·{" "}
                          {revision.lifecycle_status} ·{" "}
                          {revision.predecessor_revision_id
                            ? "có tiền nhiệm trực tiếp"
                            : "phiên bản đầu"}{" "}
                          · {revision.reason_note}
                        </li>
                      ))}
                    </ol>
                  </details>
                </article>
              );
            })}
          </section>

          <aside className="adjustment-rule-editor">
            <h3>{editing ? "Tạo phiên bản kế nhiệm" : "Tạo quy tắc mới"}</h3>
            <label>
              Phạm vi
              <select
                value={draft.scope}
                disabled={!!editing}
                onChange={(event) =>
                  changeScope(event.target.value as RecipeAdjustmentScope)
                }
              >
                {Object.entries(scopeLabel).map(([value, label]) => (
                  <option key={value} value={value}>
                    {label}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Hành động
              <select
                value={draft.action}
                disabled={!!editing}
                onChange={(event) => {
                  setPreview(null);
                  setDraft((value) => ({
                    ...value,
                    action: event.target.value as RecipeAdjustmentAction,
                    targetIngredientId: "",
                    targetRecipeLineId: "",
                    substituteIngredientId: "",
                    quantity: "",
                    unitId: "",
                  }));
                }}
              >
                {ACTIONS[draft.scope].map((action) => (
                  <option key={action} value={action}>
                    {actionLabel[action]}
                  </option>
                ))}
              </select>
            </label>
            {(draft.scope === "SCHOOL" || draft.scope === "SCHOOL_DISH") && (
              <label>
                Trường áp dụng
                <select
                  value={draft.schoolId}
                  disabled={!!editing}
                  onChange={(event) =>
                    setDraft((value) => ({
                      ...value,
                      schoolId: event.target.value,
                    }))
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
            {(draft.scope === "SYSTEM_DISH" ||
              draft.scope === "SCHOOL_DISH") && (
              <label>
                Món áp dụng
                <select
                  value={draft.dishId}
                  disabled={!!editing}
                  onChange={(event) =>
                    setDraft((value) => ({
                      ...value,
                      dishId: event.target.value,
                      targetRecipeLineId: "",
                    }))
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
                Giới hạn loại trường (không bắt buộc)
                <select
                  value={draft.schoolTypeId}
                  disabled={!!editing}
                  onChange={(event) =>
                    setDraft((value) => ({
                      ...value,
                      schoolTypeId: event.target.value,
                    }))
                  }
                >
                  <option value="">Mọi loại trường</option>
                  {load.data.school_types.map((schoolType) => (
                    <option
                      key={schoolType.school_type_id ?? "school-type"}
                      value={schoolType.school_type_id ?? ""}
                    >
                      {schoolType.school_type_name ?? schoolType.school_type_id}
                    </option>
                  ))}
                </select>
              </label>
            )}
            {(draft.scope === "SYSTEM_INGREDIENT" ||
              draft.scope === "SCHOOL" ||
              draft.action === "ADD") && (
              <label>
                {draft.action === "ADD"
                  ? "Nguyên liệu thêm"
                  : "Nguyên liệu mục tiêu"}
                <select
                  value={draft.targetIngredientId}
                  disabled={!!editing}
                  onChange={(event) =>
                    setDraft((value) => ({
                      ...value,
                      targetIngredientId: event.target.value,
                    }))
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
            {(draft.scope === "SYSTEM_DISH" || draft.scope === "SCHOOL_DISH") &&
              draft.action !== "ADD" && (
                <label>
                  Dòng công thức ổn định
                  <select
                    value={draft.targetRecipeLineId}
                    disabled={!!editing}
                    onChange={(event) =>
                      setDraft((value) => ({
                        ...value,
                        targetRecipeLineId: event.target.value,
                      }))
                    }
                  >
                    <option value="">Chọn RecipeLine</option>
                    {lineOptions.map((line) => (
                      <option
                        key={line.recipe_line_id}
                        value={line.recipe_line_id}
                      >
                        {line.line_code || "Dòng không có mã"} ·{" "}
                        {line.recipe_line_id?.slice(0, 8)}
                      </option>
                    ))}
                  </select>
                </label>
              )}
            {draft.action === "REPLACE" && (
              <label>
                Nguyên liệu thay thế
                <select
                  value={draft.substituteIngredientId}
                  onChange={(event) =>
                    setDraft((value) => ({
                      ...value,
                      substituteIngredientId: event.target.value,
                    }))
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
            {["ADD", "ADJUST_QUANTITY", "REPLACE"].includes(draft.action) && (
              <label>
                {draft.action === "REPLACE"
                  ? "Định lượng thay thế (không bắt buộc)"
                  : "Định lượng theo định mức"}
                <input
                  type="number"
                  min="0.000001"
                  step="0.000001"
                  value={draft.quantity}
                  onChange={(event) =>
                    setDraft((value) => ({
                      ...value,
                      quantity: event.target.value,
                    }))
                  }
                />
              </label>
            )}
            {(draft.action === "ADD" ||
              (draft.action === "REPLACE" && draft.quantity)) && (
              <label>
                Đơn vị
                <select
                  value={draft.unitId}
                  onChange={(event) =>
                    setDraft((value) => ({
                      ...value,
                      unitId: event.target.value,
                    }))
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
                    setDraft((value) => ({
                      ...value,
                      effectiveFrom: event.target.value,
                    }))
                  }
                />
              </label>
              <label>
                Hiệu lực đến (không gồm ngày này)
                <input
                  type="date"
                  value={draft.effectiveTo}
                  onChange={(event) =>
                    setDraft((value) => ({
                      ...value,
                      effectiveTo: event.target.value,
                    }))
                  }
                />
              </label>
            </div>
            <label>
              Lý do bắt buộc
              <textarea
                value={draft.reason}
                onChange={(event) =>
                  setDraft((value) => ({
                    ...value,
                    reason: event.target.value,
                  }))
                }
              />
            </label>
            <div className="table-actions">
              <button
                type="button"
                disabled={busy}
                onClick={() => void runPreview()}
              >
                {busy ? "Đang xem trước…" : "Xem trước có thẩm quyền"}
              </button>
              <button
                type="button"
                disabled={busy || !preview?.can_save}
                onClick={() => void saveRule()}
              >
                {editing ? "Lưu bản kế nhiệm" : "Lưu quy tắc"}
              </button>
            </div>
            {editing && (
              <button
                type="button"
                onClick={() => {
                  setEditing(null);
                  setPreview(null);
                  setDraft(emptyDraft());
                }}
              >
                Bỏ sửa kế nhiệm
              </button>
            )}
            {preview && (
              <section className="adjustment-preview-card">
                <h4>Kết quả trước / sau</h4>
                <p>
                  {preview.affected_line_count} dòng bị ảnh hưởng ·{" "}
                  {preview.can_save ? "Có thể lưu" : "Đang bị chặn"}
                </p>
                {preview.blockers.map((blocker) => (
                  <p className="operator-notice warning" key={blocker.code}>
                    {blocker.code}: {blocker.message}
                  </p>
                ))}
                <CompactTable
                  headers={["RecipeLine", "Trước", "Sau", "Nguồn cuối"]}
                >
                  {preview.after.lines.map((line) => {
                    const before = preview.before.lines.find(
                      (candidate) =>
                        (candidate.base_recipe_line_id ??
                          candidate.adjustment_line_id) ===
                        (line.base_recipe_line_id ?? line.adjustment_line_id),
                    );
                    return (
                      <tr
                        key={
                          line.base_recipe_line_id ?? line.adjustment_line_id
                        }
                      >
                        <td>{line.line_code ?? "Dòng điều chỉnh"}</td>
                        <td>
                          {referenceLabel(
                            load.data.ingredients,
                            before?.final_ingredient_id ?? null,
                            "ingredient_id",
                            "ingredient_name",
                          )}{" "}
                          · {before?.final_quantity_per_basis ?? "—"}
                        </td>
                        <td>
                          {referenceLabel(
                            load.data.ingredients,
                            line.final_ingredient_id,
                            "ingredient_id",
                            "ingredient_name",
                          )}{" "}
                          · {line.final_quantity_per_basis}
                        </td>
                        <td>{layerLabel[line.source_layer]}</td>
                      </tr>
                    );
                  })}
                </CompactTable>
              </section>
            )}
          </aside>
        </div>
      ) : (
        <section className="effective-bom-workbench">
          <div className="table-actions">
            <button
              type="button"
              disabled={busy}
              onClick={() => void resolve()}
            >
              {busy ? "Đang phân giải…" : "Phân giải BOM hiệu lực"}
            </button>
            <button
              type="button"
              disabled={!resolution}
              onClick={() => void copyAudit()}
            >
              Sao chép chi tiết kiểm toán
            </button>
          </div>
          {resolution && (
            <>
              <div className="effective-bom-summary">
                <article>
                  <span>Công thức được chọn</span>
                  <strong>
                    {resolution.selected_recipe?.selection_scope ===
                    "SCHOOL_TYPE"
                      ? "Theo loại trường"
                      : "Công thức chung"}
                  </strong>
                </article>
                <article>
                  <span>RecipeVersion</span>
                  <strong>
                    {resolution.selected_recipe?.recipe_version_id.slice(0, 8)}
                  </strong>
                </article>
                <article>
                  <span>Định mức</span>
                  <strong>
                    {resolution.selected_recipe?.basis_portions} suất
                  </strong>
                </article>
                <article>
                  <span>Trạng thái</span>
                  <strong>
                    {resolution.status === "READY" ? "Sẵn sàng" : "Bị chặn"}
                  </strong>
                </article>
              </div>
              {resolution.blockers.map((blocker) => (
                <p className="operator-notice warning" key={blocker.code}>
                  {blocker.code}: {blocker.message}
                </p>
              ))}
              {resolution.warnings.map((warning) => (
                <p className="operator-notice" key={warning.code}>
                  {warning.message}
                </p>
              ))}
              <div className="effective-bom-comparison">
                <section>
                  <h3>BOM phát hành</h3>
                  <CompactTable
                    headers={[
                      "Dòng",
                      "Nguyên liệu",
                      "Định lượng",
                      "Trạng thái",
                    ]}
                  >
                    {resolution.lines.map((line) => (
                      <tr
                        key={`base:${line.base_recipe_line_id ?? line.adjustment_line_id}`}
                      >
                        <td>{line.line_code ?? "Dòng thêm"}</td>
                        <td>
                          {referenceLabel(
                            load.data.ingredients,
                            line.base_ingredient_id,
                            "ingredient_id",
                            "ingredient_name",
                          )}
                        </td>
                        <td>
                          {line.base_quantity_per_basis ?? "—"}{" "}
                          {referenceLabel(
                            load.data.units,
                            line.base_unit_id,
                            "unit_id",
                            "unit_name",
                          )}
                        </td>
                        <td>
                          {line.base_disposition ?? "Không có trong BOM gốc"}
                        </td>
                      </tr>
                    ))}
                  </CompactTable>
                </section>
                <section>
                  <h3>BOM hiệu lực</h3>
                  <CompactTable
                    headers={["Dòng", "Nguyên liệu", "Định lượng", "Lớp nguồn"]}
                  >
                    {resolution.lines.map((line) => (
                      <tr
                        className={
                          line.final_disposition === "REMOVED"
                            ? "removed-effective-line"
                            : ""
                        }
                        key={`effective:${line.base_recipe_line_id ?? line.adjustment_line_id}`}
                      >
                        <td>
                          {line.line_code ?? "Dòng thêm"}
                          <details>
                            <summary>
                              {line.lineage.length} bước điều chỉnh
                            </summary>
                            {line.lineage.length === 0 ? (
                              <small>Chỉ dùng BOM phát hành.</small>
                            ) : (
                              <ol>
                                {line.lineage.map((step) => (
                                  <li key={step.revision_id}>
                                    {scopeLabel[step.scope_kind]} ·{" "}
                                    {actionLabel[step.action_kind]} ·{" "}
                                    {step.reason_note}
                                  </li>
                                ))}
                              </ol>
                            )}
                            <code>
                              {line.base_recipe_line_id ??
                                line.adjustment_line_id}
                            </code>
                          </details>
                        </td>
                        <td>
                          {referenceLabel(
                            load.data.ingredients,
                            line.final_ingredient_id,
                            "ingredient_id",
                            "ingredient_name",
                          )}
                        </td>
                        <td>
                          {line.final_quantity_per_basis}{" "}
                          {referenceLabel(
                            load.data.units,
                            line.final_unit_id,
                            "unit_id",
                            "unit_name",
                          )}
                          {line.final_disposition === "REMOVED" && (
                            <small> · Đã loại bỏ</small>
                          )}
                        </td>
                        <td>
                          <Chip tone={sourceTone(line.source_layer)}>
                            {layerLabel[line.source_layer] ?? line.source_layer}
                          </Chip>
                        </td>
                      </tr>
                    ))}
                  </CompactTable>
                </section>
              </div>
            </>
          )}
          {!resolution && load.status === "ready" && (
            <p className="operator-notice">
              Chọn đúng ngày, Trường và Món ăn rồi phân giải BOM hiệu lực.
            </p>
          )}
        </section>
      )}
    </Panel>
  );
}
