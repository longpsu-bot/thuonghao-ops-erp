-- The atomic daily command invokes deferred integrity triggers hundreds of
-- times (1,013 Need Generation checks and 552 Confirmed Need membership checks
-- for the real 304 -> 248 workload). Parameter-specific replanning amplifies
-- that fan-out and produced an 8,007.970 ms rollback failure; the identical
-- workload with generic plans completed in 4,594.096 ms. Scope the planner
-- choice to this command only. No role setting, timeout, query, trigger,
-- invariant, lifecycle, privilege, or public response changes.
alter function atlas_api.execute_need_generation(jsonb)
  set plan_cache_mode = 'force_generic_plan';
