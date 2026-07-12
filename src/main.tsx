import React from "react";
import ReactDOM from "react-dom/client";
import { PlannerWorkspacePage } from "./modules/planner/PlannerWorkspacePage";
import "./styles.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <PlannerWorkspacePage />
  </React.StrictMode>,
);
