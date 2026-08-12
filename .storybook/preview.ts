import React from "react";
import type { Preview } from "@storybook/react-vite";
import { MantineProvider } from "@mantine/core";
import { DatePickerInput, DatesProvider } from "@mantine/dates";
import "@mantine/core/styles.css";
import "@mantine/dates/styles.css";
import "dayjs/locale/vi";
import "../src/styles.css";
import "../src/recipe-ui-cleanup.css";
import { atlasTheme } from "../src/theme";
import {
  AtlasDatePickerInputContext,
  type AtlasDatePickerInputProps,
} from "../src/modules/atlas/planning-inputs/PlanningInputsWorkbench";

const preview: Preview = {
  decorators: [
    (Story) =>
      React.createElement(
        MantineProvider,
        { theme: atlasTheme, defaultColorScheme: "light" },
        React.createElement(
          DatesProvider,
          { settings: { locale: "vi", firstDayOfWeek: 1 } },
          React.createElement(
            AtlasDatePickerInputContext.Provider,
            {
              value:
                DatePickerInput as React.ComponentType<AtlasDatePickerInputProps>,
            },
            React.createElement(Story),
          ),
        ),
      ),
  ],
  parameters: {
    layout: "fullscreen",
    controls: { disable: true },
  },
};

export default preview;
