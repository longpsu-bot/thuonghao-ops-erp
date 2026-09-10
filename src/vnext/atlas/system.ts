import {
  createSystem,
  defaultConfig,
  defineConfig,
  defineRecipe,
} from "@chakra-ui/react";

const fontFamily = 'Inter, "Segoe UI", Arial, sans-serif';
const focus = {
  outlineWidth: "var(--atlas-layout-focus-width, 2px)",
  outlineStyle: "solid",
  outlineColor: "focus.ring",
  outlineOffset: "var(--atlas-layout-focus-offset, 2px)",
} as const;
const control = {
  borderRadius: "control",
  bg: "bg.workbench",
  borderColor: "border.default",
  color: "fg.default",
  focusRingColor: "focus.ring",
  _placeholder: { color: "fg.muted" },
  _focusVisible: focus,
} as const;

const button = defineRecipe({
  base: {
    borderRadius: "control",
    textStyle: "body",
    fontWeight: "semibold",
    _focusVisible: focus,
  },
  variants: {
    size: {
      md: { h: "control", minW: "control", px: "md" },
      sm: { h: "compact", minW: "compact", px: "sm" },
    },
    variant: {
      businessPrimary: {
        bg: "action.primary.default",
        color: "fg.inverse",
        _hover: { bg: "action.primary.hover" },
      },
      secondary: {
        bg: "bg.workbench",
        color: "fg.primary",
        borderWidth: "var(--atlas-layout-edge, 1px)",
        borderColor: "border.default",
        _hover: { bg: "bg.subtle" },
      },
      utility: {
        bg: "transparent",
        color: "fg.muted",
        _hover: { bg: "bg.selected", color: "fg.primary" },
      },
      destructive: {
        bg: "status.danger",
        color: "fg.inverse",
        _hover: { opacity: "var(--atlas-layout-hover-opacity, 0.9)" },
      },
    },
  },
  defaultVariants: { size: "md", variant: "secondary" },
});

// Retain Chakra's complete configuration, but relocate its global selectors to
// the isolated root. Merely scoping preflight would leave global html styles.
const { globalCss: chakraGlobals, ...chakraConfig } = defaultConfig;
const { html: rootStyles, ...descendantStyles } = chakraGlobals ?? {};

export const atlasSystem = createSystem(
  chakraConfig,
  defineConfig({
    cssVarsPrefix: "atlas",
    strictTokens: true,
    // Legacy Storybook loads unlayered element rules. Keep scoped Chakra classes
    // in that cascade so the new reference retains its own typography.
    disableLayers: true,
    cssVarsRoot: ".atlas-vnext",
    // Scope inherited conditional tokens too; Atlas currently renders light only.
    conditions: {
      light: "&.atlas-vnext",
      dark: "&.atlas-vnext[data-atlas-color-mode=dark]",
    },
    preflight: { scope: ":where(.atlas-vnext)" },
    globalCss: {
      ".atlas-vnext": {
        ...rootStyles,
        ...descendantStyles,
        fontFamily: "body",
        textStyle: "body",
        color: "fg.default",
        bg: "bg.workspace",
        colorScheme: "light",
        "& :focus-visible": focus,
      },
    },
    theme: {
      tokens: {
        fonts: { body: { value: fontFamily }, heading: { value: fontFamily } },
        colors: {
          atlas: {
            workspace: { value: "#F2F4F2" },
            workbench: { value: "#FAFBFA" },
            toolbar: { value: "#F0F4F1" },
            subtle: { value: "#F6F8F6" },
            selected: { value: "#E7EFEB" },
            navigation: { value: "#31413E" },
            navigationHover: { value: "#3B4D49" },
            navMuted: { value: "#C2CBC7" },
            primary: { value: "#35564C" },
            primaryHover: { value: "#2F4B43" },
            text: { value: "#2A3330" },
            muted: { value: "#66726D" },
            clay: { value: "#B47A56" },
            clayText: { value: "#915D3E" },
            border: { value: "#D8DFDB" },
            borderSoft: { value: "#E4E9E6" },
            focus: { value: "#567A71" },
            focusDark: { value: "#E0B589" },
            success: { value: "#3F755E" },
            successSoft: { value: "#EAF3ED" },
            warning: { value: "#80612A" },
            warningSoft: { value: "#F8F1DF" },
            danger: { value: "#A3493F" },
            dangerSoft: { value: "#F9ECEA" },
            info: { value: "#456D76" },
            infoSoft: { value: "#E9F0F1" },
            white: { value: "#FFFFFF" },
          },
        },
        spacing: {
          xs: { value: "6px" },
          sm: { value: "10px" },
          md: { value: "16px" },
          lg: { value: "24px" },
          xl: { value: "32px" },
        },
        radii: { control: { value: "6px" }, workbench: { value: "6px" } },
        sizes: { control: { value: "40px" }, compact: { value: "36px" } },
      },
      semanticTokens: {
        colors: {
          action: {
            primary: {
              default: { value: "{colors.atlas.primary}" },
              hover: { value: "{colors.atlas.primaryHover}" },
            },
          },
          bg: {
            DEFAULT: { value: "{colors.atlas.workbench}" },
            workspace: { value: "{colors.atlas.workspace}" },
            workbench: { value: "{colors.atlas.workbench}" },
            toolbar: { value: "{colors.atlas.toolbar}" },
            subtle: { value: "{colors.atlas.subtle}" },
            selected: { value: "{colors.atlas.selected}" },
            navigation: { value: "{colors.atlas.navigation}" },
            navigationHover: { value: "{colors.atlas.navigationHover}" },
            success: { value: "{colors.atlas.successSoft}" },
            warning: { value: "{colors.atlas.warningSoft}" },
            danger: { value: "{colors.atlas.dangerSoft}" },
            info: { value: "{colors.atlas.infoSoft}" },
          },
          fg: {
            DEFAULT: { value: "{colors.atlas.text}" },
            default: { value: "{colors.atlas.text}" },
            muted: { value: "{colors.atlas.muted}" },
            primary: { value: "{colors.atlas.primary}" },
            accent: { value: "{colors.atlas.clayText}" },
            inverse: { value: "{colors.atlas.white}" },
            navMuted: { value: "{colors.atlas.navMuted}" },
          },
          border: {
            DEFAULT: { value: "{colors.atlas.border}" },
            default: { value: "{colors.atlas.border}" },
            subtle: { value: "{colors.atlas.borderSoft}" },
            accent: { value: "{colors.atlas.clay}" },
          },
          status: {
            success: { value: "{colors.atlas.success}" },
            warning: { value: "{colors.atlas.warning}" },
            danger: { value: "{colors.atlas.danger}" },
            info: { value: "{colors.atlas.info}" },
          },
          focus: {
            ring: { value: "{colors.atlas.focus}" },
            inverse: { value: "{colors.atlas.focusDark}" },
          },
        },
      },
      textStyles: {
        brand: { value: { fontSize: "28px", fontWeight: "650" } },
        brandCompact: { value: { fontSize: "20px", fontWeight: "650" } },
        quantity: { value: { fontSize: "22px", fontWeight: "600" } },
        workbenchTitle: {
          value: { fontSize: "24px", fontWeight: "650", lineHeight: "1.3" },
        },
        section: {
          value: {
            fontSize: "17px",
            fontWeight: "semibold",
            lineHeight: "1.4",
          },
        },
        body: { value: { fontSize: "14px", lineHeight: "1.5" } },
        table: { value: { fontSize: "13px", lineHeight: "1.4" } },
        label: {
          value: {
            fontSize: "13px",
            fontWeight: "semibold",
            lineHeight: "1.4",
          },
        },
        helper: { value: { fontSize: "12px", lineHeight: "1.5" } },
      },
      keyframes: {
        atlasRefreshSpin: { to: { transform: "rotate(360deg)" } },
        atlasRefreshComplete: {
          "0%, 100%": { transform: "translateY(0)" },
          "45%": { transform: "translateY(-2px)" },
        },
      },
      animationStyles: {
        refreshSpin: {
          value: {
            animation: "atlasRefreshSpin 800ms linear infinite",
            _motionReduce: { animation: "none" },
          },
        },
        refreshComplete: {
          value: {
            animation: "atlasRefreshComplete 200ms ease-out",
            _motionReduce: { animation: "none" },
          },
        },
      },
      recipes: {
        button,
        input: {
          base: control,
          variants: {
            variant: { outline: control },
            size: { md: { h: "control", px: "sm", textStyle: "body" } },
          },
          defaultVariants: { size: "md" },
        },
        badge: defineRecipe({
          base: {
            borderRadius: "control",
            textStyle: "helper",
            fontWeight: "medium",
            px: "xs",
            py: "0.5",
          },
          variants: {
            variant: {
              neutral: { bg: "bg.subtle", color: "fg.muted" },
              success: { bg: "bg.success", color: "status.success" },
              warning: { bg: "bg.warning", color: "status.warning" },
              danger: { bg: "bg.danger", color: "status.danger" },
              information: { bg: "bg.info", color: "status.info" },
            },
          },
          defaultVariants: { variant: "neutral" },
        }),
      },
      slotRecipes: {
        dateInput: {
          slots: ["root", "label", "control", "segmentGroup", "segment"],
          base: {
            root: { gap: "xs", width: "full" },
            label: { textStyle: "label", color: "fg.default" },
            segmentGroup: {
              ...control,
              h: "control",
              minH: "control",
              px: "sm",
              textStyle: "body",
            },
            segment: {
              _focusVisible: focus,
              _placeholderShown: { color: "fg.muted" },
              "&[data-type=literal]": { color: "fg.muted" },
            },
          },
          variants: {
            variant: {
              outline: {
                segmentGroup: control,
                segment: { _focus: { bg: "bg.selected", color: "fg.default" } },
              },
            },
          },
        },
        nativeSelect: {
          slots: ["root", "field", "indicator"],
          base: { field: control },
          variants: {
            variant: { outline: { field: control } },
            size: {
              md: {
                field: { h: "control", ps: "sm", pe: "xl", textStyle: "body" },
              },
            },
          },
          defaultVariants: { size: "md" },
        },
        field: {
          slots: [
            "root",
            "label",
            "helperText",
            "errorText",
            "requiredIndicator",
          ],
          base: {
            label: { textStyle: "label", color: "fg.default" },
            root: { gap: "xs" },
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
            root: { textStyle: "table", bg: "bg.workbench" },
            columnHeader: {
              textStyle: "table",
              letterSpacing: "var(--atlas-layout-tracking, normal)",
              bg: "bg.toolbar",
              borderColor: "border.subtle",
              color: "fg.muted",
              fontWeight: "semibold",
              textTransform: "none",
            },
            cell: {
              borderColor: "border.subtle",
              "& [data-selection-indicator]": {
                position: "absolute",
                insetY: "xs",
                left: "var(--atlas-layout-zero, 0)",
                width: "var(--atlas-layout-rail, 3px)",
                bg: "border.accent",
              },
            },
            row: {
              transition:
                "var(--atlas-layout-row-transition, background-color 140ms ease-out)",
              _hover: { bg: "bg.subtle" },
              _selected: { bg: "bg.selected", _hover: { bg: "bg.selected" } },
              _motionReduce: { transition: "var(--atlas-layout-motion, none)" },
              "&[aria-selected=true], &[data-attention=true]": {
                "& [data-row-secondary], & button": { color: "fg.primary" },
              },
            },
          },
          variants: {
            size: {
              sm: {
                root: { textStyle: "table" },
                columnHeader: { px: "sm", py: "sm" },
                cell: { px: "sm", py: "xs" },
              },
            },
          },
          defaultVariants: { size: "sm" },
        },
      },
    },
  }),
);

export default atlasSystem;
