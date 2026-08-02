# TASK-PANTRY-NG-02 — Direct Pantry Ingredient persistence and materialization

## Status

Implemented on branch `codex/pantry-ng-02-direct-ingredient-persistence-materialization` from exact baseline `249361bc0c4005e2c9a05e7b84a8468dd0ec4956`. The immutable implementation head is reported by the draft PR and final task handoff; embedding the SHA in the commit that defines that SHA would be self-referential.

GitHub Actions is the authoritative Supabase validation environment. The correction code head `111cfd1d4f3c1645ad220e7adef4139c84606f17` passed Supabase Integration, Frontend CI, UI Review Export, and Qodana on draft PR #167. The immutable final documentation-bearing head and its repeated exact-head results are reported by the draft PR and final task handoff.

The continuation from published head `39e1110843baad10a18842b20cca4ba810aa653a` expands the authorized manifest from fourteen to sixteen paths solely to correct two legacy H0B1b fixture helpers. Each helper now repeats the complete Pantry triple already owned by its Planning Input Evaluation. The production migration and integrity guard are unchanged: post-migration snapshots still cannot commit with missing or partial Pantry binding.

Independent review at published head `daf82adf3d31fa99f4b4b2691e306dd1a3da117f` found that the initial CMD-15 revision and contribution joins used a tautological Recipe destination branch. The same review found that the existing H0B1b every-and-only membership guard grouped released contributions without their effective Delivery Location. The forward PANTRY-NG-02 migration now corrects both existing function bodies in place, while preserving the exact sixteen-path manifest and every object/security ceiling.

## Bounded implementation

The implementation follows D-028 and PNG-P01 through PNG-P12. It adds one forward-only migration:

`supabase/migrations/20260802090000_pantry_ng_02_direct_ingredient_persistence_materialization.sql`

It alters only these existing relations:

- `atlas_planning.need_generation_input_snapshots`: three nullable historical-compatibility columns, an all-null-or-complete positive binding rule, the exact Pantry approval-snapshot ownership FK, and one supporting index.
- `atlas_planning.theoretical_need_lines`: seven columns, the closed `RECIPE_DERIVED` / `PANTRY_DIRECT` family, exactly twenty Recipe-only columns made nullable, family-dependent typed lineage, three partial atomic anchors, and Pantry lookup indexes.
- `atlas_planning.need_generation_issues`: three typed Pantry context columns, rebuilt nulls-not-distinct context uniqueness, typed FKs and indexes, and exactly three new blocking classifications.

Column arithmetic is exactly `3 + 7 + 3 = 13`. Named-constraint arithmetic is exactly `+15 / -4`: input snapshot `+2`, theoretical line `+7 / -2`, and issue `+6 / -2`. Physical-index arithmetic is exactly `+12 / -2`: input snapshot `+1`, theoretical line `+7 / -1`, and issue `+4 / -1`.

Exactly three existing function bodies are replaced without changing identity, signature, owner, security mode, search path, grants, policy, runtime, capability, or contract version:

1. `atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()`
2. `atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()`
3. `atlas_api.create_confirmed_needs_from_generation(jsonb)`

The object and security delta is zero for tables, views, APIs, private functions, capabilities, database roles, runtime roles, policies, positive grants, ordinary triggers, constraint triggers, upstream/source triggers, lifecycle states, scope kinds, and sequences. CMD-15 continues to use `PA-06E-H0C.v1`, capability `confirmed_need_generation.materialize`, and runtime `atlas_planning_materialization_runtime`. It reads no Pantry base relation.

## Historical evidence

Existing theoretical lines receive only the deterministic `RECIPE_DERIVED` default. Their IDs, quantities, dispositions, predecessors, Recipe lineage, calculation evidence, issues, and release membership are not rewritten.

The three Pantry input-binding columns remain physically nullable solely for historical Recipe-only snapshots. Historical rows stay all-null, readable, and immutable. The migration performs no evaluation-derived backfill and fabricates no Pantry identifier. Every newly inserted run/input snapshot must instead commit with the complete positive Pantry triple equal to its exact current Planning Input Evaluation; a missing or partial binding cannot commit even if `MISSING_PANTRY_INPUT_BINDING` is persisted as a blocker.

## Pantry persistence and predecessor compatibility

Every positive approved Pantry snapshot member inside the inclusive run period owns one active `PANTRY_DIRECT` atom with exact School, Delivery Location, date, Ingredient, Unit, quantity, snapshot, stable line, and active member. Out-of-period members create no line, issue, count, release member, predecessor, or removal obligation. Zero-line headers and positive snapshots with zero in-period members retain their mandatory header evidence.

A compatible Pantry predecessor fixes stable Pantry line, Planning Input Set, exact run period, service date, School, Delivery Location, and Ingredient. Requested quantity, Purpose, note, source-reference group, Unit, approval snapshot, and active snapshot member may change. A same-stable-line change to date, School, Delivery Location, or Ingredient requires `INVALID_PREDECESSOR` and prevents validation/release before CMD-15. Unit correction may keep its Need Generation predecessor but CMD-15 rejects it with the existing `SOURCE_SPLIT_MERGE_POLICY_REQUIRED` boundary.

## CMD-15 compatibility

Recipe initial materialization uses the School current default Delivery Location in stable-line creation, validation, group counting, revision grouping, and contribution mapping. Pantry uses `theoretical_need_lines.delivery_location_id` at every one of those boundaries. Recipe correction retains the prior immutable contribution location. No Recipe contribution can join a Pantry-location line merely because date, School, Ingredient, and Unit match.

The replaced H0B1b membership guard derives the per-revision effective destination by source family: Pantry uses the theoretical line's exact destination; an initial or genuinely new Recipe contribution uses the revision's captured current School default; and a Recipe successor uses its predecessor's immutable contribution destination. It retains nonempty every-and-only membership, exact totals, immutable membership, active-release partition completeness, and exactly-once current membership while rejecting cross-destination assignment, omission, and duplication.

Initial Recipe-only, Pantry-only, and mixed releases group by exact date, Customer, School, Delivery Location, Ingredient, and Unit while retaining one immutable contribution row per theoretical line. Pantry quantity/metadata corrections, new lines, partial group removals, and retirement of the final active Pantry group use existing Confirmed Need history. Recipe removal remains unchanged. No zero current revision is created for a retired group.

## Tests and validation ownership

Protected plans remain exactly:

- H0A5b: `43 / 60 / 76 / 64`
- H0Cb: `63 / 80 / 104 / 112`
- corrected H0B1b fixtures: `68 / 80`

The new focused suite is `supabase/tests/pantry_ng_02_direct_ingredient_persistence_materialization.sql` at exact `plan(144)`. Its arithmetic is `58 + 10 + 9 + 11 + 12 + 23 + 21 = 144`. The final 21 assertions now execute real CMD-15 transactional coverage for one Recipe and one Pantry contribution with the same date, School, Customer, Ingredient, and Unit but different destinations. They prove two separate stable lines and revisions, family-exact memberships, separate quantities, exactly-once partitioning, and response-count agreement. The H0B1b contribution suite remains exact `plan(80)` and now exercises both rejected cross-family destination assignments. Workflow registration produces the authoritative target of 36 pgTAP files and 2,178 assertions.

Local validation covers migration/static SQL inspection, exact manifest and plan arithmetic, formatting/whitespace checks, `pnpm ops:workspace`, forbidden-delta searches, and the three narrow database suites affected by the correction. GitHub Supabase Integration still owns the authoritative fresh seedless reset, all registered suites, synthetic identities, and browser-key checks. Frontend CI, UI Review Export, and Qodana remain required exact-head checks.

For the mixed-location correction, the complete local migration chain applied successfully through `20260802090000` on PostgreSQL 17.6. Kong remained unhealthy, so the documented `--ignore-health-check` startup mode was used solely to keep the local database available. The real focused suite passed `144/144`, the destination-aware H0B1b contribution suite passed `80/80`, and the existing Recipe-only H0Cb initial-materialization suite passed `80/80`. Local database advisors reported only six pre-existing multiple-permissive-policy performance warnings and no new security finding. The local stack was then stopped without deleting its backed-up volume.

GitHub Supabase Integration run `30745638419` completed the fresh seedless reset, all migrations, all 36 registered pgTAP files, the two corrected H0B1b suites at exact plans `68` and `80`, the focused suite at exact `plan(144)`, the remaining backend acceptance suites, synthetic identities, and browser-key checks. The accepted assertion-ownership ledger remains exactly `2,034 + 144 = 2,178`. The same successful pg_prove run emitted 2,239 runtime subtests because the three pre-existing `no_plan()` suites dynamically expand to 127 assertions, 61 more than the accepted ledger convention; no unrelated suite or plan was changed to conceal that distinction.

## Exact sixteen-path manifest

1. `supabase/migrations/20260802090000_pantry_ng_02_direct_ingredient_persistence_materialization.sql`
2. `supabase/tests/pantry_ng_02_direct_ingredient_persistence_materialization.sql`
3. `supabase/tests/pa_06e_h0a5b_need_generation_structure_security.sql`
4. `supabase/tests/pa_06e_h0a5b_need_generation_run_input_recipe_calculation_integrity.sql`
5. `supabase/tests/pa_06e_h0a5b_theoretical_line_source_predecessor_release_integrity.sql`
6. `supabase/tests/pa_06e_h0a5b_need_generation_lifecycle_issues_invalidation_history.sql`
7. `supabase/tests/pa_06e_h0cb_materialization_registry_security_catalog.sql`
8. `supabase/tests/pa_06e_h0cb_initial_materialization.sql`
9. `supabase/tests/pa_06e_h0cb_corrected_materialization_history.sql`
10. `supabase/tests/pa_06e_h0cb_errors_authorization_concurrency.sql`
11. `.github/workflows/supabase-integration.yml`
12. `docs/implementation-tasks/TASK-PANTRY-NG-02-direct-ingredient-persistence-materialization.md`
13. `docs/decisions/decision-register.md`
14. `docs/architecture/roadmap.md`
15. `supabase/tests/pa_06e_h0b1b_school_catering_identity_current_source.sql`
16. `supabase/tests/pa_06e_h0b1b_contribution_membership_total_partition_history.sql`

## Exclusions and remaining boundary

No hosted Supabase project, production data, Retool export, OPS v1/v2 surface, credential, Edge Function, deployed application, React/TypeScript file, generated type, Purchase Handoff, Procurement, Warehouse, Dispatch, or Pantry fulfilment behavior is changed. Connected Need Generation commands/workbench and any API/React work remain separately unauthorized.
