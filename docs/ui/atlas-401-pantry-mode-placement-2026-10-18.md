# Atlas #401 — Pantry demand-mode placement (UX A7)

Authority: the approved 18 October Pantry Mode Selector Placement amendment in [Issue #400](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/400) and the Owner's explicit implementation request. Starting head: `eaaa8da759944878d48e144ec15cb1d0814b085a`, existing branch `codex/atlas-400-ux-closeout`, existing stacked Draft #401. Preserve #392 at `6f9f288c76cfa48691fca2f4968ce03185502bb2` and all six original stashes.

## Bounded implementation

Move the one editable `Cách tính nhu cầu` selector between the existing target School chooser/automatic single-School context and `+ Thêm dòng`. Use the existing `c.setMode(targetSchoolId, mode)` and School/date draft state. Disable the field and Add without a valid target, during existing edit locks, and during whole-week no-additions confirmation. The School table heading retains School/location and a compact read-only mode label. No editable mode remains in the table.

The controller already retains mode choices independently from rows, but previously exposed only its row-scoped projection. The toolbar now reads those existing drafts, allowing a choice before the first line and retaining it across School/date filters. Dirty comparison, preview and Save continue to use the unchanged `pantryModesForRows` projection. A mode-only target has no row and therefore contributes no mode to a write. It is an unsaved local preference, not a persisted orphan or an independently Save-eligible business fact. Valid Pantry rows remain exact positive quantities under the existing backend contract.

`ADDITIVE` remains the historical/default mode (`Cộng với thực đơn`); `COMPLETE` remains `Danh sách đầy đủ` at Pantry batch × School × service date, as defined by D-044. Ingredient UUIDs, exact quantities, row references, no-additions, dirty navigation, versions, correction impact, stale and UNKNOWN guards are unchanged. This field is separate from the B1 source categories. Their isolated review-only prototype still has a permanently disabled Save.

Allowed files: `PlanningPantryStage.tsx`, `usePlanningSources.ts`, their nearest controller/workbench regressions, and this report. No SQL, API, backend calculation, persistence contract, historical record, dependency, permission or unrelated UX change. Security remains backend-enforced; the existing `canEdit` guard also protects `setMode`.

## Regression and visual gates

The new controller regression first failed at the intended pre-line assertion: `c.modes` returned `[]` after choosing School A's COMPLETE mode without a row. Preserve its JSON/log as a genuine before result. It then exercises A/COMPLETE, B/ADDITIVE, two service dates, unchanged exact rows/references, an empty second-date B target, exact preview mode arguments, v4 Save mode serialization and authoritative fixture readback. A mode-only empty draft must call neither preview nor Save.

The workbench regression checks disabled mode/Add before target selection, DOM order School → mode → Add, searchable selection, choosing COMPLETE before the first line, retention after Add, read-only group labeling and absence of table mode controls. Existing tests retain single-School inheritance, saved A/COMPLETE and B/ADDITIVE, return-to-A selection, School/location/Unit identity, hidden draft retention and all original no-write assertions.

Focused controller verification: **4 PASS / 0 FAIL**, with 42 cases excluded by the name filter. This includes pre-line/two-School/two-date preview and Save, exact draft retention across filters, existing v4 Save/readback and UNKNOWN recovery. Two new test expectations were corrected against the existing fixture/command source: new-batch expected version is `1`, and authoritative fixture readback supplies `review-only-neutral-classification`. The final assertion explicitly checks that classification alongside unchanged exact row identity and quantities.

Earlier local evidence remains retained: an interrupted combined run; a relative-path controller run that also discovered preserved nested worktrees; an interrupted absolute-path attempt (Vitest also falls back to substring matching); and the correctly scoped two-file run with **3 PASS / 4 FAIL**. That scoped run exposed the readback expectation above; three UI journeys failed after 6.9/7.7/13.5 seconds with `STACK_TRACE_ERROR` JSON messages under unchanged five-second test budgets. Low free physical memory was observed, but these logs alone do not establish every failure's root cause. No unchanged UI retry, sleep, timeout increase or assertion relaxation is used. `--dir src/vnext/atlas/planning` limits discovery to the canonical Planning directory; it changes no registered test or CI configuration. Real browser acceptance and one normal exact-head CI remain required for the UI gate.

Required browser acceptance uses owned fresh Playwright Chrome contexts at exact 1366×768 and 390×844, DPR 1. Verify requested dimensions against DOM, visualViewport and PNG headers; inspect real toolbar wrapping and keyboard School → mode → Add. Exercise School/date independence and the empty-target guard. Browser fixtures certify interaction/presentation only; no hosted write is authorized.

Final focused results, exact capture source, independent review, exact final head and normal exact-head Frontend CI are recorded in the handoff and existing PR description after verification. Original passing and failed evidence remains unchanged.

Rollback reverts this bounded frontend amendment to `eaaa8da`; no migration or database rollback is needed. Stop for Product review. B1 source separation remains **BLOCKED — CONTRACT**; no merge, deployment or automatic B1/B2/C advancement.
