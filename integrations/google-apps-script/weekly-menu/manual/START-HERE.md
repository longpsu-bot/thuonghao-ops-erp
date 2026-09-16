# Atlas Weekly Menu — manual installation

This package extends the existing Google Sheet Web App. It does **not** create another spreadsheet, require a Google service account, replace the v1 handlers, or save any Atlas Weekly Menu.

**Workbook:** `1kSNc69C-Fe7QYjmbwYiCL6Kf01r2dsvonRIC7qn2urI`

**Atlas target:** Staging only (`rnzxmxiiqgtdevzregff`)

**First shadow week:** Monday **21/09/2026** (`2026-09-21`)

## What you need to do

### 1. Prepare the private reader credential

Extract the ZIP into a normal folder outside the Git repository. Your computer already has Node.js and GitHub CLI. In that folder, open PowerShell and run:

```powershell
node .\Prepare-Install.mjs
```

The program asks for the **existing Weekly Menu Web App URL ending `/exec`**. Get it from the Sheet → Extensions → Apps Script → Deploy → Manage deployments. Choose the deployment currently used by the v1 Supabase webhook. There were two versioned deployments in the inspected project; do not guess or create a third URL. The matching existing URL is the value already used as `GAS_WEBAPP_URL` in v1.

The program creates a fresh, dedicated random reader credential and stores it directly in the repository's protected `atlas-staging` GitHub Environment. It stores the Web App URL there too. It prints **no secret**, changes **no v1 secret**, makes **no Sheet edit**, and creates a local `AtlasWeeklyMenuConfig.gs` containing only the digest and workbook identity.

If GitHub CLI needs sign-in, run `gh auth login` and retry. If it reports `READER_SECRET_ALREADY_EXISTS` or `OUTPUT_EXISTS`, stop: the first setup may already have completed. Do not delete/rotate a working credential just to rerun installation. Keep the generated config together with this package.

### 2. Add two files and two lines in the existing Apps Script project

Before editing, save a private copy of the current `Dishes Syncing` code and record the current deployed version. Do not delete any existing file.

In the Apps Script editor opened from the **existing Weekly Menu Sheet**:

1. Add a script file named **AtlasWeeklyMenuReader**. Paste all code from `AppsScript/AtlasWeeklyMenuReader.gs`.
2. Add a script file named **AtlasWeeklyMenuConfig**. Paste all code from the locally generated `AtlasWeeklyMenuConfig.gs`.
3. Find the existing `function doPost(e) {` in **Dishes Syncing**. Immediately after that opening line, insert:

```javascript
const atlasRead = maybeHandleAtlasWeeklyMenuRead_(e);
if (atlasRead !== null) return atlasRead;
```

Keep everything else inside the existing `doPost` unchanged. The new lines must be **before** its old `try`, `SYNC_SECRET` check, school-sync routing and generic dish-sync fallback. `AppsScript/DOPOST-INSERT.txt` shows the placement.

There must remain **exactly one** `doPost` function in the project. Do not paste the example as a second function. No change is needed in `Control`, `Menu`, `ExportMenu`, `AutoHidePastweeks`, `school_validation_sync`, the manifest, existing Script Properties, or triggers. Do not run `initializeAtlasWeeklyMenuReader`; the generated config already supplies the source identity and reader credential digest.

### 3. Update that same Web App deployment

Save the files. In **Deploy → Manage deployments**, select the same deployed Web App URL you used in Step 1, click Edit, choose **New version**, then Deploy. Preserve **Execute as: Me / the owner** and the existing access setting. A server-to-server call must reach the deployed script without an interactive Google login; the script itself requires its reader credential. If the existing setting is restricted to signed-in Google users, stop and report that rather than changing sharing or access blindly.

Approve Google's consent screen only if requested by your own existing script project. **Do not use New deployment** for this normal upgrade, and do not change the URL in Retool or v1. A `/dev` test URL is not the deployed `/exec` URL.

Then tell the implementer: **“Web App updated; existing deployment URL unchanged.”** The URL is not the secret. Do not send a credential or JSON private key in chat.

## What is already implemented on the Atlas side

The repository contains a protected GitHub Action named **Atlas Weekly Menu Web App Shadow**. After the implementation is merged and certified, the implementer can run it using:

| Input            | Value                                             |
| ---------------- | ------------------------------------------------- |
| Branch           | `main`                                            |
| `commit_sha`     | Exact certified current `main` SHA, not a PR head |
| `spreadsheet_id` | `1kSNc69C-Fe7QYjmbwYiCL6Kf01r2dsvonRIC7qn2urI`    |
| `week_start`     | `2026-09-21`                                      |

That job checks the actual Web App, installs the Edge secrets, deploys the Atlas reader, configures the existing source table, signs in through the existing Staging test account, fetches the Sheet, runs the real parser and backend Preview, and checks that the Weekly Menu/Attendance facts did not change.

A successful **read** can still produce **source blockers**. They are now read from the correct `preview.issues.blockers` envelope and reported rather than hidden. No Save, Approve, Need Generation, PO, PXK or supplier-send command is part of this job.

## Expected result

`GOOGLE_WEEKLY_MENU_SHADOW_READ_PASS` means the real fetch, parser and saveability preview passed for the chosen week. `GOOGLE_WEEKLY_MENU_SHADOW_READ_BLOCKED` means the transport ran but the source needs specific corrections. Neither status means a Weekly Menu was saved.

The uploaded workbook previously contained 40 Schools × five days for 21/09/2026. The live Sheet may change; compare against its actual current rows, not this historical count alone.

## Official platform guidance

Google documents Web App execution identity, `doPost` and `/exec` vs `/dev` at https://developers.google.com/apps-script/guides/web . JSON ContentService replies redirect to `script.googleusercontent.com`; the Atlas reader follows only that controlled response redirect without forwarding credentials: https://developers.google.com/apps-script/guides/content . Versioned deployment updates preserve the deployment identity: https://developers.google.com/apps-script/concepts/deployments .
