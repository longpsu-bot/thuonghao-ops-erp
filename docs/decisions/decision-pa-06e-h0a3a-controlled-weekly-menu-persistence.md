# Decision PA-06E-H0A3a — Controlled Weekly Menu Persistence

**Status:** Accepted for the bounded Issue #121 foundation

**Date:** 2026-07-19

**Owner:** Planning

**Parent contracts:** [Planning Domain Weekly Menu](../architecture/planning-domain-weekly-menu-contract.md) and [PA-06E-H0 School-Catering Persistence and Materialization](../architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md)

## Decision

Issue #121 establishes the smallest private PostgreSQL foundation for a controlled Weekly Menu. It persists:

- one stable `atlas_planning.weekly_menus` root per `week_start`;
- stable `weekly_menu_lines` with typed School and Dish references;
- one immutable approval snapshot per positive Weekly Menu version; and
- immutable snapshot lines that exactly copy every and only `ACTIVE` line accepted at approval.

The root service period is any inclusive seven-calendar-day range where `week_end = week_start + 6`. H0A3a makes no Monday-start assumption.

## Stable root and working-line decision

The Weekly Menu root retains its UUID and exact service-week scope through import, correction, approval, Need Generation request, and reopen. Source type, source name, and source signature are nonblank evidence. Row count is nonnegative, and the root version is positive. Source type, source name, source signature, row count, imported actor/time, and `updated_at` describe the current working version: they may be refreshed only by same-state `DRAFT` or `REOPENED` updates, and that refresh does not require a version change. Every lifecycle transition preserves those source/import facts, while same-state `VALIDATED`, `APPROVED`, and `NEED_GENERATION_REQUESTED` updates cannot rewrite them.

Every root enters as `DRAFT`. The only accepted transitions are:

```text
DRAFT → VALIDATED → APPROVED → NEED_GENERATION_REQUESTED
                           ↘
APPROVED / NEED_GENERATION_REQUESTED → REOPENED → DRAFT
```

Reopen advances exactly to the next working version. Other lifecycle transitions retain the current version. Later approval requires a new snapshot for a later version. Previously established approval actor, timestamp, and snapshot evidence remain unchanged across request and reopen transitions.

A stable line belongs permanently to one Weekly Menu. It may change only while the root is `DRAFT` or `REOPENED`. Its normalized assignment is:

```text
Weekly Menu + School + service date + lowercase menu-slot code → Dish
```

The service date must be inside the root period, and the assignment is unique within the menu. The menu-slot code is open normalized source evidence: this task seeds no slot catalogue and hard-codes no OPS v1 slot list.

## Approval snapshot decision

Approval is represented by a distinct immutable snapshot header for the exact current positive menu version. Its actor and timestamp must match the root's latest approval evidence.

Snapshot lines carry the stable menu-line ID plus exact School, service date, menu-slot code, Dish, and optional source-row reference. Composite foreign keys prove exact menu ownership. Database guards reject:

- snapshot creation outside the exact current `VALIDATED` version;
- missing `ACTIVE` lines;
- `INVALID` or extra lines;
- altered copied values;
- cross-menu stable-line ownership;
- duplicate stable lines or duplicate School/date/slot assignments; and
- snapshot update or deletion.

Reopening makes working lines mutable again without changing any prior snapshot. A later approval creates a new snapshot; earlier approvals remain queryable and protected by `ON DELETE RESTRICT` relationships.

## Security and boundary decision

All four relations are owned by `atlas_owner`, have RLS enabled and forced, and have zero policies. `PUBLIC`, `anon`, `authenticated`, and `service_role` receive no direct relation or function privilege. The four private trigger functions use an empty `search_path`.

H0A3a adds no `atlas_api` function, runtime role, capability, membership, seed, read model, RPC, React surface, Retool write, public/`ops_v2` relation, hosted Supabase action, production data, credential, or deployment behavior. The existing 18-function API registry remains exact.

OPS v1 `public.daily_orders`, `public.daily_order_dishes`, `public.menu_import_weeks`, Google Sheet identity, same-signature behavior, and downstream rebalance remain evidence only. Atlas does not copy or write them in this task.

## Deferred decisions

The following remain separate work:

- import, validate, edit, approve, reopen, and Need Generation request commands;
- actor authorization, capabilities, reasons, warnings, issues, and events;
- a canonical menu-slot catalogue or required-slot policy;
- same-signature or database-drift behavior;
- Attendance, readiness, Need Generation, Confirmed Need, and downstream correction;
- read APIs, generated types, React, Retool, migration/backfill, hosted execution, and production rollout.

If any later task needs these choices, it must obtain its own explicit contract and issue rather than broadening this foundation.

## Migration and rollback effect

The migration is additive and seeds no row. Before operational data or dependent migrations exist, an unshipped migration can be reverted normally. After use, approval history must not be deleted or rewritten; an unsafe path must be revoked and forward-fixed through another reviewed migration.
