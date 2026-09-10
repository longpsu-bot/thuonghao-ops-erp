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

const NEED_QUANTITY_SCALE = 6;

function needQuantity(value) {
  const match = /^(-?)(\d+)(?:\.(\d+))?$/.exec(String(value).trim());
  if (!match || (match[3]?.length ?? 0) > NEED_QUANTITY_SCALE)
    throw new Error(
      "Need quantity evidence is not an exact supported decimal.",
    );
  const magnitude = BigInt(
    `${match[2]}${(match[3] ?? "").padEnd(NEED_QUANTITY_SCALE, "0")}`,
  );
  return match[1] ? -magnitude : magnitude;
}

function sumNeedQuantities(rows, field) {
  return rows.reduce((sum, row) => sum + needQuantity(row[field]), 0n);
}

function detailGroupFromRequirement(requirement) {
  return {
    service_date: requirement.service_date,
    school_id: requirement.school_id,
    delivery_location_id: requirement.delivery_location_id,
    ingredient_id: requirement.ingredient_id,
    unit_id: requirement.unit_id,
  };
}

function uniqueDetailGroups(requirements) {
  const groups = new Map();
  for (const requirement of requirements) {
    const detailGroup = detailGroupFromRequirement(requirement);
    const key = JSON.stringify([
      detailGroup.service_date,
      detailGroup.school_id,
      detailGroup.delivery_location_id,
      detailGroup.ingredient_id,
      detailGroup.unit_id,
    ]);
    groups.set(key, detailGroup);
  }
  return [...groups.values()];
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
  const dailyNeed = bundle?.needEvidence?.daily;
  if (!Array.isArray(dailyNeed))
    throw new Error("Daily Need workbench evidence is missing.");
  const needDay = (serviceDate) => {
    const day = dailyNeed.find(
      (item) =>
        item?.service_date === serviceDate &&
        item.workbench?.period?.period_start === serviceDate &&
        item.workbench?.period?.period_end === serviceDate,
    );
    if (!day) throw new Error(`Need workbench for ${serviceDate} is missing.`);
    if (!Array.isArray(day.workbench.grouped_requirements))
      throw new Error(
        `Need workbench for ${serviceDate} has no grouped evidence.`,
      );
    if (!Array.isArray(day.atomic_detail))
      throw new Error(
        `Need workbench for ${serviceDate} has no atomic evidence.`,
      );
    return day;
  };
  const scenarioANeed = needDay(SCHOOL_FULFILMENT_SCENARIO_DATES[0]);
  const scenarioAGroups = scenarioANeed.workbench.grouped_requirements;
  const scenarioARecipe = sumNeedQuantities(
    scenarioAGroups,
    "recipe_derived_quantity",
  );
  const scenarioAPantry = sumNeedQuantities(
    scenarioAGroups,
    "pantry_direct_quantity",
  );
  const scenarioATotal = sumNeedQuantities(
    scenarioAGroups,
    "total_theoretical_quantity",
  );
  if (
    scenarioARecipe !== needQuantity("11") ||
    scenarioAPantry !== needQuantity("1.3") ||
    scenarioATotal !== needQuantity("12.3") ||
    scenarioATotal !== scenarioARecipe + scenarioAPantry
  )
    throw new Error(
      "Scenario A does not prove additive Recipe and Pantry grouped quantities.",
    );
  const scenarioAFamilies = new Set(
    scenarioANeed.atomic_detail
      .filter((item) => item.disposition === "ACTIVE")
      .map((item) => item.contribution_family),
  );
  if (
    !scenarioAFamilies.has("RECIPE_DERIVED") ||
    !scenarioAFamilies.has("PANTRY_DIRECT")
  )
    throw new Error(
      "Scenario A does not prove additive Recipe and Pantry contribution membership.",
    );
  const scenarioBNeed = needDay(SCHOOL_FULFILMENT_SCENARIO_DATES[1]);
  const scenarioBGroups = scenarioBNeed.workbench.grouped_requirements;
  const scenarioBRecipe = sumNeedQuantities(
    scenarioBGroups,
    "recipe_derived_quantity",
  );
  const scenarioBPantry = sumNeedQuantities(
    scenarioBGroups,
    "pantry_direct_quantity",
  );
  const scenarioBTotal = sumNeedQuantities(
    scenarioBGroups,
    "total_theoretical_quantity",
  );
  if (
    scenarioBRecipe !== needQuantity("0") ||
    scenarioBPantry !== needQuantity("7.75") ||
    scenarioBTotal !== needQuantity("7.75") ||
    scenarioBTotal !== scenarioBPantry
  )
    throw new Error(
      "Scenario B does not prove COMPLETE Pantry-only grouped quantities.",
    );
  const scenarioBAtomic = scenarioBNeed.atomic_detail.filter(
    (item) => item.disposition === "ACTIVE",
  );
  if (
    !scenarioBAtomic.length ||
    scenarioBAtomic.some(
      (item) =>
        item.contribution_family !== "PANTRY_DIRECT" || item.recipe_id != null,
    )
  )
    throw new Error(
      "Scenario B does not prove COMPLETE Pantry authority without fabricated bindings.",
    );
  needDay(SCHOOL_FULFILMENT_SCENARIO_DATES[2]);
  const scenarioC = rows.find(
    (item) => item.service_date === SCHOOL_FULFILMENT_SCENARIO_DATES[2],
  );
  const confirmedNeedLines = (bundle?.confirmedNeeds?.rows ?? []).flatMap(
    (response) => response?.workbench?.lines ?? [],
  );
  const correctedNeedLine = confirmedNeedLines.find(
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
  const poFacts = (bundle?.purchaseOrders?.purchase_orders ?? []).filter(
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

function needWorkbenchRequest(authSubject, serviceDate, detailGroup) {
  return envelope("RMVP-04.v1", authSubject, {
    period_start: serviceDate,
    period_end: serviceDate,
    need_generation_run_id: null,
    filters: {
      service_date: null,
      school_id: null,
      ingredient_id: null,
      contribution_family: null,
    },
    group_offset: 0,
    group_limit: 250,
    ...(detailGroup ? { detail_group: detailGroup } : {}),
  });
}

async function readDailyNeedEvidence(client, authSubject) {
  const dailyBase = await Promise.all(
    SCHOOL_FULFILMENT_SCENARIO_DATES.map(async (serviceDate) => ({
      service_date: serviceDate,
      response: await readRpc(
        client,
        "get_need_generation_workbench",
        needWorkbenchRequest(authSubject, serviceDate),
      ),
    })),
  );
  return {
    daily: await Promise.all(
      dailyBase.map(async ({ service_date, response }) => {
        const workbench = response?.workbench;
        const requirements = Array.isArray(workbench?.grouped_requirements)
          ? workbench.grouped_requirements
          : [];
        const needsAtomicDetail =
          service_date === SCHOOL_FULFILMENT_SCENARIO_DATES[0] ||
          service_date === SCHOOL_FULFILMENT_SCENARIO_DATES[1];
        const detailGroups = needsAtomicDetail
          ? uniqueDetailGroups(requirements)
          : [];
        const detailResponses = await Promise.all(
          detailGroups.map((detailGroup) =>
            readRpc(
              client,
              "get_need_generation_workbench",
              needWorkbenchRequest(authSubject, service_date, detailGroup),
            ),
          ),
        );
        return {
          service_date,
          workbench,
          atomic_detail: detailResponses.flatMap((detailResponse) =>
            Array.isArray(detailResponse?.workbench?.atomic_detail)
              ? detailResponse.workbench.atomic_detail
              : [],
          ),
        };
      }),
    ),
  };
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
    const [needEvidence, allocation, purchaseOrders, dispatch, reconciliation] =
      await Promise.all([
        readDailyNeedEvidence(client, authSubject),
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
        (allocation?.rows ?? [])
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
      needEvidence,
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
