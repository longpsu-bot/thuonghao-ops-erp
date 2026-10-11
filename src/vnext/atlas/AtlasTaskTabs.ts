export const atlasPrimaryTabList = {
  "data-tab-tier": "primary",
  "data-tab-align": "start",
  justifyContent: "flex-start",
  gap: "xs",
  w: "var(--atlas-layout-fit-content, fit-content)",
  maxW: "full",
  bg: "transparent",
  borderBottomWidth: "var(--atlas-layout-edge, 1px)",
  borderColor: "border.subtle",
  borderRadius: "var(--atlas-layout-zero, 0)",
  overflowX: "auto",
} as const;

export const atlasPrimaryTabTrigger = {
  flexShrink: 0,
  minH: {
    base: "var(--atlas-layout-mobile-target, 44px)",
    lg: "var(--atlas-layout-zero, 0)",
  },
  px: "md",
  py: "sm",
  color: "fg.muted",
  fontWeight: "semibold",
  borderRadius: "var(--atlas-layout-zero, 0)",
  borderWidth: "var(--atlas-layout-edge, 1px)",
  borderColor: "transparent",
  position: "relative",
  _hover: { bg: "bg.subtle", color: "fg.primary" },
  _after: {
    content: '""',
    position: "absolute",
    left: "sm",
    right: "sm",
    bottom: "var(--atlas-layout-zero, 0)",
    height: "var(--atlas-layout-tab-marker, 3px)",
    bg: "border.accent",
    opacity: "var(--atlas-layout-tab-marker-hidden, 0)",
  },
  _selected: {
    color: "fg.primary",
    bg: "bg.workbench",
    borderColor: "transparent",
    _after: { opacity: "var(--atlas-layout-tab-marker-visible, 1)" },
  },
  _before: { display: "none" },
} as const;

export const atlasSecondaryTabList = {
  "data-tab-tier": "secondary",
  "data-tab-align": "start",
  justifyContent: "flex-start",
  gap: "xs",
  w: "full",
  px: "md",
  pt: "md",
  pb: "sm",
  borderBottomWidth: "var(--atlas-layout-edge, 1px)",
  borderColor: "border.subtle",
  overflowX: "auto",
} as const;

export const atlasSecondaryTabTrigger = {
  flexShrink: 0,
  minH: {
    base: "var(--atlas-layout-mobile-target, 44px)",
    lg: "var(--atlas-layout-zero, 0)",
  },
  px: "sm",
  py: "xs",
  color: "fg.muted",
  fontWeight: "semibold",
  borderRadius: "var(--atlas-layout-zero, 0)",
  _selected: {
    color: "fg.primary",
    bg: "transparent",
    fontWeight: "semibold",
  },
  _before: { bg: "border.accent" },
} as const;

export const atlasVisuallyHidden = {
  position: "absolute",
  w: "var(--atlas-layout-visually-hidden-size, 1px)",
  h: "var(--atlas-layout-visually-hidden-size, 1px)",
  p: "var(--atlas-layout-zero, 0)",
  m: "var(--atlas-layout-visually-hidden-margin, -1px)",
  overflow: "hidden",
  clip: "rect(0, 0, 0, 0)",
  whiteSpace: "nowrap",
  borderWidth: "var(--atlas-layout-zero, 0)",
} as const;
