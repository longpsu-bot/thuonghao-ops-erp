import { execFileSync } from "node:child_process";

const LOOPBACK_HOSTS = new Set(["127.0.0.1", "localhost"]);

function textField(value) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

export function parseLocalSupabaseStatus(
  rawStatus,
  { requireAdminKey = false } = {},
) {
  let status;
  try {
    status = typeof rawStatus === "string" ? JSON.parse(rawStatus) : rawStatus;
  } catch {
    throw new Error("Local Supabase status output is not valid JSON.");
  }
  if (!status || typeof status !== "object" || Array.isArray(status)) {
    throw new Error("Local Supabase status output is not a JSON object.");
  }

  const rawApiUrl = textField(status.API_URL);
  if (!rawApiUrl) {
    throw new Error("The local Supabase API URL is missing.");
  }

  let apiUrl;
  try {
    apiUrl = new URL(rawApiUrl);
  } catch {
    throw new Error("The local Supabase API URL is invalid.");
  }
  if (
    !["http:", "https:"].includes(apiUrl.protocol) ||
    !LOOPBACK_HOSTS.has(apiUrl.hostname) ||
    apiUrl.username ||
    apiUrl.password
  ) {
    throw new Error("The Supabase CLI status is not for a loopback API URL.");
  }

  const browserKey =
    textField(status.ANON_KEY) ?? textField(status.PUBLISHABLE_KEY);
  if (!browserKey) {
    throw new Error("The local Supabase browser key is missing.");
  }

  const serviceRoleKey = textField(status.SERVICE_ROLE_KEY);
  if (requireAdminKey && !serviceRoleKey) {
    throw new Error("The local Supabase admin key is missing.");
  }

  return {
    apiUrl: apiUrl.origin,
    browserKey,
    ...(requireAdminKey && serviceRoleKey ? { serviceRoleKey } : {}),
  };
}

export function runPinnedSupabase(
  args,
  { execFile = execFileSync, ...options } = {},
) {
  const pnpmExecutable = process.env.npm_execpath;
  if (!pnpmExecutable) {
    throw new Error("Run this local Supabase command through a pnpm script.");
  }
  return execFile(
    process.execPath,
    [pnpmExecutable, "exec", "supabase", ...args],
    options,
  );
}

export function readLocalSupabaseStatus({ requireAdminKey = false } = {}) {
  let rawStatus;
  try {
    rawStatus = runPinnedSupabase(["status", "-o", "json"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    });
  } catch {
    throw new Error(
      "Local Supabase status is unhealthy. Start the complete local stack before continuing.",
    );
  }
  return parseLocalSupabaseStatus(rawStatus, { requireAdminKey });
}
