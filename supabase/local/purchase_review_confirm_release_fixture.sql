-- Include inside a rolled-back pgTAP transaction. No replica mode or guard bypass.
\ir pa_06b_synthetic_identity.sql
set local atlas.test_generated_rice_quantity='100.000000';
\ir rmvp_05_browser_fixture.sql
\ir school_catering_procurement_verifier_fixture.sql
-- The shared fixture verifies its own deferred guards at exit. Restore normal
-- transaction timing before exercising commands that append successor evidence.
set constraints all deferred;
insert into atlas_core.role_capabilities(role_id,capability_id)
select 'b6000000-0000-0000-0000-000000000003',capability_id
from atlas_core.capabilities where capability_code in (
  'confirmed_need_release.release','confirmed_need_approval.approve',
  'confirmed_need_validation.validate') on conflict do nothing;
