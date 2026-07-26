import { describe, expect, it } from "vitest";
import { isAtlasReviewMode } from "./reviewMode";

describe("Atlas review build flag", () => {
  it("enables review mode only for the explicit true value", () => {
    expect(isAtlasReviewMode({ VITE_ATLAS_REVIEW_MODE: "true" })).toBe(true);
    expect(isAtlasReviewMode({ VITE_ATLAS_REVIEW_MODE: "false" })).toBe(false);
    expect(isAtlasReviewMode({ VITE_ATLAS_REVIEW_MODE: "1" })).toBe(false);
    expect(isAtlasReviewMode({})).toBe(false);
  });
});
