import { describe, expect, it } from "vitest";
import environmentSource from "./environment.ts?raw";
import clientSource from "./supabaseClient.ts?raw";
import authSource from "./authSession.ts?raw";
import rpcSource from "./atlasRpc.ts?raw";
import panelSource from "./AtlasConnectionPanel.tsx?raw";
import evidenceApiSource from "../evidence/supplierEvidenceApi.ts?raw";
import evidenceWorkbenchSource from "../evidence/SupplierEvidenceReadinessWorkbench.tsx?raw";

describe("PA-06B browser-source security boundary", () => {
  const browserSource = [
    environmentSource,
    clientSource,
    authSource,
    rpcSource,
    panelSource,
    evidenceApiSource,
    evidenceWorkbenchSource,
  ].join("\n");

  it("contains no browser service-role variable or hosted project reference", () => {
    expect(browserSource).not.toMatch(/VITE_SUPABASE_SERVICE_ROLE_KEY/);
    expect(browserSource).not.toMatch(/qnthofvccilhnefdcxnz/);
  });

  it("contains no direct private or legacy table operation", () => {
    expect(browserSource).not.toMatch(
      /\.from\s*\(|atlas_(core|admin|planning|procurement|evidence|dispatch|audit|reporting)|ops_v2|public\./,
    );
  });

  it("keeps RPC calls behind the atlas_api schema and reviewed registry", () => {
    expect(browserSource).toContain('.schema("atlas_api")');
    expect(browserSource).toContain("ATLAS_RPC_FUNCTIONS[functionName]");
    expect(browserSource).not.toMatch(/rpc\s*\(\s*functionName/);
  });

  it("limits the PA-06C adapter to its exact five-function subset", () => {
    expect(evidenceApiSource.match(/atlas_api\.[a-z_]+/g)).toEqual([
      "atlas_api.record_supplier_receiving_evidence",
      "atlas_api.apply_supplier_evidence_to_allocation",
      "atlas_api.get_dispatch_evidence_readiness",
      "atlas_api.get_operator_blockers",
      "atlas_api.get_command_audit_timeline",
    ]);
    expect(evidenceWorkbenchSource).not.toMatch(/\.from\s*\(|\.rpc\s*\(/);
  });

  it("disables built-in PostgREST retries without a retry wrapper", () => {
    expect(clientSource).toContain("db: { retry: false }");
    expect(clientSource).not.toMatch(/\bas\s+(?:never|any)\b/);
    expect(rpcSource).toContain(".retry(false)");
    expect(browserSource).not.toMatch(
      /retryWith|withRetry|fetchRetry|retryFetch|global\s*:\s*\{[^}]*fetch/,
    );
  });
});
