import { describe, expect, it } from "vitest";
import {
  responseArray,
  type IngredientMasterData,
  type IngredientOrderGroupMasterData,
  type IngredientTypeMasterData,
} from "../master-data/masterDataModel";
import { createReviewMasterDataApi } from "./reviewMasterDataApi";

describe("review-only master-data adapter", () => {
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
