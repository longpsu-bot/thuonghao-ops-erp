import { act, renderHook, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type {
  AtlasRpcResult,
  IngredientMasterData,
  IngredientSupplierMasterDataApi,
  SupplierMasterData,
} from "../bridges/ingredientSupplierMasterData";
import { useIngredientSupplierWorkbench } from "./useIngredientSupplierWorkbench";

const ingredient: IngredientMasterData = {
  ingredient_id: "ingredient-1",
  ingredient_code: "NL-001",
  ingredient_name: "Rau muống",
  ingredient_status: "ACTIVE",
  ingredient_type_id: "type-1",
  ingredient_type_name: "Rau lá",
  ingredient_order_group_id: "group-1",
  ingredient_order_group_name: "Hàng ngày",
  ingredient_type: "Rau lá",
  shopping_type: "Hàng ngày",
  purchase_unit_id: "unit-1",
  purchase_unit_code: "KG",
  purchase_unit_name: "Kilôgam",
  order_step: 0.5,
  version: 4,
  supplier_priorities: [],
};
const supplier: SupplierMasterData = {
  supplier_id: "supplier-1",
  supplier_code: "NCC-001",
  supplier_name: "NCC Minh Tâm",
  supplier_status: "ACTIVE",
  contact_name: null,
  contact_phone: null,
  contact_email: null,
  version: 3,
};

function readSuccess(overrides: Record<string, unknown> = {}): AtlasRpcResult {
  return {
    kind: "success",
    response: {
      success: true,
      ingredients: [ingredient],
      suppliers: [supplier],
      units: [
        {
          unit_id: "unit-1",
          unit_code: "KG",
          unit_name: "Kilôgam",
          unit_status: "ACTIVE",
        },
      ],
      ingredient_types: [
        {
          ingredient_type_id: "type-1",
          ingredient_type_code: "RAU",
          ingredient_type_name: "Rau lá",
          display_order: 1,
          ingredient_type_status: "ACTIVE",
        },
      ],
      ingredient_order_groups: [
        {
          ingredient_order_group_id: "group-1",
          ingredient_order_group_code: "DAILY",
          ingredient_order_group_name: "Hàng ngày",
          display_order: 1,
          ingredient_order_group_status: "ACTIVE",
        },
      ],
      ...overrides,
    },
  };
}

const writeSuccess: AtlasRpcResult = {
  kind: "success",
  response: { success: true },
};

function apiWithRead(result: AtlasRpcResult = readSuccess()) {
  return {
    getIngredientsAndSuppliers: vi.fn().mockResolvedValue(result),
    createIngredient: vi.fn().mockResolvedValue(writeSuccess),
    updateIngredient: vi.fn().mockResolvedValue(writeSuccess),
    setIngredientLifecycle: vi.fn().mockResolvedValue(writeSuccess),
    createSupplier: vi.fn().mockResolvedValue(writeSuccess),
    updateSupplier: vi.fn().mockResolvedValue(writeSuccess),
    replacePriorities: vi.fn().mockResolvedValue(writeSuccess),
  } satisfies IngredientSupplierMasterDataApi;
}

describe("useIngredientSupplierWorkbench", () => {
  beforeEach(() => vi.useRealTimers());

  it("adopts one authoritative read only when all five arrays exist", async () => {
    const api = apiWithRead(
      readSuccess({ ingredient_order_groups: undefined }),
    );
    const { result } = renderHook(() =>
      useIngredientSupplierWorkbench({ authSubject: "operator-1", api }),
    );
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(api.getIngredientsAndSuppliers).toHaveBeenCalledTimes(1);
    expect(result.current.ingredients).toEqual([]);
    expect(result.current.error).toBeTruthy();
  });

  it("suppresses an older slow read after a newer refresh", async () => {
    let resolveOld!: (value: AtlasRpcResult) => void;
    const old = new Promise<AtlasRpcResult>(
      (resolve) => (resolveOld = resolve),
    );
    const api = apiWithRead();
    api.getIngredientsAndSuppliers
      .mockReset()
      .mockReturnValueOnce(old)
      .mockResolvedValueOnce(
        readSuccess({
          ingredients: [{ ...ingredient, ingredient_name: "Mới" }],
        }),
      );
    const { result } = renderHook(() =>
      useIngredientSupplierWorkbench({ authSubject: "operator-1", api }),
    );
    await act(async () => void (await result.current.refresh()));
    expect(result.current.ingredients[0]?.ingredient_name).toBe("Mới");
    await act(async () => resolveOld(readSuccess()));
    expect(result.current.ingredients[0]?.ingredient_name).toBe("Mới");
  });

  it("freezes an Ingredient update review and sends one exact command before authoritative readback", async () => {
    const api = apiWithRead();
    const { result } = renderHook(() =>
      useIngredientSupplierWorkbench({ authSubject: "operator-1", api }),
    );
    await waitFor(() => expect(result.current.ingredients).toHaveLength(1));
    act(() => {
      result.current.openIngredient("ingredient-1");
      result.current.setIngredientField("ingredientName", "  Rau muống non  ");
    });
    act(() => result.current.openIngredientReview());
    expect(result.current.review?.kind).toBe("ingredient");
    await act(async () => void (await result.current.saveReview()));
    expect(api.updateIngredient).toHaveBeenCalledTimes(1);
    expect(api.updateIngredient).toHaveBeenCalledWith(
      expect.objectContaining({
        contract_version: "RMVP-01.v1",
        expected_version: 4,
        reason_code: "INGREDIENT_UPDATE",
        payload: {
          ingredient_id: "ingredient-1",
          ingredient_name: "Rau muống non",
          purchase_unit_id: "unit-1",
          ingredient_type_id: "type-1",
          ingredient_order_group_id: "group-1",
          order_step: 0.5,
        },
      }),
    );
    expect(api.getIngredientsAndSuppliers).toHaveBeenCalledTimes(2);
    expect(result.current.activeSurface).toBeNull();
  });

  it("creates a Supplier with optional blank contacts and expected version 1", async () => {
    const api = apiWithRead();
    const { result } = renderHook(() =>
      useIngredientSupplierWorkbench({ authSubject: "operator-1", api }),
    );
    await waitFor(() => expect(result.current.loading).toBe(false));
    act(() => result.current.openSupplier("NEW"));
    act(() =>
      result.current.setSupplierField("supplierName", "  Nhà cung ứng Mới "),
    );
    act(() => result.current.openSupplierReview());
    await act(async () => void (await result.current.saveReview()));
    expect(api.createSupplier).toHaveBeenCalledWith(
      expect.objectContaining({
        expected_version: 1,
        reason_code: "SUPPLIER_CREATE",
        payload: {
          supplier_name: "Nhà cung ứng Mới",
          contact_name: "",
          contact_phone: "",
          contact_email: "",
        },
      }),
    );
  });

  it("sends an explicit empty priority replacement exactly once with the current Ingredient version", async () => {
    const api = apiWithRead(
      readSuccess({
        ingredients: [
          {
            ...ingredient,
            supplier_priorities: [
              {
                supplier_eligibility_id: "eligibility-1",
                supplier_id: supplier.supplier_id,
                supplier_name: supplier.supplier_name,
                priority: 1,
              },
            ],
          },
        ],
      }),
    );
    const { result } = renderHook(() =>
      useIngredientSupplierWorkbench({ authSubject: "operator-1", api }),
    );
    await waitFor(() => expect(result.current.ingredients).toHaveLength(1));
    act(() => result.current.openPriorities("ingredient-1"));
    act(() => result.current.setPriorities([]));
    act(() => result.current.openPriorityReview());
    await act(async () => void (await result.current.saveReview()));
    expect(api.replacePriorities).toHaveBeenCalledTimes(1);
    expect(api.replacePriorities).toHaveBeenCalledWith(
      expect.objectContaining({
        expected_version: 4,
        reason_code: "INGREDIENT_SUPPLIER_PRIORITIES_REPLACE",
        payload: { ingredient_id: "ingredient-1", priorities: [] },
      }),
    );
  });

  it("locks mutations after unknown outcome without resending the write", async () => {
    const api = apiWithRead();
    api.setIngredientLifecycle.mockResolvedValueOnce({
      kind: "transport_error",
      diagnostic: { code: "NETWORK_FAILURE", safeMessage: "offline" },
    });
    const { result } = renderHook(() =>
      useIngredientSupplierWorkbench({ authSubject: "operator-1", api }),
    );
    await waitFor(() => expect(result.current.ingredients).toHaveLength(1));
    act(() => result.current.openLifecycle("ingredient-1", "INACTIVE"));
    await act(async () => void (await result.current.confirmLifecycle()));
    expect(result.current.lock).toBe("unknown");
    expect(result.current.notice).toBe(
      "Atlas chưa thể xác nhận thao tác đã hoàn tất hay chưa.",
    );
    await act(async () => void (await result.current.confirmLifecycle()));
    expect(api.setIngredientLifecycle).toHaveBeenCalledTimes(1);
  });

  it("invalidates authority and ignores delayed results when auth subject changes", async () => {
    let resolveOld!: (value: AtlasRpcResult) => void;
    const old = new Promise<AtlasRpcResult>(
      (resolve) => (resolveOld = resolve),
    );
    const api = apiWithRead();
    api.getIngredientsAndSuppliers
      .mockReset()
      .mockReturnValueOnce(old)
      .mockResolvedValueOnce(
        readSuccess({
          ingredients: [{ ...ingredient, ingredient_name: "Operator 2" }],
        }),
      );
    const { result, rerender } = renderHook(
      ({ authSubject }) => useIngredientSupplierWorkbench({ authSubject, api }),
      { initialProps: { authSubject: "operator-1" as string | null } },
    );
    rerender({ authSubject: "operator-2" });
    await waitFor(() =>
      expect(result.current.ingredients[0]?.ingredient_name).toBe("Operator 2"),
    );
    await act(async () => resolveOld(readSuccess()));
    expect(result.current.ingredients[0]?.ingredient_name).toBe("Operator 2");
  });

  it("protects dirty close, row, and job transitions while local search leaves the draft intact", async () => {
    const second = {
      ...ingredient,
      ingredient_id: "ingredient-2",
      ingredient_name: "Cà rốt",
    };
    const api = apiWithRead(readSuccess({ ingredients: [ingredient, second] }));
    const { result } = renderHook(() =>
      useIngredientSupplierWorkbench({ authSubject: "operator-1", api }),
    );
    await waitFor(() => expect(result.current.ingredients).toHaveLength(2));
    act(() => result.current.openIngredient("ingredient-1"));
    act(() => result.current.setIngredientField("ingredientName", "Bản nháp"));
    act(() => result.current.setIngredientQuery("không khớp"));
    expect(result.current.ingredientDraft.ingredientName).toBe("Bản nháp");
    expect(result.current.canRefresh).toBe(false);

    act(() => result.current.requestIngredient("ingredient-2"));
    expect(result.current.discardOpen).toBe(true);
    act(() => result.current.cancelDiscard());
    expect(result.current.activeSurface).toEqual({
      kind: "ingredient",
      id: "ingredient-1",
    });
    expect(result.current.ingredientDraft.ingredientName).toBe("Bản nháp");

    act(() => result.current.requestJob("suppliers"));
    expect(result.current.discardOpen).toBe(true);
    act(() => result.current.confirmDiscard());
    expect(result.current.job).toBe("suppliers");
    expect(result.current.activeSurface).toBeNull();

    act(() => result.current.openIngredient("ingredient-1"));
    act(() => result.current.setIngredientField("ingredientName", "Lại sửa"));
    act(() => result.current.requestClose());
    expect(result.current.discardOpen).toBe(true);
  });

  it("creates an Ingredient from the five business fields with expected version 1 and no code", async () => {
    const api = apiWithRead();
    const { result } = renderHook(() =>
      useIngredientSupplierWorkbench({ authSubject: "operator-1", api }),
    );
    await waitFor(() => expect(result.current.loading).toBe(false));
    act(() => result.current.openIngredient("NEW"));
    act(() => {
      result.current.setIngredientField("ingredientName", "Bí đỏ");
      result.current.setIngredientField("purchaseUnitId", "unit-1");
      result.current.setIngredientField("ingredientTypeId", "type-1");
      result.current.setIngredientField("ingredientOrderGroupId", "group-1");
      result.current.setIngredientField("orderStep", "2,5");
    });
    act(() => result.current.openIngredientReview());
    await act(async () => void (await result.current.saveReview()));
    expect(api.createIngredient).toHaveBeenCalledWith(
      expect.objectContaining({
        expected_version: 1,
        reason_code: "INGREDIENT_CREATE",
        payload: {
          ingredient_name: "Bí đỏ",
          purchase_unit_id: "unit-1",
          ingredient_type_id: "type-1",
          ingredient_order_group_id: "group-1",
          order_step: 2.5,
        },
      }),
    );
    expect(api.getIngredientsAndSuppliers).toHaveBeenCalledTimes(2);
  });

  it("updates a Supplier with its current version without changing code or status", async () => {
    const api = apiWithRead();
    const { result } = renderHook(() =>
      useIngredientSupplierWorkbench({ authSubject: "operator-1", api }),
    );
    await waitFor(() => expect(result.current.suppliers).toHaveLength(1));
    act(() => result.current.openSupplier("supplier-1"));
    act(() => result.current.setSupplierField("contactPhone", " 0909 "));
    act(() => result.current.openSupplierReview());
    await act(async () => void (await result.current.saveReview()));
    const request = api.updateSupplier.mock.calls[0]![0];
    expect(request).toMatchObject({
      expected_version: 3,
      reason_code: "SUPPLIER_UPDATE",
      payload: {
        supplier_id: "supplier-1",
        supplier_name: "NCC Minh Tâm",
        contact_name: "",
        contact_phone: "0909",
        contact_email: "",
      },
    });
    expect(request.payload).not.toHaveProperty("supplier_code");
    expect(request.payload).not.toHaveProperty("supplier_status");
    expect(api.getIngredientsAndSuppliers).toHaveBeenCalledTimes(2);
  });

  it("sends the exact allowed lifecycle transition and requires authoritative readback", async () => {
    const api = apiWithRead();
    const { result } = renderHook(() =>
      useIngredientSupplierWorkbench({ authSubject: "operator-1", api }),
    );
    await waitFor(() => expect(result.current.ingredients).toHaveLength(1));
    act(() => result.current.openLifecycle("ingredient-1", "INACTIVE"));
    await act(async () => void (await result.current.confirmLifecycle()));
    expect(api.setIngredientLifecycle).toHaveBeenCalledWith(
      expect.objectContaining({
        expected_version: 4,
        reason_code: "INGREDIENT_LIFECYCLE",
        payload: {
          ingredient_id: "ingredient-1",
          ingredient_status: "INACTIVE",
        },
      }),
    );
    expect(api.getIngredientsAndSuppliers).toHaveBeenCalledTimes(2);
  });

  it("locks after stale, retryable concurrency, or successful-write readback failure but keeps definite validation separate", async () => {
    const outcomes: Array<{
      write: AtlasRpcResult;
      expectedLock: "stale" | "readback" | null;
    }> = [
      {
        write: {
          kind: "backend_error",
          error: {
            success: false,
            error_code: "STALE_VERSION",
            safe_message: "stale",
          },
        },
        expectedLock: "stale",
      },
      {
        write: {
          kind: "backend_error",
          error: {
            success: false,
            error_code: "LOCK_TIMEOUT",
            safe_message: "busy",
            retryable: true,
          },
        },
        expectedLock: "stale",
      },
      {
        write: {
          kind: "backend_error",
          error: {
            success: false,
            error_code: "VALIDATION_FAILED",
            safe_message: "invalid",
          },
        },
        expectedLock: null,
      },
    ];
    for (const outcome of outcomes) {
      const api = apiWithRead();
      api.updateIngredient.mockResolvedValueOnce(outcome.write);
      const { result, unmount } = renderHook(() =>
        useIngredientSupplierWorkbench({ authSubject: "operator-1", api }),
      );
      await waitFor(() => expect(result.current.ingredients).toHaveLength(1));
      act(() => result.current.openIngredient("ingredient-1"));
      act(() => result.current.setIngredientField("ingredientName", "Bản sửa"));
      act(() => result.current.openIngredientReview());
      await act(async () => void (await result.current.saveReview()));
      expect(result.current.lock).toBe(outcome.expectedLock);
      expect(api.updateIngredient).toHaveBeenCalledTimes(1);
      unmount();
    }

    const api = apiWithRead();
    api.getIngredientsAndSuppliers
      .mockReset()
      .mockResolvedValueOnce(readSuccess())
      .mockResolvedValueOnce({
        kind: "backend_error",
        error: {
          success: false,
          error_code: "READ_FAILED",
          safe_message: "read failed",
        },
      });
    const { result } = renderHook(() =>
      useIngredientSupplierWorkbench({ authSubject: "operator-1", api }),
    );
    await waitFor(() => expect(result.current.ingredients).toHaveLength(1));
    act(() => result.current.openIngredient("ingredient-1"));
    act(() => result.current.setIngredientField("ingredientName", "Bản sửa"));
    act(() => result.current.openIngredientReview());
    await act(async () => void (await result.current.saveReview()));
    expect(result.current.lock).toBe("readback");
    expect(result.current.notice).toBe(
      "Đã gửi lệnh lưu nhưng chưa tải lại được dữ liệu chính thức.",
    );
    expect(api.updateIngredient).toHaveBeenCalledTimes(1);
  });
});
