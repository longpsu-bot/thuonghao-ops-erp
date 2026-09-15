export const atlasPrimaryTabList = {
  "data-tab-tier": "primary",
  "data-tab-align": "start",
  justifyContent: "flex-start",
  gap: "xs",
  w: "var(--atlas-layout-fit-content, fit-content)",
  maxW: "full",
  p: "xs",
  bg: "bg.toolbar",
  borderWidth: "var(--atlas-layout-edge, 1px)",
  borderColor: "border.subtle",
  borderRadius: "control",
  overflowX: "auto",
} as const;

export const atlasPrimaryTabTrigger = {
  flexShrink: 0,
  px: "md",
  py: "sm",
  color: "fg.muted",
  fontWeight: "semibold",
  borderRadius: "control",
  borderWidth: "var(--atlas-layout-edge, 1px)",
  borderColor: "transparent",
  _selected: {
    color: "fg.primary",
    bg: "bg.selected",
    borderColor: "border.accent",
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
  px: "sm",
  py: "xs",
  color: "fg.muted",
  fontWeight: "medium",
  borderRadius: "control",
  _selected: { color: "fg.primary", bg: "bg.selected", fontWeight: "semibold" },
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
