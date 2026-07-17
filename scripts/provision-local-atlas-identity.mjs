import { execFileSync, spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";

const authSubject = "b6000000-0000-0000-0000-000000000101";
const email = "atlas.pa06b.operator@local.test";
const password = "Atlas-PA06B-local-only!";

function localStatus() {
  let output;
  try {
    output = execFileSync("supabase", ["status", "-o", "json"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    });
  } catch {
    throw new Error(
      "Local Supabase status is unhealthy. Start the complete local stack before provisioning.",
    );
  }
  const status = JSON.parse(output);
  const apiUrl = new URL(status.API_URL);
  if (!["127.0.0.1", "localhost"].includes(apiUrl.hostname)) {
    throw new Error("PA-06B provisioning is restricted to local Supabase.");
  }
  if (!status.SECRET_KEY) {
    throw new Error(
      "The local Supabase secret key is unavailable from CLI status.",
    );
  }
  return { apiUrl: apiUrl.origin, secretKey: status.SECRET_KEY };
}

async function provisionAuthUser(apiUrl, secretKey) {
  const admin = createClient(apiUrl, secretKey, {
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
  const result = spawnSync(
    "docker",
    [
      "exec",
      "-i",
      "supabase_db_thuonghao-ops-erp",
      "psql",
      "-U",
      "postgres",
      "-d",
      "postgres",
      "-v",
      "ON_ERROR_STOP=1",
    ],
    {
      input: readFileSync(sqlPath, "utf8"),
      encoding: "utf8",
      stdio: ["pipe", "inherit", "inherit"],
    },
  );
  if (result.status !== 0) {
    throw new Error(
      "The synthetic Atlas actor mapping could not be provisioned.",
    );
  }
}

async function main() {
  const { apiUrl, secretKey } = localStatus();
  await provisionAuthUser(apiUrl, secretKey);
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
