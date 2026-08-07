import React from "react";
import type { Preview } from "@storybook/react-vite";
import { MantineProvider } from "@mantine/core";
import "@mantine/core/styles.css";
import "../src/styles.css";
import { atlasTheme } from "../src/theme";

const preview: Preview = {
  decorators: [
    (Story) =>
      React.createElement(
        MantineProvider,
        { theme: atlasTheme, defaultColorScheme: "light" },
        React.createElement(Story),
      ),
  ],
  parameters: {
    layout: "fullscreen",
    controls: { disable: true },
  },
};

export default preview;
