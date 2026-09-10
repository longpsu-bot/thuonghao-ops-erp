# ATLAS-UI-01A — UI safety and semantic correctness

Pinned starting baseline: `a00f5d01bddacc79ed54dbeb979eb993d0564534`.

Branch: `feat/atlas-ui-safety-01a`. Bounded, single-agent implementation under the approved task; no broader Product redesign. The owner explicitly approved switching the clean checkout from its prior branch to this pinned baseline.

## Scope and acceptance

- **A — PXK (E078 / E079):** previously, an old selected row remained releasable while a changed scope loaded or failed. The component now compares the requested date start, date end, School and raw search (also bound to the authenticated subject) with the scope of the latest successful read. Starting any read invalidates that success marker. Changed scope immediately disables release/replacement and release notes; failure leaves them disabled. Successful current-scope readback restores only backend-permitted actions. The release handler repeats the safety guard. Existing read generations reject superseded responses; effect cleanup also invalidates outstanding reads. Notes are cleared when the scope read effect changes.
- **B — Pantry (E015):** move only the combination-mode cell after School and Ingredient. The row now follows the existing header order: service date, School/location, Ingredient/unit, combination mode, purpose, quantity, note, reference, action. Validation, quantities, purpose, ADDITIVE/COMPLETE semantics and save payload are unchanged.
- **C — Supplier split (E031 / E034 / E035):** clean Close remains immediate. Draft participants and exact quantities are compared with the authoritative values used to initialize the editor. Dirty Close asks “Có thay đổi phân bổ chưa lưu. Đóng và bỏ các thay đổi này?” Cancel preserves the exact draft; Confirm invokes normal Close, discarding the unpersisted editor. Equivalent decimal spellings remain clean; one-millionth quantity changes and newly added blank participants are dirty. The existing six-decimal BigInt parser is reused. Save is unchanged.

Allowed implementation files are the three workbenches/panels and their existing tests, plus this record. No CSS, dependencies, shared framework, domain boundary or backend changes are included.

## Regression verification

Each defect received tests before its correction. Observed red runs:

```text
pnpm exec vitest run src/modules/atlas/dispatch/SchoolDispatchReleaseWorkbench.test.tsx -t 'locks release through'
4 failed, 5 skipped: old release remained enabled after each scope control changed.

pnpm exec vitest run src/modules/atlas/planning-inputs/pantry/PantryWorkbench.test.tsx -t 'aligns School'
1 failed, 15 skipped: the School control was outside the School cell.

pnpm exec vitest run src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx -t 'discard|numerically unchanged|closes the attached'
3 failed, 5 passed, 47 skipped: dirty quantity/participant Close never requested confirmation.
```

The first green run passed all 80 tests in the three affected files. Coverage was then extended to repeat all four scope transitions for replacement PXK as well as initial release.

Final targeted command:

```text
pnpm exec vitest run src/modules/atlas/dispatch/SchoolDispatchReleaseWorkbench.test.tsx src/modules/atlas/planning-inputs/pantry/PantryWorkbench.test.tsx src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx
```

Final result: **3 test files passed; 84 tests passed; 0 failures** (13.31 seconds). This includes 13 PXK, 16 Pantry and 55 Procurement tests.

Formatting is checked only on the seven changed files, followed by `git diff --check`. Full repository certification belongs to GitHub Actions (`Frontend CI / Format, typecheck, test, build`). This Draft PR is not merge approval and must remain unmerged pending CI and Product/architecture review.

## Local browser evidence

Evidence root: `C:/Users/HOME/atlas-ui-safety-01a-20260910/`.

All eight replacement screenshots are 1440×900 under `screenshots/`:

| File                               | Evidence                                                                        |
| ---------------------------------- | ------------------------------------------------------------------------------- |
| `A-pantry-aligned.png`             | Full-app Review: header/control alignment                                       |
| `B1-pxk-current-ready.png`         | Component-only Review: current scope, release enabled                           |
| `B2-pxk-scope-loading.png`         | Component-only Review: changed search, pending read, release and notes disabled |
| `B3-pxk-scope-failed.png`          | Component-only Review: permission failure, release and notes still disabled     |
| `B4-pxk-current-recovered.png`     | Component-only Review: successful current-scope read restores eligibility       |
| `C1-supplier-dirty-balanced.png`   | Full-app legacy Review adapter: exact unsaved balanced split                    |
| `C2-supplier-cancel-retained.png`  | Cancel discard retains `60.000001 / 39.999999`                                  |
| `C3-supplier-discard-reopened.png` | Confirm discard and reopen restores `60.000000 / 40.000000`                     |

`browser-evidence.json` contains the screenshot manifest, browser version, dialog outcomes, page errors and request log. Matching `runtime/*.json` record visible controls, values and disabled states. `capture_review.py`, `harness.tsx` and `vite.config.ts` retain the local-only reproduction setup outside the repository. The harness imports the authorized checkout directly; it does not execute a copied application checkout.

The PXK harness changes read timing only, using existing ready and permission-denied Review results. Assertions inspect actual disabled DOM controls through pending/failure/recovery and verify zero release submissions. Supplier browser journeys click only Close and reopen, never Save. Native confirmation wording and Cancel/Confirm outcomes are recorded in the dialog log. Every browser HTTP request was a local GET; zero external requests were attempted, zero page errors occurred, and no business commands were submitted. External HTTP and WebSocket requests were blocked by default.

## Preservation, security and rollback

Backend contracts, Supabase schema/migrations, RPCs, RLS, authorization, currentness semantics, Confirmed Need and supplier-allocation authority, PO/PXK lifecycles and reconciliation are unchanged. No Supabase, Retool, hosted Staging, live OPS or Google Sheets data was read or written during browser verification. Git fetch/push and PR creation are the only intended remote repository operations.

The new PXK condition only restricts UI actions; the backend still decides business eligibility. No migration is required. Reverting this commit reverts the UI protections without changing persisted data.

Deferred as instructed: PXK/table and quantity/unit redesign, reconciliation layout, date normalization, Procurement styling, sticky editor footer, shared workbench/context components, navigation, Recipe density, Admin convergence, responsive closeout and large-School fixtures. Existing PXK layout issues visible in component evidence remain outside this safety task.
