// Checkpoint E comparison only. Three token variants on the existing review route.
// Keep D-048 composition, controller state, geometry and command contracts fixed.
import { createSystem, defineConfig } from "@chakra-ui/react";
import { Warning } from "@phosphor-icons/react";
import { renderToStaticMarkup } from "react-dom/server";
import { atlasSystem } from "./system";

export const legibilityPalettes = {
  A: {
    name: "Neutral High Contrast",
    workspace: "#D6DCE3",
    workbench: "#FFFFFF",
    toolbar: "#E4E8EE",
    subtle: "#E4E8EE",
    context: "#E4E8EE",
    selected: "#CCD6E2",
    navigation: "#242C36",
    navigationHover: "#354150",
    navMuted: "#E3E8EE",
    primary: "#263544",
    primaryHover: "#152330",
    text: "#17212B",
    muted: "#465360",
    border: "#7D8996",
    borderSoft: "#BBC4CE",
    control: "#657180",
    focus: "#263544",
    clay: "#263544",
    clayText: "#263544",
  },
  B: {
    name: "Strong Atlas Green",
    workspace: "#DCE4DF",
    workbench: "#FFFFFF",
    toolbar: "#E4EEE7",
    subtle: "#E4EEE7",
    context: "#E4EEE7",
    selected: "#CDE7D5",
    navigation: "#154B36",
    navigationHover: "#216246",
    navMuted: "#DDEEE4",
    primary: "#14623E",
    primaryHover: "#104C31",
    text: "#16271E",
    muted: "#40594B",
    border: "#718A7B",
    borderSoft: "#B3C7BA",
    control: "#527C65",
    focus: "#14623E",
    clay: "#14623E",
    clayText: "#14623E",
  },
  C: {
    name: "Neutral Operational + Atlas Accents",
    workspace: "#DCE1DD",
    workbench: "#FFFFFF",
    toolbar: "#E7EBE8",
    subtle: "#E7EBE8",
    context: "#E7EBE8",
    selected: "#E0EEE4",
    navigation: "#293630",
    navigationHover: "#3B4B42",
    navMuted: "#E0E7E2",
    primary: "#246044",
    primaryHover: "#194B33",
    text: "#1C2721",
    muted: "#48594E",
    border: "#7B8B82",
    borderSoft: "#BCC7BF",
    control: "#65796C",
    focus: "#246044",
    clay: "#246044",
    clayText: "#246044",
  },
} as const;

export type LegibilityVariant = keyof typeof legibilityPalettes;
const warningMask = `url("data:image/svg+xml,${encodeURIComponent(renderToStaticMarkup(<Warning />))}")`;
const controlBoundary = {
  borderWidth: "var(--atlas-legibility-edge, 1px)",
  borderColor: "var(--atlas-colors-border-control)",
} as const;
const selected = {
  fontWeight: "bold",
  textDecoration: "underline",
  textUnderlineOffset: "5px",
  textDecorationThickness: "var(--atlas-legibility-heavy-edge, 2px)",
  outline: "1px solid",
  outlineColor: "border.interactive",
  outlineOffset: "-1px",
} as const;

// Reuse the complete Atlas configuration, including scoped preflight and portals.
export function createLegibilitySystem(variant: LegibilityVariant) {
  const { name: _name, ...palette } = legibilityPalettes[variant];
  return createSystem(
    atlasSystem._config,
    defineConfig({
      globalCss: {
        ".atlas-vnext main label": {
          textStyle: "label",
          fontWeight: "semibold",
        },
        ".atlas-vnext main :is(input, select, textarea):not(:disabled)": {
          ...controlBoundary,
          bg: "bg.workbench",
        },
        ".atlas-vnext main": {
          borderWidth: "var(--atlas-legibility-edge, 1px)",
          borderColor: "border.default",
        },
        ".atlas-vnext [role=tab][aria-selected=true]": selected,
        ".atlas-vnext tr[aria-selected=true]": { fontWeight: "semibold" },
        ".atlas-vnext tr[aria-selected=true] td": {
          borderTopWidth: "var(--atlas-legibility-edge, 1px)",
          borderBottomWidth: "var(--atlas-legibility-edge, 1px)",
          borderColor: "border.interactive",
        },
        ".atlas-vnext tr[aria-selected=true] td:first-of-type": {
          textDecoration: "underline",
          textUnderlineOffset: "4px",
          boxShadow:
            "var(--atlas-legibility-selected-marker, inset 4px 0 0 var(--atlas-colors-action-primary-default))",
        },
        ".atlas-vnext table :is(th, td, p, span, button)": {
          fontSize: "var(--atlas-legibility-body-size, 14px)",
        },
        ".atlas-vnext [role=alert]": {
          bg: "bg.warning",
          borderWidth: "var(--atlas-legibility-edge, 1px)",
          borderColor: "status.warning",
          px: "sm",
          py: "sm",
          _before: {
            content: '\"\"',
            display: "inline-block",
            w: "var(--atlas-legibility-icon-size, 18px)",
            h: "var(--atlas-legibility-icon-size, 18px)",
            bg: "status.warning",
            maskImage: warningMask,
            maskSize: "contain",
            maskRepeat: "no-repeat",
            verticalAlign: "text-bottom",
            mr: "xs",
          },
        },
      },
      theme: {
        tokens: {
          colors: {
            atlas: Object.fromEntries(
              Object.entries(palette).map(([key, value]) => [key, { value }]),
            ),
          },
        },
        semanticTokens: {
          colors: {
            border: { control: { value: "{colors.atlas.control}" } },
            bg: {
              warning: { value: "#FFF1D6" },
              danger: { value: "#FCE7E5" },
              success: { value: "#E3F0E7" },
              info: { value: "#E5EFF5" },
            },
            status: {
              warning: { value: "#775015" },
              danger: { value: "#9A2E25" },
              success: { value: "#23613B" },
              info: { value: "#27566F" },
            },
          },
        },
        textStyles: {
          table: {
            value: {
              fontSize: "var(--atlas-legibility-body-size, 14px)",
              lineHeight: "1.45",
            },
          },
          label: {
            value: {
              fontSize: "var(--atlas-legibility-body-size, 14px)",
              fontWeight: "600",
              lineHeight: "1.4",
            },
          },
          helper: { value: { fontSize: "13px", lineHeight: "1.5" } },
          quantityInline: {
            value: {
              fontSize: "var(--atlas-legibility-body-size, 14px)",
              fontWeight: "600",
              lineHeight: "1.45",
              fontVariantNumeric: "tabular-nums",
            },
          },
          unitInline: {
            value: {
              fontSize: "var(--atlas-legibility-body-size, 14px)",
              lineHeight: "1.45",
            },
          },
        },
        recipes: {
          input: {
            base: controlBoundary,
            variants: { variant: { outline: controlBoundary } },
          },
          textarea: {
            base: {
              ...controlBoundary,
              bg: "bg.workbench",
              color: "fg.default",
              fontSize: "var(--atlas-legibility-body-size, 14px)",
            },
          },
          button: {
            variants: {
              variant: {
                secondary: {
                  borderColor: "var(--atlas-colors-border-control)",
                },
                tertiary: {
                  borderColor: "transparent",
                  textDecoration: "underline",
                  textUnderlineOffset: "3px",
                },
                tableAction: {
                  borderColor: "var(--atlas-colors-border-control)",
                },
              },
            },
          },
          badge: {
            base: {
              borderWidth: "var(--atlas-legibility-edge, 1px)",
              borderColor:
                "var(--atlas-legibility-status-stroke, currentColor)",
              fontWeight: "semibold",
            },
          },
        },
        slotRecipes: {
          field: {
            slots: [
              "root",
              "label",
              "helperText",
              "errorText",
              "requiredIndicator",
            ],
            base: {
              label: { color: "fg.default" },
              helperText: { textStyle: "helper" },
              errorText: { textStyle: "helper" },
            },
          },
          nativeSelect: {
            slots: ["root", "field", "indicator"],
            base: { field: controlBoundary },
            variants: { variant: { outline: { field: controlBoundary } } },
          },
          dateInput: {
            slots: ["root", "label", "control", "segmentGroup", "segment"],
            base: { segmentGroup: controlBoundary },
            variants: {
              variant: { outline: { segmentGroup: controlBoundary } },
            },
          },
          table: {
            slots: [
              "root",
              "header",
              "body",
              "row",
              "columnHeader",
              "cell",
              "footer",
              "caption",
            ],
            base: {
              root: {
                borderWidth: "var(--atlas-legibility-edge, 1px)",
                borderColor: "border.default",
              },
              columnHeader: {
                borderBottomWidth: "var(--atlas-legibility-heavy-edge, 2px)",
                borderBottomColor: "border.default",
              },
            },
          },
        },
      },
    }),
  );
}

export function LegibilityPrototypeSwitcher({
  variant,
}: {
  variant: LegibilityVariant;
}) {
  // Review route only; outside the Atlas work plane. Capture mode hides this comparison utility.
  if (new URLSearchParams(location.search).has("capture")) return null;
  return (
    <nav
      aria-label="So sánh giao diện — bản thử"
      style={{
        position: "fixed",
        bottom: 8,
        right: 8,
        zIndex: 9999,
        padding: 8,
        background: "#fff",
        border: "1px solid #657180",
        font: "14px Inter, sans-serif",
        boxShadow: "0 2px 8px #0002",
      }}
    >
      <strong>Prototype · {variant}</strong>{" "}
      {(Object.keys(legibilityPalettes) as LegibilityVariant[]).map((key) => {
        const url = new URL(location.href);
        url.searchParams.set("legibility", key);
        return (
          <a
            key={key}
            href={url.href}
            aria-current={key === variant ? "true" : undefined}
            style={{
              marginLeft: 10,
              color: "#174B36",
              textDecoration: "underline",
            }}
          >
            {key} · {legibilityPalettes[key].name}
          </a>
        );
      })}
    </nav>
  );
}
