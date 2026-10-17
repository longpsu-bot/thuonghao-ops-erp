begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select plan(9);
\ir ../local/confirmed_need_correction_fixture.sql

-- Run both stored implementations against the same disposable raw rowsets.
-- The oracle is the unchanged per-revision membership helper, not copied proof logic.
do $$
declare relation text; definition text; target text;
begin
 foreach relation in array array['purchase_handoff_revisions','purchase_handoff_batches',
  'purchase_handoff_line_revisions','purchase_handoff_lines','purchase_demand_references',
  'confirmed_need_snapshot_lines','confirmed_need_approval_snapshots'] loop
  execute format('create temporary table p395_%I as select * from atlas_planning.%I',relation,relation);
 end loop;
 foreach target in array array['confirmed_need_handoff_membership','purchase_review_continuity_context'] loop
  definition:=pg_get_functiondef(('atlas_core.'||target||'(uuid)')::regprocedure);
  definition:=replace(definition,'atlas_core.'||target||'(','pg_temp.p395_'||target||'(');
  foreach relation in array array['purchase_handoff_revisions','purchase_handoff_batches',
   'purchase_handoff_line_revisions','purchase_handoff_lines','purchase_demand_references',
   'confirmed_need_snapshot_lines','confirmed_need_approval_snapshots'] loop
   definition:=replace(definition,'atlas_planning.'||relation,'pg_temp.p395_'||relation);
  end loop;
  -- Incumbent context delegates here; candidate resolves bindings relationally.
  definition:=replace(definition,'atlas_core.confirmed_need_handoff_membership(',
   'pg_temp.p395_confirmed_need_handoff_membership(');
  execute definition;
 end loop;
end;$$;

create function pg_temp.p395_comparison() returns boolean language sql as $$
 with contexts as materialized (
  select atlas_core.purchase_review_correction_roots(b.confirmed_need_batch_id) roots,
   pg_temp.p395_purchase_review_continuity_context(b.confirmed_need_batch_id) context
  from atlas_planning.confirmed_need_batches b where b.source_kind='NEED_GENERATION'
 ), comparisons as (
  select h.value metadata,pg_temp.p395_confirmed_need_handoff_membership(
   (h.value->>'purchase_handoff_revision_id')::uuid) oracle,
   coalesce((select jsonb_agg(m.value order by m.value->>'purchase_handoff_line_revision_id')
    from jsonb_each(context#>array['handoff_members',h.value->>'purchase_handoff_revision_id',h.value->>'member_group_key']) f
    cross join lateral jsonb_array_elements(f.value) m),'[]'::jsonb) actual
  from contexts cross join lateral jsonb_array_elements(context->'handoffs') h
 ) select count(*)>0 and bool_and(
  (metadata#>'{membership,complete}') is not distinct from oracle->'complete'
  and actual is not distinct from oracle->'members') from comparisons;
$$;

select ok(pg_temp.p395_comparison(),'phase members equal every exact incumbent per-revision member');
create temporary table p395_results(name text,pass boolean);
do $$
declare property record; result boolean;
begin
 for property in select * from(values
 ('missing Handoff lines','delete from pg_temp.p395_purchase_handoff_line_revisions'),
 ('duplicate raw demand references','insert into pg_temp.p395_purchase_demand_references select * from pg_temp.p395_purchase_demand_references'),
 ('missing Handoff line identity','delete from pg_temp.p395_purchase_handoff_lines'),
 ('missing approval membership','delete from pg_temp.p395_confirmed_need_snapshot_lines'),
 ('missing approval header','delete from pg_temp.p395_confirmed_need_approval_snapshots'),
 ('NULL historical release time','update pg_temp.p395_purchase_handoff_revisions set released_at=null'),
 ('changed captured quantity','update pg_temp.p395_confirmed_need_snapshot_lines set approved_quantity=approved_quantity+0.000001'),
 ('NULL exact Unit','update pg_temp.p395_purchase_handoff_line_revisions set unit_id=null')
 )cases(name,mutation) loop
  begin
   execute property.mutation;
   result:=pg_temp.p395_comparison();
   raise sqlstate 'PZ395';
  exception when sqlstate 'PZ395' then null;
  end;
  insert into p395_results values(property.name,result);
 end loop;
end;$$;
select ok(pass,'phase parity: '||name) from p395_results;
select * from finish();
rollback;
