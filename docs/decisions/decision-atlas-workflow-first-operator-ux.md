# D-035 — Atlas Workflow-First Operator UX

**Status:** Accepted

**Date:** 08/08/2026

## Decision

Atlas Application presentation is happy-path-first. Everything not needed for the ordinary task uses progressive disclosure or contextual exception presentation.

- The normal screen answers period, current state, attention required, main work surface, one next action, and its consequence in that order.
- At an ordinary lifecycle state, exactly one backend-authorized next action is visually dominant. Future lifecycle commands are not presented as disabled teaching controls.
- OPS v1 and retained Retool evidence inform familiar vocabulary, direct task sequence, table density, navigation and immediate actions. They do not define Atlas authority, calculation, security, lifecycle, persistence or application architecture.
- Atlas-only features are classified as core work, safety guardrail, exception/recovery, audit/support or technical implementation detail. Only core work is visible by default; guardrails and exceptions appear when relevant; audit/support evidence is subordinate; technical detail does not enter the normal reading flow.
- Normal operator language is concise Vietnamese business language. Technical identities and audit evidence remain available under `Chi tiết`, `Bằng chứng` or `Lịch sử`.
- Invalidation, exact retry, uncertain-outcome recovery and similar exception paths are contextual and do not compete with ordinary work.
- Every normal state must pass a five-second comprehension test for period, state, problem and next action, plus a first-time-operator test that requires no knowledge of Atlas database or architecture terminology.

Backend authority is unchanged. D-035 changes no business capability, object, contract, command, event, read model, calculation, persistence, permission or lifecycle rule.
