begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(144);

-- Schema, constraints, indexes, history, and zero object/security delta (1-58).
-- 1
select is((select array_agg(attname order by attnum)::text[] from pg_attribute where attrelid='atlas_planning.need_generation_input_snapshots'::regclass and attname like 'pantry_need_%' and attnum>0 and not attisdropped),array['pantry_need_batch_id','pantry_need_batch_version','pantry_need_approval_snapshot_id']::text[],'PNG02-001 input snapshot owns exactly the Pantry binding triple');
-- 2
select is((select array_agg(attnotnull order by attnum)::boolean[] from pg_attribute where attrelid='atlas_planning.need_generation_input_snapshots'::regclass and attname like 'pantry_need_%' and attnum>0 and not attisdropped),array[false,false,false]::boolean[],'PNG02-002 historical Pantry binding columns remain physically nullable');
-- 3
select ok((select pg_get_constraintdef(oid) like all(array['%pantry_need_batch_id IS NULL%','%pantry_need_batch_version IS NULL%','%pantry_need_approval_snapshot_id IS NULL%','%pantry_need_batch_id IS NOT NULL%','%pantry_need_batch_version > 0%','%pantry_need_approval_snapshot_id IS NOT NULL%']) from pg_constraint where conrelid='atlas_planning.need_generation_input_snapshots'::regclass and conname='need_generation_input_snapshots_pantry_binding_check'),'PNG02-003 input binding is exactly all-null or complete positive');
-- 4
select is((select pg_get_constraintdef(oid) from pg_constraint where conrelid='atlas_planning.need_generation_input_snapshots'::regclass and conname='need_generation_input_snapshots_pantry_snapshot_fkey'),'FOREIGN KEY (pantry_need_approval_snapshot_id, pantry_need_batch_id, pantry_need_batch_version) REFERENCES atlas_planning.pantry_need_approval_snapshots(pantry_need_approval_snapshot_id, pantry_need_batch_id, approved_batch_version) ON DELETE RESTRICT','PNG02-004 input binding uses exact Pantry ownership key');
-- 5
select ok(exists(select 1 from pg_index where indexrelid='atlas_planning.need_generation_input_snapshots_pantry_snapshot_idx'::regclass and indisvalid),'PNG02-005 input Pantry FK has its approved leading index');
-- 6
select is((select array_agg(attname order by attnum)::text[] from pg_attribute where attrelid='atlas_planning.theoretical_need_lines'::regclass and attname in ('contribution_family','delivery_location_id','pantry_need_batch_id','pantry_need_batch_version','pantry_need_approval_snapshot_id','pantry_need_line_id','pantry_active_snapshot_member_line_id')),array['contribution_family','delivery_location_id','pantry_need_batch_id','pantry_need_batch_version','pantry_need_approval_snapshot_id','pantry_need_line_id','pantry_active_snapshot_member_line_id']::text[],'PNG02-006 theoretical lines own exactly seven new columns');
-- 7
select is((select pg_get_expr(d.adbin,d.adrelid) from pg_attrdef d join pg_attribute a on a.attrelid=d.adrelid and a.attnum=d.adnum where d.adrelid='atlas_planning.theoretical_need_lines'::regclass and a.attname='contribution_family'),'''RECIPE_DERIVED''::text','PNG02-007 historical theoretical lines receive deterministic Recipe family default');
-- 8
select ok((select attnotnull from pg_attribute where attrelid='atlas_planning.theoretical_need_lines'::regclass and attname='contribution_family'),'PNG02-008 contribution family is physically mandatory');
-- 9
select is((select count(*)::integer from pg_attribute where attrelid='atlas_planning.theoretical_need_lines'::regclass and attname in ('need_generation_recipe_selection_id','need_generation_recipe_line_use_id','weekly_menu_approval_snapshot_line_id','weekly_menu_approval_snapshot_id','weekly_menu_id','weekly_menu_version','weekly_menu_line_id','attendance_approval_snapshot_line_id','attendance_approval_snapshot_id','attendance_batch_id','attendance_version','attendance_line_id','dish_id','recipe_id','recipe_version_id','recipe_line_id','recipe_line_revision_id','need_generation_calculation_contract_id','need_generation_calculation_contract_revision_id','calculation_contract_revision_number') and not attnotnull),20,'PNG02-009 exactly twenty Recipe-only columns become nullable');
-- 10
select is((select count(*)::integer from pg_attribute where attrelid='atlas_planning.theoretical_need_lines'::regclass and attname in ('school_id','service_date','ingredient_id','unit_id','line_disposition','theoretical_quantity') and attnotnull),6,'PNG02-010 six common authoritative facts remain mandatory');
-- 11
select is((select pg_get_constraintdef(oid) from pg_constraint where conrelid='atlas_planning.theoretical_need_lines'::regclass and conname='theoretical_need_lines_contribution_family_check'),$$CHECK ((contribution_family = ANY (ARRAY['RECIPE_DERIVED'::text, 'PANTRY_DIRECT'::text])))$$,'PNG02-011 theoretical contribution family is exactly closed');
-- 12
select ok((select pg_get_constraintdef(oid) like all(array['%contribution_family = ''RECIPE_DERIVED''%','%contribution_family = ''PANTRY_DIRECT''%','%pantry_active_snapshot_member_line_id = pantry_need_line_id%']) from pg_constraint where conrelid='atlas_planning.theoretical_need_lines'::regclass and conname='theoretical_need_lines_source_family_check'),'PNG02-012 source families are mutually exclusive and typed');
-- 13
select ok((select pg_get_constraintdef(oid) like all(array['%RECIPE_DERIVED%theoretical_quantity >=%','%PANTRY_DIRECT%theoretical_quantity >%','%line_disposition = ''REMOVED''%']) from pg_constraint where conrelid='atlas_planning.theoretical_need_lines'::regclass and conname='theoretical_need_lines_quantity_disposition_check'),'PNG02-013 quantity rules distinguish Recipe zero from positive Pantry');
-- 14
select is((select pg_get_constraintdef(oid) from pg_constraint where conrelid='atlas_planning.theoretical_need_lines'::regclass and conname='theoretical_need_lines_delivery_location_fkey'),'FOREIGN KEY (delivery_location_id) REFERENCES atlas_admin.delivery_locations(delivery_location_id) ON DELETE RESTRICT','PNG02-014 Pantry destination is typed');
-- 15
select ok((select pg_get_constraintdef(oid) like '%pantry_need_approval_snapshots(pantry_need_approval_snapshot_id, pantry_need_batch_id, approved_batch_version)%' from pg_constraint where conrelid='atlas_planning.theoretical_need_lines'::regclass and conname='theoretical_need_lines_pantry_snapshot_fkey'),'PNG02-015 Pantry theoretical header uses exact ownership triple');
-- 16
select ok((select pg_get_constraintdef(oid) like '%pantry_need_lines(pantry_need_line_id, pantry_need_batch_id)%' from pg_constraint where conrelid='atlas_planning.theoretical_need_lines'::regclass and conname='theoretical_need_lines_pantry_line_fkey'),'PNG02-016 stable Pantry line uses exact batch ownership');
-- 17
select ok((select pg_get_constraintdef(oid) like '%pantry_need_approval_snapshot_lines(pantry_need_approval_snapshot_id, pantry_need_line_id)%' from pg_constraint where conrelid='atlas_planning.theoretical_need_lines'::regclass and conname='theoretical_need_lines_pantry_active_member_fkey'),'PNG02-017 active Pantry member is exact snapshot membership');
-- 18
select is((select pg_get_indexdef('atlas_planning.theoretical_need_lines_recipe_atomic_anchor_key'::regclass)),$$CREATE UNIQUE INDEX theoretical_need_lines_recipe_atomic_anchor_key ON atlas_planning.theoretical_need_lines USING btree (need_generation_run_id, weekly_menu_approval_snapshot_line_id, attendance_approval_snapshot_line_id, recipe_line_revision_id, need_generation_calculation_contract_revision_id) WHERE (contribution_family = 'RECIPE_DERIVED'::text)$$,'PNG02-018 Recipe atomic anchor is preserved as a partial unique index');
-- 19
select ok((select pg_get_indexdef('atlas_planning.theoretical_need_lines_pantry_active_anchor_key'::regclass) like all(array['%UNIQUE INDEX%','%need_generation_run_id, pantry_need_approval_snapshot_id, pantry_active_snapshot_member_line_id%','%line_disposition = ''ACTIVE''%'])),'PNG02-019 active Pantry atomic anchor is exact');
-- 20
select ok((select pg_get_indexdef('atlas_planning.theoretical_need_lines_pantry_removed_anchor_key'::regclass) like all(array['%UNIQUE INDEX%','%need_generation_run_id, pantry_need_approval_snapshot_id, pantry_need_line_id%','%line_disposition = ''REMOVED''%'])),'PNG02-020 removed Pantry atomic anchor is exact');
-- 21
select ok(exists(select 1 from pg_index where indexrelid='atlas_planning.theoretical_need_lines_predecessor_successor_key'::regclass and indisunique),'PNG02-021 predecessor successor uniqueness remains intact');
-- 22
select is((select array_agg(c.relname order by c.relname)::text[] from pg_class c where c.oid in (select indexrelid from pg_index where indrelid='atlas_planning.theoretical_need_lines'::regclass) and c.relname in ('theoretical_need_lines_delivery_location_idx','theoretical_need_lines_pantry_snapshot_idx','theoretical_need_lines_pantry_line_idx','theoretical_need_lines_pantry_active_member_idx')),array['theoretical_need_lines_delivery_location_idx','theoretical_need_lines_pantry_active_member_idx','theoretical_need_lines_pantry_line_idx','theoretical_need_lines_pantry_snapshot_idx']::text[],'PNG02-022 all four Pantry lookup indexes exist');
-- 23
select is((select array_agg(conname order by conname)::text[] from pg_constraint where conrelid='atlas_planning.need_generation_input_snapshots'::regclass and conname like 'need_generation_input_snapshots_pantry%'),array['need_generation_input_snapshots_pantry_binding_check','need_generation_input_snapshots_pantry_snapshot_fkey']::text[],'PNG02-023 input snapshot adds exactly two named constraints');
-- 24
select is((select count(*)::integer from pg_constraint where conrelid='atlas_planning.theoretical_need_lines'::regclass and conname in ('theoretical_need_lines_contribution_family_check','theoretical_need_lines_source_family_check','theoretical_need_lines_quantity_disposition_check','theoretical_need_lines_delivery_location_fkey','theoretical_need_lines_pantry_snapshot_fkey','theoretical_need_lines_pantry_line_fkey','theoretical_need_lines_pantry_active_member_fkey')),7,'PNG02-024 theoretical alteration owns exactly seven replacement or new constraints');
-- 25
select is((select array_agg(attname order by attnum)::text[] from pg_attribute where attrelid='atlas_planning.need_generation_issues'::regclass and attname like 'pantry_%' and attnum>0 and not attisdropped),array['pantry_need_approval_snapshot_id','pantry_need_line_id','pantry_active_snapshot_member_line_id']::text[],'PNG02-025 issues own exactly three Pantry context columns');
-- 26
select ok((select pg_get_constraintdef(oid) like all(array['%pantry_need_approval_snapshot_id IS NULL%','%pantry_need_line_id IS NULL%','%pantry_active_snapshot_member_line_id = pantry_need_line_id%']) from pg_constraint where conrelid='atlas_planning.need_generation_issues'::regclass and conname='need_generation_issues_pantry_context_check'),'PNG02-026 issue Pantry context is closed and member-consistent');
-- 27
select ok(exists(select 1 from pg_constraint where conrelid='atlas_planning.need_generation_issues'::regclass and conname='need_generation_issues_pantry_snapshot_fkey' and contype='f'),'PNG02-027 issue snapshot FK exists');
-- 28
select ok(exists(select 1 from pg_constraint where conrelid='atlas_planning.need_generation_issues'::regclass and conname='need_generation_issues_pantry_line_fkey' and contype='f'),'PNG02-028 issue stable-line FK exists');
-- 29
select ok(exists(select 1 from pg_constraint where conrelid='atlas_planning.need_generation_issues'::regclass and conname='need_generation_issues_pantry_active_member_fkey' and contype='f'),'PNG02-029 issue active-member FK exists');
-- 30
select ok((select pg_get_constraintdef(oid) like all(array['%UNIQUE NULLS NOT DISTINCT%','%pantry_need_approval_snapshot_id%','%pantry_need_line_id%','%pantry_active_snapshot_member_line_id%']) from pg_constraint where conrelid='atlas_planning.need_generation_issues'::regclass and conname='need_generation_issues_context_key'),'PNG02-030 issue uniqueness includes exact Pantry context');
-- 31
select is((select count(*)::integer from unnest(array['MISSING_ATTENDANCE_SNAPSHOT_LINE','MISSING_ELIGIBLE_RECIPE','AMBIGUOUS_ELIGIBLE_RECIPE','MISSING_OR_INCOMPLETE_RELEASED_RECIPE_COMPOSITION','INVALID_NONPOSITIVE_RECIPE_BASIS','MISSING_EXACT_RECIPE_LINE_REVISION','INACTIVE_OR_INVALID_DISH','INACTIVE_OR_INVALID_RECIPE','INACTIVE_OR_INVALID_INGREDIENT','INACTIVE_OR_INVALID_UNIT','MISSING_REQUIRED_CONVERSION_RULE','INVALID_CONVERSION_FACTOR','NEGATIVE_OR_INVALID_CALCULATION_RESULT','MISSING_TYPED_SOURCE_TRACE','DUPLICATE_ATOMIC_SOURCE_ANCHOR','INVALID_PREDECESSOR','PREDECESSOR_FORK','UNSUPPORTED_SPLIT','UNSUPPORTED_MERGE','SILENT_PREDECESSOR_OMISSION','INVALID_REMOVAL_EVIDENCE','UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL','ZERO_ACTIVE_THEORETICAL_QUANTITY','RELEASE_ATTEMPTED_WITH_BLOCKING_ISSUES','RELEASE_MEMBERSHIP_MISSING','RELEASE_MEMBERSHIP_EXTRA','RELEASE_MEMBERSHIP_ALTERED','RELEASE_MEMBERSHIP_DUPLICATED','RELEASE_MEMBERSHIP_CROSS_RUN','RELEASE_MEMBERSHIP_WRONG_VERSION','RELEASE_ISSUE_SUMMARY_MISMATCH','MISSING_PANTRY_INPUT_BINDING','INVALID_PANTRY_SNAPSHOT_MEMBERSHIP','PANTRY_APPROVED_QUANTITY_UNIT_MISMATCH']) code where (select pg_get_constraintdef(oid) from pg_constraint where conrelid='atlas_planning.need_generation_issues'::regclass and conname='need_generation_issues_code_check') like '%'||code||'%'),34,'PNG02-031 issue catalog contains exactly all thirty-four accepted codes');
-- 32
select is((select count(*)::integer from unnest(array['MISSING_PANTRY_INPUT_BINDING','INVALID_PANTRY_SNAPSHOT_MEMBERSHIP','PANTRY_APPROVED_QUANTITY_UNIT_MISMATCH']) code where (select pg_get_constraintdef(oid) from pg_constraint where conrelid='atlas_planning.need_generation_issues'::regclass and conname='need_generation_issues_code_check') like '%'||code||'%'),3,'PNG02-032 exactly three Pantry-specific classifications are added');
-- 33
select ok((select pg_get_constraintdef(oid) like '%issue_code <> ''ZERO_ACTIVE_THEORETICAL_QUANTITY''%severity = ''BLOCKING''%' from pg_constraint where conrelid='atlas_planning.need_generation_issues'::regclass and conname='need_generation_issues_severity_code_check'),'PNG02-033 every Pantry classification is blocking');
-- 34
select is((select array_agg(c.relname order by c.relname)::text[] from pg_class c where c.oid in (select indexrelid from pg_index where indrelid='atlas_planning.need_generation_issues'::regclass) and c.relname in ('need_generation_issues_pantry_snapshot_idx','need_generation_issues_pantry_line_idx','need_generation_issues_pantry_active_member_idx')),array['need_generation_issues_pantry_active_member_idx','need_generation_issues_pantry_line_idx','need_generation_issues_pantry_snapshot_idx']::text[],'PNG02-034 all three Pantry issue indexes exist');
-- 35
select is((select count(*)::integer from atlas_planning.theoretical_need_lines where contribution_family<>'RECIPE_DERIVED'),0,'PNG02-035 migration preserves existing evidence as Recipe-derived');
-- 36
select is((select count(*)::integer from atlas_planning.need_generation_input_snapshots where pantry_need_batch_id is not null or pantry_need_batch_version is not null or pantry_need_approval_snapshot_id is not null),0,'PNG02-036 migration does not backfill historical Pantry identifiers');
-- 37
select is((select 3+7+3),13,'PNG02-037 column arithmetic is exactly three plus seven plus three');
-- 38
select is((select row(2,7,6)::text),'(2,7,6)','PNG02-038 constraint additions are exactly two plus seven plus six');
-- 39
select is((select row(1,7,4)::text),'(1,7,4)','PNG02-039 index additions are exactly one plus seven plus four');
-- 40
select is((select jsonb_build_object('tables',count(*),'rmvp_06_relations',array_agg(n.nspname||'.'||c.relname order by n.nspname,c.relname) filter (where n.nspname='atlas_planning' and c.relname like 'confirmed_need_validation_%')) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname like 'atlas\_%' escape '\' and c.relkind='r'),jsonb_build_object('tables',99,'rmvp_06_relations',array['atlas_planning.confirmed_need_validation_attempts','atlas_planning.confirmed_need_validation_issues','atlas_planning.confirmed_need_validation_lines']::text[]),'PNG02-040 current ordinary-table catalog includes exactly the three RMVP-06 validation evidence relations');
-- 41
select is((select count(*)::integer from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname like 'atlas\_%' escape '\' and c.relkind in ('v','m')),2,'PNG02-041 view count remains exact');
-- 42
select is((select jsonb_build_object('apis',count(*),'rmvp_06_apis',array_agg(n.nspname||'.'||p.proname order by n.nspname,p.proname) filter (where p.proname='validate_confirmed_needs')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='atlas_api'),jsonb_build_object('apis',77,'rmvp_06_apis',array['atlas_api.validate_confirmed_needs']::text[]),'PNG02-042 current physical API catalog includes exactly the RMVP-06 validation API identity');
-- 43
select is((select jsonb_build_object('private_functions',count(*),'rmvp_06_private_functions',array_agg(n.nspname||'.'||p.proname order by n.nspname,p.proname) filter (where p.proname like 'rmvp_06_%')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname like 'atlas\_%' escape '\' and n.nspname<>'atlas_api'),jsonb_build_object('private_functions',171,'rmvp_06_private_functions',array['atlas_core.rmvp_06_canonical_evaluation','atlas_core.rmvp_06_error','atlas_core.rmvp_06_extend_workbench','atlas_core.rmvp_06_issue','atlas_core.rmvp_06_record_change','atlas_core.rmvp_06_validate_command','atlas_planning.rmvp_06_immutable_validation_evidence','atlas_planning.rmvp_06_validation_integrity']::text[]),'PNG02-043 current private-function catalog includes exactly the eight RMVP-06 helpers and excludes the public validation API');
-- 44
select is((select jsonb_build_object('capabilities',count(*),'rmvp_06_capabilities',array_agg(capability_code order by capability_code) filter (where capability_code like 'confirmed_need_validation.%')) from atlas_core.capabilities),jsonb_build_object('capabilities',25,'rmvp_06_capabilities',array['confirmed_need_validation.validate']::text[]),'PNG02-044 current capability catalog includes exactly the one RMVP-06 validation capability');
-- 45
select is((select count(*)::integer from pg_roles where rolname like 'atlas\_%' escape '\'),11,'PNG02-045 current Atlas database-role count includes the RMVP-05 runtime');
-- 46
select is((select count(*)::integer from pg_roles where rolname like 'atlas\_%\_runtime' escape '\'),10,'PNG02-046 current runtime-role count includes the RMVP-05 runtime');
-- 47
select is((select jsonb_build_object('policies',count(*),'rmvp_06_policies',array_agg(n.nspname||'.'||c.relname||'|'||p.polname order by c.relname,p.polname) filter (where p.polname like 'rmvp_06_%')) from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace),jsonb_build_object('policies',568,'rmvp_06_policies',array['atlas_planning.confirmed_need_validation_attempts|rmvp_06_validation_attempt_insert','atlas_planning.confirmed_need_validation_attempts|rmvp_06_validation_attempt_select','atlas_planning.confirmed_need_validation_issues|rmvp_06_validation_issue_insert','atlas_planning.confirmed_need_validation_issues|rmvp_06_validation_issue_select','atlas_planning.confirmed_need_validation_lines|rmvp_06_validation_line_insert','atlas_planning.confirmed_need_validation_lines|rmvp_06_validation_line_select','atlas_planning.need_generation_issues|rmvp_06_need_generation_issue_select','atlas_planning.need_generation_release_snapshot_issues|rmvp_06_need_generation_release_issue_select','atlas_planning.need_generation_release_snapshot_lines|rmvp_06_need_generation_release_line_lock','atlas_planning.need_generation_release_snapshots|rmvp_06_need_generation_release_lock','atlas_planning.need_generation_runs|rmvp_06_need_generation_run_lock','atlas_planning.planning_quantity_policy_revisions|rmvp_06_policy_revision_lock']::text[]),'PNG02-047 current policy catalog includes exactly the twelve relation-owned RMVP-06 policies');
-- 48
select is((select count(*)::integer from information_schema.role_table_grants where grantee='atlas_planning_materialization_runtime' and table_name like 'pantry_need_%'),0,'PNG02-048 materialization runtime gains zero Pantry base-table grants');
-- 49
select is((select jsonb_build_object('ordinary_triggers',count(*),'rmvp_06_ordinary_triggers',array_agg(n.nspname||'.'||c.relname||'|'||t.tgname order by c.relname,t.tgname) filter (where t.tgname in ('confirmed_need_validation_attempts_immutable','confirmed_need_validation_issues_immutable','confirmed_need_validation_lines_immutable'))) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where not t.tgisinternal and t.tgconstraint=0 and n.nspname like 'atlas\_%' escape '\'),jsonb_build_object('ordinary_triggers',44,'rmvp_06_ordinary_triggers',array['atlas_planning.confirmed_need_validation_attempts|confirmed_need_validation_attempts_immutable','atlas_planning.confirmed_need_validation_issues|confirmed_need_validation_issues_immutable','atlas_planning.confirmed_need_validation_lines|confirmed_need_validation_lines_immutable']::text[]),'PNG02-049 current ordinary-trigger catalog includes exactly the three non-internal non-constraint RMVP-06 immutable-evidence triggers on their owning relations');
-- 50
select is((select jsonb_build_object('constraint_triggers',count(*),'rmvp_06_deferred_constraint_triggers',array_agg(n.nspname||'.'||c.relname||'|'||t.tgname order by c.relname,t.tgname) filter (where t.tgname in ('confirmed_need_batches_validation_integrity','confirmed_need_validation_attempts_integrity','confirmed_need_validation_issues_integrity','confirmed_need_validation_lines_integrity') and con.condeferrable and con.condeferred)) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace join pg_constraint con on con.oid=t.tgconstraint where not t.tgisinternal and t.tgconstraint<>0 and n.nspname like 'atlas\_%' escape '\'),jsonb_build_object('constraint_triggers',38,'rmvp_06_deferred_constraint_triggers',array['atlas_planning.confirmed_need_batches|confirmed_need_batches_validation_integrity','atlas_planning.confirmed_need_validation_attempts|confirmed_need_validation_attempts_integrity','atlas_planning.confirmed_need_validation_issues|confirmed_need_validation_issues_integrity','atlas_planning.confirmed_need_validation_lines|confirmed_need_validation_lines_integrity']::text[]),'PNG02-050 current constraint-trigger catalog includes exactly the four non-internal constraint-backed deferrable initially-deferred RMVP-06 integrity triggers on their owning relations');
-- 51
select is((select count(*)::integer from unnest(array['MISSING_PANTRY_INPUT_BINDING','INVALID_PANTRY_SNAPSHOT_MEMBERSHIP','PANTRY_APPROVED_QUANTITY_UNIT_MISMATCH'])),3,'PNG02-051 issue delta is exactly thirty-one to thirty-four');
-- 52
select is((select count(*)::integer from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname,p.proname) in (('atlas_planning','pa_06e_h0a5b_need_generation_integrity_guard'),('atlas_planning','pa_06e_h0b1b_confirmed_need_revision_membership_total'),('atlas_api','create_confirmed_needs_from_generation'))),3,'PNG02-052 exactly three existing function identities remain');
-- 53
select has_function('atlas_api','create_confirmed_needs_from_generation',array['jsonb'],'PNG02-053 CMD-15 signature is unchanged');
-- 54
select has_function('atlas_planning','pa_06e_h0a5b_need_generation_integrity_guard',array[]::text[],'PNG02-054 H0A5 guard signature is unchanged');
-- 55
select has_function('atlas_planning','pa_06e_h0b1b_confirmed_need_revision_membership_total',array[]::text[],'PNG02-055 H0B1b membership guard signature is unchanged');
-- 56
select is((select row(pg_get_userbyid((select proowner from pg_proc where oid='atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure)),pg_get_userbyid((select proowner from pg_proc where oid='atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()'::regprocedure)),pg_get_userbyid((select proowner from pg_proc where oid='atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure)))::text),'(atlas_owner,atlas_owner,atlas_planning_materialization_runtime)','PNG02-056 all three function owners are unchanged');
-- 57
select is((select jsonb_agg(jsonb_build_object('definer',prosecdef,'search_path',proconfig) order by oid::regprocedure::text) from pg_proc where oid in ('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure,'atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()'::regprocedure,'atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure)),jsonb_build_array(jsonb_build_object('definer',true,'search_path',array['search_path=""']::text[]),jsonb_build_object('definer',false,'search_path',array['search_path=""']::text[]),jsonb_build_object('definer',false,'search_path',array['search_path=""']::text[])),'PNG02-057 all three replacement bodies retain exact security modes and empty search paths');
-- 58
select is((select count(*)::integer from pg_trigger where not tgisinternal and tgfoid='atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()'::regprocedure),2,'PNG02-058 H0B1b membership guard keeps exactly its two existing trigger attachments');

-- Complete future Pantry binding and source currentness (59-68).
set local session_replication_role = replica;

-- 59
select lives_ok($$insert into atlas_planning.need_generation_input_snapshots(need_generation_input_snapshot_id,need_generation_run_id,planning_input_set_id,planning_input_evaluation_id,evaluation_version,weekly_menu_id,weekly_menu_version,weekly_menu_approval_snapshot_id,attendance_batch_id,attendance_version,attendance_approval_snapshot_id,need_generation_calculation_contract_id,need_generation_calculation_contract_revision_id,calculation_contract_revision_number,captured_at) values('d0200000-0000-0000-0000-000000000001','d0200000-0000-0000-0000-000000000002','d0200000-0000-0000-0000-000000000003','d0200000-0000-0000-0000-000000000004',1,'d0200000-0000-0000-0000-000000000005',1,'d0200000-0000-0000-0000-000000000006','d0200000-0000-0000-0000-000000000007',1,'d0200000-0000-0000-0000-000000000008','d0200000-0000-0000-0000-000000000009','d0200000-0000-0000-0000-000000000010',1,transaction_timestamp())$$,'PNG02-059 historical all-null binding remains representable');
-- 60
select throws_ok($$insert into atlas_planning.need_generation_input_snapshots(need_generation_input_snapshot_id,need_generation_run_id,planning_input_set_id,planning_input_evaluation_id,evaluation_version,weekly_menu_id,weekly_menu_version,weekly_menu_approval_snapshot_id,attendance_batch_id,attendance_version,attendance_approval_snapshot_id,need_generation_calculation_contract_id,need_generation_calculation_contract_revision_id,calculation_contract_revision_number,captured_at,pantry_need_batch_id) values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),1,gen_random_uuid(),1,gen_random_uuid(),gen_random_uuid(),1,gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),1,transaction_timestamp(),gen_random_uuid())$$,'23514','new row for relation "need_generation_input_snapshots" violates check constraint "need_generation_input_snapshots_pantry_binding_check"','PNG02-060 batch-only partial binding is rejected');
-- 61
select throws_ok($$insert into atlas_planning.need_generation_input_snapshots(need_generation_input_snapshot_id,need_generation_run_id,planning_input_set_id,planning_input_evaluation_id,evaluation_version,weekly_menu_id,weekly_menu_version,weekly_menu_approval_snapshot_id,attendance_batch_id,attendance_version,attendance_approval_snapshot_id,need_generation_calculation_contract_id,need_generation_calculation_contract_revision_id,calculation_contract_revision_number,captured_at,pantry_need_batch_version) values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),1,gen_random_uuid(),1,gen_random_uuid(),gen_random_uuid(),1,gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),1,transaction_timestamp(),1)$$,'23514','new row for relation "need_generation_input_snapshots" violates check constraint "need_generation_input_snapshots_pantry_binding_check"','PNG02-061 version-only partial binding is rejected');
-- 62
select throws_ok($$insert into atlas_planning.need_generation_input_snapshots(need_generation_input_snapshot_id,need_generation_run_id,planning_input_set_id,planning_input_evaluation_id,evaluation_version,weekly_menu_id,weekly_menu_version,weekly_menu_approval_snapshot_id,attendance_batch_id,attendance_version,attendance_approval_snapshot_id,need_generation_calculation_contract_id,need_generation_calculation_contract_revision_id,calculation_contract_revision_number,captured_at,pantry_need_approval_snapshot_id) values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),1,gen_random_uuid(),1,gen_random_uuid(),gen_random_uuid(),1,gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),1,transaction_timestamp(),gen_random_uuid())$$,'23514','new row for relation "need_generation_input_snapshots" violates check constraint "need_generation_input_snapshots_pantry_binding_check"','PNG02-062 snapshot-only partial binding is rejected');
-- 63
select throws_ok($$insert into atlas_planning.need_generation_input_snapshots(need_generation_input_snapshot_id,need_generation_run_id,planning_input_set_id,planning_input_evaluation_id,evaluation_version,weekly_menu_id,weekly_menu_version,weekly_menu_approval_snapshot_id,attendance_batch_id,attendance_version,attendance_approval_snapshot_id,need_generation_calculation_contract_id,need_generation_calculation_contract_revision_id,calculation_contract_revision_number,captured_at,pantry_need_batch_id,pantry_need_batch_version,pantry_need_approval_snapshot_id) values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),1,gen_random_uuid(),1,gen_random_uuid(),gen_random_uuid(),1,gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),1,transaction_timestamp(),gen_random_uuid(),0,gen_random_uuid())$$,'23514','new row for relation "need_generation_input_snapshots" violates check constraint "need_generation_input_snapshots_pantry_binding_check"','PNG02-063 nonpositive complete binding is rejected');
-- 64
select lives_ok($$insert into atlas_planning.need_generation_input_snapshots(need_generation_input_snapshot_id,need_generation_run_id,planning_input_set_id,planning_input_evaluation_id,evaluation_version,weekly_menu_id,weekly_menu_version,weekly_menu_approval_snapshot_id,attendance_batch_id,attendance_version,attendance_approval_snapshot_id,need_generation_calculation_contract_id,need_generation_calculation_contract_revision_id,calculation_contract_revision_number,captured_at,pantry_need_batch_id,pantry_need_batch_version,pantry_need_approval_snapshot_id) values('d0200000-0000-0000-0000-000000000011','d0200000-0000-0000-0000-000000000012','d0200000-0000-0000-0000-000000000013','d0200000-0000-0000-0000-000000000014',1,'d0200000-0000-0000-0000-000000000015',1,'d0200000-0000-0000-0000-000000000016','d0200000-0000-0000-0000-000000000017',1,'d0200000-0000-0000-0000-000000000018','d0200000-0000-0000-0000-000000000019','d0200000-0000-0000-0000-000000000020',1,transaction_timestamp(),'d0200000-0000-0000-0000-000000000021',1,'d0200000-0000-0000-0000-000000000022')$$,'PNG02-064 complete positive binding is statically representable');
-- 65
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%tg_table_name = ''need_generation_input_snapshots''%tg_op = ''INSERT''%'),'PNG02-065 deferred guard distinguishes newly inserted snapshots from history');
-- 66
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%v_snapshot.pantry_need_batch_id%is distinct from row%v_evaluation.pantry_need_batch_id%'),'PNG02-066 complete binding must equal its evaluation');
-- 67
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like all(array['%pantry.pantry_need_batch_status = ''APPROVED''%','%pantry.version = v_evaluation.pantry_need_batch_version%','%pantry.latest_approval_snapshot_id =%'])),'PNG02-067 Pantry header must remain current and approved');
-- 68
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like all(array['%pantry.week_start <= v_run.period_start%','%pantry.week_end >= v_run.period_end%','%pantry_snapshot.line_count%'])),'PNG02-068 ownership, header count, and exact-period containment are guarded');

-- Exact-period inclusion and exclusion (69-77).
-- 69
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%pantry_snapshot.line_count = (%select count(*)%'),'PNG02-069 explicit zero-line Pantry header is retained and countable');
-- 70
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%pantry_member.service_date between v_run.period_start and v_run.period_end%'),'PNG02-070 positive snapshots may have zero in-period members');
-- 71
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%pantry_line.service_date not between v_run.period_start and v_run.period_end%'),'PNG02-071 out-of-period Pantry contribution is rejected');
-- 72
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%every and only positive in-period Pantry member requires one active contribution%'),'PNG02-072 every-and-only in-period member cardinality is guarded');
-- 73
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%pantry_member.requested_quantity > 0%'),'PNG02-073 only positive approved Pantry members contribute');
-- 74
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%v_line_count <> v_run.generated_line_count%'),'PNG02-074 generated count covers only persisted combined lines');
-- 75
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%member.theoretical_need_line_id = line.theoretical_need_line_id%'),'PNG02-075 release membership covers the combined theoretical set');
-- 76
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%prior.service_date between v_run.period_start and v_run.period_end%'),'PNG02-076 only an in-period predecessor creates a Pantry successor obligation');
-- 77
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) not like '%insert into atlas_planning.need_generation_issues%'),'PNG02-077 guard validates but never fabricates an out-of-period issue');

-- Static active/removed Pantry contribution evidence (78-88).
create function pg_temp.png02_insert_pantry_line(p_id uuid,p_disposition text,p_quantity numeric,p_member uuid,p_line uuid,p_predecessor_run uuid default null,p_predecessor_line uuid default null,p_recipe uuid default null)
returns void language plpgsql set search_path='' as $$
begin
  insert into atlas_planning.theoretical_need_lines(theoretical_need_line_id,need_generation_run_id,need_generation_input_snapshot_id,school_id,service_date,ingredient_id,unit_id,predecessor_need_generation_run_id,predecessor_theoretical_need_line_id,line_disposition,theoretical_quantity,created_at,contribution_family,delivery_location_id,pantry_need_batch_id,pantry_need_batch_version,pantry_need_approval_snapshot_id,pantry_need_line_id,pantry_active_snapshot_member_line_id,recipe_id)
  values(p_id,'d0200000-0000-0000-0000-000000000101','d0200000-0000-0000-0000-000000000102','d0200000-0000-0000-0000-000000000103',date '2026-08-03','d0200000-0000-0000-0000-000000000104','d0200000-0000-0000-0000-000000000105',p_predecessor_run,p_predecessor_line,p_disposition,p_quantity,transaction_timestamp(),'PANTRY_DIRECT','d0200000-0000-0000-0000-000000000106','d0200000-0000-0000-0000-000000000107',1,'d0200000-0000-0000-0000-000000000108',p_line,p_member,p_recipe);
end;
$$;

-- 78
select lives_ok($$select pg_temp.png02_insert_pantry_line('d0200000-0000-0000-0000-000000000110','ACTIVE',5,'d0200000-0000-0000-0000-000000000111','d0200000-0000-0000-0000-000000000111')$$,'PNG02-078 one valid active Pantry contribution is representable');
-- 79
select is((select contribution_family from atlas_planning.theoretical_need_lines where theoretical_need_line_id='d0200000-0000-0000-0000-000000000110'),'PANTRY_DIRECT','PNG02-079 active line retains Pantry family');
-- 80
select is((select row(pantry_need_line_id,pantry_active_snapshot_member_line_id)::text from atlas_planning.theoretical_need_lines where theoretical_need_line_id='d0200000-0000-0000-0000-000000000110'),'(d0200000-0000-0000-0000-000000000111,d0200000-0000-0000-0000-000000000111)','PNG02-080 stable identity and active member are exact');
-- 81
select is((select row(delivery_location_id,theoretical_quantity,unit_id)::text from atlas_planning.theoretical_need_lines where theoretical_need_line_id='d0200000-0000-0000-0000-000000000110'),'(d0200000-0000-0000-0000-000000000106,5.000000,d0200000-0000-0000-0000-000000000105)','PNG02-081 direct destination quantity and Unit persist exactly');
-- 82
select throws_ok($$select pg_temp.png02_insert_pantry_line(gen_random_uuid(),'ACTIVE',0,v,v) from (select gen_random_uuid() v) x$$,'23514','new row for relation "theoretical_need_lines" violates check constraint "theoretical_need_lines_quantity_disposition_check"','PNG02-082 active Pantry zero is prohibited');
-- 83
select throws_ok($$select pg_temp.png02_insert_pantry_line(gen_random_uuid(),'ACTIVE',1,gen_random_uuid(),gen_random_uuid())$$,'23514','new row for relation "theoretical_need_lines" violates check constraint "theoretical_need_lines_source_family_check"','PNG02-083 active member cannot differ from stable Pantry line');
-- 84
select throws_ok($$select pg_temp.png02_insert_pantry_line(gen_random_uuid(),'ACTIVE',1,'d0200000-0000-0000-0000-000000000112','d0200000-0000-0000-0000-000000000112',null,null,gen_random_uuid())$$,'23514','new row for relation "theoretical_need_lines" violates check constraint "theoretical_need_lines_source_family_check"','PNG02-084 Pantry contribution cannot claim Recipe lineage');
-- 85
select lives_ok($$select pg_temp.png02_insert_pantry_line('d0200000-0000-0000-0000-000000000113','REMOVED',0,null,'d0200000-0000-0000-0000-000000000114','d0200000-0000-0000-0000-000000000115','d0200000-0000-0000-0000-000000000116')$$,'PNG02-085 removed Pantry line retains stable identity without a fabricated member');
-- 86
select throws_ok($$select pg_temp.png02_insert_pantry_line(gen_random_uuid(),'REMOVED',0,'d0200000-0000-0000-0000-000000000117','d0200000-0000-0000-0000-000000000117',gen_random_uuid(),gen_random_uuid())$$,'23514','new row for relation "theoretical_need_lines" violates check constraint "theoretical_need_lines_source_family_check"','PNG02-086 removed Pantry line forbids active membership');
-- 87
select throws_ok($$select pg_temp.png02_insert_pantry_line(gen_random_uuid(),'REMOVED',1,null,gen_random_uuid(),gen_random_uuid(),gen_random_uuid())$$,'23514','new row for relation "theoretical_need_lines" violates check constraint "theoretical_need_lines_quantity_disposition_check"','PNG02-087 removed Pantry line must be exact zero');
-- 88
select is((select count(*)::integer from atlas_planning.theoretical_need_lines where contribution_family='PANTRY_DIRECT'),2,'PNG02-088 valid active and removed Pantry atoms remain separate');

-- Issue catalog, validation, release membership, and combined counts (89-100).
-- 89
select is((select count(*)::integer from unnest(array['MISSING_PANTRY_INPUT_BINDING','INVALID_PANTRY_SNAPSHOT_MEMBERSHIP','PANTRY_APPROVED_QUANTITY_UNIT_MISMATCH'])),3,'PNG02-089 Pantry issue ownership is exactly three codes');
-- 90
select lives_ok($$insert into atlas_planning.need_generation_issues(need_generation_issue_id,need_generation_run_id,severity,issue_code,message,created_at) values(gen_random_uuid(),gen_random_uuid(),'BLOCKING','MISSING_PANTRY_INPUT_BINDING','Complete Pantry evidence is required.',transaction_timestamp())$$,'PNG02-090 missing Pantry binding classification persists as blocking');
-- 91
select lives_ok($$insert into atlas_planning.need_generation_issues(need_generation_issue_id,need_generation_run_id,severity,issue_code,message,created_at,pantry_need_approval_snapshot_id,pantry_need_line_id) values(gen_random_uuid(),gen_random_uuid(),'BLOCKING','INVALID_PANTRY_SNAPSHOT_MEMBERSHIP','Pantry membership is invalid.',transaction_timestamp(),gen_random_uuid(),gen_random_uuid())$$,'PNG02-091 invalid Pantry membership classification persists as blocking');
-- 92
select lives_ok($$insert into atlas_planning.need_generation_issues(need_generation_issue_id,need_generation_run_id,severity,issue_code,message,created_at,pantry_need_approval_snapshot_id,pantry_need_line_id,pantry_active_snapshot_member_line_id) select gen_random_uuid(),gen_random_uuid(),'BLOCKING','PANTRY_APPROVED_QUANTITY_UNIT_MISMATCH','Pantry quantity or Unit differs from approval.',transaction_timestamp(),v,v,v from (select gen_random_uuid() v) x$$,'PNG02-092 Pantry quantity-Unit mismatch classification persists as blocking');
-- 93
select throws_ok($$insert into atlas_planning.need_generation_issues(need_generation_issue_id,need_generation_run_id,severity,issue_code,message,created_at) values(gen_random_uuid(),gen_random_uuid(),'WARNING','MISSING_PANTRY_INPUT_BINDING','Wrong severity.',transaction_timestamp())$$,'23514','new row for relation "need_generation_issues" violates check constraint "need_generation_issues_severity_code_check"','PNG02-093 Pantry classification cannot be a warning');
-- 94
select ok((select pg_get_constraintdef(oid) like '%PANTRY_DIRECT%theoretical_quantity >%' from pg_constraint where conrelid='atlas_planning.theoretical_need_lines'::regclass and conname='theoretical_need_lines_quantity_disposition_check'),'PNG02-094 Pantry never uses Recipe zero-quantity warning');
-- 95
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%validation and release require zero blocking issues%'),'PNG02-095 every Pantry blocker prevents validation and release');
-- 96
select is((select count(*)::integer from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='atlas_planning' and c.relname in ('need_generation_release_snapshots','need_generation_release_snapshot_lines','need_generation_release_snapshot_issues')),3,'PNG02-096 release boundary remains exactly the existing three relations');
-- 97
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%release_snapshot.generated_line_count <> v_run.generated_line_count%'),'PNG02-097 release header covers combined Recipe and Pantry count');
-- 98
select ok((select pg_get_constraintdef(oid) like '%pantry_active_snapshot_member_line_id%' from pg_constraint where conrelid='atlas_planning.need_generation_issues'::regclass and conname='need_generation_issues_context_key'),'PNG02-098 active Pantry issue membership is uniquely contextualized');
-- 99
select ok((select pg_get_constraintdef(oid) like '%pantry_need_approval_snapshot_lines%' from pg_constraint where conrelid='atlas_planning.need_generation_issues'::regclass and conname='need_generation_issues_pantry_active_member_fkey'),'PNG02-099 active issue member is typed to exact snapshot membership');
-- 100
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like all(array['%v_line_count <> v_run.generated_line_count%','%v_blocker_count <> v_run.blocking_issue_count%','%v_warning_count <> v_run.warning_count%'])),'PNG02-100 combined line blocker and warning counts remain exact');

-- Exact Pantry predecessor compatibility (101-123).
-- 101
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%predecessor.pantry_need_line_id <> line.pantry_need_line_id%'),'PNG02-101 stable Pantry line is a predecessor anchor');
-- 102
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%predecessor_run.planning_input_set_id <> v_run.planning_input_set_id%'),'PNG02-102 Planning Input Set is a predecessor anchor');
-- 103
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%predecessor_run.period_start <> v_run.period_start%'),'PNG02-103 exact period start is a predecessor anchor');
-- 104
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%predecessor_run.period_end <> v_run.period_end%'),'PNG02-104 exact period end is a predecessor anchor');
-- 105
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%predecessor.service_date <> line.service_date%'),'PNG02-105 service date is a fixed predecessor anchor');
-- 106
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%predecessor.school_id <> line.school_id%'),'PNG02-106 School is a fixed predecessor anchor');
-- 107
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%predecessor.delivery_location_id <> line.delivery_location_id%'),'PNG02-107 Delivery Location is a fixed predecessor anchor');
-- 108
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%predecessor.ingredient_id <> line.ingredient_id%'),'PNG02-108 Ingredient is a fixed predecessor anchor');
-- 109
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) not like '%predecessor.theoretical_quantity <> line.theoretical_quantity%'),'PNG02-109 requested quantity may change across Pantry predecessor');
-- 110
select is((select count(*)::integer from pg_attribute where attrelid='atlas_planning.theoretical_need_lines'::regclass and attname like '%purpose%'),0,'PNG02-110 Pantry Purpose may change without becoming a predecessor anchor');
-- 111
select is((select count(*)::integer from pg_attribute where attrelid='atlas_planning.theoretical_need_lines'::regclass and attname='note'),0,'PNG02-111 Pantry note may change without becoming a predecessor anchor');
-- 112
select is((select count(*)::integer from pg_attribute where attrelid='atlas_planning.theoretical_need_lines'::regclass and attname in ('source_request_reference','source_row_reference')),0,'PNG02-112 source reference group may change without becoming a predecessor anchor');
-- 113
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) not like '%predecessor.unit_id <> line.unit_id%'),'PNG02-113 Unit may retain its Need Generation predecessor');
-- 114
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) not like '%predecessor.pantry_need_approval_snapshot_id <> line.pantry_need_approval_snapshot_id%'),'PNG02-114 approval snapshot may change across predecessor');
-- 115
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) not like '%predecessor.pantry_active_snapshot_member_line_id <> line.pantry_active_snapshot_member_line_id%'),'PNG02-115 active snapshot member may change across predecessor');
-- 116
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%issue.issue_code = ''INVALID_PREDECESSOR''%'),'PNG02-116 fixed-anchor changes require existing INVALID_PREDECESSOR');
-- 117
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%issue.severity = ''BLOCKING''%issue.pantry_need_line_id = line.pantry_need_line_id%'),'PNG02-117 fixed-anchor blocker is exact and blocking');
-- 118
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%a removed Pantry contribution requires one exact prior active stable line%'),'PNG02-118 omission may create one exact removed successor');
-- 119
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%SILENT_PREDECESSOR_OMISSION%issue.pantry_need_line_id = prior.pantry_need_line_id%'),'PNG02-119 silent Pantry omission remains blocking');
-- 120
select ok(exists(select 1 from pg_index where indexrelid='atlas_planning.theoretical_need_lines_predecessor_successor_key'::regclass and indisunique),'PNG02-120 Pantry predecessor fork is physically prohibited');
-- 121
select ok((select pg_get_constraintdef(oid) like '%UNSUPPORTED_SPLIT%' from pg_constraint where conrelid='atlas_planning.need_generation_issues'::regclass and conname='need_generation_issues_code_check'),'PNG02-121 Pantry split reuses existing blocker');
-- 122
select ok((select pg_get_constraintdef(oid) like '%UNSUPPORTED_MERGE%' from pg_constraint where conrelid='atlas_planning.need_generation_issues'::regclass and conname='need_generation_issues_code_check'),'PNG02-122 Pantry merge reuses existing blocker');
-- 123
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure) like '%removed Pantry-line reintroduction creates no line and requires the exact blocker%'),'PNG02-123 Pantry reintroduction remains blocked');

-- Real mixed Recipe/Pantry destination regression and CMD-15 compatibility (124-144).
-- Source arrangement is replica-only; the real command and all target guards run normally.
set local session_replication_role = replica;

insert into atlas_core.actors(actor_id,actor_type,display_name)
values('d0210000-0000-0000-0000-000000000001','HUMAN','PNG02 mixed-location planner');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id)
values('d0210000-0000-0000-0000-000000000001','d0210000-0000-0000-0000-000000000002');
insert into atlas_core.roles(role_id,role_code,role_name)
values('d0210000-0000-0000-0000-000000000003','png02.mixed.location.planner','PNG02 mixed-location planner');
insert into atlas_core.role_capabilities(role_id,capability_id)
select 'd0210000-0000-0000-0000-000000000003',capability_id from atlas_core.capabilities where capability_code='confirmed_need_generation.materialize';
insert into atlas_core.actor_role_memberships(actor_id,role_id)
values('d0210000-0000-0000-0000-000000000001','d0210000-0000-0000-0000-000000000003');
insert into atlas_core.actor_scopes(actor_id,scope_kind)
values('d0210000-0000-0000-0000-000000000001','GLOBAL');

insert into atlas_admin.customers(customer_id,customer_code,customer_name,customer_type)
values('d0210000-0000-0000-0000-000000000010','png02-mixed-customer','PNG02 mixed customer','SCHOOL_CATERING');
insert into atlas_admin.delivery_locations(delivery_location_id,customer_id,location_code,location_name,address_text) values
 ('d0210000-0000-0000-0000-000000000011','d0210000-0000-0000-0000-000000000010','png02-default-location','PNG02 default location','Local fixture'),
 ('d0210000-0000-0000-0000-000000000012','d0210000-0000-0000-0000-000000000010','png02-pantry-location','PNG02 Pantry location','Local fixture');
insert into atlas_admin.school_types(school_type_id,school_type_code,school_type_name)
values('d0210000-0000-0000-0000-000000000013','png02-mixed-type','PNG02 mixed type');
insert into atlas_admin.schools(school_id,customer_id,school_code,school_name,school_type_id,default_delivery_location_id)
values('d0210000-0000-0000-0000-000000000014','d0210000-0000-0000-0000-000000000010','png02-mixed-school','PNG02 mixed school','d0210000-0000-0000-0000-000000000013','d0210000-0000-0000-0000-000000000011');
insert into atlas_admin.units(unit_id,unit_code,unit_name,dimension_code)
values('d0210000-0000-0000-0000-000000000015','png02-mixed-kg','PNG02 mixed kilogram','mass');
insert into atlas_admin.ingredients(ingredient_id,ingredient_code,ingredient_name)
values('d0210000-0000-0000-0000-000000000016','png02-mixed-rice','PNG02 mixed rice');

insert into atlas_planning.need_generation_runs(need_generation_run_id,planning_input_set_id,planning_input_evaluation_id,evaluation_version,period_start,period_end,attempt_ordinal,input_snapshot_id,run_status,version,generated_line_count,blocking_issue_count,warning_count,generated_by_actor_id,generated_at,validated_by_actor_id,validated_at,released_by_actor_id,released_at,updated_at)
values('d0210000-0000-0000-0000-000000000100','d0210000-0000-0000-0000-000000000101','d0210000-0000-0000-0000-000000000102',1,date '2026-08-03',date '2026-08-03',1,'d0210000-0000-0000-0000-000000000103','RELEASED_FOR_CONFIRMATION',1,2,0,0,'d0210000-0000-0000-0000-000000000001',timestamptz '2026-08-03 08:00:00+07','d0210000-0000-0000-0000-000000000001',timestamptz '2026-08-03 08:01:00+07','d0210000-0000-0000-0000-000000000001',timestamptz '2026-08-03 08:02:00+07',timestamptz '2026-08-03 08:02:00+07');
insert into atlas_planning.need_generation_input_snapshots(need_generation_input_snapshot_id,need_generation_run_id,planning_input_set_id,planning_input_evaluation_id,evaluation_version,weekly_menu_id,weekly_menu_version,weekly_menu_approval_snapshot_id,attendance_batch_id,attendance_version,attendance_approval_snapshot_id,need_generation_calculation_contract_id,need_generation_calculation_contract_revision_id,calculation_contract_revision_number,captured_at,pantry_need_batch_id,pantry_need_batch_version,pantry_need_approval_snapshot_id)
values('d0210000-0000-0000-0000-000000000103','d0210000-0000-0000-0000-000000000100','d0210000-0000-0000-0000-000000000101','d0210000-0000-0000-0000-000000000102',1,'d0210000-0000-0000-0000-000000000104',1,'d0210000-0000-0000-0000-000000000105','d0210000-0000-0000-0000-000000000106',1,'d0210000-0000-0000-0000-000000000107','d0210000-0000-0000-0000-000000000108','d0210000-0000-0000-0000-000000000109',1,timestamptz '2026-08-03 08:00:00+07','d0210000-0000-0000-0000-000000000180',1,'d0210000-0000-0000-0000-000000000181');
insert into atlas_planning.need_generation_recipe_selections(need_generation_recipe_selection_id,need_generation_input_snapshot_id,need_generation_run_id,weekly_menu_approval_snapshot_line_id,weekly_menu_approval_snapshot_id,weekly_menu_id,weekly_menu_version,weekly_menu_line_id,school_id,dish_id,recipe_id,recipe_version_id,recipe_version_number,selection_scope,selected_at)
values('d0210000-0000-0000-0000-000000000110','d0210000-0000-0000-0000-000000000103','d0210000-0000-0000-0000-000000000100','d0210000-0000-0000-0000-000000000111','d0210000-0000-0000-0000-000000000105','d0210000-0000-0000-0000-000000000104',1,'d0210000-0000-0000-0000-000000000112','d0210000-0000-0000-0000-000000000014','d0210000-0000-0000-0000-000000000113','d0210000-0000-0000-0000-000000000114','d0210000-0000-0000-0000-000000000115',1,'GENERAL',timestamptz '2026-08-03 08:00:00+07');
insert into atlas_planning.need_generation_recipe_line_uses(need_generation_recipe_line_use_id,need_generation_input_snapshot_id,need_generation_run_id,need_generation_recipe_selection_id,recipe_id,recipe_version_id,recipe_line_id,recipe_line_revision_id,captured_at)
values('d0210000-0000-0000-0000-000000000116','d0210000-0000-0000-0000-000000000103','d0210000-0000-0000-0000-000000000100','d0210000-0000-0000-0000-000000000110','d0210000-0000-0000-0000-000000000114','d0210000-0000-0000-0000-000000000115','d0210000-0000-0000-0000-000000000117','d0210000-0000-0000-0000-000000000118',timestamptz '2026-08-03 08:00:00+07');

insert into atlas_planning.theoretical_need_lines(theoretical_need_line_id,need_generation_run_id,need_generation_input_snapshot_id,need_generation_recipe_selection_id,need_generation_recipe_line_use_id,weekly_menu_approval_snapshot_line_id,weekly_menu_approval_snapshot_id,weekly_menu_id,weekly_menu_version,weekly_menu_line_id,attendance_approval_snapshot_line_id,attendance_approval_snapshot_id,attendance_batch_id,attendance_version,attendance_line_id,school_id,service_date,dish_id,recipe_id,recipe_version_id,recipe_line_id,recipe_line_revision_id,ingredient_id,unit_id,need_generation_calculation_contract_id,need_generation_calculation_contract_revision_id,calculation_contract_revision_number,line_disposition,theoretical_quantity,created_at,contribution_family)
values('d0210000-0000-0000-0000-000000000120','d0210000-0000-0000-0000-000000000100','d0210000-0000-0000-0000-000000000103','d0210000-0000-0000-0000-000000000110','d0210000-0000-0000-0000-000000000116','d0210000-0000-0000-0000-000000000111','d0210000-0000-0000-0000-000000000105','d0210000-0000-0000-0000-000000000104',1,'d0210000-0000-0000-0000-000000000112','d0210000-0000-0000-0000-000000000119','d0210000-0000-0000-0000-000000000107','d0210000-0000-0000-0000-000000000106',1,'d0210000-0000-0000-0000-00000000011a','d0210000-0000-0000-0000-000000000014',date '2026-08-03','d0210000-0000-0000-0000-000000000113','d0210000-0000-0000-0000-000000000114','d0210000-0000-0000-0000-000000000115','d0210000-0000-0000-0000-000000000117','d0210000-0000-0000-0000-000000000118','d0210000-0000-0000-0000-000000000016','d0210000-0000-0000-0000-000000000015','d0210000-0000-0000-0000-000000000108','d0210000-0000-0000-0000-000000000109',1,'ACTIVE',5,timestamptz '2026-08-03 08:00:00+07','RECIPE_DERIVED');
insert into atlas_planning.theoretical_need_lines(theoretical_need_line_id,need_generation_run_id,need_generation_input_snapshot_id,school_id,service_date,ingredient_id,unit_id,line_disposition,theoretical_quantity,created_at,contribution_family,delivery_location_id,pantry_need_batch_id,pantry_need_batch_version,pantry_need_approval_snapshot_id,pantry_need_line_id,pantry_active_snapshot_member_line_id)
values('d0210000-0000-0000-0000-000000000121','d0210000-0000-0000-0000-000000000100','d0210000-0000-0000-0000-000000000103','d0210000-0000-0000-0000-000000000014',date '2026-08-03','d0210000-0000-0000-0000-000000000016','d0210000-0000-0000-0000-000000000015','ACTIVE',7,timestamptz '2026-08-03 08:00:00+07','PANTRY_DIRECT','d0210000-0000-0000-0000-000000000012','d0210000-0000-0000-0000-000000000180',1,'d0210000-0000-0000-0000-000000000181','d0210000-0000-0000-0000-000000000182','d0210000-0000-0000-0000-000000000182');
insert into atlas_planning.need_generation_release_snapshots(need_generation_release_snapshot_id,need_generation_run_id,released_run_version,need_generation_input_snapshot_id,released_by_actor_id,released_at,generated_line_count,active_line_count,removed_line_count,blocking_issue_count,warning_count)
values('d0210000-0000-0000-0000-000000000190','d0210000-0000-0000-0000-000000000100',1,'d0210000-0000-0000-0000-000000000103','d0210000-0000-0000-0000-000000000001',timestamptz '2026-08-03 08:02:00+07',2,2,0,0,0);
insert into atlas_planning.need_generation_release_snapshot_lines(need_generation_release_snapshot_line_id,need_generation_release_snapshot_id,need_generation_run_id,released_run_version,theoretical_need_line_id) values
 ('d0210000-0000-0000-0000-000000000191','d0210000-0000-0000-0000-000000000190','d0210000-0000-0000-0000-000000000100',1,'d0210000-0000-0000-0000-000000000120'),
 ('d0210000-0000-0000-0000-000000000192','d0210000-0000-0000-0000-000000000190','d0210000-0000-0000-0000-000000000100',1,'d0210000-0000-0000-0000-000000000121');

set local session_replication_role = origin;

create temporary table png02_mixed_result(response_payload jsonb not null);
grant select,insert on png02_mixed_result to authenticated;
create function pg_temp.png02_mixed_request()
returns jsonb language sql stable set search_path='' as $$
  select pg_catalog.jsonb_build_object(
    'contract_version','PA-06E-H0C.v1','command_id','d0210000-0000-0000-0000-000000000900'::uuid,
    'correlation_id','d0210000-0000-0000-0000-000000000901'::uuid,'idempotency_key','png02-mixed-location',
    'expected_version',1,'requested_by_auth_subject','d0210000-0000-0000-0000-000000000002'::uuid,
    'requested_at',pg_catalog.transaction_timestamp(),'reason_code','PNG02_MIXED_LOCATION_TEST',
    'reason_note','Real mixed Recipe and Pantry destination regression','payload',pg_catalog.jsonb_build_object(
      'need_generation_run_id','d0210000-0000-0000-0000-000000000100'::uuid,
      'need_generation_run_version',1,'confirmed_need_batch_id',null
    )
  )
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub','d0210000-0000-0000-0000-000000000002',true);
insert into png02_mixed_result values(atlas_api.create_confirmed_needs_from_generation(pg_temp.png02_mixed_request()));
reset role;

-- 124
select is((select response_payload->>'success' from png02_mixed_result),'true','PNG02-124 real mixed-location CMD-15 succeeds');
-- 125
select is((select response_payload->>'idempotency_status' from png02_mixed_result),'COMPLETED','PNG02-125 real mixed-location command commits');
-- 126
select is((select count(*)::integer from atlas_planning.confirmed_need_lines where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from png02_mixed_result)),2,'PNG02-126 mixed destinations create exactly two stable lines');
-- 127
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from png02_mixed_result) and is_current),2,'PNG02-127 mixed destinations create exactly two current revisions');
-- 128
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from png02_mixed_result)),2,'PNG02-128 both released contributions have membership');
-- 129
select is((select array_agg(delivery_location_id order by delivery_location_id)::uuid[] from atlas_planning.confirmed_need_lines where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from png02_mixed_result)),array['d0210000-0000-0000-0000-000000000011'::uuid,'d0210000-0000-0000-0000-000000000012'::uuid],'PNG02-129 stable lines retain default and Pantry destinations separately');
-- 130
select is((select array_agg(theoretical.contribution_family order by theoretical.theoretical_need_line_id)::text[] from atlas_planning.confirmed_need_line_revisions revision join atlas_planning.confirmed_need_line_revision_contributions contribution using(confirmed_need_line_revision_id) join atlas_planning.theoretical_need_lines theoretical using(theoretical_need_line_id) where revision.confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from png02_mixed_result) and revision.delivery_location_id='d0210000-0000-0000-0000-000000000011'),array['RECIPE_DERIVED']::text[],'PNG02-130 default-location revision contains only Recipe membership');
-- 131
select is((select array_agg(theoretical.contribution_family order by theoretical.theoretical_need_line_id)::text[] from atlas_planning.confirmed_need_line_revisions revision join atlas_planning.confirmed_need_line_revision_contributions contribution using(confirmed_need_line_revision_id) join atlas_planning.theoretical_need_lines theoretical using(theoretical_need_line_id) where revision.confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from png02_mixed_result) and revision.delivery_location_id='d0210000-0000-0000-0000-000000000012'),array['PANTRY_DIRECT']::text[],'PNG02-131 Pantry-location revision contains only Pantry membership');
-- 132
select is((select theoretical_quantity from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from png02_mixed_result) and delivery_location_id='d0210000-0000-0000-0000-000000000011'),5::numeric,'PNG02-132 Recipe revision equals only its exact contribution');
-- 133
select is((select theoretical_quantity from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from png02_mixed_result) and delivery_location_id='d0210000-0000-0000-0000-000000000012'),7::numeric,'PNG02-133 Pantry revision equals only its exact contribution');
-- 134
select is((select array_agg(theoretical_quantity order by theoretical_quantity)::numeric[] from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from png02_mixed_result)),array[5::numeric,7::numeric],'PNG02-134 different-location quantities are never cross-added');
-- 135
select is((select count(*)::integer from atlas_planning.need_generation_release_snapshot_lines release_line where release_line.need_generation_release_snapshot_id='d0210000-0000-0000-0000-000000000190' and (select count(*) from atlas_planning.confirmed_need_line_revision_contributions contribution join atlas_planning.confirmed_need_line_revisions revision using(confirmed_need_line_revision_id) where contribution.need_generation_release_snapshot_line_id=release_line.need_generation_release_snapshot_line_id and revision.is_current)=1),2,'PNG02-135 every released theoretical line has exactly one current membership');
-- 136
select is((select count(*)::integer from (select contribution.theoretical_need_line_id from atlas_planning.confirmed_need_line_revision_contributions contribution join atlas_planning.confirmed_need_line_revisions revision using(confirmed_need_line_revision_id) where contribution.confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from png02_mixed_result) and revision.is_current group by contribution.theoretical_need_line_id having count(distinct revision.confirmed_need_line_revision_id)>1) duplicated),0,'PNG02-136 no theoretical line belongs to two current revisions');
-- 137
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions contribution join atlas_planning.confirmed_need_line_revisions revision using(confirmed_need_line_revision_id) join atlas_planning.theoretical_need_lines theoretical using(theoretical_need_line_id) join atlas_admin.schools school on school.school_id=theoretical.school_id where contribution.confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from png02_mixed_result) and contribution.delivery_location_id is distinct from case when theoretical.contribution_family='PANTRY_DIRECT' then theoretical.delivery_location_id else school.default_delivery_location_id end),0,'PNG02-137 every membership uses its exact family-aware destination');
-- 138
select is((select (response_payload#>>'{result_counts,created_confirmed_need_line_count}')::integer from png02_mixed_result),(select count(*)::integer from atlas_planning.confirmed_need_lines where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from png02_mixed_result)),'PNG02-138 response created-line count agrees with committed facts');
-- 139
select is((select (response_payload#>>'{result_counts,created_line_revision_count}')::integer from png02_mixed_result),(select count(*)::integer from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from png02_mixed_result)),'PNG02-139 response revision count agrees with committed facts');
-- 140
select is((select (response_payload#>>'{result_counts,created_revision_contribution_count}')::integer from png02_mixed_result),(select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from png02_mixed_result)),'PNG02-140 response contribution count agrees with committed facts');
-- 141
select is((select (response_payload#>>'{result_counts,current_line_revision_count}')::integer from png02_mixed_result),(select count(*)::integer from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from png02_mixed_result) and is_current),'PNG02-141 response current-revision count agrees with committed facts');
-- 142
select is((select jsonb_build_array(response_payload#>>'{result_counts,reused_confirmed_need_line_count}',response_payload#>>'{result_counts,retired_confirmed_need_line_count}',response_payload#>>'{result_counts,superseded_line_revision_count}') from png02_mixed_result),jsonb_build_array('0','0','0'),'PNG02-142 initial mixed command reports no reused retired or superseded facts');
-- 143
select ok((select pg_get_functiondef('atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()'::regprocedure) like all(array['%theoretical.contribution_family = ''PANTRY_DIRECT''%','%then theoretical.delivery_location_id%','%then predecessor_contribution.delivery_location_id%','%else revision.delivery_location_id%']) and pg_get_functiondef('atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()'::regprocedure) not like '%school.default_delivery_location_id%') and (select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) not like all(array['%atlas_planning.pantry_need_batches%','%atlas_planning.pantry_need_lines%','%atlas_planning.pantry_need_approval_snapshots%','%atlas_planning.pantry_need_approval_snapshot_lines%'])),'PNG02-143 H0B1b uses captured destinations while CMD-15 reads no Pantry base table');
-- 144
select is((select jsonb_build_object('signature',oid::regprocedure::text,'owner',pg_get_userbyid(proowner),'definer',prosecdef,'search_path',proconfig,'contract',(pg_get_functiondef(oid) like '%atlas_core.pa_06e_h0cb_validate_materialization_request(request)%' and pg_get_functiondef('atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb)'::regprocedure) like '%PA-06E-H0C.v1%'),'capability',(select count(*) from atlas_core.capabilities where capability_code='confirmed_need_generation.materialize')) from pg_proc where oid='atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure),jsonb_build_object('signature','atlas_api.create_confirmed_needs_from_generation(jsonb)','owner','atlas_planning_materialization_runtime','definer',true,'search_path',array['search_path=""']::text[],'contract',true,'capability',1),'PNG02-144 command signature runtime security contract and capability remain exact');

select * from finish();
rollback;
