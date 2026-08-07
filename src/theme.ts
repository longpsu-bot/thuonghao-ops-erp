import { Button, createTheme, Paper } from "@mantine/core";

if (
  import.meta.env.MODE === "test" &&
  typeof window !== "undefined" &&
  typeof window.matchMedia !== "function"
) {
  Object.defineProperty(window, "matchMedia", {
    configurable: true,
    writable: true,
    value: (query: string): MediaQueryList =>
      ({
        matches: false,
        media: query,
        onchange: null,
        addListener: () => undefined,
        removeListener: () => undefined,
        addEventListener: () => undefined,
        removeEventListener: () => undefined,
        dispatchEvent: () => false,
      }) as MediaQueryList,
  });
}

export const atlasTheme = createTheme({
  primaryColor: "atlasGreen",
  primaryShade: 7,
  fontFamily: 'Inter, "Segoe UI", Arial, sans-serif',
  headings: {
    fontFamily: 'Inter, "Segoe UI", Arial, sans-serif',
    fontWeight: "700",
    sizes: {
      h1: { fontSize: "1.875rem", lineHeight: "1.2" },
      h2: { fontSize: "1.25rem", lineHeight: "1.3" },
      h3: { fontSize: "1rem", lineHeight: "1.35" },
    },
  },
  defaultRadius: "sm",
  spacing: {
    xs: "0.375rem",
    sm: "0.625rem",
    md: "1rem",
    lg: "1.5rem",
    xl: "2rem",
  },
  colors: {
    atlasGreen: [
      "#edf7f3",
      "#d9ebe4",
      "#b7d8cc",
      "#91c4b2",
      "#70b39c",
      "#59a78d",
      "#4b9f84",
      "#2f8068",
      "#216653",
      "#10352c",
    ],
    atlasGold: [
      "#fff8e7",
      "#f8edcf",
      "#ecd79d",
      "#dfbf68",
      "#d6aa42",
      "#cf9c29",
      "#c78f1c",
      "#a77413",
      "#865c12",
      "#6e4a10",
    ],
  },
  components: {
    Button: Button.extend({
      defaultProps: {
        radius: "sm",
        size: "compact-md",
      },
    }),
    Paper: Paper.extend({
      defaultProps: {
        radius: "md",
      },
    }),
  },
});
