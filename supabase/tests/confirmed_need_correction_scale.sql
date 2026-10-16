begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select plan(20);
\ir ../local/confirmed_need_correction_scale_fixture.sql

select is((select count(*)from atlas_planning.confirmed_need_lines l
 join atlas_planning.confirmed_need_line_revisions r on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
 where l.confirmed_need_batch_id=(select(value#>>'{}')::uuid from c_scale_context where name='batch')and r.confirmed_quantity>0),
 250::bigint,'genuine public workload retains250 positive whole families');
select is((select count(distinct school_id)from atlas_planning.confirmed_need_line_revisions where is_current),50::bigint,
 'public generated Need represents50 Schools');
select is((select count(distinct delivery_location_id)from atlas_planning.confirmed_need_line_revisions where is_current),50::bigint,
 'each School has a distinct captured delivery location');
select is((select count(distinct ingredient_id)from atlas_planning.confirmed_need_line_revisions where is_current),5::bigint,
 'workload has five Ingredients');
select is((select count(*)from c_scale_results where name like'allocation-%'and api='save_confirmed_supplier_allocation'),250::bigint,
 'all250 initial allocations were saved through authenticated public commands');
select is((select batch_status from atlas_planning.confirmed_need_batches
 where confirmed_need_batch_id=(select(value#>>'{}')::uuid from c_scale_context where name='batch')),
 'RELEASED_FOR_PURCHASE_HANDOFF','final explicit Preparation leaves genuine released Need');
select is((select count(*)from atlas_planning.purchase_handoff_revisions),9::bigint,
 'eight public correction cycles append nine consecutive Handoff revisions');
select is((select count(distinct history_depth)from c_scale_results where history_depth>0),8::bigint,
 'all eight measured history depths completed');
select is((select count(*)from c_scale_results where history_depth>0),80::bigint,
 'each history edge completed ten explicit public operations');
select ok((select bool_and(invoked_as='authenticated'and response->>'success'='true')from c_scale_results),
 'one authenticated Actor succeeds throughout the public workflow');
select ok((select bool_and(elapsed_ms<8000)from c_scale_results where api<>'prepare_school_catering_purchase_orders'),
 'every complete non-Preparation public response including guards remains below8s');
select ok((select bool_and(elapsed_ms<20000)from c_scale_results where api='prepare_school_catering_purchase_orders'),
 'every complete Preparation response including guards remains below its existing20s');
select is((select count(*)from c_scale_preserved),249::bigint,'249 untouched allocation identities are retained');
select is((select count(*)from c_scale_other_pos old join atlas_procurement.purchase_orders p using(purchase_order_id)
 join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
 where r.is_current and to_jsonb(p)is not distinct from old.root and to_jsonb(r)is not distinct from old.revision),4::bigint,
 'four other Supplier POs retain exact immutable identities and current root versions');
select is((select count(*)from atlas_procurement.purchase_orders),13::bigint,
 'five original complete Supplier POs plus eight explicit complete replacements are preserved');
select is((select count(*)from atlas_dispatch.school_dispatch_releases),9::bigint,
 'only the selected School has one initial PXK and eight explicit successors');
select is((select confirmed_quantity from atlas_planning.confirmed_need_line_revisions where is_current
 and school_id='b6500000-0000-0000-000000000004'and ingredient_id='b6500000-0000-0000-0000-000000000006'),108::numeric,
 'eight selected-line corrections preserve exact final quantity108');
select is((select count(*)from atlas_procurement.purchase_orders where purchase_order_status='RELEASED_TO_SUPPLIER'),5::bigint,
 'exactly five complete current Supplier commitments remain');
select ok((select bool_and(jsonb_array_length(response->'rows')=50)from c_scale_results
 where api='get_school_dispatch_release_workbench'),
 'every full PXK read covers all50 School scopes rather than a reduced sample');
select ok((select bool_and(jsonb_array_length(response->'rows')=250)from c_scale_results
 where api='get_confirmed_supplier_allocation_workbench'),
 'every full allocation read covers250 families');
select diag(jsonb_build_object('workload','50 Schools x5 Ingredients; one selected School PXK; eight history edges',
 'local_sql_only_not_hosted_http',true,'measurements',(select jsonb_agg(to_jsonb(r)-'response'order by history_depth,name)
 from c_scale_results r))::text);
select *from finish();
rollback;
