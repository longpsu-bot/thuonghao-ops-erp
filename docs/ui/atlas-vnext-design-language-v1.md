# Atlas vNext design language v1

Authority: [D-045](../decisions/decision-atlas-chakra-ui-foundation.md), D-034 visual architecture, D-035 workflow-first UX and OPS_SYSTEM_MAP v1.0. This is a presentation contract; it adds no business state or command.

## Ownership

Chakra UI v3 owns primitives; Atlas semantic tokens own visual meaning; recipes own sanctioned repeated variants; workbench grammar owns composition. Business/API/model contracts remain reusable and authoritative. Legacy Mantine is behavioral/reference evidence, not the new design system.

## SOFT MINERAL VISUAL IDENTITY

Approved profile under D-045: **ATLAS-UI-VNEXT-01B**. Reduce visual fatigue during long operational sessions through calm mineral neutrals, precise eucalyptus/slate actions and sparse clay signature details. Maintain dense operational usability and WCAG AA normal text; maximum contrast everywhere is not the objective.

Raw values belong only in the Chakra system. Components use semantic tokens and sanctioned recipes. Exact palette:

| Raw foundation  | Value     |
| --------------- | --------- |
| workspace       | `#F2F4F2` |
| workbench       | `#FAFBFA` |
| toolbar         | `#F0F4F1` |
| subtle          | `#F6F8F6` |
| selected        | `#E7EFEB` |
| navigation      | `#31413E` |
| navigationHover | `#3B4D49` |
| navMuted        | `#C2CBC7` |
| primary         | `#35564C` |
| primaryHover    | `#2F4B43` |
| text            | `#2A3330` |
| muted           | `#66726D` |
| clay            | `#B47A56` |
| clayText        | `#915D3E` |
| border          | `#D8DFDB` |
| borderSoft      | `#E4E9E6` |
| focus           | `#567A71` |
| focusDark       | `#E0B589` |
| success         | `#3F755E` |
| successSoft     | `#EAF3ED` |
| warning         | `#80612A` |
| warningSoft     | `#F8F1DF` |
| danger          | `#A3493F` |
| dangerSoft      | `#F9ECEA` |
| info            | `#456D76` |
| infoSoft        | `#E9F0F1` |
| white           | `#FFFFFF` |

Mineral surfaces dominate: workspace → off-white workbench → tinted toolbar → subtle attached detail, with no elevated workbench shadow. Eucalyptus owns `action.primary.default` / `.hover`; navigation has independent slate/eucalyptus default and hover values. Clay is limited to small identity cues such as the active navigation rail and selected-row rail. Never use clay for primary actions, whole rows, normal body text or warning/error meaning.

Semantic authority: `bg.workspace/workbench/toolbar/subtle/selected/navigation/navigationHover/success/warning/danger/info`; `fg.default/muted/primary/accent/inverse/navMuted`; `border.default/subtle/accent`; `action.primary.default/hover`; `status.success/warning/danger/info`; `focus.ring/inverse`. Each status retains its own text and pale surface pair, independent of branding.

Table-first comfort: workbench rows, readable muted toolbar header, quiet hover, no zebra striping. The shared table recipe owns selected eucalyptus background, a 3px clay geometric rail, `aria-selected` and 140ms background transition (disabled for reduced motion). No extra selection text line. Selection/attention rows promote secondary text and utility labels to `fg.primary`: ordinary muted text would fall below AA on these surfaces. Warning rows also retain explicit warning text and a symbol. The active navigation rail remains narrow with stronger active icon/label weight.

Soften boundaries: subtle workbench edge, 6px radius, one master/detail separator, standard soft input/secondary-button borders. Use tone, spacing and typography before outlined grouping. Attached detail uses `bg.subtle`, without shadow. All routine refresh uses `AtlasRefreshButton`; all primary actions use `businessPrimary`; controls remain 40px/6px. Workbenches must not invent alternate treatments where existing tokens/recipes describe the meaning.

Inter / Segoe UI / Arial; title 24px/650, section 17px/600, body 14px, table 13px, label 13px/600, helper 12px, button 14px/600. Spacing: 6/10/16/24/32px. Controls 40px; compact actions and refresh 36px. Control radius 6px; workbench 6px. The circular routine refresh is the intentional geometry exception.

## Composition

Workbench identity → scope/filter toolbar → exception/blocker when needed → primary dense table/editor → attached detail when selected → one dominant business command → authoritative feedback.

No card-inside-card default, decorative KPI cards or dashboard. Use spacing, typography, Separator and subtle surface change before borders. Meaningful surfaces are workspace, workbench, toolbar, table, attached detail and signal; dialogs only for real decisions.

Filter order: date/period → School → search → state/exception → refresh. Controls share height, radius and label typography, align at desktop and reflow at narrow widths. `AtlasDateInput` uses official Chakra 3.37 `DateInput`, explicit `locale="vi-VN"`, day granularity and `shouldForceLeadingZeros`: visible segments are always **dd/mm/yyyy**, regardless of browser/OS locale. Controlled business values remain canonical **YYYY-MM-DD**, using Chakra's public `parseDate` export and DateValue serialization. The resolved transitive `@internationalized/date@3.12.3` needs no additional direct dependency. No native date input, custom mask/parser or alternative date framework.

Reference identity is module/context **Kế hoạch mua hàng** and active operator job / h1 **Phân bổ nhà cung ứng**, in a compact title region. Explicit row actions are **Phân bổ NCC** for allocation work and **Xem phân bổ** for persisted-allocation fixtures; ingredient identity is not a hidden navigation affordance.

Tables: human identity → context → right-aligned quantity and adjacent Unit → relevant state → action. Compact rows, quiet headers, local horizontal scrolling. Selection combines a soft background, stable left geometric indicator and `aria-selected`, with no extra visible selection text line. No UUID/version/fingerprint columns. Desktop master/detail targets **62 / 38** (master 58–64%, detail 36–42%), with a 320px detail minimum and local table scrolling; below the desktop breakpoint they stack. Detail retains one header and a reachable action footer, without document-wide horizontal overflow.

Fixture quantities use human display literals such as `120`, `48,5`, `25,75`, with Unit adjacent. Storage/comparison precision does not automatically determine how many meaningless trailing zeroes the operator sees. This is not a universal formatter and changes no real quantity rounding, exact serialization, BigInt/decimal handling or business model.

## Recipes and interactions

Buttons: businessPrimary (eucalyptus), secondary (soft mineral border), utility (quiet), destructive (danger). Badge: neutral, success, warning, danger, information. No module-specific variants. State text always explains color. Unknown outcome uses uncertain/warning treatment, explicitly states that completion is uncertain and blocks mutation; it claims neither success nor failure. **Tải lại để xác nhận** is a separate labeled recovery control, visually and semantically distinct from routine toolbar refresh. Only this fixture recovery resets uncertain fixture state after loading; routine refresh cannot unblock it. Fixture actions never call business APIs or imply a real save.

Refresh: `loading`, optional `disabled`, `onClick`; accessible label/title `Làm mới dữ liệu`. Stable 36×36 circle, shaded background, visible focus, ArrowClockwise spins clockwise at 800ms while loading and blocks duplicate activation. After true→false, 200ms lift to -2px and settle; this means read completion, never business success. Reduced motion disables spin and lift. DOM identity and geometry remain fixed.

## Isolation, typing and evidence

The provider owns `.atlas-vnext`; variables use `atlas` prefix, scoped preflight and scoped global styles. No production entrypoint changes. Future portals must explicitly remain inside the scoped root. Storybook retains its legacy global configuration; each new story explicitly provides the VNext provider.

`strictTokens: true` is required. A typecheck sentinel rejects a casual raw `bg` string; generated declarations stay authoritative. Strict typing alone still allows Chakra raw tokens and explicit escapes, so the semantic-token convention remains mandatory.

Structural dimensions, zero/auto, border thickness, viewport bounds and motion expressions use typed CSS variable fallbacks (`var(--atlas-layout-…, fallback)`). These are CSS-local structural values, not new Product tokens; colors, surfaces, font families/sizes/weights and radii never use this escape. Chakra 3.37's generated bracket escape accepts `[value]` at type level but emits literal brackets into CSS, so it must not be used here. Explicit outline width/style/color preserve semantic focus colors against inherited Chakra shorthand. Rendered browser checks verify these fallbacks preserve actual geometry and reduced motion. The provider's only additional adjustment is its structural zero minimum width; refresh changes are limited to structural syntax/resting colors.

The pinned CLI runs `ui:vnext:typegen` before typecheck/build/Storybook and in certification. Chakra's generated package declarations remain in node_modules; do not check them in or duplicate generated token/recipe unions. See [Chakra system configuration](https://chakra-ui.com/docs/theming/overview) and [CLI](https://chakra-ui.com/docs/get-started/cli).

`ui:vnext:check` rejects direct Mantine imports, legacy theme/styles and Chakra outside vNext. All internal imports from vNext to legacy `src/` are denied unless made through **src/vnext/atlas/bridges/** to an exact module in the checker's approved business-only registry. This blocks indirect reuse of legacy Workbenches, Panels, shell/navigation, components and presentation helpers. Before adding an API/model/type/helper to that registry, review its dependencies to establish that it is non-presentation and explicitly justified. Relative imports, `@/` aliases, reexports, literal dynamic imports and require are checked. No speculative bridges or approved legacy dependencies are populated in this fixture foundation; focused fixtures demonstrate a permitted API bridge and rejected indirect UI imports. This is structural enforcement, not a dependency-graph framework.

Visual evidence comes from a pure local harness outside the repository at 1366×768, 1440×900, 1920×1080 and 360×800. Record browser/DPR, screenshots, console and network. Check focus, reduced motion, local overflow, control alignment, Vietnamese wrapping and attached detail. Navigation labels are fixtures, not an approved future information architecture.
