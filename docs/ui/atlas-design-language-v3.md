# Atlas Design Language v3 — Operational Legibility

**Task:** ATLAS-DESIGN-LANGUAGE-V3, Checkpoint E of ATLAS-PRODUCT-CORRECTIONS-01.

**Direction authorized:** 6 October 2026. **Delivery:** Draft PR #354; final Product review and merge remain separate.

## Product objective and authority

**OPERATIONAL LEGIBILITY FIRST — POLISH SECOND.** Atlas supports repeated table scanning and exact operational decisions. Its atmosphere is **bright, calm, precise, professional, human, modern operations software**. Staff legibility takes precedence over ERP parsing speed, density, coherence, polish and implementation elegance, in that order.

Staff feedback supersedes v2's visually similar eucalyptus/mineral structural planes. Text contrast alone did not distinguish canvas, toolbar, table, selected items and editable controls. C's neutral structure plus meaningful Atlas accents is the approved semantic distribution; its prototype hex values are historical evidence, not a frozen palette. A/B/C is not reopened. Coolors contributes no colors.

The owner's atmosphere correction supersedes the first v3 pass's charcoal shell and medium-gray tab band. Keep its successful geometry and legibility; make the header deep eucalyptus, tabs nearly white, canvas lighter and large working planes white. Remove redundant boxes, retain visible controls and important divisions, and give business actions a little more chroma. Avoid both grim administrative monochrome and soft pastel SaaS.

[ARCH-002](../architecture/arch-002-atlas-system-map.md), [D-048](../decisions/decision-atlas-persistent-workspace.md), the thirteen persistent owners (8 October composition amendment), local-state ownership and every business/API/security contract remain authoritative. **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.** The three-stage operating baseline remains unchanged. V3 supersedes v2 visual color, contrast, typography-legibility and component styling only.

## Color architecture

### Sanzo Wada palette trial — 27 October 2026

The Owner requested and approved a bounded Sanzo Wada palette trial in the
canonical E-drive checkout. For this trial only, warm ivory neutrals supersede
the achromatic-neutral rule below. Existing semantic roles, white working tables,
geometry, selection indicators and contrast floors still apply. Typography is
refined in the follow-up below.
This is a separately reviewable frontend change, without merge or deployment
authorization; it does not resume the completed core-data task or Warehouse.

The [digital Wada color dictionary](https://colorcombinations.org/colors/)
provides the reference anchors: Deep Slate Green `#112F2C` (navigation), Glaucous
Green `#B4CDC2` (light Brand), Yellow Ocher `#E2B540` (supporting warning tone)
and Grenadine Pink `#F48067` (supporting attention tone). Ivory Buff `#EBD3A2`
informs the lighter ivory workspace `#F1EBDC` and toolbar `#FAF7F0`.
Accessible derived shades carry actions (`#245B50`), warning text (`#56400E`)
and small attention markers (`#9B4937`). This is a Wada-inspired adaptation,
not a claim to reproduce one numbered historical combination. The coral and
mustard reference tones are not used as ordinary text on white.

Initial palette scope was `src/vnext/atlas/system.ts`, its existing contrast tests,
and this record. All consumers inherit the shared primitives; no provider replacement,
dependency, palette switch, business handler, API, permission or stored data
changes. Success, Danger and Info retain their independent existing palettes.
Acceptance requires monotonic scales, white workplanes, warm structural layers,
the existing text/control/focus contrast floors, and fixture-based desktop/mobile
review. Rollback reverts these frontend/docs changes; no migration is involved.

Local verification: 111 focused theme/provider/design-reference/shell tests pass;
formatting, the vNext boundary check and whitespace check pass. The local fixture
review covers Menu, Supplier Allocation, Recipes and School defaults at
1920×1080, 1440×900, 1366×768, 650×900 and 360×800, with no page errors or
document-level horizontal overflow. Shared computed colors match the trial.
Independent read-only review found no actionable issues. These are local fixture
results; hosted workflows, exports and full CVD simulation were not re-certified.
Full routine frontend validation remains GitHub Actions' responsibility.

The [mobile contact sheet](../testing/artifacts/atlas-sanzo-wada/contact-sheet.png)
combines four current 390×844 fixture captures at 2× resolution and the trial swatches. It is
stored with this PR so it can be opened from a phone with repository access.

### Typography follow-up — 27 October 2026

After reviewing the palette contact sheet, the Owner requested a substantial
typography improvement. This bounded follow-up supersedes the old type sizes
below while keeping the Wada trial colors and existing workbench structure.

The old stack named Inter without shipping a face: Chromium actually rendered
Segoe UI, including Bold for 650-weight headings. The shared provider now imports
one self-hosted, unmodified [Inter v4.1 variable face](../../src/assets/Inter.md),
with its OFL license, full glyph coverage, optical sizing and `font-display: swap`.
There is no runtime font CDN or package dependency. The asset adds 352,240 bytes
before transport compression and remains cacheable by the existing Vite build.

- Job titles: 24px on narrow layouts / 26px desktop, weight 600, 1.3 line height,
  restrained -0.025em tracking.
- Body, table and inline quantity text: 15px narrow / 14px desktop, 1.5 line height;
  existing tabular numerals remain.
- Labels: 14px/500, 1.5 line height. Context summaries use normal weight and
  secondary foreground so they no longer compete with titles.
- Helper text: 13px, 1.6 line height. Phone input/select/date text: 16px, retaining
  14px desktop controls and all existing target heights and keyboard behavior.

Scope extends to shared type styles/tests, the task-context presentation, the
provider's CSS import, the local face/license/provenance, and preview artifacts.
No business handlers, data, API, permission, palette, navigation or export changes.
Rollback reverts this frontend/docs follow-up; there is no database migration.

Verification: 139 focused theme/provider/reference/date/shell tests and four
task-context assertions pass. Chromium checks cover four workbenches at six
viewports (the five palette sizes plus 390×844), with the expected loaded face,
title/input sizes and no page errors or document-level overflow. A rendered
62-glyph Vietnamese probe uses only the custom Inter face; visible keyboard focus
and a deliberately blocked-font fallback pass. Mechanical typography scan and
the vNext boundary check pass. A focused production Vite build passes and includes
byte-identical font and full OFL license assets. Independent review's license
distribution finding is fixed and its follow-up review has no remaining findings. See the
[before/after comparison](../testing/artifacts/atlas-sanzo-wada/typography-comparison.png).
Physical iOS/Android text rendering and focus zoom, hosted workflows and exports
were not re-certified. Full routine validation remains owned by GitHub Actions.

### Allocation composition follow-up — 28 October 2026

The Owner rejected cosmetic type/layout changes as too generic and requested a
more purposeful design pass. Supplier Allocation is the bounded reference screen:
the composition must explain which confirmed need is selected, how its exact
quantity is distributed, and where the current action belongs.

The existing selected layout gave most width to a directory while squeezing the
allocation editor into 360–420px. The new desktop composition assigns 340px to
the need directory and the remaining width to the allocation workplane. Supplier
identity, exact quantity and notes align in columns. The existing reconciliation
quantity uses the larger quantity role so it leads the decision; supporting
location/date and notes retain quieter typography. The working plane is white;
selection and structural dividers carry the visual distinctions.

The non-scrolling selected-need header owns the common Ingredient, School,
location and date once. Supplier rows no longer repeat that whole block on a
phone. Each quantity keeps its own visible Supplier, saved baseline and Unit;
its accessible description references the common header plus those individual
facts. Both suppliers' full descriptions are covered by focused assertions and
rendered ID/visibility checks. No quantity context is inferred or dropped.

On phones the selected editor occupies the working area and Close returns to the
list. The list uses explicit stacked field labels and discoverable sorting
instead of presenting clipped desktop columns. Counts and existing commands are
grouped into one command strip. These changes are a bounded supersession of the
old Allocation presentation, not a new workflow or a redesign of other owners.

The already-locked scope toolbar remains mounted but leaves the composition while
editing; Close restores it and returns focus to the original row after rendering.
On phones the sort disclosure exposes all five existing three-state sort axes
without permanently displacing the record with a second control band.

Scope is the Allocation workbench/table/editor presentation, directly affected
tests and review artifacts. Existing commands, exact arithmetic, supplier
eligibility, statuses, dirty/exit/Save guards, focus restoration and source facts
remain authoritative. No new visual metrics, lifecycle, business action, API,
dependency, data write or Warehouse work is introduced. Earlier UI records remain
historical. The normal desktop allocation list retains its table density.

The synthetic fixture currently shows an aggregate mismatch warning alongside a
balanced row, and its workbench date and selected source date differ. Presentation
must preserve those displayed facts; this visual pass does not reconcile them or
claim hosted operational evidence. Rollback reverts this frontend/docs follow-up;
there is no migration. Draft review remains the endpoint, without merge or manual
deployment authorization.

Verification: 70 focused Allocation table/workbench/supplier-detail tests,
typecheck, formatting, boundary and whitespace checks pass. Rendered list,
selected and balanced-draft views pass at the six typography review sizes;
additional 768px and 1024px breakpoint checks pass. The existing 60/40 fixture
baseline was locally edited to 55/45 without Save: the balance stays 100/100,
Cancel retains the draft, and Discard/Close restores exact row focus and scope
controls. Sort disclosure visibility and all five ascending/descending/default
cycles pass in the browser. No page errors or document-level overflow were found.
At 1440px the selected editor is 1042px wide beside the 340px directory.
Independent visual finish review found no material issues. Physical phones,
hosted workflows and live-data density are not certified by these fixtures.

Review the matched
[desktop composition comparison](../testing/artifacts/atlas-sanzo-wada/allocation-layout-review.png)
and [phone comparison](../testing/artifacts/atlas-sanzo-wada/allocation-phone-review.png).

### Allocation row alignment correction — 28 October 2026

The Owner's screenshot identified a defect missed by the preceding internal
review: supplier identity, quantity and note controls occupied incompatible grid
rows. The quantity spanned two rows while the note spanned three, so controls
started at different heights and repeated labels obscured the column hierarchy.

Wide editors now use one shared column heading and identical tracks for every
Supplier. Identity and saved baseline form one group; quantity and note controls
share their top edge. A reserved removal-control track keeps numeric inputs the
same width for saved and newly added Suppliers. All content shares the selected
need's left inset. At 1024px the note moves beneath identity and quantity; at
narrow widths each Supplier is one linear block with local field labels and a
single divider. No additional enclosure or visual level is introduced.

This correction changes only `ProcurementSupplierDetail.tsx`, affected navigation
test expectations, this record and review images. Scope controls remain mounted
and hidden while editing: navigation tests now verify retained values in that
state and search restoration after guarded close. Supplier-specific accessible
names, context descriptions, exact quantities, eligibility, Save/exit guards,
permissions and all backend contracts remain unchanged. There is no migration;
rollback reverts this frontend/test/docs follow-up.

Browser verification covers 1920, 1440, 1366, 1024, 768, 650, 390 and 360px widths
without page errors or document overflow. Wide quantity/note top edges match
exactly. Added-row input widths, invalid quantities, long-name wrapping, keyboard
order, accessible context and dirty Cancel/Discard pass at 1440, 1024, 390 and
360px. Save was not invoked. The layout detector reports no findings; the
independent visual follow-up passes. Physical devices and hosted operational
workflows remain unchecked; normal full validation belongs to GitHub Actions.
The 29 Supplier editor tests and both affected navigation regressions pass;
typecheck, formatting, the vNext boundary and whitespace checks also pass.

Review the [desktop row comparison](../testing/artifacts/atlas-sanzo-wada/allocation-row-alignment.png)
and [phone row comparison](../testing/artifacts/atlas-sanzo-wada/allocation-row-alignment-phone.png).
Earlier comparisons preserve their earlier checkpoints.

### Allocation further review — 28 October 2026

A broader independent review found defects beyond aligned rows: opening the phone
editor scrolled the workbench scope out of view; automatic mobile cell placement
orphaned status; Add/Remove lost keyboard focus; and the 131px footer, nested
frame and expanded empty notes consumed the editing area. The Owner selected
empty notes on demand, with saved notes visible.

The selected workbench now fits its existing owner viewport and preserves the
scope header. Phone editing uses one working plane and a 77px action row. Empty
notes open inline below `xl`; saved notes remain visible and clearing an opened
note does not collapse it. Add, Remove and note disclosure have explicit focus
destinations. Mobile list fields have defined grid areas and no desktop cell
separators. The local Tabs content spacing variable removes an unintended 16px
inset. Shared recipes, palette, typography, desktop columns, exact arithmetic,
notes, eligibility, command/recovery guards and backend authority are retained.

Verification covers seven Chromium widths from 360 to 1920px, with visible
scope, zero outer-panel scroll and no document overflow. At 390px the editor is
368px wide instead of 348px. Focused workbench/editor/table checks and affected
navigation/UNKNOWN regressions pass, including saved-note visibility and focus
after removing the only draft Supplier. Typecheck, formatting, boundary and
whitespace checks pass. No browser Save or hosted write was performed.

The [full review and qualified findings](../../.impeccable/critique/2026-10-28T09-28-48Z__procurement-procurementsupplierdetail-tsx-6ed0547c.md)
records the baseline 27/40 design assessment and subsequent corrections. See the
[phone editor comparison](../testing/artifacts/atlas-sanzo-wada/allocation-review-more-phone.png)
and [phone list comparison](../testing/artifacts/atlas-sanzo-wada/allocation-review-more-list.png).
Physical devices, screen-reader speech, high Supplier counts and hosted workflows
remain unchecked. Fixture date/warning inconsistencies remain preserved and are
not treated as calculation bugs. This is a frontend/test/docs revertible change
with no migration; Draft review does not authorize merge or manual deployment.

The remaining color description records the pre-trial v3 baseline.

Stable sRGB primitives in `src/vnext/atlas/system.ts` → semantic tokens → Chakra recipes → components. Applications use meaning, never primitive colors or arbitrary hex values. The existing isolated Atlas Chakra system and provider remain in place.

Neutral has 25/50/100/200/300/400/500/600/700/800/900/950 steps. It is achromatic: R=G=B, with orderly perceptual lightness. Large working surfaces carry no green chroma. White is the working plane; darker neutral layers and structural edges organize it.

Brand has 50–950 steps. The Atlas eucalyptus hue is designed around OKLCH 170°, with an intentional chroma envelope that rises through the middle and falls in dark steps. Rounded, gamut-checked sRGB values are stored once; no browser/runtime generator exists. Stronger Brand steps express identity, primary business actions, selection geometry and focus. They do not tint toolbars or table headers.

Success uses a warmer leaf-green hue (about 135°), independent from eucalyptus. Warning uses amber (75°), Danger red (25°), Info blue (250°). Each has five useful steps: 50 subtle surface, 200 supporting tone, 500 boundary/icon, 600 solid emphasis and 700 foreground. Dark steps have restrained chroma and readable inverse text. Status backgrounds stay quiet; exceptions draw attention through icon, text and structure as well as color.

A restrained clay family (200/500/700, approximately 45°) supports human attention. `fg.attention` uses Clay 500 for small unsaved/attention markers; warning remains amber and blockers remain Danger. Clay has no structural surface role. Brand 900 measures approximately OKLCH L=0.29/C=0.05; Brand 500/600 gain controlled middle-range chroma while the primary action retains at least 7:1 inverse-text contrast.

The certification artifact records final hex values, measured OKLCH progression and actual semantic contrast combinations. Uniform mathematical spacing is not treated as visual approval.

## Semantic vocabulary and surface hierarchy

Retain the existing purpose-based vocabulary where it is already clear; do not introduce a second alias for every role.

| Role                                    | Semantic tokens                                                           | Primitive mapping             |
| --------------------------------------- | ------------------------------------------------------------------------- | ----------------------------- |
| Canvas / workbench                      | `bg.workspace`, `bg.workbench`                                            | Neutral 100 / white           |
| Toolbar / table header / nested context | `bg.toolbar`, `bg.tableHeader`, `bg.context`                              | Neutral 50 / 100 / 100        |
| Quiet hover / disabled                  | `bg.subtle`, `bg.disabled`                                                | Neutral 50 / 100              |
| Selection                               | `bg.selected`, `border.accent`                                            | Brand 100 / 600               |
| Reading                                 | `fg.default`, `fg.primary`, `fg.secondary`, `fg.muted`                    | Neutral 900 / 900 / 700 / 600 |
| Placeholder / disabled text             | `fg.placeholder`, `fg.disabled`                                           | Neutral 500 / 600             |
| Interaction / inverse / identity        | `fg.brand`, `fg.inverse`, `fg.navBrand`                                   | Brand 600 / white / Brand 200 |
| Default / resting control / divider     | `border.default`, `border.strong`, `border.subtle`                        | Neutral 400 / 500 / 300       |
| Hover boundary / disabled boundary      | `border.interactive`, `border.disabled`                                   | Brand 600 / Neutral 300       |
| Primary action                          | `action.primary.default/hover/pressed`                                    | Brand 600 / 700 / 800         |
| Destructive action                      | `action.danger.default/hover/pressed`                                     | Danger 600 / 700 / 700        |
| Status                                  | `status.success/warning/danger/info`, corresponding `bg.*` and `border.*` | Family 700 / 50 / 500         |
| Focus                                   | `focus.ring`, `focus.inverse`                                             | Brand 600 / 200               |
| Utility shell                           | `bg.navigation`, `bg.navigationHover`, `fg.navMuted`                      | Brand 900 / 800 / Neutral 300 |
| Human attention                         | `fg.attention`                                                            | Clay 500                      |

Chakra DEFAULT entries support framework consumption; they are not new application vocabulary.

Deep Brand shell → Neutral 50 tab strip → Neutral 100 canvas → white workbench → Neutral 50 toolbar → Neutral 100 table header → white rows. Nested context uses Neutral 100. Large-area hierarchy uses surfaces before enclosing borders; selected geometry, control boundaries and important table divisions remain. Shadows are reserved for overlays/notifications. Hue never establishes basic structure.

## Typography and density

Tables and inline quantities: **14px minimum**, line-height 1.4; labels: **14px semibold**; helpers and inline Units: **13px**, line-height 1.5/1.4. Body: 14px, section: 18px, workbench title: 24px desktop (22px on mobile). Primary/secondary/helper reading uses Neutral 900/700/600. No ordinary information uses low opacity.

Keep tabular numbers aligned, and quantity and Unit paired. Recover density through padding, column sizing, grouping and line height, never smaller text. Table headers use emphasis weight, distinct fill and horizontal rules. Do not introduce global zebra striping, desktop cards, decorative row rounding or a cell-border grid.

## Controls, selection and actions

Inputs/selects/date fields/textareas and checkboxes have a visible Neutral 500 resting border, Brand hover/focus and independent Danger invalid styling. They look editable before hover. Disabled controls use Neutral 100 fill, Neutral 600 text, Neutral 300 border and full opacity, including hover/pressed states. A disabled primary action is neutral. Textareas retain a 60px minimum; mobile controls retain 44px targets.

Selected rows and compact selected Dishes combine Brand 100 fill and a **3px Brand edge**. Neutral hover stays different from selection; sticky cells inherit both states. Workspace navigation uses compact bounded tabs: neutral inactive surfaces, a white active surface, stronger text and a restrained Brand edge. Keep the existing strip height and avoid pills or decorative enclosure. Dirty, attention and blocked markers remain independent from activation and have distinct shapes and accessible labels. Internal section tabs stay flat and quieter. The Recipe editor's existing action footer stays reachable at the bottom of its scrolling workplane; master-detail geometry is unchanged.

**Workbench correction — 8 October 2026, Draft PR #358:** The previous rounded/outlined treatment is rejected and its approval claim is withdrawn. The current direction is thirteen persistent operator jobs with separate Menu, Attendance and Hàng đặt riêng owners, quiet workspace navigation, neutral inactive/hover treatment and visible keyboard focus. Existing dirty/attention markers and guards remain. See the [current fixture evidence](../testing/ux/atlas-tab-borders/README.md).

**Owner convergence instruction — 10 October 2026:** [UI convergence 01](atlas-ui-convergence-01.md) supersedes the underline-only treatment above with clearer bounded active/inactive tabs. The thirteen owners, guarded exit behavior, neutral structure and existing token system remain authoritative. Workbars use shared bottom alignment with 40px desktop controls and 44px narrow targets; no per-button vertical padding offsets.

The shared left scroll-continuation fade stays below pinned identity cells. It must not wash out a selected edge: final browser certification samples the rendered rail pixel at every viewport, beyond checking the existence of a CSS indicator.

One next business action uses solid Brand 600, darkening on hover/press. Secondary actions use neutral fill and a visible border; utility/tertiary actions use readable text and discoverable hover. Destructive actions use Danger, never Brand. Do not style every clickable item green.

## Status, focus and accessibility

Blockers use danger text, an explicit icon, a visible accent/border and subtle danger background. Warnings use the corresponding amber anatomy; Info remains quiet and textual; Success is restrained. Status copy and icon shape carry meaning when hue is removed. Avoid normal-screen success floods.

Focus is a 2px solid Brand ring with 2px offset; dark shell controls use the light inverse Brand ring. Selection geometry, invalid borders and focus outlines are different structures. Keep keyboard focus, labels, semantic table markup and existing guarded exit behavior.

Contrast floors: 7:1 preferred for primary/long reading and solid primary actions; 4.5:1 for ordinary, helper and placeholder text; 3:1 for meaningful control/state/focus indicators against their actual neighbors. Decorative table dividers are not editable-control boundaries. Numerical compliance does not replace rendered-pixel and operator judgment.

Review grayscale, protanopia and deuteranopia with representative selected, disabled and warning/blocker states. The hierarchy must remain understandable through value, geometry, labels and icons.

## Responsive operation

Certify 1920×1080, 1440×900, 1366×768, 650×900 and 360×800 at 100% zoom. Keep 44px mobile targets and intentional local table scrolling. Document-level horizontal overflow is prohibited. Identity, quantity, Unit and important actions remain reachable. The mobile launcher/open-owner selector remains D-048's existing interaction, without a card conversion or a new navigation model.

## Governance and anti-patterns

New colors must use an existing semantic role mapped to an existing primitive. A genuinely new meaning requires Product review before adding its semantic role and scale mapping. Centralize raw colors in the system; component-local `#abcdef`, RGB/HSL styling, opacity-derived ordinary text, tinted structural planes, hidden resting controls and hue-only selected states are prohibited. No new framework, dependency, palette package, runtime variant toggle or generator.

Historical A/B/C evidence remains preserved on `codex/atlas-v3-legibility-variants` at `3a4fe94afc1f02d7c4361443844b4451e8ad7cd6`, and the owner's local ZIP remains untouched. Prototype runtime code is not imported into #354.

## Reference review

The [Untitled UI v7 Figma palette](https://www.figma.com/community/file/1029506782158027808/untitled-ui-v7-0-color-palette) was reviewed through its Community description and visual tonal-family preview. Its organized light-to-dark families inform the scale architecture; detailed component-state mapping is informed by [Untitled UI theming](https://untitledui.com/react/docs/theming) and [Figma token architecture](https://www.figma.com/resource-library/design-tokens/). No Untitled UI brand colors are copied. The downloadable Figma editor file was not inspected.

[Carbon color usage](https://v10.carbondesignsystem.com/guidelines/color/usage/) informs neutral layering and semantic roles. [W3C CSS Color 4](https://www.w3.org/TR/css-color-4/#ok-lab) informs perceptual lightness/chroma construction. [W3C non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html) informs resting control and state boundaries. These are references, not Atlas Product authority.

## Owner-selected C presentation — 16 October 2026

Owner selection in #391 authorizes connected subtly sloped neutral desktop workspace tabs with an active white workplane, preserving the thirteen real persistent owners and narrow selector. Supplier PO presentation uses a compact identity rail and broad selected document, retaining dates, document numbers, derived states, current shaped evidence and all command/export guards. The [bounded C implementation record](atlas-c-workspace-po-implementation.md) supersedes prior tab and PO geometry only; tokens, provider, API contracts and business authority remain unchanged.

## Bounded implementation and certification plan

The original #354 plan below records its eleven-owner baseline. Current #358 composition checks supersede that count with thirteen; historical captures remain unchanged.

1. Update `system.test.tsx` first: scale progression, text/control/action/status contrast, minimum typography, neutral disabled treatment, table/selection geometry, raw-color and prototype checks. Run against v2 and record expected failures.
2. Replace v2 primitives and semantic mappings in `system.ts`; update shared recipes. Touch the shell and specific blocker anatomy only where geometry/icon structure cannot live in the recipes. Do not alter handlers, hooks, quantities, API shapes or fixtures.
3. Run focused tests and browser certification using the existing local review entry and real production workbenches. Capture four main screens at the five sizes plus critical states, eleven-owner smoke, grayscale/CVD, computed CSS and contrast/scale reports. Reuse the existing functional regression and switching benchmark harnesses; do not overwrite historical evidence.
4. Resolve operational findings, explicitly answer the twelve operator questions, then apply Impeccable polish and Ponytail FULL/code review. Run requested UI check, typecheck, full tests, Storybook/application builds, workspace and whitespace checks; update the integrated evidence.
5. Commit/push the same branch, update Draft #354 and verify exact-head GitHub CI. Do not merge or manually deploy. V3 adds zero Supabase migrations, hosted writes, business-data writes, Retool or live OPS changes. Styling rollback reverts the v3 frontend/docs commits; the earlier Recipe read migration is untouched and not deployed.
