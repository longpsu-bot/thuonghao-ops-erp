# Decision D-045 — Atlas Chakra UI Foundation

**Status:** Accepted

**Date:** 10/09/2026

**Approval:** Product Owner, ATLAS-UI-VNEXT-01-CHAKRA-FOUNDATION-SHELL.

## Decision

Chakra UI v3 is Atlas's long-term presentation primitive and theming foundation. Atlas UI vNext is a greenfield presentation over the existing authoritative backend, API, models and business behavior. The current Mantine application is legacy/reference and a behavioral oracle during migration; it remains operationally unchanged in this foundation task.

D-045 supersedes [D-033](decision-atlas-ui-component-foundation.md). [D-034](decision-atlas-modern-operations-ui-visual-architecture.md) remains authoritative for visual architecture and [D-035](decision-atlas-workflow-first-operator-ux.md) for workflow-first UX. D-034's historical Mantine primitive reference is superseded here; its visual principles are preserved. Normal desktop controls follow the current UI quality standard at 40px; compact controls remain 34–36px.

## Ownership and constraints

Under OPS_SYSTEM_MAP v1.0: FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.

Business capability → operator job/decision → command/read model → Atlas vNext workbench → Atlas design language → Chakra primitive.

Chakra owns generic presentation mechanics. Atlas owns business semantics, Vietnamese operator language, information hierarchy, dense table grammar and presentation of backend-authoritative state. Supabase remains authoritative for facts, calculations, quantities, security, currentness, lifecycle and immutable documents. Retool is behavioral evidence only.

The new presentation lives under `src/vnext/atlas`, with scoped reset/variables/global CSS. It does not import Mantine or legacy theme/styles. Existing business models/APIs remain reusable. No production workbench is migrated or connected in this task, and no production navigation is changed.

## Delivery and consequences

Exact runtime pins: `@chakra-ui/react@3.37.0`, `@emotion/react@11.14.0`; development `@chakra-ui/cli@3.37.0`. Mantine and Phosphor remain. No color-mode subsystem, grid, state manager or proprietary wrapper library is introduced.

The [design-language contract](../ui/atlas-vnext-design-language-v1.md), fixture shell, scoped provider, refresh interaction and import boundary checker establish the foundation. Storybook is documentation; a pure local harness supplies isolation evidence.

Backend/API/model authority is unchanged. No database migration or hosted write is required. Rollback removes the isolated foundation and build guard without data effects. Production adoption and legacy retirement require later bounded tasks. Next, after visual approval: `ATLAS-UI-VNEXT-02-CHAKRA-PROCUREMENT`.
