import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Modal } from "@mantine/core";
import type { AtlasAuthState } from "../atlas/connection/authSession";
import type { AtlasRpcResult } from "../atlas/connection/atlasRpc";
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
type Notice = {
  tone: "success" | "warning" | "danger";
  message: string;
  requiresRefresh?: boolean;
};

type IngredientReviewValues = IngredientDraft & {
  orderStepValue: number;
  purchaseUnitLabel: string;
};

type SupplierReviewValues = SupplierDraft;

type ReviewedPriority = PriorityDraft & { supplierName: string };

type ReviewSnapshot =
  | {
      kind: "ingredient";
      mode: "create" | "update";
      objectId: string | null;
      expectedVersion: number;
      before: IngredientReviewValues | null;
      after: IngredientReviewValues;
      payload: Record<string, string | number>;
    }
  | {
      kind: "supplier";
      mode: "create" | "update";
      objectId: string | null;
      expectedVersion: number;
      before: SupplierReviewValues | null;
      after: SupplierReviewValues;
      payload: Record<string, string>;
    }
  | {
      kind: "priorities";
      ingredientId: string;
      ingredientName: string;
      expectedVersion: number;
      before: ReviewedPriority[];
      after: ReviewedPriority[];
      payload: {
        ingredient_id: string;
        priorities: { supplier_id: string; priority: number }[];
      };
    };
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

const ingredientDraftFor = (
  ingredient: IngredientMasterData,
): IngredientDraft => ({
  ingredientCode: ingredient.ingredient_code,
  ingredientName: ingredient.ingredient_name,
  purchaseUnitId: ingredient.purchase_unit_id ?? "",
  ingredientType: ingredient.ingredient_type ?? "",
  shoppingType: ingredient.shopping_type ?? "",
  orderStep: String(ingredient.order_step ?? ""),
});

const supplierDraftFor = (supplier: SupplierMasterData): SupplierDraft => ({
  supplierCode: supplier.supplier_code,
  supplierName: supplier.supplier_name,
  contactName: supplier.contact_name ?? "",
  contactPhone: supplier.contact_phone ?? "",
  contactEmail: supplier.contact_email ?? "",
});

const sameIngredientDraft = (left: IngredientDraft, right: IngredientDraft) =>
  Object.keys(left).every(
    (key) =>
      left[key as keyof IngredientDraft] ===
      right[key as keyof IngredientDraft],
  );

const sameSupplierDraft = (left: SupplierDraft, right: SupplierDraft) =>
  Object.keys(left).every(
    (key) =>
      left[key as keyof SupplierDraft] === right[key as keyof SupplierDraft],
  );

const samePriorities = (left: PriorityDraft[], right: PriorityDraft[]) => {
  const normalize = (items: PriorityDraft[]) =>
    items
      .map((item) => `${item.supplierId}:${item.priority}`)
      .sort((a, b) => a.localeCompare(b));
  return JSON.stringify(normalize(left)) === JSON.stringify(normalize(right));
};

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
  const [mutationLocked, setMutationLocked] = useState(false);
  const [notice, setNotice] = useState<Notice | null>(null);
  const [reviewSnapshot, setReviewSnapshot] = useState<ReviewSnapshot | null>(
    null,
  );
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
    setReviewSnapshot(null);
    setMutationLocked(false);
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

  const resetSurfaces = () => {
    setIngredientId(null);
    setIngredientDraft(emptyIngredient());
    setSupplierId(null);
    setSupplierDraft(emptySupplier());
    setPriorityIngredientId(null);
    setPriorities([]);
    setLifecycleIntent(null);
    setReviewSnapshot(null);
  };

  const reloadAuthoritative = async () => {
    if (busy) return;
    setNotice(null);
    setReviewSnapshot(null);
    const refreshed = await refresh();
    if (refreshed) {
      resetSurfaces();
      setMutationLocked(false);
      setNotice({
        tone: "warning",
        message:
          "Đã tải lại dữ liệu chính thức. Hãy mở lại mục cần sửa và áp dụng lại thay đổi nếu vẫn cần.",
      });
    }
  };

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

  const editingIngredient = load.ingredients.find(
    (item) => item.ingredient_id === ingredientId,
  );
  const editingSupplier = load.suppliers.find(
    (item) => item.supplier_id === supplierId,
  );
  const priorityIngredient = load.ingredients.find(
    (item) => item.ingredient_id === priorityIngredientId,
  );

  const ingredientOrderStep = Number(ingredientDraft.orderStep);
  const ingredientValid =
    Boolean(ingredientDraft.ingredientCode.trim()) &&
    Boolean(ingredientDraft.ingredientName.trim()) &&
    Boolean(ingredientDraft.purchaseUnitId) &&
    Boolean(ingredientDraft.ingredientType.trim()) &&
    Boolean(ingredientDraft.shoppingType.trim()) &&
    Number.isFinite(ingredientOrderStep) &&
    ingredientOrderStep > 0;
  const ingredientDirty =
    ingredientId === "NEW"
      ? Object.values(ingredientDraft).some(Boolean)
      : Boolean(
          editingIngredient &&
          !sameIngredientDraft(
            ingredientDraft,
            ingredientDraftFor(editingIngredient),
          ),
        );
  const supplierValid =
    Boolean(supplierDraft.supplierCode.trim()) &&
    Boolean(supplierDraft.supplierName.trim());
  const supplierDirty =
    supplierId === "NEW"
      ? Object.values(supplierDraft).some(Boolean)
      : Boolean(
          editingSupplier &&
          !sameSupplierDraft(supplierDraft, supplierDraftFor(editingSupplier)),
        );
  const authoritativePriorities =
    priorityIngredient?.supplier_priorities.map((item) => ({
      supplierId: item.supplier_id,
      priority: item.priority,
    })) ?? [];
  const prioritySupplierIds = priorities.map((item) => item.supplierId);
  const priorityValues = priorities.map((item) => item.priority);
  const prioritiesValid =
    priorities.length <= 6 &&
    prioritySupplierIds.every(Boolean) &&
    new Set(prioritySupplierIds).size === prioritySupplierIds.length &&
    new Set(priorityValues).size === priorityValues.length &&
    priorityValues.every(
      (priority) =>
        Number.isInteger(priority) && priority >= 1 && priority <= 6,
    );
  const prioritiesDirty = Boolean(
    priorityIngredient && !samePriorities(priorities, authoritativePriorities),
  );

  const setIngredientField = (field: keyof IngredientDraft, value: string) => {
    setNotice(null);
    setReviewSnapshot(null);
    setIngredientDraft((current) => ({ ...current, [field]: value }));
  };

  const setSupplierField = (field: keyof SupplierDraft, value: string) => {
    setNotice(null);
    setReviewSnapshot(null);
    setSupplierDraft((current) => ({ ...current, [field]: value }));
  };

  const setPriorityDrafts = (
    update: (current: PriorityDraft[]) => PriorityDraft[],
  ) => {
    setNotice(null);
    setReviewSnapshot(null);
    setPriorities(update);
  };

  const handleWriteResult = async (
    result: AtlasRpcResult,
    successMessage: string,
  ) => {
    setReviewSnapshot(null);
    if (result.kind === "transport_error") {
      setMutationLocked(true);
      setNotice({
        tone: "danger",
        requiresRefresh: true,
        message:
          "Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa. Không gửi lại thao tác; hãy tải lại dữ liệu chính thức trước khi tiếp tục.",
      });
      return;
    }
    if (result.kind === "success") {
      const refreshed = await refresh();
      if (refreshed) {
        resetSurfaces();
        setMutationLocked(false);
        setNotice({ tone: "success", message: successMessage });
      } else {
        setMutationLocked(true);
        setNotice({
          tone: "danger",
          requiresRefresh: true,
          message:
            "Thao tác đã được chấp nhận nhưng chưa tải lại được dữ liệu chính thức. Không gửi lại thao tác; hãy tải lại dữ liệu trước khi tiếp tục.",
        });
      }
      return;
    }
    const stale =
      result.kind === "backend_error" &&
      result.error.error_code === "STALE_VERSION";
    if (stale) setMutationLocked(true);
    setNotice({
      tone: result.kind === "backend_error" ? "warning" : "danger",
      requiresRefresh: stale,
      message: stale
        ? "Dữ liệu chính thức đã được người khác cập nhật. Không có thay đổi nào từ lần lưu này được chấp nhận; hãy tải lại rồi mở lại mục cần sửa."
        : resultMessage(result),
    });
  };

  const editIngredient = (ingredient?: IngredientMasterData) => {
    resetSurfaces();
    setIngredientId(ingredient?.ingredient_id ?? "NEW");
    setIngredientDraft(
      ingredient ? ingredientDraftFor(ingredient) : emptyIngredient(),
    );
    setNotice(null);
  };

  const openIngredientReview = () => {
    if (
      busy ||
      mutationLocked ||
      !ingredientId ||
      !ingredientValid ||
      !ingredientDirty
    )
      return;
    const unit = load.units.find(
      (item) => item.unit_id === ingredientDraft.purchaseUnitId,
    );
    const after: IngredientReviewValues = {
      ...ingredientDraft,
      orderStepValue: ingredientOrderStep,
      purchaseUnitLabel: unit
        ? `${unit.unit_name} (${unit.unit_code})`
        : "Chưa chọn",
    };
    const creating = ingredientId === "NEW";
    const before = editingIngredient
      ? {
          ...ingredientDraftFor(editingIngredient),
          orderStepValue: Number(editingIngredient.order_step),
          purchaseUnitLabel: editingIngredient.purchase_unit_name
            ? `${editingIngredient.purchase_unit_name} (${editingIngredient.purchase_unit_code})`
            : "Chưa chọn",
        }
      : null;
    setReviewSnapshot({
      kind: "ingredient",
      mode: creating ? "create" : "update",
      objectId: creating ? null : ingredientId,
      expectedVersion: creating ? 1 : (editingIngredient?.version ?? 1),
      before,
      after,
      payload: creating
        ? {
            ingredient_code: after.ingredientCode,
            ingredient_name: after.ingredientName,
            purchase_unit_id: after.purchaseUnitId,
            ingredient_type: after.ingredientType,
            shopping_type: after.shoppingType,
            order_step: after.orderStepValue,
          }
        : {
            ingredient_id: ingredientId,
            ingredient_name: after.ingredientName,
            purchase_unit_id: after.purchaseUnitId,
            ingredient_type: after.ingredientType,
            shopping_type: after.shoppingType,
            order_step: after.orderStepValue,
          },
    });
  };

  const changeLifecycle = async (
    ingredient: IngredientMasterData,
    status: "ACTIVE" | "INACTIVE" | "ARCHIVED",
  ) => {
    if (!api || !authSubject || busy || mutationLocked) return;
    setBusy(true);
    setNotice(null);
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
    await handleWriteResult(
      result,
      `Đã cập nhật trạng thái ${ingredient.ingredient_name} và tải lại dữ liệu chính thức.`,
    );
  };

  const editSupplier = (supplier?: SupplierMasterData) => {
    resetSurfaces();
    setSupplierId(supplier?.supplier_id ?? "NEW");
    setSupplierDraft(supplier ? supplierDraftFor(supplier) : emptySupplier());
    setNotice(null);
  };

  const openSupplierReview = () => {
    if (
      busy ||
      mutationLocked ||
      !supplierId ||
      !supplierValid ||
      !supplierDirty
    )
      return;
    const creating = supplierId === "NEW";
    const after = { ...supplierDraft };
    const commonPayload = {
      supplier_name: after.supplierName,
      contact_name: after.contactName,
      contact_phone: after.contactPhone,
      contact_email: after.contactEmail,
    };
    setReviewSnapshot({
      kind: "supplier",
      mode: creating ? "create" : "update",
      objectId: creating ? null : supplierId,
      expectedVersion: creating ? 1 : (editingSupplier?.version ?? 1),
      before: editingSupplier ? supplierDraftFor(editingSupplier) : null,
      after,
      payload: creating
        ? { supplier_code: after.supplierCode, ...commonPayload }
        : { supplier_id: supplierId, ...commonPayload },
    });
  };

  const editPriorities = (ingredient: IngredientMasterData) => {
    resetSurfaces();
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
    setPriorityDrafts((current) => [
      ...current,
      { supplierId: supplier.supplier_id, priority },
    ]);
  };

  const priorityWithNames = (items: PriorityDraft[]): ReviewedPriority[] =>
    items.map((item) => ({
      ...item,
      supplierName:
        load.suppliers.find(
          (supplier) => supplier.supplier_id === item.supplierId,
        )?.supplier_name ?? "Nhà cung ứng không còn trong danh mục",
    }));

  const openPriorityReview = () => {
    if (
      busy ||
      mutationLocked ||
      !priorityIngredient ||
      !prioritiesValid ||
      !prioritiesDirty
    )
      return;
    setReviewSnapshot({
      kind: "priorities",
      ingredientId: priorityIngredient.ingredient_id,
      ingredientName: priorityIngredient.ingredient_name,
      expectedVersion: priorityIngredient.version,
      before: priorityWithNames(authoritativePriorities),
      after: priorityWithNames(priorities),
      payload: {
        ingredient_id: priorityIngredient.ingredient_id,
        priorities: priorities.map((item) => ({
          supplier_id: item.supplierId,
          priority: item.priority,
        })),
      },
    });
  };

  const saveReviewed = async () => {
    if (!api || !authSubject || busy || mutationLocked || !reviewSnapshot)
      return;
    const snapshot = reviewSnapshot;
    setBusy(true);
    setNotice(null);
    let result: AtlasRpcResult;
    let successMessage: string;
    if (snapshot.kind === "ingredient") {
      const request = commandRequest(
        authSubject,
        correlationId,
        snapshot.expectedVersion,
        snapshot.mode === "create" ? "INGREDIENT_CREATE" : "INGREDIENT_UPDATE",
        snapshot.payload,
      );
      result =
        snapshot.mode === "create"
          ? await api.createIngredient(request)
          : await api.updateIngredient(request);
      successMessage = `Đã ${snapshot.mode === "create" ? "tạo" : "cập nhật"} nguyên liệu và tải lại dữ liệu chính thức.`;
    } else if (snapshot.kind === "supplier") {
      const request = commandRequest(
        authSubject,
        correlationId,
        snapshot.expectedVersion,
        snapshot.mode === "create" ? "SUPPLIER_CREATE" : "SUPPLIER_UPDATE",
        snapshot.payload,
      );
      result =
        snapshot.mode === "create"
          ? await api.createSupplier(request)
          : await api.updateSupplier(request);
      successMessage = `Đã ${snapshot.mode === "create" ? "tạo" : "cập nhật"} nhà cung ứng và tải lại dữ liệu chính thức.`;
    } else {
      result = await api.replacePriorities(
        commandRequest(
          authSubject,
          correlationId,
          snapshot.expectedVersion,
          "INGREDIENT_SUPPLIER_PRIORITIES_REPLACE",
          snapshot.payload,
        ),
      );
      successMessage =
        "Đã cập nhật ưu tiên nhà cung ứng và tải lại dữ liệu chính thức.";
    }
    setBusy(false);
    await handleWriteResult(result, successMessage);
  };

  const switchCatalogTab = (tab: "ingredients" | "suppliers") => {
    if (tab === catalogTab) return;
    resetSurfaces();
    if (!mutationLocked) setNotice(null);
    setCatalogTab(tab);
  };

  const openLifecycle = (
    ingredient: IngredientMasterData,
    status: "ACTIVE" | "INACTIVE" | "ARCHIVED",
  ) => {
    resetSurfaces();
    setNotice(null);
    setLifecycleIntent({ ingredient, status });
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
          onClick={() => switchCatalogTab("ingredients")}
        >
          Nguyên liệu <span>{load.ingredients.length}</span>
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={catalogTab === "suppliers"}
          className={catalogTab === "suppliers" ? "active" : ""}
          onClick={() => switchCatalogTab("suppliers")}
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
          <button
            type="button"
            disabled={busy || load.status === "loading"}
            onClick={() => void reloadAuthoritative()}
          >
            Tải lại
          </button>
          <button
            type="button"
            className="primary-toolbar-action"
            disabled={busy || mutationLocked}
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
          <button
            type="button"
            disabled={busy || load.status === "loading"}
            onClick={() => void reloadAuthoritative()}
          >
            Tải lại
          </button>
          <button
            type="button"
            className="primary-toolbar-action"
            disabled={busy || mutationLocked}
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
          <button type="button" onClick={() => void reloadAuthoritative()}>
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
                {shownIngredients.map((ingredient) => (
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
                          disabled={
                            mutationLocked ||
                            ingredient.ingredient_status === "ARCHIVED"
                          }
                          onClick={() => editIngredient(ingredient)}
                        >
                          Sửa
                        </button>
                        <button
                          className="inline-action"
                          type="button"
                          disabled={
                            mutationLocked ||
                            ingredient.ingredient_status !== "ACTIVE"
                          }
                          onClick={() => editPriorities(ingredient)}
                        >
                          Ưu tiên
                        </button>
                        {ingredient.ingredient_status === "ACTIVE" ? (
                          <button
                            className="inline-action danger-action"
                            type="button"
                            disabled={busy || mutationLocked}
                            onClick={() =>
                              openLifecycle(ingredient, "INACTIVE")
                            }
                          >
                            Ngừng dùng
                          </button>
                        ) : ingredient.ingredient_status === "INACTIVE" ? (
                          <>
                            <button
                              className="inline-action"
                              type="button"
                              disabled={busy || mutationLocked}
                              onClick={() =>
                                openLifecycle(ingredient, "ACTIVE")
                              }
                            >
                              Kích hoạt
                            </button>
                            <button
                              className="inline-action danger-action"
                              type="button"
                              disabled={busy || mutationLocked}
                              onClick={() =>
                                openLifecycle(ingredient, "ARCHIVED")
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
                        disabled={mutationLocked}
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
              disabled={busy}
              onClick={resetSurfaces}
            >
              ×
            </button>
          </div>
          <div className="master-data-drawer-body">
            <div className="master-data-form-grid">
              <label className="evidence-field">
                Mã nguyên liệu
                <input
                  disabled={busy || mutationLocked || ingredientId !== "NEW"}
                  value={ingredientDraft.ingredientCode}
                  onChange={(event) =>
                    setIngredientField("ingredientCode", event.target.value)
                  }
                />
              </label>
              <label className="evidence-field">
                Tên nguyên liệu
                <input
                  disabled={busy || mutationLocked}
                  value={ingredientDraft.ingredientName}
                  onChange={(event) =>
                    setIngredientField("ingredientName", event.target.value)
                  }
                />
              </label>
              <label className="evidence-field">
                Đơn vị mua
                <select
                  disabled={busy || mutationLocked}
                  value={ingredientDraft.purchaseUnitId}
                  onChange={(event) =>
                    setIngredientField("purchaseUnitId", event.target.value)
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
                  disabled={busy || mutationLocked}
                  value={ingredientDraft.ingredientType}
                  onChange={(event) =>
                    setIngredientField("ingredientType", event.target.value)
                  }
                />
              </label>
              <label className="evidence-field">
                Cách mua
                <input
                  disabled={busy || mutationLocked}
                  value={ingredientDraft.shoppingType}
                  onChange={(event) =>
                    setIngredientField("shoppingType", event.target.value)
                  }
                />
              </label>
              <label className="evidence-field">
                Bước đặt hàng
                <input
                  type="number"
                  min="0.000001"
                  step="any"
                  disabled={busy || mutationLocked}
                  value={ingredientDraft.orderStep}
                  onChange={(event) =>
                    setIngredientField("orderStep", event.target.value)
                  }
                />
              </label>
            </div>
            <div className="workbench-actions">
              <button
                type="button"
                className="primary"
                disabled={
                  busy || mutationLocked || !ingredientValid || !ingredientDirty
                }
                onClick={openIngredientReview}
              >
                Xem thay đổi
              </button>
              <button type="button" disabled={busy} onClick={resetSurfaces}>
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
              disabled={busy}
              onClick={resetSurfaces}
            >
              ×
            </button>
          </div>
          <div className="master-data-drawer-body">
            <div className="master-data-form-grid">
              <label className="evidence-field">
                Mã nhà cung ứng
                <input
                  disabled={busy || mutationLocked || supplierId !== "NEW"}
                  value={supplierDraft.supplierCode}
                  onChange={(event) =>
                    setSupplierField("supplierCode", event.target.value)
                  }
                />
              </label>
              <label className="evidence-field">
                Tên nhà cung ứng
                <input
                  disabled={busy || mutationLocked}
                  value={supplierDraft.supplierName}
                  onChange={(event) =>
                    setSupplierField("supplierName", event.target.value)
                  }
                />
              </label>
              <label className="evidence-field">
                Người liên hệ
                <input
                  disabled={busy || mutationLocked}
                  value={supplierDraft.contactName}
                  onChange={(event) =>
                    setSupplierField("contactName", event.target.value)
                  }
                />
              </label>
              <label className="evidence-field">
                Điện thoại
                <input
                  disabled={busy || mutationLocked}
                  value={supplierDraft.contactPhone}
                  onChange={(event) =>
                    setSupplierField("contactPhone", event.target.value)
                  }
                />
              </label>
              <label className="evidence-field">
                Email
                <input
                  type="email"
                  disabled={busy || mutationLocked}
                  value={supplierDraft.contactEmail}
                  onChange={(event) =>
                    setSupplierField("contactEmail", event.target.value)
                  }
                />
              </label>
            </div>
            <div className="workbench-actions">
              <button
                type="button"
                className="primary"
                disabled={
                  busy || mutationLocked || !supplierValid || !supplierDirty
                }
                onClick={openSupplierReview}
              >
                Xem thay đổi
              </button>
              <button type="button" disabled={busy} onClick={resetSurfaces}>
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
              disabled={busy}
              onClick={resetSurfaces}
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
                    aria-invalid={
                      prioritySupplierIds.filter(
                        (supplierId) => supplierId === item.supplierId,
                      ).length > 1
                    }
                    disabled={busy || mutationLocked}
                    value={item.supplierId}
                    onChange={(event) =>
                      setPriorityDrafts((current) =>
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
                        (supplier) =>
                          supplier.supplier_status === "ACTIVE" ||
                          supplier.supplier_id === item.supplierId,
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
                    aria-invalid={
                      !Number.isInteger(item.priority) ||
                      item.priority < 1 ||
                      item.priority > 6 ||
                      priorityValues.filter(
                        (priority) => priority === item.priority,
                      ).length > 1
                    }
                    disabled={busy || mutationLocked}
                    value={item.priority}
                    onChange={(event) =>
                      setPriorityDrafts((current) =>
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
                  disabled={busy || mutationLocked}
                  onClick={() =>
                    setPriorityDrafts((current) =>
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
            {!prioritiesValid && (
              <p className="master-data-validation" role="alert">
                Tối đa sáu nhà cung ứng; nhà cung ứng và mức ưu tiên 1–6 không
                được trùng.
              </p>
            )}
            <div className="workbench-actions">
              <button
                type="button"
                disabled={busy || mutationLocked || priorities.length >= 6}
                onClick={addPriority}
              >
                Thêm nhà cung ứng
              </button>
              <button
                type="button"
                className="primary"
                disabled={
                  busy || mutationLocked || !prioritiesValid || !prioritiesDirty
                }
                onClick={openPriorityReview}
              >
                Xem thay đổi
              </button>
              <button type="button" disabled={busy} onClick={resetSurfaces}>
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
              disabled={busy}
              onClick={resetSurfaces}
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
                disabled={busy || mutationLocked}
                onClick={() =>
                  void changeLifecycle(
                    lifecycleIntent.ingredient,
                    lifecycleIntent.status,
                  )
                }
              >
                {busy ? "Đang cập nhật…" : "Xác nhận thay đổi"}
              </button>
              <button type="button" disabled={busy} onClick={resetSurfaces}>
                Hủy
              </button>
            </div>
          </div>
        </section>
      )}

      <Modal
        opened={reviewSnapshot !== null}
        onClose={() => {
          if (!busy) setReviewSnapshot(null);
        }}
        title="Xem thay đổi"
        size="760px"
        centered
        xOffset="20px"
        yOffset="20px"
        closeOnClickOutside={!busy}
        closeOnEscape={!busy}
        withCloseButton={!busy}
        styles={{
          content: { maxHeight: "86dvh", overflowX: "hidden" },
          body: {
            maxHeight: "calc(86dvh - 64px)",
            overflowY: "auto",
            overflowX: "hidden",
          },
        }}
      >
        {reviewSnapshot?.kind === "ingredient" && (
          <>
            <p className="master-data-review-intro">
              <b>
                {reviewSnapshot.mode === "create"
                  ? "Nguyên liệu mới"
                  : reviewSnapshot.before?.ingredientName}
              </b>
              <span>Kiểm tra đúng các thông tin kinh doanh sẽ được lưu.</span>
            </p>
            <table className="master-data-review-table">
              <thead>
                <tr>
                  <th>Thông tin</th>
                  {reviewSnapshot.before && <th>Hiện tại</th>}
                  <th>Sau thay đổi</th>
                </tr>
              </thead>
              <tbody>
                {[
                  [
                    "Mã nguyên liệu",
                    reviewSnapshot.before?.ingredientCode,
                    reviewSnapshot.after.ingredientCode,
                  ],
                  [
                    "Tên nguyên liệu",
                    reviewSnapshot.before?.ingredientName,
                    reviewSnapshot.after.ingredientName,
                  ],
                  [
                    "Đơn vị mua",
                    reviewSnapshot.before?.purchaseUnitLabel,
                    reviewSnapshot.after.purchaseUnitLabel,
                  ],
                  [
                    "Loại nguyên liệu",
                    reviewSnapshot.before?.ingredientType,
                    reviewSnapshot.after.ingredientType,
                  ],
                  [
                    "Cách mua",
                    reviewSnapshot.before?.shoppingType,
                    reviewSnapshot.after.shoppingType,
                  ],
                  [
                    "Bước đặt hàng",
                    reviewSnapshot.before?.orderStepValue,
                    reviewSnapshot.after.orderStepValue,
                  ],
                ].map(([label, before, after]) => {
                  const changed = before === undefined || before !== after;
                  return (
                    <tr key={String(label)}>
                      <th scope="row">{label}</th>
                      {reviewSnapshot.before && <td>{before}</td>}
                      <td className={changed ? "changed" : "unchanged"}>
                        {after}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </>
        )}

        {reviewSnapshot?.kind === "supplier" && (
          <>
            <p className="master-data-review-intro">
              <b>
                {reviewSnapshot.mode === "create"
                  ? "Nhà cung ứng mới"
                  : reviewSnapshot.before?.supplierName}
              </b>
              <span>Kiểm tra đúng các thông tin kinh doanh sẽ được lưu.</span>
            </p>
            <table className="master-data-review-table">
              <thead>
                <tr>
                  <th>Thông tin</th>
                  {reviewSnapshot.before && <th>Hiện tại</th>}
                  <th>Sau thay đổi</th>
                </tr>
              </thead>
              <tbody>
                {[
                  [
                    "Mã nhà cung ứng",
                    reviewSnapshot.before?.supplierCode,
                    reviewSnapshot.after.supplierCode,
                  ],
                  [
                    "Tên nhà cung ứng",
                    reviewSnapshot.before?.supplierName,
                    reviewSnapshot.after.supplierName,
                  ],
                  [
                    "Người liên hệ",
                    reviewSnapshot.before?.contactName,
                    reviewSnapshot.after.contactName,
                  ],
                  [
                    "Điện thoại",
                    reviewSnapshot.before?.contactPhone,
                    reviewSnapshot.after.contactPhone,
                  ],
                  [
                    "Email",
                    reviewSnapshot.before?.contactEmail,
                    reviewSnapshot.after.contactEmail,
                  ],
                ].map(([label, before, after]) => {
                  const changed = before === undefined || before !== after;
                  return (
                    <tr key={String(label)}>
                      <th scope="row">{label}</th>
                      {reviewSnapshot.before && <td>{before || "—"}</td>}
                      <td className={changed ? "changed" : "unchanged"}>
                        {after || "—"}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </>
        )}

        {reviewSnapshot?.kind === "priorities" && (
          <>
            <p className="master-data-review-intro">
              <b>{reviewSnapshot.ingredientName}</b>
              <span>
                Kiểm tra toàn bộ danh sách ưu tiên sẽ thay thế danh sách hiện
                tại.
              </span>
            </p>
            <div className="master-data-priority-review">
              {[
                { title: "Hiện tại", items: reviewSnapshot.before },
                { title: "Sau thay đổi", items: reviewSnapshot.after },
              ].map(({ title, items }) => (
                <section key={title}>
                  <h3>{title}</h3>
                  {items.length ? (
                    <ol>
                      {[...items]
                        .sort((a, b) => a.priority - b.priority)
                        .map((item) => (
                          <li key={`${item.supplierId}:${item.priority}`}>
                            <b>{item.priority}</b>
                            <span>{item.supplierName}</span>
                          </li>
                        ))}
                    </ol>
                  ) : (
                    <p>Không có nhà cung ứng ưu tiên.</p>
                  )}
                </section>
              ))}
            </div>
          </>
        )}

        <div className="workbench-actions master-data-review-actions">
          <button
            type="button"
            disabled={busy}
            onClick={() => setReviewSnapshot(null)}
          >
            Quay lại
          </button>
          <button
            type="button"
            className="primary"
            disabled={busy || mutationLocked || !reviewSnapshot}
            onClick={() => void saveReviewed()}
          >
            {busy ? "Đang lưu…" : "Lưu"}
          </button>
        </div>
      </Modal>

      {notice && (
        <div
          className={`operator-notice ${notice.tone} master-data-outcome-notice`}
          role={notice.tone === "danger" ? "alert" : "status"}
        >
          <p>{notice.message}</p>
          {notice.requiresRefresh && (
            <button type="button" onClick={() => void reloadAuthoritative()}>
              Tải lại dữ liệu chính thức
            </button>
          )}
        </div>
      )}
    </Panel>
  );
}
