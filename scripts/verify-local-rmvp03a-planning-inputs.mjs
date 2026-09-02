import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import { parseMenuMatrix } from "../src/modules/atlas/planning-inputs/planningInputsWorkbook.ts";
// Node executes this verifier directly, so the Edge Function entry file must remain explicit.
// noinspection ES6PreferShortImport
import { createGoogleSyncHandler } from "../supabase/functions/atlas-weekly-menu-google-sync/index.ts";
import {
  readLocalSupabaseStatus,
  runPinnedSupabase,
} from "./local-supabase-status.mjs";

const email = "atlas.pa06b.operator@local.test";
const password = "Atlas-PA06B-local-only!";
const contractVersion = "RMVP-03A.v1";
const localGoogleSourceCode = "rmvp03a.local.synthetic";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function readRequest(subject, payload) {
  return {
    contract_version: contractVersion,
    requested_by_auth_subject: subject,
    correlation_id: crypto.randomUUID(),
    payload,
  };
}

function commandRequest(subject, expectedVersion, reasonCode, payload) {
  const commandId = crypto.randomUUID();
  return {
    contract_version: contractVersion,
    command_id: commandId,
    correlation_id: crypto.randomUUID(),
    idempotency_key: `${reasonCode.toLowerCase()}:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: subject,
    requested_at: new Date(Date.now() - 1000).toISOString(),
    reason_code: reasonCode,
    reason_note: "Bounded local RMVP-03A acceptance evidence.",
    payload,
  };
}

async function invoke(client, name, request) {
  const { data, error } = await client
    .schema("atlas_api")
    .rpc(name, { request })
    .retry(false);
  if (error) {
    throw new Error(
      `RMVP-03A ${name} transport failed safely (${error.code ?? "UNKNOWN"}: ${error.message ?? "no message"}).`,
    );
  }
  if (!data || data.success !== true) {
    throw new Error(
      `RMVP-03A ${name} was rejected: ${data?.error_code ?? "UNKNOWN"}.`,
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
    throw new Error("RMVP-03A local acceptance sign-in failed.");
  }
  return data.session.user.id;
}

function provisionSyntheticGoogleSource() {
  const sqlPath = fileURLToPath(
    new URL(
      "../supabase/local/rmvp_03a_synthetic_google_source.sql",
      import.meta.url,
    ),
  );
  runPinnedSupabase(["db", "query", "--local", "--file", sqlPath], {
    stdio: "inherit",
  });
}

async function readWorkbench(client, subject, weekStart) {
  const result = await invoke(
    client,
    "get_planning_inputs_workbench",
    readRequest(subject, { week_start: weekStart }),
  );
  assert(result.workbench, "RMVP-03A workbench envelope was absent.");
  return result.workbench;
}

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

async function findEmptyFutureMonday(client, subject) {
  const candidate = new Date();
  candidate.setUTCHours(0, 0, 0, 0);
  const daysUntilMonday = (8 - candidate.getUTCDay()) % 7;
  candidate.setUTCDate(candidate.getUTCDate() + daysUntilMonday + 7 * 1040);

  for (let offset = 0; offset < 26; offset += 1) {
    const weekStart = isoDate(candidate);
    const workbench = await readWorkbench(client, subject, weekStart);
    if (!workbench.weekly_menu && !workbench.attendance) return weekStart;
    candidate.setUTCDate(candidate.getUTCDate() + 7);
  }
  throw new Error("RMVP-03A could not find an unused explicit future week.");
}

function activeMenuRows(menu) {
  return menu.lines.filter((line) => line.line_status === "ACTIVE");
}

function activeAttendanceRows(attendance) {
  return attendance.lines.filter((line) => line.line_status === "ACTIVE");
}

async function fetchSyntheticGoogleMenu({
  apiUrl,
  browserKey,
  accessToken,
  source,
  weekStart,
  school,
  dishType,
  dish,
}) {
  const handler = createGoogleSyncHandler({
    env: {
      get(name) {
        const values = {
          SUPABASE_URL: apiUrl,
          SUPABASE_ANON_KEY: browserKey,
          GOOGLE_SERVICE_ACCOUNT_JSON:
            '{"client_email":"local-fixture@example.test","private_key":"not-used"}',
        };
        return values[name];
      },
    },
    now: () => new Date(`${weekStart}T03:00:00.000Z`),
    getGoogleAccessToken: async () => ({
      accessToken: "local-synthetic-google-token",
    }),
    fetch: async (input, init) => {
      const url = String(input);
      if (url.startsWith("https://sheets.googleapis.com/")) {
        return new Response(
          JSON.stringify({
            values: [
              ["Thứ", "Ngày", "Tên trường", dishType.dish_type_name],
              ["Thứ Hai", weekStart, school.school_name, dish.dish_name],
            ],
          }),
          { headers: { "Content-Type": "application/json" } },
        );
      }
      return fetch(input, init);
    },
  });
  const correlationId = crypto.randomUUID();
  const response = await handler(
    new Request(`${apiUrl}/functions/v1/atlas-weekly-menu-google-sync`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        weekly_menu_google_source_id: source.weekly_menu_google_source_id,
        week_start: weekStart,
        correlation_id: correlationId,
      }),
    }),
  );
  const connector = await response.json();
  assert(
    response.ok &&
      connector.success === true &&
      connector.correlation_id === correlationId,
    `RMVP-03A synthetic Google connector failed safely: ${
      connector.error_code ?? "UNKNOWN"
    }.`,
  );
  const parsed = await parseMenuMatrix(
    connector.rows,
    {
      sourceName: connector.source.source_name,
      sheetName: connector.source.sheet_name,
      firstRowNumber: 3,
    },
    [dishType],
    [school],
    [dish],
  );
  assert(
    parsed.errors.length === 0 && parsed.rows.length === 1,
    "RMVP-03A shared Google matrix parser did not produce one canonical assignment.",
  );
  return { connector, parsed };
}

async function main() {
  provisionSyntheticGoogleSource();
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
  const sessionResult = await client.auth.getSession();
  let accessToken = sessionResult.data.session?.access_token;
  assert(accessToken, "RMVP-03A local acceptance session token was absent.");
  const weekStart = await findEmptyFutureMonday(client, subject);
  const initial = await readWorkbench(client, subject, weekStart);
  const school = initial.schools.find(
    (item) => item.school_status === "ACTIVE",
  );
  const dishType = initial.dish_types.find((candidate) => {
    if (candidate.dish_type_status !== "ACTIVE") return false;
    return (
      initial.dishes.filter(
        (dish) =>
          dish.dish_status === "ACTIVE" &&
          dish.dish_type_id === candidate.dish_type_id,
      ).length >= 2
    );
  });
  const dishes = initial.dishes.filter(
    (item) =>
      item.dish_status === "ACTIVE" &&
      item.dish_type_id === dishType?.dish_type_id,
  );
  const dish = dishes[0];
  const correctionDish = dishes[1];
  const googleSource = initial.google_sheet_sources.find(
    (source) => source.source_code === localGoogleSourceCode,
  );
  assert(school, "RMVP-03A requires one active School reference.");
  assert(
    dishType,
    "RMVP-03A requires one database Dish Type with two matching active Dishes.",
  );
  assert(dish, "RMVP-03A requires one active Dish reference.");
  assert(
    correctionDish,
    "RMVP-03A requires a second active Dish for stable-line correction evidence.",
  );
  assert(
    googleSource,
    "RMVP-03A browser read did not return the configured active synthetic Google source.",
  );
  const firstGoogleFetch = await fetchSyntheticGoogleMenu({
    apiUrl,
    browserKey,
    accessToken,
    source: googleSource,
    weekStart,
    school,
    dishType,
    dish,
  });
  const afterFetch = await readWorkbench(client, subject, weekStart);
  assert(
    !afterFetch.weekly_menu,
    "RMVP-03A Google fetch wrote a Weekly Menu before preview and confirmation.",
  );

  const menuPreview = await invoke(
    client,
    "preview_weekly_menu_import",
    readRequest(subject, {
      week_start: weekStart,
      rows: firstGoogleFetch.parsed.rows,
    }),
  );
  assert(
    menuPreview.preview.can_save &&
      menuPreview.preview.source_signature &&
      menuPreview.preview.canonical_rows.length === 1,
    "RMVP-03A Weekly Menu preview was not checksum-backed and saveable.",
  );

  const menuSaveRequest = commandRequest(
    subject,
    1,
    "RMVP03A_ACCEPT_MENU_SAVE",
    {
      week_start: weekStart,
      source_type: "GOOGLE_SHEET",
      source_name: firstGoogleFetch.parsed.sourceName,
      source_signature: menuPreview.preview.source_signature,
      expected_source_signature: null,
      rows: menuPreview.preview.canonical_rows,
    },
  );
  const menuSave = await invoke(
    client,
    "save_weekly_menu_draft",
    menuSaveRequest,
  );
  const menuReplay = await invoke(
    client,
    "save_weekly_menu_draft",
    menuSaveRequest,
  );
  assert(
    menuReplay.idempotency_status === "COMPLETED" &&
      menuReplay.command_id === menuSave.command_id &&
      menuReplay.affected_aggregate_ids.weekly_menu_id ===
        menuSave.affected_aggregate_ids.weekly_menu_id,
    "RMVP-03A exact Weekly Menu command replay did not return the original durable receipt.",
  );
  const initialMenu = menuSave.authoritative_readback.weekly_menu;
  const initialMenuLine = activeMenuRows(initialMenu)[0];
  assert(
    initialMenu.weekly_menu_status === "DRAFT" &&
      initialMenuLine?.weekly_menu_line_id,
    "RMVP-03A Weekly Menu draft did not return stable assignment identity.",
  );

  const menuNoChange = await invoke(
    client,
    "save_weekly_menu_draft",
    commandRequest(subject, 1, "RMVP03A_ACCEPT_MENU_NO_CHANGE", {
      week_start: weekStart,
      source_type: initialMenu.source_type,
      source_name: initialMenu.source_name,
      source_signature: initialMenu.source_signature,
      expected_source_signature: initialMenu.source_signature,
      rows: activeMenuRows(initialMenu),
    }),
  );
  assert(
    menuNoChange.idempotency_status === "NO_CHANGE",
    "RMVP-03A canonical Weekly Menu replacement was not a no-write success.",
  );

  const refreshedMenuDraft = await readWorkbench(client, subject, weekStart);
  const refreshedMenuLine = activeMenuRows(refreshedMenuDraft.weekly_menu)[0];
  assert(
    refreshedMenuDraft.weekly_menu.weekly_menu_status === "DRAFT" &&
      refreshedMenuLine.weekly_menu_line_id ===
        initialMenuLine.weekly_menu_line_id,
    "RMVP-03A authoritative refresh did not preserve the imported stable Menu line.",
  );
  const firstMenuCorrectionPreview = await invoke(
    client,
    "preview_weekly_menu_import",
    readRequest(subject, {
      week_start: weekStart,
      rows: activeMenuRows(refreshedMenuDraft.weekly_menu).map((line) => ({
        ...line,
        dish_id: correctionDish.dish_id,
        source_row_reference: "acceptance-menu-review-correction:2",
      })),
    }),
  );
  const reviewedMenu = await invoke(
    client,
    "save_weekly_menu_draft",
    commandRequest(subject, 1, "RMVP03A_ACCEPT_MENU_REVIEW_CORRECTION", {
      week_start: weekStart,
      source_type: "MANUAL_CORRECTION",
      source_name: "RMVP-03A reviewed Menu draft",
      source_signature: firstMenuCorrectionPreview.preview.source_signature,
      expected_source_signature:
        refreshedMenuDraft.weekly_menu.source_signature,
      rows: firstMenuCorrectionPreview.preview.canonical_rows,
    }),
  );
  const reviewedMenuLine = activeMenuRows(
    reviewedMenu.authoritative_readback.weekly_menu,
  )[0];
  assert(
    reviewedMenuLine.weekly_menu_line_id ===
      initialMenuLine.weekly_menu_line_id &&
      reviewedMenuLine.dish_id === correctionDish.dish_id,
    "RMVP-03A pre-validation Menu correction did not reuse the imported stable line.",
  );

  await invoke(
    client,
    "validate_weekly_menu",
    commandRequest(subject, 1, "RMVP03A_ACCEPT_MENU_VALIDATE", {
      week_start: weekStart,
    }),
  );
  const firstMenuApproval = await invoke(
    client,
    "approve_weekly_menu",
    commandRequest(subject, 1, "RMVP03A_ACCEPT_MENU_APPROVE", {
      week_start: weekStart,
    }),
  );
  const firstMenuSnapshot =
    firstMenuApproval.authoritative_readback.weekly_menu
      .latest_approval_snapshot_id;
  assert(
    firstMenuSnapshot,
    "RMVP-03A Weekly Menu approval did not create an exact snapshot.",
  );

  const beforeAttendance = await readWorkbench(client, subject, weekStart);
  const attendancePreview = await invoke(
    client,
    "preview_attendance_import",
    readRequest(subject, {
      week_start: weekStart,
      rows: beforeAttendance.default_attendance_preview,
    }),
  );
  assert(
    attendancePreview.preview.can_save &&
      attendancePreview.preview.canonical_rows.length === 1,
    "RMVP-03A menu-aware Attendance defaults did not produce one saveable school/date row.",
  );
  const defaultAttendance = await invoke(
    client,
    "create_attendance_draft_from_defaults",
    commandRequest(subject, 1, "RMVP03A_ACCEPT_ATTENDANCE_DEFAULTS", {
      week_start: weekStart,
      source_signature: attendancePreview.preview.source_signature,
      expected_source_signature: null,
    }),
  );
  const defaultBatch = defaultAttendance.authoritative_readback.attendance;
  const defaultLine = activeAttendanceRows(defaultBatch)[0];
  assert(
    defaultLine?.attendance_line_id,
    "RMVP-03A Attendance defaults did not return stable row identity.",
  );

  const zeroPreview = await invoke(
    client,
    "preview_attendance_import",
    readRequest(subject, {
      week_start: weekStart,
      rows: [
        {
          school_id: defaultLine.school_id,
          service_date: defaultLine.service_date,
          student_portions: 0,
          teacher_portions: 0,
          source_row_reference: "acceptance-attendance:2",
        },
      ],
    }),
  );
  assert(
    zeroPreview.preview.can_save &&
      zeroPreview.preview.canonical_rows[0].student_portions === 0 &&
      zeroPreview.preview.canonical_rows[0].teacher_portions === 0,
    "RMVP-03A explicit zero Attendance was not preserved as legitimate input.",
  );
  const zeroAttendance = await invoke(
    client,
    "save_attendance_draft",
    commandRequest(subject, 1, "RMVP03A_ACCEPT_ATTENDANCE_ZERO", {
      week_start: weekStart,
      source_type: "BULK_PASTE",
      source_name: "RMVP-03A explicit zero acceptance",
      source_signature: zeroPreview.preview.source_signature,
      expected_source_signature: defaultBatch.source_signature,
      rows: zeroPreview.preview.canonical_rows,
    }),
  );
  assert(
    activeAttendanceRows(zeroAttendance.authoritative_readback.attendance)[0]
      .attendance_line_id === defaultLine.attendance_line_id,
    "RMVP-03A Attendance correction changed stable row identity.",
  );

  await invoke(
    client,
    "validate_attendance",
    commandRequest(subject, 1, "RMVP03A_ACCEPT_ATTENDANCE_VALIDATE", {
      week_start: weekStart,
    }),
  );
  const attendanceApproval = await invoke(
    client,
    "approve_attendance",
    commandRequest(subject, 1, "RMVP03A_ACCEPT_ATTENDANCE_APPROVE", {
      week_start: weekStart,
    }),
  );
  const firstAttendanceSnapshot =
    attendanceApproval.authoritative_readback.attendance
      .latest_approval_snapshot_id;
  const firstApprovedReadback = attendanceApproval.authoritative_readback;
  assert(
    firstApprovedReadback.attendance.attendance_status === "APPROVED" &&
      firstAttendanceSnapshot &&
      firstApprovedReadback.readiness.ready === true,
    "RMVP-03A readiness did not become true after both exact approvals.",
  );

  const signOut = await client.auth.signOut({ scope: "local" });
  if (signOut.error) throw new Error("RMVP-03A local sign-out failed.");
  const signedInAgainSubject = await signIn(client);
  accessToken = (await client.auth.getSession()).data.session?.access_token;
  assert(
    signedInAgainSubject === subject,
    "RMVP-03A sign-in restored a different subject.",
  );
  assert(accessToken, "RMVP-03A reauthenticated session token was absent.");
  const persisted = await readWorkbench(client, subject, weekStart);
  assert(
    persisted.readiness.ready === true &&
      persisted.weekly_menu.approval_history.length === 1 &&
      activeAttendanceRows(persisted.attendance)[0].student_portions === 0,
    "RMVP-03A authoritative approvals, history, or explicit zero did not persist across reauthentication.",
  );

  const reopenedMenu = await invoke(
    client,
    "reopen_weekly_menu",
    commandRequest(subject, 1, "RMVP03A_ACCEPT_MENU_REOPEN", {
      week_start: weekStart,
    }),
  );
  const reopenedMenuState = reopenedMenu.authoritative_readback.weekly_menu;
  assert(
    reopenedMenuState.weekly_menu_status === "REOPENED" &&
      reopenedMenuState.version === 2 &&
      reopenedMenuState.latest_approval_snapshot_id === firstMenuSnapshot,
    "RMVP-03A Weekly Menu reopen did not preserve approval history and advance version.",
  );
  const correctedMenuPreview = await invoke(
    client,
    "preview_weekly_menu_import",
    readRequest(subject, {
      week_start: weekStart,
      rows: (
        await fetchSyntheticGoogleMenu({
          apiUrl,
          browserKey,
          accessToken,
          source: googleSource,
          weekStart,
          school,
          dishType,
          dish,
        })
      ).parsed.rows,
    }),
  );
  const resavedMenu = await invoke(
    client,
    "save_weekly_menu_draft",
    commandRequest(subject, 2, "RMVP03A_ACCEPT_MENU_RESAVE", {
      week_start: weekStart,
      source_type: "GOOGLE_SHEET",
      source_name: "RMVP-03A corrected synthetic Google fixture",
      source_signature: correctedMenuPreview.preview.source_signature,
      expected_source_signature: reopenedMenuState.source_signature,
      rows: correctedMenuPreview.preview.canonical_rows,
    }),
  );
  const correctedMenuLine = activeMenuRows(
    resavedMenu.authoritative_readback.weekly_menu,
  )[0];
  assert(
    correctedMenuLine.weekly_menu_line_id ===
      initialMenuLine.weekly_menu_line_id &&
      correctedMenuLine.dish_id === dish.dish_id,
    "RMVP-03A Weekly Menu correction did not preserve stable assignment identity.",
  );
  await invoke(
    client,
    "validate_weekly_menu",
    commandRequest(subject, 2, "RMVP03A_ACCEPT_MENU_REVALIDATE", {
      week_start: weekStart,
    }),
  );
  const secondMenuApproval = await invoke(
    client,
    "approve_weekly_menu",
    commandRequest(subject, 2, "RMVP03A_ACCEPT_MENU_REAPPROVE", {
      week_start: weekStart,
    }),
  );
  const approvedMenu = secondMenuApproval.authoritative_readback.weekly_menu;
  assert(
    approvedMenu.weekly_menu_status === "APPROVED" &&
      approvedMenu.approval_history.length === 2 &&
      approvedMenu.approval_history.some(
        (entry) => entry.approval_snapshot_id === firstMenuSnapshot,
      ) &&
      approvedMenu.latest_approval_snapshot_id !== firstMenuSnapshot,
    "RMVP-03A Weekly Menu reapproval did not preserve the prior exact snapshot.",
  );

  const reopenedAttendance = await invoke(
    client,
    "reopen_attendance",
    commandRequest(subject, 1, "RMVP03A_ACCEPT_ATTENDANCE_REOPEN", {
      week_start: weekStart,
    }),
  );
  const reopenedAttendanceState =
    reopenedAttendance.authoritative_readback.attendance;
  assert(
    reopenedAttendanceState.attendance_status === "REOPENED" &&
      reopenedAttendanceState.version === 2 &&
      reopenedAttendanceState.latest_approval_snapshot_id ===
        firstAttendanceSnapshot,
    "RMVP-03A Attendance reopen did not preserve approval history and advance version.",
  );
  const correctedAttendancePreview = await invoke(
    client,
    "preview_attendance_import",
    readRequest(subject, {
      week_start: weekStart,
      rows: activeAttendanceRows(reopenedAttendanceState).map((line) => ({
        ...line,
        student_portions: 1,
        teacher_portions: 0,
        source_row_reference: "acceptance-attendance-correction:2",
      })),
    }),
  );
  const resavedAttendance = await invoke(
    client,
    "save_attendance_draft",
    commandRequest(subject, 2, "RMVP03A_ACCEPT_ATTENDANCE_RESAVE", {
      week_start: weekStart,
      source_type: "MANUAL_CORRECTION",
      source_name: "RMVP-03A stable Attendance correction",
      source_signature: correctedAttendancePreview.preview.source_signature,
      expected_source_signature: reopenedAttendanceState.source_signature,
      rows: correctedAttendancePreview.preview.canonical_rows,
    }),
  );
  const correctedAttendanceLine = activeAttendanceRows(
    resavedAttendance.authoritative_readback.attendance,
  )[0];
  assert(
    correctedAttendanceLine.attendance_line_id ===
      defaultLine.attendance_line_id &&
      correctedAttendanceLine.student_portions === 1,
    "RMVP-03A Attendance correction did not preserve stable row identity.",
  );
  await invoke(
    client,
    "validate_attendance",
    commandRequest(subject, 2, "RMVP03A_ACCEPT_ATTENDANCE_REVALIDATE", {
      week_start: weekStart,
    }),
  );
  const secondAttendanceApproval = await invoke(
    client,
    "approve_attendance",
    commandRequest(subject, 2, "RMVP03A_ACCEPT_ATTENDANCE_REAPPROVE", {
      week_start: weekStart,
    }),
  );
  const finalReadback = secondAttendanceApproval.authoritative_readback;
  assert(
    finalReadback.readiness.ready === true &&
      finalReadback.attendance.approval_history.length === 2 &&
      finalReadback.attendance.approval_history.some(
        (entry) => entry.approval_snapshot_id === firstAttendanceSnapshot,
      ) &&
      finalReadback.attendance.latest_approval_snapshot_id !==
        firstAttendanceSnapshot,
    "RMVP-03A Attendance reapproval did not preserve the prior exact snapshot or readiness.",
  );
  await client.auth.signOut({ scope: "local" });
  console.log(
    `Verified RMVP-03A browser-key configured Google fetch/shared parse/preview/confirmed save plus Menu and Attendance lifecycle, dynamic Dish Type ${dishType.dish_type_code}, stable lines, snapshots, replay/no-change, explicit zero, reauthentication, and readiness for ${weekStart}.`,
  );
}

try {
  await main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "RMVP-03A local acceptance failed safely.",
  );
  process.exitCode = 1;
}
