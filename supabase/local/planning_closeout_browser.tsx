// Loaded only by the loopback disposable test harness; never a production entrypoint.
import React from "react";
import { createRoot } from "react-dom/client";
import { AtlasVNextProvider } from "../../src/vnext/atlas/AtlasVNextProvider";
import { ConfirmedNeedWorkbench } from "../../src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench";
if (location.hostname !== "127.0.0.1") throw new Error("LOCAL_FIXTURE_ONLY");
async function rpc(method: string, request?: unknown) {
  const response = await fetch("/__closeout-rpc", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ method, request }),
  });
  if (!response.ok) throw new Error("LOCAL_RPC_FAILED");
  const result = await response.json();
  return result.success
    ? { kind: "success" as const, response: result }
    : { kind: "backend_error" as const, error: result };
}
const prohibited = async () => {
  throw new Error("UNEXPECTED_GENERATION_OR_DOWNSTREAM_ACTION");
};
createRoot(document.getElementById("root")!).render(
  <AtlasVNextProvider>
    <ConfirmedNeedWorkbench
      authSubject="a7400000-0000-4000-8000-000000000101"
      initialServiceDate="2050-09-19"
      preflightApi={{ preflight: () => rpc("preflight") }}
      confirmedNeedApi={{
        getReview: () => rpc("review"),
        save: (request) => rpc("save", request),
      }}
      needGenerationApi={{ execute: prohibited, getWorkbench: prohibited }}
    />
  </AtlasVNextProvider>,
);
