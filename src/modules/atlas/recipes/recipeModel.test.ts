import { describe, expect, it } from "vitest";
import { emptyRecipeWorkbench, recipeWorkbenchFromResult } from "./recipeModel";

describe("recipe workbench response parsing", () => {
  it("reads the authoritative nested workbench envelope", () => {
    const workbench = emptyRecipeWorkbench();
    expect(
      recipeWorkbenchFromResult({
        kind: "success",
        response: {
          success: true,
          workbench,
        },
      }),
    ).toEqual(workbench);
  });

  it("fails closed when a required collection is missing", () => {
    expect(
      recipeWorkbenchFromResult({
        kind: "success",
        response: {
          success: true,
          workbench: {
            dishes: [],
          },
        },
      }),
    ).toBeNull();
  });
});
