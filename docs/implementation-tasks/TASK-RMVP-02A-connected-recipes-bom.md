# TASK-RMVP-02A — Connected Dishes, Recipes, and BOM

## Outcome

Deliver one migration and a connected Vietnamese `Công thức` experience for Dish governance, scoped Recipe roots, versioned BOM maintenance, validation, Planning release, correction successors, copy, and narrow reviewed OPS v1 `.xlsx` import.

## Allowed scope

- Existing `atlas_admin` recipe foundation and existing `atlas_core`, `atlas_audit`, `atlas_api`, and typed `atlas_legacy` evidence
- Existing `atlas_master_data_command_runtime` and `atlas_read_runtime`
- One shaped read, eleven bounded commands, and five recipe capabilities
- Existing Atlas React shell and consolidated Dish/Recipe workbench
- One exact workbook dependency, focused tests, local acceptance, documentation, and the existing CI workflow

## Prohibited changes

- No new database role or business table
- No generic workbook or CRUD framework
- No new operating stage or module boundary
- No automatic creation of missing reference data
- No direct browser access to private schemas or service-role credential
- No mutation of validated, released, or locked composition
- No silent line omission or historical rewrite
- No automatic import validation or Planning release
- No hosted, production, OPS v1/v2, or Retool mutation
- No second migration or new CI workflow

## Acceptance criteria

- Fresh local migration exposes exactly 40 reviewed Atlas RPCs and preserves the private-table boundary.
- Authorized reads return the nested workbench; denied, unauthenticated, and lost-session states fail closed.
- Dish create/edit/lifecycle and Recipe-root lifecycle use optimistic concurrency, receipts, events, audit, and authoritative readback.
- A full draft BOM replacement is atomic and rejects stale versions, inactive references, duplicates, and invalid quantities.
- Validation materializes immutable stable-line revisions once.
- Planning release is explicit; a successor release locks the prior release.
- Successors preserve exact version and line predecessors, including explicit removed-line revisions.
- Copy previews the complete source composition (line, Ingredient, quantity,
  Unit, disposition, and note) and creates a traceable draft only.
- The authenticated browser-key acceptance proves initial release, successor
  stable-line correction, validation, release, prior locking and unchanged
  composition, exact version/revision lineage, reauthentication, and
  authoritative readback of both versions.
- The narrow `.xlsx` parser supports Vietnamese headers and decimal commas, resolves existing references, and calculates canonical SHA-256.
- Import rejects missing references without partial writes, reconciles typed mappings, creates draft-only state, and replays an identical checksum without duplicate writes.
- Connected and review-mode UI tests cover operator-critical states and the future-planning boundary.
- Documentation states security, migration, rollback, and production exclusions.

## Verification

```bash
pnpm exec supabase db reset --local
pnpm exec supabase test db supabase/tests/rmvp_02a_connected_recipes_bom.sql --local
pnpm exec supabase test db supabase/tests/rmvp_01_atlas_master_data.sql --local
pnpm exec supabase test db supabase/tests/pa_06e_h0a2_recipe_bom_immutable_reference_foundation.sql --local
pnpm exec supabase test db supabase/tests/atlas_current_platform_security_catalog.sql --local
pnpm local:auth:provision
pnpm local:master-data:import -- --file supabase/local/rmvp_01_master_data_snapshot.example.json
pnpm local:rmvp02a:verify
pnpm typecheck
pnpm test
pnpm build
```

GitHub Actions owns the routine frozen install, formatting, typecheck, test, build, whitespace, and local Supabase integration suite on the pull request.
