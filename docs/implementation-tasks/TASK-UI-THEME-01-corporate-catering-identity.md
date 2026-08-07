# TASK-UI-THEME-01 - Atlas Corporate Catering Visual Identity

**Status:** Implemented on bounded branch

## Baseline and worktree handling

- Required origin/main baseline: `c98d044f3b880cca02fb8cb95f7c2ebcd0246f78`
- Verified canonical worktree used: `E:/Project/OPS ERP/thuonghao-ops-erp-ui-theme-01`
- Baseline verification command run: `git rev-parse origin/main` matched required SHA.
- Branch: `codex/ui-theme-01-corporate-catering`
- Previous dirty worktree intentionally not modified; work was completed in this dedicated bounded branch worktree.

## Objective

UI-THEME-01 establishes the corporate visual identity for Atlas as a warm-stone, professional institutional catering dashboard while preserving zero business-behavior changes.

## Exact changed-path manifest

- `src/theme.ts`
- `src/styles.css`
- `src/modules/atlas/WorkbenchComponents.tsx` (only read-only semantic tone adjustment)
- `src/modules/atlas/AtlasApp.stories.tsx` (review evidence stories)
- `docs/ui/atlas-ui-quality-standard.md`
- `docs/architecture/roadmap.md`
- `docs/implementation-tasks/TASK-UI-THEME-01-corporate-catering-identity.md`

## Previous visual identity snapshot

- Green/olive anchor for shell and primary controls.
- Gold for multiple shell and control accents.
- Green-tinted neutrals used as non-semantic background and navigation states.

## Final visual identity

Primary direction:
- Ink navy: `#253246`
- Dark navigation: `#1C2735`
- Selected/hover navigation: `#303E51`
- Workspace warm-stone: `#F4F1EB`
- Soft ivory surface: `#F8F6F2`
- Main surface: `#FFFFFF`
- Border: `#DDD8CF`
- Primary text: `#22272E`
- Muted text: `#626B74`
- Primary action color: `#253246` (`atlasNavy`)
- Burnished copper accent: `#B66A3C`/`#A35B35`
- Secondary amber: `#D5A13D`
- Semantic states:
  - Success: `#31745B`
  - Warning: amber family (`#D5A13D`)
  - Error/blocking: deep red family (`#B53E2E`)
  - Information: restrained blue family (`#2F6594`)

## Mantine theme changes

- `atlasTheme.primaryColor` set to `atlasNavy`.
- Replaced legacy `atlasGreen`/`atlasGold` families with:
  - `atlasNavy`
  - `atlasCopper`
  - `atlasAmber`
- Kept Mantine control sizing and compact radii stable (`radius: sm`, `compact-md`) to avoid behavior changes.

## Global shell/style changes

- Introduced canonical semantic variables in `src/styles.css`:
  - `--atlas-sidebar`, `--atlas-sidebar-hover`, `--atlas-accent`, `--atlas-workspace`, `--atlas-surface`, `--atlas-surface-soft`, `--atlas-border`, `--atlas-text`, `--atlas-text-muted`, `--atlas-primary-action`, `--atlas-success`, `--atlas-warning`, `--atlas-danger`, `--atlas-info`, `--atlas-focus`.
- Migrated shell, topbar, navbar, session panel, planning/workbench surfaces, primary buttons, and review surfaces to the canonical color tokens.
- Retained compact radii, compact controls, restrained table accents, and restrained shadows.
- Added explicit operational focus ring color and reduced-motion accessibility behavior.

## Old green-brand values removed

- Replaced legacy non-semantic green brand anchors in shell/nav/button surfaces with navy/copper/caution colors.
- Updated green/olive navigation and accent usage that was brand-facing or decorative.
- Preserved green/amber/red usage where it remains explicit semantic state communication (e.g., success/warning/error statuses).

## Semantic green retained

- `--atlas-success = #31745B` remains for semantic success/approval contexts.
- Existing warning/blocking status colors retained as explicit status semantics.

## Shell treatment

- Dark ink nav remains dense and compact.
- Selected/active navigation uses `#303E51` background and `#B66A3C` accent bar.
- Inactive sidebar text uses muted neutral contrast for readable hierarchy.

## Primary-action treatment

- Primary buttons and key action surfaces now resolve to `atlasNavy` (`--atlas-primary-action`), with neutral/outline secondary styles retained.
- Copper remains a restrained accent for active selection and secondary emphasis, not global primary fill.

## Visual surface treatment

- Workspace set to warm-stone (`--atlas-workspace`) with white/ivory work panels and card surfaces.
- Borders shifted to muted warm neutrals for dense operational grouping.
- Table and dense form surfaces prioritized over dashboard-style cards.

## Accessibility and contrast

- Focus styles now use visible high-contrast outline (`--atlas-focus`).
- Kept heading/body hierarchy and readable table typography.
- `prefers-reduced-motion: reduce` handling added/retained for core animated transitions.

## Validation status

- `pnpm ops:workspace`
- `pnpm format`
- `pnpm typecheck`
- `pnpm test`
- `pnpm build`
- `pnpm build:review`
- `pnpm build-storybook`
- `git diff --check`

All required validation commands are run before PR creation and recorded in final completion report.

## UI review and PR status

- Story coverage added in `AtlasApp.stories.tsx` for shell, active navigation, state treatment, and long Vietnamese text review.
- UI review export and GitHub CI status are collected in final report once generated.

## Zero-change gates

- Dependency delta: zero
- API/model/runtime/business-contract delta: zero
- Migration/RPC/lifecycle/backend-contract delta: zero
- Hosted Supabase delta: zero
- Retool delta: zero

## Deferred work

- UI-QUALITY-02 remains deferred until UI-THEME-01 is reviewed and accepted.
- UI-QUALITY-03 remains deferred.

