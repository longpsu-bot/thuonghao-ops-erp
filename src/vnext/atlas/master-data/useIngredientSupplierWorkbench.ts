import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  commandRequest,
  responseArray,
  resultMessage,
  type AtlasRpcResult,
  type IngredientMasterData,
  type IngredientOrderGroupMasterData,
  type IngredientSupplierMasterDataApi,
  type IngredientTypeMasterData,
  type SupplierMasterData,
  type UnitMasterData,
} from "../bridges/ingredientSupplierMasterData";
import {
  filterIngredients,
  filterSuppliers,
  parseOrderStepDraft,
  validatePriorities,
  type IngredientStatusFilter,
  type PriorityDraft,
} from "./ingredientSupplierModel";

export type IngredientDraft = {
  ingredientName: string;
  purchaseUnitId: string;
  ingredientTypeId: string;
  ingredientOrderGroupId: string;
  orderStep: string;
};
export type SupplierDraft = {
  supplierName: string;
  contactName: string;
  contactPhone: string;
  contactEmail: string;
};
export type WorkbenchJob = "ingredients" | "suppliers";
export type WorkbenchLock = "stale" | "unknown" | "readback" | null;
export type ActiveSurface =
  | { kind: "ingredient"; id: string }
  | { kind: "supplier"; id: string }
  | { kind: "priorities"; ingredientId: string }
  | {
      kind: "lifecycle";
      ingredientId: string;
      status: IngredientMasterData["ingredient_status"];
    };
type PendingTransition =
  | { kind: "close" }
  | { kind: "job"; job: WorkbenchJob }
  | { kind: "ingredient"; id: string }
  | { kind: "supplier"; id: string }
  | { kind: "priorities"; ingredientId: string };

type IngredientReview = {
  kind: "ingredient";
  mode: "create" | "update";
  expectedVersion: number;
  before: IngredientDraft | null;
  after: IngredientDraft & { orderStepValue: number };
  payload: Record<string, string | number>;
};
type SupplierReview = {
  kind: "supplier";
  mode: "create" | "update";
  expectedVersion: number;
  before: SupplierDraft | null;
  after: SupplierDraft;
  payload: Record<string, string>;
};
type PriorityReview = {
  kind: "priorities";
  ingredientId: string;
  ingredientName: string;
  expectedVersion: number;
  before: PriorityDraft[];
  after: PriorityDraft[];
  payload: {
    ingredient_id: string;
    priorities: { supplier_id: string; priority: number }[];
  };
};
export type WorkbenchReview =
  IngredientReview | SupplierReview | PriorityReview;

type Authority = {
  ingredients: IngredientMasterData[];
  suppliers: SupplierMasterData[];
  units: UnitMasterData[];
  ingredientTypes: IngredientTypeMasterData[];
  ingredientOrderGroups: IngredientOrderGroupMasterData[];
};
const emptyAuthority = (): Authority => ({
  ingredients: [],
  suppliers: [],
  units: [],
  ingredientTypes: [],
  ingredientOrderGroups: [],
});
const emptyIngredient = (): IngredientDraft => ({
  ingredientName: "",
  purchaseUnitId: "",
  ingredientTypeId: "",
  ingredientOrderGroupId: "",
  orderStep: "",
});
const emptySupplier = (): SupplierDraft => ({
  supplierName: "",
  contactName: "",
  contactPhone: "",
  contactEmail: "",
});
const ingredientDraftFor = (item: IngredientMasterData): IngredientDraft => ({
  ingredientName: item.ingredient_name,
  purchaseUnitId: item.purchase_unit_id ?? "",
  ingredientTypeId: item.ingredient_type_id ?? "",
  ingredientOrderGroupId: item.ingredient_order_group_id ?? "",
  orderStep: item.order_step === null ? "" : String(item.order_step),
});
const supplierDraftFor = (item: SupplierMasterData): SupplierDraft => ({
  supplierName: item.supplier_name,
  contactName: item.contact_name ?? "",
  contactPhone: item.contact_phone ?? "",
  contactEmail: item.contact_email ?? "",
});
const canonicalIngredientDraft = (draft: IngredientDraft) => ({
  ...draft,
  ingredientName: draft.ingredientName.trim(),
  orderStep: draft.orderStep.trim(),
});
const canonicalSupplierDraft = (draft: SupplierDraft): SupplierDraft => ({
  supplierName: draft.supplierName.trim(),
  contactName: draft.contactName.trim(),
  contactPhone: draft.contactPhone.trim(),
  contactEmail: draft.contactEmail.trim(),
});
const same = (a: unknown, b: unknown) =>
  JSON.stringify(a) === JSON.stringify(b);
const normalizedPriorities = (items: PriorityDraft[]) =>
  items
    .map((item) => ({ ...item }))
    .sort(
      (a, b) =>
        a.priority - b.priority || a.supplierId.localeCompare(b.supplierId),
    );

export function useIngredientSupplierWorkbench({
  authSubject,
  api,
}: {
  authSubject: string | null;
  api: IngredientSupplierMasterDataApi;
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [authority, setAuthority] = useState<Authority>(emptyAuthority);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [lock, setLock] = useState<WorkbenchLock>(null);
  const [job, setJob] = useState<WorkbenchJob>("ingredients");
  const [ingredientQuery, setIngredientQuery] = useState("");
  const [ingredientStatus, setIngredientStatus] =
    useState<IngredientStatusFilter>("ALL");
  const [supplierQuery, setSupplierQuery] = useState("");
  const [activeSurface, setActiveSurface] = useState<ActiveSurface | null>(
    null,
  );
  const [ingredientDraft, setIngredientDraft] =
    useState<IngredientDraft>(emptyIngredient);
  const [supplierDraft, setSupplierDraft] =
    useState<SupplierDraft>(emptySupplier);
  const [priorities, setPrioritiesState] = useState<PriorityDraft[]>([]);
  const [review, setReview] = useState<WorkbenchReview | null>(null);
  const [pendingTransition, setPendingTransition] =
    useState<PendingTransition | null>(null);
  const requestGeneration = useRef(0);

  const resetSurfaces = useCallback(() => {
    setActiveSurface(null);
    setReview(null);
    setIngredientDraft(emptyIngredient());
    setSupplierDraft(emptySupplier());
    setPrioritiesState([]);
  }, []);

  const readAuthority = useCallback(
    async (purpose: "initial" | "routine" | "recovery" | "readback") => {
      if (!authSubject) return false;
      const generation = ++requestGeneration.current;
      setLoading(true);
      setError(null);
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
      const ingredientTypes = responseArray<IngredientTypeMasterData>(
        result,
        "ingredient_types",
      );
      const ingredientOrderGroups =
        responseArray<IngredientOrderGroupMasterData>(
          result,
          "ingredient_order_groups",
        );
      if (
        !ingredients ||
        !suppliers ||
        !units ||
        !ingredientTypes ||
        !ingredientOrderGroups
      ) {
        setLoading(false);
        setError(resultMessage(result));
        if (purpose === "readback") {
          setLock("readback");
          setNotice(
            "Đã gửi lệnh lưu nhưng chưa tải lại được dữ liệu chính thức.",
          );
        }
        return false;
      }
      setAuthority({
        ingredients,
        suppliers,
        units,
        ingredientTypes,
        ingredientOrderGroups,
      });
      setLoading(false);
      setError(null);
      if (purpose === "recovery" || purpose === "readback") resetSurfaces();
      if (purpose === "recovery") setNotice("Đã tải lại dữ liệu chính thức.");
      setLock(null);
      return true;
    },
    [api, authSubject, correlationId, resetSurfaces],
  );

  useEffect(() => {
    requestGeneration.current += 1;
    setAuthority(emptyAuthority());
    setLoading(false);
    setSaving(false);
    setError(null);
    setNotice(null);
    setLock(null);
    setJob("ingredients");
    setIngredientQuery("");
    setIngredientStatus("ALL");
    setSupplierQuery("");
    resetSurfaces();
    setPendingTransition(null);
    if (authSubject) void readAuthority("initial");
  }, [authSubject, readAuthority, resetSurfaces]);

  const selectedIngredient = useMemo(() => {
    if (!activeSurface) return undefined;
    const id =
      activeSurface.kind === "ingredient"
        ? activeSurface.id
        : "ingredientId" in activeSurface
          ? activeSurface.ingredientId
          : null;
    return authority.ingredients.find((item) => item.ingredient_id === id);
  }, [activeSurface, authority.ingredients]);
  const selectedSupplier = useMemo(
    () =>
      activeSurface?.kind === "supplier"
        ? authority.suppliers.find(
            (item) => item.supplier_id === activeSurface.id,
          )
        : undefined,
    [activeSurface, authority.suppliers],
  );

  const ingredientDirty = useMemo(() => {
    if (activeSurface?.kind !== "ingredient") return false;
    const canonical = canonicalIngredientDraft(ingredientDraft);
    if (activeSurface.id === "NEW")
      return Object.values(canonical).some(Boolean);
    return Boolean(
      selectedIngredient &&
      !same(
        canonical,
        canonicalIngredientDraft(ingredientDraftFor(selectedIngredient)),
      ),
    );
  }, [activeSurface, ingredientDraft, selectedIngredient]);
  const supplierDirty = useMemo(() => {
    if (activeSurface?.kind !== "supplier") return false;
    const canonical = canonicalSupplierDraft(supplierDraft);
    if (activeSurface.id === "NEW")
      return Object.values(canonical).some(Boolean);
    return Boolean(
      selectedSupplier &&
      !same(
        canonical,
        canonicalSupplierDraft(supplierDraftFor(selectedSupplier)),
      ),
    );
  }, [activeSurface, selectedSupplier, supplierDraft]);
  const authoritativePriorities = useMemo(
    () =>
      normalizedPriorities(
        selectedIngredient?.supplier_priorities.map((item) => ({
          supplierId: item.supplier_id,
          priority: item.priority,
        })) ?? [],
      ),
    [selectedIngredient],
  );
  const prioritiesDirty =
    activeSurface?.kind === "priorities" &&
    !same(normalizedPriorities(priorities), authoritativePriorities);
  const dirty = ingredientDirty || supplierDirty || prioritiesDirty;

  const openIngredient = (id: string) => {
    const item = authority.ingredients.find(
      (value) => value.ingredient_id === id,
    );
    setActiveSurface({ kind: "ingredient", id });
    setIngredientDraft(item ? ingredientDraftFor(item) : emptyIngredient());
    setReview(null);
    setNotice(null);
  };
  const openSupplier = (id: string) => {
    const item = authority.suppliers.find((value) => value.supplier_id === id);
    setActiveSurface({ kind: "supplier", id });
    setSupplierDraft(item ? supplierDraftFor(item) : emptySupplier());
    setReview(null);
    setNotice(null);
  };
  const openPriorities = (ingredientId: string) => {
    const item = authority.ingredients.find(
      (value) => value.ingredient_id === ingredientId,
    );
    if (!item || item.ingredient_status !== "ACTIVE") return;
    setActiveSurface({ kind: "priorities", ingredientId });
    setPrioritiesState(
      item.supplier_priorities.map((priority) => ({
        supplierId: priority.supplier_id,
        priority: priority.priority,
      })),
    );
    setReview(null);
    setNotice(null);
  };
  const openLifecycle = (
    ingredientId: string,
    status: IngredientMasterData["ingredient_status"],
  ) => {
    const item = authority.ingredients.find(
      (value) => value.ingredient_id === ingredientId,
    );
    const allowed =
      item?.ingredient_status === "ACTIVE"
        ? status === "INACTIVE"
        : item?.ingredient_status === "INACTIVE"
          ? status === "ACTIVE" || status === "ARCHIVED"
          : false;
    if (allowed) setActiveSurface({ kind: "lifecycle", ingredientId, status });
  };

  const setIngredientField = (field: keyof IngredientDraft, value: string) => {
    if (selectedIngredient?.ingredient_status === "ARCHIVED") return;
    setReview(null);
    setNotice(null);
    setIngredientDraft((current) => ({ ...current, [field]: value }));
  };
  const setSupplierField = (field: keyof SupplierDraft, value: string) => {
    setReview(null);
    setNotice(null);
    setSupplierDraft((current) => ({ ...current, [field]: value }));
  };
  const setPriorities = (items: PriorityDraft[]) => {
    setReview(null);
    setNotice(null);
    setPrioritiesState(items);
  };

  const ingredientOrderStep = parseOrderStepDraft(ingredientDraft.orderStep);
  const ingredientValid = Boolean(
    canonicalIngredientDraft(ingredientDraft).ingredientName &&
    ingredientDraft.purchaseUnitId &&
    ingredientDraft.ingredientTypeId &&
    ingredientDraft.ingredientOrderGroupId &&
    ingredientOrderStep,
  );
  const supplierValid = Boolean(
    canonicalSupplierDraft(supplierDraft).supplierName,
  );
  const priorityErrors = selectedIngredient
    ? validatePriorities(priorities, selectedIngredient, authority.suppliers)
    : [];

  const openIngredientReview = () => {
    if (
      activeSurface?.kind !== "ingredient" ||
      !ingredientDirty ||
      !ingredientValid ||
      selectedIngredient?.ingredient_status === "ARCHIVED"
    )
      return;
    const creating = activeSurface.id === "NEW";
    const after = canonicalIngredientDraft(ingredientDraft);
    const payload = {
      ...(creating ? {} : { ingredient_id: activeSurface.id }),
      ingredient_name: after.ingredientName,
      purchase_unit_id: after.purchaseUnitId,
      ingredient_type_id: after.ingredientTypeId,
      ingredient_order_group_id: after.ingredientOrderGroupId,
      order_step: ingredientOrderStep!,
    };
    setReview({
      kind: "ingredient",
      mode: creating ? "create" : "update",
      expectedVersion: creating ? 1 : selectedIngredient!.version,
      before: creating ? null : ingredientDraftFor(selectedIngredient!),
      after: { ...after, orderStepValue: ingredientOrderStep! },
      payload,
    });
  };
  const openSupplierReview = () => {
    if (activeSurface?.kind !== "supplier" || !supplierDirty || !supplierValid)
      return;
    const creating = activeSurface.id === "NEW";
    const after = canonicalSupplierDraft(supplierDraft);
    setReview({
      kind: "supplier",
      mode: creating ? "create" : "update",
      expectedVersion: creating ? 1 : selectedSupplier!.version,
      before: creating ? null : supplierDraftFor(selectedSupplier!),
      after,
      payload: {
        ...(creating ? {} : { supplier_id: activeSurface.id }),
        supplier_name: after.supplierName,
        contact_name: after.contactName,
        contact_phone: after.contactPhone,
        contact_email: after.contactEmail,
      },
    });
  };
  const openPriorityReview = () => {
    if (
      activeSurface?.kind !== "priorities" ||
      !selectedIngredient ||
      !prioritiesDirty ||
      priorityErrors.length
    )
      return;
    const after = normalizedPriorities(priorities);
    setReview({
      kind: "priorities",
      ingredientId: selectedIngredient.ingredient_id,
      ingredientName: selectedIngredient.ingredient_name,
      expectedVersion: selectedIngredient.version,
      before: authoritativePriorities,
      after,
      payload: {
        ingredient_id: selectedIngredient.ingredient_id,
        priorities: after.map((item) => ({
          supplier_id: item.supplierId,
          priority: item.priority,
        })),
      },
    });
  };

  const handleWriteResult = async (result: AtlasRpcResult, success: string) => {
    setReview(null);
    if (result.kind === "transport_error") {
      setLock("unknown");
      setNotice("Atlas chưa thể xác nhận thao tác đã hoàn tất hay chưa.");
      return;
    }
    if (result.kind === "success") {
      const current = await readAuthority("readback");
      if (current) setNotice(success);
      return;
    }
    if (
      result.kind === "backend_error" &&
      (result.error.error_code === "STALE_VERSION" || result.error.retryable)
    ) {
      setLock("stale");
      setNotice(
        "Dữ liệu đã được cập nhật ở nơi khác. Hãy tải lại trước khi tiếp tục.",
      );
      return;
    }
    setNotice(resultMessage(result));
  };

  const saveReview = async () => {
    if (!authSubject || !review || saving || lock) return;
    const frozen = review;
    setSaving(true);
    const generation = requestGeneration.current;
    let result: AtlasRpcResult;
    if (frozen.kind === "ingredient") {
      const request = commandRequest(
        authSubject,
        correlationId,
        frozen.expectedVersion,
        frozen.mode === "create" ? "INGREDIENT_CREATE" : "INGREDIENT_UPDATE",
        frozen.payload,
      );
      result = await (frozen.mode === "create"
        ? api.createIngredient(request)
        : api.updateIngredient(request));
    } else if (frozen.kind === "supplier") {
      const request = commandRequest(
        authSubject,
        correlationId,
        frozen.expectedVersion,
        frozen.mode === "create" ? "SUPPLIER_CREATE" : "SUPPLIER_UPDATE",
        frozen.payload,
      );
      result = await (frozen.mode === "create"
        ? api.createSupplier(request)
        : api.updateSupplier(request));
    } else {
      result = await api.replacePriorities(
        commandRequest(
          authSubject,
          correlationId,
          frozen.expectedVersion,
          "INGREDIENT_SUPPLIER_PRIORITIES_REPLACE",
          frozen.payload,
        ),
      );
    }
    if (generation !== requestGeneration.current) return;
    await handleWriteResult(result, "Đã lưu và tải lại dữ liệu chính thức.");
    if (generation === requestGeneration.current) setSaving(false);
  };

  const confirmLifecycle = async () => {
    if (!authSubject || activeSurface?.kind !== "lifecycle" || saving || lock)
      return;
    const item = selectedIngredient;
    if (!item) return;
    setSaving(true);
    const generation = requestGeneration.current;
    const result = await api.setIngredientLifecycle(
      commandRequest(
        authSubject,
        correlationId,
        item.version,
        "INGREDIENT_LIFECYCLE",
        {
          ingredient_id: item.ingredient_id,
          ingredient_status: activeSurface.status,
        },
      ),
    );
    if (generation !== requestGeneration.current) return;
    await handleWriteResult(
      result,
      "Đã cập nhật trạng thái và tải lại dữ liệu chính thức.",
    );
    if (generation === requestGeneration.current) setSaving(false);
  };

  const canRefresh = !activeSurface && !review && !saving;
  const refresh = () => {
    if (!canRefresh && !lock) return Promise.resolve(false);
    return readAuthority(lock ? "recovery" : "routine");
  };

  const visibleIngredients = useMemo(
    () =>
      filterIngredients(
        authority.ingredients,
        ingredientQuery,
        ingredientStatus,
        {
          suppliers: authority.suppliers,
          units: authority.units,
          ingredientTypes: authority.ingredientTypes,
          ingredientOrderGroups: authority.ingredientOrderGroups,
        },
      ),
    [authority, ingredientQuery, ingredientStatus],
  );
  const visibleSuppliers = useMemo(
    () => filterSuppliers(authority.suppliers, supplierQuery),
    [authority.suppliers, supplierQuery],
  );

  const performTransition = (transition: PendingTransition) => {
    resetSurfaces();
    if (transition.kind === "job") setJob(transition.job);
    if (transition.kind === "ingredient") openIngredient(transition.id);
    if (transition.kind === "supplier") openSupplier(transition.id);
    if (transition.kind === "priorities")
      openPriorities(transition.ingredientId);
  };
  const requestTransition = (transition: PendingTransition) => {
    if (dirty) setPendingTransition(transition);
    else performTransition(transition);
  };
  const confirmDiscard = () => {
    if (!pendingTransition) return;
    const transition = pendingTransition;
    setPendingTransition(null);
    performTransition(transition);
  };

  return {
    ...authority,
    loading,
    saving,
    error,
    notice,
    lock,
    job,
    setJob,
    ingredientQuery,
    setIngredientQuery,
    ingredientStatus,
    setIngredientStatus,
    supplierQuery,
    setSupplierQuery,
    visibleIngredients,
    visibleSuppliers,
    activeSurface,
    selectedIngredient,
    selectedSupplier,
    ingredientDraft,
    supplierDraft,
    priorities,
    review,
    ingredientDirty,
    supplierDirty,
    prioritiesDirty,
    dirty,
    discardOpen: pendingTransition !== null,
    ingredientValid,
    supplierValid,
    priorityErrors,
    canRefresh,
    openIngredient,
    openSupplier,
    openPriorities,
    openLifecycle,
    setIngredientField,
    setSupplierField,
    setPriorities,
    openIngredientReview,
    openSupplierReview,
    openPriorityReview,
    requestIngredient: (id: string) =>
      requestTransition({ kind: "ingredient", id }),
    requestSupplier: (id: string) =>
      requestTransition({ kind: "supplier", id }),
    requestPriorities: (ingredientId: string) =>
      requestTransition({ kind: "priorities", ingredientId }),
    requestJob: (nextJob: WorkbenchJob) =>
      requestTransition({ kind: "job", job: nextJob }),
    requestClose: () => requestTransition({ kind: "close" }),
    cancelDiscard: () => setPendingTransition(null),
    confirmDiscard,
    closeReview: () => !saving && setReview(null),
    closeSurface: resetSurfaces,
    refresh,
    saveReview,
    confirmLifecycle,
  };
}

export type IngredientSupplierWorkbenchController = ReturnType<
  typeof useIngredientSupplierWorkbench
>;
