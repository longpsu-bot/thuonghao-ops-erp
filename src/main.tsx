import React from "react";
import ReactDOM from "react-dom/client";
import { MantineProvider } from "@mantine/core";
import "@mantine/core/styles.css";
import { AtlasAppView as AtlasApp } from "./modules/atlas/AtlasApp";
import { atlasTheme } from "./theme";
import "./styles.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <MantineProvider theme={atlasTheme} defaultColorScheme="light">
      <AtlasApp />
    </MantineProvider>
  </React.StrictMode>,
);
