import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import {
  executeAtlasStagingManagementSql,
  repositorySupabaseCliInvocation,
} from "./atlas-staging-contract.mjs";
import { validateV1ReferenceImportRequest } from "./atlas-staging-v1-reference-target.mjs";
import { verifyExactMainCheckout } from "./import-atlas-staging-v1-reference-snapshot.mjs";
import { readWeeklyMenuWebApp } from "../supabase/functions/atlas-weekly-menu-google-sync/webAppTransport.ts";
import { parseMenuMatrix } from "../src/modules/atlas/planning-inputs/planningInputsWorkbook.ts";
const staging = "rnzxmxiiqgtdevzregff";
const lit = (value) => `'${value.replaceAll("'", "''")}'`;
export function buildWeeklyMenuSourceSql(target, spreadsheetId) {
  if (target !== staging || !/^[A-Za-z0-9_-]{10,200}$/.test(spreadsheetId))
    throw new Error("STAGING_SOURCE_AUTHORITY_INVALID");
  return `do $source$ begin
 if to_regclass('public.schools') is not null then raise exception 'FORBIDDEN_TARGET'; end if;
 if exists(select 1 from atlas_planning.weekly_menu_google_sources where source_code='ops.weekly-menu' and
   (spreadsheet_id<>${lit(spreadsheetId)} or sheet_name_pattern<>'Tuần {DD-MM-YYYY}' or range_a1_template<>${lit("'{sheet}'!A3:I500")} or source_status<>'ACTIVE')) then
   raise exception 'SOURCE_IDENTITY_CONFLICT'; end if;
 insert into atlas_planning.weekly_menu_google_sources(source_code,source_name,spreadsheet_id,sheet_name_pattern,range_a1_template,source_status,display_order)
 values('ops.weekly-menu','Thực đơn tuần — Google Sheet',${lit(spreadsheetId)},'Tuần {DD-MM-YYYY}',${lit("'{sheet}'!A3:I500")},'ACTIVE',1)
 on conflict(source_code) do nothing;
 end $source$;
 select weekly_menu_google_source_id as source_id from atlas_planning.weekly_menu_google_sources where source_code='ops.weekly-menu';`;
}
function exactWeek(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value ?? "")) throw new Error("INVALID_WEEK");
  const date = new Date(`${value}T00:00:00Z`);
  if (
    Number.isNaN(date.valueOf()) ||
    date.toISOString().slice(0, 10) !== value ||
    date.getUTCDay() !== 1
  )
    throw new Error("INVALID_WEEK");
  return `Tuần ${value.split("-").reverse().join("-")}`;
}
export async function verifyWeeklyMenuShadow({
  environment = process.env,
  sourceId,
  weekStart,
  fetchImpl = fetch,
}) {
  if (
    environment.ATLAS_STAGING_PROJECT_REF !== staging ||
    environment.VITE_SUPABASE_URL !== `https://${staging}.supabase.co`
  )
    throw new Error("SHADOW_TARGET_INVALID");
  exactWeek(weekStart);
  const root = environment.VITE_SUPABASE_URL,
    key = environment.VITE_SUPABASE_PUBLISHABLE_KEY;
  if (
    !key ||
    !environment.ATLAS_STAGING_TEST_EMAIL ||
    !environment.ATLAS_STAGING_TEST_PASSWORD
  )
    throw new Error("SHADOW_CREDENTIAL_MISSING");
  async function call(path, body, token) {
    const response = await fetchImpl(`${root}${path}`, {
      method: "POST",
      redirect: "error",
      signal: AbortSignal.timeout(45000),
      headers: {
        apikey: key,
        "Content-Type": "application/json",
        ...(token
          ? { Authorization: `Bearer ${token}`, "Content-Profile": "atlas_api" }
          : {}),
      },
      body: JSON.stringify(body),
    });
    let json;
    try {
      json = await response.json();
    } catch {
      throw new Error("SHADOW_RESPONSE_INVALID");
    }
    if (!response.ok) throw new Error(`SHADOW_HTTP_${response.status}`);
    return json;
  }
  const session = await call("/auth/v1/token?grant_type=password", {
    email: environment.ATLAS_STAGING_TEST_EMAIL,
    password: environment.ATLAS_STAGING_TEST_PASSWORD,
  });
  if (!session.access_token || !session.user?.id)
    throw new Error("SHADOW_SIGNIN_FAILED");
  const rpc = async (name, payload) => {
    const data = await call(
      `/rest/v1/rpc/${name}`,
      {
        request: {
          contract_version: "RMVP-03A.v1",
          requested_by_auth_subject: session.user.id,
          correlation_id: crypto.randomUUID(),
          payload,
        },
      },
      session.access_token,
    );
    if (data.success !== true) throw new Error(`SHADOW_RPC_REJECTED:${name}`);
    return data;
  };
  const before = await rpc("get_planning_inputs_workbench", {
    week_start: weekStart,
  });
  const source = await call(
    "/functions/v1/atlas-weekly-menu-google-sync",
    {
      weekly_menu_google_source_id: sourceId,
      week_start: weekStart,
      correlation_id: crypto.randomUUID(),
    },
    session.access_token,
  );
  if (source.success !== true)
    throw new Error(
      `SHADOW_FETCH_REJECTED:${/^[A-Z_]+$/.test(source.error_code ?? "") ? source.error_code : "UNKNOWN"}`,
    );
  const wb = before.workbench;
  const parsed = await parseMenuMatrix(
    source.rows,
    {
      sourceName: source.source.source_name,
      sheetName: source.source.sheet_name,
      firstRowNumber: 3,
    },
    wb.dish_types,
    wb.schools,
    wb.dishes,
  );
  const preview = await rpc("preview_weekly_menu_import", {
    week_start: weekStart,
    rows: parsed.rows,
  });
  const after = await rpc("get_planning_inputs_workbench", {
    week_start: weekStart,
  });
  const same =
    JSON.stringify(wb.weekly_menu) ===
      JSON.stringify(after.workbench.weekly_menu) &&
    JSON.stringify(wb.attendance) ===
      JSON.stringify(after.workbench.attendance);
  if (!same) throw new Error("SHADOW_SOURCE_AGGREGATE_CHANGED");
  const issues = preview.preview?.issues;
  if (
    !Array.isArray(issues?.blockers) ||
    !Array.isArray(issues?.warnings) ||
    typeof preview.preview?.can_save !== "boolean"
  )
    throw new Error("SHADOW_PREVIEW_ENVELOPE_INVALID");
  const ready =
    parsed.errors.length === 0 &&
    issues.blockers.length === 0 &&
    preview.preview.can_save === true;
  return {
    status: ready
      ? "GOOGLE_WEEKLY_MENU_SHADOW_READ_PASS"
      : "GOOGLE_WEEKLY_MENU_SHADOW_READ_BLOCKED",
    week_start: weekStart,
    source_row_count: parsed.sourceRowCount,
    assignment_count: parsed.rows.length,
    resolved_school_count: new Set(
      parsed.rows
        .map((row) => row.school_id)
        .filter((id) => !id.startsWith("unresolved:")),
    ).size,
    source_signature: preview.preview?.source_signature ?? null,
    parser_errors: parsed.errors,
    parser_warnings: parsed.warnings,
    preview_blockers: issues.blockers,
    preview_warnings: issues.warnings,
    menu_unchanged: same,
    save_calls: 0,
    approve_calls: 0,
  };
}
async function main() {
  const env = process.env,
    commitSha = env.APPROVED_COMMIT_SHA,
    weekStart = env.ATLAS_SHADOW_WEEK;
  const authority = validateV1ReferenceImportRequest({ environment: env });
  verifyExactMainCheckout({ commitSha, cwd: process.cwd() });
  const sheetName = exactWeek(weekStart),
    spreadsheetId = env.ATLAS_WEEKLY_MENU_SPREADSHEET_ID;
  buildWeeklyMenuSourceSql(authority.targetProjectRef, spreadsheetId ?? "");
  const url = env.ATLAS_WEEKLY_MENU_WEBAPP_URL,
    secret = env.ATLAS_WEEKLY_MENU_WEBAPP_SECRET;
  if (
    !secret ||
    secret.length < 32 ||
    secret.length > 1024 ||
    /[\r\n]/.test(secret)
  )
    throw new Error("READER_SECRET_UNAVAILABLE");
  // Verify the actual owner-authorized read before enabling any Atlas source.
  const preflight = await readWeeklyMenuWebApp({
    url,
    secret,
    spreadsheetId,
    sheetName,
    range: `'${sheetName}'!A3:I500`,
    weekStart,
    requestId: crypto.randomUUID(),
    fetchImpl: fetch,
  });
  if (!preflight.ok)
    throw new Error(`WEBAPP_PREFLIGHT_FAILED:${preflight.code}`);
  const dir = mkdtempSync(join(tmpdir(), "atlas-webapp-secret-"));
  function cli(args) {
    const c = repositorySupabaseCliInvocation(args);
    const result = spawnSync(c.command, c.args, {
      shell: c.shell,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
      env: { ...env, SUPABASE_ACCESS_TOKEN: authority.targetAccessToken },
    });
    if (result.status !== 0)
      throw new Error(`STAGING_EDGE_${args[0].toUpperCase()}_FAILED`);
  }
  try {
    const file = join(dir, "edge.env");
    writeFileSync(
      file,
      `GOOGLE_APPS_SCRIPT_WEBAPP_URL=${url}\nGOOGLE_APPS_SCRIPT_SECRET=${secret}\n`,
      { mode: 0o600 },
    );
    cli(["secrets", "set", "--project-ref", staging, "--env-file", file]);
    cli([
      "functions",
      "deploy",
      "atlas-weekly-menu-google-sync",
      "--project-ref",
      staging,
    ]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
  const raw = await executeAtlasStagingManagementSql(
    {
      projectRef: staging,
      supabaseUrl: authority.targetSupabaseUrl,
      accessToken: authority.targetAccessToken,
    },
    buildWeeklyMenuSourceSql(staging, spreadsheetId),
  );
  const data = typeof raw === "string" ? JSON.parse(raw) : raw;
  const sourceId =
    Array.isArray(data) && data.length === 1 ? data[0].source_id : null;
  if (typeof sourceId !== "string")
    throw new Error("SOURCE_CONFIGURATION_READBACK_FAILED");
  const result = await verifyWeeklyMenuShadow({ sourceId, weekStart });
  console.log(JSON.stringify(result, null, 2));
  if (result.status !== "GOOGLE_WEEKLY_MENU_SHADOW_READ_PASS")
    process.exitCode = 2;
}
if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
)
  main().catch((error) => {
    const message =
      error instanceof Error && /^[A-Z0-9_:]+$/.test(error.message)
        ? error.message
        : "WEEKLY_MENU_DEPLOYMENT_FAILED";
    console.error(message);
    process.exitCode = 1;
  });
