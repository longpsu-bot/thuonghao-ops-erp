import { describe, expect, it } from "vitest";
import type { SystemStyleObject } from "@chakra-ui/react";
import {
  atlasPrimaryTabTrigger,
  atlasSecondaryTabTrigger,
} from "./AtlasTaskTabs";
import { atlasSystem } from "./system";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

function luminance(hex: string) {
  const rgb = hex.match(/^#([\da-f]{2})([\da-f]{2})([\da-f]{2})$/i);
  if (!rgb) throw new Error(`Expected resolved sRGB color: ${hex}`);
  const [r, g, b] = rgb.slice(1).map((c) => {
    const v = parseInt(c, 16) / 255;
    return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
function color(name: string): string {
  const token = atlasSystem.tokens.getByName(`colors.${name}`);
  expect(token, name).toBeDefined();
  const value = String(token?.originalValue);
  const reference = value.match(/^\{colors\.(.+)\}$/);
  return reference ? color(reference[1]) : value;
}

describe("Atlas v3 color and typography floors", () => {
  it("provides monotonic neutral, Brand and independent status scales", () => {
    for (const [family, steps] of Object.entries({
      neutral: [25, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950],
      brand: [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950],
      success: [50, 200, 500, 600, 700],
      warning: [50, 200, 500, 600, 700],
      danger: [50, 200, 500, 600, 700],
      info: [50, 200, 500, 600, 700],
    })) {
      let previous = 2;
      for (const step of steps) {
        const value = color(`${family}.${step}`),
          current = luminance(value);
        expect(current, `${family}.${step}`).toBeLessThan(previous);
        if (family === "neutral")
          expect(new Set(value.slice(1).match(/../g)).size).toBe(1);
        previous = current;
      }
    }
    expect(color("status.success")).not.toBe(color("action.primary.default"));
    const planes = [
      "bg.workspace",
      "bg.workbench",
      "bg.toolbar",
      "bg.tableHeader",
    ];
    expect(new Set(planes.map(color)).size).toBe(3);
    for (const name of planes)
      expect(new Set(color(name).slice(1).match(/../g)).size).toBe(1);
    expect(color("fg.primary")).toBe(color("neutral.900"));
    expect(color("bg.workspace")).toBe(color("neutral.100"));
    expect(color("bg.navigation")).toBe(color("brand.900"));
    expect(color("fg.attention")).not.toBe(color("status.warning"));
  });
  it.each([
    ["fg.primary", "bg.workbench", 7],
    ["fg.secondary", "bg.workbench", 7],
    ["fg.muted", "bg.workbench", 4.5],
    ["fg.placeholder", "bg.workbench", 4.5],
    ["border.default", "bg.workbench", 3],
    ["border.strong", "bg.toolbar", 3],
    ["border.strong", "bg.workbench", 3],
    ["fg.inverse", "action.primary.default", 7],
    ["fg.inverse", "action.primary.hover", 7],
    ["fg.inverse", "action.primary.pressed", 7],
    ["fg.primary", "bg.selected", 7],
    ["border.accent", "bg.selected", 3],
    ["focus.ring", "bg.workbench", 3],
    ["focus.ring", "bg.toolbar", 3],
    ["focus.ring", "bg.selected", 3],
    ["focus.inverse", "bg.navigation", 3],
    ["fg.disabled", "bg.disabled", 4.5],
    ["status.danger", "bg.danger", 4.5],
    ["status.warning", "bg.warning", 4.5],
    ["status.info", "bg.info", 4.5],
    ["status.success", "bg.success", 4.5],
    ["border.danger", "bg.danger", 3],
    ["border.warning", "bg.warning", 3],
    ["border.info", "bg.info", 3],
    ["border.success", "bg.success", 3],
  ])("keeps %s against %s above %s:1", (a, b, floor) => {
    const [high, low] = [
      luminance(color(String(a))),
      luminance(color(String(b))),
    ].sort((x, y) => y - x);
    expect((high + 0.05) / (low + 0.05)).toBeGreaterThanOrEqual(Number(floor));
  });
  it("keeps operational typography large enough for repeated scanning", () => {
    const styles = atlasSystem._config.theme?.textStyles;
    for (const name of ["table", "label", "quantityInline"])
      expect(styles?.[name]?.value).toMatchObject({ fontSize: "14px" });
    for (const name of ["helper", "unitInline"])
      expect(styles?.[name]?.value).toMatchObject({ fontSize: "13px" });
    expect(styles?.label?.value).toMatchObject({ fontWeight: "semibold" });
  });
  it("keeps resting input boundaries and error indication explicit", () => {
    const control = {
      borderColor: "border.strong",
      _invalid: { borderColor: "status.danger" },
    };
    expect(atlasSystem.getRecipe("input").base).toMatchObject(control);
    expect(atlasSystem.getRecipe("textarea").base).toMatchObject(control);
    expect(atlasSystem.getSlotRecipe("nativeSelect").base?.field).toMatchObject(
      control,
    );
    expect(
      atlasSystem.getSlotRecipe("dateInput").base?.segmentGroup,
    ).toMatchObject(control);
    expect(
      atlasSystem.getSlotRecipe("field").base?.label?._disabled,
    ).toMatchObject({
      color: "fg.disabled",
      opacity: "var(--atlas-layout-disabled-opacity, 1)",
    });
  });
  it("neutralizes disabled primary hover and press as well as rest", () => {
    const disabled = {
      bg: "bg.disabled",
      color: "fg.disabled",
      borderColor: "border.disabled",
    };
    const primary =
      atlasSystem.getRecipe("button").variants?.variant?.businessPrimary;
    expect(primary?._disabled).toMatchObject(disabled);
    expect(primary?._disabled?._hover).toMatchObject(disabled);
    expect(primary?._disabled?._active).toMatchObject(disabled);
    expect(
      atlasSystem.getRecipe("button").variants?.variant?.secondary,
    ).toMatchObject({ borderColor: "border.strong" });
    expect(atlasSystem.getSlotRecipe("checkbox").base?.control).toMatchObject({
      borderColor: "border.strong",
      _disabled: disabled,
      "&:is([data-state=checked], [data-state=indeterminate])": {
        bg: "action.primary.default",
        _disabled: disabled,
      },
    });
  });
  it("rejects casual component colors and production prototype selectors", () => {
    function audit(directory: string) {
      for (const entry of readdirSync(directory, { withFileTypes: true })) {
        const path = join(directory, entry.name);
        if (entry.isDirectory()) audit(path);
        else if (
          /\.tsx?$/.test(path) &&
          !/\.(test|stories)\./.test(path) &&
          entry.name !== "system.ts"
        ) {
          const source = readFileSync(path, "utf8");
          expect(source, path).not.toMatch(
            /#[\da-f]{3,8}\b|\brgba?\(|\bhsla?\(/i,
          );
          expect(source, path).not.toMatch(
            /AtlasLegibilityVariants|atlas-variant/,
          );
        }
      }
    }
    audit("src/vnext/atlas");
  });
});

// Typecheck must reject a casual raw color after the configured CLI typegen.
const rejectedColor: SystemStyleObject = {
  // @ts-expect-error Atlas requires a token, not an arbitrary color string.
  bg: "#f7f8fa",
};

describe("Atlas v3 operational legibility", () => {
  it("keeps interactive controls at the 44px mobile target without changing desktop density", () => {
    const mobileTarget = {
      base: "var(--atlas-layout-mobile-target, 44px)",
      lg: "var(--atlas-layout-zero, 0)",
    };
    expect(atlasSystem.getRecipe("button").base?.minH).toEqual(mobileTarget);
    expect(atlasSystem.getRecipe("input").base?.minH).toEqual(mobileTarget);
    expect(atlasSystem.getSlotRecipe("nativeSelect").base?.field?.minH).toEqual(
      mobileTarget,
    );
    expect(
      atlasSystem.getSlotRecipe("dateInput").base?.segmentGroup?.minH,
    ).toEqual(mobileTarget);
    expect(atlasSystem.getSlotRecipe("datePicker").base?.trigger?.w).toEqual({
      base: "var(--atlas-layout-mobile-target, 44px)",
      lg: "compact",
    });
    expect(atlasPrimaryTabTrigger.minH).toEqual(mobileTarget);
    expect(atlasSecondaryTabTrigger.minH).toEqual(mobileTarget);
  });
  it("gives disabled controls readable neutral surfaces instead of fading active colors", () => {
    const disabled = {
      bg: "bg.disabled",
      color: "fg.disabled",
      borderColor: "border.disabled",
      opacity: "var(--atlas-layout-disabled-opacity, 1)",
      cursor: "disabled",
    };
    expect(atlasSystem.getRecipe("button").base?._disabled).toMatchObject(
      disabled,
    );
    expect(atlasSystem.getRecipe("input").base?._disabled).toMatchObject(
      disabled,
    );
    expect(
      atlasSystem.getSlotRecipe("nativeSelect").base?.field?._disabled,
    ).toMatchObject(disabled);
    expect(
      atlasSystem.getSlotRecipe("dateInput").base?.segmentGroup?._disabled,
    ).toMatchObject(disabled);
    expect(
      atlasSystem.getSlotRecipe("dateInput").base?.root?._disabled,
    ).toMatchObject({ opacity: "var(--atlas-layout-disabled-opacity, 1)" });
  });
  it("enforces strict tokens", () => {
    expect(atlasSystem._config.strictTokens).toBe(true);
    expect(rejectedColor).toHaveProperty("bg");
  });
  it("keeps semantic focus colors independent of inherited outline shorthand", () => {
    const focus = atlasSystem.getRecipe("button").base?._focusVisible;
    expect(focus).toMatchObject({
      outlineColor: "focus.ring",
      outlineWidth: "var(--atlas-layout-focus-width, 2px)",
      outlineStyle: "solid",
    });
    expect(focus).not.toHaveProperty("outline");
  });
  it("keeps outline controls white with readable placeholders and Brand focus", () => {
    expect(
      atlasSystem.getRecipe("input").variants?.variant?.outline,
    ).toMatchObject({
      bg: "bg.workbench",
      focusRingColor: "focus.ring",
      _placeholder: { color: "fg.placeholder" },
    });
    expect(
      atlasSystem.getSlotRecipe("nativeSelect").variants?.variant?.outline,
    ).toMatchObject({
      field: { bg: "bg.workbench", focusRingColor: "focus.ring" },
    });
    expect(
      atlasSystem.getSlotRecipe("dateInput").variants?.variant?.outline,
    ).toMatchObject({
      segmentGroup: { bg: "bg.workbench", focusRingColor: "focus.ring" },
    });
  });
  it("owns quiet table selection and its Brand geometric cue in the shared recipe", () => {
    expect(atlasSystem.getSlotRecipe("table").base).toMatchObject({
      root: { bg: "bg.workbench" },
      columnHeader: { bg: "bg.tableHeader", color: "fg.default" },
      row: {
        _selected: { bg: "bg.selected" },
        _motionReduce: { transition: "var(--atlas-layout-motion, none)" },
      },
      cell: {
        "& [data-selection-indicator]": {
          bg: "border.accent",
          width: "var(--atlas-layout-rail, 3px)",
        },
      },
    });
  });
  it("authors controls as one operational system with a quiet row-action variant", () => {
    expect(atlasSystem.getRecipe("input").base).toMatchObject({
      bg: "bg.workbench",
      _hover: { borderColor: "border.interactive" },
    });
    expect(atlasSystem.getSlotRecipe("nativeSelect").base?.field).toMatchObject(
      {
        bg: "bg.workbench",
        _hover: { borderColor: "border.interactive" },
      },
    );
    expect(
      atlasSystem.getRecipe("button").variants?.variant?.tableAction,
    ).toMatchObject({
      bg: "transparent",
      color: "fg.primary",
      borderColor: "border.subtle",
      _hover: { bg: "bg.selected", borderColor: "border.interactive" },
    });
  });
  it("gives operational tables an authored header and restrained row rhythm", () => {
    expect(atlasSystem.getSlotRecipe("table").base).toMatchObject({
      columnHeader: {
        minH: "var(--atlas-table-header-height, 38px)",
        bg: "bg.tableHeader",
        color: "fg.default",
        fontWeight: "emphasis",
        borderBottomColor: "border.subtle",
        _after: {
          w: "var(--atlas-layout-edge, 1px)",
          bg: "border.subtle",
        },
      },
      cell: {
        _after: {
          w: "var(--atlas-layout-edge, 1px)",
          bg: "border.subtle",
        },
        "&[data-sticky-column]::after": { bg: "border.default" },
      },
      row: {
        borderBottomWidth: "var(--atlas-layout-edge, 1px)",
        borderBottomColor: "border.subtle",
      },
    });
  });
  it("separates task switching from source switching without filled-chip tabs", () => {
    expect(atlasPrimaryTabTrigger._selected).toMatchObject({
      color: "fg.primary",
      bg: "bg.workbench",
      borderColor: "border.accent",
    });
    expect(atlasPrimaryTabTrigger._after).toMatchObject({
      bg: "border.accent",
      height: "var(--atlas-layout-tab-marker, 3px)",
    });
    expect(atlasSecondaryTabTrigger._selected).toMatchObject({
      color: "fg.primary",
      bg: "bg.workbench",
      borderColor: "border.accent",
      fontWeight: "semibold",
    });
  });
});
