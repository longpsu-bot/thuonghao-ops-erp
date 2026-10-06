# Atlas Product Corrections 01 — integrated certification

This record covers the owner-authorized change from main
`dd00f304e43de77b59288e32109db6fd8884c5f7` on
`feat/atlas-product-corrections-01`. It is local certification for draft PR review;
final-head GitHub validation and product/architecture review remain delivery gates.
No hosted migration, Retool, OPS v1, live business write or manual deployment is
part of this work. Existing branch-preview automation, if reported by the PR,
must be disclosed in delivery.

## Evidence and limits

Artifacts live in
[`docs/testing/artifacts/atlas-product-corrections-01`](../testing/artifacts/atlas-product-corrections-01/).
The earlier [#351 evidence](atlas-persistent-workspace-03c-evidence.md) and its
seven-owner timings are historical and are not overwritten.

Browser runs use the real application, production workbenches and opt-in local
snapshot APIs at `atlas-vnext-review.html`. They establish browser behavior, not
hosted database outcomes. The invalid-cell, missing-Unit and pending valid Preview
scenarios are explicit review-entry snapshots. Normal valid sync is also tested
through its immediate Save/readback path. No fixture implements new business
calculations or enters the production entrypoint.

The Recipe implementation checkpoint passed 225 frontend tests and 232 pgTAP
assertions across six suites in the isolated `atlas-recipe-corrections-pg`
container. Raw logs for all six suites are retained here (32 + 42 + 59 + 15 +
57 + 27 = 232); five were copied from that isolated container's saved `/tmp`
logs without executing SQL again. Unchanged SQL was not rerun
for this documentation/browser checkpoint. No existing Supabase container was
reset or modified.

## Forty requested regressions

Test names below refer to the committed suites. Integrated full-test output and
browser JSON provide final-source frontend evidence. SQL entries explicitly name
the earlier unchanged local backend certification.

| #   | Requirement                             | Actual evidence                                                                                                                                                                                                                  |
| --- | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Recipe discard instability              | `RecipeCapability`: `clears metadata status only after approved discard completes`; browser natural CSS exit under normal and reduced motion. Baseline was 23 passing/1 failing in jsdom; real Chromium already passed.          |
| 2   | Ingredient determines Unit              | `DishRecipeWorkbench`: `adds the Ingredient purchase Unit instead of the first active Unit and saves exact readback`; `recipe-editor-unit-*` captures.                                                                           |
| 3   | No independent Unit selection           | Same component assertion and browser row has no combobox; Unit remains readable.                                                                                                                                                 |
| 4   | No unrelated first Unit                 | Same regression uses a distinct `Lít` purchase Unit while another active Unit is first.                                                                                                                                          |
| 5   | Missing Unit blocks Save                | `blocks saving an added Ingredient with missing purchase Unit`; `missingRecipeUnit-*` captures and disabled Review assertion.                                                                                                    |
| 6   | Inactive Unit blocks Save               | `blocks saving an added Ingredient with inactive purchase Unit`; draft model rejection and earlier SQL command rejection.                                                                                                        |
| 7   | Backend rejects mismatch                | Earlier `ui_quality_03a_recipe_workflow.sql`: actual `save_recipe` mismatch and missing-purchase-Unit command rejection, root/version and immutable-line atomicity assertions.                                                   |
| 8   | Historical Unit retained                | `preserves a historical stored Unit and blocks mismatched normal authoring`; earlier Recipe effective/import SQL suites and 03A unchanged-history assertions.                                                                    |
| 9   | Recipe Save/readback                    | Distinct-Unit component regression and `RecipeCapability / reports BOM work, frozen Review and successful authoritative Save`; earlier 03A command/readback SQL.                                                                 |
| 10  | Import/copy/successor unchanged         | Recipe module/frontend suites; earlier `rmvp_02a_connected_recipes_bom`, `recipe_effective_contract_01`, `recipe_effective_product_model_correction`, `master_data_rehearsal_recipe_import` pgTAP.                               |
| 11  | ADD inline Unit                         | `RecipeCapability / attaches the authoritative Unit to ADD quantity without changing payload semantics`; `change-order-quantity-unit-*` browser group and description assertions.                                                |
| 12  | Quantity REPLACE inline substitute Unit | Same parameterized regression for REPLACE, with substitute `Lít` distinct from stored `Kilôgam`.                                                                                                                                 |
| 13  | ADJUST_QUANTITY stored Unit             | Same parameterized regression for ADJUST_QUANTITY plus `retains a prior ADD's authoritative Unit when its Ingredient purchase Unit has since changed`.                                                                           |
| 14  | KEEP adds no Unit input                 | `shows required REPLACE business fields and authoritative before/after Review`; default KEEP has no new quantity control; existing change-order model payload tests.                                                             |
| 15  | Change Order payload unchanged          | Attached-Unit regressions assert exact Preview quantity and Unit semantics (`null` for ADJUST_QUANTITY); existing model/controller create/preview tests.                                                                         |
| 16  | Registry exactly once                   | `AtlasOperatorOwners / registers exactly eleven real operator owners in the approved groups`; browser launcher count and outer owner count.                                                                                      |
| 17  | Existing destination never duplicates   | All eleven reopened in browser with owner count fixed at eleven; reducer and persistent-workspace tests.                                                                                                                         |
| 18  | Recipe/Change Order no remount/read     | `AtlasOperatorOwners / retains independent Recipe and Change Order editors, filters and guards without activation reads` asserts exact DOM identity and read counts; browser retained input handles at desktop/mobile.           |
| 19  | Recipe state preserved                  | Same regression and browser `retained-recipe-0-*` with exact `2,25` quantity.                                                                                                                                                    |
| 20  | Change Order state preserved            | Same regression preserves search/reason; browser `retained-recipe-1-*` with exact reason.                                                                                                                                        |
| 21  | Menu/Need independent state             | `retains independent Planning source and Need drafts, DOM, reads and close/sign-out guards`; browser independent Attendance and Need drafts. Menu candidate persistence also covered by Task 3 controller tests.                 |
| 22  | Allocation/Orders independent state     | `retains Allocation's dirty supplier detail and Orders search with independent panels and dates`; browser Supplier note/search/DatePicker path.                                                                                  |
| 23  | Ingredient/Supplier independent state   | `retains independent Ingredient and Supplier drafts while reusing the existing master-data API`; browser exact draft node identity.                                                                                              |
| 24  | Owner-specific close                    | Every editable split owner tested through its own guard at desktop/mobile; natural cancel preserves values. Existing persistent-workspace tests also cover approved unmount. Orders has no fabricated dirty draft.               |
| 25  | All dirty owners in sign-out            | Pair tests assert exact named dirty owners and retained values, with hidden owners included; existing PXK/School multi-owner regressions retained.                                                                               |
| 26  | Need → Allocation                       | `AtlasWorkspaceHandoff` exact-date first mount, same-context no read/remount, different retained date disclosure and dirty Supplier detail tests; Orders handoff/recovery controller tests preserve authority.                   |
| 27  | Eleven real + twelve capacity           | Browser eleven outer panels retained; existing `capacity` helper checks twelve desktop keyboard destinations/full tab-item reveal and mobile touch/close controls.                                                               |
| 28  | Mobile selector                         | Browser activates every real destination at 650 and 360 widths; twelve-fixture reachability at 360.                                                                                                                              |
| 29  | No document horizontal overflow         | Every browser capture asserts document width, one active outer owner, hidden/inert owners and no focus inside hidden/inert content. Tables retain local overflow.                                                                |
| 30  | Switching performance                   | All-eleven 4×CPU benchmark and legacy subset; actual starting-main versus final-source same-host seven/four control finds no broad tail regression. Modest median shift and separate dense Ingredients cost are disclosed below. |
| 31  | All-valid sync unchanged                | `usePlanningSources / performs fetch, preview and canonical Save from one Google action`; browser `menu-valid-readback-*`.                                                                                                       |
| 32  | One invalid Dish retains neighbors      | `retains valid neighbors and blocks programmatic review, Save and correction until a corrected resync`; browser `invalidMenuCell-*` shows resolved School 1 and exact unresolved School 2 source cell.                           |
| 33  | Several exact cell diagnostics          | Parser `retains every source cell and exact diagnostics beside valid neighbors`; UI `shows valid neighbors, marks every rejected source cell, and counts a cell with two causes only once`.                                      |
| 34  | Invalid School/date never authority     | Parser invalid-calendar-date parameterized cases (including invalid Date); unknown School/date source evidence; controller rejects before Preview/Save.                                                                          |
| 35  | Save blocked with blockers              | Programmatic controller Review/Save/correction guards and backend-blocked candidate tests; invalid snapshot does not expose a normal Menu Save action.                                                                           |
| 36  | No invalid partial write                | Corrected-resync controller regression asserts zero Preview/write while invalid, including programmatic calls. Browser is fixture-only; backend atomicity relies on unchanged certified command.                                 |
| 37  | Corrected candidate Preview succeeds    | Same controller regression corrects source, then asserts canonical Preview and the consequential Save request.                                                                                                                   |
| 38  | One atomic Menu replacement             | `performs fetch, preview and canonical Save from one Google action`, `saves the full canonical Menu payload despite School, date, and search filters`; unchanged backend `save_weekly_menu` transaction authority.               |
| 39  | Signature/currentness unchanged         | `weeklyMenuSync`, `planningInputsIntegrity` and controller NO_CHANGE, stale, obsolete-response, mismatched-readback and uncertain-transport/no-retry cases.                                                                      |
| 40  | Correction/commitment protected         | `exposes governed correction detail only after the Menu Save is rejected`, `does not request correction impact for unrelated Save failures`, source-isolation tests and unchanged backend commitment command.                    |

## Migration, security and deployment sequence

`20261006040547_atlas_recipe_purchase_unit_read.sql` changes only the existing
private `atlas_core.uiq03a_workbench_payload(uuid,uuid,uuid)` body. V2 Ingredient
references, including successful Save readback, gain nullable `purchase_unit_id`
and `purchase_unit_name`; v1 shape and public function identities stay intact.
The controlled Unit catalog supplies active status. No table, lifecycle,
calculation precedence, conversion or historical normalization is added.

The helper remains owned by `atlas_owner`, STABLE, SECURITY INVOKER, empty
`search_path`, without direct authenticated/anon execution. Existing public
wrappers, runtime ownership, RLS, capabilities and command checks remain the
security boundary. Migration temporarily enables the existing postgres→atlas_owner
SET membership to replace the helper and restores SET false. Task 1 verified
both membership rows afterward. D-047 already rejects mismatched new PRESENT
revisions atomically; this PR does not replace its command error semantics.

After separate deployment approval: apply the reviewed repository migration,
verify shaped v2 reads/readback and helper ownership/ACL/SET flags, then enable
the coordinated frontend and smoke-test with authorized synthetic data. The
new frontend deployed first fails closed for Recipe authoring until purchase
Unit metadata is available. Do not treat that safe blocker as completed hosted
enablement. No hosted command was run during this certification.

Rollback uses a reviewed forward migration restoring the previous helper body,
same owner/properties/ACL, and restored SET false; coordinate frontend rollback
before removing its required read metadata. No business data restoration is
needed. Historical line Units remain exactly stored; mismatches require governed
data review outside this scope.

Two root rulings remain explicit. The 03B pgTAP exact capability count changed
29→31 only after baseline reproduction proved the approved School Dispatch
migration adds `dispatch.school_release.read` and `dispatch.school_release.release`;
Recipe adds no capability. Dirty Menu candidates retain existing week/date/School
discard guards. Switching workspaces preserves them; changing source context may
require discard and resync. Exact date-aware source details remain available in
the current context. No candidate-view exception was added.

## Final local validation, browser, performance and visual review

All required local commands passed on the integrated UI source. Logs are in the
artifact directory's `logs/` subdirectory:

| Command                                        | Result                                  | Log                   |
| ---------------------------------------------- | --------------------------------------- | --------------------- |
| `pnpm ui:vnext:check`                          | PASS                                    | `ui-check.log`        |
| `pnpm typecheck`                               | PASS                                    | `typecheck.log`       |
| `pnpm test --maxWorkers=2 --testTimeout=20000` | PASS, 184 files / 2,448 tests, 814.74 s | `full-test.log`       |
| `pnpm build-storybook`                         | PASS                                    | `storybook-build.log` |
| `pnpm build`                                   | PASS                                    | `build.log`           |
| `pnpm ops:workspace`                           | PASS                                    | `workspace.log`       |
| `git diff --check`                             | PASS                                    | `diff-check.log`      |

The owner-authorized local test resource flags do not change CI configuration.
Task 2's earlier 91/92 batch encountered an unchanged five-second Planning Apply
deadline; that case passed in isolation at the default deadline. Its original
cause remains unproven. The final full local suite above passed, while default
GitHub CI remains a separate gate. Both builds retain the existing large-chunk
advisory. The workspace check retains a stale D-drive documentation advisory;
root, origin, branch and the explicitly authorized E-drive checkout were verified.
No successful full suite was repeated after it passed.

### Browser and artifact manifest

[`browser-all.json`](../testing/artifacts/atlas-product-corrections-01/browser-all.json)
records 131 captures and ten state/discard proofs. There are 21 requested views
at each of 1920×1080, 1440×900, 1366×768, 650×900 and 360×800 (105 images),
plus 24 desktop/mobile pair/guard captures and two twelve-capacity captures.
[`image-dimensions.json`](../testing/artifacts/atlas-product-corrections-01/image-dimensions.json)
checks every PNG's exact viewport dimensions. Images are viewport captures,
not scaled full-page images. The browser is Chromium 151.0.7922.34.

The eleven real owners are `schools`, `planning`, `confirmed-need`, `procurement`,
`purchase-orders`, `recipes`, `change-orders`, `ingredients`, `suppliers`, `pxk`, and
`reconciliation`. Every matrix capture checks one active outer panel, retained
hidden/inert owners, one h1, no hidden focus and no document overflow. Real
desktop keyboard navigation checks the entire active tab item including its
close control; mobile activation reaches every owner. The reused twelve-owner
fixture checks the same capacity boundary. Launcher search, ArrowDown, Escape
and focus restoration pass.

Pair proofs retain actual editor DOM handles and values across switches,
identify the exact dirty owners at sign-out, and exercise each dirty owner's
close/cancel guard at desktop and phone sizes. Orders is a clean search/date
owner: its independent date remains day 8 and its calendar closes on workspace
switch. No artificial Orders draft is claimed. No-remount/read counts are also
asserted in `AtlasOperatorOwners.test.tsx`; browser DOM evidence alone is not
claimed to prove backend reads. Genuine Recipe discard completes under normal
and reduced motion without synthetic animation events. Requests remained local.

The final assertion run reused unchanged UI images after a Windows native Vite
watcher `EBUSY` interruption. This is a harness interruption, recorded in
`logs/vite-watch-interruption.log`, not an application assertion failure. Final
browser assertions and source-control timings used identical source-frozen Vite
wrappers with `server.watch: null`; no application setting was changed. One
bounded capture-framing correction reveals Recipe quantity/Unit and the Menu
soup cell using existing local horizontal scrolling. The browser helper checks
the text clears the sticky School column; no production visual change was made.
`browser-capture-correction.json` records those four replacement phone captures.

Run `python -X utf8 scripts/atlas_product_corrections_browser_test.py` against
the local review entry to reproduce the matrix and assertions. The existing
capture/capacity helpers are reused; `--keep-images` can rerun assertions without
image churn. `browser-matrix.json` contains the primary matrix and
`browser-pairs.json` retains the bounded pair-run evidence. Raw browser logs and
the six pgTAP logs are in `logs/`. `artifact-manifest.json` lists all evidence
files with sizes and SHA-256 hashes, excluding itself.

### Switching performance and investigation

The existing benchmark method is preserved: local Vite fixtures, Chromium,
4× CPU throttling, click to two animation frames, six cycles with the first
excluded. The eleven-owner run has 55 measured samples per viewport, with
the same four historical targets reported as a 20-sample subset. It ran before
heavy tests/builds. Historical #351 had seven mounted owners and four targets.
These are local responsiveness measurements, not staging or production SLAs.

| Workload                                                | 1440 median / p95 ms | 650 median / p95 ms |
| ------------------------------------------------------- | -------------------- | ------------------- |
| Historical #351, seven retained owners / four targets   | 181.0 / 213.6        | 126.45 / 199.0      |
| Final, eleven retained owners / all eleven targets      | 314.1 / 1337.5       | 234.8 / 1270.4      |
| Same eleven-owner run, historical four-target subset    | 278.4 / 397.8        | 174.1 / 358.4       |
| Current-source diagnostic, seven owners / four targets  | 314.45 / 447.1       | 249.1 / 405.2       |
| Current-source diagnostic, eleven owners / four targets | 300.85 / 397.4       | 212.85 / 326.4      |
| Original `dd00f304` source, idle matched host/runtime   | 221.8 / 325.1        | 164.15 / 250.9      |
| Final source, same idle matched seven/four workload     | 247.6 / 294.6        | 173.4 / 254.9       |

The historical comparison showed a material increase and triggered investigation.
The extra-owner diagnostic did not reproduce a retained-count penalty, but it
cannot exclude a decomposition contribution. CDP counters show median script
time about 150–214 ms, versus layout 6–9 ms and style recalculation 25–41 ms for
those four-target sequences. They do not isolate hidden-tree React updates.
Ingredients contributes the all-eleven tail at roughly 1.3–1.4 s: its existing
360-row fixture produces 5,994 DOM nodes/361 table rows. The fixture, catalogue
renderer and provider are unchanged from starting main, and Ingredients was not
a timed target in #351. This observed dense-view cost remains a limitation.

To separate historical timing drift from source changes, a read-only `git archive`
of exact starting main was served alongside final source on the same idle host
after all heavy jobs ended. Both Vite servers had watchers disabled. The original
benchmark ran without source edits, with only its URL redirected in memory to
port 3001; final source used the equivalent seven owners/four-target sequence on
port 3000. Each source retained the same six-cycle method and 20 measured samples.
Final desktop median is 11.6% higher while p95 is 9.4% lower; mobile median is
5.6% higher and p95 1.6% higher. This control does not reproduce the large
historical tail regression; the modest median difference remains disclosed.
One short sequential sample cannot prove zero regression or an environmental
cause. Requirement 30 is supported by this matched control and completed
investigation, with these limits, rather than an exact historical target claim.
No speculative caching, unmounting or optimization was introduced.

Raw samples/counters and runnable bounded diagnostics are
`performance.json`, `performance-investigation.json` / `.py`, and
`performance-source-control.json` / `.py`, with matching raw logs. Reproduce the
main run using `python scripts/atlas_workspace_performance.py --phase product-corrections`.
For the source control, archive `dd00f304` under ignored task scratch `baseline/`,
serve it at 3001 and final at 3000 with the same `createServer({root, server:
{host:'127.0.0.1', port, strictPort:true, watch:null}})` Vite wrapper, then run
the source-control script. No copied source is used for implementation.

`raw-logs.zip` preserves the captured command/SQL/browser log bytes. Readable
`.log` copies normalize line endings and remove terminal padding so repository
whitespace checks remain meaningful; assertions, errors and timing values are
unchanged. Format/diff-check logs are recorded separately after packaging.

### Impeccable and Ponytail final review

Impeccable Operate review preserves Atlas's approved visual authority and
vendored Chakra guidance. Context ran once at root; the one manual detector run
on the twelve changed production UI paths returned `[]` (exit 0), retained in
`impeccable-detect.json`. One batched screenshot inspection covered all five
sizes and both pair classes. The bounded correction above adjusts evidence
framing only; no production visual defect required a change.

1. **Workspace simpler? Yes.** Primary destinations are directly named; local
   Menu/Sĩ số/Bổ sung jobs remain secondary and the duplicate primary hierarchy is gone.
2. **Launcher obvious without dominating? Yes.** The far-left 44px hamburger,
   accessible title/name and visible menu heading make it recognizable while
   leaving operational content primary.
3. **Quantity and Unit natural? Yes.** Read-only Recipe Unit sits beside quantity;
   Change Order's derived Unit belongs to the same labeled group. Phone tables
   retain deliberate local horizontal scrolling.
4. **Menu errors actionable? Yes.** A concise blocker count opens exact source,
   row, field and original text with a correction/resync instruction. Valid
   neighboring cells remain visible; no invented authoritative value appears.
5. **Density preserved? Yes.** Compact operational tables, toolbar hierarchy and
   retained context remain; the shell does not add card or spacer layers.
6. **Would you ship it? Yes, through the required review/CI gate.** Visual and
   interaction certification passes. Dense Ingredients switching and the small
   matched median increase are disclosed, and hosted metadata enablement still
   requires separate deployment authorization.

**Ponytail FULL: PASS.** Existing fixture factories, capture/capacity helpers,
native DOM identity checks and stdlib statistics/JSON are reused. The only new
entry snapshots describe three explicit review cases; no new business engine,
global state, cache, dependency or alternative renderer was introduced. The
browser/performance scripts contain runnable invariant assertions. The manual
review does not substitute for parent-owned final whole-branch review.

GitHub CI is not certified by local commands. The draft PR must pass the required
final-head checks and product/architecture review before a merge decision.
`SUPABASE_REPO_CHANGE=YES`; `HOSTED_SUPABASE_CHANGE=0`; `BUSINESS_DATA_WRITES=0`
outside isolated tests/fixtures; `RETOOL_CHANGES=0`; `LIVE_OPS_CHANGES=0`.
