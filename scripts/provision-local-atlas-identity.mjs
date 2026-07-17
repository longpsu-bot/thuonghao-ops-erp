import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  readLocalSupabaseStatus,
  runPinnedSupabase,
} from "./local-supabase-status.mjs";

const authSubject = "b6000000-0000-0000-0000-000000000101";
const email = "atlas.pa06b.operator@local.test";
const password = "Atlas-PA06B-local-only!";

async function provisionAuthUser(apiUrl, serviceRoleKey) {
  const admin = createClient(apiUrl, serviceRoleKey, {
    db: { retry: false },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
  const { data: usersData, error: usersError } =
    await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (usersError) throw new Error("Local Auth users could not be inspected.");

  const conflictingUser = usersData.users.find(
    (user) => user.email === email && user.id !== authSubject,
  );
  if (conflictingUser) {
    throw new Error(
      "The synthetic local email is already assigned unexpectedly.",
    );
  }

  const existingUser = usersData.users.find((user) => user.id === authSubject);
  const attributes = {
    email,
    password,
    email_confirm: true,
    user_metadata: { display_name: "PA-06B Synthetic Local Operator" },
    app_metadata: { environment: "local-pa-06b" },
  };
  const result = existingUser
    ? await admin.auth.admin.updateUserById(authSubject, attributes)
    : await admin.auth.admin.createUser({ id: authSubject, ...attributes });
  if (result.error || result.data.user?.id !== authSubject) {
    throw new Error(
      "The deterministic local Auth user could not be provisioned.",
    );
  }
}

function provisionAtlasMapping() {
  const sqlPath = fileURLToPath(
    new URL("../supabase/local/pa_06b_synthetic_identity.sql", import.meta.url),
  );
  const assertionPath = fileURLToPath(
    new URL(
      "../supabase/local/pa_06b_synthetic_identity_assertion.sql",
      import.meta.url,
    ),
  );
  runPinnedSupabase(["db", "query", "--local", "--file", sqlPath], {
    stdio: "inherit",
  });
  runPinnedSupabase(["db", "query", "--local", "--file", assertionPath], {
    stdio: "inherit",
  });
}

async function main() {
  const { apiUrl, serviceRoleKey } = readLocalSupabaseStatus({
    requireAdminKey: true,
  });
  await provisionAuthUser(apiUrl, serviceRoleKey);
  provisionAtlasMapping();
  console.log(`Provisioned deterministic local Atlas identity: ${email}`);
}

try {
  await main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "Local identity provisioning failed safely.",
  );
  process.exitCode = 1;
}
