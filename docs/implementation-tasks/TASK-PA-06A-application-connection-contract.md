# TASK-PA-06A — Application Connection Contract

**Status:** Implemented as a documentation-only review change; pending draft-PR review
**Baseline:** `59640c33ec3eb759c28659991a751261cdb352ab`
**Branch:** `docs/pa-06a-application-connection-contract`
**Draft PR title:** `PA-06A: Define application connection contract`
**Execution settings:** Sol; Medium reasoning; one agent; parallel agents off; subagents off

## 1. Objective

Define the smallest practical application contract for consuming the accepted 18-function Atlas backend while preserving backend authority, operator visibility, security boundaries, and the current no-hosted-target decision.

PA-06A is documentation and planning only.

## 2. Allowed files

Required:

- `docs/architecture/pa-06a-application-connection-contract.md`;
- `docs/ui/pa-06a-operator-workflow-matrix.md`;
- `docs/ui/pa-06a-screen-workbench-and-io-map.md`;
- `docs/architecture/pa-06a-environment-deployment-contract.md`;
- `docs/implementation-tasks/TASK-PA-06A-application-connection-contract.md`.

Optional narrow status/link updates only:

- `README.md`;
- `docs/architecture/roadmap.md`.

No broader documentation rewrite is allowed.

## 3. Prohibited changes

Do not change:

- `src/`;
- package or lock files;
- Supabase migrations or tests;
- generated types;
- backend functions, lifecycle, grants, RLS, or Auth;
- hosted Supabase;
- credentials;
- Vercel or DNS;
- Retool or OPS v1;
- production data;
- Issue #105;
- another external service.

Do not create a GitHub issue unless separately authorized.

## 4. Required source review

Before editing, verify the canonical workspace and read:

- `AGENTS.md` and its mandatory documents;
- ARCH-001 and ARCH-002;
- PA-05A through PA-05G contracts relevant to the 18 functions;
- merged migrations and focused pgTAP;
- current Atlas page configuration, React shell, workbench components, and package baseline;
- active and superseded prototype UI documents;
- hosted Supabase settings and security advisors read-only;
- four Retool JSON exports for operator evidence only.

## 5. Deliverables and ownership

| Deliverable | Owning document |
|---|---|
| OPS_SYSTEM_MAP capability map | Application Connection Contract |
| Canonical 14-command/four-read registry | Application Connection Contract |
| Client ownership matrix | Application Connection Contract |
| AGENTS three-stage reconciliation | Application Connection Contract |
| Evidence-based first-slice comparison | Application Connection Contract |
| Operator workflow matrix | Operator Workflow Matrix |
| Workbench and screen map | Screen, Workbench, and I/O Map |
| Formal read-gap register | Screen, Workbench, and I/O Map |
| Input/output diagrams | Screen, Workbench, and I/O Map |
| Retool ergonomics boundary | Screen, Workbench, and I/O Map |
| Environment, Auth, migration, coexistence, rollback gates | Environment and Deployment Contract |
| Simplicity, validation, publication, and stop conditions | This task document |

The exact API contract must not be duplicated outside the canonical registry.

## 6. Acceptance criteria

### 6.1 API and client contract

- all 18 reviewed functions have stable registry IDs;
- every entry records exact function, version, capability, payload/selector, aggregate, consumed/returned IDs and versions, transition, warnings/blockers, safe errors, stale, retry, replay, changed reuse, audit/trace, and next action;
- common command envelope and safe outcome shape are documented once;
- no document invents a command or read;
- client ownership is explicit without moving business authority into React.

### 6.2 Operator visibility

- every required workflow names operator, trigger, goal, prerequisite, information, registry entry, transition, version, success, blockers, stale/retry, audit, and next action;
- every proposed workbench distinguishes queue, detail, action, confirmation, outcome, and history;
- command outcome is more than a toast;
- input/output diagrams show concrete input and output categories.

### 6.3 Read gaps

- every proposed queue/list/search/dashboard/selector is classified 1 through 5;
- each row identifies the current read, known selector, selector source, and direct-table consequence;
- no production queue depends on private-table access;
- fixture-context behavior is labeled;
- a separately approved bounded discovery read is required where necessary.

### 6.4 Baseline and repository consistency

- the AGENTS three-stage baseline is explicitly reconciled;
- exact frontend paths are cited;
- active and superseded prototype documents are distinguished;
- current absence of a Supabase client dependency is recorded;
- no unsupported prototype transition is treated as implemented.

### 6.5 Environment and Retool boundaries

- `qnthofvccilhnefdcxnz` is explicitly rejected as an assumed Atlas target;
- Issue #105 remains separate;
- no environment, key, Auth, Vercel, DNS, Retool, or deployment action is authorized;
- Retool contributes ergonomics only, not SQL or UI-owned business logic.

## 7. Simplicity and dependency gate

Every later proposal must answer:

1. Which approved workflow requires it?
2. What becomes difficult or unsafe without it?
3. Why are existing React or browser capabilities insufficient?
4. What maintenance and onboarding cost does it add?
5. What is the smaller alternative?

| Proposed later item | Approved workflow requiring it | Difficulty or safety failure without it | Why existing capability is insufficient | Maintenance/onboarding cost | Smaller alternative / decision |
|---|---|---|---|---|---|
| `@supabase/supabase-js` | Any authenticated PA-06B/PA-06C API call | Session refresh and RPC calls would be hand-built and inconsistent | `fetch` has no built-in Supabase Auth lifecycle or typed RPC convention | One runtime dependency and Supabase-specific onboarding | Direct `fetch` is smaller in bytes but less safe; recommend only after PA-06B approval |
| One Supabase client module | All connected workflows | Multiple clients may diverge in session and environment handling | React alone does not construct the service client | Small module and environment validation | Inline client per screen rejected |
| Narrow typed `atlasApi` adapter | More than one connected command/read | RPC names, envelopes, and safe mapping would be duplicated | Components should not encode transport and contract plumbing | Small adapter surface; requires keeping registry/types aligned | Per-screen calls acceptable only for a one-call spike; adapter is smaller for a real slice |
| Auth session boundary | All connected screens | Session expiry and subject propagation become inconsistent | Repeated component subscriptions are error-prone | One provider and Auth mental model | Prop drilling for one screen; choose Context only when multiple descendants need it |
| Auth hook | Multiple components reading the same Auth boundary | Repeated null/expired checks and subscriptions | Plain Context access can be verbose | One hook to learn/test | Use direct Context if only one consumer |
| Immutable command-intent helper | Every write | Retries may regenerate IDs, timestamp, or key and break replay semantics | React state does not define request identity by itself | Small pure utility | Inline construction is acceptable for one test but unsafe when retry exists |
| Workbench-local `useReducer` | Evidence or Dispatch multi-step screen | Form, confirmation, request, outcome, and stale state may drift | Multiple independent `useState` calls can become inconsistent | Local reducer events to learn | Use `useState` until transitions become coupled |
| Global state container | None currently | No concrete failure exists | Context/local state are sufficient | High conceptual and dependency cost | Reject Redux/Zustand |
| Query library | None currently | No demonstrated caching or invalidation failure | Explicit bounded reads are few and selector-driven | Dependency, cache semantics, onboarding | Reject until multiple screens prove need |
| Form framework | None currently | Current approved forms are small and exact | Controlled inputs and local validation are sufficient | Dependency and schema integration cost | Reject |
| Router dependency | None for first pilot | Existing page state can open one workbench | Deep linking/Auth callback requirements are not yet approved | Route configuration and migration cost | Keep current page switching; revisit when a concrete route is required |
| Browser UUID helper | Every write/read journey | Command/correlation IDs need collision-resistant generation | `crypto.randomUUID()` already exists | No dependency | Use browser API |
| Safe error mapper | All connected writes/reads | Components may expose raw transport details or misclassify stale/retry | Repeating switches in screens is inconsistent | Small pure mapping module | Inline mapping for one spike; shared mapper for first real slice |
| Command outcome component | Every write workbench | IDs, versions, events, replay, warnings, and blockers would be hidden in toasts | Existing `Panel`/`Chip` are visual primitives, not an outcome contract | Small reusable presentation component | Compose existing primitives first; extract only after repeated use |
| Confirmation component | Release, Evidence application, load, departure, delivery, closure | Operators cannot review authoritative target/transition | Browser confirm lacks structured business context | Small UI pattern | Slice-specific panel before generic extraction |
| Trace/Audit panel extension | First slice with READ-04 | Static trace cannot show receipt/events/audit/versions | Existing `TracePanel` is fixture-only | Moderate data-shape and state work | Extend existing panel, do not build reporting framework |
| Dedicated workbench screens | Approved workflow groups | One page per command fragments operator context | Existing prototype pages do not match accepted transitions exactly | Each screen adds training and tests | Use five coherent workbenches, connect one first |
| `VITE_SUPABASE_URL` | PA-06B | Client cannot select an approved environment | Browser cannot infer a target safely | One deployment variable | None |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | PA-06B | Browser cannot authenticate or call Data API | No safe implicit credential exists | One non-secret deployment variable | None; never use service role |
| Response fixture factory | Repeated contract/UI tests | Large inline objects become inconsistent | Plain literals are sufficient initially | Small test utility to maintain | Add only after duplication appears |
| Storybook state fixtures | Operator review of connected screen states | Stale/replay/denied/empty states are hard to review | Unit tests do not provide visual review | Story maintenance | Add only states required by the first connected slice |

## 8. Later implementation testing strategy

A PA-06B/PA-06C implementation should include the minimum:

- exact request-shape construction;
- exact response-shape mapping;
- stale-version behavior;
- exact replay behavior;
- retryable concurrency behavior;
- capability and scope denial;
- session expiry;
- loading, missing-context, empty, success, blocker, and safe-error rendering;
- no service-role variable or credential;
- no direct private-table operation;
- one complete operator workflow integration test;
- Storybook states for idle, loading, confirmation, success, replay, stale, retryable, denied, and expired session.

## 9. Validation ownership

Before editing in a normal canonical checkout:

```bash
git rev-parse --show-toplevel
git remote -v
git fetch origin
git branch --show-current
git status --short
pnpm ops:workspace
```

During PA-06A:

- run focused Markdown formatting checks only;
- run `git diff --check`;
- inspect changed paths and the complete diff;
- do not run the routine full frontend suite locally.

GitHub Actions owns:

- frozen installation;
- workspace validation;
- formatting;
- typecheck;
- complete application tests;
- build;
- Storybook build;
- artifacts;
- diff validation;
- Qodana where configured.

## 10. Publication

After focused validation:

1. commit intentionally on `docs/pa-06a-application-connection-contract`;
2. push the bounded branch;
3. open a draft pull request titled `PA-06A: Define application connection contract`;
4. leave it draft;
5. do not mark ready;
6. do not merge;
7. do not deploy;
8. do not wait for GitHub Actions.

No issue is created without separate authorization.

## 11. Stop conditions

Stop and report rather than improvise if:

- the accepted 18-function surface differs from the merged migrations/tests;
- an exact registry field cannot be grounded;
- a production workflow needs private-table access;
- a new read or command appears necessary;
- the supplier-direct path cannot be reconciled without changing AGENTS governance;
- a dependency is justified only by hypothetical future modules;
- a hosted project, Auth change, credential, or deployment is required;
- the diff needs files outside the allowed scope;
- the live OPS v1 project would become an Atlas dependency.

## 12. Completion boundary

PA-06A is complete when the five documents are internally consistent and reviewable.

It does not authorize PA-06B or PA-06C. The next approved step must separately decide:

- isolated environment ownership;
- Auth test identities;
- whether a bounded discovery read is required before a production operator queue;
- the exact first connected slice and its implementation file scope.
