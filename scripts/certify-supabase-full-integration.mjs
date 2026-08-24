import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import {
  defaultCommandRunner,
  redactAtlasStagingDiagnostic,
} from "./atlas-staging-contract.mjs";

const REDUCED_STACK_EXCLUSIONS =
  "edge-runtime,imgproxy,logflare,mailpit,postgres-meta,realtime,storage-api,studio,supavisor,vector";

const DATABASE_TESTS_BEFORE_BROWSER = Object.freeze([
  "atlas_current_platform_security_catalog.sql",
  "pa_04_supplier_direct_slice_1_foundation.sql",
  "pa_05b_h1_runtime_role_hardening_test.sql",
  "pa_05b_h2_multiline_dispatch_execution.sql",
  "pa_05b_h3_successful_trip_closure.sql",
  "pa_05b_supplier_direct_command_subset.sql",
  "pa_05c_authorized_read_api_wrappers.sql",
  "pa_05c_h2_current_command_timeline_scope.sql",
  "pa_05d_planning_command_family.sql",
  "pa_05e_procurement_command_family.sql",
  "pa_05f_dispatch_setup_command_family.sql",
  "rmvp_01_atlas_master_data.sql",
  "rmvp_02a_connected_recipes_bom.sql",
  "rmvp_02b_recipe_adjustments_effective_bom.sql",
  "rmvp_03a_connected_weekly_menu_attendance.sql",
  "pantry_02_connected_pantry_source.sql",
  "pa_06e_h1b1_line_decision_structure_security.sql",
  "pa_06e_h1b1_line_decision_chain_pointer.sql",
  "pa_06e_h1b1_line_decision_policy_quantity_integrity.sql",
  "pa_06e_h1a_planning_quantity_policy_structure_security.sql",
  "pa_06e_h1a_planning_quantity_policy_revision_lifecycle.sql",
  "pa_06e_h1a_planning_quantity_policy_effectivity_resolution.sql",
  "pa_06e_h0a1_school_customer_location_foundation.sql",
  "pa_06e_h0a2_recipe_bom_immutable_reference_foundation.sql",
  "pa_06e_h0a3a_weekly_menu_persistence_foundation.sql",
  "pa_06e_h0a3b_attendance_structure_security.sql",
  "pa_06e_h0a3b_attendance_lifecycle_mutability.sql",
  "pa_06e_h0a3b_attendance_approval_snapshot_integrity.sql",
  "pa_06e_h0a4b_planning_input_readiness_structure_security.sql",
  "pa_06e_h0a4b_planning_input_readiness_evaluation_source_snapshot_integrity.sql",
  "pa_06e_h0a4b_planning_input_readiness_lifecycle_issues_invalidation.sql",
  "rmvp_03b_connected_planning_input_readiness.sql",
  "pa_06e_h0a5b_need_generation_structure_security.sql",
  "pa_06e_h0a5b_need_generation_run_input_recipe_calculation_integrity.sql",
  "pa_06e_h0a5b_theoretical_line_source_predecessor_release_integrity.sql",
  "pa_06e_h0a5b_need_generation_lifecycle_issues_invalidation_history.sql",
  "pa_06e_h0b1b_confirmed_need_structure_security_catalog.sql",
  "pa_06e_h0b1b_wholesale_compatibility_source_classification.sql",
  "pa_06e_h0b1b_school_catering_identity_current_source.sql",
  "pa_06e_h0b1b_contribution_membership_total_partition_history.sql",
  "pa_06e_h0cb_materialization_registry_security_catalog.sql",
  "pa_06e_h0cb_initial_materialization.sql",
  "pa_06e_h0cb_corrected_materialization_history.sql",
  "pa_06e_h0cb_errors_authorization_concurrency.sql",
  "pantry_ng_02_direct_ingredient_persistence_materialization.sql",
  "rmvp_04_connected_need_generation.sql",
  "planning_contract_01_atomic_planning_boundaries.sql",
  "planning_contract_02b_selective_confirmation_continuity.sql",
  "rmvp_05_connected_confirmed_need_review.sql",
]);

function pnpm(...args) {
  return Object.freeze({ command: "pnpm", args: Object.freeze(args) });
}

const databaseTests = DATABASE_TESTS_BEFORE_BROWSER.map((file) =>
  pnpm("exec", "supabase", "test", "db", `supabase/tests/${file}`, "--local"),
);

export const SUPABASE_FULL_INTEGRATION_COMMANDS = Object.freeze([
  pnpm("exec", "supabase", "db", "reset", "--local", "--no-seed"),
  ...databaseTests,
  pnpm(
    "exec",
    "supabase",
    "db",
    "query",
    "--local",
    "--file",
    "supabase/local/pa_06b_synthetic_identity.sql",
  ),
  pnpm(
    "exec",
    "supabase",
    "db",
    "query",
    "--local",
    "--file",
    "supabase/local/rmvp_05_browser_fixture.sql",
  ),
  pnpm(
    "exec",
    "supabase",
    "test",
    "db",
    "supabase/tests/rmvp_06_connected_confirmed_need_validation.sql",
    "--local",
  ),
  pnpm(
    "exec",
    "supabase",
    "test",
    "db",
    "supabase/tests/rmvp_07_connected_confirmed_need_approval_release.sql",
    "--local",
  ),
  pnpm(
    "exec",
    "supabase",
    "test",
    "db",
    "supabase/tests/d037_confirmed_need_save_release_boundary.sql",
    "--local",
  ),
  pnpm("exec", "supabase", "db", "reset", "--local", "--no-seed"),
  pnpm(
    "exec",
    "supabase",
    "test",
    "db",
    "supabase/tests/pa_05g_backend_end_to_end_acceptance.sql",
    "--local",
  ),
  pnpm(
    "exec",
    "supabase",
    "test",
    "db",
    "supabase/tests/pa_05c_h3_evidence_readiness_current_command_context.sql",
    "--local",
  ),
  pnpm("local:auth:provision"),
  pnpm("local:connection:verify"),
  pnpm("local:pa06c:provision"),
  pnpm("local:pa06c:verify"),
  pnpm(
    "local:master-data:import",
    "--",
    "--file",
    "supabase/local/rmvp_01_master_data_snapshot.example.json",
  ),
  pnpm("local:rmvp01:verify"),
  pnpm("local:rmvp02a:verify"),
  pnpm("local:rmvp02b:verify"),
  pnpm("local:rmvp03a:verify"),
  pnpm("local:pantry02:verify"),
  Object.freeze({
    ...pnpm("local:rmvp04:verify"),
    environment: Object.freeze({
      RMVP05_BROWSER_SOURCE: "rmvp04",
      RMVP06_BROWSER_SOURCE: "rmvp04",
      RMVP07_BROWSER_SOURCE: "rmvp04",
      RMVP07_CONTRACT: "v1",
    }),
  }),
  Object.freeze({
    ...pnpm("local:rmvp05:verify"),
    environment: Object.freeze({
      RMVP05_BROWSER_SOURCE: "rmvp04",
      RMVP06_BROWSER_SOURCE: "rmvp04",
      RMVP07_BROWSER_SOURCE: "rmvp04",
      RMVP07_CONTRACT: "v1",
    }),
  }),
  Object.freeze({
    ...pnpm("local:rmvp06:verify"),
    environment: Object.freeze({
      RMVP05_BROWSER_SOURCE: "rmvp04",
      RMVP06_BROWSER_SOURCE: "rmvp04",
      RMVP07_BROWSER_SOURCE: "rmvp04",
      RMVP07_CONTRACT: "v1",
    }),
  }),
  Object.freeze({
    ...pnpm("verify:local:rmvp07"),
    environment: Object.freeze({
      RMVP05_BROWSER_SOURCE: "rmvp04",
      RMVP06_BROWSER_SOURCE: "rmvp04",
      RMVP07_BROWSER_SOURCE: "rmvp04",
      RMVP07_CONTRACT: "v1",
    }),
  }),
  pnpm("verify:local:rmvp07"),
  pnpm("local:planning-contract-01:verify"),
]);

function boundedDiagnostic(result) {
  return redactAtlasStagingDiagnostic(
    `${result.stdout ?? ""}\n${result.stderr ?? ""}`,
  )
    .split(/\r?\n/)
    .slice(-120)
    .join("\n")
    .trim();
}

function requireCommandSuccess(result, label) {
  if (result.status === 0) return;
  const diagnostic = boundedDiagnostic(result);
  throw new Error(
    diagnostic
      ? `Supabase Full Integration failed at ${label}.\n${diagnostic}`
      : `Supabase Full Integration failed at ${label}.`,
  );
}

export function inspectLocalSupabaseCertificationCli({
  cwd = process.cwd(),
  environment = process.env,
  runCommand = defaultCommandRunner,
} = {}) {
  const expectedVersion = JSON.parse(
    readFileSync(`${cwd}/package.json`, "utf8"),
  ).devDependencies?.supabase;
  const options = {
    cwd,
    env: { ...environment, SUPABASE_TELEMETRY_DISABLED: "1" },
  };
  const versionResult = runCommand(
    "pnpm",
    ["exec", "supabase", "--version"],
    options,
  );
  requireCommandSuccess(versionResult, "pinned CLI version inspection");
  if (versionResult.stdout.trim() !== expectedVersion) {
    throw new Error(
      "Supabase Full Integration requires the repository-pinned CLI version.",
    );
  }
  const helpChecks = [
    [["exec", "supabase", "start", "--help"], ["--exclude"]],
    [
      ["exec", "supabase", "db", "reset", "--help"],
      ["--local", "--no-seed"],
    ],
    [["exec", "supabase", "test", "db", "--help"], ["--local"]],
    [
      ["exec", "supabase", "db", "query", "--help"],
      ["--local", "--file"],
    ],
    [["exec", "supabase", "stop", "--help"], ["--no-backup"]],
  ];
  for (const [args, flags] of helpChecks) {
    const result = runCommand("pnpm", args, options);
    requireCommandSuccess(result, `pnpm ${args.join(" ")}`);
    if (flags.some((flag) => !result.stdout.includes(flag))) {
      throw new Error(
        "The pinned Supabase CLI does not expose a required local certification flag.",
      );
    }
  }
  return expectedVersion;
}

export function certifySupabaseFullIntegration({
  cwd = process.cwd(),
  environment = process.env,
  runCommand = defaultCommandRunner,
} = {}) {
  const certificationEnvironment = {
    ...environment,
    SUPABASE_TELEMETRY_DISABLED: "1",
  };
  inspectLocalSupabaseCertificationCli({
    cwd,
    environment: certificationEnvironment,
    runCommand,
  });

  let primaryError;
  try {
    console.log("Supabase Full Integration: start reduced local stack");
    requireCommandSuccess(
      runCommand(
        "pnpm",
        ["exec", "supabase", "start", "--exclude", REDUCED_STACK_EXCLUSIONS],
        { cwd, env: certificationEnvironment },
      ),
      "reduced local Supabase start",
    );

    for (const item of SUPABASE_FULL_INTEGRATION_COMMANDS) {
      const label = `${item.command} ${item.args.join(" ")}`;
      console.log(`Supabase Full Integration: ${label}`);
      const result = runCommand(item.command, item.args, {
        cwd,
        env: { ...certificationEnvironment, ...item.environment },
      });
      requireCommandSuccess(result, label);
    }
  } catch (error) {
    primaryError = error;
    throw error;
  } finally {
    console.log("Supabase Full Integration: stop local stack");
    const stopResult = runCommand(
      "pnpm",
      ["exec", "supabase", "stop", "--no-backup"],
      { cwd, env: certificationEnvironment },
    );
    if (stopResult.status !== 0 && !primaryError) {
      console.warn(
        "Local Supabase cleanup did not complete; certification checks had already passed.",
      );
    }
  }
  return {
    status: "certified",
    commands: SUPABASE_FULL_INTEGRATION_COMMANDS.length,
  };
}

function main() {
  certifySupabaseFullIntegration();
  console.log("Supabase Full Integration certification passed.");
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  try {
    main();
  } catch (error) {
    console.error(
      redactAtlasStagingDiagnostic(
        error instanceof Error
          ? error.message
          : "Supabase Full Integration certification failed safely.",
      ),
    );
    process.exitCode = 1;
  }
}
