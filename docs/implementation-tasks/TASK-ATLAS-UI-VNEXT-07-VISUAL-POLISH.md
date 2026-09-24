# TASK-ATLAS-UI-VNEXT-07 — Visual polish with dedicated Chakra design agents

**Status:** Draft implementation task  
**Baseline:** `55a9fb2702043fba7c8f3a7d8cdcc43a76577808`  
**Branch:** `feat/atlas-ui-vnext-07-visual-polish`

## Goal

Raise Atlas vNext from functionally correct Chakra UI to a deliberately art-directed,
polished operations interface without changing business behavior, backend authority,
Supabase contracts, Retool, or protected Planning closeout semantics.

## Agent workflow

Use these project-scoped Codex agents sequentially:

1. `atlas-ui-director` — read-only current-state audit and implementation-ready visual direction.
2. `atlas-chakra-implementer` — one bounded implementation owner.
3. `atlas-ui-finish-reviewer` — read-only adversarial finish gate.

Do not use multiple concurrent UI writers.

## First implementation slice

Keep the first slice shared and UI-only:

- Atlas vNext shell and navigation hierarchy;
- page/workbench identity framing;
- shared toolbar/control alignment and spacing;
- shared workbench/table visual rhythm;
- responsive shell/workbench composition.

Prefer shared improvements that naturally benefit Schools, Ingredients/Suppliers,
Recipes and Procurement. Avoid Planning-specific behavior until Planning closeout is
independently resolved.

## Authority

- `AGENTS.md`
- `docs/ui/atlas-vnext-design-language-v1.md`
- D-034 visual architecture
- D-035 workflow-first operator UX
- D-045 Chakra UI foundation
- `src/vnext/atlas/system.ts`

OPS v1 / Retool is workflow and vocabulary evidence only.

## Hard boundaries

No changes to:

- Supabase schema, migrations, RLS or hosted business data;
- domain/API/business contracts;
- quantity, rounding, lifecycle, currentness or release semantics;
- Retool applications;
- Planning performance/browser certification logic;
- PR #286;
- production cutover behavior.

No Mantine dependency or Mantine imports in vNext.

## Visual acceptance

The changed surfaces should:

- read as modern institutional operations software rather than a generic SaaS dashboard;
- make the operator job and dominant action immediately obvious;
- preserve dense table-first work without visual fatigue;
- reduce unnecessary borders/containers and improve hierarchy with spacing/typography;
- use Atlas semantic tokens/recipes consistently;
- avoid card soup, fake KPI tiles, gradients, glow, glass and decorative motion;
- remain coherent at 1440, 1280, 768 and 390px;
- preserve keyboard/focus and reduced-motion behavior;
- keep loading, empty, error, success, permission and disabled states legible.

## Validation

Use focused component/interaction tests while iterating. GitHub Actions remains the
full frontend validation authority.

Before declaring the PR ready:

- exact changed UI flows are tested;
- targeted tests pass;
- typecheck passes for touched boundaries;
- Prettier and `git diff --check` pass;
- `atlas-ui-finish-reviewer` returns PASS or all blocking findings are resolved;
- rendered evidence is captured for the major target viewports.

## Deliverable

One Draft PR containing the agent definitions plus the bounded UI polish implementation,
with before/after evidence and an explicit statement that backend/Retool/hosted data were
not changed.
