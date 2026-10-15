begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select plan(9);
\ir ../local/confirmed_need_correction_fixture.sql
select ok(not exists(select from c_results where invoked_as<>'authenticated'),
 'C fixture calls tested public APIs as authenticated');
select is((select count(*) from atlas_planning.confirmed_need_validation_lines
 where current_confirmed_need_line_decision_id is not null),6::bigint,
 'real validation captured all six immutable non-NULL decisions');
select is((select count(*) from atlas_planning.confirmed_need_approval_snapshots),2::bigint,
 'real public approval created historical authority');
select is((select count(*) from atlas_procurement.purchase_orders
 where purchase_order_status='RELEASED_TO_SUPPLIER'),4::bigint,
 'four actual Supplier/date POs were explicitly released');
select is((select count(*) from atlas_dispatch.school_dispatch_releases
 where release_status='RELEASED'),3::bigint,'three actual School PXKs were explicitly released');
select is((select response->>'error_code' from c_results
 where name='ordinary-released-save'),'CONFIRMED_NEED_BATCH_NOT_EDITABLE',
 'ordinary released Save remains blocked');
select is((select jsonb_agg(to_jsonb(r)order by r.confirmed_need_line_revision_id)
 from atlas_planning.confirmed_need_line_revisions r),
 (select revisions from c_before_ordinary),'denied ordinary Save writes no successor');
select ok(to_regprocedure('atlas_api.get_confirmed_need_correction_preview(jsonb)')is not null,
 'C dedicated correction preview exists');
select ok(to_regprocedure('atlas_api.correct_confirmed_need(jsonb)')is not null,
 'C atomic correction command exists');
select * from finish();
rollback;
