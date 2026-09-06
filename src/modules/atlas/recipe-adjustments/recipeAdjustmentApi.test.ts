import { describe, expect, it, vi } from "vitest";
import type {
  AtlasRpcName,
  AtlasRpcRequest,
  JsonValue,
} from "../connection/atlasRpc";
import {
  RECIPE_ADJUSTMENT_RPC_FUNCTIONS,
  createRecipeAdjustmentApi,
  recipeAdjustmentCommandRequest,
  recipeEffectiveTargetContextRequest,
  recipeAdjustmentOperatorReadRequest,
  recipeAdjustmentReadRequest,
  systemEffectiveRecipeRequest,
} from "./recipeAdjustmentApi";
import {
  adjustmentPreviewFromResult,
  adjustmentWorkbenchFromResult,
  effectiveTargetContextFromResult,
} from "./recipeAdjustmentModel";
import { createReviewRecipeAdjustmentApi } from "./reviewRecipeAdjustmentApi";

describe("Recipe adjustment API contract", () => {
  it("builds explicit RMVP-02B read and command envelopes", () => {
    expect(
      recipeAdjustmentReadRequest("subject-1", "correlation-1", {
        as_of_date: "2026-07-27",
      }),
    ).toEqual({
      contract_version: "RMVP-02B.v1",
      requested_by_auth_subject: "subject-1",
      correlation_id: "correlation-1",
      payload: { as_of_date: "2026-07-27" },
    });
    expect(
      recipeAdjustmentOperatorReadRequest(
        "subject-1",
        "correlation-2",
        "2026-08-14",
      ),
    ).toEqual({
      contract_version: "RMVP-02B.v2",
      requested_by_auth_subject: "subject-1",
      correlation_id: "correlation-2",
      payload: { as_of_date: "2026-08-14" },
    });

    vi.spyOn(crypto, "randomUUID").mockReturnValue(
      "10000000-0000-4000-8000-000000000001",
    );
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-07-27T02:00:00.000Z"));
    expect(
      recipeAdjustmentCommandRequest(
        "subject-1",
        "correlation-1",
        3,
        "RULE_CORRECTION",
        "Điều chỉnh theo biên bản vận hành.",
        { adjustment_id: "adjustment-1" },
      ),
    ).toMatchObject({
      contract_version: "RMVP-02B.v1",
      command_id: "10000000-0000-4000-8000-000000000001",
      idempotency_key: "rule_correction:10000000-0000-4000-8000-000000000001",
      expected_version: 3,
      requested_at: "2026-07-27T02:00:00.000Z",
      reason_code: "RULE_CORRECTION",
      reason_note: "Điều chỉnh theo biên bản vận hành.",
      payload: { adjustment_id: "adjustment-1" },
    });
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it("keeps all six v1 APIs and adds one bounded v2 operator read", async () => {
    const calls: Array<[AtlasRpcName, AtlasRpcRequest]> = [];
    const api = createRecipeAdjustmentApi({
      invoke: vi.fn(async (name, request) => {
        calls.push([name, request]);
        return {
          kind: "success" as const,
          response: { success: true as const },
        };
      }),
    });
    const command = recipeAdjustmentCommandRequest(
      "subject-1",
      "correlation-1",
      1,
      "TEST",
      "Kiểm tra hợp đồng.",
      {},
    );
    await api.getWorkbench("subject-1", "read-1");
    await api.getOperatorWorkbench("subject-1", "read-operator", "2026-08-14");
    await api.resolve("subject-1", "read-2", {
      as_of_date: "2026-07-27",
    });
    await api.preview("subject-1", "read-3", {
      as_of_date: "2026-07-27",
    });
    await api.create(command);
    await api.supersede(command);
    await api.cancel(command);

    for (const [, request] of calls.slice(-3)) {
      expect(request).toBe(command);
    }

    expect(calls.map(([name]) => name)).toEqual([
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.getWorkbench,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.getOperatorWorkbench,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.resolve,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.preview,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.create,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.supersede,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.cancel,
    ]);
  });

  it("builds explicit RECIPE-EFFECTIVE system and target-context reads", () => {
    expect(
      systemEffectiveRecipeRequest(
        "subject-1",
        "correlation-system",
        "2026-09-05",
        "dish-1",
        "school-type-1",
      ),
    ).toEqual({
      contract_version: "RECIPE-EFFECTIVE.v1",
      requested_by_auth_subject: "subject-1",
      correlation_id: "correlation-system",
      payload: {
        as_of_date: "2026-09-05",
        dish_id: "dish-1",
        school_type_id: "school-type-1",
      },
    });

    expect(
      recipeEffectiveTargetContextRequest(
        "subject-1",
        "correlation-school",
        "2026-09-05",
        "dish-1",
        { kind: "school", schoolId: "school-1" },
      ),
    ).toEqual({
      contract_version: "RECIPE-EFFECTIVE.v1",
      requested_by_auth_subject: "subject-1",
      correlation_id: "correlation-school",
      payload: {
        as_of_date: "2026-09-05",
        dish_id: "dish-1",
        school_id: "school-1",
      },
    });
  });

  it("maps effective reads to their reviewed RPCs", async () => {
    const calls: Array<[AtlasRpcName, AtlasRpcRequest]> = [];
    const api = createRecipeAdjustmentApi({
      invoke: vi.fn(async (name, request) => {
        calls.push([name, request]);
        return {
          kind: "success" as const,
          response: { success: true as const },
        };
      }),
    });

    await api.resolveSystem(
      "subject-1",
      "system-read",
      "2026-09-05",
      "dish-1",
      "school-type-1",
    );
    await api.getEffectiveTargetContext(
      "subject-1",
      "target-read",
      "2026-09-05",
      "dish-1",
      { kind: "system", schoolTypeId: "school-type-1" },
    );

    expect(calls.map(([name]) => name)).toEqual([
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.resolveSystem,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.getEffectiveTargetContext,
    ]);
  });

  it("parses target rows only when exact context and stable target XOR are shaped", () => {
    const targetContext = {
      as_of_date: "2026-09-05",
      dish_id: "dish-1",
      school_id: null,
      school_type_id: "school-type-1",
      selected_recipe: {
        dish_id: "dish-1",
        recipe_id: "recipe-1",
        recipe_version_id: "version-1",
        selection_scope: "SCHOOL_TYPE",
        basis_portions: 100,
      },
      basis_portions: 100,
      effective_lines: [
        {
          ingredient_id: "ingredient-base",
          ingredient_name: "Thịt heo hiệu lực",
          quantity_per_basis: 8,
          unit_id: "unit-1",
          unit_name: "kg",
          target_kind: "RECIPE_LINE",
          target_recipe_line_id: "recipe-line-1",
          adjustment_line_id: null,
          target_id: "recipe-line-1",
          source_layer: "RELEASED_RECIPE_VERSION",
        },
        {
          ingredient_id: "ingredient-1",
          ingredient_name: "Hành lá",
          quantity_per_basis: 2,
          unit_id: "unit-1",
          unit_name: "kg",
          target_kind: "ADJUSTMENT_LINE",
          target_recipe_line_id: null,
          adjustment_line_id: "adjustment-line-1",
          target_id: "adjustment-line-1",
          source_layer: "SYSTEM_DISH",
        },
      ],
      warnings: [],
      blockers: [],
    };

    expect(
      effectiveTargetContextFromResult({
        kind: "success",
        response: { success: true, target_context: targetContext },
      }),
    ).toEqual(targetContext);
    expect(
      effectiveTargetContextFromResult({
        kind: "success",
        response: {
          success: true,
          target_context: { ...targetContext, effective_lines: [{}] },
        },
      }),
    ).toBeNull();

    for (const malformedLine of [
      {
        ...targetContext.effective_lines[0],
        adjustment_line_id: "adjustment-line-conflict",
      },
      {
        ...targetContext.effective_lines[1],
        target_recipe_line_id: "recipe-line-conflict",
      },
      {
        ...targetContext.effective_lines[1],
        target_id: "wrong-target-id",
      },
    ]) {
      expect(
        effectiveTargetContextFromResult({
          kind: "success",
          response: {
            success: true,
            target_context: {
              ...targetContext,
              effective_lines: [malformedLine],
            },
          },
        }),
      ).toBeNull();
    }

    expect(
      effectiveTargetContextFromResult({
        kind: "success",
        response: {
          success: true,
          target_context: {
            ...targetContext,
            school_id: "school-1",
            school_type_id: null,
          },
        },
      }),
    ).toBeNull();
    expect(
      effectiveTargetContextFromResult({
        kind: "success",
        response: {
          success: true,
          target_context: {
            ...targetContext,
            selected_recipe: { recipe_id: "partial" },
          },
        },
      }),
    ).toBeNull();
  });

  it("rejects malformed previews instead of authorizing a write", () => {
    const composition = {
      status: "READY",
      as_of_date: "2026-09-05",
      school_id: "school-1",
      school_type_id: "school-type-1",
      dish_id: "dish-1",
      historical: false,
      selected_recipe: {
        dish_id: "dish-1",
        recipe_id: "recipe-1",
        recipe_version_id: "version-1",
        selection_scope: "SCHOOL_TYPE",
        basis_portions: 100,
      },
      lines: [],
      warnings: [],
      blockers: [],
    };
    const preview = {
      as_of_date: "2026-09-05",
      school_id: "school-1",
      school_type_id: null,
      dish_id: "dish-1",
      proposed_adjustment: {
        scope_kind: "SCHOOL_DISH",
        action_kind: "REMOVE",
      },
      before: composition,
      after: composition,
      affected_line_count: 1,
      can_save: true,
      warnings: [],
      blockers: [],
    };

    expect(
      adjustmentPreviewFromResult({
        kind: "success",
        response: { success: true, preview },
      }),
    ).toEqual(preview);
    expect(
      adjustmentPreviewFromResult({
        kind: "success",
        response: {
          success: true,
          preview: { ...preview, can_save: "yes" },
        },
      }),
    ).toBeNull();
    expect(
      adjustmentPreviewFromResult({
        kind: "success",
        response: {
          success: true,
          preview: {
            ...preview,
            before: { ...composition, lines: [{}] },
          },
        },
      }),
    ).toBeNull();
  });

  it("parses exact School and system Preview identities and rejects ambiguous context", () => {
    const composition = {
      status: "READY" as const,
      as_of_date: "2026-09-05",
      school_id: null,
      school_type_id: "school-type-1",
      dish_id: "dish-1",
      historical: false,
      selected_recipe: {
        dish_id: "dish-1",
        recipe_id: "recipe-1",
        recipe_version_id: "version-1",
        selection_scope: "SCHOOL_TYPE" as const,
        basis_portions: 100,
      },
      lines: [],
      warnings: [],
      blockers: [],
    };
    const systemPreview = {
      as_of_date: "2026-09-05",
      school_id: null,
      school_type_id: "school-type-1",
      dish_id: "dish-1",
      proposed_adjustment: {
        scope_kind: "SYSTEM_DISH",
        school_id: null,
        school_type_id: "school-type-1",
        dish_id: "dish-1",
      },
      before: composition,
      after: composition,
      affected_line_count: 1,
      can_save: true,
      warnings: [],
      blockers: [],
    };
    const parse = (preview: Record<string, JsonValue>) =>
      adjustmentPreviewFromResult({
        kind: "success",
        response: { success: true, preview },
      });

    expect(parse(systemPreview)).toEqual(systemPreview);
    expect(parse({ ...systemPreview, school_id: "proxy-school" })).toBeNull();
    expect(parse({ ...systemPreview, school_type_id: null })).toBeNull();

    const schoolComposition = {
      ...composition,
      school_id: "school-1",
    };
    const schoolPreview = {
      ...systemPreview,
      school_id: "school-1",
      school_type_id: null,
      proposed_adjustment: {
        scope_kind: "SCHOOL_DISH",
        school_id: "school-1",
        school_type_id: null,
        dish_id: "dish-1",
      },
      before: schoolComposition,
      after: schoolComposition,
    };
    expect(parse(schoolPreview)).toEqual(schoolPreview);
    expect(
      parse({ ...schoolPreview, school_type_id: "school-type-1" }),
    ).toBeNull();
  });

  it("accepts the four exact SQL revision projections and validates each consumed slot", async () => {
    const result = await createReviewRecipeAdjustmentApi(
      "ready",
    ).getOperatorWorkbench("subject", "correlation", "2026-09-06");
    if (result.kind !== "success") throw new Error("Expected fixture");
    const source = result.response.workbench as Record<string, JsonValue>;
    const row = (source.operator_rows as Array<Record<string, JsonValue>>)[0];
    // Exact JSON slots from 20260814045038_ui_quality_03b_recipe_adjustment_corrections.sql.
    const command = {
      revision_id: "10000000-0000-4000-8000-000000000001",
      effective_from: "2026-09-01",
      effective_to: null,
      substitute_ingredient_id: "17000000-0000-4000-8000-000000000003",
      quantity_per_basis: null,
      unit_id: null,
      reason_note: "Approved correction",
    };
    const issuance = {
      issued_at: null,
      issuance_kind: "LEGACY_UNATTRIBUTED",
      issued_by_actor_name: null,
    };
    const exactRow = {
      ...row,
      current_revision_id: command.revision_id,
      display_revision: { ...command, ...issuance, revision_status: "ACTIVE" },
      content_revision: { ...command, ...issuance, revision_status: "ACTIVE" },
      command_revision: command,
      history: [{ ...command, ...issuance, business_event_kind: "CREATED" }],
    };
    const parse = (operatorRow: Record<string, JsonValue>) =>
      adjustmentWorkbenchFromResult({
        kind: "success",
        response: {
          success: true,
          workbench: { ...source, operator_rows: [operatorRow] },
        },
      });
    expect(parse(exactRow)?.operator_rows[0]).toEqual(exactRow);
    for (const [slot, field, value] of [
      ["display_revision", "revision_status", "INVALID"],
      ["display_revision", "issued_at", 42],
      ["content_revision", "issuance_kind", "IMPORTER"],
      ["content_revision", "quantity_per_basis", "12"],
      ["command_revision", "revision_id", null],
      ["command_revision", "effective_from", 42],
      ["history", "business_event_kind", "UPSERT"],
      ["history", "issued_by_actor_name", {}],
    ] as const) {
      const invalid = structuredClone(exactRow) as Record<string, JsonValue>;
      const revision =
        slot === "history"
          ? (invalid.history as JsonValue[])[0]
          : invalid[slot];
      (revision as Record<string, JsonValue>)[field] = value;
      expect(parse(invalid), `${slot}.${field}`).toBeNull();
    }
  });

  it("accepts nullable legacy issuance and rejects malformed temporal authority", async () => {
    const result = await createReviewRecipeAdjustmentApi(
      "ready",
    ).getOperatorWorkbench("subject-1", "correlation-1", "2026-09-05");
    const parsed = adjustmentWorkbenchFromResult(result);

    expect(parsed).not.toBeNull();
    expect(parsed?.operator_rows[0]?.display_revision).toMatchObject({
      issuance_kind: "LEGACY_UNATTRIBUTED",
      issued_at: null,
      issued_by_actor_name: null,
    });

    if (result.kind !== "success") throw new Error("Expected review fixture");
    const workbench = structuredClone(result.response.workbench) as Record<
      string,
      unknown
    >;
    const rows = workbench.operator_rows as Array<Record<string, unknown>>;
    rows[0] = { ...rows[0], is_effective_now: "yes" };
    expect(
      adjustmentWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench } as never,
      }),
    ).toBeNull();
  });

  it("rejects malformed scope, catalog, and Recipe-line references", async () => {
    const result = await createReviewRecipeAdjustmentApi(
      "ready",
    ).getOperatorWorkbench("subject-1", "correlation-1", "2026-09-05");
    if (result.kind !== "success") throw new Error("Expected review fixture");
    const source = result.response.workbench;
    if (typeof source !== "object" || source === null || Array.isArray(source))
      throw new Error("Expected workbench object");

    const malformedRows: Array<{
      collection:
        | "scope_catalog"
        | "schools"
        | "dishes"
        | "school_types"
        | "ingredients"
        | "units"
        | "recipe_lines";
      field: string;
      value: JsonValue;
    }> = [
      {
        collection: "scope_catalog",
        field: "actions",
        value: ["REPLACE", "UPSERT"],
      },
      { collection: "schools", field: "school_id", value: 42 },
      { collection: "dishes", field: "dish_name", value: 42 },
      {
        collection: "school_types",
        field: "school_type_id",
        value: 42,
      },
      {
        collection: "ingredients",
        field: "purchase_unit_id",
        value: 42,
      },
      {
        collection: "units",
        field: "unit_id",
        value: null,
      },
      {
        collection: "recipe_lines",
        field: "quantity_per_basis",
        value: "8",
      },
    ];

    for (const { collection, field, value } of malformedRows) {
      const workbench = structuredClone(source);
      const rows = workbench[collection];
      if (!Array.isArray(rows) || rows.length === 0)
        throw new Error(`Expected ${collection} rows`);
      const row = rows[0];
      if (typeof row !== "object" || row === null || Array.isArray(row))
        throw new Error(`Expected ${collection} object row`);
      row[field] = value;
      expect(
        adjustmentWorkbenchFromResult({
          kind: "success",
          response: { success: true, workbench },
        }),
      ).toBeNull();
    }

    const malformedPrecedence = structuredClone(source);
    malformedPrecedence.precedence = ["RELEASED_RECIPE_VERSION", 7];
    expect(
      adjustmentWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench: malformedPrecedence },
      }),
    ).toBeNull();
  });
});
