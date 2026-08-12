import React from "react";
import ReactDOM from "react-dom/client";
import { MantineProvider } from "@mantine/core";
import { DatePickerInput, DatesProvider } from "@mantine/dates";
import "@mantine/core/styles.css";
import "@mantine/dates/styles.css";
import "dayjs/locale/vi";
import { AtlasAppView as AtlasApp } from "./modules/atlas/AtlasApp";
import {
  AtlasDatePickerInputContext,
  type AtlasDatePickerInputProps,
} from "./modules/atlas/planning-inputs/PlanningInputsWorkbench";
import { atlasTheme } from "./theme";
import "./styles.css";
import "./recipe-ui-cleanup.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <MantineProvider theme={atlasTheme} defaultColorScheme="light">
      <DatesProvider settings={{ locale: "vi", firstDayOfWeek: 1 }}>
        <AtlasDatePickerInputContext.Provider
          value={
            DatePickerInput as React.ComponentType<AtlasDatePickerInputProps>
          }
        >
          <AtlasApp />
        </AtlasDatePickerInputContext.Provider>
      </DatesProvider>
    </MantineProvider>
  </React.StrictMode>,
);
