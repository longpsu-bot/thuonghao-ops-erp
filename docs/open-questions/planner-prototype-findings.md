# Planner Prototype Findings

**Status:** Open for product-owner and architecture review
**Source:** TASK-001 React Planner Workspace prototype

These questions were exposed by the fixture-driven screen. They deliberately do not define new business rules.

## Architecture and workflow

1. Does planning review happen per requirement row, source group, planning date, or a combination?
2. Which role may mark a requirement ready, and does that require a separate approval?
3. How should corrections before release differ from corrections against released snapshots?
4. Should a blocked line prevent only itself, its source group, or the entire planning set from progressing?
5. Should future planner review notes belong to a requirement row, demand source, date group, or planning set, and what visibility and edit lifecycle should they have?

## Calculation and trace

1. Should the trace read model be an ordered list of display steps, a graph of domain entities, or both?
2. Which trace values are persisted facts versus reproducible derivations?
3. How should the UI display the original suppressed line and replacement line for a substitution?
4. Should herb/condiment inference require planner confirmation, and which role can override it?
5. In which unit should thresholds, batch sizes, conversions, and rounding inputs appear?

## Read-model and table shape

1. Does one planner row represent a source requirement or an aggregated procurement requirement?
2. How are multiple sources represented after aggregation without losing stable line identity?
3. Should warning severity and procurement readiness be backend-returned independent fields?
4. Does a planner row need both planning, recipe, purchase, and display units at the same time?
5. How should supplier suggestions be distinguished from committed assignments?

## API and command boundaries

1. Are review, flag, and readiness separate commands or one command updating planning disposition?
2. What request and response fields are required for a quantity-override draft, including reason codes and free text?
3. Should substitution creation return both the suppressed and replacement requirement read models atomically?
4. Which backend command validates readiness, and at what grouping level?
5. How are stale calculation versions detected when a user acts from an open planner screen?
