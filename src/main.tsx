import React from "react";
import ReactDOM from "react-dom/client";
import { AtlasApp } from "./modules/atlas/AtlasApp";
import "./styles.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <AtlasApp />
  </React.StrictMode>,
);
