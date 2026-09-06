# Atlas Model Convergence — Staging readiness and later cutover gate

**Current authorization:** Read-only inspection only.

**Permitted target for this inspection:** Atlas Staging `rnzxmxiiqgtdevzregff`.

**Forbidden write target:** live OPS `qnthofvccilhnefdcxnz`; Retool also remains unchanged.

**No deployment, hosted fixtures, data repair, migration application, function invocation that writes, grant change, role binding, or hosted branch creation is authorized.**

## 1. Observed starting point

The packet preparation recheck at **2026-09-06 08:36:35 Asia/Ho_Chi_Minh** returned:

| Observation                                    | Value                                       |
| ---------------------------------------------- | ------------------------------------------- |
| Staging migration tip                          | `20260904081048_master_data_creation_ux_02` |
| New effective-Recipe API identities present    | 0 of the 4 checked                          |
| Atlas tables inspected                         | 107                                         |
| Tables with RLS enabled / forced               | 107 / 107                                   |
| Existing Recipe roots by scope                 | 2 GENERAL, 1 TYPED                          |
| Readiness for the new canonical Recipe journey | NOT READY at this observation               |

This is a dated metadata observation, not proof of a defect in #257, not a current permanent fact, and not a security/business-journey certification. Repository main was separately rechecked as `a60085163ecbfde8dc5f7c2d97a454bc57ec0f60`.

## 2. Inspection method

Use a least-privilege authorized connection. Confirm the exact project reference before querying. Inspect catalog metadata and aggregate data only. Use a read-only transaction and a bounded statement timeout. Do not run an existing “verify” script until its side effects have been inspected; some verifiers create synthetic actors or business records.

Never test a mutating RPC on Staging under a rollback and describe it as read-only. Use CI's disposable database for command, receipt, lock, copy, rollback and authentication journeys.

### Migration and API metadata

```sql
BEGIN READ ONLY;
SET LOCAL statement_timeout = '10s';

SELECT version, name
FROM supabase_migrations.schema_migrations
ORDER BY version DESC
LIMIT 8;

SELECT n.nspname AS schema_name,
       p.proname,
       pg_get_function_identity_arguments(p.oid) AS arguments,
       pg_get_userbyid(p.proowner) AS owner,
       p.prosecdef,
       p.proconfig,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_exec,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_exec,
       has_function_privilege('service_role', p.oid, 'EXECUTE') AS service_role_exec
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'atlas_api'
  AND p.proname IN (
    'get_dish_recipe_operator_workbench',
    'get_recipe_effective_target_context',
    'resolve_system_effective_recipe_composition',
    'copy_dish_recipes'
  )
ORDER BY p.proname;

SELECT count(*) AS table_count,
       count(*) FILTER (WHERE c.relrowsecurity) AS rls_enabled,
       count(*) FILTER (WHERE c.relforcerowsecurity) AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname LIKE 'atlas_%' AND c.relkind = 'r';

SELECT grantee, table_schema, count(*) AS table_privilege_entries
FROM information_schema.role_table_grants
WHERE table_schema LIKE 'atlas_%'
  AND grantee IN ('anon', 'authenticated')
GROUP BY grantee, table_schema;

COMMIT;
```

The expected migration set at the audited baseline includes:

```text
20260905105253_recipe_effective_contract_01.sql
20260905161348_recipe_effective_product_model_correction.sql
20260906000923_recipe_active_on_create_lifecycle_correction.sql
```

Compare the full ordered repository migration delta and deployed definitions, not only the largest timestamp or the presence of function names. A function can exist with an older body. API existence alone also does not prove Data API schema exposure, real Actor capability/scope, browser connectivity, or valid business data.

### Canonical catalog and root coverage

Run this only after confirming these existing relations/columns are present. It reads aggregate gaps, not business rows for commit into the repository.

```sql
BEGIN READ ONLY;
SET LOCAL statement_timeout = '10s';

WITH expected(code) AS (
  VALUES ('v1-school-type-1'), ('v1-school-type-2')
)
SELECT e.code,
       count(t.school_type_id) AS matching_catalog_rows,
       count(t.school_type_id) FILTER (
         WHERE t.school_type_status = 'ACTIVE'
       ) AS active_catalog_rows
FROM expected e
LEFT JOIN atlas_admin.school_types t ON t.school_type_code = e.code
GROUP BY e.code
ORDER BY e.code;

WITH expected(code) AS (
  VALUES ('v1-school-type-1'), ('v1-school-type-2')
), coverage AS (
  SELECT d.dish_id, e.code,
         count(DISTINCT r.recipe_id) AS active_typed_roots,
         count(DISTINCT rv.recipe_version_id) AS current_released_versions
  FROM atlas_admin.dishes d
  CROSS JOIN expected e
  LEFT JOIN atlas_admin.school_types t
    ON t.school_type_code = e.code AND t.school_type_status = 'ACTIVE'
  LEFT JOIN atlas_admin.recipes r
    ON r.dish_id = d.dish_id
   AND r.school_type_id = t.school_type_id
   AND r.recipe_status = 'ACTIVE'
  LEFT JOIN atlas_admin.recipe_versions rv
    ON rv.recipe_id = r.recipe_id
   AND rv.recipe_version_status = 'RELEASED_FOR_PLANNING'
  WHERE d.dish_status = 'ACTIVE'
  GROUP BY d.dish_id, e.code
)
SELECT code,
       count(*) AS active_dish_contexts,
       count(*) FILTER (WHERE active_typed_roots = 0) AS missing_root_contexts,
       count(*) FILTER (WHERE active_typed_roots > 1) AS ambiguous_root_contexts,
       count(*) FILTER (WHERE current_released_versions = 0) AS not_effective_ready_contexts,
       count(*) FILTER (WHERE current_released_versions > 1) AS ambiguous_release_contexts
FROM coverage
GROUP BY code
ORDER BY code;

SELECT CASE WHEN school_type_id IS NULL THEN 'GENERAL' ELSE 'TYPED' END AS scope,
       count(*) AS recipe_roots
FROM atlas_admin.recipes
GROUP BY 1;

COMMIT;
```

A root-only Dish with no release is valid authoring data, not a corrupt record. Count it as not effective-ready, not as requiring fabricated content. Legacy GENERAL rows do not automatically need deletion. Readiness must be assessed for the exact Dishes/scopes intended for an authorized rehearsal, not by imposing a new global historical constraint.

## 3. Report requirements

Record project reference, timestamp, execution baseline, deployed migration delta, function owners/search paths/grants, exposure/connectivity status when actually verified, canonical catalog gaps, root/release coverage, known legacy shapes, and evidence limitations. Summaries committed to GitHub must omit credentials, raw operational rows, personal Actor details and tokens.

Use these report labels only; do not persist them as ERP states:

- **NOT READY:** a required migration/API/catalog/data condition is known missing.
- **READY FOR AUTHORIZED REHEARSAL:** metadata and intended fixture/data prerequisites are established, but a separately authorized hosted journey is still required.
- **NOT VERIFIED:** the check could not be performed or evidence is insufficient.

Do not claim hosted operability or deployment parity from frontend preview builds or disposable-Supabase CI.

## 4. Separate later authorization

A later Staging deployment/cutover task needs explicit approval of the exact target, reviewed code/migration artifact, verified migration delta, data reconciliation plan, backup/recovery policy, authorized test identities, allowed write operations and post-deployment acceptance cases.

That future plan must reconcile legacy Dishes to the canonical typed scopes without inventing BOMs, rewriting immutable Recipe history, substituting GENERAL fallback, or creating production data from test fixtures. Missing business data requires explicit disposition. Reviewed migrations remain forward-only; do not rewrite migration history or repair it to manufacture parity.

It must verify the full operator journey with actual authenticated browser contracts after deployment and retain the existing downstream commitment protections. Live OPS and Retool remain outside the Atlas deployment target.

This packet prepares the gate and read-only evidence only. It supplies no command to deploy or mutate hosted data.
