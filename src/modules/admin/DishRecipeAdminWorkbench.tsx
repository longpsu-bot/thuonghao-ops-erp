import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { AtlasAuthState } from "../atlas/connection/authSession";
import type { JsonValue } from "../atlas/connection/atlasRpc";
import type { RecipeApi } from "../atlas/recipes/recipeApi";
import {
  recipeCommandRequest,
  recipeWorkflowCommandRequest,
} from "../atlas/recipes/recipeApi";
import type { RecipeAdjustmentApi } from "../atlas/recipe-adjustments/recipeAdjustmentApi";
import {
  emptyRecipeWorkbench,
  ingredientLabel,
  recipeResultMessage,
  recipeWorkbenchFromResult,
  schoolScopeLabel,
  unitLabel,
  type DishRecord,
  type RecipeCompositionLine,
  type RecipeWorkbenchData,
} from "../atlas/recipes/recipeModel";
import {
  reviewRecipeWorkbook,
  type RecipeWorkbookReview,
} from "../atlas/recipes/recipeWorkbook";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import { RecipeAdjustmentWorkbench } from "./RecipeAdjustmentWorkbench";

type Tab =
  "recipes" | "catalog" | "adjustments" | "effective" | "copy" | "import";
type LoadState = {
  status: "idle" | "loading" | "ready" | "error";
  data: RecipeWorkbenchData;
  message?: string;
};
type DishDraft = {
  code: string;
  name: string;
  category: string;
  dishTypeId: string;
  notes: string;
  displayOrder: string;
  requiresNeedGeneration: boolean;
};
type CopyDraft = {
  sourceVersionId: string;
  targetDishId: string;
  targetSchoolTypeId: string;
  reason: string;
};

const emptyDishDraft = (): DishDraft => ({
  code: "",
  name: "",
  category: "",
  dishTypeId: "",
  notes: "",
  displayOrder: "0",
  requiresNeedGeneration: true,
});
const statusLabel: Record<string, string> = {
  DRAFT: "Nháp",
  ACTIVE: "Đang dùng",
  INACTIVE: "Ngừng dùng",
  VALIDATED: "Đã xác thực",
  RELEASED_FOR_PLANNING: "Đã phát hành cho Lập nhu cầu",
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
  NOT_SAVED: "Chưa lưu",
  SAVED: "Đã lưu",
  IN_USE: "Đang sử dụng",
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
  const [tab, setTab] = useState<Tab>("recipes");
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
    sourceVersionId: "",
    targetDishId: "",
    targetSchoolTypeId: "",
    reason: "",
  });
  const [workbook, setWorkbook] = useState<RecipeWorkbookReview | null>(null);
  const [importReason, setImportReason] = useState("");
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [writeUncertain, setWriteUncertain] = useState(false);
  const generation = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;

  const refresh = useCallback(
    async (selection?: { dishId: string; schoolTypeId: string | null }) => {
      if (!api || !authSubject) return false;
      const current = ++generation.current;
      setLoad((state) => ({ ...state, status: "loading", message: undefined }));
      const result = await api.getWorkbench(
        authSubject,
        correlationId,
        selection,
      );
      if (current !== generation.current) return false;
      const data = recipeWorkbenchFromResult(result);
      if (!data) {
        setLoad((state) => ({
          ...state,
          status: "error",
          message: recipeResultMessage(result),
        }));
        return false;
      }
      setLoad({ status: "ready", data });
      setDishId(data.selected_recipe.dish_id);
      setSchoolTypeId(data.selected_recipe.school_type_id);
      setComposition(structuredClone(data.selected_recipe.composition));
      setBasisPortions(String(data.selected_recipe.basis_portions));
      setIngredientQuery("");
      setIngredientTargetLineId(null);
      setWriteUncertain(false);
      return true;
    },
    [api, authSubject, correlationId],
  );

  useEffect(() => {
    generation.current += 1;
    setNotice(null);
    if (authSubject) void refresh();
    else setLoad({ status: "idle", data: emptyRecipeWorkbench() });
  }, [authSubject, refresh]);

  const dish = load.data.dishes.find((item) => item.dish_id === dishId);
  const dishRecipes = useMemo(
    () => load.data.recipes.filter((recipe) => recipe.dish_id === dishId),
    [dishId, load.data.recipes],
  );

  const versions = useMemo(
    () =>
      load.data.recipe_versions
        .filter(
          (version) =>
            version.recipe_id === load.data.selected_recipe.recipe_id,
        )
        .sort((left, right) => right.version_number - left.version_number),
    [load.data.recipe_versions, load.data.selected_recipe.recipe_id],
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
    if (!authSubject) return false;
    setBusy(true);
    const result = await action(
      recipeCommandRequest(
        authSubject,
        correlationId,
        expectedVersion,
        reasonCode,
        payload,
        reasonNote,
      ),
    );
    setBusy(false);
    setNotice(recipeResultMessage(result));
    if (result.kind === "success") {
      await refresh();
      return true;
    }
    if (result.kind === "transport_error") setWriteUncertain(true);
    return false;
  };

  const selectRecipeContext = async (
    nextDishId: string,
    nextSchoolTypeId: string | null,
  ) => {
    setDishId(nextDishId);
    setSchoolTypeId(nextSchoolTypeId);
    setNotice(null);
    await refresh({ dishId: nextDishId, schoolTypeId: nextSchoolTypeId });
  };

  const workflowCommand = async (
    action: "save" | "release",
    expectedVersion: number,
    payload: Record<string, JsonValue>,
  ) => {
    if (!api || !authSubject) return false;
    setBusy(true);
    const result = await (
      action === "save" ? api.saveRecipe : api.releaseRecipe
    )(
      recipeWorkflowCommandRequest(
        authSubject,
        correlationId,
        expectedVersion,
        action,
        payload,
      ),
    );
    setBusy(false);
    setNotice(recipeResultMessage(result));
    if (result.kind === "transport_error") {
      setWriteUncertain(true);
      return false;
    }
    if (result.kind !== "success") return false;
    await refresh({ dishId: dishId!, schoolTypeId });
    return true;
  };

  const shownDishes = load.data.dishes.filter((item) => {
    const needle = query.trim().toLocaleLowerCase("vi");
    return (
      !needle ||
      [
        item.dish_code,
        item.dish_name,
        item.dish_category,
        item.dish_type_name,
      ].some((value) => (value ?? "").toLocaleLowerCase("vi").includes(needle))
    );
  });

  const shownIngredients = load.data.ingredients
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
    basisPortions !== String(load.data.selected_recipe.basis_portions) ||
    JSON.stringify(presentComposition) !==
      JSON.stringify(
        load.data.selected_recipe.composition.filter(
          (line) => line.line_disposition === "PRESENT",
        ),
      );
  const visibleRecipeStatus = writeUncertain
    ? "Cần xử lý"
    : isDirty
      ? "Có thay đổi chưa lưu"
      : recipeBusinessStatusLabel[load.data.selected_recipe.business_status];

  const beginDish = (selected?: DishRecord) => {
    setDishEditorId(selected?.dish_id ?? "NEW");
    setDishDraft(
      selected
        ? {
            code: selected.dish_code,
            name: selected.dish_name,
            category: selected.dish_category ?? "",
            dishTypeId: selected.dish_type_id ?? "",
            notes: selected.operational_notes ?? "",
            displayOrder: String(selected.display_order),
            requiresNeedGeneration: selected.requires_need_generation,
          }
        : {
            ...emptyDishDraft(),
            dishTypeId:
              load.data.dish_types.find(
                (dishType) => dishType.dish_type_status === "ACTIVE",
              )?.dish_type_id ?? "",
          },
    );
  };

  const saveDish = async () => {
    if (!api || !dishEditorId) return;
    const displayOrder = Number(dishDraft.displayOrder);
    if (
      !dishDraft.code.trim() ||
      !dishDraft.name.trim() ||
      !dishDraft.dishTypeId ||
      !Number.isInteger(displayOrder) ||
      displayOrder < 0
    ) {
      setNotice(
        "Mã món, tên món, Loại món và thứ tự hiển thị không âm là bắt buộc.",
      );
      return;
    }
    const editing = load.data.dishes.find(
      (item) => item.dish_id === dishEditorId,
    );
    const payload = {
      dish_code: dishDraft.code,
      dish_name: dishDraft.name,
      dish_category: dishDraft.category,
      dish_type_id: dishDraft.dishTypeId,
      operational_notes: dishDraft.notes,
      display_order: displayOrder,
      requires_need_generation: dishDraft.requiresNeedGeneration,
    };
    const saved = editing
      ? await command(api.updateDish, editing.version, "DISH_UPDATE", {
          dish_id: editing.dish_id,
          ...payload,
        })
      : await command(api.createDish, 1, "DISH_CREATE", payload);
    if (saved) setDishEditorId(null);
  };

  const saveComposition = async () => {
    const selection = load.data.selected_recipe;
    if (!dish || selection.expected_version === null || !compositionValid) {
      setNotice(
        "Công thức cần ít nhất một nguyên liệu, đơn vị và định lượng dương.",
      );
      return;
    }
    await workflowCommand("save", selection.expected_version, {
      dish_id: dish.dish_id,
      school_type_id: schoolTypeId,
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

  const releaseComposition = async () => {
    const selection = load.data.selected_recipe;
    if (
      selection.expected_version === null ||
      !selection.recipe_version_id ||
      isDirty ||
      !compositionValid
    )
      return;
    if (
      !window.confirm(
        "Đưa công thức đã lưu vào sử dụng cho các lần Lập nhu cầu sau? Lịch sử đã dùng trước đây vẫn được giữ nguyên.",
      )
    )
      return;
    await workflowCommand("release", selection.expected_version, {
      recipe_version_id: selection.recipe_version_id,
    });
  };

  const chooseIngredient = (ingredientId: string) => {
    const ingredient = load.data.ingredients.find(
      (item) => item.ingredient_id === ingredientId,
    );
    const unit = load.data.units.find((item) => item.unit_status === "ACTIVE");
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

  const applyCopy = async () => {
    if (!api || !copyDraft.sourceVersionId || !copyDraft.targetDishId) return;
    if (!copyDraft.reason.trim()) {
      setNotice("Cần ghi lý do sao chép.");
      return;
    }
    if (!window.confirm("Tạo một bản nháp mới ở phạm vi đích đã xem trước?"))
      return;
    await command(
      api.copyVersion,
      1,
      "RECIPE_VERSION_COPY",
      {
        source_recipe_version_id: copyDraft.sourceVersionId,
        target_dish_id: copyDraft.targetDishId,
        target_school_type_id: copyDraft.targetSchoolTypeId || null,
      },
      copyDraft.reason,
    );
  };

  const parseWorkbook = async (file?: File) => {
    if (!file) return;
    setBusy(true);
    setNotice(null);
    try {
      setWorkbook(
        await reviewRecipeWorkbook(file, {
          schoolTypes: load.data.school_types,
          ingredients: load.data.ingredients,
          units: load.data.units,
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
    if (!api || !workbook || workbook.errors.length || !importReason.trim())
      return;
    if (
      !window.confirm(
        "Áp dụng workbook đã xem trước thành các phiên bản NHÁP mới?",
      )
    )
      return;
    await command(
      api.applyImport,
      1,
      "RECIPE_WORKBOOK_IMPORT",
      {
        canonical_json: workbook.canonicalJson,
        workbook_checksum: workbook.checksum,
      },
      importReason,
    );
  };

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
      </Panel>
    );
  }

  return (
    <Panel
      title="Công thức món ăn"
      description="Chọn món và phạm vi áp dụng, sau đó cập nhật nguyên liệu và định lượng."
      status={
        <Chip tone={load.status === "error" ? "danger" : "ok"}>
          {mode === "review" ? "Dữ liệu xem thử" : "Kết nối Atlas"}
        </Chip>
      }
    >
      <div className="master-data-tabs" role="tablist">
        {(
          [
            ["recipes", "Công thức"],
            ["catalog", "Món ăn"],
            ["adjustments", "Điều chỉnh"],
            ["copy", "Công cụ"],
          ] as const
        ).map(([value, label]) => (
          <button
            type="button"
            role="tab"
            aria-selected={tab === value}
            className={tab === value ? "active" : ""}
            onClick={() => setTab(value)}
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
          Chưa xác định thao tác vừa rồi đã hoàn tất hay chưa. Hãy tải lại dữ
          liệu trước khi tiếp tục.
          <button
            type="button"
            onClick={() => void refresh({ dishId: dishId!, schoolTypeId })}
          >
            Tải lại
          </button>
        </p>
      )}

      {tab === "adjustments" && (
        <>
          <div className="recipe-secondary-tabs" role="tablist">
            <button
              type="button"
              role="tab"
              aria-selected
              onClick={() => setTab("adjustments")}
            >
              Quy tắc điều chỉnh
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={false}
              onClick={() => setTab("effective")}
            >
              Công thức hiệu lực
            </button>
          </div>
          <RecipeAdjustmentWorkbench
            authState={authState}
            api={adjustmentApi}
            view="rules"
            mode={mode}
          />
        </>
      )}

      {tab === "effective" && (
        <>
          <div className="recipe-secondary-tabs" role="tablist">
            <button
              type="button"
              role="tab"
              aria-selected={false}
              onClick={() => setTab("adjustments")}
            >
              Quy tắc điều chỉnh
            </button>
            <button type="button" role="tab" aria-selected>
              Công thức hiệu lực
            </button>
          </div>
          <RecipeAdjustmentWorkbench
            authState={authState}
            api={adjustmentApi}
            view="effective"
            mode={mode}
          />
        </>
      )}

      {tab === "catalog" && (
        <>
          <div className="master-data-toolbar">
            <label className="evidence-field">
              Tìm món ăn
              <input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Tìm theo tên hoặc mã món…"
              />
            </label>
            <span />
            <button type="button" onClick={() => void refresh()}>
              Tải lại
            </button>
            <button
              type="button"
              className="primary-toolbar-action"
              onClick={() => beginDish()}
            >
              Thêm món
            </button>
          </div>
          <div className="master-data-workspace with-detail">
            <div className="master-data-table-scroll">
              <CompactTable
                headers={["Món ăn", "Loại món", "Trạng thái", "Phạm vi", ""]}
              >
                {shownDishes.map((item) => (
                  <tr key={item.dish_id}>
                    <td>
                      <strong>{item.dish_name}</strong>
                      <small>{item.dish_code}</small>
                    </td>
                    <td>
                      {item.dish_type_name ?? (
                        <span className="operator-notice danger">Chưa gán</span>
                      )}
                    </td>
                    <td>
                      <Chip tone={statusTone(item.dish_status)}>
                        {statusLabel[item.dish_status]}
                      </Chip>
                    </td>
                    <td>
                      {
                        load.data.recipes.filter(
                          (recipeItem) =>
                            recipeItem.dish_id === item.dish_id &&
                            recipeItem.recipe_status === "ACTIVE",
                        ).length
                      }
                    </td>
                    <td>
                      <div className="master-data-row-actions">
                        <button
                          className="inline-action"
                          onClick={() => {
                            setTab("recipes");
                            void selectRecipeContext(item.dish_id, null);
                          }}
                        >
                          Mở
                        </button>
                        <button
                          className="inline-action"
                          onClick={() => beginDish(item)}
                        >
                          Sửa
                        </button>
                        <button
                          className="inline-action"
                          disabled={busy || !api}
                          onClick={() =>
                            void command(
                              api!.setDishLifecycle,
                              item.version,
                              "DISH_LIFECYCLE",
                              {
                                dish_id: item.dish_id,
                                dish_status:
                                  item.dish_status === "ACTIVE"
                                    ? "INACTIVE"
                                    : "ACTIVE",
                              },
                            )
                          }
                        >
                          {item.dish_status === "ACTIVE"
                            ? "Ngừng dùng"
                            : "Kích hoạt"}
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
            <aside className="master-data-detail">
              <div className="master-data-detail-heading">
                <div>
                  <span>Phạm vi công thức</span>
                  <h3>{dish?.dish_name ?? "Chọn một món"}</h3>
                </div>
              </div>
              {dish && (
                <>
                  <dl className="master-data-detail-list">
                    {dishRecipes.map((item) => (
                      <div key={item.recipe_id}>
                        <dt>
                          {schoolScopeLabel(item, load.data.school_types)}
                        </dt>
                        <dd>
                          {statusLabel[item.recipe_status]} ·{" "}
                          {
                            load.data.recipe_versions.filter(
                              (candidate) =>
                                candidate.recipe_id === item.recipe_id,
                            ).length
                          }{" "}
                          phiên bản
                        </dd>
                      </div>
                    ))}
                  </dl>
                  <p className="supporting-copy">
                    Mở món ăn để xem hoặc tạo công thức theo phạm vi áp dụng.
                  </p>
                </>
              )}
            </aside>
          </div>
        </>
      )}

      {tab === "recipes" && (
        <div className="recipe-first-user-layout">
          <aside className="recipe-dish-finder" aria-label="Tìm món ăn">
            <label className="recipe-field-label" htmlFor="recipe-dish-search">
              Tìm món
            </label>
            <input
              id="recipe-dish-search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Tìm theo tên hoặc mã món…"
            />
            <div className="recipe-dish-results" role="listbox">
              {shownDishes.map((item) => (
                <button
                  type="button"
                  role="option"
                  aria-selected={item.dish_id === dishId}
                  className={item.dish_id === dishId ? "active" : ""}
                  key={item.dish_id}
                  onClick={() => void selectRecipeContext(item.dish_id, null)}
                >
                  <strong>{item.dish_name}</strong>
                  <span>
                    {item.dish_code}
                    {item.dish_type_name ? ` · ${item.dish_type_name}` : ""}
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
            {dish ? (
              <>
                <header className="recipe-context-header">
                  <div>
                    <span>Món đang chọn</span>
                    <h3>{dish.dish_name}</h3>
                    <p>
                      Mã món: {dish.dish_code} · Loại món:{" "}
                      {dish.dish_type_name ?? "Chưa xác định"}
                    </p>
                  </div>
                  <Chip
                    tone={
                      visibleRecipeStatus === "Cần xử lý"
                        ? "warning"
                        : visibleRecipeStatus === "Đang sử dụng"
                          ? "ok"
                          : "neutral"
                    }
                  >
                    {visibleRecipeStatus}
                  </Chip>
                </header>

                <div className="recipe-scope-row">
                  <label className="recipe-field-label">
                    Áp dụng cho
                    <select
                      value={schoolTypeId ?? ""}
                      onChange={(event) =>
                        void selectRecipeContext(
                          dish.dish_id,
                          event.target.value || null,
                        )
                      }
                    >
                      <option value="">Tất cả</option>
                      {load.data.school_types
                        .filter((item) => item.school_type_status === "ACTIVE")
                        .map((item) => (
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
                          role="option"
                          aria-selected={false}
                          key={item.ingredient_id}
                          onClick={() => chooseIngredient(item.ingredient_id)}
                        >
                          <strong>{item.ingredient_name}</strong>
                          <span>{item.ingredient_code}</span>
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
                              load.data.ingredients,
                            )}
                          </strong>
                          <button
                            type="button"
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
                            aria-label={`Định lượng ${ingredientLabel(
                              line.ingredient_id,
                              load.data.ingredients,
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
                            aria-label={`Đơn vị ${ingredientLabel(
                              line.ingredient_id,
                              load.data.ingredients,
                            )}`}
                            value={line.unit_id}
                            onChange={(event) =>
                              setComposition((lines) =>
                                lines.map((item) =>
                                  item.recipe_line_id === line.recipe_line_id
                                    ? { ...item, unit_id: event.target.value }
                                    : item,
                                ),
                              )
                            }
                          >
                            {load.data.units
                              .filter((item) => item.unit_status === "ACTIVE")
                              .map((item) => (
                                <option value={item.unit_id} key={item.unit_id}>
                                  {item.unit_name}
                                </option>
                              ))}
                          </select>
                        </td>
                        <td>
                          <input
                            aria-label={`Ghi chú ${ingredientLabel(
                              line.ingredient_id,
                              load.data.ingredients,
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
                      Lưu để tiếp tục chỉnh sửa sau. Đưa vào sử dụng chỉ ảnh
                      hưởng các lần Lập nhu cầu trong tương lai.
                    </p>
                  </div>
                  <div className="workbench-actions">
                    <button
                      type="button"
                      className={
                        isDirty && compositionValid ? "primary" : undefined
                      }
                      disabled={
                        busy ||
                        writeUncertain ||
                        !api ||
                        !isDirty ||
                        !compositionValid ||
                        !load.data.selected_recipe.allowed_actions.save_recipe
                      }
                      title={
                        load.data.selected_recipe.disabled_reasons
                          .save_recipe ?? undefined
                      }
                      onClick={() => void saveComposition()}
                    >
                      Lưu
                    </button>
                    <button
                      type="button"
                      className={
                        !isDirty &&
                        load.data.selected_recipe.allowed_actions.release_recipe
                          ? "primary"
                          : undefined
                      }
                      disabled={
                        busy ||
                        writeUncertain ||
                        !api ||
                        isDirty ||
                        !compositionValid ||
                        !load.data.selected_recipe.allowed_actions
                          .release_recipe
                      }
                      title={
                        load.data.selected_recipe.disabled_reasons
                          .release_recipe ?? undefined
                      }
                      onClick={() => void releaseComposition()}
                    >
                      Đưa vào sử dụng
                    </button>
                  </div>
                </div>

                {(load.data.selected_recipe.disabled_reasons.save_recipe ||
                  load.data.selected_recipe.disabled_reasons
                    .release_recipe) && (
                  <p className="recipe-disabled-reason">
                    {isDirty
                      ? load.data.selected_recipe.disabled_reasons.save_recipe
                      : load.data.selected_recipe.disabled_reasons
                          .release_recipe}
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
                                ? "Đưa vào sử dụng"
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
                              Số lưu trữ: {item.version_number} · Mã tham chiếu:{" "}
                              {item.recipe_version_id}
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
      )}

      {/* Legacy backend-shaped Recipe Version editor retired by UI-QUALITY-03A.
      {tab === "versions" && (
        <div className="recipe-connected-layout">
          <section className="recipe-selection-panel">
            <label className="evidence-field">
              Món ăn
              <select
                value={dishId ?? ""}
                onChange={(event) => setDishId(event.target.value)}
              >
                {load.data.dishes.map((item) => (
                  <option key={item.dish_id} value={item.dish_id}>
                    {item.dish_name}
                  </option>
                ))}
              </select>
            </label>
            <label className="evidence-field">
              Phạm vi
              <select
                value={recipeId ?? ""}
                onChange={(event) => setRecipeId(event.target.value)}
              >
                {dishRecipes.map((item) => (
                  <option key={item.recipe_id} value={item.recipe_id}>
                    {schoolScopeLabel(item, load.data.school_types)} ·{" "}
                    {statusLabel[item.recipe_status]}
                  </option>
                ))}
              </select>
            </label>
            <div className="recipe-version-list">
              {versions.map((item) => (
                <button
                  type="button"
                  className={
                    item.recipe_version_id === versionId ? "active" : ""
                  }
                  onClick={() => setVersionId(item.recipe_version_id)}
                  key={item.recipe_version_id}
                >
                  <strong>v{item.version_number}</strong>
                  <span>{statusLabel[item.recipe_version_status]}</span>
                </button>
              ))}
            </div>
          </section>
          <section className="recipe-composition-panel">
            {!version ? (
              <p className="supporting-copy">
                Phạm vi này chưa có phiên bản công thức.
              </p>
            ) : (
              <>
                <div className="recipe-version-heading">
                  <div>
                    <span>Phiên bản v{version.version_number}</span>
                    <h3>{statusLabel[version.recipe_version_status]}</h3>
                  </div>
                  <Chip tone={statusTone(version.recipe_version_status)}>
                    {version.predecessor_recipe_version_id
                      ? "Có tiền nhiệm"
                      : "Phiên bản đầu"}
                  </Chip>
                </div>
                <div className="recipe-lifecycle-evidence">
                  <span>
                    Tạo: {new Date(version.created_at).toLocaleString("vi-VN")}
                  </span>
                  <span>
                    Xác thực:{" "}
                    {version.validated_at
                      ? new Date(version.validated_at).toLocaleString("vi-VN")
                      : "—"}
                  </span>
                  <span>
                    Phát hành:{" "}
                    {version.released_at
                      ? new Date(version.released_at).toLocaleString("vi-VN")
                      : "—"}
                  </span>
                </div>
                <label className="evidence-field recipe-basis-field">
                  Số suất cơ sở
                  <input
                    type="number"
                    min="1"
                    disabled={version.recipe_version_status !== "DRAFT"}
                    value={basisPortions}
                    onChange={(event) => setBasisPortions(event.target.value)}
                  />
                </label>
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
                    {composition.map((line) => (
                      <tr key={line.recipe_line_id}>
                        <td>
                          {version.recipe_version_status === "DRAFT" &&
                          line.line_disposition === "PRESENT" ? (
                            <select
                              value={line.ingredient_id}
                              onChange={(event) =>
                                setComposition((lines) =>
                                  lines.map((item) =>
                                    item.recipe_line_id === line.recipe_line_id
                                      ? {
                                          ...item,
                                          ingredient_id: event.target.value,
                                        }
                                      : item,
                                  ),
                                )
                              }
                            >
                              {load.data.ingredients
                                .filter(
                                  (item) => item.ingredient_status === "ACTIVE",
                                )
                                .map((item) => (
                                  <option
                                    value={item.ingredient_id}
                                    key={item.ingredient_id}
                                  >
                                    {item.ingredient_name}
                                  </option>
                                ))}
                            </select>
                          ) : (
                            ingredientLabel(
                              line.ingredient_id,
                              load.data.ingredients,
                            )
                          )}
                          {line.line_disposition === "REMOVED" && (
                            <small>Đã loại bỏ rõ ràng ở phiên bản này</small>
                          )}
                        </td>
                        <td>
                          <input
                            type="number"
                            min="0"
                            step="0.000001"
                            disabled={
                              version.recipe_version_status !== "DRAFT" ||
                              line.line_disposition === "REMOVED"
                            }
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
                          {version.recipe_version_status === "DRAFT" &&
                          line.line_disposition === "PRESENT" ? (
                            <select
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
                              {load.data.units
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
                          ) : (
                            unitLabel(line.unit_id, load.data.units)
                          )}
                        </td>
                        <td>
                          <input
                            disabled={version.recipe_version_status !== "DRAFT"}
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
                          {version.recipe_version_status === "DRAFT" &&
                            line.line_disposition === "PRESENT" && (
                              <button
                                className="inline-action danger-action"
                                onClick={() => removeLine(line)}
                              >
                                Loại bỏ
                              </button>
                            )}
                        </td>
                      </tr>
                    ))}
                  </CompactTable>
                </div>
                <div className="workbench-actions">
                  {version.recipe_version_status === "DRAFT" && (
                    <>
                      <button onClick={addLine}>Thêm dòng BOM</button>
                      <button
                        className="primary"
                        disabled={busy || !api}
                        onClick={() => void saveComposition()}
                      >
                        Lưu toàn bộ BOM
                      </button>
                      <button
                        disabled={busy || !api}
                        onClick={() => void transitionVersion("validate")}
                      >
                        Xác thực
                      </button>
                    </>
                  )}
                  {version.recipe_version_status === "VALIDATED" && (
                    <button
                      className="primary"
                      disabled={busy || !api}
                      onClick={() => void transitionVersion("release")}
                    >
                      Phát hành cho Lập nhu cầu
                    </button>
                  )}
                  {["VALIDATED", "RELEASED_FOR_PLANNING", "LOCKED"].includes(
                    version.recipe_version_status,
                  ) && (
                    <button
                      disabled={busy || !api}
                      onClick={() => void transitionVersion("successor")}
                    >
                      Tạo phiên bản kế nhiệm
                    </button>
                  )}
                </div>
                <p className="drawer-guidance">
                  Phiên bản đã xác thực, phát hành hoặc khóa chỉ đọc. Mọi điều
                  chỉnh phải đi qua một phiên bản kế nhiệm; việc phát hành chỉ
                  ảnh hưởng tham chiếu Lập nhu cầu trong tương lai.
                </p>
              </>
            )}
          </section>
        </div>
      )}

      */}

      {(tab === "copy" || tab === "import") && (
        <div className="recipe-secondary-tabs" role="tablist">
          <button
            type="button"
            role="tab"
            aria-selected={tab === "copy"}
            onClick={() => setTab("copy")}
          >
            Sao chép công thức
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={tab === "import"}
            onClick={() => setTab("import")}
          >
            Nhập workbook
          </button>
        </div>
      )}

      {tab === "copy" && (
        <div className="recipe-operation-grid">
          <section>
            <h3>Nguồn và đích</h3>
            <label className="evidence-field">
              Phiên bản nguồn
              <select
                value={copyDraft.sourceVersionId}
                onChange={(event) =>
                  setCopyDraft((state) => ({
                    ...state,
                    sourceVersionId: event.target.value,
                  }))
                }
              >
                <option value="">Chọn phiên bản</option>
                {load.data.recipe_versions.map((item) => {
                  const sourceRecipe = load.data.recipes.find(
                    (candidate) => candidate.recipe_id === item.recipe_id,
                  );
                  const sourceDish = load.data.dishes.find(
                    (candidate) => candidate.dish_id === sourceRecipe?.dish_id,
                  );
                  return (
                    <option
                      key={item.recipe_version_id}
                      value={item.recipe_version_id}
                    >
                      {sourceDish?.dish_name} · v{item.version_number} ·{" "}
                      {statusLabel[item.recipe_version_status]}
                    </option>
                  );
                })}
              </select>
            </label>
            <label className="evidence-field">
              Món đích
              <select
                value={copyDraft.targetDishId}
                onChange={(event) =>
                  setCopyDraft((state) => ({
                    ...state,
                    targetDishId: event.target.value,
                  }))
                }
              >
                <option value="">Chọn món đích</option>
                {load.data.dishes
                  .filter((item) => item.dish_status === "ACTIVE")
                  .map((item) => (
                    <option key={item.dish_id} value={item.dish_id}>
                      {item.dish_name}
                    </option>
                  ))}
              </select>
            </label>
            <label className="evidence-field">
              Phạm vi đích
              <select
                value={copyDraft.targetSchoolTypeId}
                onChange={(event) =>
                  setCopyDraft((state) => ({
                    ...state,
                    targetSchoolTypeId: event.target.value,
                  }))
                }
              >
                <option value="">Công thức chung</option>
                {load.data.school_types.map((item) => (
                  <option key={item.school_type_id} value={item.school_type_id}>
                    {item.school_type_name}
                  </option>
                ))}
              </select>
            </label>
            <label className="evidence-field">
              Lý do sao chép
              <textarea
                value={copyDraft.reason}
                onChange={(event) =>
                  setCopyDraft((state) => ({
                    ...state,
                    reason: event.target.value,
                  }))
                }
              />
            </label>
          </section>
          <section>
            <h3>Xem trước có kiểm soát</h3>
            {(() => {
              const source = load.data.recipe_versions.find(
                (item) => item.recipe_version_id === copyDraft.sourceVersionId,
              );
              const targetRecipe = load.data.recipes.find(
                (item) =>
                  item.dish_id === copyDraft.targetDishId &&
                  item.school_type_id ===
                    (copyDraft.targetSchoolTypeId || null) &&
                  item.recipe_status === "ACTIVE",
              );
              const targetVersions = load.data.recipe_versions.filter(
                (item) => item.recipe_id === targetRecipe?.recipe_id,
              );
              return (
                <>
                  <dl className="master-data-detail-list">
                    <div>
                      <dt>Dòng nguồn</dt>
                      <dd>{source?.composition.length ?? 0}</dd>
                    </div>
                    <div>
                      <dt>Phiên bản đích hiện có</dt>
                      <dd>{targetVersions.length}</dd>
                    </div>
                    <div>
                      <dt>Kết quả</dt>
                      <dd>
                        Một bản nháp mới; không ghi đè bản nháp hoặc lịch sử
                        hiện có.
                      </dd>
                    </div>
                  </dl>
                  <h4>Thành phần công thức nguồn</h4>
                  {!source ? (
                    <p className="supporting-copy">
                      Chọn phiên bản nguồn để xem đầy đủ thành phần sẽ sao chép.
                    </p>
                  ) : source.composition.length ? (
                    <div className="master-data-table-scroll recipe-bom-table">
                      <CompactTable
                        headers={[
                          "Mã dòng",
                          "Nguyên liệu",
                          "Định lượng",
                          "Đơn vị",
                          "Trạng thái",
                          "Ghi chú",
                        ]}
                      >
                        {source.composition.map((line) => (
                          <tr key={line.recipe_line_id}>
                            <td>{line.line_code ?? "—"}</td>
                            <td>
                              {ingredientLabel(
                                line.ingredient_id,
                                load.data.ingredients,
                              )}
                            </td>
                            <td>{line.quantity_per_basis}</td>
                            <td>{unitLabel(line.unit_id, load.data.units)}</td>
                            <td>
                              <Chip tone={statusTone(line.line_disposition)}>
                                {statusLabel[line.line_disposition]}
                              </Chip>
                            </td>
                            <td>{line.operational_note ?? "—"}</td>
                          </tr>
                        ))}
                      </CompactTable>
                    </div>
                  ) : (
                    <p className="supporting-copy">
                      Phiên bản nguồn không có thành phần để sao chép.
                    </p>
                  )}
                </>
              );
            })()}
            <button
              type="button"
              disabled={
                busy ||
                !api ||
                !copyDraft.sourceVersionId ||
                !copyDraft.targetDishId ||
                !copyDraft.reason.trim()
              }
              onClick={() => void applyCopy()}
            >
              Tạo bản nháp từ bản sao
            </button>
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
                Chọn tệp để xem số lượng, lỗi tham chiếu và checksum trước khi
                áp dụng.
              </p>
            ) : (
              <>
                <dl className="master-data-detail-list">
                  <div>
                    <dt>Tệp</dt>
                    <dd>{workbook.fileName}</dd>
                  </div>
                  <div>
                    <dt>Nguồn</dt>
                    <dd>
                      {workbook.sourceCounts.dishes} món ·{" "}
                      {workbook.sourceCounts.recipes} công thức ·{" "}
                      {workbook.sourceCounts.recipeLines} dòng BOM
                    </dd>
                  </div>
                  <div>
                    <dt>Checksum</dt>
                    <dd>
                      <code>{workbook.checksum}</code>
                    </dd>
                  </div>
                  <div>
                    <dt>Vòng đời</dt>
                    <dd>{workbook.lifecycleInterpretation}</dd>
                  </div>
                </dl>
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
              <h3>{dishEditorId === "NEW" ? "Thêm món" : "Sửa món"}</h3>
            </div>
            <button onClick={() => setDishEditorId(null)}>×</button>
          </div>
          <div className="master-data-drawer-body master-data-detail-form">
            {(
              [
                ["code", "Mã món"],
                ["name", "Tên món"],
                ["category", "Nhóm mô tả (tương thích)"],
                ["displayOrder", "Thứ tự hiển thị"],
              ] as const
            ).map(([key, label]) => (
              <label className="evidence-field" key={key}>
                {label}
                <input
                  value={dishDraft[key]}
                  disabled={key === "code" && dishEditorId !== "NEW"}
                  onChange={(event) =>
                    setDishDraft((state) => ({
                      ...state,
                      [key]: event.target.value,
                    }))
                  }
                />
              </label>
            ))}
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
                {load.data.dish_types.map((dishType) => (
                  <option
                    value={dishType.dish_type_id}
                    key={dishType.dish_type_id}
                    disabled={dishType.dish_type_status !== "ACTIVE"}
                  >
                    {dishType.dish_type_name} ({dishType.dish_type_code})
                    {dishType.dish_type_status === "INACTIVE"
                      ? " — ngừng hoạt động"
                      : ""}
                  </option>
                ))}
              </select>
            </label>
            <label className="evidence-field">
              Ghi chú vận hành
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
            <label>
              <input
                type="checkbox"
                checked={dishDraft.requiresNeedGeneration}
                onChange={(event) =>
                  setDishDraft((state) => ({
                    ...state,
                    requiresNeedGeneration: event.target.checked,
                  }))
                }
              />{" "}
              Tham gia sinh nhu cầu
            </label>
            <button
              type="button"
              disabled={busy || !api}
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
