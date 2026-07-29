import type { Session, SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import {
  ATLAS_EDGE_FUNCTIONS,
  ATLAS_RPC_FUNCTIONS,
  createAtlasRpcTransport,
  type AtlasRpcName,
} from "./atlasRpc";

const authSubject = "10000000-0000-0000-0000-000000000101";

function session(expiresAt = Math.floor(Date.now() / 1000) + 3600): Session {
  return {
    access_token: "local-access-token",
    refresh_token: "local-refresh-token",
    expires_in: 3600,
    expires_at: expiresAt,
    token_type: "bearer",
    user: {
      id: authSubject,
      aud: "authenticated",
      role: "authenticated",
      email: "atlas.operator@local.test",
      created_at: "2026-07-17T00:00:00.000Z",
      app_metadata: {},
      user_metadata: {},
    },
  };
}

function rpcClient(
  response: { data: unknown; error: unknown },
  currentSession: Session | null = session(),
) {
  const retry = vi.fn().mockResolvedValue(response);
  const rpc = vi.fn(() => ({ retry }));
  const schema = vi.fn(() => ({ rpc }));
  const getSession = vi.fn().mockResolvedValue({
    data: { session: currentSession },
    error: null,
  });
  return {
    client: { auth: { getSession }, schema } as unknown as SupabaseClient,
    getSession,
    schema,
    rpc,
    retry,
  };
}

function edgeClient(
  response: { data: unknown; error: unknown },
  currentSession: Session | null = session(),
) {
  const invoke = vi.fn().mockResolvedValue(response);
  const getSession = vi.fn().mockResolvedValue({
    data: { session: currentSession },
    error: null,
  });
  return {
    client: {
      auth: { getSession },
      functions: { invoke },
    } as unknown as SupabaseClient,
    getSession,
    invoke,
  };
}

describe("Atlas RPC transport", () => {
  it("contains exactly the reviewed 63-function browser registry", () => {
    expect(Object.keys(ATLAS_RPC_FUNCTIONS)).toHaveLength(63);
    expect(Object.keys(ATLAS_RPC_FUNCTIONS)).toEqual([
      "atlas_api.record_wholesale_source",
      "atlas_api.release_wholesale_order",
      "atlas_api.release_purchase_handoff",
      "atlas_api.release_dispatch_requirement",
      "atlas_api.allocate_supplier_direct_fulfilment",
      "atlas_api.release_supplier_purchase_order",
      "atlas_api.record_supplier_receiving_evidence",
      "atlas_api.apply_supplier_evidence_to_allocation",
      "atlas_api.create_dispatch_plan",
      "atlas_api.create_or_assign_dispatch_trip",
      "atlas_api.confirm_dispatch_load",
      "atlas_api.record_dispatch_departure",
      "atlas_api.confirm_successful_delivery",
      "atlas_api.close_successful_trip",
      "atlas_api.get_supplier_direct_trace",
      "atlas_api.get_dispatch_evidence_readiness",
      "atlas_api.get_operator_blockers",
      "atlas_api.get_command_audit_timeline",
      "atlas_api.get_school_master_data",
      "atlas_api.get_ingredient_supplier_master_data",
      "atlas_api.update_school_portion_defaults",
      "atlas_api.create_ingredient",
      "atlas_api.update_ingredient",
      "atlas_api.set_ingredient_lifecycle",
      "atlas_api.create_supplier",
      "atlas_api.update_supplier",
      "atlas_api.replace_ingredient_supplier_priorities",
      "atlas_api.get_dish_recipe_workbench",
      "atlas_api.create_dish",
      "atlas_api.update_dish",
      "atlas_api.set_dish_lifecycle",
      "atlas_api.set_recipe_lifecycle",
      "atlas_api.create_recipe_draft",
      "atlas_api.create_recipe_successor_version",
      "atlas_api.replace_recipe_draft_composition",
      "atlas_api.validate_recipe_version",
      "atlas_api.release_recipe_version_for_planning",
      "atlas_api.copy_recipe_version",
      "atlas_api.apply_recipe_import",
      "atlas_api.get_recipe_adjustment_workbench",
      "atlas_api.resolve_effective_recipe_composition",
      "atlas_api.preview_recipe_composition_adjustment",
      "atlas_api.create_recipe_composition_adjustment",
      "atlas_api.supersede_recipe_composition_adjustment",
      "atlas_api.cancel_recipe_composition_adjustment",
      "atlas_api.get_planning_inputs_workbench",
      "atlas_api.preview_weekly_menu_import",
      "atlas_api.preview_attendance_import",
      "atlas_api.save_weekly_menu_draft",
      "atlas_api.validate_weekly_menu",
      "atlas_api.approve_weekly_menu",
      "atlas_api.reopen_weekly_menu",
      "atlas_api.create_attendance_draft_from_defaults",
      "atlas_api.save_attendance_draft",
      "atlas_api.validate_attendance",
      "atlas_api.approve_attendance",
      "atlas_api.reopen_attendance",
      "atlas_api.get_pantry_source_workbench",
      "atlas_api.preview_pantry_source",
      "atlas_api.save_pantry_draft",
      "atlas_api.validate_pantry",
      "atlas_api.approve_pantry",
      "atlas_api.reopen_pantry",
    ]);
  });

  it("contains exactly one reviewed read-only Edge Function route", () => {
    expect(ATLAS_EDGE_FUNCTIONS).toEqual({
      weeklyMenuGoogleSync: "atlas-weekly-menu-google-sync",
    });
  });

  it("rejects an arbitrary RPC name before client invocation", async () => {
    const fake = rpcClient({ data: null, error: null });
    const result = await createAtlasRpcTransport(fake.client).invoke(
      "atlas_api.arbitrary" as AtlasRpcName,
      {},
    );
    expect(result.kind).toBe("client_error");
    expect(fake.getSession).not.toHaveBeenCalled();
    expect(fake.rpc).not.toHaveBeenCalled();
  });

  it("rejects an unreviewed Pantry RPC before client invocation", async () => {
    const fake = rpcClient({ data: null, error: null });
    const result = await createAtlasRpcTransport(fake.client).invoke(
      "atlas_api.delete_pantry_draft" as AtlasRpcName,
      {},
    );
    expect(result.kind).toBe("client_error");
    expect(fake.getSession).not.toHaveBeenCalled();
    expect(fake.rpc).not.toHaveBeenCalled();
  });

  it("uses the exposed schema separately and forces the session subject", async () => {
    const fake = rpcClient({ data: { success: true }, error: null });
    await createAtlasRpcTransport(fake.client).invoke(
      "atlas_api.get_operator_blockers",
      { requested_by_auth_subject: "caller-override" },
    );
    expect(fake.schema).toHaveBeenCalledWith("atlas_api");
    expect(fake.rpc).toHaveBeenCalledWith("get_operator_blockers", {
      request: { requested_by_auth_subject: authSubject },
    });
    expect(fake.retry).toHaveBeenCalledWith(false);
  });

  it("preserves a structured successful response", async () => {
    const response = {
      success: true,
      command_id: "command-1",
      correlation_id: "correlation-1",
      idempotency_status: "COMPLETED",
      affected_aggregate_ids: { dispatch_trip_id: "trip-1" },
      new_versions: { dispatch_trip_version: 2 },
      emitted_event_ids: ["event-1"],
      audit_event_ids: ["audit-1"],
      safe_operator_message: "Completed safely.",
      warnings: [],
      blockers: [],
    };
    const fake = rpcClient({ data: response, error: null });
    await expect(
      createAtlasRpcTransport(fake.client).invoke(
        "atlas_api.close_successful_trip",
        {},
      ),
    ).resolves.toEqual({ kind: "success", response });
  });

  it.each([
    "STALE_VERSION",
    "IDEMPOTENCY_CONFLICT",
    "CAPABILITY_DENIED",
    "SCOPE_DENIED",
    "RETRYABLE_CONCURRENCY_FAILURE",
  ])("preserves the identifiable backend error %s", async (errorCode) => {
    const fake = rpcClient({
      data: {
        success: false,
        error_code: errorCode,
        safe_message: "Safe backend message.",
        retryable: errorCode === "RETRYABLE_CONCURRENCY_FAILURE",
        expected_version: 1,
        actual_version: 2,
        correlation_id: "correlation-1",
        command_name: "release_wholesale_order",
      },
      error: null,
    });
    const result = await createAtlasRpcTransport(fake.client).invoke(
      "atlas_api.release_wholesale_order",
      {},
    );
    expect(result.kind).toBe("backend_error");
    if (result.kind === "backend_error") {
      expect(result.error.error_code).toBe(errorCode);
      expect(result.error.safe_message).toBe("Safe backend message.");
      expect(result.error.expected_version).toBe(1);
      expect(result.error.actual_version).toBe(2);
      expect(result.error.command_name).toBe("release_wholesale_order");
    }
  });

  it("preserves only reviewed PA-05C read error fields", async () => {
    const fake = rpcClient({
      data: {
        success: false,
        error_code: "NOT_FOUND",
        safe_message: "No operating context matched.",
        contract_version: "PA-05C.v1",
        domain: "REPORTING",
        read_name: "get_operator_blockers",
        raw_sql: "select private_value",
        token: "private-token",
        key: "private-key",
        stack: "private-stack",
      },
      error: null,
    });
    const result = await createAtlasRpcTransport(fake.client).invoke(
      "atlas_api.get_operator_blockers",
      {},
    );
    expect(result.kind).toBe("backend_error");
    if (result.kind === "backend_error") {
      expect(result.error).toMatchObject({
        contract_version: "PA-05C.v1",
        read_name: "get_operator_blockers",
      });
      expect(result.error).not.toHaveProperty("raw_sql");
      expect(result.error).not.toHaveProperty("token");
      expect(result.error).not.toHaveProperty("key");
      expect(result.error).not.toHaveProperty("stack");
      expect(JSON.stringify(result.error)).not.toMatch(
        /private_value|private-token|private-key|private-stack/,
      );
    }
  });

  it("maps a network failure separately and never retries a write", async () => {
    const fake = rpcClient({
      data: null,
      error: { message: "fetch failed: token=local-access-token" },
    });
    const result = await createAtlasRpcTransport(fake.client).invoke(
      "atlas_api.record_wholesale_source",
      { correlation_id: "correlation-1" },
    );
    expect(result.kind).toBe("transport_error");
    expect(fake.rpc).toHaveBeenCalledOnce();
    expect(fake.retry).toHaveBeenCalledOnce();
    expect(fake.retry).toHaveBeenCalledWith(false);
    expect(JSON.stringify(result)).not.toContain("local-access-token");
    if (result.kind === "transport_error") {
      expect(result.diagnostic.code).toBe("NETWORK_FAILURE");
      expect(result.diagnostic.correlationId).toBe("correlation-1");
    }
  });

  it("requires a current authenticated session", async () => {
    const fake = rpcClient({ data: null, error: null }, null);
    const result = await createAtlasRpcTransport(fake.client).invoke(
      "atlas_api.get_supplier_direct_trace",
      {},
    );
    expect(result.kind).toBe("auth_error");
    expect(fake.rpc).not.toHaveBeenCalled();
  });

  it("rejects an expired session before command submission", async () => {
    const fake = rpcClient(
      { data: null, error: null },
      session(Math.floor(Date.now() / 1000) - 1),
    );
    const result = await createAtlasRpcTransport(fake.client).invoke(
      "atlas_api.release_purchase_handoff",
      {},
    );
    expect(result.kind).toBe("auth_error");
    if (result.kind === "auth_error") {
      expect(result.diagnostic.code).toBe("SESSION_EXPIRED");
    }
    expect(fake.rpc).not.toHaveBeenCalled();
  });

  it("invokes the Google adapter with the current bearer token", async () => {
    const response = {
      success: true,
      correlation_id: "correlation-1",
      rows: [],
    };
    const fake = edgeClient({ data: response, error: null });
    const result = await createAtlasRpcTransport(
      fake.client,
    ).invokeEdgeFunction("atlas-weekly-menu-google-sync", {
      correlation_id: "correlation-1",
    });
    expect(result).toEqual({ kind: "success", response });
    expect(fake.invoke).toHaveBeenCalledWith("atlas-weekly-menu-google-sync", {
      body: { correlation_id: "correlation-1" },
      headers: { Authorization: "Bearer local-access-token" },
    });
  });

  it("preserves a safe non-2xx Edge response without exposing transport internals", async () => {
    const context = new Response(
      JSON.stringify({
        success: false,
        error_code: "WEEKLY_SHEET_MISSING",
        safe_message: "The selected weekly sheet was not found.",
        retryable: false,
        correlation_id: "correlation-1",
        upstream_body: "private Google body",
      }),
      { status: 404 },
    );
    const fake = edgeClient({
      data: null,
      error: { message: "Edge Function returned a non-2xx status", context },
    });
    const result = await createAtlasRpcTransport(
      fake.client,
    ).invokeEdgeFunction("atlas-weekly-menu-google-sync", {
      correlation_id: "correlation-1",
    });
    expect(result.kind).toBe("backend_error");
    if (result.kind === "backend_error") {
      expect(result.error).toMatchObject({
        error_code: "WEEKLY_SHEET_MISSING",
        safe_message: "The selected weekly sheet was not found.",
        retryable: false,
      });
      expect(result.error).not.toHaveProperty("upstream_body");
    }
  });
});
