import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { AtlasAuthState } from "../atlas/connection/authSession";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import type { MasterDataApi } from "../atlas/master-data/masterDataApi";
import {
  commandRequest,
  responseArray,
  resultMessage,
  type IngredientMasterData,
  type SupplierMasterData,
  type UnitMasterData,
} from "../atlas/master-data/masterDataModel";

type MasterDataLoad = {
  status: "idle" | "loading" | "ready" | "error";
  ingredients: IngredientMasterData[];
  suppliers: SupplierMasterData[];
  units: UnitMasterData[];
  message?: string;
};

type IngredientDraft = {
  ingredientCode: string;
  ingredientName: string;
  purchaseUnitId: string;
  ingredientType: string;
  shoppingType: string;
  orderStep: string;
};

type SupplierDraft = {
  supplierCode: string;
  supplierName: string;
  contactName: string;
  contactPhone: string;
  contactEmail: string;
};

type PriorityDraft = { supplierId: string; priority: number };
type LifecycleIntent = {
  ingredient: IngredientMasterData;
  status: "ACTIVE" | "INACTIVE" | "ARCHIVED";
} | null;

const emptyIngredient = (): IngredientDraft => ({
  ingredientCode: "",
  ingredientName: "",
  purchaseUnitId: "",
  ingredientType: "",
  shoppingType: "",
  orderStep: "",
});

const emptySupplier = (): SupplierDraft => ({
  supplierCode: "",
  supplierName: "",
  contactName: "",
  contactPhone: "",
  contactEmail: "",
});

const ingredientStatusLabel = (
  status: IngredientMasterData["ingredient_status"],
) =>
  ({
    ACTIVE: "Đang dùng",
    INACTIVE: "Ngừng dùng",
    ARCHIVED: "Lưu trữ",
  })[status];

const supplierStatusLabel = (status: SupplierMasterData["supplier_status"]) =>
  ({
    ACTIVE: "Đang hợp tác",
    INACTIVE: "Ngừng hợp tác",
    SUSPENDED: "Tạm dừng",
  })[status];

export function IngredientSupplierAdminWorkbench({
  authState,
  api,
  mode = "connected",
}: {
  authState: AtlasAuthState;
  api?: MasterDataApi;
  mode?: "connected" | "review";
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [load, setLoad] = useState<MasterDataLoad>({
    status: "idle",
    ingredients: [],
    suppliers: [],
    units: [],
  });
  const [query, setQuery] = useState("");
  const [supplierQuery, setSupplierQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [catalogTab, setCatalogTab] = useState<"ingredients" | "suppliers">(
    "ingredients",
  );
  const [ingredientId, setIngredientId] = useState<string | null>(null);
  const [ingredientDraft, setIngredientDraft] =
    useState<IngredientDraft>(emptyIngredient);
  const [supplierId, setSupplierId] = useState<string | null>(null);
  const [supplierDraft, setSupplierDraft] =
    useState<SupplierDraft>(emptySupplier);
  const [priorityIngredientId, setPriorityIngredientId] = useState<
    string | null
  >(null);
  const [priorities, setPriorities] = useState<PriorityDraft[]>([]);
  const [lifecycleIntent, setLifecycleIntent] = useState<LifecycleIntent>(null);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const requestGeneration = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;

  const refresh = useCallback(async () => {
    if (!api || !authSubject) return false;
    const generation = ++requestGeneration.current;
    setLoad((current) => ({
      ...current,
      status: "loading",
      message: undefined,
    }));
    const result = await api.getIngredientsAndSuppliers(
      authSubject,
      correlationId,
    );
    if (generation !== requestGeneration.current) return false;
    const ingredients = responseArray<IngredientMasterData>(
      result,
      "ingredients",
    );
    const suppliers = responseArray<SupplierMasterData>(result, "suppliers");
    const units = responseArray<UnitMasterData>(result, "units");
    if (!ingredients || !suppliers || !units) {
      setLoad((current) => ({
        ...current,
        status: "error",
        message: resultMessage(result),
      }));
      return false;
    }
    setLoad({ status: "ready", ingredients, suppliers, units });
    return true;
  }, [api, authSubject, correlationId]);

  useEffect(() => {
    requestGeneration.current += 1;
    setNotice(null);
    setIngredientId(null);
    setSupplierId(null);
    setPriorityIngredientId(null);
    setLifecycleIntent(null);
    if (authSubject) void refresh();
    else
      setLoad({
        status: "idle",
        ingredients: [],
        suppliers: [],
        units: [],
      });
  }, [authSubject, refresh]);

  const shownIngredients = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase("vi");
    return load.ingredients.filter(
      (ingredient) =>
        (statusFilter === "ALL" ||
          ingredient.ingredient_status === statusFilter) &&
        (!normalized ||
          [
            ingredient.ingredient_name,
            ingredient.ingredient_code,
            ingredient.ingredient_type,
            ingredient.shopping_type,
          ].some((value) =>
            (value ?? "").toLocaleLowerCase("vi").includes(normalized),
          )),
    );
  }, [load.ingredients, query, statusFilter]);

  const shownSuppliers = useMemo(() => {
    const normalized = supplierQuery.trim().toLocaleLowerCase("vi");
    if (!normalized) return load.suppliers;
    return load.suppliers.filter((supplier) =>
      [
        supplier.supplier_name,
        supplier.supplier_code,
        supplier.contact_name,
        supplier.contact_phone,
        supplier.contact_email,
      ].some((value) =>
        (value ?? "").toLocaleLowerCase("vi").includes(normalized),
      ),
    );
  }, [load.suppliers, supplierQuery]);
  const visibleIngredients = shownIngredients.slice(0, 60);

  const editingIngredient = load.ingredients.find(
    (item) => item.ingredient_id === ingredientId,
  );
  const editingSupplier = load.suppliers.find(
    (item) => item.supplier_id === supplierId,
  );
  const priorityIngredient = load.ingredients.find(
    (item) => item.ingredient_id === priorityIngredientId,
  );

  const editIngredient = (ingredient?: IngredientMasterData) => {
    setSupplierId(null);
    setPriorityIngredientId(null);
    setLifecycleIntent(null);
    setIngredientId(ingredient?.ingredient_id ?? "NEW");
    setIngredientDraft(
      ingredient
        ? {
            ingredientCode: ingredient.ingredient_code,
            ingredientName: ingredient.ingredient_name,
            purchaseUnitId: ingredient.purchase_unit_id ?? "",
            ingredientType: ingredient.ingredient_type ?? "",
            shoppingType: ingredient.shopping_type ?? "",
            orderStep: String(ingredient.order_step ?? ""),
          }
        : emptyIngredient(),
    );
    setNotice(null);
  };

  const saveIngredient = async () => {
    if (!api || !authSubject || !ingredientId) return;
    const orderStep = Number(ingredientDraft.orderStep);
    if (
      !ingredientDraft.ingredientCode.trim() ||
      !ingredientDraft.ingredientName.trim() ||
      !ingredientDraft.purchaseUnitId ||
      !ingredientDraft.ingredientType.trim() ||
      !ingredientDraft.shoppingType.trim() ||
      !Number.isFinite(orderStep) ||
      orderStep <= 0
    ) {
      setNotice(
        "Điền đủ mã, tên, đơn vị mua, loại nguyên liệu, loại mua và bước đặt hàng dương.",
      );
      return;
    }
    setBusy(true);
    const creating = ingredientId === "NEW";
    const result = creating
      ? await api.createIngredient(
          commandRequest(authSubject, correlationId, 1, "INGREDIENT_CREATE", {
            ingredient_code: ingredientDraft.ingredientCode,
            ingredient_name: ingredientDraft.ingredientName,
            purchase_unit_id: ingredientDraft.purchaseUnitId,
            ingredient_type: ingredientDraft.ingredientType,
            shopping_type: ingredientDraft.shoppingType,
            order_step: orderStep,
          }),
        )
      : await api.updateIngredient(
          commandRequest(
            authSubject,
            correlationId,
            editingIngredient?.version ?? 1,
            "INGREDIENT_UPDATE",
            {
              ingredient_id: ingredientId,
              ingredient_name: ingredientDraft.ingredientName,
              purchase_unit_id: ingredientDraft.purchaseUnitId,
              ingredient_type: ingredientDraft.ingredientType,
              shopping_type: ingredientDraft.shoppingType,
              order_step: orderStep,
            },
          ),
        );
    setBusy(false);
    setNotice(resultMessage(result));
    if (result.kind === "success") {
      await refresh();
      setIngredientId(null);
    }
  };

  const changeLifecycle = async (
    ingredient: IngredientMasterData,
    status: "ACTIVE" | "INACTIVE" | "ARCHIVED",
  ) => {
    if (!api || !authSubject) return;
    setBusy(true);
    const result = await api.setIngredientLifecycle(
      commandRequest(
        authSubject,
        correlationId,
        ingredient.version,
        "INGREDIENT_LIFECYCLE",
        {
          ingredient_id: ingredient.ingredient_id,
          ingredient_status: status,
        },
      ),
    );
    setBusy(false);
    setNotice(resultMessage(result));
    if (result.kind === "success") await refresh();
    setLifecycleIntent(null);
  };

  const editSupplier = (supplier?: SupplierMasterData) => {
    setIngredientId(null);
    setPriorityIngredientId(null);
    setLifecycleIntent(null);
    setSupplierId(supplier?.supplier_id ?? "NEW");
    setSupplierDraft(
      supplier
        ? {
            supplierCode: supplier.supplier_code,
            supplierName: supplier.supplier_name,
            contactName: supplier.contact_name ?? "",
            contactPhone: supplier.contact_phone ?? "",
            contactEmail: supplier.contact_email ?? "",
          }
        : emptySupplier(),
    );
    setNotice(null);
  };

  const saveSupplier = async () => {
    if (!api || !authSubject || !supplierId) return;
    if (
      !supplierDraft.supplierCode.trim() ||
      !supplierDraft.supplierName.trim()
    ) {
      setNotice("Mã và tên nhà cung cấp là bắt buộc.");
      return;
    }
    setBusy(true);
    const creating = supplierId === "NEW";
    const payload = {
      supplier_name: supplierDraft.supplierName,
      contact_name: supplierDraft.contactName,
      contact_phone: supplierDraft.contactPhone,
      contact_email: supplierDraft.contactEmail,
    };
    const result = creating
      ? await api.createSupplier(
          commandRequest(authSubject, correlationId, 1, "SUPPLIER_CREATE", {
            supplier_code: supplierDraft.supplierCode,
            ...payload,
          }),
        )
      : await api.updateSupplier(
          commandRequest(
            authSubject,
            correlationId,
            editingSupplier?.version ?? 1,
            "SUPPLIER_UPDATE",
            { supplier_id: supplierId, ...payload },
          ),
        );
    setBusy(false);
    setNotice(resultMessage(result));
    if (result.kind === "success") {
      await refresh();
      setSupplierId(null);
    }
  };

  const editPriorities = (ingredient: IngredientMasterData) => {
    setIngredientId(null);
    setSupplierId(null);
    setLifecycleIntent(null);
    setPriorityIngredientId(ingredient.ingredient_id);
    setPriorities(
      ingredient.supplier_priorities.map((item) => ({
        supplierId: item.supplier_id,
        priority: item.priority,
      })),
    );
    setNotice(null);
  };

  const addPriority = () => {
    const supplier = load.suppliers.find(
      (item) =>
        item.supplier_status === "ACTIVE" &&
        !priorities.some(
          (priority) => priority.supplierId === item.supplier_id,
        ),
    );
    if (!supplier || priorities.length >= 6) return;
    const used = new Set(priorities.map((item) => item.priority));
    const priority =
      [1, 2, 3, 4, 5, 6].find((candidate) => !used.has(candidate)) ?? 6;
    setPriorities((current) => [
      ...current,
      { supplierId: supplier.supplier_id, priority },
    ]);
  };

  const savePriorities = async () => {
    if (!api || !authSubject || !priorityIngredient) return;
    const supplierIds = priorities.map((item) => item.supplierId);
    const priorityValues = priorities.map((item) => item.priority);
    if (
      priorities.length > 6 ||
      new Set(supplierIds).size !== supplierIds.length ||
      new Set(priorityValues).size !== priorityValues.length ||
      priorityValues.some(
        (priority) =>
          !Number.isInteger(priority) || priority < 1 || priority > 6,
      )
    ) {
      setNotice(
        "Tối đa sáu nhà cung cấp; nhà cung cấp và mức ưu tiên 1–6 không được trùng.",
      );
      return;
    }
    setBusy(true);
    const result = await api.replacePriorities(
      commandRequest(
        authSubject,
        correlationId,
        priorityIngredient.version,
        "INGREDIENT_SUPPLIER_PRIORITIES_REPLACE",
        {
          ingredient_id: priorityIngredient.ingredient_id,
          priorities: priorities.map((item) => ({
            supplier_id: item.supplierId,
            priority: item.priority,
          })),
        },
      ),
    );
    setBusy(false);
    setNotice(resultMessage(result));
    if (result.kind === "success") {
      await refresh();
      setPriorityIngredientId(null);
    }
  };

  if (!authSubject) {
    return (
      <Panel
        title="Danh mục nguyên liệu và nhà cung ứng"
        description="Tìm kiếm, duy trì trạng thái và sắp xếp nhà cung ứng ưu tiên."
        status={<Chip tone="warning">Cần đăng nhập</Chip>}
      >
        <p className="operator-notice warning">
          {authState.status === "session_expired"
            ? "Phiên làm việc đã hết. Vui lòng đăng nhập lại để tiếp tục."
            : "Đăng nhập để xem và cập nhật dữ liệu."}
        </p>
      </Panel>
    );
  }

  return (
    <Panel
      title="Danh mục nguyên liệu và nhà cung ứng"
      description="Tìm kiếm, tạo, sửa, quản lý vòng đời và thứ tự ưu tiên nhà cung ứng."
      status={
        <Chip tone={load.status === "error" ? "danger" : "ok"}>
          {load.status === "error"
            ? "Không tải được"
            : mode === "review"
              ? "Dữ liệu xem thử"
              : "Đã kết nối"}
        </Chip>
      }
    >
      <div className="master-data-tabs" role="tablist">
        <button
          type="button"
          role="tab"
          aria-selected={catalogTab === "ingredients"}
          className={catalogTab === "ingredients" ? "active" : ""}
          onClick={() => setCatalogTab("ingredients")}
        >
          Nguyên liệu <span>{load.ingredients.length}</span>
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={catalogTab === "suppliers"}
          className={catalogTab === "suppliers" ? "active" : ""}
          onClick={() => setCatalogTab("suppliers")}
        >
          Nhà cung ứng <span>{load.suppliers.length}</span>
        </button>
      </div>

      {catalogTab === "ingredients" ? (
        <div className="master-data-toolbar">
          <label className="evidence-field">
            Tìm nguyên liệu
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Tên, mã, loại nguyên liệu hoặc cách mua"
            />
          </label>
          <label className="evidence-field">
            Trạng thái
            <select
              value={statusFilter}
              onChange={(event) => setStatusFilter(event.target.value)}
            >
              <option value="ALL">Tất cả</option>
              <option value="ACTIVE">Đang dùng</option>
              <option value="INACTIVE">Ngừng dùng</option>
              <option value="ARCHIVED">Lưu trữ</option>
            </select>
          </label>
          <button type="button" onClick={() => void refresh()}>
            Tải lại
          </button>
          <button
            type="button"
            className="primary-toolbar-action"
            onClick={() => editIngredient()}
          >
            Tạo nguyên liệu
          </button>
        </div>
      ) : (
        <div className="master-data-toolbar suppliers-toolbar">
          <label className="evidence-field">
            Tìm nhà cung ứng
            <input
              value={supplierQuery}
              onChange={(event) => setSupplierQuery(event.target.value)}
              placeholder="Tên, mã, người liên hệ, điện thoại hoặc email"
            />
          </label>
          <button type="button" onClick={() => void refresh()}>
            Tải lại
          </button>
          <button
            type="button"
            className="primary-toolbar-action"
            onClick={() => editSupplier()}
          >
            Tạo nhà cung ứng
          </button>
        </div>
      )}

      {load.status === "loading" && load.ingredients.length === 0 && (
        <p role="status" className="empty">
          Đang tải nguyên liệu và nhà cung ứng…
        </p>
      )}
      {load.status === "error" && (
        <div className="command-outcome danger" role="alert">
          <p>{load.message}</p>
          <button type="button" onClick={() => void refresh()}>
            Thử lại
          </button>
        </div>
      )}

      {catalogTab === "ingredients" && load.status === "ready" && (
        <>
          {load.ingredients.length === 0 ? (
            <p className="empty">Chưa có nguyên liệu.</p>
          ) : shownIngredients.length === 0 ? (
            <p className="empty">Không có nguyên liệu phù hợp bộ lọc.</p>
          ) : (
            <div className="master-data-table-scroll">
              <CompactTable
                headers={[
                  "Nguyên liệu",
                  "Trạng thái",
                  "Đơn vị mua",
                  "Loại / cách mua",
                  "Bước đặt",
                  "Ưu tiên nhà cung ứng",
                  "Thao tác",
                ]}
              >
                {visibleIngredients.map((ingredient) => (
                  <tr key={ingredient.ingredient_id}>
                    <td>
                      <b>{ingredient.ingredient_name}</b>
                      <small>{ingredient.ingredient_code}</small>
                    </td>
                    <td>
                      <Chip
                        tone={
                          ingredient.ingredient_status === "ACTIVE"
                            ? "ok"
                            : "warning"
                        }
                      >
                        {ingredientStatusLabel(ingredient.ingredient_status)}
                      </Chip>
                    </td>
                    <td>
                      {ingredient.purchase_unit_name ?? "Chưa đặt"}
                      <small>{ingredient.purchase_unit_code}</small>
                    </td>
                    <td>
                      {ingredient.ingredient_type ?? "Chưa đặt"}
                      <small>{ingredient.shopping_type ?? "Chưa đặt"}</small>
                    </td>
                    <td>{ingredient.order_step ?? "—"}</td>
                    <td>
                      {ingredient.supplier_priorities.length ? (
                        <ol className="supplier-priority-preview">
                          {ingredient.supplier_priorities.map((item) => (
                            <li key={item.supplier_eligibility_id}>
                              <b>{item.priority}</b>
                              <span>{item.supplier_name}</span>
                            </li>
                          ))}
                        </ol>
                      ) : (
                        "Chưa có"
                      )}
                    </td>
                    <td>
                      <div className="master-data-row-actions">
                        <button
                          className="inline-action"
                          type="button"
                          disabled={ingredient.ingredient_status === "ARCHIVED"}
                          onClick={() => editIngredient(ingredient)}
                        >
                          Sửa
                        </button>
                        <button
                          className="inline-action"
                          type="button"
                          disabled={ingredient.ingredient_status !== "ACTIVE"}
                          onClick={() => editPriorities(ingredient)}
                        >
                          Ưu tiên
                        </button>
                        {ingredient.ingredient_status === "ACTIVE" ? (
                          <button
                            className="inline-action danger-action"
                            type="button"
                            disabled={busy}
                            onClick={() =>
                              setLifecycleIntent({
                                ingredient,
                                status: "INACTIVE",
                              })
                            }
                          >
                            Ngừng dùng
                          </button>
                        ) : ingredient.ingredient_status === "INACTIVE" ? (
                          <>
                            <button
                              className="inline-action"
                              type="button"
                              disabled={busy}
                              onClick={() =>
                                setLifecycleIntent({
                                  ingredient,
                                  status: "ACTIVE",
                                })
                              }
                            >
                              Kích hoạt
                            </button>
                            <button
                              className="inline-action danger-action"
                              type="button"
                              disabled={busy}
                              onClick={() =>
                                setLifecycleIntent({
                                  ingredient,
                                  status: "ARCHIVED",
                                })
                              }
                            >
                              Lưu trữ
                            </button>
                          </>
                        ) : null}
                      </div>
                    </td>
                  </tr>
                ))}
              </CompactTable>
            </div>
          )}
        </>
      )}

      {catalogTab === "suppliers" && load.status === "ready" && (
        <>
          {load.suppliers.length === 0 ? (
            <p className="empty">Chưa có nhà cung ứng.</p>
          ) : shownSuppliers.length === 0 ? (
            <p className="empty">Không có nhà cung ứng phù hợp tìm kiếm.</p>
          ) : (
            <div className="master-data-table-scroll suppliers-table">
              <CompactTable
                headers={[
                  "Nhà cung ứng",
                  "Trạng thái",
                  "Người liên hệ",
                  "Điện thoại",
                  "Email",
                  "Thao tác",
                ]}
              >
                {shownSuppliers.map((supplier) => (
                  <tr key={supplier.supplier_id}>
                    <td>
                      <b>{supplier.supplier_name}</b>
                      <small>{supplier.supplier_code}</small>
                    </td>
                    <td>{supplierStatusLabel(supplier.supplier_status)}</td>
                    <td>{supplier.contact_name ?? "—"}</td>
                    <td>{supplier.contact_phone ?? "—"}</td>
                    <td>{supplier.contact_email ?? "—"}</td>
                    <td>
                      <button
                        type="button"
                        className="inline-action"
                        onClick={() => editSupplier(supplier)}
                      >
                        Xem và sửa
                      </button>
                    </td>
                  </tr>
                ))}
              </CompactTable>
            </div>
          )}
        </>
      )}

      {ingredientId && (
        <section
          className="master-data-drawer"
          aria-label="Biểu mẫu nguyên liệu"
        >
          <div className="master-data-detail-heading">
            <div>
              <span>Nguyên liệu</span>
              <h3>
                {ingredientId === "NEW" ? "Tạo nguyên liệu" : "Sửa nguyên liệu"}
              </h3>
            </div>
            <button
              type="button"
              aria-label="Đóng"
              onClick={() => setIngredientId(null)}
            >
              ×
            </button>
          </div>
          <div className="master-data-drawer-body">
            <div className="master-data-form-grid">
              <label className="evidence-field">
                Mã nguyên liệu
                <input
                  disabled={ingredientId !== "NEW"}
                  value={ingredientDraft.ingredientCode}
                  onChange={(event) =>
                    setIngredientDraft((current) => ({
                      ...current,
                      ingredientCode: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="evidence-field">
                Tên nguyên liệu
                <input
                  value={ingredientDraft.ingredientName}
                  onChange={(event) =>
                    setIngredientDraft((current) => ({
                      ...current,
                      ingredientName: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="evidence-field">
                Đơn vị mua
                <select
                  value={ingredientDraft.purchaseUnitId}
                  onChange={(event) =>
                    setIngredientDraft((current) => ({
                      ...current,
                      purchaseUnitId: event.target.value,
                    }))
                  }
                >
                  <option value="">Chọn đơn vị</option>
                  {load.units
                    .filter((unit) => unit.unit_status === "ACTIVE")
                    .map((unit) => (
                      <option key={unit.unit_id} value={unit.unit_id}>
                        {unit.unit_name} ({unit.unit_code})
                      </option>
                    ))}
                </select>
              </label>
              <label className="evidence-field">
                Loại nguyên liệu
                <input
                  value={ingredientDraft.ingredientType}
                  onChange={(event) =>
                    setIngredientDraft((current) => ({
                      ...current,
                      ingredientType: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="evidence-field">
                Cách mua
                <input
                  value={ingredientDraft.shoppingType}
                  onChange={(event) =>
                    setIngredientDraft((current) => ({
                      ...current,
                      shoppingType: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="evidence-field">
                Bước đặt hàng
                <input
                  type="number"
                  min="0.000001"
                  step="any"
                  value={ingredientDraft.orderStep}
                  onChange={(event) =>
                    setIngredientDraft((current) => ({
                      ...current,
                      orderStep: event.target.value,
                    }))
                  }
                />
              </label>
            </div>
            <div className="workbench-actions">
              <button
                type="button"
                className="primary"
                disabled={busy}
                onClick={() => void saveIngredient()}
              >
                {busy ? "Đang lưu…" : "Lưu thay đổi"}
              </button>
              <button type="button" onClick={() => setIngredientId(null)}>
                Hủy
              </button>
            </div>
          </div>
        </section>
      )}

      {supplierId && (
        <section
          className="master-data-drawer"
          aria-label="Biểu mẫu nhà cung ứng"
        >
          <div className="master-data-detail-heading">
            <div>
              <span>Nhà cung ứng</span>
              <h3>
                {supplierId === "NEW" ? "Tạo nhà cung ứng" : "Sửa nhà cung ứng"}
              </h3>
            </div>
            <button
              type="button"
              aria-label="Đóng"
              onClick={() => setSupplierId(null)}
            >
              ×
            </button>
          </div>
          <div className="master-data-drawer-body">
            <div className="master-data-form-grid">
              <label className="evidence-field">
                Mã nhà cung ứng
                <input
                  disabled={supplierId !== "NEW"}
                  value={supplierDraft.supplierCode}
                  onChange={(event) =>
                    setSupplierDraft((current) => ({
                      ...current,
                      supplierCode: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="evidence-field">
                Tên nhà cung ứng
                <input
                  value={supplierDraft.supplierName}
                  onChange={(event) =>
                    setSupplierDraft((current) => ({
                      ...current,
                      supplierName: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="evidence-field">
                Người liên hệ
                <input
                  value={supplierDraft.contactName}
                  onChange={(event) =>
                    setSupplierDraft((current) => ({
                      ...current,
                      contactName: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="evidence-field">
                Điện thoại
                <input
                  value={supplierDraft.contactPhone}
                  onChange={(event) =>
                    setSupplierDraft((current) => ({
                      ...current,
                      contactPhone: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="evidence-field">
                Email
                <input
                  type="email"
                  value={supplierDraft.contactEmail}
                  onChange={(event) =>
                    setSupplierDraft((current) => ({
                      ...current,
                      contactEmail: event.target.value,
                    }))
                  }
                />
              </label>
            </div>
            <div className="workbench-actions">
              <button
                type="button"
                className="primary"
                disabled={busy}
                onClick={() => void saveSupplier()}
              >
                {busy ? "Đang lưu…" : "Lưu thay đổi"}
              </button>
              <button type="button" onClick={() => setSupplierId(null)}>
                Hủy
              </button>
            </div>
          </div>
        </section>
      )}

      {priorityIngredient && (
        <section
          className="master-data-drawer priority-drawer"
          aria-label="Sắp xếp ưu tiên nhà cung ứng"
        >
          <div className="master-data-detail-heading">
            <div>
              <span>Ưu tiên nhà cung ứng</span>
              <h3>{priorityIngredient.ingredient_name}</h3>
            </div>
            <button
              type="button"
              aria-label="Đóng"
              onClick={() => setPriorityIngredientId(null)}
            >
              ×
            </button>
          </div>
          <div className="master-data-drawer-body">
            <p className="drawer-guidance">
              Có thể để trống hoặc chọn tối đa sáu nhà cung ứng. Mỗi nhà cung
              ứng và mỗi mức ưu tiên từ 1 đến 6 chỉ được dùng một lần.
            </p>
            {priorities.length === 0 && (
              <p className="empty compact-empty">
                Chưa có nhà cung ứng ưu tiên.
              </p>
            )}
            {priorities.map((item, index) => (
              <div
                className="master-data-priority-row"
                key={`${item.supplierId}:${index}`}
              >
                <b className="priority-order">{index + 1}</b>
                <label className="evidence-field">
                  Nhà cung ứng
                  <select
                    aria-label={`Nhà cung ứng ưu tiên ${index + 1}`}
                    value={item.supplierId}
                    onChange={(event) =>
                      setPriorities((current) =>
                        current.map((priority, currentIndex) =>
                          currentIndex === index
                            ? { ...priority, supplierId: event.target.value }
                            : priority,
                        ),
                      )
                    }
                  >
                    {load.suppliers
                      .filter(
                        (supplier) => supplier.supplier_status === "ACTIVE",
                      )
                      .map((supplier) => (
                        <option
                          key={supplier.supplier_id}
                          value={supplier.supplier_id}
                        >
                          {supplier.supplier_name}
                        </option>
                      ))}
                  </select>
                </label>
                <label className="evidence-field">
                  Mức ưu tiên
                  <input
                    aria-label={`Mức ưu tiên ${index + 1}`}
                    type="number"
                    min="1"
                    max="6"
                    step="1"
                    value={item.priority}
                    onChange={(event) =>
                      setPriorities((current) =>
                        current.map((priority, currentIndex) =>
                          currentIndex === index
                            ? {
                                ...priority,
                                priority: Number(event.target.value),
                              }
                            : priority,
                        ),
                      )
                    }
                  />
                </label>
                <button
                  type="button"
                  onClick={() =>
                    setPriorities((current) =>
                      current.filter(
                        (_, currentIndex) => currentIndex !== index,
                      ),
                    )
                  }
                >
                  Gỡ
                </button>
              </div>
            ))}
            <div className="workbench-actions">
              <button
                type="button"
                disabled={priorities.length >= 6}
                onClick={addPriority}
              >
                Thêm nhà cung ứng
              </button>
              <button
                type="button"
                className="primary"
                disabled={busy}
                onClick={() => void savePriorities()}
              >
                {busy ? "Đang lưu…" : "Lưu thứ tự ưu tiên"}
              </button>
              <button
                type="button"
                onClick={() => setPriorityIngredientId(null)}
              >
                Hủy
              </button>
            </div>
          </div>
        </section>
      )}

      {lifecycleIntent && (
        <section
          className="master-data-drawer lifecycle-drawer"
          aria-label="Xác nhận thay đổi trạng thái"
        >
          <div className="master-data-detail-heading">
            <div>
              <span>Thay đổi trạng thái</span>
              <h3>{lifecycleIntent.ingredient.ingredient_name}</h3>
            </div>
            <button
              type="button"
              aria-label="Đóng"
              onClick={() => setLifecycleIntent(null)}
            >
              ×
            </button>
          </div>
          <div className="master-data-drawer-body">
            <div className="operator-notice warning">
              <b>Xác nhận trước khi tiếp tục</b>
              <p>
                Trạng thái mới:{" "}
                <strong>{ingredientStatusLabel(lifecycleIntent.status)}</strong>
                . Khi ngừng dùng hoặc lưu trữ, danh sách ưu tiên nhà cung ứng
                của nguyên liệu sẽ được gỡ.
              </p>
            </div>
            <div className="workbench-actions">
              <button
                type="button"
                className="primary"
                disabled={busy}
                onClick={() =>
                  void changeLifecycle(
                    lifecycleIntent.ingredient,
                    lifecycleIntent.status,
                  )
                }
              >
                {busy ? "Đang cập nhật…" : "Xác nhận thay đổi"}
              </button>
              <button type="button" onClick={() => setLifecycleIntent(null)}>
                Hủy
              </button>
            </div>
          </div>
        </section>
      )}

      {notice && (
        <p
          className={
            notice.includes("không") ||
            notice.includes("thay đổi") ||
            notice.includes("hết")
              ? "operator-notice warning"
              : "operator-notice success"
          }
          role="status"
        >
          {notice}
        </p>
      )}
    </Panel>
  );
}
