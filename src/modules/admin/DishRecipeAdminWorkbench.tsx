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
  type RecipeCompositionLine,
  type RecipeWorkbenchData,
} from "../atlas/recipes/recipeModel";
import {
  reviewRecipeWorkbook,
  type RecipeWorkbookReview,
} from "../atlas/recipes/recipeWorkbook";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import { RecipeAdjustmentWorkbench } from "./RecipeAdjustmentWorkbench";

type Tab = "recipes" | "catalog" | "adjustments" | "effective" | "import";
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
  const [tab, setTab] = useState<Tab>("catalog");
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
  });
  const [copyOpen, setCopyOpen] = useState(false);
  const [copyQuery, setCopyQuery] = useState("");
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
      return result;
    }
    if (result.kind === "transport_error") setWriteUncertain(true);
    return null;
  };

  const selectRecipeContext = async (
    nextDishId: string,
    nextSchoolTypeId: string | null,
  ) => {
    if (
      isDirty &&
      !window.confirm(
        "Bạn có thay đổi chưa lưu. Bỏ các thay đổi này và chuyển sang nội dung khác?",
      )
    )
      return;
    setDishId(nextDishId);
    setSchoolTypeId(nextSchoolTypeId);
    setNotice(null);
    await refresh({ dishId: nextDishId, schoolTypeId: nextSchoolTypeId });
  };

  const workflowCommand = async (
    expectedVersion: number,
    payload: Record<string, JsonValue>,
  ) => {
    if (!api || !authSubject) return false;
    setBusy(true);
    const result = await api.saveRecipe(
      recipeWorkflowCommandRequest(
        authSubject,
        correlationId,
        expectedVersion,
        "save",
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

  const effectiveRecipesForDish = (targetDishId: string) =>
    load.data.recipes
      .filter(
        (recipe) =>
          recipe.dish_id === targetDishId && recipe.recipe_status === "ACTIVE",
      )
      .map((recipe) => ({
        recipe,
        version: load.data.recipe_versions
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

  const shownDishes = load.data.dishes.filter((item) => {
    const needle = query.trim().toLocaleLowerCase("vi");
    const effectiveIngredientNames = effectiveRecipesForDish(item.dish_id)
      .flatMap(({ version }) => version.composition)
      .filter((line) => line.line_disposition === "PRESENT")
      .map(
        (line) =>
          load.data.ingredients.find(
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
        ...effectiveIngredientNames,
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
  const creationLocked =
    load.data.selected_recipe.locked_for_normal_editing ?? false;
  const copySourceOptions = load.data.recipe_versions.filter((version) => {
    if (version.recipe_version_status !== "RELEASED_FOR_PLANNING") return false;
    const recipe = load.data.recipes.find(
      (item) => item.recipe_id === version.recipe_id,
    );
    const sourceDish = load.data.dishes.find(
      (item) => item.dish_id === recipe?.dish_id,
    );
    const needle = copyQuery.trim().toLocaleLowerCase("vi");
    if (!needle) return true;
    const ingredientNames = version.composition.map(
      (line) =>
        load.data.ingredients.find(
          (item) => item.ingredient_id === line.ingredient_id,
        )?.ingredient_name ?? "",
    );
    return [
      sourceDish?.dish_name,
      sourceDish?.dish_code,
      ...ingredientNames,
    ].some((value) => (value ?? "").toLocaleLowerCase("vi").includes(needle));
  });
  const copySource = load.data.recipe_versions.find(
    (item) => item.recipe_version_id === copyDraft.sourceVersionId,
  );

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
    setTab(nextTab);
  };

  const beginDish = () => {
    setDishEditorId("NEW");
    setDishDraft({
      ...emptyDishDraft(),
      dishTypeId:
        load.data.dish_types.find(
          (dishType) => dishType.dish_type_status === "ACTIVE",
        )?.dish_type_id ?? "",
    });
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
    const payload = {
      dish_code: dishDraft.code,
      dish_name: dishDraft.name,
      dish_category: dishDraft.category,
      dish_type_id: dishDraft.dishTypeId,
      operational_notes: dishDraft.notes,
      display_order: displayOrder,
      requires_need_generation: dishDraft.requiresNeedGeneration,
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
    const createdDishId =
      affectedDishId ??
      returnedDishes.find((item) => item.dish_code === dishDraft.code.trim())
        ?.dish_id;
    setDishEditorId(null);
    setTab("recipes");
    if (createdDishId) {
      await refresh({ dishId: createdDishId, schoolTypeId: null });
    } else {
      await refresh();
    }
  };

  const saveComposition = async () => {
    const selection = load.data.selected_recipe;
    if (!dish || selection.expected_version === null || !compositionValid) {
      setNotice(
        "Công thức cần ít nhất một nguyên liệu, đơn vị và định lượng dương.",
      );
      return;
    }
    await workflowCommand(selection.expected_version, {
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

  const applyCopy = () => {
    const source = load.data.recipe_versions.find(
      (item) => item.recipe_version_id === copyDraft.sourceVersionId,
    );
    if (!source || !dish || creationLocked) return;
    setBasisPortions(String(source.basis_portions));
    setComposition(
      source.composition
        .filter((line) => line.line_disposition === "PRESENT")
        .map((line) => ({
          ...structuredClone(line),
          recipe_line_id: crypto.randomUUID(),
          predecessor_recipe_line_revision_id: null,
          line_code: null,
        })),
    );
    setNotice(
      `Đã sao chép nội dung vào ${dish.dish_name}. Hãy kiểm tra rồi bấm ${load.data.selected_recipe.recipe_id ? "Lưu" : "Tạo"}.`,
    );
    setCopyOpen(false);
    setCopyQuery("");
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
              Tìm món hoặc nguyên liệu
              <input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Tìm theo tên món, mã món hoặc nguyên liệu…"
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
                  "Công thức hiện hành",
                  "Tình trạng",
                  "",
                ]}
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
                      {effectiveRecipesForDish(item.dish_id).length ? (
                        effectiveRecipesForDish(item.dish_id).map(
                          ({ recipe, version }) => (
                            <small key={recipe.recipe_id}>
                              {schoolScopeLabel(recipe, load.data.school_types)}
                              : {version.basis_portions} suất ·{" "}
                              {version.composition
                                .filter(
                                  (line) => line.line_disposition === "PRESENT",
                                )
                                .map((line) =>
                                  ingredientLabel(
                                    line.ingredient_id,
                                    load.data.ingredients,
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
                          onClick={() => {
                            setDishId(item.dish_id);
                          }}
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
            <aside className="master-data-detail">
              <div className="master-data-detail-heading">
                <div>
                  <span>Thông tin đang sử dụng</span>
                  <h3>{dish?.dish_name ?? "Chọn một món"}</h3>
                </div>
              </div>
              {dish && (
                <>
                  <dl className="master-data-detail-list">
                    {effectiveRecipesForDish(dish.dish_id).map(
                      ({ recipe, version }) => (
                        <div key={recipe.recipe_id}>
                          <dt>
                            {schoolScopeLabel(recipe, load.data.school_types)}
                          </dt>
                          <dd>
                            {version.basis_portions} suất ·{" "}
                            {
                              version.composition.filter(
                                (line) => line.line_disposition === "PRESENT",
                              ).length
                            }{" "}
                            nguyên liệu
                          </dd>
                        </div>
                      ),
                    )}
                  </dl>
                  <p className="supporting-copy">
                    Danh sách này chỉ để tra cứu. Nếu món/công thức đã được sử
                    dụng và cần thay đổi, hãy chuyển sang Điều chỉnh.
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
            <button type="button" onClick={() => beginDish()}>
              Tạo món mới
            </button>
            <button
              type="button"
              disabled={!dish || creationLocked}
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
                        {load.data.selected_recipe.lock_reason ??
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

                  <div className="recipe-scope-row">
                    <label className="recipe-field-label">
                      Áp dụng cho
                      <select
                        disabled={creationLocked}
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
                          .filter(
                            (item) => item.school_type_status === "ACTIVE",
                          )
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
                          disabled={creationLocked}
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
                        disabled={creationLocked}
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
                            disabled={creationLocked}
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
                              disabled={creationLocked}
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
                              disabled={creationLocked}
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
                              disabled={creationLocked}
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
                              disabled={creationLocked}
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
                              disabled={creationLocked}
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
                          isDirty && compositionValid ? "primary" : undefined
                        }
                        disabled={
                          busy ||
                          writeUncertain ||
                          !api ||
                          !isDirty ||
                          !compositionValid ||
                          creationLocked ||
                          !load.data.selected_recipe.allowed_actions.save_recipe
                        }
                        title={
                          load.data.selected_recipe.disabled_reasons
                            .save_recipe ?? undefined
                        }
                        onClick={() => void saveComposition()}
                      >
                        {load.data.selected_recipe.recipe_id ? "Lưu" : "Tạo"}
                      </button>
                    </div>
                  </div>

                  {load.data.selected_recipe.disabled_reasons.save_recipe && (
                    <p className="recipe-disabled-reason">
                      {load.data.selected_recipe.disabled_reasons.save_recipe}
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
              Tìm và xem trước một công thức mẫu. Nội dung chỉ được điền vào
              biểu mẫu hiện tại và chưa ghi vào Atlas.
            </p>
            <label className="evidence-field">
              Tìm công thức nguồn
              <input
                value={copyQuery}
                onChange={(event) => setCopyQuery(event.target.value)}
                placeholder="Tìm theo món hoặc nguyên liệu…"
              />
            </label>
            <label className="evidence-field">
              Chọn công thức nguồn
              <select
                value={copyDraft.sourceVersionId}
                onChange={(event) =>
                  setCopyDraft({ sourceVersionId: event.target.value })
                }
              >
                <option value="">Chọn công thức mẫu</option>
                {copySourceOptions.map((item) => {
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
                      {sourceDish?.dish_name} · {item.basis_portions} suất
                    </option>
                  );
                })}
              </select>
            </label>
            <div className="recipe-copy-preview">
              <h4>Xem trước thành phần</h4>
              {!copySource ? (
                <p className="supporting-copy">
                  Chọn một công thức nguồn để xem thành phần.
                </p>
              ) : (
                <CompactTable headers={["Nguyên liệu", "Định lượng", "Đơn vị"]}>
                  {copySource.composition
                    .filter((line) => line.line_disposition === "PRESENT")
                    .map((line) => (
                      <tr key={line.recipe_line_id}>
                        <td>
                          {ingredientLabel(
                            line.ingredient_id,
                            load.data.ingredients,
                          )}
                        </td>
                        <td>{line.quantity_per_basis}</td>
                        <td>{unitLabel(line.unit_id, load.data.units)}</td>
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
                disabled={busy || !copySource || !dish || creationLocked}
                onClick={applyCopy}
              >
                Dùng công thức này
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
              <h3>Thêm món</h3>
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
