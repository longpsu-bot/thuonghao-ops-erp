# Atlas Design Language v3 — Operational Legibility

**Task:** ATLAS-DESIGN-LANGUAGE-V3, Checkpoint E of ATLAS-PRODUCT-CORRECTIONS-01.

**Direction authorized:** 6 October 2026. **Delivery:** Draft PR #354; final Product review and merge remain separate.

## Product objective and authority

**OPERATIONAL LEGIBILITY FIRST — POLISH SECOND.** Atlas supports repeated table scanning and exact operational decisions. Its atmosphere is **bright, calm, precise, professional, human, modern operations software**. Staff legibility takes precedence over ERP parsing speed, density, coherence, polish and implementation elegance, in that order.

Staff feedback supersedes v2's visually similar eucalyptus/mineral structural planes. Text contrast alone did not distinguish canvas, toolbar, table, selected items and editable controls. C's neutral structure plus meaningful Atlas accents is the approved semantic distribution; its prototype hex values are historical evidence, not a frozen palette. A/B/C is not reopened. Coolors contributes no colors.

The owner's atmosphere correction supersedes the first v3 pass's charcoal shell and medium-gray tab band. Keep its successful geometry and legibility; make the header deep eucalyptus, tabs nearly white, canvas lighter and large working planes white. Remove redundant boxes, retain visible controls and important divisions, and give business actions a little more chroma. Avoid both grim administrative monochrome and soft pastel SaaS.

[ARCH-002](../architecture/arch-002-atlas-system-map.md), [D-048](../decisions/decision-atlas-persistent-workspace.md), the thirteen persistent owners (8 October composition amendment), local-state ownership and every business/API/security contract remain authoritative. **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.** The three-stage operating baseline remains unchanged. V3 supersedes v2 visual color, contrast, typography-legibility and component styling only.

## Color architecture

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

Selected rows and compact selected Dishes combine Brand 100 fill and a **3px Brand edge**. Neutral hover stays different from selection; sticky cells inherit both states. Active workspace navigation uses clear stronger text, surface continuity and one restrained Brand underline. It has no full outline, accent enclosure, rounded lower corners or extra gap beneath the strip. Inactive tabs use transparent fill on Neutral 50; dirty/attention markers remain independent from activation. The Recipe editor's existing action footer stays reachable at the bottom of its scrolling workplane; master-detail geometry is unchanged.

**Workbench correction — 8 October 2026, Draft PR #358:** The previous rounded/outlined treatment is rejected and its approval claim is withdrawn. The current direction is thirteen persistent operator jobs with separate Menu, Attendance and Hàng đặt riêng owners, quiet workspace navigation, neutral inactive/hover treatment and visible keyboard focus. Existing dirty/attention markers and guards remain. See the [current fixture evidence](../testing/ux/atlas-tab-borders/README.md).

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

## Bounded implementation and certification plan

The original #354 plan below records its eleven-owner baseline. Current #358 composition checks supersede that count with thirteen; historical captures remain unchanged.

1. Update `system.test.tsx` first: scale progression, text/control/action/status contrast, minimum typography, neutral disabled treatment, table/selection geometry, raw-color and prototype checks. Run against v2 and record expected failures.
2. Replace v2 primitives and semantic mappings in `system.ts`; update shared recipes. Touch the shell and specific blocker anatomy only where geometry/icon structure cannot live in the recipes. Do not alter handlers, hooks, quantities, API shapes or fixtures.
3. Run focused tests and browser certification using the existing local review entry and real production workbenches. Capture four main screens at the five sizes plus critical states, eleven-owner smoke, grayscale/CVD, computed CSS and contrast/scale reports. Reuse the existing functional regression and switching benchmark harnesses; do not overwrite historical evidence.
4. Resolve operational findings, explicitly answer the twelve operator questions, then apply Impeccable polish and Ponytail FULL/code review. Run requested UI check, typecheck, full tests, Storybook/application builds, workspace and whitespace checks; update the integrated evidence.
5. Commit/push the same branch, update Draft #354 and verify exact-head GitHub CI. Do not merge or manually deploy. V3 adds zero Supabase migrations, hosted writes, business-data writes, Retool or live OPS changes. Styling rollback reverts the v3 frontend/docs commits; the earlier Recipe read migration is untouched and not deployed.
