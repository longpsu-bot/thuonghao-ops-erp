import { describe, expect, it } from "vitest";
import {
  commandRequest,
  responseArray,
  type IngredientMasterData,
  type IngredientOrderGroupMasterData,
  type IngredientTypeMasterData,
  type SupplierMasterData,
  type UnitMasterData,
} from "../master-data/masterDataModel";
import { createReviewMasterDataApi } from "./reviewMasterDataApi";

describe("review-only master-data adapter", () => {
  it("accepts code-free Ingredient and Supplier creation while preserving controlled explicit codes", async () => {
    const api = createReviewMasterDataApi();
    const initial = await api.getIngredientsAndSuppliers("reviewer", "review");
    const unit = responseArray<UnitMasterData>(initial, "units")![0]!;
    const type = responseArray<IngredientTypeMasterData>(
      initial,
      "ingredient_types",
    )![0]!;
    const group = responseArray<IngredientOrderGroupMasterData>(
      initial,
      "ingredient_order_groups",
    )![0]!;
    for (const code of [undefined, "controlled-import"]) {
      const ingredientResult = await api.createIngredient(
        commandRequest("reviewer", "review", 1, "CREATE", {
          ingredient_name: "Bí đỏ mới",
          purchase_unit_id: unit.unit_id,
          ingredient_type_id: type.ingredient_type_id,
          ingredient_order_group_id: group.ingredient_order_group_id,
          order_step: 1,
          ...(code ? { ingredient_code: code } : {}),
        }),
      );
      expect(ingredientResult.kind).toBe("success");
      const supplierResult = await api.createSupplier(
        commandRequest("reviewer", "review", 1, "CREATE", {
          supplier_name: "Nhà cung ứng mới",
          ...(code ? { supplier_code: code } : {}),
        }),
      );
      expect(supplierResult.kind).toBe("success");
    }
    const catalog = await api.getIngredientsAndSuppliers("reviewer", "review");
    const ingredients = responseArray<IngredientMasterData>(
      catalog,
      "ingredients",
    )!;
    const suppliers = responseArray<SupplierMasterData>(catalog, "suppliers")!;
    expect(ingredients[0]!.ingredient_code).toBe("controlled-import");
    expect(suppliers[0]!.supplier_code).toBe("controlled-import");
    expect(ingredients[1]!.ingredient_code).toMatch(
      /^ingredient-[0-9a-f-]{36}$/,
    );
    expect(suppliers[1]!.supplier_code).toMatch(/^supplier-[0-9a-f-]{36}$/);
    expect(ingredients[1]!.ingredient_name).toBe("Bí đỏ mới");
    expect(suppliers[1]!.supplier_name).toBe("Nhà cung ứng mới");
    const reread = await api.getIngredientsAndSuppliers("reviewer", "review");
    expect(
      responseArray<IngredientMasterData>(reread, "ingredients")![1]!
        .ingredient_code,
    ).toBe(ingredients[1]!.ingredient_code);
    expect(
      responseArray<SupplierMasterData>(reread, "suppliers")![1]!.supplier_code,
    ).toBe(suppliers[1]!.supplier_code);
  });

  it("provides realistic deterministic review volumes", async () => {
    const api = createReviewMasterDataApi();
    const schools = await api.getSchools("reviewer", "review");
    const catalog = await api.getIngredientsAndSuppliers("reviewer", "review");

    expect(responseArray(schools, "schools")).toHaveLength(33);
    expect(responseArray(catalog, "ingredients")).toHaveLength(180);
    expect(responseArray(catalog, "suppliers")).toHaveLength(24);
    expect(
      responseArray<IngredientTypeMasterData>(catalog, "ingredient_types"),
    ).toHaveLength(17);
    expect(
      responseArray<IngredientOrderGroupMasterData>(
        catalog,
        "ingredient_order_groups",
      )?.map((item) => [
        item.ingredient_order_group_code,
        item.ingredient_order_group_name,
        item.display_order,
      ]),
    ).toEqual([
      ["pantry", "Hàng đặt riêng", 1],
      ["daily_vegetable", "Rau củ", 2],
      ["daily_other", "Còn lại", 3],
    ]);
    expect(
      responseArray<IngredientMasterData>(catalog, "ingredients")?.[0],
    ).toMatchObject({
      ingredient_name: "Gạo Jasmine",
      ingredient_type_name: "Thực phẩm khô - gia vị",
      ingredient_order_group_name: "Hàng đặt riêng",
      order_step: 0.1,
    });
  });

  it("exposes empty, permission, server, and stale outcomes without external calls", async () => {
    const empty = await createReviewMasterDataApi("empty").getSchools(
      "reviewer",
      "review",
    );
    expect(responseArray(empty, "schools")).toEqual([]);

    const denied = await createReviewMasterDataApi(
      "permission_denied",
    ).getIngredientsAndSuppliers("reviewer", "review");
    expect(denied).toMatchObject({
      kind: "backend_error",
      error: { error_code: "CAPABILITY_DENIED" },
    });

    const server = await createReviewMasterDataApi("server_error").getSchools(
      "reviewer",
      "review",
    );
    expect(server.kind).toBe("transport_error");

    const stale = await createReviewMasterDataApi("stale").updateSchoolDefaults(
      {
        contract_version: "RMVP-01.v1",
        command_id: "review-command",
        correlation_id: "review",
        idempotency_key: "review",
        expected_version: 1,
        requested_by_auth_subject: "reviewer",
        requested_at: "2026-07-27T00:00:00.000Z",
        reason_code: "SCHOOL_PORTION_DEFAULTS_UPDATE",
        reason_note: null,
        payload: {
          school_id: "review-school-01",
          default_student_portions: 400,
          default_teacher_portions: 30,
        },
      },
    );
    expect(stale).toMatchObject({
      kind: "backend_error",
      error: { error_code: "STALE_VERSION" },
    });
  });
});
