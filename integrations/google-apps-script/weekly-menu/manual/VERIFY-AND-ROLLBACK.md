# Verification and rollback

## Installation checks

- One existing spreadsheet; no duplicate authoring workbook.
- Exactly one `doPost` with the new two-line router before the legacy body.
- Reader and generated configuration names match the supplied files.
- Only a SHA-256 reader digest is in the generated config; the raw reader credential is held in GitHub/Edge server secrets.
- Same deployed `/exec` URL; new immutable script version selected.
- Same execute-as and access settings. No public Sheet sharing change.
- Existing v1 `SYNC_SECRET`, Supabase URL/key, triggers and Lists routines are untouched.
- Do not click the old validation-sync functions merely as a diagnostic: they perform real v1/Sheet operations.

## Safe checks to delegate

The protected GitHub workflow uses the real Atlas session/capabilities and only reads the selected menu source, runs the backend preview, and compares persisted Menu/Attendance before/after. It installs integration configuration but does not persist menu business facts. Review the reported source-row and assignment counts separately: a School/day can have multiple Dish Type assignments.

## Typical errors

| Error                                | What to check                                                                                        |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| `GITHUB_AUTH_REQUIRED`               | GitHub CLI sign-in and access to `longpsu-bot/thuonghao-ops-erp`.                                    |
| `GITHUB_ENVIRONMENT_ACCESS_REQUIRED` | Permission to manage secrets in existing `atlas-staging`; do not create an unrelated environment.    |
| `OUTPUT_EXISTS`                      | Keep the generated config; do not rerun setup or rotate credentials blindly.                         |
| `READER_SECRET_ALREADY_EXISTS`       | Reconcile the existing installation; GitHub cannot reveal the plaintext secret.                      |
| `WEBAPP_URL_INVALID`                 | Must be the existing HTTPS `script.google.com/macros/s/.../exec` URL, without query string.          |
| `GOOGLE_AUTH_FAILED`                 | Digest/secret mismatch, wrong deployment, or old deployed code.                                      |
| `GOOGLE_WEBAPP_REDIRECT_REJECTED`    | Wrong URL or Web App requiring interactive Google login; do not publish the Sheet as a workaround.   |
| `WEEKLY_SHEET_MISSING`               | Selected ISO Monday must correspond to `Tuần DD-MM-YYYY`.                                            |
| `RESPONSE_SIZE_LIMIT`                | Sheet has content beyond row 500 or exceeds safe size; no rows are silently dropped.                 |
| `SHADOW_PREVIEW_ENVELOPE_INVALID`    | Actual backend response differs from the expected contract; stop rather than assuming zero blockers. |

## Rollback

1. In Apps Script → Deploy → Manage deployments, edit the **same** deployment and select the previously recorded version. This restores old deployed behavior without changing the URL.
2. Restore the previously saved editor code or remove only the two inserted router lines and the two new Atlas files. Do not delete or alter old v1 files.
3. Ask the implementer to inactivate only the `ops.weekly-menu` Staging source if it was configured, and to remove/restore only the new Atlas reader Edge deployment and its reader-specific secrets. Do not touch v1 `SYNC_SECRET` or other environment secrets.
4. Never delete Weekly Menus, Attendance, master mappings, Recipes, POs or PXKs as part of this transport rollback. Do not reset either Supabase project.

If preparation succeeded but Google installation has not happened, simply retain the generated config and finish installation later. No source read or business change occurs from preparing the credential alone.
