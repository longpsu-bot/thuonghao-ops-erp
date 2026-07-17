import { execFileSync } from "node:child_process";
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
      "Local Supabase status is unhealthy. Start the complete local stack before verification.",
    );
  }
  const status = JSON.parse(output);
  const apiUrl = new URL(status.API_URL);
  if (!["127.0.0.1", "localhost"].includes(apiUrl.hostname)) {
    throw new Error("PA-06B verification is restricted to local Supabase.");
  }
  if (!status.PUBLISHABLE_KEY) {
    throw new Error("The local browser publishable key is unavailable.");
  }
  return { apiUrl: apiUrl.origin, publishableKey: status.PUBLISHABLE_KEY };
}

async function main() {
  const { apiUrl, publishableKey } = localStatus();
  const client = createClient(apiUrl, publishableKey, {
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
  const { error: signOutError } = await client.auth.signOut({ scope: "local" });
  if (signOutError) throw new Error("The deterministic local sign-out failed.");
  const { data: afterSignOut } = await client.auth.getSession();
  if (afterSignOut.session)
    throw new Error("The local session remained after sign-out.");

  console.log(`Verified local sign-in, Auth subject, and sign-out: ${email}`);
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
