# Atlas #401 — focused Product follow-up

Starting source: `ad56ee372402aae87f431fed665fa49f3a6532fd`. Authority: Owner Product review on existing Draft #401 at that head and the explicit follow-up request. Keep the stacked #392 base; no new PR, merge, deployment, SQL/API change, hosted business write or B1 implementation.

## Bounded correction

The Add-time target School was still a native select, distinct from the global School filter. A fresh Chrome reproduction typed `TAN THANH`: the native control selected UUID `school-0` instead of retaining a search query. The failing query/selection invariant is retained in `browser-school-search-red.json`.

`PantrySchoolChooser` replaces only that control with the existing controlled Input/Popover pattern. It searches all eligible scoped Schools by accent-folded name/internal reference, renders at most 40 suggestions with a narrowing prompt, and shows location/reference identity. Only explicit selection commits a UUID. Keyboard, pointer/touch, inactive/disabled guards, catalogue reorder/removal and workbench hiding retain the established contracts. The existing Ingredient chooser is unchanged. Parent automatic single-School inheritance, exact rows, dirty guards, filters and deletion focus remain in place.

Files: `PantrySchoolChooser.tsx`, its focused test, `PlanningPantryStage.tsx`, `PlanningSourcesWorkbench.test.tsx`, and this report. No business/controller/API change is introduced.

## Validation method and retained evidence

Use the bundled Playwright runtime and installed Chrome executable in an owned, fresh headless browser. Each acceptance context has explicit viewport, DPR 1, and mobile touch settings where applicable. Each PNG is captured with `fullPage: false`; image-header dimensions must equal `innerWidth/innerHeight` and the requested size. Record visualViewport, devicePixelRatio, browser version, source head and local fixture URL. No extension resizing, CSS viewport simulation or image rescaling.

The fresh 1366×768 baseline matched DOM, visualViewport and PNG pixels at DPR 1. Global School picker Apply was fully visible (bottom approximately 759px). The old clipped extension capture therefore does not establish a source viewport-fit defect. Before captures and prior failures remain preserved.

Initial local integrated-test startup was interrupted without a result; it is not a pass. New focused runs reached the UUID/query assertions but exposed synchronous queries before Chakra list mount/closure. Tests now await the real list state, preserving all assertions and five-second budgets. Failed JSON/logs remain retained; no repeated local stress loop or timeout increase is used. Fresh typecheck and UI boundary passed. Independent read-only source review found no Critical/Important defect. Final normal exact-head CI is the integration gate after coherent browser/source review.

Artifact directory: `C:/Users/hp/.codex/visualizations/2026/10/17/01a14bb2-0dab-7f32-9c8f-404034947526/atlas-401-product-followup/`. The prior `atlas-401-completion/` and `atlas-400-ux/` evidence remains unchanged.

## Acceptance disposition

Browser acceptance and the final exact-head CI outcome will be linked in the final handoff and PR description after validation. Source implementation is a checkpoint until that evidence is complete. Two-category Pantry authoritative persistence remains **BLOCKED — CONTRACT (B1)**; its isolated prototype Save remains disabled. No Product/release acceptance is implied by CI alone.

Rollback reverts this follow-up's frontend changes to `ad56ee3`. No migration or database rollback is needed. Stop for Product review without automatic B1 promotion.
