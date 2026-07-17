# PA-06A — Environment and Deployment Contract

**Status:** Proposed documentation contract; pending review
**Scope:** Defines options and hard gates only; creates or changes no environment.

## 1. Hard decision

The hosted Supabase project:

```text
qnthofvccilhnefdcxnz
```

is the live OPS v1 project.

It is **not** an approved Atlas development, staging, preview, or production target. PA-06A does not recommend connecting Atlas React to it, does not deploy Atlas migrations to it, and does not modify its Auth, keys, grants, RLS, Data API configuration, data, or Retool resources.

Issue #105 remains a separate legacy-security inventory and remediation program. It is a deployment decision gate if a future proposal considers sharing the live project, but it is not part of PA-06A.

## 2. Environment matrix

| Environment | Purpose | Allowed data | Auth identity | Browser configuration | Migration owner | Creation status |
|---|---|---|---|---|---|---|
| Local fixture prototype | Review current in-memory UI and operator language | Static synthetic fixtures only | None required | No Supabase variables | Not applicable | Existing |
| Local Supabase development | Develop and test an approved connected slice | Version-controlled migrations and synthetic local data; no production copy | Local test users mapped to synthetic Atlas actors/capabilities/scopes | Local URL and publishable key only | Repository migrations; local reset | Not created by PA-06A |
| Isolated hosted development/staging | Shared authenticated review after separate approval | Synthetic or explicitly approved masked data only | Dedicated non-production users and Atlas actors/scopes | Hosted isolated URL and publishable key | Reviewed repository migration deployment | Not approved or created |
| Vercel preview | Review a connected frontend PR | Uses only an approved isolated Atlas environment | Same non-production Auth strategy | Preview-scoped URL and publishable key | No database ownership in Vercel | Not approved or created |
| Production Atlas | Future operator service | Production data only after migration, security, ownership, and cutover approval | Production Auth subjects mapped to governed Atlas actors | Production URL and publishable key | Reviewed release process from repository | Target not selected |
| Live OPS v1 | Continue current Retool operations during transition | Existing legacy production data | Existing OPS v1 identity/resource model | No Atlas React connection introduced by PA-06A | Existing legacy process | Existing; read-only review only |

## 3. Browser-safe configuration

A later approved PA-06B should require at most:

```text
VITE_SUPABASE_URL
VITE_SUPABASE_PUBLISHABLE_KEY
```

Rules:

- never expose a service-role key;
- never expose a database password, JWT secret, management token, or private diagnostic credential;
- environment owners configure variables in the deployment platform; developers do not commit values;
- local examples contain placeholders only;
- a frontend build must fail safely when required non-secret variables are absent;
- the application must identify its environment visibly enough to prevent fixture, staging, and production confusion.

PA-06A adds no variables or example file.

## 4. Auth identity contract

For a later connection:

- Supabase Auth session subject is the only browser source for `requested_by_auth_subject`;
- Atlas resolves the active actor and capability/scope server-side;
- the browser never supplies a service actor or management override;
- test users use synthetic, least-privilege actors and scopes;
- preview users do not share production identities;
- session expiry disables command submission;
- reauthentication does not automatically replay a pending write;
- role/capability/scope provisioning is migration or governed Admin work, not hidden frontend configuration.

## 5. Data contract

### Local fixture prototype

May use static data to review layout and language. It must remain labeled as local/non-authoritative.

### Local Supabase

May use deterministic synthetic records created by focused tests or separately approved local seeds. Synthetic data must preserve realistic identity, version, lineage, capability, and scope behavior.

### Isolated hosted development/staging

Requires separate approval for:

- project or branch cost;
- region;
- Auth strategy;
- Data API exposed schemas;
- migration deployment;
- synthetic or masked data set;
- retention and cleanup;
- operator access;
- rollback and support ownership.

### Production

Requires a separate cutover contract. No PA-06A statement selects the live OPS project or authorizes data migration.

## 6. Migration and schema ownership

- Git repository migrations are the sole source for Atlas schema changes.
- No manual hosted DDL is part of PA-06A.
- The browser may call only reviewed `atlas_api` functions.
- Private Atlas schemas remain inaccessible to browser API roles.
- Any new discovery read requires its own architecture contract, migration, pgTAP, security review, and forward rollback plan.
- Generated types, if later approved, are artifacts of one explicitly selected environment and must not become authority over migrations.

## 7. Deployment sequence

A future approved connected rollout should preserve:

```text
reviewed migration state
→ isolated environment
→ synthetic Auth actors/capabilities/scopes
→ PA-06B connection foundation
→ one bounded PA-06C pilot
→ focused operator review
→ security and read-gap decisions
→ production target and cutover approval
```

It must not jump from the local fixture prototype directly to live OPS v1.

## 8. Rollback boundaries

### Frontend rollback

Removing or reverting a connected workbench stops new browser calls. It does not undo commands already completed by the backend.

### Database rollback

Unshipped migrations are reverted in Git. Shipped migrations require a reviewed forward migration that preserves operational and audit history.

### Auth rollback

Test identities and scopes are removed or disabled through a separately approved identity procedure. The frontend does not delete Auth users automatically.

### Environment rollback

An isolated non-production environment may be paused or removed only after data-retention and cost ownership are confirmed. PA-06A creates none.

## 9. OPS v1 and Atlas coexistence

Business Rule BR-009 applies: one system owns writes for a workflow at a time.

During transition:

- Retool may continue to own approved OPS v1 workflows;
- an Atlas pilot owns only its explicitly approved synthetic or isolated workflow;
- no dual write is introduced;
- no browser-side replication or synchronization is introduced;
- no Retool query is silently redirected to Atlas;
- no Atlas command writes legacy `public` or `ops_v2` objects;
- cutover requires an explicit ownership matrix and smoke-test plan.

## 10. Security gate

The live project’s legacy exposure findings remain material, including broad legacy PostgREST reachability, RLS-disabled tables, permissive policies, security-definer objects, and mutable function search paths. PA-06A neither remediates nor accepts those risks.

A future proposal to use the same hosted project must first:

1. complete or explicitly accept Issue #105;
2. identify exact exposed schemas and API roles;
3. preserve Retool production call paths;
4. prove Atlas private-schema and function-only boundaries;
5. receive explicit environment and deployment approval.

## 11. Explicit non-actions

PA-06A does not create or modify:

- a Supabase project or branch;
- Atlas migrations on hosted Supabase;
- Auth configuration;
- keys or credentials;
- Vercel;
- DNS;
- deployment configuration;
- Retool;
- OPS v1;
- production data;
- Issue #105.
