import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  redactAtlasStagingDiagnostic,
  validateApprovedAtlasStagingTarget,
  validateAtlasStagingProtectedValues,
} from "./atlas-staging-contract.mjs";

export const SCHOOL_FULFILMENT_SCENARIO_DATES = Object.freeze([
  "2046-09-17",
  "2046-09-18",
  "2046-09-19",
]);

function objects(value) {
  if (Array.isArray(value)) return value.flatMap(objects);
  if (!value || typeof value !== "object") return [];
  return [value, ...Object.values(value).flatMap(objects)];
}

export function assertSchoolFulfilmentScenarios(bundle) {
  const rows = bundle?.reconciliation?.rows;
  if (!Array.isArray(rows))
    throw new Error("Reconciliation evidence is missing.");
  for (const serviceDate of SCHOOL_FULFILMENT_SCENARIO_DATES) {
    const row = rows.find((item) => item?.service_date === serviceDate);
    if (!row) throw new Error(`Scenario ${serviceDate} is missing.`);
    if (
      row.comparison_status !== "OK" ||
      row.pxk_state !== "CURRENT" ||
      row.blockers?.length
    )
      throw new Error(
        `Scenario ${serviceDate} is not reconciled and operationally current.`,
      );
    if (
      !Array.isArray(row.quantity_totals_by_unit) ||
      !row.quantity_totals_by_unit.length
    )
      throw new Error(
        `Scenario ${serviceDate} has no unit-safe quantity evidence.`,
      );
  }
  const needFacts = objects(bundle.need);
  const scenarioAFamilies = new Set(
    needFacts
      .filter(
        (item) => item.service_date === SCHOOL_FULFILMENT_SCENARIO_DATES[0],
      )
      .map((item) => item.contribution_family ?? item.contribution_kind)
      .filter(Boolean),
  );
  if (
    !scenarioAFamilies.has("RECIPE_DERIVED") ||
    !scenarioAFamilies.has("PANTRY_DIRECT")
  )
    throw new Error(
      "Scenario A does not prove additive Recipe and Pantry contribution membership.",
    );
  const scenarioB = needFacts.find(
    (item) =>
      item.service_date === SCHOOL_FULFILMENT_SCENARIO_DATES[1] &&
      (item.contribution_family ?? item.contribution_kind) === "PANTRY_DIRECT",
  );
  if (
    !scenarioB ||
    scenarioB.weekly_menu_id ||
    scenarioB.attendance_batch_id ||
    scenarioB.recipe_version_id
  )
    throw new Error(
      "Scenario B does not prove COMPLETE Pantry authority without fabricated bindings.",
    );
  const scenarioC = rows.find(
    (item) => item.service_date === SCHOOL_FULFILMENT_SCENARIO_DATES[2],
  );
  const correctedNeedLine = objects(bundle.confirmedNeeds).find(
    (item) =>
      item.service_date === SCHOOL_FULFILMENT_SCENARIO_DATES[2] &&
      Array.isArray(item.decision_history),
  );
  const currentNeedDecision = correctedNeedLine?.decision_history.find(
    (item) => item.decision_id === correctedNeedLine.current_decision_id,
  );
  const predecessorNeedDecision = correctedNeedLine?.decision_history.find(
    (item) => item.decision_id === currentNeedDecision?.predecessor_decision_id,
  );
  if (
    correctedNeedLine?.decision_history.length < 2 ||
    currentNeedDecision?.revision_id !==
      correctedNeedLine.current_revision_id ||
    !predecessorNeedDecision ||
    predecessorNeedDecision.revision_id === currentNeedDecision.revision_id
  )
    throw new Error(
      "Scenario C does not retain the predecessor Confirmed Need decision and revision.",
    );
  const oldPxk = scenarioC?.history?.find(
    (item) => item.status === "SUPERSEDED",
  );
  const currentPxk = scenarioC?.history?.find(
    (item) =>
      item.school_dispatch_release_id === scenarioC.school_dispatch_release_id,
  );
  if (
    !Array.isArray(scenarioC?.history) ||
    scenarioC.history.length < 2 ||
    !oldPxk ||
    currentPxk?.status !== "RELEASED" ||
    currentPxk.predecessor_release_id !== oldPxk.school_dispatch_release_id
  )
    throw new Error("Scenario C does not retain superseded PXK evidence.");
  const poFacts = objects(bundle.purchaseOrders).filter(
    (item) =>
      item.service_date === SCHOOL_FULFILMENT_SCENARIO_DATES[2] ||
      item.school_catering_service_date === SCHOOL_FULFILMENT_SCENARIO_DATES[2],
  );
  const oldPo = poFacts.find(
    (item) =>
      item.purchase_order_status === "SUPERSEDED" ||
      item.status === "SUPERSEDED",
  );
  const currentPo = poFacts.find(
    (item) =>
      item.purchase_order_status === "RELEASED_TO_SUPPLIER" ||
      item.status === "RELEASED_TO_SUPPLIER",
  );
  if (
    !oldPo ||
    !currentPo ||
    currentPo.replaces_purchase_order_id !== oldPo.purchase_order_id ||
    !scenarioC.purchase_order_ids?.includes(currentPo.purchase_order_id)
  )
    throw new Error("Scenario C does not retain superseded PO evidence.");
  return {
    status: "verified",
    scenarios: SCHOOL_FULFILMENT_SCENARIO_DATES.length,
  };
}

function envelope(contractVersion, authSubject, payload) {
  return {
    contract_version: contractVersion,
    requested_by_auth_subject: authSubject,
    correlation_id: randomUUID(),
    payload,
  };
}

async function readRpc(client, name, request) {
  const { data, error } = await client
    .schema("atlas_api")
    .rpc(name, { request })
    .retry(false);
  if (error || data?.success !== true)
    throw new Error(`Read-only ${name} verification failed.`);
  return data;
}

export function planSchoolFulfilmentVerification(environment = process.env) {
  const target = validateAtlasStagingProtectedValues(environment, {
    requireDatabasePassword: false,
  });
  validateApprovedAtlasStagingTarget(target.projectRef, target.supabaseUrl);
  return {
    target,
    dates: SCHOOL_FULFILMENT_SCENARIO_DATES,
    routes: [
      "get_need_generation_workbench",
      "get_confirmed_need_review",
      "get_confirmed_supplier_allocation_workbench",
      "get_school_catering_purchase_orders",
      "get_school_dispatch_release_workbench",
      "get_school_fulfilment_reconciliation_workbench",
    ],
    networkWrites: false,
  };
}

export async function verifyAtlasStagingSchoolFulfilment({
  environment = process.env,
  createClientFactory = createClient,
  dryRun = false,
} = {}) {
  const plan = planSchoolFulfilmentVerification(environment);
  if (dryRun) return plan;
  const client = createClientFactory(
    plan.target.supabaseUrl,
    plan.target.publishableKey,
    {
      db: { retry: false },
      auth: {
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUrl: false,
      },
    },
  );
  const signIn = await client.auth.signInWithPassword({
    email: plan.target.testEmail,
    password: plan.target.testPassword,
  });
  if (signIn.error || !signIn.data.session?.user.id)
    throw new Error("Protected Atlas staging sign-in failed safely.");
  const authSubject = signIn.data.session.user.id;
  let failure;
  try {
    const dateStart = SCHOOL_FULFILMENT_SCENARIO_DATES[0];
    const dateEnd = SCHOOL_FULFILMENT_SCENARIO_DATES[2];
    const scope = {
      date_start: dateStart,
      date_end: dateEnd,
      school_ids: [],
      search: null,
    };
    const [need, allocation, purchaseOrders, dispatch, reconciliation] =
      await Promise.all([
        readRpc(
          client,
          "get_need_generation_workbench",
          envelope("RMVP-04.v1", authSubject, {
            period_start: dateStart,
            period_end: dateEnd,
            need_generation_run_id: null,
            filters: {
              service_date: null,
              school_id: null,
              ingredient_id: null,
              contribution_family: null,
            },
            group_offset: 0,
            group_limit: 250,
          }),
        ),
        readRpc(
          client,
          "get_confirmed_supplier_allocation_workbench",
          envelope("CONFIRMED-SUPPLIER-ALLOCATION.v1", authSubject, {
            ...scope,
            states: [],
          }),
        ),
        readRpc(
          client,
          "get_school_catering_purchase_orders",
          envelope("SCHOOL-CATERING-PROCUREMENT.v1", authSubject, {
            date_start: dateStart,
            date_end: dateEnd,
            supplier_ids: [],
            statuses: [],
            search: null,
          }),
        ),
        readRpc(
          client,
          "get_school_dispatch_release_workbench",
          envelope("SCHOOL-DISPATCH-RELEASE.v1", authSubject, scope),
        ),
        readRpc(
          client,
          "get_school_fulfilment_reconciliation_workbench",
          envelope("SCHOOL-FULFILMENT-RECONCILIATION.v1", authSubject, scope),
        ),
      ]);
    const scenarioCBatchIds = [
      ...new Set(
        objects(allocation)
          .filter(
            (item) => item.service_date === SCHOOL_FULFILMENT_SCENARIO_DATES[2],
          )
          .map(
            (item) =>
              item.source_confirmed_need_batch_id ??
              item.confirmed_need_batch_id,
          )
          .filter(Boolean),
      ),
    ];
    const confirmedNeeds = await Promise.all(
      scenarioCBatchIds.map((confirmedNeedBatchId) =>
        readRpc(
          client,
          "get_confirmed_need_review",
          envelope("RMVP-05.v1", authSubject, {
            confirmed_need_batch_id: confirmedNeedBatchId,
            filters: {
              service_date: SCHOOL_FULFILMENT_SCENARIO_DATES[2],
              school_id: null,
              delivery_location_id: null,
              ingredient_id: null,
              decision_state: null,
            },
            line_offset: 0,
            line_limit: 250,
          }),
        ),
      ),
    );
    return assertSchoolFulfilmentScenarios({
      need,
      confirmedNeeds: { rows: confirmedNeeds },
      allocation,
      purchaseOrders,
      dispatch,
      reconciliation,
    });
  } catch (error) {
    failure = error;
  } finally {
    const signOut = await client.auth.signOut({ scope: "local" });
    if (!failure && signOut.error)
      failure = new Error("The staging verification session was not cleared.");
  }
  throw failure;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  verifyAtlasStagingSchoolFulfilment({
    dryRun: process.argv.includes("--dry-run"),
  })
    .then((result) =>
      console.log(
        process.argv.includes("--dry-run")
          ? "School fulfilment verifier dry-run passed."
          : `School fulfilment verifier passed (${result.scenarios} scenarios).`,
      ),
    )
    .catch((error) => {
      console.error(redactAtlasStagingDiagnostic(error));
      process.exitCode = 1;
    });
}
