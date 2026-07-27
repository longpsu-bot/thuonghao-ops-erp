import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { AtlasAuthState } from "../atlas/connection/authSession";
import type { JsonValue } from "../atlas/connection/atlasRpc";
import type { RecipeApi } from "../atlas/recipes/recipeApi";
import { recipeCommandRequest } from "../atlas/recipes/recipeApi";
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
  "catalog" | "versions" | "adjustments" | "effective" | "copy" | "import";
type LoadState = {
  status: "idle" | "loading" | "ready" | "error";
  data: RecipeWorkbenchData;
  message?: string;
};
type DishDraft = {
  code: string;
  name: string;
  category: string;
  notes: string;
  displayOrder: string;
  requiresNeedGeneration: boolean;
};
type DraftScope = { schoolTypeId: string; basisPortions: string };
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
  notes: "",
  displayOrder: "0",
  requiresNeedGeneration: true,
});
const emptyScope = (): DraftScope => ({
  schoolTypeId: "",
  basisPortions: "100",
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
  const [recipeId, setRecipeId] = useState<string | null>(null);
  const [versionId, setVersionId] = useState<string | null>(null);
  const [dishEditorId, setDishEditorId] = useState<string | null>(null);
  const [dishDraft, setDishDraft] = useState<DishDraft>(emptyDishDraft);
  const [scopeDraft, setScopeDraft] = useState<DraftScope>(emptyScope);
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
  const generation = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;

  const refresh = useCallback(async () => {
    if (!api || !authSubject) return false;
    const current = ++generation.current;
    setLoad((state) => ({ ...state, status: "loading", message: undefined }));
    const result = await api.getWorkbench(authSubject, correlationId);
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
    setDishId((selected) =>
      selected && data.dishes.some((dish) => dish.dish_id === selected)
        ? selected
        : (data.dishes[0]?.dish_id ?? null),
    );
    return true;
  }, [api, authSubject, correlationId]);

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

  useEffect(() => {
    setRecipeId((selected) =>
      selected && dishRecipes.some((recipe) => recipe.recipe_id === selected)
        ? selected
        : (dishRecipes.find((recipe) => !recipe.school_type_id)?.recipe_id ??
          dishRecipes[0]?.recipe_id ??
          null),
    );
  }, [dishRecipes]);

  const versions = useMemo(
    () =>
      load.data.recipe_versions
        .filter((version) => version.recipe_id === recipeId)
        .sort((left, right) => right.version_number - left.version_number),
    [load.data.recipe_versions, recipeId],
  );

  useEffect(() => {
    setVersionId((selected) =>
      selected &&
      versions.some((version) => version.recipe_version_id === selected)
        ? selected
        : (versions[0]?.recipe_version_id ?? null),
    );
  }, [versions]);

  const version = load.data.recipe_versions.find(
    (item) => item.recipe_version_id === versionId,
  );
  useEffect(() => {
    setComposition(structuredClone(version?.composition ?? []));
    setBasisPortions(String(version?.basis_portions ?? 100));
  }, [version]);

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
    return false;
  };

  const shownDishes = load.data.dishes.filter((item) => {
    const needle = query.trim().toLocaleLowerCase("vi");
    return (
      !needle ||
      [item.dish_code, item.dish_name, item.dish_category].some((value) =>
        (value ?? "").toLocaleLowerCase("vi").includes(needle),
      )
    );
  });

  const beginDish = (selected?: DishRecord) => {
    setDishEditorId(selected?.dish_id ?? "NEW");
    setDishDraft(
      selected
        ? {
            code: selected.dish_code,
            name: selected.dish_name,
            category: selected.dish_category ?? "",
            notes: selected.operational_notes ?? "",
            displayOrder: String(selected.display_order),
            requiresNeedGeneration: selected.requires_need_generation,
          }
        : emptyDishDraft(),
    );
  };

  const saveDish = async () => {
    if (!api || !dishEditorId) return;
    const displayOrder = Number(dishDraft.displayOrder);
    if (
      !dishDraft.code.trim() ||
      !dishDraft.name.trim() ||
      !Number.isInteger(displayOrder) ||
      displayOrder < 0
    ) {
      setNotice("Mã món, tên món và thứ tự hiển thị không âm là bắt buộc.");
      return;
    }
    const editing = load.data.dishes.find(
      (item) => item.dish_id === dishEditorId,
    );
    const payload = {
      dish_code: dishDraft.code,
      dish_name: dishDraft.name,
      dish_category: dishDraft.category,
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

  const createDraft = async () => {
    if (!api || !dish) return;
    const basis = Number(scopeDraft.basisPortions);
    if (!Number.isInteger(basis) || basis <= 0) {
      setNotice("Số suất cơ sở phải là số nguyên dương.");
      return;
    }
    const created = await command(
      api.createDraft,
      dish.version,
      "RECIPE_DRAFT_CREATE",
      {
        dish_id: dish.dish_id,
        school_type_id: scopeDraft.schoolTypeId || null,
        basis_portions: basis,
      },
    );
    if (created) {
      setScopeDraft(emptyScope());
      setTab("versions");
    }
  };

  const saveComposition = async () => {
    if (!api || !version) return;
    const basis = Number(basisPortions);
    const present = composition.filter(
      (line) => line.line_disposition === "PRESENT",
    );
    if (
      !Number.isInteger(basis) ||
      basis <= 0 ||
      !present.length ||
      present.some(
        (line) =>
          !line.ingredient_id ||
          !line.unit_id ||
          !Number.isFinite(line.quantity_per_basis) ||
          line.quantity_per_basis <= 0,
      ) ||
      new Set(present.map((line) => line.ingredient_id)).size !== present.length
    ) {
      setNotice(
        "BOM cần ít nhất một dòng có nguyên liệu duy nhất, đơn vị và định lượng dương.",
      );
      return;
    }
    await command(
      api.replaceComposition,
      version.version,
      "RECIPE_COMPOSITION_REPLACE",
      {
        recipe_version_id: version.recipe_version_id,
        basis_portions: basis,
        lines: composition as unknown as JsonValue,
      },
    );
  };

  const transitionVersion = async (
    target: "validate" | "release" | "successor",
  ) => {
    if (!api || !version) return;
    const prompts = {
      validate:
        "Xác thực phiên bản này? Sau bước này, BOM trở thành lịch sử bất biến.",
      release:
        "Phát hành cho Lập nhu cầu trong tương lai? Dữ liệu vận hành đã phát hành sẽ không bị tính lại.",
      successor: "Tạo phiên bản kế nhiệm dạng nháp từ thành phần hiện tại?",
    };
    if (!window.confirm(prompts[target])) return;
    if (target === "validate")
      await command(
        api.validateVersion,
        version.version,
        "RECIPE_VERSION_VALIDATE",
        { recipe_version_id: version.recipe_version_id },
      );
    if (target === "release")
      await command(
        api.releaseVersion,
        version.version,
        "RECIPE_VERSION_RELEASE",
        { recipe_version_id: version.recipe_version_id },
      );
    if (target === "successor")
      await command(
        api.createSuccessor,
        version.version,
        "RECIPE_SUCCESSOR_CREATE",
        { recipe_version_id: version.recipe_version_id },
      );
  };

  const addLine = () => {
    const ingredient = load.data.ingredients.find(
      (item) =>
        item.ingredient_status === "ACTIVE" &&
        !composition.some(
          (line) =>
            line.line_disposition === "PRESENT" &&
            line.ingredient_id === item.ingredient_id,
        ),
    );
    const unit = load.data.units.find((item) => item.unit_status === "ACTIVE");
    if (!ingredient || !unit) {
      setNotice("Không còn nguyên liệu hoặc đơn vị đang hoạt động để thêm.");
      return;
    }
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
  };

  const removeLine = (line: RecipeCompositionLine) => {
    if (line.predecessor_recipe_line_revision_id) {
      setComposition((lines) =>
        lines.map((item) =>
          item.recipe_line_id === line.recipe_line_id
            ? { ...item, line_disposition: "REMOVED", quantity_per_basis: 0 }
            : item,
        ),
      );
    } else {
      setComposition((lines) =>
        lines.filter((item) => item.recipe_line_id !== line.recipe_line_id),
      );
    }
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
        title="Danh mục món ăn và công thức"
        description="Quản lý phạm vi, phiên bản và BOM có kiểm soát."
        status={<Chip tone="warning">Cần đăng nhập</Chip>}
      >
        <p className="operator-notice warning">
          {authState.status === "session_expired"
            ? "Phiên làm việc đã hết. Vui lòng đăng nhập lại."
            : "Đăng nhập để đọc dữ liệu công thức có thẩm quyền."}
        </p>
      </Panel>
    );
  }

  return (
    <Panel
      title="Danh mục món ăn và công thức"
      description="Một món có công thức chung hoặc công thức theo loại trường; mỗi thay đổi được lưu bằng phiên bản kế nhiệm."
      status={
        <Chip tone={load.status === "error" ? "danger" : "ok"}>
          {mode === "review" ? "Dữ liệu xem thử" : "Kết nối Atlas"}
        </Chip>
      }
    >
      <div
        className="confirmed-need-summary"
        aria-label="Tóm tắt quản trị món ăn và công thức"
      >
        <article>
          <span>Món ăn</span>
          <strong>{load.data.dishes.length}</strong>
        </article>
        <article>
          <span>Phạm vi công thức</span>
          <strong>{load.data.recipes.length}</strong>
        </article>
        <article>
          <span>Bản nháp</span>
          <strong>
            {
              load.data.recipe_versions.filter(
                (item) => item.recipe_version_status === "DRAFT",
              ).length
            }
          </strong>
        </article>
        <article>
          <span>Đang phát hành</span>
          <strong>
            {
              load.data.recipe_versions.filter(
                (item) =>
                  item.recipe_version_status === "RELEASED_FOR_PLANNING",
              ).length
            }
          </strong>
        </article>
      </div>

      <div className="master-data-tabs" role="tablist">
        {(
          [
            ["catalog", "Món ăn"],
            ["versions", "Phiên bản & BOM"],
            ["adjustments", "Quy tắc điều chỉnh"],
            ["effective", "BOM hiệu lực"],
            ["copy", "Sao chép"],
            ["import", "Nhập workbook"],
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

      {tab === "adjustments" && (
        <RecipeAdjustmentWorkbench
          authState={authState}
          api={adjustmentApi}
          view="rules"
          mode={mode}
        />
      )}

      {tab === "effective" && (
        <RecipeAdjustmentWorkbench
          authState={authState}
          api={adjustmentApi}
          view="effective"
          mode={mode}
        />
      )}

      {tab === "catalog" && (
        <>
          <div className="master-data-toolbar">
            <label className="evidence-field">
              Tìm món ăn
              <input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Tên, mã hoặc nhóm món"
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
                headers={["Món ăn", "Nhóm", "Trạng thái", "Phạm vi", ""]}
              >
                {shownDishes.map((item) => (
                  <tr key={item.dish_id}>
                    <td>
                      <strong>{item.dish_name}</strong>
                      <small>{item.dish_code}</small>
                    </td>
                    <td>{item.dish_category ?? "—"}</td>
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
                            setDishId(item.dish_id);
                            setTab("versions");
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
                  <div className="master-data-detail-form">
                    <h4>Tạo phạm vi và bản nháp đầu tiên</h4>
                    <label className="evidence-field">
                      Loại trường
                      <select
                        value={scopeDraft.schoolTypeId}
                        onChange={(event) =>
                          setScopeDraft((state) => ({
                            ...state,
                            schoolTypeId: event.target.value,
                          }))
                        }
                      >
                        <option value="">Công thức chung</option>
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
                    <label className="evidence-field">
                      Số suất cơ sở
                      <input
                        type="number"
                        min="1"
                        value={scopeDraft.basisPortions}
                        onChange={(event) =>
                          setScopeDraft((state) => ({
                            ...state,
                            basisPortions: event.target.value,
                          }))
                        }
                      />
                    </label>
                    <button
                      type="button"
                      disabled={busy || !api}
                      onClick={() => void createDraft()}
                    >
                      Tạo bản nháp
                    </button>
                  </div>
                </>
              )}
            </aside>
          </div>
        </>
      )}

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
                ["category", "Nhóm món"],
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
