import { createClient } from "@supabase/supabase-js";
import { readLocalSupabaseStatus } from "./local-supabase-status.mjs";

const authSubject = "b6000000-0000-0000-0000-000000000101";
const email = "atlas.pa06b.operator@local.test";
const password = "Atlas-PA06B-local-only!";
const customerId = "b6000000-0000-0000-0000-000000000201";
const correlationId = "b6000000-0000-0000-0000-000000000301";
const serviceDate = "2026-07-17";

async function main() {
  const { apiUrl, browserKey } = readLocalSupabaseStatus();
  const client = createClient(apiUrl, browserKey, {
    db: { retry: false },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
  const { data, error } = await client.auth.signInWithPassword({
    email,
    password,
  });
  if (error || data.session?.user.id !== authSubject) {
    throw new Error("The deterministic local Auth sign-in did not succeed.");
  }

  const { data: signedInState, error: sessionError } =
    await client.auth.getSession();
  if (sessionError || signedInState.session?.user.id !== authSubject) {
    throw new Error("The deterministic local Auth session was not available.");
  }

  let probeCategory;
  let probeFailure;
  try {
    const { data: probe, error: probeError } = await client
      .schema("atlas_api")
      .rpc("get_operator_blockers", {
        request: {
          contract_version: "PA-05C.v1",
          correlation_id: correlationId,
          requested_by_auth_subject: authSubject,
          payload: { service_date: serviceDate, customer_id: customerId },
        },
      })
      .retry(false);
    if (probeError || !probe || typeof probe !== "object") {
      throw new Error("The authenticated Atlas read transport failed safely.");
    }
    if (probe.success === true) {
      probeCategory = "SUCCESS";
    } else if (
      probe.success === false &&
      probe.error_code === "NOT_FOUND" &&
      probe.contract_version === "PA-05C.v1" &&
      probe.read_name === "get_operator_blockers"
    ) {
      probeCategory = "SAFE_NOT_FOUND";
    } else {
      throw new Error(
        "The authenticated Atlas read returned an unacceptable safe category.",
      );
    }
  } catch (error) {
    probeFailure =
      error instanceof Error
        ? error
        : new Error("The authenticated Atlas read failed safely.");
  }

  const { error: signOutError } = await client.auth.signOut({ scope: "local" });
  if (signOutError) throw new Error("The deterministic local sign-out failed.");
  const { data: afterSignOut, error: afterSignOutError } =
    await client.auth.getSession();
  if (afterSignOutError || afterSignOut.session)
    throw new Error("The local session remained after sign-out.");
  if (probeFailure) throw probeFailure;

  console.log(
    `Verified local sign-in, Auth subject ${authSubject}, ${probeCategory} Atlas read, and sign-out: ${email}`,
  );
}

try {
  await main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "Local connection verification failed safely.",
  );
  process.exitCode = 1;
}
