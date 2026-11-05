// @vitest-environment node
import { expect, it } from "vitest";
import { createReviewRecipeAdjustmentApi } from "./reviewRecipeAdjustmentApi";
import { adjustmentWorkbenchFromResult } from "./recipeAdjustmentModel";
import type { AtlasRpcResult, JsonValue } from "../connection/atlasRpc";

it("accepts old reads but rejects malformed populated source history", async () => {
  const result = await createReviewRecipeAdjustmentApi().getOperatorWorkbench(
    "operator",
    "history-test",
    "2026-11-05",
  );
  expect(adjustmentWorkbenchFromResult(result)).not.toBeNull();
  if (result.kind !== "success") throw new Error("Fixture unavailable");
  const malformed: AtlasRpcResult = {
    ...result,
    response: {
      ...result.response,
      workbench: {
        ...(result.response.workbench as Record<string, JsonValue>),
        legacy_history: [{ legacy_id: "1", quantity: 1.000001 }],
      },
    },
  };
  expect(adjustmentWorkbenchFromResult(malformed)).toBeNull();
});
