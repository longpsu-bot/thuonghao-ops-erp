import {
  createSystem,
  defaultConfig,
  defineConfig,
  defineRecipe,
} from "@chakra-ui/react";

const fontFamily = 'Inter, "Segoe UI", Arial, sans-serif';
const focus = {
  outline: "2px solid",
  outlineColor: "focus.ring",
  outlineOffset: "2px",
};
const control = {
  borderRadius: "control",
  bg: "bg.workbench",
  borderColor: "border.default",
  color: "fg.default",
  _focusVisible: focus,
};

const button = defineRecipe({
  base: {
    borderRadius: "control",
    fontSize: "14px",
    fontWeight: "600",
    _focusVisible: focus,
  },
  variants: {
    size: {
      md: { h: "control", minW: "control", px: "md" },
      sm: { h: "compact", minW: "compact", px: "sm" },
    },
    variant: {
      businessPrimary: {
        bg: "fg.primary",
        color: "fg.inverse",
        _hover: { bg: "action.primary.hover" },
      },
      secondary: {
        bg: "bg.workbench",
        color: "fg.primary",
        borderWidth: "1px",
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
        _hover: { opacity: 0.9 },
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
        fontFamily,
        fontSize: "14px",
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
            navy: { value: "#1c2735" },
            navyHover: { value: "#303e51" },
            primary: { value: "#253246" },
            workspace: { value: "#f4f1eb" },
            white: { value: "#ffffff" },
            subtle: { value: "#f8f6f2" },
            selected: { value: "#edf3f7" },
            text: { value: "#22272e" },
            muted: { value: "#626b74" },
            copper: { value: "#b66a3c" },
            copperText: { value: "#a35b35" },
            border: { value: "#ddd8cf" },
            borderSoft: { value: "#e4e8ed" },
            navMuted: { value: "#aeb8c4" },
            success: { value: "#31745b" },
            successSoft: { value: "#eaf4ef" },
            warning: { value: "#714a0b" },
            warningSoft: { value: "#fff8e8" },
            danger: { value: "#b53e2e" },
            dangerSoft: { value: "#fff1ef" },
            info: { value: "#2f6594" },
            focusDark: { value: "#f2c66d" },
          },
        },
        spacing: {
          xs: { value: "6px" },
          sm: { value: "10px" },
          md: { value: "16px" },
          lg: { value: "24px" },
          xl: { value: "32px" },
        },
        radii: { control: { value: "6px" }, workbench: { value: "9px" } },
        sizes: { control: { value: "40px" }, compact: { value: "36px" } },
      },
      semanticTokens: {
        colors: {
          action: {
            primary: { hover: { value: "{colors.atlas.navyHover}" } },
          },
          bg: {
            DEFAULT: { value: "{colors.atlas.white}" },
            workspace: { value: "{colors.atlas.workspace}" },
            workbench: { value: "{colors.atlas.white}" },
            toolbar: { value: "{colors.atlas.subtle}" },
            subtle: { value: "{colors.atlas.subtle}" },
            selected: { value: "{colors.atlas.selected}" },
            navigation: { value: "{colors.atlas.navy}" },
            navigationHover: { value: "{colors.atlas.navyHover}" },
            success: { value: "{colors.atlas.successSoft}" },
            warning: { value: "{colors.atlas.warningSoft}" },
            danger: { value: "{colors.atlas.dangerSoft}" },
          },
          fg: {
            DEFAULT: { value: "{colors.atlas.text}" },
            default: { value: "{colors.atlas.text}" },
            muted: { value: "{colors.atlas.muted}" },
            primary: { value: "{colors.atlas.primary}" },
            accent: { value: "{colors.atlas.copperText}" },
            inverse: { value: "{colors.atlas.white}" },
            navMuted: { value: "{colors.atlas.navMuted}" },
          },
          border: {
            DEFAULT: { value: "{colors.atlas.border}" },
            default: { value: "{colors.atlas.border}" },
            subtle: { value: "{colors.atlas.borderSoft}" },
            accent: { value: "{colors.atlas.copper}" },
          },
          status: {
            success: { value: "{colors.atlas.success}" },
            warning: { value: "{colors.atlas.warning}" },
            danger: { value: "{colors.atlas.danger}" },
            info: { value: "{colors.atlas.info}" },
          },
          focus: {
            ring: { value: "{colors.atlas.info}" },
            inverse: { value: "{colors.atlas.focusDark}" },
          },
        },
      },
      textStyles: {
        workbenchTitle: {
          value: { fontSize: "24px", fontWeight: "650", lineHeight: "1.3" },
        },
        section: {
          value: { fontSize: "17px", fontWeight: "600", lineHeight: "1.4" },
        },
        body: { value: { fontSize: "14px", lineHeight: "1.5" } },
        table: { value: { fontSize: "13px", lineHeight: "1.4" } },
        label: {
          value: { fontSize: "13px", fontWeight: "600", lineHeight: "1.4" },
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
            size: { md: { h: "control", px: "sm", textStyle: "body" } },
          },
          defaultVariants: { size: "md" },
        },
        badge: defineRecipe({
          base: {
            borderRadius: "control",
            fontSize: "12px",
            fontWeight: "500",
            px: "xs",
            py: "2px",
          },
          variants: {
            variant: {
              neutral: { bg: "bg.subtle", color: "fg.muted" },
              success: { bg: "bg.success", color: "status.success" },
              warning: { bg: "bg.warning", color: "status.warning" },
              danger: { bg: "bg.danger", color: "status.danger" },
              information: { bg: "bg.selected", color: "status.info" },
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
            segment: { _focusVisible: focus },
          },
        },
        nativeSelect: {
          slots: ["root", "field", "indicator"],
          base: { field: control },
          variants: {
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
            root: { textStyle: "table" },
            columnHeader: {
              textStyle: "table",
              letterSpacing: "normal",
              bg: "bg.toolbar",
              color: "fg.muted",
              fontWeight: "600",
              textTransform: "none",
            },
            cell: { borderColor: "border.subtle" },
            row: { _selected: { bg: "bg.selected" } },
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
