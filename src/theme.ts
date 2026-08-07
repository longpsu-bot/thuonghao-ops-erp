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
  spacing: {
    xs: "0.375rem",
    sm: "0.625rem",
    md: "1rem",
    lg: "1.5rem",
    xl: "2rem",
  },
  colors: {
    atlasNavy: [
      "#f4f8fc",
      "#dbe8f4",
      "#bfd3e7",
      "#91b0d0",
      "#6793bd",
      "#4379a8",
      "#2f6092",
      "#253246",
      "#1d2a3e",
      "#152030",
    ],
    atlasCopper: [
      "#fdf8f3",
      "#f4e5d2",
      "#edcea2",
      "#e5b56f",
      "#db9c49",
      "#cf8740",
      "#b66a3c",
      "#a35b35",
      "#8d4d2f",
      "#744026",
    ],
    atlasAmber: [
      "#fff7e1",
      "#ffeeb6",
      "#ffd98d",
      "#ffc04e",
      "#e6a83b",
      "#ce9632",
      "#b9832a",
      "#a06f21",
      "#8e601c",
      "#724915",
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
