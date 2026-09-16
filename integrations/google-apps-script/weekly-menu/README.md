# Atlas Weekly Menu Web App reader

This is a narrow extension to the owner's existing Apps Script project, not a replacement project. Google Sheet remains the sole authoring source. The endpoint returns source evidence only. Atlas performs its existing parser → backend Preview → explicit Save flow; fetch never saves.

## Install without disturbing OPS v1

Pull the current Apps Script project using its existing authorized `clasp` login. Keep a private pre-change backup and deployment-version record. Add `AtlasWeeklyMenuReader.js`. At the very beginning of the **existing** `doPost(e)`, before legacy secret checking or generic dish-sync fallback, insert:

```js
const atlasRead = maybeHandleAtlasWeeklyMenuRead_(e);
if (atlasRead !== null) return atlasRead;
```

Do not replace the remaining `doPost` body, school handler, dish list writer, week-creation code, exports, manifest, triggers, or v1 Script Properties. `fixtures/` contains narrow legacy handler snapshots (trailing whitespace normalized only) solely for regression testing; **do not push fixtures to Apps Script**.

The preferred automated deployment generates an instance-local file defining:

```js
function atlasWeeklyMenuDeploymentConfig_() {
  return {
    spreadsheetId: "OWNER_APPROVED_ID",
    secretSha256: "SHA256_OF_RANDOM_256_BIT_READER_SECRET",
  };
}
```

Only the digest and non-secret source identity go in that file. The random secret remains private and is installed into the protected GitHub `atlas-staging` Environment as `ATLAS_WEEKLY_MENU_WEBAPP_SECRET`. The approved `/exec` URL is stored as `ATLAS_WEEKLY_MENU_WEBAPP_URL`. Never commit either credential, put it in a query string, return it, or forward it with Google's redirect. This configuration takes precedence over the old secret and cannot authorize v1 writes.

The alternative manual configuration uses Script Properties `ATLAS_WEEKLY_MENU_SPREADSHEET_ID` and `ATLAS_WEEKLY_MENU_SECRET` (or explicit reuse of `SYNC_SECRET`). `initializeAtlasWeeklyMenuReader` can set the non-secret workbook ID when run from the bound spreadsheet editor. It must not be invoked through a Web App or Apps Script API because bound active-document methods are not available there.

Create a new immutable script version and update the selected existing Web App deployment to it, preserving its URL, execute-as-owner and access settings. A default `clasp deploy` that creates a different URL is not the intended operation. Rollback repoints that same deployment to the recorded prior version; it does not reset any spreadsheet or database.

## Protocol

POST JSON: exact event `atlas_weekly_menu_read`, `contract_version=ATLAS-WEEKLY-MENU-READ.v1`, ISO Monday `week_start`, UUID `request_id`, and `secret`. Caller URLs, Sheet IDs, tab names, ranges, query-string credentials, and unrelated fields are rejected.

Response: `success`, matching protocol/request/week, actual `spreadsheet_id`, `sheet_name`, fixed `range`, and `rows`. The server chooses `Tuần DD-MM-YYYY!A3:I500`. Date cells are converted using the **spreadsheet timezone**, not the server's timezone. No rows are written or silently truncated. The deployment rejects a worksheet with content beyond row 500; expand the reviewed contract instead of dropping that tail.

Google ContentService serves JSON via a one-time HTTPS `script.googleusercontent.com/macros/echo` redirect. The Edge adapter follows only that allowed redirect as a fresh GET with no credential/JWT/body. Authentication redirects, POST-preserving redirects, loops, malformed responses, wrong source/week/request, oversized UTF-8 responses and timeouts fail closed.

## Atlas Staging enablement

Manual GitHub workflow: **Atlas Weekly Menu Web App Shadow**. Inputs: exact certified current-main SHA, owner-approved spreadsheet ID and Monday week. The workflow keeps secrets in the protected environment, preflights the actual Web App, installs its two Edge secrets, deploys the JWT-verified reader, configures the existing private source table without changing another identity, and exercises authenticated fetch/parser/backend Preview. It never invokes a Menu Save/Approve or a downstream command.

An unconfigured or failing source is not replaced with a successful empty menu. Full hosted PASS requires the workflow and independent unchanged-Menu readback. Local mocks prove code behavior, not deployed credentials or Sheet access.

## Official platform references

- https://developers.google.com/apps-script/guides/web
- https://developers.google.com/apps-script/guides/content#redirects
- https://developers.google.com/apps-script/guides/bound#special_methods
- https://developers.google.com/apps-script/api/reference/rest/v1/projects.deployments/update
