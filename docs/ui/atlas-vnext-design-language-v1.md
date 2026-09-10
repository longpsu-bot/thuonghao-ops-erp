# Atlas vNext design language v1

Authority: [D-045](../decisions/decision-atlas-chakra-ui-foundation.md), D-034 visual architecture, D-035 workflow-first UX and OPS_SYSTEM_MAP v1.0. This is a presentation contract; it adds no business state or command.

## Ownership

Chakra UI v3 owns primitives; Atlas semantic tokens own visual meaning; recipes own sanctioned repeated variants; workbench grammar owns composition. Business/API/model contracts remain reusable and authoritative. Legacy Mantine is behavioral/reference evidence, not the new design system.

## Identity and proportions

Values are carried from the baseline `src/styles.css` and `src/theme.ts`, without runtime imports: navy `#1c2735`, primary `#253246`, warm workspace `#f4f1eb`, white workbench, subtle `#f8f6f2`, selected `#edf3f7`, copper `#b66a3c`, text `#22272e`, muted `#626b74`, border `#ddd8cf`, success `#31745b`, warning `#714a0b`, danger `#b53e2e`, information/focus `#2f6594`.

Semantic groups: bg.workspace/workbench/toolbar/subtle/selected, fg.default/muted/primary/accent, border.default/subtle, status.success/warning/danger/info, focus.ring. Navigation and status surface tokens are semantic extensions of the same baseline.

Inter / Segoe UI / Arial; title 24px/650, section 17px/600, body 14px, table 13px, label 13px/600, helper 12px, button 14px/600. Spacing: 6/10/16/24/32px. Controls 40px; compact actions and refresh 36px. Control radius 6px; workbench 9px. The circular routine refresh is the intentional geometry exception.

## Composition

Workbench identity → scope/filter toolbar → exception/blocker when needed → primary dense table/editor → attached detail when selected → one dominant business command → authoritative feedback.

No card-inside-card default, decorative KPI cards or dashboard. Use spacing, typography, Separator and subtle surface change before borders. Meaningful surfaces are workspace, workbench, toolbar, table, attached detail and signal; dialogs only for real decisions.

Filter order: date/period → School → search → state/exception → refresh. Controls share height, radius and label typography, align at desktop and reflow at narrow widths. Native date inputs preserve platform interaction; nearby scope copy displays dd/mm/yyyy.

Tables: human identity → context → right-aligned quantity and adjacent Unit → relevant state → action. Compact rows, quiet headers, local horizontal scrolling. Selection has explicit text and aria-selected as well as background. No UUID/version/fingerprint columns. Master/detail is side-by-side on desktop, stacked on narrow screens; the detail has one header and reachable action footer.

## Recipes and interactions

Buttons: businessPrimary (navy), secondary (outlined), utility (quiet), destructive (danger). Badge: neutral, success, warning, danger, information. No module-specific variants. State text always explains color; unknown outcome blocks further fixture commitment and invites refresh. Fixture actions never call business APIs or imply a real save.

Refresh: `loading`, optional `disabled`, `onClick`; accessible label/title `Làm mới dữ liệu`. Stable 36×36 circle, shaded background, visible focus, ArrowClockwise spins clockwise at 800ms while loading and blocks duplicate activation. After true→false, 200ms lift to -2px and settle; this means read completion, never business success. Reduced motion disables spin and lift. DOM identity and geometry remain fixed.

## Isolation, typing and evidence

The provider owns `.atlas-vnext`; variables use `atlas` prefix, scoped preflight and scoped global styles. No production entrypoint changes. Future portals must explicitly remain inside the scoped root. Storybook retains its legacy global configuration; each new story explicitly provides the VNext provider.

The pinned CLI runs `ui:vnext:typegen` before typecheck/build/Storybook and in certification. Chakra's generated package declarations remain in node_modules; do not check them in or duplicate generated token/recipe unions. See [Chakra system configuration](https://chakra-ui.com/docs/theming/overview) and [CLI](https://chakra-ui.com/docs/get-started/cli).

`ui:vnext:check` rejects Mantine and legacy theme/styles under vNext and Chakra outside vNext; business/model/API imports remain legal. No exceptions are initially needed.

Visual evidence comes from a pure local harness outside the repository at 1366×768, 1440×900, 1920×1080 and 360×800. Record browser/DPR, screenshots, console and network. Check focus, reduced motion, local overflow, control alignment, Vietnamese wrapping and attached detail. Navigation labels are fixtures, not an approved future information architecture.
