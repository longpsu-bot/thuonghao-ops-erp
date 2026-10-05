# Atlas Persistent Workspace Implementation Plan

**Goal:** Implement approved D-048 / Design Language v2 in the production composition.

**Spec:** `docs/implementation-tasks/TASK-ATLAS-UI-VNEXT-03C-PERSISTENT-WORKSPACE-PRODUCTION.md`.

**Architecture:** Static seven-destination registry, local ordered-ID reducer, stable keyed mounted panels. Explicit owner callbacks report only unsaved/blocked/attention presentation. Existing backend and exit guards retain authority.

## Constraints and public seams

- Use this authorized checkout and branch only, starting at `7629ccfdcd88e41a2dfa094c6a7b9719a94d9659`.
- No backend, Retool, hosted write, dependency, lifecycle or business contract changes.
- Production App/workbench operator interactions are the approved public test seam; external APIs and time are fixture boundaries.
- Switch never exits, remounts or reads. Close invokes the owner guard. Dirty sign-out discards nothing.
- Workbench state remains local. Registry contains only seven real destinations.
- DateInput retains Chakra 3.37 and the approved Vietnamese presentation.

## 03C-A

- [ ] Static registry, ordered-ID reducer and stable persistent panels in App; owner-scoped portals and hidden/inert panels.
- [ ] Explicit status callbacks from every editable owner; Planning owns its mount-seeded date. Procurement reports date/stage only for truthful navigation disclosure.
- [ ] Recipe exact metadata/BOM/change-order dirty status and timer audit.
- [ ] DatePicker source audit, smallest bounded correction, keyboard/pending-announcement tests.
- [ ] App integration tests: retention, reads, close, sign-out, identity, handoff, modal safety and accessibility.

## 03C-B

- [ ] Registry launcher, compact account utility, attached desktop tabs, mobile open selector and 12-descriptor fixture.
- [ ] Central v2 geometry/type adoption; bounded four-surface finish.
- [ ] Screenshot matrix and Impeccable review, Ponytail review, requested validation, draft PR and exact-head CI.

## Ownership / preflight

| Work         | Ownership                                                       | Shared interface                                   | Result                                        |
| ------------ | --------------------------------------------------------------- | -------------------------------------------------- | --------------------------------------------- |
| Workspace    | App, Shell, Registry, reducer, Provider, shared status contract | `onWorkspaceStatus({unsaved, blocked, attention})` | No overlapping worker writes                  |
| Recipe       | `recipes/`                                                      | Existing exit guard + status callback              | Local dirty baselines remain owner-controlled |
| Other owners | schools, master-data, Planning, Need, Procurement, PXK          | Same callback; Procurement date/stage report       | Navigation metadata only                      |
| DateInput    | DateInput and its focused tests                                 | Owner visibility from existing portal scope        | No provider/bootstrap replacement             |

Tasks share the status/visibility interfaces only; root owns those definitions. A precedes visual adoption. Each implementation receives focused review; final review uses the fixed starting SHA.
