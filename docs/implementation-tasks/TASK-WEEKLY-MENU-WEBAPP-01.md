# WEEKLY-MENU-WEBAPP-01

Owner approved 16/09/2026: reuse the existing Apps Script Web App for explicit Atlas Weekly Menu fetch. Baseline `a6fcbda5ef799f16c285f904637d4036faa683e9`. The live Apps Script HEAD was fetched with the existing authorized clasp login; seven source files match the supplied project. Existing v1 Retool and school/dish webhook behavior is evidence and must remain unchanged.

## Approved boundaries

- Google Sheet is the sole menu-authoring source. No Weekly Menu XLSX UI is added.
- Preserve the Atlas browser request, authenticated user + Planning capability checks, configured source authority, matrix response, existing parser/backend preview and explicit Save boundary.
- Replace service-account OAuth with one server-side Apps Script Web App endpoint and shared secret. No fallback to OAuth and no credentials/endpoint in the browser.
- Apps Script accepts only `atlas_weekly_menu_read`, protocol version, Monday week, request ID and a body secret. It never accepts a caller-selected spreadsheet, tab, URL or range. The server-side spreadsheet ID, `Tuần DD-MM-YYYY`, and `A3:I500` remain fixed. Serialize Date cells using the spreadsheet timezone to ISO calendar dates.
- Route the new read action before the legacy generic dish-sync fallback. Invalid Atlas requests must never update Lists. Existing school/dish code remains byte-equivalent after the one guarded router insertion.
- Fail closed if configuration/secret is absent. Use `ATLAS_WEEKLY_MENU_SECRET` where configured; otherwise explicit reuse of existing `SYNC_SECRET` is supported. Secret is sent in HTTPS JSON body, never a URL, response, log or client bundle.
- Handle Google's ContentService redirect manually: only HTTPS `script.googleusercontent.com`, GET without forwarding secret/token/body; refuse authentication redirects, 307/308, foreign origins, loops, oversized payloads, wrong source/week/request correlation, malformed matrices and truncation.
- Preserve the current Web App execute-as/access settings and URL. Do not replace the project wholesale with the uploaded archive. Verify current remote content and merge only the read module/router with private rollback backups.
- Staging only: configure one source, install server secrets without output, deploy JWT-verified Edge Function, run actual read/parser/backend preview for 21/09/2026. No menu Save/Approve, downstream operations, v1 business writes or PR #286 changes.

## Tasks and gates

1. Existing handler baseline tests, source/deployment inspection and exact workspace preflight.
2. RED/GREEN Web App protocol, legacy dispatcher isolation and secure transport tests; adapt inherited handler and local integration tests without weakening their authorization assertions.
3. Update current architecture/API docs for the approved transport amendment; no schema migration or new domain objects.
4. Push a bounded PR and verify required CI. Keep deployment status distinct from implementation status.
5. Deploy only if authorized credentials and exact current deployment identity can be established. Do not invent a secret, extract browser sessions, or expose secret material to the conversation. If secret installation or Apps Script authorization is unavailable, finish the tested code/package and report the precise remaining setup.
6. Live acceptance requires actual source identity, all current-week rows accounted for, parser/preview result and unchanged Weekly Menu counts. A mocked test is not a hosted PASS.

## References

- OPS_SYSTEM_MAP v1.0 / ARCH-002: facts explicit, state derived, supporting objects generated.
- `docs/architecture/rmvp-03a-connected-weekly-menu-attendance.md`
- Google Web Apps request/execute-as documentation and ContentService redirect specification.
- No synthetic setup, test call or generic doPost probe may invoke v1's legacy write handlers on the live deployment.

## Deployment credential refinement

The existing clasp authorization can fetch/update project source but cannot execute editor functions via `scripts.run`. To avoid asking the owner for manual Script Property setup or exporting the legacy write secret, the automated path generates a separate random 256-bit reader secret privately. Only its SHA-256 digest and the already approved spreadsheet identity go in an instance-local `atlasWeeklyMenuDeploymentConfig_()` module. This is deployment configuration, never browser code or a raw credential. Atlas's matching raw secret goes directly into the protected GitHub Environment via stdin, then into Supabase Edge secrets in the protected workflow. The legacy `SYNC_SECRET` property is neither read out nor modified. A malformed/incorrect dedicated digest cannot fall back to the legacy credential. Manual Script Property configuration remains a supported non-automated alternative, not an extra step required by this rollout.

## 17/09/2026 resumption and manual delivery

The owner requested completion of the local fix and a manual installation package. No Apps Script source/deployment or Sheet cell is changed by this resumption. The verifier regression was reproduced (nested backend issue envelope), corrected, and extended to reject malformed issue envelopes and contradictory saveability. Dedicated installer tests cover private stdin transport, digest-only config, existing-installation refusal and auth-before-write behavior. Package setup never prints a secret or changes the v1 credential. The normal GitHub workflow is ready to perform the Atlas-side deployment and read/preview after manual Web App installation and current-main certification. Hosted PASS must not be claimed before that actual run.

### Local certification before push

- Original handler baseline: 10/10 passed before transport replacement.
- Apps Script/transport RED: missing modules and 16 expected failed script cases, then 36/36 GREEN.
- Existing handler amended-transport RED: 3 failures, then 10/10 GREEN with authorization assertions retained.
- Dedicated digest RED: 2 expected failures, then 18/18 Apps Script tests GREEN.
- Verifier nested-envelope RED reproduced on resumption; malformed-envelope and contradictory-blocker tests added RED, then GREEN.
- Installer RED: missing module; GREEN covers digest-only config, private stdin, existing-secret refusal and failure before secret generation.
- Final affected regression: **173/173 PASS across seven files**, including 103 unchanged Staging authority checks and six current typed parser tests.
- Typecheck including Chakra type generation PASS; real Node direct-import smoke PASS; changed-file Prettier and git diff whitespace checks PASS.
- The fresh source audit used the supplied Retool `js_menu_syncWeek.js`, Apps Script legacy handlers, and ARCH-002. No source-derived facts were replaced with guessed values.
- No hosted source record, Edge deployment, Apps Script change, source-data write, or menu Save/Approve has occurred. Manual package preparation is separate from installation. Required GitHub full certification is recorded in the PR after push.
