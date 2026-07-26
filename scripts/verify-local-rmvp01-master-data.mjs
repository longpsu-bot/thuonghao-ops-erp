import { createClient } from "@supabase/supabase-js";
import { readLocalSupabaseStatus } from "./local-supabase-status.mjs";

const email = "atlas.pa06b.operator@local.test";
const password = "Atlas-PA06B-local-only!";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function commandRequest(subject, expectedVersion, reasonCode, payload) {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-01.v1",
    command_id: commandId,
    correlation_id: crypto.randomUUID(),
    idempotency_key: `${reasonCode.toLowerCase()}:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: subject,
    requested_at: new Date(Date.now() - 1000).toISOString(),
    reason_code: reasonCode,
    reason_note: "Deterministic local RMVP-01 acceptance.",
    payload,
  };
}

async function invoke(client, name, request) {
  const { data, error } = await client
    .schema("atlas_api")
    .rpc(name, { request })
    .retry(false);
  if (error) throw new Error(`RMVP-01 ${name} transport failed safely.`);
  if (!data || data.success !== true) {
    throw new Error(
      `RMVP-01 ${name} was rejected: ${data?.error_code ?? "UNKNOWN"}.`,
    );
  }
  return data;
}

async function signIn(client) {
  const { data, error } = await client.auth.signInWithPassword({
    email,
    password,
  });
  if (error || !data.session) {
    throw new Error("RMVP-01 local acceptance sign-in failed.");
  }
  return data.session.user.id;
}

async function readSchools(client, subject) {
  return invoke(client, "get_school_master_data", {
    contract_version: "RMVP-01.v1",
    requested_by_auth_subject: subject,
    correlation_id: crypto.randomUUID(),
    payload: {},
  });
}

async function readIngredientSupplier(client, subject) {
  return invoke(client, "get_ingredient_supplier_master_data", {
    contract_version: "RMVP-01.v1",
    requested_by_auth_subject: subject,
    correlation_id: crypto.randomUUID(),
    payload: {},
  });
}

async function main() {
  const { apiUrl, browserKey } = readLocalSupabaseStatus();
  const client = createClient(apiUrl, browserKey, {
    db: { schema: "atlas_api" },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
  const subject = await signIn(client);
  const schoolRead = await readSchools(client, subject);
  const school = schoolRead.schools?.find(
    (item) => item.school_code === "atlas-primary",
  );
  assert(school, "RMVP-01 imported school was not returned.");
  const desiredStudentPortions = 421;
  const desiredTeacherPortions = 33;
  await invoke(
    client,
    "update_school_portion_defaults",
    commandRequest(subject, school.version, "RMVP01_ACCEPT_SCHOOL", {
      school_id: school.school_id,
      default_student_portions: desiredStudentPortions,
      default_teacher_portions: desiredTeacherPortions,
    }),
  );

  const masterRead = await readIngredientSupplier(client, subject);
  const ingredient = masterRead.ingredients?.find(
    (item) => item.ingredient_code === "rice-jasmine",
  );
  const supplier = masterRead.suppliers?.find(
    (item) => item.supplier_code === "minh-tam",
  );
  assert(ingredient, "RMVP-01 imported ingredient was not returned.");
  assert(supplier, "RMVP-01 imported supplier was not returned.");
  await invoke(
    client,
    "update_ingredient",
    commandRequest(subject, ingredient.version, "RMVP01_ACCEPT_INGREDIENT", {
      ingredient_id: ingredient.ingredient_id,
      ingredient_name: ingredient.ingredient_name,
      purchase_unit_id: ingredient.purchase_unit_id,
      ingredient_type: ingredient.ingredient_type,
      shopping_type: ingredient.shopping_type,
      order_step: ingredient.order_step,
    }),
  );
  const refreshedMaster = await readIngredientSupplier(client, subject);
  const refreshedIngredient = refreshedMaster.ingredients.find(
    (item) => item.ingredient_id === ingredient.ingredient_id,
  );
  await invoke(
    client,
    "replace_ingredient_supplier_priorities",
    commandRequest(
      subject,
      refreshedIngredient.version,
      "RMVP01_ACCEPT_PRIORITIES",
      {
        ingredient_id: refreshedIngredient.ingredient_id,
        priorities: refreshedIngredient.supplier_priorities.map((item) => ({
          supplier_id: item.supplier_id,
          priority: item.priority,
        })),
      },
    ),
  );
  await invoke(
    client,
    "update_supplier",
    commandRequest(subject, supplier.version, "RMVP01_ACCEPT_SUPPLIER", {
      supplier_id: supplier.supplier_id,
      supplier_name: supplier.supplier_name,
      contact_name: supplier.contact_name,
      contact_phone: supplier.contact_phone,
      contact_email: supplier.contact_email,
    }),
  );

  const afterCommand = await readSchools(client, subject);
  const changedSchool = afterCommand.schools.find(
    (item) => item.school_id === school.school_id,
  );
  assert(
    changedSchool?.default_student_portions === desiredStudentPortions &&
      changedSchool?.default_teacher_portions === desiredTeacherPortions,
    "RMVP-01 school command did not read back authoritative values.",
  );

  const signOut = await client.auth.signOut({ scope: "local" });
  if (signOut.error) throw new Error("RMVP-01 local sign-out failed.");
  const signedInAgainSubject = await signIn(client);
  assert(
    signedInAgainSubject === subject,
    "RMVP-01 sign-in restored a different subject.",
  );
  const afterSignIn = await readSchools(client, subject);
  const persistedSchool = afterSignIn.schools.find(
    (item) => item.school_id === school.school_id,
  );
  assert(
    persistedSchool?.default_student_portions === desiredStudentPortions &&
      persistedSchool?.default_teacher_portions === desiredTeacherPortions,
    "RMVP-01 values did not survive sign-out and sign-in.",
  );
  await client.auth.signOut({ scope: "local" });
  console.log(
    "Verified RMVP-01 sign-in, commands, authoritative refresh, sign-out, sign-in, and persisted readback.",
  );
}

try {
  await main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "RMVP-01 local acceptance failed safely.",
  );
  process.exitCode = 1;
}
