begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select no_plan();

select has_column('atlas_admin','ingredients','document_code','Ingredient owns explicit outward document code');
select has_column('atlas_admin','suppliers','document_code','Supplier owns explicit outward document code');
select has_column('atlas_procurement','purchase_order_revisions','supplier_document_code_snapshot','PO header freezes supplier outward code');
select has_column('atlas_procurement','purchase_order_line_revisions','ingredient_document_code_snapshot','PO line freezes item outward code');
select has_column('atlas_procurement','purchase_order_line_revisions','ingredient_name_snapshot','PO line freezes Ingredient display name');
select has_column('atlas_procurement','purchase_order_line_revisions','unit_code_snapshot','PO line freezes Unit display code');

insert into atlas_admin.ingredients(ingredient_code,ingredient_name) values
  ('v1-ingredient-1082','Proven imported item'),
  ('v1-ingredient-123456789012345678901234567890','Large legacy identity'),
  ('v1-ingredient-01082','Leading zero is not approved provenance'),
  ('ingredient-native-doc-test','Native item');
insert into atlas_admin.suppliers(supplier_code,supplier_name) values
  ('v1-supplier-53','Proven imported supplier'),
  ('v1-supplier-0','Zero is not approved provenance'),
  ('supplier-native-doc-test','Native supplier');
select is((select to_jsonb(i)->>'document_code' from atlas_admin.ingredients i where ingredient_code='v1-ingredient-1082'),'1082','exact V1 item provenance becomes numeric text');
select is((select to_jsonb(i)->>'document_code' from atlas_admin.ingredients i where ingredient_code='v1-ingredient-123456789012345678901234567890'),'123456789012345678901234567890','legacy suffix is text without numeric overflow');
select is((select to_jsonb(s)->>'document_code' from atlas_admin.suppliers s where supplier_code='v1-supplier-53'),'53','exact V1 supplier provenance becomes numeric text');
select ok((select to_jsonb(i)->>'document_code' is null from atlas_admin.ingredients i where ingredient_code='v1-ingredient-01082'),'unapproved technical prefix form stays null');
select ok((select to_jsonb(s)->>'document_code' is null from atlas_admin.suppliers s where supplier_code='v1-supplier-0'),'zero legacy form stays null');
select ok((select to_jsonb(i)->>'document_code' is null from atlas_admin.ingredients i where ingredient_code='ingredient-native-doc-test'),'native item has no invented outward code');
select ok((select to_jsonb(s)->>'document_code' is null from atlas_admin.suppliers s where supplier_code='supplier-native-doc-test'),'native supplier has no invented outward code');

-- Governed native codes and strict code safety through the existing commands.
insert into atlas_core.actors(actor_id,actor_type,display_name) values
 ('d7100000-0000-4000-8000-000000000001','HUMAN','Document-code operator'),
 ('d7100000-0000-4000-8000-000000000002','HUMAN','Denied document-code operator');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id) values
 ('d7100000-0000-4000-8000-000000000001','d7100000-0000-4000-8000-000000000101'),
 ('d7100000-0000-4000-8000-000000000002','d7100000-0000-4000-8000-000000000102');
insert into atlas_core.roles(role_id,role_code,role_name) values
 ('d7100000-0000-4000-8000-000000000003','doc-code-author','Document-code author');
insert into atlas_core.role_capabilities(role_id,capability_id)
select 'd7100000-0000-4000-8000-000000000003',capability_id from atlas_core.capabilities where capability_code like 'master_data.%';
insert into atlas_core.actor_role_memberships(actor_id,role_id) values
 ('d7100000-0000-4000-8000-000000000001','d7100000-0000-4000-8000-000000000003');
insert into atlas_core.actor_scopes(actor_id,scope_kind) values
 ('d7100000-0000-4000-8000-000000000001','GLOBAL'),
 ('d7100000-0000-4000-8000-000000000002','GLOBAL');
insert into atlas_admin.units(unit_id,unit_code,unit_name,dimension_code) values
 ('d7100000-0000-4000-8000-000000000010','doc-kg','Kilogram','mass');
create function pg_temp.doc_request(p_payload jsonb,p_version bigint,p_key text) returns jsonb language sql as $$
 select jsonb_build_object('contract_version','RMVP-01.v1','command_id',md5(p_key)::uuid,
 'correlation_id','d7100000-0000-4000-8000-000000000099','idempotency_key',p_key,'expected_version',p_version,
 'requested_by_auth_subject','d7100000-0000-4000-8000-000000000101','requested_at',transaction_timestamp()-interval '1 second',
 'reason_code','DOCUMENT_CODE_TEST','reason_note','Rolled-back document-code test','payload',p_payload);
$$;
create function pg_temp.doc_ingredient(p_code jsonb) returns jsonb language sql as $$
 select jsonb_build_object('ingredient_code','native-document-item','ingredient_name','Native item',
 'purchase_unit_id','d7100000-0000-4000-8000-000000000010','ingredient_type','Thực phẩm khô - gia vị',
 'shopping_type','Hàng đặt riêng','order_step',1,'document_code',p_code);
$$;
create temporary table doc_results(name text primary key,response jsonb);
grant select,insert on doc_results to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','d7100000-0000-4000-8000-000000000101',true);
insert into doc_results values
 ('create-item',atlas_api.create_ingredient(pg_temp.doc_request(pg_temp.doc_ingredient('"ITEM-A"'::jsonb),1,'doc-item-create'))),
 ('create-item-replay',atlas_api.create_ingredient(pg_temp.doc_request(pg_temp.doc_ingredient('"ITEM-A"'::jsonb),1,'doc-item-create'))),
 ('create-supplier',atlas_api.create_supplier(pg_temp.doc_request('{"supplier_name":"Native supplier","document_code":"NCC-A"}',1,'doc-supplier-create')));
reset role;
select is((select response->>'success' from doc_results where name='create-item'),'true','native item document code is authored through create');
select is((select response from doc_results where name='create-item-replay'),(select response from doc_results where name='create-item'),'create exact replay returns same document identity');
select is((select document_code from atlas_admin.ingredients where ingredient_code='native-document-item'),'ITEM-A','authored native item code persists');
select is((select document_code from atlas_admin.suppliers where supplier_id=(select (response#>>'{affected_aggregate_ids,supplier_id}')::uuid from doc_results where name='create-supplier')),'NCC-A','authored native supplier code persists');
set local role authenticated;
insert into doc_results values('read',atlas_api.get_ingredient_supplier_master_data(jsonb_build_object('contract_version','RMVP-01.v1','correlation_id','d7100000-0000-4000-8000-000000000099','requested_by_auth_subject','d7100000-0000-4000-8000-000000000101','payload','{}'::jsonb)));
insert into doc_results values
 ('update-item',atlas_api.update_ingredient(pg_temp.doc_request(pg_temp.doc_ingredient('"ITEM-B"')||jsonb_build_object('ingredient_id',(select response#>>'{affected_aggregate_ids,ingredient_id}' from doc_results where name='create-item')),1,'doc-item-update'))),
 ('stale-item',atlas_api.update_ingredient(pg_temp.doc_request(pg_temp.doc_ingredient('"STALE"')||jsonb_build_object('ingredient_id',(select response#>>'{affected_aggregate_ids,ingredient_id}' from doc_results where name='create-item')),1,'doc-item-stale'))),
 ('preserve-item',atlas_api.update_ingredient(pg_temp.doc_request((pg_temp.doc_ingredient('null')-'document_code')||jsonb_build_object('ingredient_id',(select response#>>'{affected_aggregate_ids,ingredient_id}' from doc_results where name='create-item')),2,'doc-item-preserve'))),
 ('invalid-blank',atlas_api.create_ingredient(pg_temp.doc_request(pg_temp.doc_ingredient('" "'),1,'doc-invalid-blank'))),
 ('invalid-uuid',atlas_api.create_ingredient(pg_temp.doc_request(pg_temp.doc_ingredient('"d7100000-0000-4000-8000-000000000010"'),1,'doc-invalid-uuid'))),
 ('invalid-prefix',atlas_api.create_ingredient(pg_temp.doc_request(pg_temp.doc_ingredient('"v1-ingredient-1082"'),1,'doc-invalid-prefix'))),
 ('invalid-type',atlas_api.create_supplier(pg_temp.doc_request('{"supplier_name":"Bad code","document_code":53}',1,'doc-invalid-type'))),
 ('invalid-long',atlas_api.create_supplier(pg_temp.doc_request(jsonb_build_object('supplier_name','Bad code','document_code',repeat('X',201)),1,'doc-invalid-long'))),
 ('invalid-embedded-create',atlas_api.create_supplier(pg_temp.doc_request('{"supplier_name":"Embedded UUID","document_code":"ITEM-25000000-0000-4000-8000-000000000001"}',1,'doc-invalid-embedded-create'))),
 ('invalid-control',atlas_api.create_supplier(pg_temp.doc_request(jsonb_build_object('supplier_name','Control code','document_code',E'ITEM\nNEW'),1,'doc-invalid-control'))),
 ('invalid-nbsp',atlas_api.create_supplier(pg_temp.doc_request(jsonb_build_object('supplier_name','Boundary whitespace','document_code',U&'\00A0NCC'),1,'doc-invalid-nbsp'))),
 ('invalid-bom',atlas_api.create_supplier(pg_temp.doc_request(jsonb_build_object('supplier_name','Boundary whitespace','document_code',U&'NCC\FEFF'),1,'doc-invalid-bom'))),
 ('invalid-tab',atlas_api.create_supplier(pg_temp.doc_request(jsonb_build_object('supplier_name','Control code','document_code',E'ITEM\tNEW'),1,'doc-invalid-tab'))),
 ('clear-supplier',atlas_api.update_supplier(pg_temp.doc_request(jsonb_build_object('supplier_id',(select response#>>'{affected_aggregate_ids,supplier_id}' from doc_results where name='create-supplier'),'supplier_name','Native supplier','document_code',null),1,'doc-supplier-clear')));
reset role;
set local role authenticated;
insert into doc_results values('invalid-embedded-update',atlas_api.update_supplier(pg_temp.doc_request(jsonb_build_object('supplier_id',(select response#>>'{affected_aggregate_ids,supplier_id}' from doc_results where name='create-supplier'),'supplier_name','Native supplier','document_code','ITEM-25000000-0000-4000-8000-000000000001'),2,'doc-invalid-embedded-update')));
reset role;
select ok((select bool_and(value ? 'document_code') from doc_results,jsonb_array_elements(response->'ingredients') where name='read'),'shaped Ingredient read always exposes nullable document_code');
select ok((select bool_and(value ? 'document_code') from doc_results,jsonb_array_elements(response->'suppliers') where name='read'),'shaped Supplier read always exposes nullable document_code');
select is((select document_code from atlas_admin.ingredients where ingredient_code='native-document-item'),'ITEM-B','update persists code and omitted update preserves it');
select is((select response->>'error_code' from doc_results where name='stale-item'),'STALE_VERSION','document-code update cannot overwrite stale version');
select ok((select bool_and(coalesce(response->>'error_code'='VALIDATION_FAILED',false)) from doc_results where name like 'invalid-%'),'blank, UUID including embedded UUID, technical prefix, type and oversized explicit codes reject safely');
select ok((select document_code is null from atlas_admin.suppliers where supplier_id=(select (response#>>'{affected_aggregate_ids,supplier_id}')::uuid from doc_results where name='create-supplier')),'explicit null clears the governed native supplier code');
select ok(exists(select 1 from atlas_audit.audit_events where aggregate_type='Ingredient' and after_summary->>'document_code'='ITEM-B'),'document-code changes retain existing audit evidence');
insert into atlas_admin.ingredients(ingredient_code,ingredient_name,document_code) values('v1-ingredient-956','Explicit imported override','ITEM-EXPLICIT');
select is((select document_code from atlas_admin.ingredients where ingredient_code='v1-ingredient-956'),'ITEM-EXPLICIT','ongoing import insertion never clobbers explicitly supplied code');
select ok(not has_table_privilege('authenticated','atlas_admin.ingredients','UPDATE') and not has_table_privilege('authenticated','atlas_admin.suppliers','UPDATE'),'browser cannot write document codes through private tables');
select ok(not has_function_privilege('authenticated','atlas_core.lock_school_catering_po_document_facts(uuid,uuid)','EXECUTE') and not has_function_privilege('service_role','atlas_core.lock_school_catering_po_document_facts(uuid,uuid)','EXECUTE'),'document row-lock helper remains private');
select ok((select count(*)=4 and bool_and(p.proconfig=array['search_path=""']::text[] and pg_get_userbyid(p.proowner)=expected.owner and p.prosecdef=expected.definer and not has_function_privilege('anon',p.oid,'EXECUTE') and not has_function_privilege('authenticated',p.oid,'EXECUTE') and not has_function_privilege('service_role',p.oid,'EXECUTE')) from (values
 ('derive_v1_master_document_code','atlas_master_data_command_runtime',false),
 ('lock_school_catering_po_document_facts','atlas_owner',true),
 ('freeze_school_catering_po_header_document_code','atlas_procurement_command_runtime',true),
 ('guard_po_document_identity_snapshot','atlas_owner',false)
) expected(name,owner,definer) join pg_proc p on p.proname=expected.name join pg_namespace n on n.oid=p.pronamespace and n.nspname='atlas_core'),'all four bounded private helpers preserve exact ownership, fixed paths and denied browser execution');
select ok(has_column_privilege('atlas_master_data_command_runtime','atlas_admin.ingredients','document_code','INSERT,UPDATE') and has_column_privilege('atlas_master_data_command_runtime','atlas_admin.suppliers','document_code','INSERT,UPDATE') and not exists(select 1 from pg_policy p where p.polrelid in ('atlas_admin.ingredients'::regclass,'atlas_admin.suppliers'::regclass) and p.polcmd in ('w','*') and (select oid from pg_roles where rolname='atlas_procurement_command_runtime')=any(p.polroles)),'existing master writer owns document-code writes and Procurement has no Admin UPDATE RLS policy');
set local role authenticated;
select set_config('request.jwt.claim.sub','d7100000-0000-4000-8000-000000000102',true);
insert into doc_results values('capability-denied',atlas_api.create_supplier(jsonb_set(pg_temp.doc_request('{"supplier_name":"Denied","document_code":"NCC-DENIED"}',1,'doc-denied'),'{requested_by_auth_subject}','"d7100000-0000-4000-8000-000000000102"')));
reset role;
select is((select response->>'error_code' from doc_results where name='capability-denied'),'CAPABILITY_DENIED','document-code authoring requires existing master write capability');
delete from atlas_core.actor_scopes where actor_id='d7100000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','d7100000-0000-4000-8000-000000000101',true);
insert into doc_results values('scope-denied',atlas_api.create_supplier(pg_temp.doc_request('{"supplier_name":"Denied","document_code":"NCC-DENIED"}',1,'doc-scope-denied')));
reset role;
select is((select response->>'error_code' from doc_results where name='scope-denied'),'SCOPE_DENIED','document-code authoring requires GLOBAL Admin scope');
select * from finish();
rollback;
