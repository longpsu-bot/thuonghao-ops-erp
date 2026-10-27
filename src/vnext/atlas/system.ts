import {
  createSystem,
  defaultConfig,
  defineConfig,
  defineRecipe,
} from "@chakra-ui/react";

const fontFamily = '"Atlas Inter", Inter, "Segoe UI", Arial, sans-serif';
const pressed = {
  transform: "translateY(var(--atlas-layout-button-press, 1px))",
} as const;
const focus = {
  focusRingColor: "focus.ring",
  focusRingWidth: "var(--atlas-layout-focus-width, 2px)",
  focusRingOffset: "var(--atlas-layout-focus-offset, 2px)",
  outlineWidth: "var(--atlas-layout-focus-width, 2px)",
  outlineStyle: "solid",
  outlineColor: "focus.ring",
  outlineOffset: "var(--atlas-layout-focus-offset, 2px)",
} as const;
const mobileTargetHeight = {
  base: "var(--atlas-layout-mobile-target, 44px)",
  lg: "var(--atlas-layout-zero, 0)",
} as const;
const disabledControl = {
  bg: "bg.disabled",
  color: "fg.disabled",
  borderColor: "border.disabled",
  opacity: "var(--atlas-layout-disabled-opacity, 1)",
  cursor: "disabled",
} as const;
const disabledButton = {
  ...disabledControl,
  _hover: disabledControl,
  _active: { ...disabledControl, transform: "none" },
} as const;
const control = {
  minH: mobileTargetHeight,
  borderRadius: "control",
  bg: "bg.workbench",
  borderColor: "border.strong",
  color: "fg.default",
  focusRingColor: "focus.ring",
  focusVisibleRing: "outside",
  _placeholder: { color: "fg.placeholder" },
  _hover: { borderColor: "border.interactive" },
  _focusVisible: focus,
  _invalid: { borderColor: "status.danger" },
  _disabled: disabledControl,
} as const;
const checkboxControl = {
  focusVisibleRing: "outside",
  bg: "bg.workbench",
  borderColor: "border.strong",
  _focusVisible: focus,
  _disabled: disabledControl,
  "&:is([data-state=checked], [data-state=indeterminate])": {
    bg: "action.primary.default",
    color: "fg.inverse",
    borderColor: "action.primary.default",
    _disabled: disabledControl,
  },
} as const;

const button = defineRecipe({
  base: {
    minH: mobileTargetHeight,
    borderRadius: "control",
    textStyle: "body",
    fontWeight: "semibold",
    _focusVisible: focus,
    _disabled: disabledButton,
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
        _active: { bg: "action.primary.pressed", ...pressed },
        _disabled: disabledButton,
      },
      secondary: {
        bg: "bg.toolbar",
        color: "fg.primary",
        borderWidth: "var(--atlas-layout-edge, 1px)",
        borderColor: "border.strong",
        _hover: { bg: "bg.selected", borderColor: "border.interactive" },
        _active: { bg: "bg.selected", ...pressed },
      },
      tertiary: {
        bg: "transparent",
        color: "fg.default",
        borderWidth: "var(--atlas-layout-edge, 1px)",
        borderColor: "border.subtle",
        _hover: { bg: "bg.selected", color: "fg.primary" },
        _active: { bg: "bg.selected", ...pressed },
      },
      tableAction: {
        bg: "transparent",
        color: "fg.primary",
        borderWidth: "var(--atlas-layout-edge, 1px)",
        borderColor: "border.subtle",
        _hover: { bg: "bg.selected", borderColor: "border.interactive" },
        _active: { bg: "bg.selected", ...pressed },
      },
      utility: {
        bg: "transparent",
        color: "fg.muted",
        _hover: { bg: "bg.selected", color: "fg.primary" },
      },
      destructive: {
        bg: "action.danger.default",
        color: "fg.inverse",
        _hover: { bg: "action.danger.hover" },
        _active: { bg: "action.danger.pressed", ...pressed },
        _disabled: disabledButton,
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
        fontSizes: { module: { value: "15px" } },
        fontWeights: { emphasis: { value: "600" } },
        // Wada-inspired sRGB anchors with accessible tints and shades; no runtime generation.
        colors: {
          white: { value: "#FFFFFF" },
          neutral: {
            25: { value: "#FDFCF9" },
            50: { value: "#FAF7F0" },
            100: { value: "#F1EBDC" },
            200: { value: "#E2D9C5" },
            300: { value: "#CCC1A9" },
            400: { value: "#8A8477" },
            500: { value: "#686459" },
            600: { value: "#504D44" },
            700: { value: "#3B3932" },
            800: { value: "#282923" },
            900: { value: "#1C211D" },
            950: { value: "#111713" },
          },
          brand: {
            50: { value: "#F1F7F3" },
            100: { value: "#E0ECE3" },
            200: { value: "#B4CDC2" },
            300: { value: "#92B3A5" },
            400: { value: "#689582" },
            500: { value: "#3F7A64" },
            600: { value: "#245B50" },
            700: { value: "#1C4B43" },
            800: { value: "#173D37" },
            900: { value: "#112F2C" },
            950: { value: "#091E1B" },
          },
          clay: {
            200: { value: "#F48067" },
            500: { value: "#9B4937" },
            700: { value: "#743226" },
          },
          success: {
            50: { value: "#F0F8EC" },
            200: { value: "#C3D9B8" },
            500: { value: "#668E4F" },
            600: { value: "#41632D" },
            700: { value: "#2E481E" },
          },
          warning: {
            50: { value: "#FCF5E3" },
            200: { value: "#E2B540" },
            500: { value: "#96731E" },
            600: { value: "#76570F" },
            700: { value: "#56400E" },
          },
          danger: {
            50: { value: "#FEF4F3" },
            200: { value: "#F1CECA" },
            500: { value: "#C45B56" },
            600: { value: "#A53332" },
            700: { value: "#7A2020" },
          },
          info: {
            50: { value: "#F2F7FD" },
            200: { value: "#C7DAEE" },
            500: { value: "#5B84AE" },
            600: { value: "#2D5B88" },
            700: { value: "#1D4266" },
          },
        },
        spacing: {
          xs: { value: "6px" },
          sm: { value: "10px" },
          md: { value: "16px" },
          lg: { value: "24px" },
          xl: { value: "32px" },
        },
        radii: { control: { value: "8px" }, workbench: { value: "6px" } },
        sizes: { control: { value: "40px" }, compact: { value: "36px" } },
        shadows: {
          notification: { value: "0 8px 24px rgba(28, 28, 28, 0.14)" },
        },
      },
      semanticTokens: {
        colors: {
          action: {
            primary: {
              default: { value: "{colors.brand.600}" },
              hover: { value: "{colors.brand.700}" },
              pressed: { value: "{colors.brand.800}" },
            },
            danger: {
              default: { value: "{colors.danger.600}" },
              hover: { value: "{colors.danger.700}" },
              pressed: { value: "{colors.danger.700}" },
            },
          },
          bg: {
            DEFAULT: { value: "{colors.white}" },
            workspace: { value: "{colors.neutral.100}" },
            workbench: { value: "{colors.white}" },
            toolbar: { value: "{colors.neutral.50}" },
            tableHeader: { value: "{colors.neutral.100}" },
            subtle: { value: "{colors.neutral.50}" },
            context: { value: "{colors.neutral.100}" },
            selected: { value: "{colors.brand.100}" },
            disabled: { value: "{colors.neutral.100}" },
            navigation: { value: "{colors.brand.900}" },
            navigationHover: { value: "{colors.brand.800}" },
            success: { value: "{colors.success.50}" },
            warning: { value: "{colors.warning.50}" },
            danger: { value: "{colors.danger.50}" },
            info: { value: "{colors.info.50}" },
          },
          fg: {
            DEFAULT: { value: "{colors.neutral.900}" },
            default: { value: "{colors.neutral.900}" },
            primary: { value: "{colors.neutral.900}" },
            secondary: { value: "{colors.neutral.700}" },
            muted: { value: "{colors.neutral.600}" },
            placeholder: { value: "{colors.neutral.500}" },
            disabled: { value: "{colors.neutral.600}" },
            brand: { value: "{colors.brand.600}" },
            navBrand: { value: "{colors.brand.200}" },
            attention: { value: "{colors.clay.500}" },
            inverse: { value: "{colors.white}" },
            navMuted: { value: "{colors.neutral.300}" },
          },
          border: {
            DEFAULT: { value: "{colors.neutral.400}" },
            default: { value: "{colors.neutral.400}" },
            subtle: { value: "{colors.neutral.300}" },
            strong: { value: "{colors.neutral.500}" },
            accent: { value: "{colors.brand.600}" },
            interactive: { value: "{colors.brand.600}" },
            disabled: { value: "{colors.neutral.300}" },
            success: { value: "{colors.success.500}" },
            warning: { value: "{colors.warning.500}" },
            danger: { value: "{colors.danger.500}" },
            info: { value: "{colors.info.500}" },
          },
          status: {
            success: { value: "{colors.success.700}" },
            warning: { value: "{colors.warning.700}" },
            danger: { value: "{colors.danger.700}" },
            info: { value: "{colors.info.700}" },
          },
          focus: {
            ring: { value: "{colors.brand.600}" },
            inverse: { value: "{colors.brand.200}" },
          },
        },
      },
      layerStyles: {
        feedbackDanger: {
          value: {
            bg: "bg.danger",
            color: "status.danger",
            borderInlineStartWidth: "var(--atlas-layout-rail, 3px)",
            borderColor: "border.danger",
          },
        },
        feedbackWarning: {
          value: {
            bg: "bg.warning",
            color: "status.warning",
            borderInlineStartWidth: "var(--atlas-layout-rail, 3px)",
            borderColor: "border.warning",
          },
        },
        feedbackInfo: {
          value: {
            bg: "bg.info",
            color: "status.info",
            borderInlineStartWidth: "var(--atlas-layout-rail, 3px)",
            borderColor: "border.info",
          },
        },
        feedbackSuccess: {
          value: {
            bg: "bg.success",
            color: "status.success",
            borderInlineStartWidth: "var(--atlas-layout-rail, 3px)",
            borderColor: "border.success",
          },
        },
      },
      textStyles: {
        brand: {
          value: {
            fontSize: "28px",
            fontWeight: "semibold",
            letterSpacing: "0.06em",
          },
        },
        brandCompact: {
          value: {
            fontSize: "20px",
            fontWeight: "semibold",
            letterSpacing: "0.06em",
          },
        },
        quantity: { value: { fontSize: "22px", fontWeight: "600" } },
        workbenchTitle: {
          value: {
            fontSize: { base: "24px", lg: "26px" },
            fontWeight: "semibold",
            lineHeight: "1.3",
            letterSpacing: "-0.025em",
          },
        },
        section: {
          value: {
            fontSize: "18px",
            fontWeight: "semibold",
            lineHeight: "1.4",
          },
        },
        body: {
          value: { fontSize: { base: "15px", lg: "14px" }, lineHeight: "1.5" },
        },
        table: {
          value: { fontSize: { base: "15px", lg: "14px" }, lineHeight: "1.5" },
        },
        input: {
          value: { fontSize: { base: "16px", lg: "14px" }, lineHeight: "1.5" },
        },
        label: {
          value: {
            fontSize: "14px",
            fontWeight: "medium",
            lineHeight: "1.5",
          },
        },
        helper: { value: { fontSize: "13px", lineHeight: "1.6" } },
        quantityInline: {
          value: {
            fontSize: { base: "15px", lg: "14px" },
            fontWeight: "semibold",
            lineHeight: "1.5",
            fontVariantNumeric: "tabular-nums",
          },
        },
        unitInline: {
          value: {
            fontSize: "13px",
            fontWeight: "normal",
            lineHeight: "1.5",
          },
        },
      },
      keyframes: {
        atlasDetailEnter: {
          from: { opacity: 0, transform: "translateY(6px)" },
          to: { opacity: 1, transform: "translateY(0)" },
        },
        atlasRefreshSpin: { to: { transform: "rotate(360deg)" } },
        atlasRefreshComplete: {
          "0%, 100%": { transform: "translateY(0)" },
          "45%": { transform: "translateY(-2px)" },
        },
      },
      animationStyles: {
        detailEnter: {
          value: {
            animation: "atlasDetailEnter 160ms ease-out",
            _motionReduce: { animation: "none" },
          },
        },
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
            size: { md: { h: "control", px: "sm", textStyle: "input" } },
          },
          defaultVariants: { size: "md" },
        },
        textarea: {
          base: { ...control, minH: "var(--atlas-layout-textarea-min, 60px)" },
          variants: {
            variant: {
              outline: {
                ...control,
                minH: "var(--atlas-layout-textarea-min, 60px)",
              },
            },
            size: { md: { px: "sm", py: "xs", textStyle: "input" } },
          },
          defaultVariants: { size: "md", variant: "outline" },
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
        checkbox: {
          slots: ["root", "label", "control", "indicator", "group"],
          base: {
            root: { minH: mobileTargetHeight },
            label: {
              textStyle: "label",
              color: "fg.default",
              _disabled: {
                color: "fg.disabled",
                opacity: "var(--atlas-layout-disabled-opacity, 1)",
              },
            },
            control: checkboxControl,
          },
          variants: {
            variant: {
              solid: { control: checkboxControl },
              outline: { control: checkboxControl },
            },
          },
          defaultVariants: { variant: "solid" },
        },
        datePicker: {
          slots: [
            "root",
            "control",
            "indicatorGroup",
            "trigger",
            "content",
            "view",
            "viewTrigger",
            "prevTrigger",
            "nextTrigger",
            "table",
            "tableCell",
            "tableHeader",
            "tableCellTrigger",
          ],
          base: {
            root: {
              minW: "var(--atlas-layout-zero, 0)",
              _disabled: { opacity: "var(--atlas-layout-disabled-opacity, 1)" },
            },
            indicatorGroup: {
              insetEnd: "var(--atlas-layout-calendar-trigger-offset, 2px)",
            },
            trigger: {
              ...control,
              bg: "bg.subtle",
              w: {
                base: "var(--atlas-layout-mobile-target, 44px)",
                lg: "compact",
              },
              h: "compact",
              borderWidth: "var(--atlas-layout-edge, 1px)",
              _hover: { bg: "bg.selected", color: "fg.primary" },
              _active: { bg: "bg.selected", ...pressed },
            },
            content: {
              bg: "bg.workbench",
              color: "fg.default",
              borderRadius: "control",
              borderWidth: "var(--atlas-layout-edge, 1px)",
              borderColor: "border.default",
              boxShadow: "var(--atlas-layout-shadow, none)",
              minW: "var(--atlas-layout-zero, 0)",
              w: "var(--atlas-layout-calendar-width, 292px)",
              maxW: "var(--atlas-layout-calendar-max-width, calc(100vw - 20px))",
              p: "sm",
              _open: { animationName: "var(--atlas-layout-motion, none)" },
              _closed: { animationName: "var(--atlas-layout-motion, none)" },
              _motionReduce: { animation: "var(--atlas-layout-motion, none)" },
            },
            viewTrigger: {
              ...control,
              borderWidth: "var(--atlas-layout-zero, 0)",
              h: "compact",
              _hover: { bg: "bg.selected" },
            },
            prevTrigger: {
              ...control,
              w: "compact",
              h: "compact",
              _hover: { bg: "bg.selected" },
              _focusVisible: {
                ...focus,
                boxShadow: "var(--atlas-layout-shadow, none)",
              },
            },
            nextTrigger: {
              ...control,
              w: "compact",
              h: "compact",
              _hover: { bg: "bg.selected" },
              _focusVisible: {
                ...focus,
                boxShadow: "var(--atlas-layout-shadow, none)",
              },
            },
            table: {
              minW: "var(--atlas-layout-zero, 0)",
              w: "full",
              tableLayout: "fixed",
            },
            tableCell: {
              px: "var(--atlas-layout-zero, 0)",
              borderWidth: "var(--atlas-layout-zero, 0)",
              bg: "bg.workbench",
            },
            tableHeader: {
              px: "var(--atlas-layout-zero, 0)",
              position: "static",
              borderWidth: "var(--atlas-layout-zero, 0)",
              bg: "bg.workbench",
              textStyle: "helper",
              color: "fg.muted",
              textTransform: "none",
            },
            tableCellTrigger: {
              borderRadius: "control",
              textStyle: "body",
              color: "fg.default",
              cursor: "var(--atlas-layout-cursor, pointer)",
              _hover: { bg: "bg.selected" },
              _active: { bg: "bg.selected", ...pressed },
              _focusVisible: focus,
              _today: {
                color: "fg.primary",
                fontWeight: "semibold",
                textDecoration: "underline",
              },
              "&[data-selected]": {
                bg: "action.primary.default",
                color: "fg.inverse",
                _hover: { bg: "action.primary.hover" },
              },
              "&[data-in-range]": {
                bg: "bg.selected",
                color: "fg.default",
                _hover: { bg: "bg.selected" },
              },
              "&[data-in-range][data-selected]": {
                bg: "action.primary.default",
                color: "fg.inverse",
                _hover: { bg: "action.primary.hover" },
              },
              _disabled: disabledControl,
            },
          },
          variants: {
            size: {
              md: {
                view: {
                  "--table-cell-size": "sizes.compact",
                  "--datepicker-nav-trigger-size": "sizes.compact",
                },
              },
            },
          },
        },
        dateInput: {
          slots: ["root", "label", "control", "segmentGroup", "segment"],
          base: {
            root: {
              gap: "xs",
              width: "full",
              _disabled: { opacity: "var(--atlas-layout-disabled-opacity, 1)" },
            },
            label: { textStyle: "label", color: "fg.default" },
            segmentGroup: {
              ...control,
              h: "control",
              minH: mobileTargetHeight,
              px: "sm",
              textStyle: "input",
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
                field: { h: "control", ps: "sm", pe: "xl", textStyle: "input" },
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
            label: {
              textStyle: "label",
              color: "fg.secondary",
              _disabled: {
                color: "fg.disabled",
                opacity: "var(--atlas-layout-disabled-opacity, 1)",
              },
            },
            helperText: { textStyle: "helper", color: "fg.muted" },
            errorText: { textStyle: "helper", color: "status.danger" },
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
            root: {
              textStyle: "table",
              bg: "bg.workbench",
              fontVariantNumeric: "tabular-nums",
            },
            columnHeader: {
              position: "relative",
              textStyle: "table",
              letterSpacing: "var(--atlas-layout-tracking, normal)",
              minH: "var(--atlas-table-header-height, 38px)",
              bg: "bg.tableHeader",
              borderBottomColor: "border.subtle",
              color: "fg.default",
              fontWeight: "emphasis",
              textTransform: "none",
              _after: {
                content: '\"\"',
                position: "absolute",
                insetBlock: "var(--atlas-layout-zero, 0)",
                insetInlineEnd: "var(--atlas-layout-zero, 0)",
                w: "var(--atlas-layout-edge, 1px)",
                bg: "border.subtle",
                pointerEvents: "none",
              },
              "&:last-child::after": { display: "none" },
              "&[data-sticky-column]::after": { bg: "border.default" },
            },
            cell: {
              position: "relative",
              borderColor: "border.subtle",
              _after: {
                content: '\"\"',
                position: "absolute",
                insetBlock: "var(--atlas-layout-zero, 0)",
                insetInlineEnd: "var(--atlas-layout-zero, 0)",
                w: "var(--atlas-layout-edge, 1px)",
                bg: "border.subtle",
                pointerEvents: "none",
              },
              "&:last-child::after": { display: "none" },
              "&[data-sticky-column]::after": { bg: "border.default" },
              "& [data-selection-indicator]": {
                position: "absolute",
                insetY: "xs",
                left: "var(--atlas-layout-zero, 0)",
                width: "var(--atlas-layout-rail, 3px)",
                bg: "border.accent",
              },
            },
            row: {
              borderBottomWidth: "var(--atlas-layout-edge, 1px)",
              borderBottomColor: "border.subtle",
              transition:
                "var(--atlas-layout-row-transition, background-color 140ms ease-out)",
              _hover: {
                bg: "bg.subtle",
                "& [data-sticky-column]": { bg: "bg.subtle" },
              },
              _selected: {
                bg: "bg.selected",
                "& [data-sticky-column]": { bg: "bg.selected" },
                _hover: {
                  bg: "bg.selected",
                  "& [data-sticky-column]": { bg: "bg.selected" },
                },
              },
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
                columnHeader: {
                  px: "var(--atlas-table-cell-x, 12px)",
                  py: "sm",
                },
                cell: { px: "var(--atlas-table-cell-x, 12px)", py: "xs" },
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
