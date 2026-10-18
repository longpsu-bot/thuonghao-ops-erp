# Atlas #401 — Workstream A UX implementation checkpoint

Date: 2026-10-18. Authority: Owner work order #400 and the explicit “Complete Atlas UX PR #401” task. Existing Draft #401 remains stacked on #392. No merge, deployment, database migration, staging business-data write or B1/B2/C implementation is authorized by this checkpoint.

## Identity and disposition

- Repository: `longpsu-bot/thuonghao-ops-erp`.
- Authorized checkout: `D:/Project/Repo/OPS/thuonghao-ops-erp`.
- Branch: `codex/atlas-400-ux-closeout`.
- Starting head: `f12f1218bd615eb6574d6f0f2972d055aa6e4c05`.
- Preserved parent #392 head: `6f9f288c76cfa48691fca2f4968ce03185502bb2`.
- The final commit and exact-head Frontend CI run are recorded in the updated #401 description and completion report. Six pre-existing stashes and other checkouts are preserved.

**Product verdict: BLOCKED — VALIDATION.** Implementation is a review checkpoint, not Product acceptance. The complete verified Chrome viewport matrix and actual Chrome Ingredient typing are still required. Authoritative two-category Pantry Save is separately **BLOCKED — CONTRACT (B1)**.

## Workstream A checklist

| Requirement               | Implementation and evidence                                                                                                                                                                                                                                                                                                                                                                                                           | Remaining gate                                                                                                  |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| A1 School once            | A single selected School automatically supplies new-line UUIDs. Multiple/all selection asks once at Add. Row School/location/date are read-only. School/day filters retain all unsaved rows and exact quantities, including hidden rows; week/refresh/owner exit retain dirty guards. Controller and UI tests cover inheritance, filter round trips and explicit preview payload.                                                     | Chrome add/edit/filter/remove and three-size visual review: BLOCKED — VALIDATION.                               |
| A2 400 Ingredients        | Bounded controlled Input + explicit Popover results; accent-folded name/internal-reference search; Unit labels; UUID commits only on selection; inactive results disabled; arrows/Enter/Escape/Tab/pointer. Highlight identity survives reorder and cannot substitute another UUID when a highlighted result disappears. Tests use 403 Ingredients, duplicate names, multi-character typing, empty results and rapid catalog changes. | Actual multi-character typing in Chrome: BLOCKED — VALIDATION.                                                  |
| A3 two sources            | Explicit opt-in `atlas-vnext-review.html?scenario=pantry-categories` shows separate Bổ sung / Đặt theo yêu cầu nhà trường sections, School/category inheritance, separate same-Ingredient 5/3 examples and Review. Permanent example-data banner and disabled Save. ADDITIVE/COMPLETE remains a separate composition example.                                                                                                         | Production integration: BLOCKED — CONTRACT (B1). Prototype presentation still needs Chrome review.              |
| A4 Schools                | Three internal views: Sĩ số mặc định / Nơi nấu / Nhóm phiếu xuất kho. Group-first membership/counts, assigned/unassigned/all/search, before/after changes and preview. Save remains per School using existing commands; group maintenance remains separate. Controller retains dirty/UNKNOWN/version/permission/readback guards.                                                                                                      | Real desktop/mobile navigation and visual acceptance: BLOCKED — VALIDATION.                                     |
| A5 quantities             | Nearby mobile identity for Confirmed Need, Supplier, Pantry, base Recipe and adjustment quantities; exact saved/current/proposed representations retained. Confirmed Need keeps its desktop table and local horizontal focus reveal; Pantry has a deliberate mobile authoring layout and visible field labels.                                                                                                                        | Actual 390×844 editing/filter/sort/validation/Save/Discard association: BLOCKED — VALIDATION.                   |
| A6 delete / School picker | Pantry removal now uses a named trash button and returns focus to Add/target School. Existing Recipe trash remains. Remaining Bỏ wording describes discard/review consequences. The previously improved global School picker is retained.                                                                                                                                                                                             | 50 selected Schools, long names, no matches, Apply and keyboard/focus at all three sizes: BLOCKED — VALIDATION. |
| Retained #401 work        | Allocation Cancel/Discard focus restoration, Chuẩn bị đơn mua copy, Allocation widths/actions, global School selector layout and optional internal Ingredient-code copy are preserved.                                                                                                                                                                                                                                                | Previous evidence is retained without expanding its viewport or release claims.                                 |

## Reproduction and replacement diagnosis

The parked `AtlasSearchSelect.PARKED.tsx` used a Chakra Combobox machine, a query-filtered collection and uncontrolled Input/value coordination. The retained failure was concrete: after ordinary multi-character typing (`Nguyễn Du`), the matching option was not available to the test. Those artifacts do not establish a definitive internal reset cause or an environment-only explanation. That strategy was not resumed.

The replacement is local to Pantry: one controlled query, an explicit result list and a separate selected UUID. Typing never writes a line. Enter commits the highlighted UUID; a removed or newly inactive highlighted result commits nothing. Escape/Tab restore the selected name without committing search text. Pointer selection prevents input blur until the result has been chosen. No new dependency or generalized selection framework was added.

Search covers the full catalog; suggestions render at most 40 rows with an explicit result count and a prompt to narrow by name/internal reference. This bounds initial rendering without truncating the searched catalog or substituting selection identities.

The final bounded local chooser run still recorded **1 PASS / 2 FAIL**: the long interaction hit the unchanged timeout, and subsequent typing/selection was contaminated by a pending interaction. The two-failure stop rule applies: no further local chooser strategy changes or unchanged retries were made. The normal exact-head CI is a separate required validation gate; actual Chrome typing remains BLOCKED — VALIDATION regardless of its result.

The existing Pantry v4 writer remains neutral-purpose. The production UI does not pretend that React category state changes that contract. B1 must define category persistence, same-School/day/Ingredient source-line uniqueness, preview/Save/readback and traceability, versioned compatibility and migration/rollback effects. Existing snapshots are unchanged by this frontend delta.

## Validation and retained failures

Original #401 evidence remains under `atlas-400-ux/`, including 167 PASS / 6 FAIL, the 16 PASS / 2 FAIL follow-up, parked attempts, failing CI `39072933848`, passing exact-head CI `39073645140`, and invalid requested-size captures. Later success does not erase these failures.

Development diagnostics for this completion are under the sibling `atlas-401-completion/` artifact directory:

- The first chooser run passed assertions but produced missing-ResizeObserver errors. The test received the same bounded observer stub used for browser primitives; a clean follow-up passed chooser and controller cases. No timeout was changed.
- Pantry group-mode local testing reached the unchanged five-second limit twice. The second run passed the two School inheritance/filter cases after waiting for the enabled Apply action. The group-mode timeout is retained; no third unchanged local retry or timeout increase was used.
- Schools tests first queried the panel synchronously after Chakra tab activation. Waiting for the actual panel exposed the precise second issue: `getByLabelText` matched both the legitimately named tab panel and its group selector. Selector queries now use the combobox role. Assertions on command identity, versions, nullable removal, replay, denied authority, dirty exit and UNKNOWN remain.
- TypeScript caught strict cursor tokens, nullable helper props and an unsupported testing-library query option. These were corrected without casts or contract changes.
- Local memory measurements fell below 100 MB free on an approximately 8 GB machine. This is recorded as an execution constraint, not proof that every timeout is environmental. Heavy checks were serialized.
- Final focused results, formatting/boundary/typecheck and exact-head normal Frontend CI outcomes are recorded alongside their logs and in #401. No test timeout, registered skip, production permission or CI check was relaxed.

The selected interaction run recorded **5 PASS / 3 FAIL / 100 not selected**. Both previously failing Confirmed Need cases, Supplier identity/exact balance, School versioned Save and rapid-catalog identity passed. The 403-Ingredient end-to-end test hit the unchanged limit (5.965 seconds); the following pointer test captured interleaved text `RMN-O4 0M0AT`, consistent with the prior asynchronous typing continuing after timeout. The Recipe dirty-Cancel case hit 5.195 seconds. These remain recorded failures. The bounded-suggestion change addresses the demonstrated excessive initial option rendering; it does not establish an environment-only diagnosis or Chrome acceptance.

`pnpm build:review` passed, including `tsc -b` and the normal application bundle. The existing script's name does not make its `index.html` production entry a visual fixture: fixture-browser evidence must use the explicit review HTML. UI boundary and diff whitespace checks passed. Large-bundle warnings were retained without expanding into performance optimization.

No new Supabase Full Integration is required for this strictly frontend-only delta. That boundary does not certify inherited #392 Pantry v4 or future B1/B2/C releases.

## Browser and independent review

Chrome could list the preview tab, but binding it timed out on `Emulation.setFocusEmulationEnabled`, before page inspection. The prior cold development preview was also blank and evaluation timed out. The user was asked to reconnect the extension; implementation continued independently. These failures cannot establish actual Ingredient typing, viewport control or operator acceptance.

Required **1366×768 / 1440×900 / 390×844 DOM dimensions plus screenshot pixels** are not certified by this checkpoint. No screenshot has been relabelled, CSS-simulated, or used as proof of an unverified size. A new completion contact sheet cannot be honestly supplied while the current UI cannot be captured. Previously retained rendered evidence is baseline evidence only.

The opt-in `scenario=ux401` local review fixture exposes 50 Schools, 403 Ingredients and populated cooking/Dispatch groups. Group writes explicitly return a review-only denial; persistence proof belongs to existing command tests. Other existing ready/error/loading/stale/unknown scenarios remain available. No hosted data is used or written by these fixtures.

Independent read-only review found and resolved missing mobile Pantry note/reference labels and a rapid-catalog highlighted-UUID removal edge. No other Critical/Important source regression was reported. This is **source review only**; independent visual acceptance remains BLOCKED — VALIDATION until actual screenshots are available.

## Delta manifest

Presentation and controllers:

- `src/vnext/atlas/AtlasQuantityContext.tsx`
- `src/vnext/atlas/AtlasVNextApp.review.tsx`
- `src/vnext/atlas/planning/PantryIngredientChooser.tsx`
- `src/vnext/atlas/planning/PantryCategoryDesignReview.tsx`
- `src/vnext/atlas/planning/PlanningPantryStage.tsx`
- `src/vnext/atlas/planning/usePlanningSources.ts`
- `src/vnext/atlas/planning-confirmed/ConfirmedNeedTable.tsx`
- `src/vnext/atlas/procurement/ProcurementSupplierDetail.tsx`
- `src/vnext/atlas/recipes/BaseRecipeEditor.tsx`
- `src/vnext/atlas/recipes/ChangeOrderEditor.tsx`
- `src/vnext/atlas/schools/SchoolGroupMemberships.tsx`
- `src/vnext/atlas/schools/SchoolDefaultsWorkbench.tsx`
- `src/vnext/atlas/schools/SchoolCookingGroupEditor.tsx`
- `src/vnext/atlas/schools/SchoolDispatchGroupEditor.tsx`

Focused regression coverage:

- Pantry chooser/category design, Planning Sources workbench/controller, Confirmed Need workbench, Supplier detail, Dish Recipe workbench, School Cooking groups and School Dispatch groups test files.
- This report supplements the retained `atlas-400-partial-ux-checkpoint-2026-10-18.md`; it does not replace its evidence.

## Security, release and rollback

No SQL, schema, RLS, credentials, API signatures, statuses, authoritative calculations, historical documents or backend write commands changed. Source/category fixtures are isolated from the production entrypoint. Frontend filters cannot reassign hidden drafts. Membership Save still sends one existing command with the current School version, and uncertainty continues to block editing until readback.

Rollback is the frontend commit revert; no data migration or database rollback is introduced. Existing saved records remain compatible. PR #401 remains Draft for Product review. Do not merge #401/#392, deploy, or advance to B1/B2/C automatically.
