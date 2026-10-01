import { describe, expect, it } from "vitest";
import type { SystemStyleObject } from "@chakra-ui/react";
import {
  atlasPrimaryTabTrigger,
  atlasSecondaryTabTrigger,
} from "./AtlasTaskTabs";
import { atlasSystem } from "./system";

// Typecheck must reject a casual raw color after the configured CLI typegen.
const rejectedColor: SystemStyleObject = {
  // @ts-expect-error Atlas requires a token, not an arbitrary color string.
  bg: "#f7f8fa",
};

const palette = {
  workspace: "#EDF0ED",
  workbench: "#FBFCFB",
  toolbar: "#EEF3F0",
  subtle: "#F5F7F5",
  selected: "#E7EFEB",
  context: "#DDE7E1",
  navigation: "#31413E",
  navigationHover: "#3B4D49",
  navMuted: "#C2CBC7",
  primary: "#35564C",
  primaryHover: "#2F4B43",
  text: "#2A3330",
  muted: "#5C6964",
  clay: "#B47A56",
  clayText: "#915D3E",
  border: "#CED8D3",
  borderSoft: "#DCE4E0",
  focus: "#567A71",
  focusDark: "#E0B589",
  success: "#3F755E",
  successSoft: "#EAF3ED",
  warning: "#80612A",
  warningSoft: "#F8F1DF",
  danger: "#A3493F",
  dangerSoft: "#F9ECEA",
  info: "#456D76",
  infoSoft: "#E9F0F1",
};

describe("Soft Mineral architecture", () => {
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
      bg: "bg.subtle",
      color: "fg.muted",
      borderColor: "border.subtle",
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
  it("owns the exact approved raw palette in the Chakra system", () => {
    for (const [name, value] of Object.entries(palette))
      expect(atlasSystem.token(`colors.atlas.${name}`), name).toBe(value);
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
  it("keeps outline controls off-white with readable placeholders and mineral focus", () => {
    expect(
      atlasSystem.getRecipe("input").variants?.variant?.outline,
    ).toMatchObject({
      bg: "bg.workbench",
      focusRingColor: "focus.ring",
      _placeholder: { color: "fg.muted" },
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
  it("maps visual meanings to independent semantic tokens", () => {
    const colors = atlasSystem._config.theme?.semanticTokens?.colors;
    expect(colors).toMatchObject({
      bg: Object.fromEntries(
        [
          "workspace",
          "workbench",
          "toolbar",
          "subtle",
          "selected",
          "context",
          "navigation",
          "navigationHover",
        ].map((name) => [name, { value: `{colors.atlas.${name}}` }]),
      ),
      fg: {
        default: { value: "{colors.atlas.text}" },
        muted: { value: "{colors.atlas.muted}" },
        accent: { value: "{colors.atlas.clayText}" },
      },
      border: { accent: { value: "{colors.atlas.clay}" } },
      action: {
        primary: {
          default: { value: "{colors.atlas.primary}" },
          hover: { value: "{colors.atlas.primaryHover}" },
        },
      },
      focus: {
        ring: { value: "{colors.atlas.focus}" },
        inverse: { value: "{colors.atlas.focusDark}" },
      },
    });
    for (const family of ["success", "warning", "danger", "info"]) {
      expect(colors).toMatchObject({
        bg: { [family]: { value: `{colors.atlas.${family}Soft}` } },
        status: { [family]: { value: `{colors.atlas.${family}}` } },
      });
    }
    expect(
      atlasSystem.getRecipe("button").variants?.variant?.businessPrimary,
    ).toMatchObject({
      bg: "action.primary.default",
      _hover: { bg: "action.primary.hover" },
    });
  });
  it("owns quiet table selection and its clay geometric cue in the shared recipe", () => {
    expect(atlasSystem.getSlotRecipe("table").base).toMatchObject({
      root: { bg: "bg.workbench" },
      columnHeader: { bg: "bg.toolbar", color: "fg.default" },
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
  it("authors controls as one mineral system with a quiet row-action variant", () => {
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
        bg: "bg.toolbar",
        color: "fg.default",
        fontWeight: "emphasis",
        borderBottomColor: "border.default",
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
      borderColor: "transparent",
    });
    expect(atlasPrimaryTabTrigger._after).toMatchObject({
      bg: "border.accent",
      height: "var(--atlas-layout-tab-marker, 3px)",
    });
    expect(atlasSecondaryTabTrigger._selected).toMatchObject({
      color: "fg.primary",
      bg: "transparent",
      fontWeight: "semibold",
    });
  });
});
