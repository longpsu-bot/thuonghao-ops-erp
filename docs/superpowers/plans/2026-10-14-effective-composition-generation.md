# Effective composition Need Generation correction

**Goal:** Implement ATLAS-EFFECTIVE-COMPOSITION-GENERATION-01, the Product-approved 14 October 2026 amendment, from main `0934f4dcc19a36f47d0f1eb79f889405039c66fc`.

**Architecture:** Reuse the canonical Recipe resolver at the selected Menu assignment context. Generalize generated composition-use evidence, preserving exact base identities and admitting typed ADD identities. Immutable selection and line captures become the calculation evidence; later resolution is used only to derive currentness.

**Constraints:** One task branch and one Draft PR. Forward migration 107 only; migrations 1–106 stay untouched. Preserve source selection, arithmetic, Pantry, zero-demand, quantity policy, authorization and Procurement semantics. No hosted deployment, business writes, accounts or legacy import.

- [ ] Add a synthetic effective-read versus generation regression and demonstrate failure on migration 106.
- [ ] Implement selection-level resolution, immutable effective-line lineage, complete deferred guards and correction/currentness in migration 107.
- [ ] Exercise no-adjustment equivalence, all adjustment actions/layers, dated revision changes, correction, zero demand and mixed Pantry.
- [ ] Run Recipe, RMVP-04, Planning, Confirmed Need, Procurement, security/catalog and operational scale regressions.
- [ ] Append dated amendments to authoritative contracts and registers; record compatibility and rollback effects.
- [ ] Obtain independent code review, push, open one Draft PR and complete Supabase Full Integration and applicable Frontend CI.
