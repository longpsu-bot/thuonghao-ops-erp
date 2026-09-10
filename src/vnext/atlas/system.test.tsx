import { describe, expect, it } from "vitest";
import type { SystemStyleObject } from "@chakra-ui/react";
import { atlasSystem } from "./system";

// Typecheck must reject a casual raw color after the configured CLI typegen.
const rejectedColor: SystemStyleObject = {
  // @ts-expect-error Atlas requires a token, not an arbitrary color string.
  bg: "#f7f8fa",
};

const palette = {
  workspace: "#F2F4F2",
  workbench: "#FAFBFA",
  toolbar: "#F0F4F1",
  subtle: "#F6F8F6",
  selected: "#E7EFEB",
  navigation: "#31413E",
  navigationHover: "#3B4D49",
  navMuted: "#C2CBC7",
  primary: "#35564C",
  primaryHover: "#2F4B43",
  text: "#2A3330",
  muted: "#66726D",
  clay: "#B47A56",
  clayText: "#915D3E",
  border: "#D8DFDB",
  borderSoft: "#E4E9E6",
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
      columnHeader: { bg: "bg.toolbar", color: "fg.muted" },
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
});
