# Atlas document School grouping 02 implementation plan

> Execute the Owner's supplied 32-section task using test-driven development, bounded parallel ownership, and a final independent review. The Owner has authorized implementation and an isolated worktree.

**Goal:** Separate explicit Cooking Locations from Dispatch export groups while preserving immutable School documents and approved PO/PXK presentation.

**Architecture:** Evolve the existing Admin cooking-group authority with explicit location kind and host School ID; keep existing physical identity and compatibility fields. Add independent current Dispatch group membership. Freeze both relationships on future releases only. Export packaging derives exclusively from released evidence.

**Spec:** Owner request recorded in `docs/implementation-tasks/TASK-ATLAS-DOCUMENT-SCHOOL-GROUPING-02.md`.

## Global constraints

- Start at `2f3741f38fe26adc9505ffd773c07c11c70b8c0e`; preserve the original dirty checkout.
- No staging deployment, live OPS writes, Retool changes, historical backfill, font distribution, new dependencies, workflow lifecycle, or general UI polish.
- School IDs determine self-cooking and membership. PO detail always retains School identity. Exact quantities use decimal strings/BigInt.
- Hosted relationships require controlled master reconciliation; fail closed with `SCHOOL_MASTER_RECONCILIATION_REQUIRED`.

## Tasks

1. **Backend authority and snapshots** — append CLI-created migration; evolve cooking authority, add private forced-RLS Dispatch authority and shaped APIs, freeze explicit location and Dispatch evidence; add Admin, snapshot, immutability, and security pgTAP tests. Preserve 97 applied migrations. Update affected API contracts and exact platform catalog.
2. **Admin controls** — extend master-data types/API registry, existing School controller and editor with independent `Nấu tại` and `Nhóm Dispatch` facts. Typed location kind/host selection and Dispatch maintenance use backend commands, versions and readback. Add independence, denied/dirty/replay-aware UI tests.
3. **Measured row heights** — measure installed Times New Roman 14 pt glyph advances without distributing fonts; commit deterministic metrics/provenance and word-aware wrap helper using actual visible Excel widths. Test explicit newlines, long tokens, diacritics, 1–5+ lines and narrower cells.
4. **Export semantics** — preserve PO School bands, use stable ID self-cooking label, aggregate Dispatch only by captured group/date/Ingredient/Unit/note, preserve hidden plural source lineage and old releases as separate. Add Owner matrix, metadata, and Shopping List regressions.
5. **Reconciliation and ordering** — inspect controlled master adoption evidence read-only; add strict ID-based configuration/preflight and stable adjacency tests for Bình Quới and Hùng Vương without unrelated sorting. No hosted configuration when identities remain unresolved.
6. **Validation and handoff** — focused and full SQL/replay, frontend format/typecheck/test/build, native Excel clipping QA, independent review, one committed Draft PR, exact-head GitHub checks. Keep blockers explicit and never merge/deploy.

## Review focus

- Historical absent location kind/host must not fabricate self-cooking or Dispatch grouping.
- Admin reassignments must never change prior released evidence.
- Grouped output must retain all School document/source identities and differing notes/Units/dates.
- Hidden metadata columns contribute zero School-band width.
- Unreconciled v1-school-10 and missing Hùng Vương cannot receive name-derived configuration.

## Progress

- Workspace verified clean; bounded task branch created. Original checkout untouched.
- Backend authority, immutable future snapshots, independent Admin controls, measured PO/PXK headers, Dispatch grouping and fail-closed configuration planning implemented.
- Focused SQL, Admin/API, export/Shopping List, measurement and ordering tests pass. Fresh chronological replay applies all 98 migrations; no hosted writes.
- Local frontend format/typecheck/build and UI boundary checks pass. Full local frontend run stopped after unchanged recipe-screen timeouts during database replay; required GitHub frontend certification remains the full-suite gate.
- Native open/save/reopen/PDF verification passes for four fixture workbooks. Printed glyph and physical width/font/formula QA pass for 25 PO/PXK School rows and three PXK-number headers; exact formula preserved. Grouped number headers expand to retain all five Hùng Vương release numbers.
- Final independent review found no remaining actionable defects after the Company-name, unresolved-location, PXK-height and tied-order corrections.
- Full local backend certification is blocked by the existing Storage container health failure during reset. GitHub full integration remains required.
- Hosted Owner configuration is blocked by unreconciled School identities; the implementation fails closed and preserves released history.
- One [Draft PR #363](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/363) created. Exact-head GitHub frontend and explicitly dispatched full backend integration are tracked there. No merge/deployment is authorized.
