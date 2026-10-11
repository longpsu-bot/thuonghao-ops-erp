// Read-only hosted acceptance: authenticated fetch, strict parser, Preview. Never Save.
import { verifyWeeklyMenuShadow } from "./deploy-atlas-weekly-menu-webapp.mjs";
import { executeAtlasStagingPostgres } from "./atlas-staging-postgres-transport.mjs";
import { parseStagingMasterResult } from "./import-atlas-staging-master-data.mjs";
import { validateV1ReferenceImportRequest } from "./atlas-staging-v1-reference-target.mjs";
import { writeFileSync } from "node:fs";
import { resolve } from "node:path";
const environment = process.env;
try {
  const authority = validateV1ReferenceImportRequest({ environment });
  const source = parseStagingMasterResult(
    await executeAtlasStagingPostgres(
      {
        projectRef: authority.targetProjectRef,
        supabaseUrl: authority.targetSupabaseUrl,
      },
      "select jsonb_build_object('source_ids',jsonb_agg(weekly_menu_google_source_id)) as result from atlas_planning.weekly_menu_google_sources where source_code='ops.weekly-menu' and source_status='ACTIVE';",
    ),
  );
  if (source.source_ids?.length !== 1)
    throw new Error("EXACT_ACTIVE_GOOGLE_SOURCE_REQUIRED");
  const result = await verifyWeeklyMenuShadow({
    environment,
    sourceId: source.source_ids[0],
    weekStart: "2026-10-12",
  });
  const diagnostics = result.parser_diagnostics ?? [];
  result.reference_issue_counts = Object.fromEntries(
    ["UNKNOWN_SCHOOL", "UNKNOWN_DISH", "AMBIGUOUS_DISH"].map((code) => [
      code,
      diagnostics.filter((d) => d.code === code).length,
    ]),
  );
  if (environment.PLANNING_PREVIEW_REPORT_DIR)
    writeFileSync(
      resolve(
        environment.PLANNING_PREVIEW_REPORT_DIR,
        "weekly-menu-read-only.json",
      ),
      JSON.stringify(result, null, 2) + "\n",
      { mode: 0o600, flag: "wx" },
    );
  const { parser_diagnostics, ...summary } = result;
  console.log(JSON.stringify(summary, null, 2));
} catch (e) {
  console.error(
    /^[A-Z_0-9:]+$/.test(e?.message ?? "")
      ? e.message
      : "WEEKLY_MENU_READ_ONLY_FAILED",
  );
  process.exitCode = 1;
}
