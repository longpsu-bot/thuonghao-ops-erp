# AGENTS.md

## Project mission

Build OPS ERP (Project Atlas), a maintainable and transferable ERP for school catering and ingredient distribution.

## Authority hierarchy

1. Approved documents in `docs/`
2. Database migrations and tests
3. Application code
4. Chat discussions and AI memory

When code conflicts with approved documentation, stop and report the conflict.

## Canonical workspace

This repository is the source of truth for OPS ERP implementation work.

- GitHub repository: `longpsu-bot/thuonghao-ops-erp`
- User's canonical Windows repo path: `D:/Project/Repo/OPS/thuonghao-ops-erp`
- Do not implement project changes in `C:/Users/hp/OneDrive/Documents/OPS ERP` or any copied workspace.

Before editing code, every implementation agent must verify the actual working tree:

```bash
git rev-parse --show-toplevel
git remote -v
git branch --show-current
git status --short
pnpm ops:workspace
```

Proceed only when the Git top level is the real `thuonghao-ops-erp` repository and `origin` points to `https://github.com/longpsu-bot/thuonghao-ops-erp.git` or the equivalent SSH remote.

## Windows Node/pnpm PATH bootstrap

If `node`, `pnpm`, or `pnpm ops:workspace` fails because the tool is not available on `PATH`, do not implement the task yet. First add the known Windows toolchain paths for the current shell/session only, then re-run the workspace check.

Known user toolchain paths:

- Node: `C:/Program Files/nodejs/node.exe`
- pnpm: `C:/Users/hp/AppData/Roaming/npm/pnpm.cmd`

For Windows `cmd.exe` sessions:

```cmd
set "PATH=C:\Program Files\nodejs;C:\Users\hp\AppData\Roaming\npm;%LOCALAPPDATA%\pnpm;%PATH%"
where node
where pnpm
node -v
pnpm -v
pnpm ops:workspace
```

A helper script is also available:

```cmd
call scripts\ops-env.cmd
pnpm ops:workspace
```

Stop and report the exact failure if Node or pnpm still cannot be found after this bootstrap. Do not continue by using another project folder.

## Mandatory reading before implementation

- `README.md`
- `docs/handbook/01-vision-product-charter.md`
- `docs/decisions/decision-register.md`
- `docs/business-rules/business-rule-register.md`
- relevant module specifications and API contracts

## Architecture rules

- Use React and TypeScript for the primary frontend.
- Use Supabase and PostgreSQL for authoritative backend logic.
- Use a modular-monolith architecture.
- Frontend coordinates user interaction; backend decides authoritative business outcomes.
- One business action should map to one transactional backend command where practical.
- Released operational documents must not be silently recalculated.
- Every effective operational quantity must retain traceability to its source and adjustments.
- React code must not use Supabase service-role credentials.
- Security must be enforced through backend privileges and RLS, not only UI visibility.

## Change-control rules

Codex and other implementation agents must not, without an approved ADR or explicit task instruction:

- change module boundaries;
- introduce new business concepts;
- alter status lifecycles;
- change calculation precedence;
- add major dependencies;
- bypass RLS or security controls;
- edit production data directly;
- alter API contracts silently;
- disable tests;
- make broad unrelated changes.

## Task boundaries

Each implementation task should:

- address one bounded capability;
- identify allowed modules and expected files;
- state prohibited changes;
- include acceptance criteria;
- include required tests;
- update affected documentation in the same change.

Prefer small, reviewable changes. Unexpectedly broad diffs must be stopped and explained.

## Branch discipline

- Start each task from latest `main` unless the user explicitly says otherwise.
- Create a bounded task branch before editing.
- Do not leave work uncommitted on `main`.
- Do not publish branches that contain no meaningful diff from `main`.
- Push the branch and let GitHub Actions perform full validation.

## Validation workflow

- Codex should run focused tests or checks needed to develop and debug the bounded change.
- The full routine frontend validation suite is owned by GitHub Actions on every pull request to `main`.
- The required workflow is `Frontend CI / Format, typecheck, test, build`.
- Routine validation includes frozen dependency installation, formatting, typecheck, tests, build, and diff whitespace checks.
- Do not spend Codex turns rerunning the full successful suite only to reproduce or report GitHub results.
- Investigate and fix validation only when a targeted local check fails, GitHub Actions fails, CI is unavailable, or the task explicitly requires additional verification.
- Never weaken, skip, or disable CI checks to merge a change.
- A pull request is not ready to merge until its GitHub Actions validation passes and its product/architecture review is complete.

## Database rules

- All schema changes must use version-controlled migrations.
- Do not manually alter production schema outside approved emergency procedures.
- Preserve stable line identity and traceability across demand, requirements, procurement, and fulfilment.
- Do not create direct dependencies from new OPS ERP modules to undocumented legacy internals; use controlled adapter views or APIs.

## Atlas product baseline

Until explicitly expanded, Atlas implementation must preserve the approved three-stage operating baseline:

1. Requirement Planning / Lập nhu cầu
2. Purchase Planning / Lập kế hoạch mua hàng
3. Warehouse Receiving / Nhập kho

Dishes, recipes, and recipe change control are supporting-data/governance areas upstream of Requirement Planning, not additional active daily workflow stages.

## Definition of done

A task is done only when:

- acceptance criteria pass;
- relevant automated tests pass;
- security implications are reviewed;
- documentation is updated;
- migration and rollback effects are stated where applicable;
- the change summary identifies files changed and any open risks.
