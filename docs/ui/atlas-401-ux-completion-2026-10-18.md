# Atlas #401 — Workstream A UX implementation checkpoint

Date: 2026-10-18. Authority: Owner work order #400 and the explicit “Complete Atlas UX PR #401” task. Existing Draft #401 remains stacked on #392. No merge, deployment, database migration, staging business-data write or B1/B2/C implementation is authorized by this checkpoint.

## Identity and disposition

- Repository: `longpsu-bot/thuonghao-ops-erp`.
- Authorized checkout: `D:/Project/Repo/OPS/thuonghao-ops-erp`.
- Branch: `codex/atlas-400-ux-closeout`.
- Starting head: `f12f1218bd615eb6574d6f0f2972d055aa6e4c05`.
- Preserved parent #392 head: `6f9f288c76cfa48691fca2f4968ce03185502bb2`.
- The final commit and exact-head Frontend CI run are recorded in the updated #401 description and completion report. Six pre-existing stashes and other checkouts are preserved.

**Product verdict: BLOCKED — VALIDATION.** This is a partial desktop-reviewed implementation checkpoint. Actual Chrome Ingredient typing, School inheritance, draft retention and trash focus passed. The complete verified viewport matrix, mobile acceptance and final normal CI remain required. Authoritative two-category Pantry Save is separately **BLOCKED — CONTRACT (B1)**.

## Workstream A checklist

| Requirement               | Implementation and evidence                                                                                                                                                                                                                                                                                                      | Remaining gate                                                                                     |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| A1 School once            | PASS for source/tests and actual desktop add/edit/filter/remove, single-School inheritance, exact quantity retention, dirty Cancel and trash focus. School/day filters retain all drafts; week/refresh/owner exit retain dirty guards.                                                                                           | Full viewport acceptance: BLOCKED — VALIDATION.                                                    |
| A2 400 Ingredients        | PASS for actual Chrome multi-character typing, duplicate-name UUID selection, inactive eligibility, Escape/Tab, and all three chooser CI cases. Controlled query and separate UUID; accent-folded full-catalog name/reference search; Unit labels; at most 40 suggestions with narrowing prompt.                                 | Mobile and full viewport acceptance: BLOCKED — VALIDATION.                                         |
| A3 two sources            | Explicit opt-in `atlas-vnext-review.html?scenario=pantry-categories` shows separate Bổ sung / Đặt theo yêu cầu nhà trường sections, School/category inheritance, separate same-Ingredient 5/3 examples and Review. Permanent example-data banner and disabled Save. ADDITIVE/COMPLETE remains a separate composition example.    | Production integration: BLOCKED — CONTRACT (B1). Prototype presentation still needs Chrome review. |
| A4 Schools                | Three internal views: Sĩ số mặc định / Nơi nấu / Nhóm phiếu xuất kho. Group-first membership/counts, assigned/unassigned/all/search, before/after changes and preview. Save remains per School using existing commands; group maintenance remains separate. Controller retains dirty/UNKNOWN/version/permission/readback guards. | Real desktop/mobile navigation and visual acceptance: BLOCKED — VALIDATION.                        |
| A5 quantities             | Nearby mobile identity for Confirmed Need, Supplier, Pantry, base Recipe and adjustment quantities; exact saved/current/proposed representations retained. Confirmed Need keeps its desktop table and local horizontal focus reveal; Pantry has a deliberate mobile authoring layout and visible field labels.                   | Actual 390×844 editing/filter/sort/validation/Save/Discard association: BLOCKED — VALIDATION.      |
| A6 delete / School picker | PASS for Pantry trash focus and actual desktop 50/50 selection, long-name and empty search. Existing Recipe trash remains; remaining Bỏ wording describes discard/review consequences.                                                                                                                                           | Apply clipping/viewport fit and all-three-size acceptance: BLOCKED — VALIDATION.                   |
| Retained #401 work        | Allocation Cancel/Discard focus restoration, Chuẩn bị đơn mua copy, Allocation widths/actions, global School selector layout and optional internal Ingredient-code copy are preserved.                                                                                                                                           | Previous evidence is retained without expanding its viewport or release claims.                    |

## Reproduction and replacement diagnosis

The parked `AtlasSearchSelect.PARKED.tsx` used a Chakra Combobox machine, a query-filtered collection and uncontrolled Input/value coordination. The retained failure was concrete: after ordinary multi-character typing (`Nguyễn Du`), the matching option was not available to the test. Those artifacts do not establish a definitive internal reset cause or an environment-only explanation. That strategy was not resumed.

The replacement is local to Pantry: one controlled query, an explicit result list and a separate selected UUID. Typing never writes a line. Enter commits the highlighted UUID; a removed or newly inactive highlighted result commits nothing. Escape/Tab restore the selected name without committing search text. Pointer selection prevents input blur until the result has been chosen. No new dependency or generalized selection framework was added.

Search covers the full catalog; suggestions render at most 40 rows with an explicit result count and a prompt to narrow by name/internal reference. This bounds initial rendering without truncating the searched catalog or substituting selection identities.

The final bounded local chooser run still recorded **1 PASS / 2 FAIL**: the long interaction hit the unchanged timeout, and subsequent typing/selection was contaminated by a pending interaction. The two-failure stop rule was respected: no further local chooser strategy changes or unchanged retries were made. All three chooser cases subsequently passed normal CI. Actual Chrome `pressSequentially('RAU MUONG')` also retained the complete query, exposed three duplicate-name results and selected UUID `ingredient-402` through keyboard navigation; inactive `ingredient-403` remained disabled. Escape/Tab returned to quantity entry. These later results do not erase the retained local failures.

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

The first normal completion CI, [39091541248](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/39091541248) at `9ad9e5549621c65364baf8b539bada79e3723606`, recorded **3042 PASS / 8 FAIL / 2 existing SKIPPED**. Installation, formatting, boundary and typecheck passed; build was not reached. All three chooser tests passed, including multi-character typing and catalog updates. This does not erase local failures or substitute for Chrome acceptance.

Three CI failures exposed a real School UI lock regression: Chakra NativeSelect reads `field?.disabled ?? props.disabled`, so an enabled enclosing Field overrode a disabled NativeSelect Root. The correction places the existing disabled condition on Field.Root for membership and group metadata. Pantry retains its NativeSelect Root disabled controls outside Field.Root. Backend/controller guards were not changed. The five remaining failures concerned the newly nested School panel (tests now target the exact outer owner for hidden/inert), displayed `KG` Unit, intended taller mobile viewport, multiple accessible-description IDs, and the Recipe description's added identity context. Their assertions retain the original consequences, exact errors and association checks.

All **14 School Cooking/Dispatch tests passed locally after the disabled-context correction**, including UNKNOWN/readback locks, exact replay, denied authority, nullable removal, optimistic versions and dirty exit. Independent read-only review of the CI repair found no blockers or weakened assertions.

The four focused post-CI assertion checks also passed (69 not selected): exact outer-owner persistence, Confirmed Need adjustment styling, invalid-quantity description/Save guards and Recipe add/validation/removal. The Pantry Unit oracle correction is verified by the next normal CI; its unchanged local timeout strategy was not resumed.

The next CI, [39092252673](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/39092252673) at `792a755cd9c019db8cfa6a4341d0052e840ccd71`, failed typecheck on two redundant Pantry `NativeSelect.Field disabled` props introduced in that repair; this component's typed contract excludes that prop. Those two props were removed, retaining the existing Root controls. The School Field.Root correction and all guarded assertions remain. A fresh local normal `pnpm typecheck`, including type generation, passed before corrected-head CI. No failed-head rerun or CI relaxation was used.

CI [39092480580](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/39092480580) at `c38ac94ddef05ebd42c90dcaae0feb73e7578438` recorded **3049 PASS / 1 FAIL / 2 existing SKIPPED**. The sole failure was the unchanged five-second dirty School sign-out/close-guard test. Chooser, School group locks and the repaired association assertions passed. Temporary phase instrumentation measured approximately 4.55 seconds in Menu/navigation/34-School setup before guard assertions; sign-out reached approximately 6.29 seconds. A scoped-query candidate still timed out and was not retained. No production performance change or timeout increase was made.

The bounded guard harness correction uses two Schools only in that test: one edited to `123`, one untouched at `317`. All other fixtures retain their original catalog sizes. It preserves the full initial Menu/navigation journey, global absence assertions, both Cancel/Discard dialogs, exact dirty value, sign-out call counts and actual input disconnection; the untouched value and both disconnections add coverage. Independent review approved this scope and found no weakened guard. It does not establish 34/50-School performance acceptance. The two local verification attempts were interrupted during unresponsive startup, with only about 10–25 MB physical memory free; neither emitted a test result. The second limited worker concurrency to one without changing any timeout or assertion. These are inconclusive attempts, not passes. The final normal exact-head CI outcome is recorded in #401 and the completion artifact.

No new Supabase Full Integration is required for this strictly frontend-only delta. That boundary does not certify inherited #392 Pantry v4 or future B1/B2/C releases.

## Browser and independent review

Earlier Chrome focus/navigation failures and the unavailable-browser reset are retained in `browser-validation.txt`. After the user reconnected the extension, Chrome successfully opened the compiled explicit review fixture at frontend head `c38ac94ddef05ebd42c90dcaae0feb73e7578438`.

Actual desktop interactions verified:

- Fifty selected Schools; accent-insensitive `CHUYEN HUNG VUONG` produced five long-name results without changing 50/50 selection. An unmatched query showed no results while preserving selection.
- Pantry selected a target School once under all-School scope; subsequent lines retained read-only School/location/date. Under single-School scope Add inherited that School automatically.
- Real multi-character Ingredient typing, duplicate-name reference/Unit identity, inactive eligibility, keyboard UUID selection, Escape and Tab passed as described above.
- Exact quantity `12.500001` survived School filter changes. A filtered-out draft was explicitly reported and retained. Refresh opened the dirty dialog; Cancel retained the exact value. Removing an empty line returned focus to Add.

The browser viewport override was diagnosed once. DOM and capture pixels disagreed; the subsequent mobile viewport call timed out, and one browser inventory recovery also timed out. No further viewport attempts, CSS simulation, resizing or relabelling were used. A viewport reset could not be confirmed after that interruption. The task-owned preview was stopped. The required **1366×768 / 1440×900 / 390×844 DOM plus screenshot-pixel matrix remains BLOCKED — VALIDATION**.

Unmodified browser captures in `atlas-401-completion/` provide equivalent rendered evidence for partial desktop review. Filenames containing a requested or DOM size do not assert screenshot pixels:

| Capture                                       | Verified DOM / screenshot pixels | Evidence                                                        |
| --------------------------------------------- | -------------------------------- | --------------------------------------------------------------- |
| `school50-request1366-actual-dom1367.jpg`     | DOM 1367×768 / pixels 1367×769   | 50 selected Schools; Apply partly clipped at capture bottom     |
| `school50-long-actual1366x768.jpg`            | DOM 1366×768 / pixels 1366×625   | Five readable long School-name matches; selection retained      |
| `pantry-403-real-typing-dom1366x768.jpg`      | DOM 1366×768 / pixels 1366×625   | Three duplicate-name results, selected UUID and inactive option |
| `pantry-refresh-dirty-dialog-dom1366x768.jpg` | DOM 1366×768 / pixels 1366×625   | Dirty refresh Cancel/Discard dialog                             |
| `pantry-fullpage-diagnostic-dom1366x768.jpg`  | DOM 1366×768 / pixels 1365×767   | Read-only School context and exact editable quantity            |

The supplied baseline screenshot and retained `atlas-400-ux/` captures remain before evidence. The new files are after evidence at the stated sizes only. Grouping, Supplier detail/focus, Recipe quantities, mobile editing and loading/error/stale/UNKNOWN browser states were not completed after the browser interruption; their source/tests do not substitute for this missing visual acceptance.

The opt-in `scenario=ux401` local review fixture exposes 50 Schools, 403 Ingredients and populated cooking/Dispatch groups. Group writes explicitly return a review-only denial; persistence proof belongs to existing command tests. Other existing ready/error/loading/stale/unknown scenarios remain available. No hosted data is used or written by these fixtures.

Independent read-only source review found and resolved missing mobile Pantry note/reference labels and a rapid-catalog highlighted-UUID removal edge. No other Critical/Important source regression was reported. Independent visual review of the five actual captures found no serious desktop visual regression: labels separated, long names readable, duplicate Ingredient identities distinct, inactive option visible, exact Pantry quantity retained and dirty dialog readable. Apply is partly clipped in the first picker capture, so popup viewport fit remains unresolved. The reviewer explicitly limited acceptance to partial desktop evidence; the exact matrix and mobile acceptance remain BLOCKED — VALIDATION.

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

- `src/vnext/atlas/AtlasVNextApp.test.tsx`
- `src/vnext/atlas/AtlasPersistentWorkspace.test.tsx`
- `src/vnext/atlas/planning/PantryIngredientChooser.test.tsx`
- `src/vnext/atlas/planning/PantryCategoryDesignReview.test.tsx`
- `src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx`
- `src/vnext/atlas/planning/usePlanningSources.test.tsx`
- `src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench.test.tsx`
- `src/vnext/atlas/procurement/ProcurementSupplierDetail.test.tsx`
- `src/vnext/atlas/recipes/DishRecipeWorkbench.test.tsx`
- `src/vnext/atlas/schools/SchoolCookingGroups.test.tsx`
- `src/vnext/atlas/schools/SchoolDispatchGroups.test.tsx`
- This report supplements the retained `atlas-400-partial-ux-checkpoint-2026-10-18.md`; it does not replace its evidence.

## Security, release and rollback

No SQL, schema, RLS, credentials, API signatures, statuses, authoritative calculations, historical documents or backend write commands changed. Source/category fixtures are isolated from the production entrypoint. Frontend filters cannot reassign hidden drafts. Membership Save still sends one existing command with the current School version, and uncertainty continues to block editing until readback.

Rollback reverts this completion's frontend commits back to starting head `f12f1218bd615eb6574d6f0f2972d055aa6e4c05`; no data migration or database rollback is introduced. Existing saved records remain compatible. PR #401 remains Draft for Product review. Do not merge #401/#392, deploy, or advance to B1/B2/C automatically.
