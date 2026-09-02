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
        addEventListener: () => undefined,
        removeEventListener: () => undefined,
        dispatchEvent: () => false,
      }) as unknown as MediaQueryList,
  });
}

export const atlasTheme = createTheme({
  primaryColor: "atlasNavy",
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
  radius: {
    xs: "0.25rem",
    sm: "0.375rem",
    md: "0.5625rem",
    lg: "0.625rem",
    xl: "0.75rem",
  },
  spacing: {
    xs: "0.375rem",
    sm: "0.625rem",
    md: "1rem",
    lg: "1.5rem",
    xl: "2rem",
  },
  colors: {
    atlasNavy: [
      "#f2f4f7",
      "#e4e8ed",
      "#c6ced8",
      "#a4b0bf",
      "#7d8ca0",
      "#5c6d83",
      "#303e51",
      "#253246",
      "#1c2735",
      "#121b27",
    ],
    atlasCopper: [
      "#fff4ed",
      "#f8e4d8",
      "#ecc6ae",
      "#dda27f",
      "#cc8158",
      "#b66a3c",
      "#ad6138",
      "#a35b35",
      "#85482c",
      "#693821",
    ],
    atlasAmber: [
      "#fff8e8",
      "#f9edcf",
      "#f0d99e",
      "#e6c36a",
      "#dcb04b",
      "#d5a13d",
      "#bd8627",
      "#966819",
      "#76500f",
      "#5f3f0b",
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
