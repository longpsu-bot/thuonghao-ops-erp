# Atlas UI vNext 03A — candidate evaluation

**PROTOTYPE / DESIGN REVIEW ONLY · 5 October 2026**

No production visual direction is selected by this report. [Candidate direction](atlas-modern-operational-direction.md) does not supersede v1. The owner chooses the finalist; scoring is advisory.

## Provenance and boundaries

Starting main SHA: `bae6ca0bc0559d20259e0241944bab5108613559`, the merged [#348](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/348). Branch: `design/atlas-ui-vnext-03a-modern-operational-pilot`. Clean task-authorized E: checkout verified before edits. No valid newer work was reset.

The coordinator is Codex, GPT-6 family. This harness does not expose the exact coordinator model identifier or a control to switch it; GPT-6.1 Sol cannot be independently attested. Ponytail FULL, Impeccable and Matt Pocock's installed `prototype` skill were applied. The approved brief replaces a new product interview; the requested Storybook isolation overrides the prototype skill's production-route suggestion. No root product/design-system documents were rewritten for a candidate.

Four independent read-only initial reviews were dispatched before sharing conclusions: Impeccable visual director, ERP operator, Chakra/Saas/Horizon reference reviewer, accessibility/density reviewer. The visual, operator and accessibility final reviews remained separate. Reviewers inspected current source, supplied images and/or their own local browser surfaces; they did not edit files or call hosted business commands.

## What the pilot represents

One Storybook story renders the current `ConfirmedNeedWorkbench`, `ProcurementWorkbench`, `DishRecipeWorkbench` and `SchoolPxkWorkbench` inside the existing `AtlasVNextProvider`. One shared fixture/render tree is styled by `data-variant`; switching A/B/C preserves mounted drafts. Screen/state controls explicitly reset demonstration data.

| Surface        | Representative fixture                                                                      | Preserved decision / action                                                                                                              |
| -------------- | ------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Confirmed Need | Six current lines, two Schools, exact quantities; preflight blocked/loading/error/no-demand | Post-#348 Shopping List export/import gates, dirty/valid reason and note, explicit `Lưu`, clean `Tiếp tục phân bổ NCC`, formation detail |
| Procurement    | Thirteen ingredient families, explicit splits and exceptions                                | Selected supplier editor, note-only dirty state, exact balance, `Lưu phân bổ`, ready `Tiếp tục lên đơn`, existing separate PO stage      |
| Recipes        | Current catalogue, editable/locked base and selected effective context                      | Two typed scopes/date, quantity editing, `Xem thay đổi` then `Lưu công thức`, locked `Tạo lệnh điều chỉnh` affordance                    |
| Dispatch       | Current multi-School PXK shape and blocked preview                                          | Selected release detail, local note/discard protection, explicit release, quantities/Units, immutable document vocabulary                |

States: normal, selected/detail, dirty, blocked, loading, read error/retry, empty and ready. All variants use identical fixture data, labels, component logic and callbacks. The current School PXK is used, not obsolete trip/load Dispatch.

This is presentation evidence. Exports and continuation use clearly labeled local notices. Shopping List import does not parse a workbook or create imported decisions. Procurement command fixtures can return success followed by unchanged fixture readback. Existing production tests/contracts own those behaviors. Stale/unknown, released/replacement and long-content journeys remain available in incumbent stories but are not exhaustively recertified by this pilot's eight-state matrix.

## Independent blind reviews

### Impeccable visual director — initial

**KEEP:** mineral/eucalyptus identity; table-first work, exact numerals/Units, explicit actions, quiet selection and job-specific detail geometry.

**CHANGE:** reduce repeated module/title/tab/filter/count bands; make one job heading dominate; organize Shopping List utilities; improve surface distinction and repeated panel anatomy.

**REMOVE:** redundant context, excessive top padding, full-strength borders around every region, decorative KPIs/elevation and oversized empty frames.

**VISUAL_PROBLEMS:** first-viewport fragmentation; inconsistent job-region hierarchy between modules; outline saturation; too many Recipe introductions; tall narrow utility/filter regions; stale incumbent screenshots missing post-#348 controls.

**TOP_5_VISUAL_IMPROVEMENTS:** coherent job header; contemporary labeled navigation; table as primary work plane; precise attached-panel anatomy; deliberate 650/360px reflow with reachable controls.

### ERP operator — initial

**KEEP:** date/School scope, dense tables/local scroll, exact quantities, explicit Save, persistent uncertainty recovery, base/effective Recipe distinction, immutable PO/PXK evidence.

**CHANGE:** reduce chrome; keep row decision/reason together; stabilize allocation reconciliation/actions; expose dirty-note context; provide clear narrow return paths.

**REMOVE:** decorative metrics, repeated scope, normal-state badge walls, excessive spacing, technical IDs in normal work.

**OPERATIONAL_PROBLEMS:** row capacity lost to bands; wide Need reason columns; selected allocation intentionally locks scope; base/effective confusion risk; PXK row trigger differs from actual commitment; unknown outcome must stay persistently locked.

**TOP_5_WORKFLOW_IMPROVEMENTS:** maximize useful rows; retain identity/quantity/Unit/exception; keep dirty → Save/recovery → continue sequence; focused allocation editor; predictable narrow scope/detail navigation.

### Chakra / Saas UI / Horizon reviewer

**REUSABLE_ATLAS_PATTERNS:** scoped provider/portals, semantic surfaces and recipes, date/refresh controls, `AtlasTableViewport`, exact quantities, explicit commands, job-specific splits and deterministic fixtures.

**SAAS_UI_PATTERNS_TO_BORROW:** shell zones, page-header anatomy, flush table surface, composed scope filters, responsive split workbench, pinned identity where appropriate.

**HORIZON_PATTERNS_TO_BORROW:** title/utility scale, restrained outer rhythm, navigation alignment, coordinated radii and one selective surface lift.

**PATTERNS_TO_REJECT:** glass, purple/dashboard metrics, generic monetary/date formatting, automatic sorting during edits, query-builder overhead, whole-row-only navigation, one universal split ratio, reduced touch targets, toast-only uncertainty.

**DEPENDENCIES_NOT_NEEDED:** Saas/Horizon runtime/preset, second provider, Tailwind, charts, table engine, form engine, animation/date/scrollbar package. Verified source versions/links are in the candidate direction.

### Accessibility / density — initial

**ACCESSIBILITY_RISKS:** inherited filter visual/Tab-order mismatch; nonuniform named keyboard-scroll regions; repeated ingredient-only accessible labels; missing per-row Recipe error association.

**DENSITY_RISKS:** long Recipe action distance; tall mobile PXK filters; contracted dirty Need viewport; fixed columns cannot be compressed safely to remove all scrolling.

**RESPONSIVE_RISKS:** preserve each module's split geometry, long Vietnamese identities and 44px mobile targets; do not freeze a 260px identity on a 360px phone.

**MUST_PRESERVE:** scoped portals, table semantics, exact quantities, sticky intersections, local scrolling, focused-field reveal, selection/return focus, dirty/discard behavior and truthful state announcements. Calculated incumbent text pairs met AA in reviewed palette examples; this is not a WCAG certification.

## Final jury and bounded corrections

**IMPECCABLE_RANKING: B > A > C.** B has the strongest identity/proportions and refined work plane. A is the most restrained continuous composition. C earns width but its horizontal navigation and repeated module strip feel less composed. This visual ordering does not imply production approval.

Final visual ship judgment: B is recommended as a direction, A is a shippable quieter alternative, and C is not recommended as the default visual language. The B–A gap is moderate; A–C is smaller. No variant is conspicuously overdecorated. Remaining visual weaknesses are inherited Recipe editing/action distance, PXK release below the initial viewport, narrow catalogue canvases leaving unused 1920px space, tall mobile scope stacks, and B's selected-allocation master-column cost. These require a separate production task after owner selection.

**ERP_UX_RANKING: C > A > B.** C preserves the widest master view and compact editing rhythm. A is predictable and economical. B spends width/height on polish, causing more master-table panning. C does not win every row-count comparison; A can show more Recipe catalogue rows.

**ACCESSIBILITY_RANKING: C > A > B for density; accessibility behavior is broadly shared after corrections.** Width drives the ordering. No variant is certified for production accessibility.

Material prototype corrections accepted during the bounded review:

- Comparison controls moved into the review toolbar, clearing business-action obstruction.
- B uses inverse navigation focus; mobile disclosure has association and entry focus; mobile C navigation retains 44px targets.
- Week range gets an adequate desktop column; the Procurement play step matches full contextual accessible row names.
- Table/detail viewport deductions leave more room for desktop command footers. Their known ceiling is documented in CSS; production v2 should use bounded workbench slots if expanded bands consume space.
- PXK long identity wraps within its cell; detail tables reserve explicit quantity/Unit columns.
- Ready-to-order and locked Recipe action evidence added; focused mobile Need screenshots show actual editing, beyond identity-only captures.

The ERP reviewer confirmed the final Need C dirty `Lưu` is fully visible/enabled at y724.19–764.19 on 1366×768. The blocked Recipe uses the authorized locked fixture: `Tạo lệnh điều chỉnh` is enabled and invokes only the review notice. The final visual reviewer confirmed wrapped School identity and visible quantity/Unit in PXK selected/blocked detail.

Remaining inherited / adoption risks: long Recipe action distance, mobile PXK filter-stack cost, short mobile page scroll to commands, Need Tab-order/recipient labeling, and nonuniform keyboard scrolling/error association. These are recorded for v2 and are not silently repaired in production.

## Advisory scoring

Scores are judgments on a 0–10 scale; weighted total is out of 100. A 0.1 difference is not meaningful evidence of superiority. Six-line Need data caps visible-row comparison; Procurement/catalogue data and selected-master width provide the stronger density evidence.

| Criterion                          |   Weight |         A |         B |         C |
| ---------------------------------- | -------: | --------: | --------: | --------: |
| Operator efficiency                |      25% |       7.8 |       7.2 |       8.1 |
| Visual polish / perceived quality  |      25% |       8.0 |       9.0 |       7.5 |
| Information hierarchy              |      15% |       8.0 |       8.5 |       7.8 |
| Dense-table usability              |      15% |       7.5 |       7.0 |       8.5 |
| Cross-module consistency           |      10% |       8.0 |       8.8 |       7.8 |
| Accessibility / responsive quality |       5% |       7.5 |       7.0 |       8.0 |
| Engineering simplicity             |       5% |      10.0 |      10.0 |      10.0 |
| **Weighted total**                 | **100%** | **79.50** | **81.05** | **80.25** |

A balances familiarity and clean workplane with moderate horizontal panning. B's polish/hierarchy/consistency offset its operational-space cost. C's scanning/table strengths offset its weaker top-level composition. Engineering scores are equal because all use one shared fixture/workbench tree with isolated CSS, no dependencies or production architectural changes.

**Recommendation:** keep B as the visual hypothesis for the owner's comparison, with C alongside it as the density benchmark. The score gap is small and judgment-sensitive; they do not declare a winner. Do not combine variants or freeze v2 automatically. Owner selection remains required.

## Evidence and reproduction

Run `pnpm storybook --ci --no-open`, then open:

`http://localhost:6006/iframe.html?id=atlas-prototypes-modern-operational-03a--pilot&viewMode=story&surface=need&variant=B&state=normal`

Queries: `surface=need|procurement|recipes|dispatch`, `variant=A|B|C`, `state=normal|selected|dirty|blocked|loading|error|empty|ready`. Variant controls preserve drafts; surface/state controls reset them. Arrow keys cycle only within review comparison controls, not editing inputs.

Capture/check command using the host's existing Python Playwright and Pillow:

```powershell
python scripts/capture-atlas-modern-pilot.py --out 'C:\Users\HOME\.codex\visualizations\2026\10\05\01a10a7d-e565-7821-a9bb-b08c25de42c7\atlas-03a-final'
```

Evidence is outside Git, matching the existing pure-local harness convention. Viewport PNGs, selected/dirty full-page PNGs, focused mobile edits and `manifest.json` live in that directory. Five viewports: 1920×1080, 1440×900, 1366×768, 650×900, 360×800. Capture assertions cover workbench identity, document overflow, Shopping List clean/dirty gates, draft preservation and absence of external requests/page errors. Review screenshots rather than relying on these assertions alone.

Contact sheets:

- `contact-need-desktop.png`, `contact-need-responsive.png`
- `contact-procurement-desktop.png`, `contact-procurement-responsive.png`
- `contact-recipes-desktop.png`, `contact-recipes-responsive.png`
- `contact-dispatch-desktop.png`, `contact-dispatch-responsive.png`

Full captures are the detail/action evidence where a narrow screen requires vertical scrolling. Native filenames carry surface/variant/state/resolution; manifest records actual geometry and row counts. No screenshot binaries or new prototype framework are committed.

Row measurements conservatively count complete rows within the first main table/scroll region and above a 62px bottom reserve. They are capacity evidence, not a claim that every visible pixel is usable; selected Recipe measurements count editor ingredient rows rather than catalogue rows. Keyboard confirmation additionally exercised ArrowRight comparison with draft retention, mobile disclosure entry focus and a 44px navigation target after the focus compatibility fix.

Final confirmation: Chromium 151.0.7922.34, DPR 1, reduced motion. **192 viewport/state records, 270 individual PNGs and eight contact sheets**; all eight sheets visually inspected. No page errors, external requests or document-wide horizontal overflow. Shopping List gates and A/B/C draft preservation passed. All five required sizes are represented for every surface/variant; the complete eight-state matrix is at 1440×900, with selected/dirty additional evidence at 650×900 and 360×800.

| Normal first-table complete rows at 1440×900 |   A |   B |   C |
| -------------------------------------------- | --: | --: | --: |
| Confirmed Need (six-row fixture cap)         |   6 |   6 |   6 |
| Procurement                                  |   8 |   7 |   8 |
| Recipe catalogue                             |  10 |  10 |  10 |
| School PXK                                   |   7 |   7 |   7 |

| Required local validation                      | Result                                                   |
| ---------------------------------------------- | -------------------------------------------------------- |
| `pnpm ui:vnext:check`                          | PASS                                                     |
| `pnpm typecheck`                               | PASS                                                     |
| `pnpm build-storybook`                         | PASS; existing bundle-size warning                       |
| `pnpm ops:workspace`                           | PASS; historical D: path warning, authorized E: checkout |
| Targeted Prettier                              | PASS                                                     |
| Capture script syntax and browser assertions   | PASS                                                     |
| `git diff --check` and staged whitespace check | PASS                                                     |

The GitHub-owned full routine suite is reported on the draft PR under `Frontend CI / Format, typecheck, test, build`. No local production test suite was duplicated and no test was weakened.

## Ponytail, audit and safety

**PONYTAIL_STATUS:** independent FULL review passed isolation/simplicity, with small capture trust-boundary corrections accepted: exact loopback origin via stdlib URL parsing and output directory excluded from repository root/descendants. Unused hidden state markup and duplicate CSS were removed. No production cleanup was attempted.

**ANTISLOP_STATUS:** not installed / not run. No available catalog entry or installed skill path was found. **ANTISLOP_FINDINGS_ACCEPTED:** none. **ANTISLOP_FINDINGS_REJECTED_WITH_REASON:** none. Impeccable's separate mechanical detector is recorded with final validation; it is not represented as an Anti-Slop run.

Impeccable's mechanical detector ran once, after the main design reviews, against the completed story and returned `[]`. No findings were accepted or rejected. This limited source scan does not replace screenshot judgment or certify CSS/accessibility.

The browser confirmation initially detected a Storybook 10.5 / Chakra focus interoperability error. Storybook's getter reads `ownerDocument` on the prototype when Ark captures `HTMLElement.prototype.focus`. A prototype-story `beforeEach` normalizes that getter to its returned focus function using an actual element receiver. The focused reproduction then passed all four surfaces in normal/selected/dirty/blocked/loading states. The production provider and Storybook configuration remain untouched. Ponytail's final verdict is `PASS_WITH_KNOWN_CEILING`: this shim affects the preview iframe until reload and replaces Storybook's getter-level recursion guard. It is review-only and marked for removal after the upstream fix; the checks cover the pilot's interactions, not every possible focus path.

Production files changed: none. Prototype files: one story and one scoped stylesheet. Supporting files: capture/check script and these two documents. Supabase, Retool, API/RPC, RLS, authorization, persistence, lifecycle, Save semantics, quantity precision, Shopping List contract and existing production tests: unchanged. No migration, hosted call, deployment or production merge. Rollback: remove these five review files; no data/schema operation.

## Owner decision

**OWNER_DECISION_REQUIRED = YES.** Select one visual direction after comparing the evidence and reviewing the operational tradeoffs. Next task: freeze Atlas Design Language v2 and create a separate bounded production implementation task. The prototype draft PR must remain unmerged as-is.

## Variant D — Persistent Workspace

**ATLAS-UI-VNEXT-03A-D · PROTOTYPE / DESIGN REVIEW ONLY.** Continues draft [#349](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/349), starting at `79cee68de5b80c7825d89289a85e156da4e6fc96` on the existing prototype branch. The clean E: checkout, origin, branch, main ancestry and draft/unmerged PR were verified before editing. No newer work was reset. A/B/C remain available. D combines C's working width with B's restrained Atlas finish and persistent workbench navigation.

The coordinator remains Codex, GPT-6 family; the exact Sol model identifier is not exposed and cannot be attested. Ponytail FULL, installed Impeccable and Matt Pocock's prototype skill apply. Independent reviewer capacity failures were retried; completed visual, ERP, accessibility and Ponytail reviews remain separate. Anti-Slop is absent/not run; no Terra requirement or new model dependency was introduced.

### Workspace and lifecycle contract

| Rule                         | Prototype behavior / production recommendation                                                                                                                                                                                                                                                                                         |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| WORKSPACE_MODEL              | Static typed descriptors → open IDs/order and active ID in one local `useReducer` → stable keyed mounted React workbenches. No classes, serialized domain state or global drafts.                                                                                                                                                      |
| TAB_OPEN_RULE                | First launch mounts one module; subsequent launches activate its existing instance. One instance per workbench.                                                                                                                                                                                                                        |
| TAB_SWITCH_RULE              | Visibility and focus change immediately. No exit request, initialization read or remount caused by activation. Existing modal work must complete first.                                                                                                                                                                                |
| TAB_CLOSE_RULE               | Make the owner visible, call its existing `exitRef.requestExit`, remove only on approval. Cancel/block keeps it open. Restore focus to a neighboring desktop tab, mobile selector or empty-workspace launcher after dialog cleanup.                                                                                                    |
| DIRTY_TAB_RULE               | Exact existing rendered dirty evidence supplies the warning dot and accessible unsaved text. Recipe create/edit metadata instead carries truthful form-open attention; no independent dirty comparison or discard decision is invented.                                                                                                |
| SIGNOUT_RULE                 | Visit every open guard serially with its owner visible; sign out only after all approve. Cancel stops the sequence. Existing callbacks can already discard, so earlier approved discards cannot be rolled back after a later cancellation. An atomic preflight would need a separate approved interface. No real sign-out action in D. |
| MOUNTING_RULE                | Open panels remain mounted; inactive ones are hidden/inert and absent from active accessibility landmarks. Reuse the existing provider per panel to contain calendar portals. Do not hide a live modal's document focus/scroll locks.                                                                                                  |
| FRESHNESS_RULE               | Activation alone does not refresh. Scope changes, explicit refresh, command/readback and write-time currentness remain with the existing workbench. Production clean-return checks should offer a truthful freshness check; never overwrite dirty, unknown-outcome or recovery state automatically.                                    |
| CURRENT_DATE_PROPAGATION     | App's shared date currently seeds the next unmounted module; Planning, Procurement and PXK report local dates outward. Recipes owns a separate as-of date. All four initial-date props are mount seeds.                                                                                                                                |
| PERSISTENT_TAB_DATE_RISK     | A new shared seed cannot retarget an already-open workbench. It may describe the most recently reporting tab rather than the active one. A retained Orders stage can also differ from Need's intended Allocation stage.                                                                                                                |
| RECOMMENDED_V2_DATE_SEMANTIC | Seed local dates on first open; retain date/stage/draft on activation. Need continuation opens new Procurement at Need's date/Allocation stage. Existing Procurement stays intact with source/retained-date disclosure and existing detail/date/stage controls. Later production may add a guarded context-request interface.          |
| FUTURE_12_TAB_BEHAVIOR       | Four real plus eight explicitly illustrative descriptors. Full Vietnamese names, one tab row, local horizontal scrolling, whole active-tab reveal including close, launcher count/overflow cue. At650/360px a native selector exposes all12. No grouping, pinning or dated multi-instance tabs.                                        |
| REDUX_DECISION               | **NOT_JUSTIFIED.** The reducer covers navigation facts; workbench-local state remains inside existing components. No Redux, Zustand, router, cache, persistence framework or tab dependency.                                                                                                                                           |

### Currentness and date investigation

The four pilot hooks have no polling or visibility-triggered refresh. Mount/Auth/API/scope changes can initiate reads; accepted reads and existing explicit recovery stay authoritative. Stable fixture API/Auth identities prevent visibility from accidentally changing those dependencies. In-flight reads may finish while hidden, and existing dirty/busy/unknown-outcome `beforeunload` protection stays registered. Persistence does not make old authority timeless. The separate Recipe change-order workbench has a Vietnam-midnight timer and is outside this four-surface pilot; production integration must audit it separately.

Focused continuation checks prove new Procurement is initialized at07/09/2026 and an already-open Procurement retains10/09/2026 plus its Orders stage without new reads. The synthetic seed updates allocation envelopes/rows/families, preparation and PO headers/lines consistently. These are UI/context fixture proofs, not certification of hosted command provenance or business handoff. Continuation into dirty Procurement retains selected detail and note and uses the same explicit date discrepancy notice; it never remounts or changes an initial prop to simulate retargeting.

### Independent jury and accepted refinements

**IMPECCABLE_B_C_D_RANKING: D > B > C**, with a small D–B gap. D feels like one Atlas application; integrated mineral tabs, restrained surfaces, usable width and visible selected Recipe/PXK actions are strengths. Required shell refinements were whole-tab reveal, overflow count/cue and moving the12-tab demonstration action into review controls. All were accepted. Wider blank catalogue areas and mobile field/action travel remain inherited adoption work. Visual direction is recommended; production adoption is not approved.

**ERP_B_C_D_RANKING: D > C > B for Product Workspace Review.** Retained drafts, filters, selection, stage and scroll remove repeated reconstruction. D preserves almost C's selected master width: at1366px, B632 / C952 / D934px. Initial laptop dirty Need Save was clipped; compact header/filter/utility geometry and a dirty-footer reserve now make enabled `Lưu` fully visible at **y709.19–749.19** at scroll0. The reviewer confirmed pointer reachability, coherent synthetic dates and Recipe metadata attention. The launcher costs an extra initial action, local dates require reconciliation, and mobile controls occupy about100px plus review-only chrome.

Accessibility review confirmed roving Arrow/Home/End access, named close buttons, textual dirty/attention status, hidden/inert panels, contained/dismissed calendars,12-tab reachability and mobile selector access. Accepted corrections: focus-out/outside/Escape launcher dismissal, visible focus destinations,44px mobile close width and launcher open-status description. Approved-close focus must occur after React commit and Zag's deferred return-focus cleanup; the browser check covers this lifecycle. This is review evidence, not WCAG certification.

**PONYTAIL_STATUS: PASS_WITH_KNOWN_CEILING.** No mandatory abstraction/simplification remains. Retained ceilings: localized DOM presentation bridge, exact Recipe metadata dirty status deferred to a narrow production callback, existing Storybook focus shim, shared DatePicker delayed document-body live announcer, and illustrative capacity surfaces. The form-attention fallback prevents a false-clean tab without claiming that every open form has edits. DatePicker announcement isolation still needs a production accessibility decision.

### Updated advisory comparison

The A/B/C scores remain the earlier review baseline. D adds a demonstrated workspace capability; its comparison is therefore partly functional, not a pure style vote. Scores are judgment, not precision or automatic owner approval.

| Criterion                          |   Weight |         A |         B |         C |         D |
| ---------------------------------- | -------: | --------: | --------: | --------: | --------: |
| Operator efficiency                |      25% |       7.8 |       7.2 |       8.1 |       9.0 |
| Visual polish / perceived quality  |      25% |       8.0 |       9.0 |       7.5 |       9.0 |
| Information hierarchy              |      15% |       8.0 |       8.5 |       7.8 |       8.5 |
| Dense-table usability              |      15% |       7.5 |       7.0 |       8.5 |       8.6 |
| Cross-module consistency           |      10% |       8.0 |       8.8 |       7.8 |       8.8 |
| Accessibility / responsive quality |       5% |       7.5 |       7.0 |       8.0 |       8.0 |
| Engineering simplicity             |       5% |      10.0 |      10.0 |      10.0 |       8.5 |
| **Weighted total /100**            | **100%** | **79.50** | **81.05** | **80.25** | **87.70** |

D's gain comes from persistent work and combined composition. Its engineering score accounts for lifecycle/focus/status integration and production gates. **Recommend D for owner review; OWNER_DECISION_REQUIRED = YES.** If selected, freeze Design Language v2 and create a separate bounded production Persistent Workspace task. Do not merge this prototype as production.

### Evidence, validation and boundaries

Queries add `variant=D` and `workspace=single|four|stress`. D starts a separate review workspace; entering/leaving D resets it, while workbench-tab switching within D preserves it. A/B/C composition switching still preserves its own tree. State controls and “Minh họa12 bàn” intentionally reset demonstration data; they are review controls.

```powershell
python scripts/capture-atlas-modern-pilot.py --workspace --out 'C:\Users\HOME\.codex\visualizations\2026\10\05\01a10a7d-e565-7821-a9bb-b08c25de42c7\atlas-03a-d-final'
pnpm exec vitest run src/vnext/atlas/prototypes/PersistentWorkspacePrototype.test.tsx
```

Final D evidence is in `atlas-03a-d-final`, outside Git: five required sizes; four real tabs; inactive dirty Need; selected detail; all12 capacity tabs; mobile switching; existing close guards; laptop Save reachability. B/C/D contact sheets reuse unchanged B/C comparison captures and recapture D after bounded refinements. `--checks-only` reruns the lifecycle/keyboard assertions using a completed matrix; `--variant D` refreshes D while retaining B/C records. Network routing permits only the exact loopback Storybook origin and data/blob URLs; no hosted business request can escape.

Four focused prototype checks cover stable inputs/reads/mounts, existing close protection, new/retained Procurement context, and metadata attention/guard ownership. Existing production business tests are unchanged. Required UI boundary, typecheck, Storybook build, workspace and whitespace/targeted format checks apply; final-head GitHub Frontend CI owns the routine full suite.

Final confirmation: **Chromium151.0.7922.34, DPR1, reduced motion;92 B/C/D matrix records,183 PNGs including eight contact sheets**, plus five stress and six explicit journey screenshots. D is recaptured at1920×1080,1440×900,1366×768,650×900 and360×800 after refinements. Editor captures scroll the internal active panel to real fields; document full-page captures alone cannot show content below D's fixed workspace viewport. There are no page errors, external requests or document-wide horizontal overflow in the final D check.

| Real panel  | Mounts before / after switching | Initial reads before / after switching |
| ----------- | ------------------------------: | -------------------------------------: |
| Need        |                            1 /1 |                                   2 /2 |
| Procurement |                            1 /1 |                                   1 /1 |
| Recipes     |                            1 /1 |                                   1 /1 |
| School PXK  |                            1 /1 |                                   1 /1 |

Draft input identity/value, Procurement search/selected detail/local scroll and Recipe search survive the scripted journey. Independent ERP proof also retained Recipe quantity and PXK note, with only explicit Recipe selection/scope reads. Twelve-tab strip widths are2013px inside1920/1440/1366px viewports; active reveal includes the close control. Mobile selectors expose12 options at44px height. Accessibility's final keyboard discard confirmation restores Procurement tab focus at1440×900 and selector focus at360×800.

| Final local validation                           | Result                                                        |
| ------------------------------------------------ | ------------------------------------------------------------- |
| Focused prototype Vitest                         | **4 passed**; no production suite duplicated                  |
| `pnpm ui:vnext:check`                            | PASS                                                          |
| `pnpm typecheck`                                 | PASS                                                          |
| `pnpm build-storybook`                           | PASS; existing bundle-size warning                            |
| `pnpm ops:workspace`                             | PASS; historical D: path warning, task-authorized E: checkout |
| Targeted Prettier / `git diff --check`           | PASS                                                          |
| D lifecycle/overflow/focus/portal/browser checks | PASS                                                          |

Contact files in `atlas-03a-d-final`: `contact-{need,procurement,recipes,dispatch}-{desktop,responsive}.png`. `manifest.json` records the measured counts, bounds and assertions. GitHub validation is linked from #349 at the final head; do not substitute the older79cee68 CI result.

**PRODUCTION_FILES_CHANGED =0; SUPABASE_CHANGES =NONE; RETOOL_CHANGES =NONE; HOSTED_BUSINESS_WRITES =0.** Six changed files: story, scoped CSS, focused test, capture/check script and two review documents. No schema/API/contract/status/currentness/auth change or new dependency. No migration. Rollback D by reverting this bounded prototype change; no data operation. Keep #349 draft/unmerged. Any existing integration-triggered branch preview is automatic and must be disclosed separately from intentional deployment.
