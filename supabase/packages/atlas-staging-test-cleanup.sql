-- One Owner-approved Staging maintenance exception. All objects are session-local.
-- Fixed recovery rows/guards are pinned below; this is not a reusable purge API.
CREATE OR REPLACE FUNCTION pg_temp.cleanup_key_expression(target regclass, alias_name text)
RETURNS text LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
  SELECT 'jsonb_build_object('||string_agg(format('%L,%I.%I',a.attname,alias_name,a.attname),',' ORDER BY k.ord)||')'
  FROM pg_catalog.pg_constraint c CROSS JOIN LATERAL unnest(c.conkey) WITH ORDINALITY k(attnum,ord)
  JOIN pg_catalog.pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=k.attnum
  WHERE c.conrelid=target AND c.contype='p'
$$;

CREATE OR REPLACE FUNCTION pg_temp.cleanup_catalog(semantic boolean DEFAULT false)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
SELECT jsonb_build_object(
  'tables',(SELECT jsonb_agg(jsonb_build_array(n.nspname,c.relname,c.relkind,c.relrowsecurity,c.relforcerowsecurity,pg_catalog.pg_get_userbyid(c.relowner),c.relacl) ORDER BY n.nspname,c.relname) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE (n.nspname LIKE 'atlas\_%' ESCAPE '\' OR n.nspname IN('auth','public','supabase_migrations')) AND c.relkind IN('r','p','v','m','S')),
  'columns',(SELECT jsonb_agg(jsonb_build_array(n.nspname,c.relname,a.attname,a.attnum,pg_catalog.format_type(a.atttypid,a.atttypmod),a.attnotnull,a.attidentity,a.attgenerated,pg_catalog.pg_get_expr(d.adbin,d.adrelid),a.attacl) ORDER BY n.nspname,c.relname,a.attnum) FROM pg_catalog.pg_attribute a JOIN pg_catalog.pg_class c ON c.oid=a.attrelid JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace LEFT JOIN pg_catalog.pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum WHERE (n.nspname LIKE 'atlas\_%' ESCAPE '\' OR n.nspname IN('auth','public','supabase_migrations')) AND a.attnum>0 AND NOT a.attisdropped),
  'constraints',(SELECT jsonb_agg(jsonb_build_array(n.nspname,c.relname,k.conname,k.convalidated,pg_catalog.pg_get_constraintdef(k.oid,true)) ORDER BY n.nspname,c.relname,k.conname) FROM pg_catalog.pg_constraint k JOIN pg_catalog.pg_class c ON c.oid=k.conrelid JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname LIKE 'atlas\_%' ESCAPE '\' OR n.nspname IN('auth','public','supabase_migrations')),
  'indexes',(SELECT jsonb_agg(jsonb_build_array(n.nspname,c.relname,pg_catalog.pg_get_indexdef(i.indexrelid),i.indisvalid,i.indisready) ORDER BY n.nspname,c.relname,pg_catalog.pg_get_indexdef(i.indexrelid)) FROM pg_catalog.pg_index i JOIN pg_catalog.pg_class c ON c.oid=i.indrelid JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname LIKE 'atlas\_%' ESCAPE '\' OR n.nspname IN('auth','public','supabase_migrations')),
  'triggers',(SELECT jsonb_agg(jsonb_build_array(r.nspname,r.relname,r.name,r.tgenabled,r.tgisinternal,r.definition,r.function_definition) ORDER BY r.nspname,r.relname,r.name) FROM (
    SELECT n.nspname,c.relname,t.tgenabled,t.tgisinternal,
      CASE WHEN semantic AND t.tgisinternal THEN 'INTERNAL:'||k.conrelid::regclass::text||':'||k.conname||':'||p.proname||':'||t.tgtype ELSE t.tgname::text END AS name,
      CASE WHEN semantic AND t.tgisinternal THEN replace(pg_catalog.pg_get_triggerdef(t.oid,true),pg_catalog.quote_ident(t.tgname),pg_catalog.quote_ident('INTERNAL:'||k.conrelid::regclass::text||':'||k.conname||':'||p.proname||':'||t.tgtype)) ELSE pg_catalog.pg_get_triggerdef(t.oid,true) END AS definition,
      pg_catalog.pg_get_functiondef(t.tgfoid) AS function_definition
    FROM pg_catalog.pg_trigger t JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace JOIN pg_catalog.pg_proc p ON p.oid=t.tgfoid LEFT JOIN pg_catalog.pg_constraint k ON k.oid=t.tgconstraint
    WHERE n.nspname LIKE 'atlas\_%' ESCAPE '\' OR n.nspname IN('auth','public','supabase_migrations')) r),
  'policies',(SELECT jsonb_agg(to_jsonb(p) ORDER BY p.schemaname,p.tablename,p.policyname) FROM pg_catalog.pg_policies p WHERE p.schemaname LIKE 'atlas\_%' ESCAPE '\' OR p.schemaname IN('auth','public','supabase_migrations')),
  'functions',(SELECT jsonb_agg(jsonb_build_array(n.nspname,p.proname,pg_catalog.pg_get_function_identity_arguments(p.oid),pg_catalog.pg_get_functiondef(p.oid),pg_catalog.pg_get_userbyid(p.proowner),p.proacl) ORDER BY n.nspname,p.proname,pg_catalog.pg_get_function_identity_arguments(p.oid)) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE (n.nspname LIKE 'atlas\_%' ESCAPE '\' OR n.nspname IN('auth','public')) AND p.prokind IN('f','p')),
  'roles',(SELECT jsonb_agg(jsonb_build_array(r.rolname,r.rolsuper,r.rolinherit,r.rolcreaterole,r.rolcreatedb,r.rolcanlogin,r.rolreplication,r.rolbypassrls,r.rolconfig) ORDER BY r.rolname) FROM pg_catalog.pg_roles r),
  'memberships',(SELECT jsonb_agg(jsonb_build_array(pg_catalog.pg_get_userbyid(m.roleid),pg_catalog.pg_get_userbyid(m.member),m.admin_option) ORDER BY m.roleid,m.member) FROM pg_catalog.pg_auth_members m),
  'default_acl',(SELECT jsonb_agg(jsonb_build_array(pg_catalog.pg_get_userbyid(d.defaclrole),n.nspname,d.defaclobjtype,d.defaclacl) ORDER BY pg_catalog.pg_get_userbyid(d.defaclrole),n.nspname,d.defaclobjtype) FROM pg_catalog.pg_default_acl d LEFT JOIN pg_catalog.pg_namespace n ON n.oid=d.defaclnamespace),
  'schemas',(SELECT jsonb_agg(jsonb_build_array(n.nspname,pg_catalog.pg_get_userbyid(n.nspowner),n.nspacl) ORDER BY n.nspname) FROM pg_catalog.pg_namespace n WHERE n.nspname LIKE 'atlas\_%' ESCAPE '\' OR n.nspname IN('auth','public','supabase_migrations'))
)
$$;

CREATE OR REPLACE FUNCTION pg_temp.cleanup_fingerprints(exclude_manifest boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path='' AS $$
DECLARE item record; result jsonb:='{}'; value jsonb; predicate text; key_sql text;
BEGIN
  FOR item IN SELECT n.nspname,c.relname,c.oid FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE (n.nspname LIKE 'atlas\_%' ESCAPE '\' OR n.nspname IN('auth','public','supabase_migrations')) AND c.relkind IN('r','p') ORDER BY n.nspname,c.relname LOOP
    predicate:='';
    IF exclude_manifest THEN
      IF EXISTS(SELECT 1 FROM pg_temp.cleanup_rows r WHERE r.table_name=item.nspname||'.'||item.relname) THEN
        key_sql:=pg_temp.cleanup_key_expression(item.oid::regclass,'t');
        predicate:=format(' WHERE NOT EXISTS(SELECT 1 FROM pg_temp.cleanup_rows r WHERE r.table_name=%L AND r.identity=%s)',item.nspname||'.'||item.relname,key_sql);
      END IF;
    END IF;
    EXECUTE format('SELECT jsonb_build_object(''count'',count(*),''sha256'',encode(extensions.digest(coalesce(string_agg(to_jsonb(t)::text,E''\n'' ORDER BY to_jsonb(t)::text),''''),''sha256''),''hex'')) FROM %I.%I t%s',item.nspname,item.relname,predicate) INTO value;
    result:=result||jsonb_build_object(item.nspname||'.'||item.relname,value);
  END LOOP;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION pg_temp.cleanup_atlas_schema_checksum()
RETURNS text LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
  SELECT atlas_legacy.master_snapshot_hash(jsonb_object_agg(e.key,filtered.rows))
  FROM jsonb_each(pg_temp.cleanup_catalog(true)) e
  CROSS JOIN LATERAL (SELECT coalesce(jsonb_agg(r.value ORDER BY r.ord),'[]'::jsonb) AS rows
    FROM jsonb_array_elements(e.value) WITH ORDINALITY r(value,ord)
    WHERE coalesce(r.value->>'schemaname',r.value->>0) LIKE 'atlas\_%' ESCAPE '\') filtered
  WHERE e.key IN('tables','columns','constraints','indexes','triggers','policies','functions','schemas')
$$;

CREATE OR REPLACE FUNCTION pg_temp.cleanup_compositions()
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path='' AS $$
DECLARE context record; result jsonb:='[]';
BEGIN
  FOR context IN SELECT d.dish_id,t.school_type_id,null::uuid AS school_id,'2026-11-09'::date AS as_of_date
    FROM atlas_legacy.master_data_mappings d CROSS JOIN atlas_legacy.master_data_mappings t
    WHERE d.source_system='OPS_V1' AND d.object_type='DISH' AND t.source_system='OPS_V1' AND t.object_type='SCHOOL_TYPE' AND t.legacy_id IN('1','2')
    UNION SELECT a.dish_id,t.school_type_id,a.school_id,'2026-11-09'::date
    FROM (SELECT dish_id,school_id FROM atlas_admin.recipe_composition_adjustments
      UNION SELECT (row_data->>'dish_id')::uuid,(row_data->>'school_id')::uuid FROM pg_temp.cleanup_rows WHERE table_name='atlas_admin.recipe_composition_adjustments') a
    JOIN atlas_legacy.master_data_mappings d ON d.dish_id=a.dish_id AND d.source_system='OPS_V1' AND d.object_type='DISH'
    CROSS JOIN atlas_legacy.master_data_mappings t
    WHERE a.school_id IS NOT NULL AND t.source_system='OPS_V1' AND t.object_type='SCHOOL_TYPE' AND t.legacy_id IN('1','2')
    ORDER BY 1,2,3 NULLS FIRST
  LOOP
    result:=result||jsonb_build_array(jsonb_build_array(context.dish_id,context.school_type_id,context.school_id,context.as_of_date,atlas_legacy.master_snapshot_hash(atlas_core.recipe_effective_resolve_composition(context.as_of_date,context.school_id,context.dish_id,context.school_type_id))));
  END LOOP;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION pg_temp.run_staging_test_cleanup(recovery jsonb,expected_migrations jsonb,apply_requested boolean,reviewed_checksum jsonb,proof jsonb,commit_sha jsonb,source_hashes jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path='' AS $$
DECLARE item record; entry jsonb; row_entry jsonb; table_name text; key_sql text; order_sql text; predicate text; actual jsonb; versions jsonb; before_catalog jsonb; before_facts jsonb; protected_facts jsonb; before_compositions jsonb; plan text; result jsonb; ctes text:=''; unions text:=''; ordinal integer:=0; deleted_count bigint; matched bigint; system_contexts bigint; trigger_modes jsonb:='[]'; guard jsonb;
BEGIN
  IF current_user<>'postgres' OR pg_catalog.to_regclass('public.schools') IS NOT NULL THEN RAISE EXCEPTION 'CLEANUP_TARGET_DENIED'; END IF;
  IF apply_requested IS NULL THEN RAISE EXCEPTION 'EXPLICIT_CLEANUP_MODE_REQUIRED'; END IF;
  -- One fixed recovery set; payloads retain exact PostgreSQL JSON decimals as strings.
  IF coalesce(recovery,'null'::jsonb)<>'null'::jsonb AND (jsonb_typeof(recovery) IS DISTINCT FROM 'array' OR jsonb_array_length(recovery)<>67) THEN RAISE EXCEPTION 'RECOVERY_REQUIRED'; END IF;
  CREATE TEMP TABLE cleanup_rows(table_name text NOT NULL,identity jsonb NOT NULL,row_data jsonb NOT NULL,ordinal bigint NOT NULL,PRIMARY KEY(table_name,identity)) ON COMMIT DROP;
  -- Deterministic locks also protect the exact-state capture used by GitHub.
  FOR item IN SELECT n.nspname,c.relname FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE (n.nspname LIKE 'atlas\_%' ESCAPE '\' OR n.nspname IN('auth','public','supabase_migrations')) AND c.relkind IN('r','p') ORDER BY n.nspname,c.relname LOOP
    -- Platform-owned ledger is SELECT-only. Its before/after hash must still match.
    IF item.nspname='auth' AND item.relname='schema_migrations' THEN
      EXECUTE 'LOCK TABLE auth.schema_migrations IN ACCESS SHARE MODE';
    ELSE
      EXECUTE format('LOCK TABLE %I.%I IN ACCESS EXCLUSIVE MODE',item.nspname,item.relname);
    END IF;
  END LOOP;
  IF coalesce(recovery,'null'::jsonb)='null'::jsonb THEN
    FOR entry IN SELECT value FROM jsonb_array_elements(pg_temp.cleanup_fixed_manifest()) LOOP
      table_name:=entry->>'table'; key_sql:=pg_temp.cleanup_key_expression(table_name::regclass,'t');
      SELECT string_agg(format('t.%I',k.value),',' ORDER BY k.ord) INTO order_sql FROM jsonb_array_elements_text(entry->'primary_key') WITH ORDINALITY k(value,ord);
      predicate:=CASE WHEN (entry->>'whole_table')::boolean THEN '' ELSE format(' WHERE %s IN(SELECT value FROM jsonb_array_elements(%L::jsonb))',key_sql,entry->'identities') END;
      EXECUTE format('INSERT INTO pg_temp.cleanup_rows SELECT %L,%s,to_jsonb(t),row_number() OVER(ORDER BY %s) FROM %s t%s',table_name,key_sql,order_sql,table_name::regclass,predicate);
    END LOOP;
  ELSE
  FOR entry IN SELECT value FROM jsonb_array_elements(recovery) LOOP
    table_name:=entry->>'table';
    SELECT m INTO actual FROM jsonb_array_elements(pg_temp.cleanup_fixed_manifest()) m WHERE m->>'table'=table_name;
    IF actual IS NULL OR entry->>'project_id' IS DISTINCT FROM 'rnzxmxiiqgtdevzregff' OR entry->'primary_key' IS DISTINCT FROM actual->'primary_key' OR entry->'row_count' IS DISTINCT FROM actual->'row_count' OR entry->>'sha256' IS DISTINCT FROM actual->>'sha256' THEN RAISE EXCEPTION 'RECOVERY_TABLE_MISMATCH: %',table_name; END IF;
    IF (SELECT encode(extensions.digest(string_agg(r.value,E'\n' ORDER BY r.ord),'sha256'),'hex') FROM jsonb_array_elements_text(entry->'row_texts') WITH ORDINALITY r(value,ord)) IS DISTINCT FROM actual->>'sha256' THEN RAISE EXCEPTION 'RECOVERY_BYTES_MISMATCH: %',table_name; END IF;
    INSERT INTO pg_temp.cleanup_rows SELECT table_name,(SELECT jsonb_object_agg(k,r.value::jsonb->k) FROM jsonb_array_elements_text(entry->'primary_key') k),r.value::jsonb,r.ord FROM jsonb_array_elements_text(entry->'row_texts') WITH ORDINALITY r(value,ord);
  END LOOP;
  END IF;
  IF (SELECT count(*) FROM pg_temp.cleanup_rows)<>27431 OR (SELECT count(DISTINCT r.table_name) FROM pg_temp.cleanup_rows r)<>67 THEN RAISE EXCEPTION 'RECOVERY_MEMBERSHIP_MISMATCH'; END IF;
  SELECT jsonb_agg(version ORDER BY version) INTO versions FROM supabase_migrations.schema_migrations;
  IF versions IS DISTINCT FROM expected_migrations THEN RAISE EXCEPTION 'MIGRATION_HISTORY_MISMATCH'; END IF;
  IF pg_temp.cleanup_atlas_schema_checksum() IS DISTINCT FROM '08fc31ff1cd527b348767e61ab2fcde2783d1e6b8a419ddd166a23d407100708' THEN RAISE EXCEPTION 'REVIEWED_STAGING_SCHEMA_MISMATCH'; END IF;
  IF (SELECT coalesce(jsonb_agg(a.recipe_composition_adjustment_id::text ORDER BY a.recipe_composition_adjustment_id::text),'[]'::jsonb) FROM atlas_admin.recipe_composition_adjustments a WHERE NOT EXISTS(SELECT 1 FROM pg_temp.cleanup_rows r WHERE r.table_name='atlas_admin.recipe_composition_adjustments' AND r.identity=jsonb_build_object('recipe_composition_adjustment_id',a.recipe_composition_adjustment_id))) IS DISTINCT FROM pg_temp.cleanup_business_adjustment_ids() THEN RAISE EXCEPTION 'NINE_BUSINESS_ADJUSTMENTS_REQUIRED'; END IF;
  FOR entry IN SELECT value FROM jsonb_array_elements(pg_temp.cleanup_fixed_manifest()) LOOP
    table_name:=entry->>'table'; key_sql:=pg_temp.cleanup_key_expression(table_name::regclass,'t');
    IF (SELECT encode(extensions.digest(string_agg(r.row_data::text,E'\n' ORDER BY r.ordinal),'sha256'),'hex') FROM pg_temp.cleanup_rows r WHERE r.table_name=entry->>'table') IS DISTINCT FROM entry->>'sha256' THEN RAISE EXCEPTION 'PINNED_EXTERNAL_BACKUP_CONTENT_MISMATCH: %',table_name; END IF;
    IF key_sql IS NULL THEN RAISE EXCEPTION 'PRIMARY_KEY_REQUIRED'; END IF;
    EXECUTE format('SELECT count(*) FROM %s t JOIN pg_temp.cleanup_rows r ON r.table_name=%L AND r.identity=%s WHERE to_jsonb(t)=r.row_data',table_name::regclass,table_name,key_sql) INTO matched;
    IF matched<>(entry->>'row_count')::bigint THEN RAISE EXCEPTION 'RECOVERY_TARGET_DRIFT: %',table_name; END IF;
  END LOOP;
  FOR entry IN SELECT value FROM jsonb_array_elements(pg_temp.cleanup_operational_manifest()) LOOP
    EXECUTE format('SELECT count(*) FROM %s',(entry->>'table_name')::regclass) INTO matched;
    IF matched<>(entry->>'row_count')::bigint THEN RAISE EXCEPTION 'OPERATIONAL_SCOPE_DRIFT: %',entry->>'table_name'; END IF;
  END LOOP;
  FOR guard IN SELECT value FROM jsonb_array_elements(pg_temp.cleanup_delete_guards()) LOOP
    SELECT jsonb_build_object('mode',t.tgenabled,'definition',pg_catalog.pg_get_triggerdef(t.oid,true),'internal',t.tgisinternal,'type',t.tgtype,'function_sha256',encode(extensions.digest(pg_catalog.pg_get_functiondef(t.tgfoid),'sha256'),'hex')) INTO actual FROM pg_catalog.pg_trigger t WHERE t.tgrelid=(guard->>'table')::regclass AND t.tgname=guard->>'trigger';
    IF actual->>'definition' IS DISTINCT FROM guard->>'definition' OR actual->>'mode' IS DISTINCT FROM 'O' OR actual->>'internal' IS DISTINCT FROM 'false' OR actual->'type' IS DISTINCT FROM guard->'type' OR actual->>'function_sha256' IS DISTINCT FROM guard->>'function_sha256' OR ((actual->>'type')::integer & 8)<>8 THEN RAISE EXCEPTION 'BUSINESS_GUARD_DRIFT: %',guard->>'trigger'; END IF;
    trigger_modes:=trigger_modes||jsonb_build_array(guard||jsonb_build_object('mode',actual->>'mode'));
  END LOOP;
  before_catalog:=pg_temp.cleanup_catalog(); before_facts:=pg_temp.cleanup_fingerprints(); protected_facts:=pg_temp.cleanup_fingerprints(true);
  SELECT count(*) INTO system_contexts FROM atlas_legacy.master_data_mappings d CROSS JOIN atlas_legacy.master_data_mappings t WHERE d.source_system='OPS_V1' AND d.object_type='DISH' AND t.source_system='OPS_V1' AND t.object_type='SCHOOL_TYPE' AND t.legacy_id IN('1','2');
  IF system_contexts<>1534 AND NOT(current_database() LIKE 'atlas_cleanup_proof\_%' ESCAPE '\' AND inet_server_addr() IS NULL) THEN RAISE EXCEPTION 'ALL_MAPPED_SYSTEM_CONTEXTS_REQUIRED'; END IF;
  before_compositions:=pg_temp.cleanup_compositions();
  plan:=atlas_legacy.master_snapshot_hash(jsonb_build_object('target','rnzxmxiiqgtdevzregff','commit',commit_sha,'source_hashes',source_hashes,'migrations',versions,'catalog',before_catalog,'facts',before_facts,'recovery_manifest_sha256','6a11d91dfb3f7715bbc120f3f1deabd0b2fe9a125f327b727685d50cb2f8b29a','manifest',pg_temp.cleanup_fixed_manifest(),'guards',trigger_modes,'compositions',before_compositions));
  IF apply_requested AND (reviewed_checksum#>>'{}') IS DISTINCT FROM plan THEN RAISE EXCEPTION 'REVIEWED_PLAN_DRIFT'; END IF;
  -- A provisional receipt can exercise only a newly owned local Unix-socket DB.
  -- The hosted TLS/TCP transport cannot use this rehearsal-only path.
  IF apply_requested AND NOT (coalesce(proof->>'status'='LOCAL_REHEARSAL_PROVISIONAL',false) AND current_database() LIKE 'atlas_cleanup_proof\_%' ESCAPE '\' AND inet_server_addr() IS NULL) THEN
    IF proof->>'status' IS DISTINCT FROM 'RESTORED_EXACTLY' OR proof->>'recovery_manifest_sha256' IS DISTINCT FROM '6a11d91dfb3f7715bbc120f3f1deabd0b2fe9a125f327b727685d50cb2f8b29a' OR proof->'commit_sha' IS DISTINCT FROM commit_sha OR proof->>'deleted_rows' IS DISTINCT FROM '27431' OR proof->>'restored_rows' IS DISTINCT FROM '27431' OR proof->>'atlas_schema_checksum' IS DISTINCT FROM pg_temp.cleanup_atlas_schema_checksum() OR proof->>'purge_constraints_checked_before_restore' IS DISTINCT FROM 'true' OR proof->>'all_foreign_keys_validated' IS DISTINCT FROM 'true' OR proof->>'in_place_catalog_and_all_rows_equal' IS DISTINCT FROM 'true' OR proof->>'external_reconstruction_catalog_and_all_rows_equal' IS DISTINCT FROM 'true' OR proof->>'restore_guards_sha256' IS DISTINCT FROM '1a8e1eae8563655ac81db71170e67a346931d56881954aaf29eb8c53328fde18' OR proof->'source_hashes' IS DISTINCT FROM source_hashes THEN RAISE EXCEPTION 'RECOVERY_PROOF_REQUIRED'; END IF;
  END IF;
  BEGIN
    FOR guard IN SELECT value FROM jsonb_array_elements(trigger_modes) LOOP
      EXECUTE format('ALTER TABLE %s DISABLE TRIGGER %I',(guard->>'table')::regclass,guard->>'trigger');
    END LOOP;
    CREATE TEMP TABLE cleanup_deleted(table_name text,identity jsonb,PRIMARY KEY(table_name,identity)) ON COMMIT DROP;
    FOR entry IN SELECT value FROM jsonb_array_elements(pg_temp.cleanup_fixed_manifest()) LOOP
      table_name:=entry->>'table'; key_sql:=pg_temp.cleanup_key_expression(table_name::regclass,'t'); ordinal:=ordinal+1;
      ctes:=ctes||CASE WHEN ordinal>1 THEN ',' ELSE '' END||format('d%s AS (DELETE FROM %s t USING pg_temp.cleanup_rows r WHERE r.table_name=%L AND r.identity=%s RETURNING %L::text AS table_name,%s AS identity)',ordinal,table_name::regclass,table_name,key_sql,table_name,key_sql);
      unions:=unions||CASE WHEN ordinal>1 THEN ' UNION ALL ' ELSE '' END||format('SELECT * FROM d%s',ordinal);
    END LOOP;
    -- One statement lets immediate RESTRICT FKs see all cyclic removals together.
    EXECUTE 'WITH '||ctes||' INSERT INTO pg_temp.cleanup_deleted '||unions;
    SET CONSTRAINTS ALL IMMEDIATE;
    SELECT count(*) INTO deleted_count FROM pg_temp.cleanup_deleted;
    IF deleted_count<>27431 OR EXISTS((SELECT r.table_name,r.identity FROM pg_temp.cleanup_rows r EXCEPT SELECT d.table_name,d.identity FROM pg_temp.cleanup_deleted d) UNION ALL (SELECT d.table_name,d.identity FROM pg_temp.cleanup_deleted d EXCEPT SELECT r.table_name,r.identity FROM pg_temp.cleanup_rows r)) THEN RAISE EXCEPTION 'DELETE_RETURNING_MEMBERSHIP_MISMATCH'; END IF;
    FOR guard IN SELECT value FROM jsonb_array_elements(trigger_modes) LOOP
      EXECUTE format('ALTER TABLE %s ENABLE TRIGGER %I',(guard->>'table')::regclass,guard->>'trigger');
    END LOOP;
    IF pg_temp.cleanup_catalog() IS DISTINCT FROM before_catalog THEN RAISE EXCEPTION 'CATALOG_NOT_RESTORED'; END IF;
    IF pg_temp.cleanup_fingerprints(true) IS DISTINCT FROM protected_facts THEN RAISE EXCEPTION 'OUTSIDE_MANIFEST_FACTS_CHANGED'; END IF;
    IF pg_temp.cleanup_compositions() IS DISTINCT FROM before_compositions THEN RAISE EXCEPTION 'MAPPED_CANONICAL_COMPOSITION_CHANGED'; END IF;
    FOR entry IN SELECT value FROM jsonb_array_elements(pg_temp.cleanup_operational_manifest()) LOOP
      EXECUTE format('SELECT count(*) FROM %s',(entry->>'table_name')::regclass) INTO matched;
      IF matched<>0 THEN RAISE EXCEPTION 'OPERATIONAL_ROWS_REMAIN'; END IF;
    END LOOP;
    result:=jsonb_build_object('status',CASE WHEN apply_requested THEN 'APPLIED' ELSE 'PREVIEW' END,'deleted_rows',deleted_count,'operational_rows',27402,'fixture_rows',29,'recovery_manifest_sha256','6a11d91dfb3f7715bbc120f3f1deabd0b2fe9a125f327b727685d50cb2f8b29a','catalog_restored',true,'protected_facts_preserved',true,'content_checksum',plan,'catalog_checksum',atlas_legacy.master_snapshot_hash(before_catalog),'canonical_context_count',jsonb_array_length(before_compositions),'system_context_count',system_contexts,'rolled_back',NOT apply_requested);
    IF NOT apply_requested THEN RAISE EXCEPTION SQLSTATE 'P9001' USING MESSAGE='PREVIEW_ROLLBACK'; END IF;
  EXCEPTION WHEN SQLSTATE 'P9001' THEN
    IF apply_requested OR sqlerrm<>'PREVIEW_ROLLBACK' THEN RAISE; END IF;
  END;
  IF NOT apply_requested AND (pg_temp.cleanup_catalog() IS DISTINCT FROM before_catalog OR pg_temp.cleanup_fingerprints() IS DISTINCT FROM before_facts) THEN RAISE EXCEPTION 'PREVIEW_NOT_ROLLED_BACK'; END IF;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION pg_temp.cleanup_fixed_manifest() RETURNS jsonb LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path='' AS $fixed$ SELECT $json$[
  {
    "table": "atlas_admin.customers",
    "primary_key": [
      "customer_id"
    ],
    "row_count": 1,
    "sha256": "0af209cda69fe4f784bede62b59959c352b669374bf8e7f9ad0f8695d350cbfe",
    "whole_table": false,
    "identities": [
      {
        "customer_id": "a1020000-0000-4000-8000-000000000201"
      }
    ]
  },
  {
    "table": "atlas_admin.delivery_locations",
    "primary_key": [
      "delivery_location_id"
    ],
    "row_count": 1,
    "sha256": "20ebc7f16feb98bca6fbe4b0a9f361a1540fbff8ae91d2f9a719a2467731beff",
    "whole_table": false,
    "identities": [
      {
        "delivery_location_id": "a1020000-0000-4000-8000-000000000202"
      }
    ]
  },
  {
    "table": "atlas_admin.dishes",
    "primary_key": [
      "dish_id"
    ],
    "row_count": 2,
    "sha256": "e3a2f84ab23a64e5d8398a11c05f74c7a51deb1872a536be1c5622e3f755b896",
    "whole_table": false,
    "identities": [
      {
        "dish_id": "22656372-430d-4afb-9e23-bd482f29853f"
      },
      {
        "dish_id": "8f74321a-7b12-4926-aa24-ffd5e0cdb10b"
      }
    ]
  },
  {
    "table": "atlas_admin.ingredients",
    "primary_key": [
      "ingredient_id"
    ],
    "row_count": 1,
    "sha256": "a3a914f8214ed20d9c62765ed6bca1d36bc66cbe94bd4afc46f0e5a2f9bda525",
    "whole_table": false,
    "identities": [
      {
        "ingredient_id": "80253553-f585-4270-a777-71fefdeaa886"
      }
    ]
  },
  {
    "table": "atlas_admin.recipe_composition_adjustment_revisions",
    "primary_key": [
      "recipe_composition_adjustment_revision_id"
    ],
    "row_count": 3,
    "sha256": "fe203797c8b32948d2a75f918e3b33af97d585b61071fe311e928cde8ebcded1",
    "whole_table": false,
    "identities": [
      {
        "recipe_composition_adjustment_revision_id": "1354bf93-1473-4967-8e11-5a7e52e8cbe9"
      },
      {
        "recipe_composition_adjustment_revision_id": "278ce4e9-8878-4b0d-91db-eafa370a7850"
      },
      {
        "recipe_composition_adjustment_revision_id": "4623c083-20ef-4830-bd49-5b30e10ed507"
      }
    ]
  },
  {
    "table": "atlas_admin.recipe_composition_adjustments",
    "primary_key": [
      "recipe_composition_adjustment_id"
    ],
    "row_count": 3,
    "sha256": "d18c1bca252edd49990cb614b3a0a260f1a3c6a07feea42ee761aaf604da48b1",
    "whole_table": false,
    "identities": [
      {
        "recipe_composition_adjustment_id": "50b5eb6e-9850-4eea-b549-49d4cc33b46f"
      },
      {
        "recipe_composition_adjustment_id": "9f824c75-a1d4-4c8b-9e2c-41f757d9ff84"
      },
      {
        "recipe_composition_adjustment_id": "ca15944e-42c5-4e26-ac5a-1c4ac10dea8c"
      }
    ]
  },
  {
    "table": "atlas_admin.recipe_line_revisions",
    "primary_key": [
      "recipe_line_revision_id"
    ],
    "row_count": 4,
    "sha256": "ddcb0185eab5871750bcaba16aeca0bee94eab740613c65fa58f40ba2e53e3f0",
    "whole_table": false,
    "identities": [
      {
        "recipe_line_revision_id": "149e2799-c45e-4784-b012-860d7b0cc0fc"
      },
      {
        "recipe_line_revision_id": "195b93c9-d8b6-43f2-abc6-0bf9ae8af55b"
      },
      {
        "recipe_line_revision_id": "35f73a6a-5f2e-43b2-be7b-4a63160e6b24"
      },
      {
        "recipe_line_revision_id": "8cce1045-3da6-40e6-bc3e-709b1d924cdc"
      }
    ]
  },
  {
    "table": "atlas_admin.recipe_lines",
    "primary_key": [
      "recipe_line_id"
    ],
    "row_count": 2,
    "sha256": "cd27dd37e048c4dbdff0e7d400640b3f0c53b3c3a2353b9eda1b70b84fc48116",
    "whole_table": false,
    "identities": [
      {
        "recipe_line_id": "6492752d-b666-4c75-8b22-29704f32faf2"
      },
      {
        "recipe_line_id": "da95b76e-bc53-41b1-82d3-8641c421d3e1"
      }
    ]
  },
  {
    "table": "atlas_admin.recipe_versions",
    "primary_key": [
      "recipe_version_id"
    ],
    "row_count": 4,
    "sha256": "9ebe5078a9eab2b6d13507e230ced3445c252ba41112b4c443b924b3dbf25880",
    "whole_table": false,
    "identities": [
      {
        "recipe_version_id": "51d207ff-dfde-441f-90ff-9cbb656d511b"
      },
      {
        "recipe_version_id": "67b44c29-0a87-4fd7-ad0e-3c078ebd63c6"
      },
      {
        "recipe_version_id": "6d237257-94f0-41a9-b199-953f844e2d47"
      },
      {
        "recipe_version_id": "96ddf7e2-ccb8-44cd-9b70-eefbf215dc0e"
      }
    ]
  },
  {
    "table": "atlas_admin.recipes",
    "primary_key": [
      "recipe_id"
    ],
    "row_count": 4,
    "sha256": "b6535a318f627142de65862424806481ef862a59cbb4f1bd283c908e91b39135",
    "whole_table": false,
    "identities": [
      {
        "recipe_id": "302e8c5a-7227-44ea-824c-5f04d1b59670"
      },
      {
        "recipe_id": "3f0b0431-733b-434f-9444-a4c3d64df22e"
      },
      {
        "recipe_id": "5254d5d9-1485-4fb3-8f02-ae39f3ca0466"
      },
      {
        "recipe_id": "e19d4a8b-03a8-465e-8ba0-476806f0fc5d"
      }
    ]
  },
  {
    "table": "atlas_admin.school_types",
    "primary_key": [
      "school_type_id"
    ],
    "row_count": 1,
    "sha256": "a9f53fee5ca585b3d78253728cb593038da30620fa6f5ccf6156fd45b75de735",
    "whole_table": false,
    "identities": [
      {
        "school_type_id": "a1020000-0000-4000-8000-000000000203"
      }
    ]
  },
  {
    "table": "atlas_admin.schools",
    "primary_key": [
      "school_id"
    ],
    "row_count": 1,
    "sha256": "d3990218174a6dc1b67e27f947ba0f4c9f4d438b1de7c5150adaa471b5a3c69b",
    "whole_table": false,
    "identities": [
      {
        "school_id": "a1020000-0000-4000-8000-000000000204"
      }
    ]
  },
  {
    "table": "atlas_admin.supplier_eligibilities",
    "primary_key": [
      "supplier_eligibility_id"
    ],
    "row_count": 1,
    "sha256": "976921015e90606698df3ed8bde3a9d2d8205a3ece8d617d8e0559caa52c3854",
    "whole_table": false,
    "identities": [
      {
        "supplier_eligibility_id": "20f408b7-cdfc-4d8e-a8dc-88ac06692deb"
      }
    ]
  },
  {
    "table": "atlas_admin.suppliers",
    "primary_key": [
      "supplier_id"
    ],
    "row_count": 1,
    "sha256": "e15f8852fbc72679e5dcb2c7c997795f726d695347c3d697eaf9d4cdef24ca3f",
    "whole_table": false,
    "identities": [
      {
        "supplier_id": "2980a8e7-936a-455d-840b-1ff8e472600f"
      }
    ]
  },
  {
    "table": "atlas_dispatch.school_dispatch_release_line_sources",
    "primary_key": [
      "school_dispatch_release_line_source_id"
    ],
    "row_count": 205,
    "sha256": "ce42d78457dbe1facbcdcae13a1a646419f6b3572d89594e4baea3d22c0c6865",
    "whole_table": true
  },
  {
    "table": "atlas_dispatch.school_dispatch_release_lines",
    "primary_key": [
      "school_dispatch_release_line_id"
    ],
    "row_count": 205,
    "sha256": "e7e17337be2c85837f8dfb7bd2b88ae1a112e45346dd810616bf8b72afb4817c",
    "whole_table": true
  },
  {
    "table": "atlas_dispatch.school_dispatch_releases",
    "primary_key": [
      "school_dispatch_release_id"
    ],
    "row_count": 22,
    "sha256": "04e7a07a28876106f8f7e0a1b00c2038857498c44cad4ad8b787146d35fe5e84",
    "whole_table": true
  },
  {
    "table": "atlas_planning.attendance_approval_snapshot_lines",
    "primary_key": [
      "attendance_approval_snapshot_line_id"
    ],
    "row_count": 703,
    "sha256": "e35e5cf3db0e1c2ef93c03270df3b846085ea7282d8b191c0f10573916261053",
    "whole_table": true
  },
  {
    "table": "atlas_planning.attendance_approval_snapshots",
    "primary_key": [
      "attendance_approval_snapshot_id"
    ],
    "row_count": 13,
    "sha256": "a85b7dddd37714135bf809f7af3117d63aad43ae5c27dbc831bef19e9379a921",
    "whole_table": true
  },
  {
    "table": "atlas_planning.attendance_batches",
    "primary_key": [
      "attendance_batch_id"
    ],
    "row_count": 8,
    "sha256": "617fd69c1e9d83408750439f44a46383ce7b47bd1a4e18726273ad2f760bd4f8",
    "whole_table": true
  },
  {
    "table": "atlas_planning.attendance_lines",
    "primary_key": [
      "attendance_line_id"
    ],
    "row_count": 586,
    "sha256": "7f49912630557e0011cfbac63d6104b553e78ee5c57fb3e9cebbcda07ae91afa",
    "whole_table": true
  },
  {
    "table": "atlas_planning.confirmed_need_approval_snapshots",
    "primary_key": [
      "confirmed_need_approval_snapshot_id"
    ],
    "row_count": 13,
    "sha256": "2760425ffe28941899cc5dd5a6125d4c4302f777e74865f7b591d65f883c514b",
    "whole_table": true
  },
  {
    "table": "atlas_planning.confirmed_need_batches",
    "primary_key": [
      "confirmed_need_batch_id"
    ],
    "row_count": 16,
    "sha256": "dbf052e0d5e6b26357fd66121e444e8fc3566b1884380f9dfb27ba8f6f7e3f53",
    "whole_table": true
  },
  {
    "table": "atlas_planning.confirmed_need_line_decision_continuity",
    "primary_key": [
      "confirmed_need_line_decision_continuity_id"
    ],
    "row_count": 1,
    "sha256": "56671a298066b0d72f78e033d3e03863af741b0fe5f8719dc528ccba1e309bdd",
    "whole_table": true
  },
  {
    "table": "atlas_planning.confirmed_need_line_decisions",
    "primary_key": [
      "confirmed_need_line_decision_id"
    ],
    "row_count": 1108,
    "sha256": "4ebb24010272e179896b1efdb847513a121d89b1c057877988341177195f70eb",
    "whole_table": true
  },
  {
    "table": "atlas_planning.confirmed_need_line_revision_contributions",
    "primary_key": [
      "confirmed_need_line_revision_contribution_id"
    ],
    "row_count": 1845,
    "sha256": "a4e4316e05ed3083c51960f4b9a84a17c5b1b83ebbfacc525bab5354ed870893",
    "whole_table": true
  },
  {
    "table": "atlas_planning.confirmed_need_line_revisions",
    "primary_key": [
      "confirmed_need_line_revision_id"
    ],
    "row_count": 1572,
    "sha256": "1bbfcf28747361403266f269c7ad197725c7aee762e9b509dc25e729f3c77841",
    "whole_table": true
  },
  {
    "table": "atlas_planning.confirmed_need_lines",
    "primary_key": [
      "confirmed_need_line_id"
    ],
    "row_count": 1311,
    "sha256": "0845530d19b796cc9ada997d5a57f4423e593d92ecb6b10b58e622a0ea8c5116",
    "whole_table": true
  },
  {
    "table": "atlas_planning.confirmed_need_releases",
    "primary_key": [
      "confirmed_need_release_id"
    ],
    "row_count": 13,
    "sha256": "9fadb59e98d755678b79bc1969ecca8b0b51570192b073fe90d0e4432f0e0cfc",
    "whole_table": true
  },
  {
    "table": "atlas_planning.confirmed_need_snapshot_lines",
    "primary_key": [
      "confirmed_need_snapshot_line_id"
    ],
    "row_count": 334,
    "sha256": "39440d3e63516f46a016eb44d032a555e87cb067582091e1535e295e586e4b69",
    "whole_table": true
  },
  {
    "table": "atlas_planning.confirmed_need_validation_attempts",
    "primary_key": [
      "confirmed_need_validation_attempt_id"
    ],
    "row_count": 13,
    "sha256": "3288b29834c43b38777a81f4ef42c24df910b112adad8482fcf6fc8bf5db1b4e",
    "whole_table": true
  },
  {
    "table": "atlas_planning.confirmed_need_validation_lines",
    "primary_key": [
      "confirmed_need_validation_line_id"
    ],
    "row_count": 334,
    "sha256": "a466715f891fbf05899d7707e3c5f14cf33cb69eb47d14435316ef77f948c10a",
    "whole_table": true
  },
  {
    "table": "atlas_planning.need_generation_input_snapshots",
    "primary_key": [
      "need_generation_input_snapshot_id"
    ],
    "row_count": 20,
    "sha256": "9f3e92e9c137fac7edb1de437b1fa0cd6070f01848721a1962f6679a05bc73e5",
    "whole_table": true
  },
  {
    "table": "atlas_planning.need_generation_issues",
    "primary_key": [
      "need_generation_issue_id"
    ],
    "row_count": 986,
    "sha256": "1b945b2f690ac2b9861c1a3dcd821048fae6f65bfbc66ae7a34e016f53efb27d",
    "whole_table": true
  },
  {
    "table": "atlas_planning.need_generation_recipe_line_uses",
    "primary_key": [
      "need_generation_recipe_line_use_id"
    ],
    "row_count": 2810,
    "sha256": "7e22a32d2a1d6577733196198ff939ffb53b695242681a57b23856e2e28fc021",
    "whole_table": true
  },
  {
    "table": "atlas_planning.need_generation_recipe_selections",
    "primary_key": [
      "need_generation_recipe_selection_id"
    ],
    "row_count": 985,
    "sha256": "984ce611428e6e882377fb863fe9f80986dd7a273868f52cbe6e3016847ae6e4",
    "whole_table": true
  },
  {
    "table": "atlas_planning.need_generation_release_snapshot_issues",
    "primary_key": [
      "need_generation_release_snapshot_issue_id"
    ],
    "row_count": 986,
    "sha256": "7bde80884a5b86a15ff00620e522aa59b26961275925d6edac466d6289e51c95",
    "whole_table": true
  },
  {
    "table": "atlas_planning.need_generation_release_snapshot_lines",
    "primary_key": [
      "need_generation_release_snapshot_line_id"
    ],
    "row_count": 2818,
    "sha256": "a1ae8532847ced8557cc25ecc58f8a57e77f3c63dc31996c7448b441790cccf7",
    "whole_table": true
  },
  {
    "table": "atlas_planning.need_generation_release_snapshots",
    "primary_key": [
      "need_generation_release_snapshot_id"
    ],
    "row_count": 20,
    "sha256": "5fbd5b947050f7941214552f837fe9f7bbf2cd60100daa8f0e851f397f4563a4",
    "whole_table": true
  },
  {
    "table": "atlas_planning.need_generation_runs",
    "primary_key": [
      "need_generation_run_id"
    ],
    "row_count": 20,
    "sha256": "29303faee765507c47fd58c34c363bf4647e9e4912cd14b21aa8f37a5e2346fc",
    "whole_table": true
  },
  {
    "table": "atlas_planning.pantry_need_approval_snapshot_lines",
    "primary_key": [
      "pantry_need_approval_snapshot_id",
      "pantry_need_line_id"
    ],
    "row_count": 17,
    "sha256": "669e9016be1b9469c0c1971575330ee1bac1734ad882c4af6cd68368670d1111",
    "whole_table": true
  },
  {
    "table": "atlas_planning.pantry_need_approval_snapshot_school_date_modes",
    "primary_key": [
      "pantry_need_approval_snapshot_id",
      "school_id",
      "service_date"
    ],
    "row_count": 16,
    "sha256": "343c18df7780f9ebf27352a9c93dda8b9307978c89a347d46691087e2ffefc5f",
    "whole_table": true
  },
  {
    "table": "atlas_planning.pantry_need_approval_snapshots",
    "primary_key": [
      "pantry_need_approval_snapshot_id"
    ],
    "row_count": 12,
    "sha256": "30e3cff8fec4b414d17682076566ad9da9444eadcaed52280b9c88177e0d1a25",
    "whole_table": true
  },
  {
    "table": "atlas_planning.pantry_need_batches",
    "primary_key": [
      "pantry_need_batch_id"
    ],
    "row_count": 7,
    "sha256": "63f670c67d960c7f9b149a64b84ed8f886b3be8288f5535dc484a8acf30d1536",
    "whole_table": true
  },
  {
    "table": "atlas_planning.pantry_need_lines",
    "primary_key": [
      "pantry_need_line_id"
    ],
    "row_count": 5,
    "sha256": "4748313f1d7f283cdda36edffffc3b72a2408820468e56f32bac31f7983fde44",
    "whole_table": true
  },
  {
    "table": "atlas_planning.pantry_need_school_date_modes",
    "primary_key": [
      "pantry_need_batch_id",
      "school_id",
      "service_date"
    ],
    "row_count": 4,
    "sha256": "fd5a266f80b16bceb00fcb2bdbdf282cb8dc10808a8c6db184adfdd548abdb59",
    "whole_table": true
  },
  {
    "table": "atlas_planning.planning_input_evaluation_issues",
    "primary_key": [
      "planning_input_readiness_issue_id"
    ],
    "row_count": 76,
    "sha256": "1120d014bed67bf9a69ca0c009fef7bac99ff6d433bc4144cf55d81f33256f63",
    "whole_table": true
  },
  {
    "table": "atlas_planning.planning_input_evaluations",
    "primary_key": [
      "planning_input_evaluation_id"
    ],
    "row_count": 20,
    "sha256": "ee4ee3c18ed4b09e4be7e2fe43be404e95105aca7cb06975d9de3bdb0688997c",
    "whole_table": true
  },
  {
    "table": "atlas_planning.planning_input_sets",
    "primary_key": [
      "planning_input_set_id"
    ],
    "row_count": 16,
    "sha256": "25e91caf1e51f973b72c568f4fb0143e2707d198694f131da108c64c94288198",
    "whole_table": true
  },
  {
    "table": "atlas_planning.purchase_demand_references",
    "primary_key": [
      "purchase_demand_reference_id"
    ],
    "row_count": 333,
    "sha256": "3309254742f8ecb548f9e97609e7bc400fc95ac164212270b7ce60bbfed154be",
    "whole_table": true
  },
  {
    "table": "atlas_planning.purchase_handoff_batches",
    "primary_key": [
      "purchase_handoff_batch_id"
    ],
    "row_count": 10,
    "sha256": "45028246914ead012b200cce2596327152501deaf8dd9f75451136a9e6e3c7d4",
    "whole_table": true
  },
  {
    "table": "atlas_planning.purchase_handoff_line_revisions",
    "primary_key": [
      "purchase_handoff_line_revision_id"
    ],
    "row_count": 333,
    "sha256": "4f7685323b94edb4e327ac6db6c0e11ca3d67a6da90d68f41609fa608a476145",
    "whole_table": true
  },
  {
    "table": "atlas_planning.purchase_handoff_lines",
    "primary_key": [
      "purchase_handoff_line_id"
    ],
    "row_count": 331,
    "sha256": "ae3f1e43de6695a6367740fcd08f4fd0b409a86309db7fa0751885011bf5812a",
    "whole_table": true
  },
  {
    "table": "atlas_planning.purchase_handoff_revisions",
    "primary_key": [
      "purchase_handoff_revision_id"
    ],
    "row_count": 12,
    "sha256": "ac3460390a2210ebabc7c738545953c92c24fc2c6ed249bfec347c92eaa4fdbe",
    "whole_table": true
  },
  {
    "table": "atlas_planning.theoretical_need_lines",
    "primary_key": [
      "theoretical_need_line_id"
    ],
    "row_count": 2818,
    "sha256": "d0c13492c1c57d8567b8754ec9db205482847f413369ac5d84b306d9e5fa8bf8",
    "whole_table": true
  },
  {
    "table": "atlas_planning.weekly_menu_approval_snapshot_lines",
    "primary_key": [
      "weekly_menu_approval_snapshot_line_id"
    ],
    "row_count": 1480,
    "sha256": "9eb25bc12456028fa9e73641e5dd4b97ff7e186655acee56e90be0c4656e0593",
    "whole_table": true
  },
  {
    "table": "atlas_planning.weekly_menu_approval_snapshots",
    "primary_key": [
      "weekly_menu_approval_snapshot_id"
    ],
    "row_count": 7,
    "sha256": "401eee98c9a422623d68151dc96027855730aa85e43ab929d9b7c409fd5ae4b2",
    "whole_table": true
  },
  {
    "table": "atlas_planning.weekly_menu_lines",
    "primary_key": [
      "weekly_menu_line_id"
    ],
    "row_count": 1480,
    "sha256": "4c2c8fa1bf433dd1e58889f70a4fc00a9e7979730fa36d46b0044d70e791cc93",
    "whole_table": true
  },
  {
    "table": "atlas_planning.weekly_menus",
    "primary_key": [
      "weekly_menu_id"
    ],
    "row_count": 7,
    "sha256": "9565dc940876e5972edb69a6808fa3b2bcebfb78aed001a97e2a96507a777f2a",
    "whole_table": true
  },
  {
    "table": "atlas_procurement.purchase_order_line_revisions",
    "primary_key": [
      "purchase_order_line_revision_id"
    ],
    "row_count": 580,
    "sha256": "e3bac2003b7c4e6c22462697ab35a2b19300e3214bae228b8731de9a9a4f3f84",
    "whole_table": true
  },
  {
    "table": "atlas_procurement.purchase_order_lines",
    "primary_key": [
      "purchase_order_line_id"
    ],
    "row_count": 399,
    "sha256": "0646904a20137b94c07cbc59f546d52c7c68edf21e584d13ca2d18680d6c01ab",
    "whole_table": true
  },
  {
    "table": "atlas_procurement.purchase_order_revisions",
    "primary_key": [
      "purchase_order_revision_id"
    ],
    "row_count": 93,
    "sha256": "9b0fb852fc1ab78bd3800eb673cf8dd3d65764eb9ea0f2a497660f4e8c8d87e3",
    "whole_table": true
  },
  {
    "table": "atlas_procurement.purchase_orders",
    "primary_key": [
      "purchase_order_id"
    ],
    "row_count": 54,
    "sha256": "967cf11e9a110f6d709cc2e2bdc7049a033301fb0eb19272a425d4dcf298f0ad",
    "whole_table": true
  },
  {
    "table": "atlas_procurement.school_catering_allocation_families",
    "primary_key": [
      "family_id"
    ],
    "row_count": 331,
    "sha256": "b9e575e8ff32db06476f4a757b9eed388173032a7ed2c7cab65e89493949b911",
    "whole_table": true
  },
  {
    "table": "atlas_procurement.school_catering_allocation_family_contributions",
    "primary_key": [
      "family_contribution_id"
    ],
    "row_count": 671,
    "sha256": "96467c8532fb201d9adf5db66d6c2f98782e2dfeeb20c4ad7e13a16914cb4acd",
    "whole_table": true
  },
  {
    "table": "atlas_procurement.school_catering_allocation_family_revisions",
    "primary_key": [
      "family_revision_id"
    ],
    "row_count": 671,
    "sha256": "baa7feacf495ddb986c0a33e17b2102f1fa066afa6ad6ebee973aa640e3c89cc",
    "whole_table": true
  },
  {
    "table": "atlas_procurement.school_catering_allocation_supplier_splits",
    "primary_key": [
      "supplier_split_id"
    ],
    "row_count": 672,
    "sha256": "12439b552b2f762a8cdb2e1cd7ad8e2cac5b5b127cd3424aa1616a5b904ef450",
    "whole_table": true
  }
]$json$::jsonb $fixed$;

CREATE OR REPLACE FUNCTION pg_temp.cleanup_delete_guards() RETURNS jsonb LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path='' AS $fixed$ SELECT $json$[
  {
    "table": "atlas_dispatch.school_dispatch_release_line_sources",
    "trigger": "school_dispatch_release_sources_immutable",
    "mode": "O",
    "definition": "CREATE TRIGGER school_dispatch_release_sources_immutable BEFORE DELETE OR UPDATE ON atlas_dispatch.school_dispatch_release_line_sources FOR EACH ROW EXECUTE FUNCTION atlas_core.school_dispatch_release_immutable_guard()",
    "type": 27,
    "function_sha256": "80a4e0d566512f2ff1638f061ed9459cf54d12218dbee3715bf82cf49bc5b599"
  },
  {
    "table": "atlas_dispatch.school_dispatch_release_lines",
    "trigger": "school_dispatch_release_lines_immutable",
    "mode": "O",
    "definition": "CREATE TRIGGER school_dispatch_release_lines_immutable BEFORE DELETE OR UPDATE ON atlas_dispatch.school_dispatch_release_lines FOR EACH ROW EXECUTE FUNCTION atlas_core.school_dispatch_release_immutable_guard()",
    "type": 27,
    "function_sha256": "80a4e0d566512f2ff1638f061ed9459cf54d12218dbee3715bf82cf49bc5b599"
  },
  {
    "table": "atlas_dispatch.school_dispatch_releases",
    "trigger": "school_dispatch_releases_immutable",
    "mode": "O",
    "definition": "CREATE TRIGGER school_dispatch_releases_immutable BEFORE DELETE OR UPDATE ON atlas_dispatch.school_dispatch_releases FOR EACH ROW EXECUTE FUNCTION atlas_core.school_dispatch_release_immutable_guard()",
    "type": 27,
    "function_sha256": "80a4e0d566512f2ff1638f061ed9459cf54d12218dbee3715bf82cf49bc5b599"
  },
  {
    "table": "atlas_planning.attendance_approval_snapshot_lines",
    "trigger": "attendance_approval_snapshot_lines_immutable_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER attendance_approval_snapshot_lines_immutable_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.attendance_approval_snapshot_lines FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a3b_attendance_snapshot_guard()",
    "type": 31,
    "function_sha256": "246627099aa39ab3ef4edc7450d03ce6bd1fba3db2e880b3347f8c6f38e5c44b"
  },
  {
    "table": "atlas_planning.attendance_approval_snapshots",
    "trigger": "attendance_approval_snapshots_immutable_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER attendance_approval_snapshots_immutable_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.attendance_approval_snapshots FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a3b_attendance_snapshot_guard()",
    "type": 31,
    "function_sha256": "246627099aa39ab3ef4edc7450d03ce6bd1fba3db2e880b3347f8c6f38e5c44b"
  },
  {
    "table": "atlas_planning.attendance_batches",
    "trigger": "attendance_batches_lifecycle_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER attendance_batches_lifecycle_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.attendance_batches FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a3b_attendance_lifecycle_guard()",
    "type": 31,
    "function_sha256": "ba3d605e258bfaf2bcd6a494fdc79e8e28304ef4c9e202c75c5ff0bd34ab2085"
  },
  {
    "table": "atlas_planning.attendance_lines",
    "trigger": "attendance_lines_mutability_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER attendance_lines_mutability_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.attendance_lines FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a3b_attendance_line_guard()",
    "type": 31,
    "function_sha256": "8352982328a5cef27e78ab5cab024a2889c2fc2b7e0a4423ece2276f8a872e42"
  },
  {
    "table": "atlas_planning.confirmed_need_approval_snapshots",
    "trigger": "confirmed_need_approval_snapshots_rmvp07_immutable",
    "mode": "O",
    "definition": "CREATE TRIGGER confirmed_need_approval_snapshots_rmvp07_immutable BEFORE DELETE OR UPDATE ON atlas_planning.confirmed_need_approval_snapshots FOR EACH ROW EXECUTE FUNCTION atlas_planning.rmvp_07_immutable_approval_release_evidence()",
    "type": 27,
    "function_sha256": "cb66a62786db34d6b33c19419763c46f230d63db39085a187507ee8e523816a2"
  },
  {
    "table": "atlas_planning.confirmed_need_line_decision_continuity",
    "trigger": "confirmed_need_line_decision_continuity_immutable",
    "mode": "O",
    "definition": "CREATE TRIGGER confirmed_need_line_decision_continuity_immutable BEFORE DELETE OR UPDATE ON atlas_planning.confirmed_need_line_decision_continuity FOR EACH ROW EXECUTE FUNCTION atlas_planning.planning_contract_02b_continuity_immutable()",
    "type": 27,
    "function_sha256": "8d8e2242738ca04f86f8b485f4284ac0dea31b393afcf446c2483ae2016707f5"
  },
  {
    "table": "atlas_planning.confirmed_need_line_decisions",
    "trigger": "confirmed_need_line_decisions_h1b1_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER confirmed_need_line_decisions_h1b1_guard BEFORE DELETE OR UPDATE ON atlas_planning.confirmed_need_line_decisions FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_guard()",
    "type": 27,
    "function_sha256": "0d89349d0661b1cd1950179281abbb154a35b7ff41714a37b16d299a1e16d9b0"
  },
  {
    "table": "atlas_planning.confirmed_need_line_revision_contributions",
    "trigger": "confirmed_need_line_revision_contributions_h0b1b_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER confirmed_need_line_revision_contributions_h0b1b_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.confirmed_need_line_revision_contributions FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0b1b_confirmed_need_guard()",
    "type": 31,
    "function_sha256": "e6b9e76edc01f9080e610829e056b34d4c493d072e36ef62980ce7d11e2cf0f6"
  },
  {
    "table": "atlas_planning.confirmed_need_releases",
    "trigger": "confirmed_need_releases_rmvp07_immutable",
    "mode": "O",
    "definition": "CREATE TRIGGER confirmed_need_releases_rmvp07_immutable BEFORE DELETE OR UPDATE ON atlas_planning.confirmed_need_releases FOR EACH ROW EXECUTE FUNCTION atlas_planning.rmvp_07_immutable_approval_release_evidence()",
    "type": 27,
    "function_sha256": "cb66a62786db34d6b33c19419763c46f230d63db39085a187507ee8e523816a2"
  },
  {
    "table": "atlas_planning.confirmed_need_snapshot_lines",
    "trigger": "confirmed_need_snapshot_lines_rmvp07_immutable",
    "mode": "O",
    "definition": "CREATE TRIGGER confirmed_need_snapshot_lines_rmvp07_immutable BEFORE DELETE OR UPDATE ON atlas_planning.confirmed_need_snapshot_lines FOR EACH ROW EXECUTE FUNCTION atlas_planning.rmvp_07_immutable_approval_release_evidence()",
    "type": 27,
    "function_sha256": "cb66a62786db34d6b33c19419763c46f230d63db39085a187507ee8e523816a2"
  },
  {
    "table": "atlas_planning.confirmed_need_validation_attempts",
    "trigger": "confirmed_need_validation_attempts_immutable",
    "mode": "O",
    "definition": "CREATE TRIGGER confirmed_need_validation_attempts_immutable BEFORE DELETE OR UPDATE ON atlas_planning.confirmed_need_validation_attempts FOR EACH ROW EXECUTE FUNCTION atlas_planning.rmvp_06_immutable_validation_evidence()",
    "type": 27,
    "function_sha256": "065a6bec07410487f5bff391c8d637b526c5f352eabb8a2e871f9ab04d2cffd8"
  },
  {
    "table": "atlas_planning.confirmed_need_validation_issues",
    "trigger": "confirmed_need_validation_issues_immutable",
    "mode": "O",
    "definition": "CREATE TRIGGER confirmed_need_validation_issues_immutable BEFORE DELETE OR UPDATE ON atlas_planning.confirmed_need_validation_issues FOR EACH ROW EXECUTE FUNCTION atlas_planning.rmvp_06_immutable_validation_evidence()",
    "type": 27,
    "function_sha256": "065a6bec07410487f5bff391c8d637b526c5f352eabb8a2e871f9ab04d2cffd8"
  },
  {
    "table": "atlas_planning.confirmed_need_validation_lines",
    "trigger": "confirmed_need_validation_lines_immutable",
    "mode": "O",
    "definition": "CREATE TRIGGER confirmed_need_validation_lines_immutable BEFORE DELETE OR UPDATE ON atlas_planning.confirmed_need_validation_lines FOR EACH ROW EXECUTE FUNCTION atlas_planning.rmvp_06_immutable_validation_evidence()",
    "type": 27,
    "function_sha256": "065a6bec07410487f5bff391c8d637b526c5f352eabb8a2e871f9ab04d2cffd8"
  },
  {
    "table": "atlas_planning.need_generation_input_snapshots",
    "trigger": "need_generation_input_snapshots_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER need_generation_input_snapshots_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.need_generation_input_snapshots FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_immutable_evidence_guard()",
    "type": 31,
    "function_sha256": "f70a25f835f22f9d96a035e11e604284ba0f72bf4dc74d83b8a0e1aee7a6b26e"
  },
  {
    "table": "atlas_planning.need_generation_issues",
    "trigger": "need_generation_issues_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER need_generation_issues_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.need_generation_issues FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_immutable_evidence_guard()",
    "type": 31,
    "function_sha256": "f70a25f835f22f9d96a035e11e604284ba0f72bf4dc74d83b8a0e1aee7a6b26e"
  },
  {
    "table": "atlas_planning.need_generation_recipe_line_uses",
    "trigger": "need_generation_recipe_line_uses_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER need_generation_recipe_line_uses_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.need_generation_recipe_line_uses FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_immutable_evidence_guard()",
    "type": 31,
    "function_sha256": "f70a25f835f22f9d96a035e11e604284ba0f72bf4dc74d83b8a0e1aee7a6b26e"
  },
  {
    "table": "atlas_planning.need_generation_recipe_selections",
    "trigger": "need_generation_recipe_selections_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER need_generation_recipe_selections_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.need_generation_recipe_selections FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_immutable_evidence_guard()",
    "type": 31,
    "function_sha256": "f70a25f835f22f9d96a035e11e604284ba0f72bf4dc74d83b8a0e1aee7a6b26e"
  },
  {
    "table": "atlas_planning.need_generation_release_snapshot_issues",
    "trigger": "need_generation_release_snapshot_issues_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER need_generation_release_snapshot_issues_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.need_generation_release_snapshot_issues FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_immutable_evidence_guard()",
    "type": 31,
    "function_sha256": "f70a25f835f22f9d96a035e11e604284ba0f72bf4dc74d83b8a0e1aee7a6b26e"
  },
  {
    "table": "atlas_planning.need_generation_release_snapshot_lines",
    "trigger": "need_generation_release_snapshot_lines_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER need_generation_release_snapshot_lines_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.need_generation_release_snapshot_lines FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_immutable_evidence_guard()",
    "type": 31,
    "function_sha256": "f70a25f835f22f9d96a035e11e604284ba0f72bf4dc74d83b8a0e1aee7a6b26e"
  },
  {
    "table": "atlas_planning.need_generation_release_snapshots",
    "trigger": "need_generation_release_snapshots_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER need_generation_release_snapshots_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.need_generation_release_snapshots FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_immutable_evidence_guard()",
    "type": 31,
    "function_sha256": "f70a25f835f22f9d96a035e11e604284ba0f72bf4dc74d83b8a0e1aee7a6b26e"
  },
  {
    "table": "atlas_planning.need_generation_runs",
    "trigger": "need_generation_runs_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER need_generation_runs_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.need_generation_runs FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_need_generation_run_guard()",
    "type": 31,
    "function_sha256": "70e70eb35b694890099e73b0cf33a6c1764729ba31e7af412cc37f041a1047fa"
  },
  {
    "table": "atlas_planning.pantry_need_approval_snapshot_lines",
    "trigger": "pantry_need_approval_snapshot_lines_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER pantry_need_approval_snapshot_lines_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.pantry_need_approval_snapshot_lines FOR EACH ROW EXECUTE FUNCTION atlas_planning.pantry_02_snapshot_guard()",
    "type": 31,
    "function_sha256": "1a09145fba51dc645a065b83b2f605d03180b8db817014ddddd1059faef74bac"
  },
  {
    "table": "atlas_planning.pantry_need_approval_snapshot_school_date_modes",
    "trigger": "pantry_need_snapshot_school_date_modes_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER pantry_need_snapshot_school_date_modes_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.pantry_need_approval_snapshot_school_date_modes FOR EACH ROW EXECUTE FUNCTION atlas_planning.direct_need_snapshot_mode_guard()",
    "type": 31,
    "function_sha256": "3efaaced097a5a98a708d746f67146996f24c50ba834419a0c55ff12ba8b9189"
  },
  {
    "table": "atlas_planning.pantry_need_approval_snapshots",
    "trigger": "pantry_need_approval_snapshots_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER pantry_need_approval_snapshots_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.pantry_need_approval_snapshots FOR EACH ROW EXECUTE FUNCTION atlas_planning.pantry_02_snapshot_guard()",
    "type": 31,
    "function_sha256": "1a09145fba51dc645a065b83b2f605d03180b8db817014ddddd1059faef74bac"
  },
  {
    "table": "atlas_planning.pantry_need_batches",
    "trigger": "pantry_need_batches_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER pantry_need_batches_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.pantry_need_batches FOR EACH ROW EXECUTE FUNCTION atlas_planning.pantry_02_batch_guard()",
    "type": 31,
    "function_sha256": "1b736c51fdffcf9b157e048f6ef7a21314cc3e6258ee5fd7d2ce1b8bfb0f625e"
  },
  {
    "table": "atlas_planning.pantry_need_lines",
    "trigger": "pantry_need_lines_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER pantry_need_lines_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.pantry_need_lines FOR EACH ROW EXECUTE FUNCTION atlas_planning.pantry_02_line_guard()",
    "type": 31,
    "function_sha256": "d653c77d0578cd2ec8f17fec7474f76c27906b6400aa8e4fa5df384bad5a4237"
  },
  {
    "table": "atlas_planning.planning_input_evaluation_issues",
    "trigger": "planning_input_evaluation_issues_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER planning_input_evaluation_issues_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.planning_input_evaluation_issues FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a4b_planning_input_issue_guard()",
    "type": 31,
    "function_sha256": "798a0d27a7a74233d0ccbc8a0b7f77f076e4fdbb4eddbdb6db179436ab29f73c"
  },
  {
    "table": "atlas_planning.planning_input_evaluations",
    "trigger": "planning_input_evaluations_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER planning_input_evaluations_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.planning_input_evaluations FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a4b_planning_input_evaluation_guard()",
    "type": 31,
    "function_sha256": "4de77f42991bbdda7f5c84414fa884d0a5783415253d5ab3f0b8b19ce3634d28"
  },
  {
    "table": "atlas_planning.planning_input_sets",
    "trigger": "planning_input_sets_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER planning_input_sets_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.planning_input_sets FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a4b_planning_input_set_guard()",
    "type": 31,
    "function_sha256": "6f81c56be9ac87c054a936c0084b1910103e57a5f470afc1830752c26cfe3ad8"
  },
  {
    "table": "atlas_planning.theoretical_need_lines",
    "trigger": "theoretical_need_lines_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER theoretical_need_lines_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.theoretical_need_lines FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_immutable_evidence_guard()",
    "type": 31,
    "function_sha256": "f70a25f835f22f9d96a035e11e604284ba0f72bf4dc74d83b8a0e1aee7a6b26e"
  },
  {
    "table": "atlas_planning.weekly_menu_approval_snapshot_lines",
    "trigger": "weekly_menu_approval_snapshot_lines_immutable_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER weekly_menu_approval_snapshot_lines_immutable_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.weekly_menu_approval_snapshot_lines FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a3a_weekly_menu_snapshot_guard()",
    "type": 31,
    "function_sha256": "20a563f2cb68fe255ef83c0d14b7bb384755801b0fe0640a2985589ddd7ef1ef"
  },
  {
    "table": "atlas_planning.weekly_menu_approval_snapshots",
    "trigger": "weekly_menu_approval_snapshots_immutable_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER weekly_menu_approval_snapshots_immutable_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.weekly_menu_approval_snapshots FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a3a_weekly_menu_snapshot_guard()",
    "type": 31,
    "function_sha256": "20a563f2cb68fe255ef83c0d14b7bb384755801b0fe0640a2985589ddd7ef1ef"
  },
  {
    "table": "atlas_planning.weekly_menu_lines",
    "trigger": "weekly_menu_lines_mutability_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER weekly_menu_lines_mutability_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.weekly_menu_lines FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a3a_weekly_menu_line_guard()",
    "type": 31,
    "function_sha256": "dc9f22477ba6403e0e4db08854eca05fab61cc4811c3bb4ee2de30b7cf13841d"
  },
  {
    "table": "atlas_planning.weekly_menus",
    "trigger": "weekly_menus_lifecycle_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER weekly_menus_lifecycle_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_planning.weekly_menus FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a3a_weekly_menu_lifecycle_guard()",
    "type": 31,
    "function_sha256": "c708356a95f5b23cee96818a6ed98be46df314a90e9f4f6cb9e9688068cb156a"
  },
  {
    "table": "atlas_procurement.school_catering_allocation_family_contributions",
    "trigger": "school_catering_family_contributions_immutable",
    "mode": "O",
    "definition": "CREATE TRIGGER school_catering_family_contributions_immutable BEFORE DELETE OR UPDATE ON atlas_procurement.school_catering_allocation_family_contributions FOR EACH ROW EXECUTE FUNCTION atlas_core.school_catering_immutable_revision_guard()",
    "type": 27,
    "function_sha256": "4bae35b7f9794c6eee84c36578944a21bcef6808f4679adac285c19a4a9b4c65"
  },
  {
    "table": "atlas_procurement.school_catering_allocation_family_revisions",
    "trigger": "school_catering_family_revisions_immutable",
    "mode": "O",
    "definition": "CREATE TRIGGER school_catering_family_revisions_immutable BEFORE DELETE OR UPDATE ON atlas_procurement.school_catering_allocation_family_revisions FOR EACH ROW EXECUTE FUNCTION atlas_core.school_catering_immutable_revision_guard()",
    "type": 27,
    "function_sha256": "4bae35b7f9794c6eee84c36578944a21bcef6808f4679adac285c19a4a9b4c65"
  },
  {
    "table": "atlas_procurement.school_catering_allocation_supplier_splits",
    "trigger": "school_catering_supplier_splits_immutable",
    "mode": "O",
    "definition": "CREATE TRIGGER school_catering_supplier_splits_immutable BEFORE DELETE OR UPDATE ON atlas_procurement.school_catering_allocation_supplier_splits FOR EACH ROW EXECUTE FUNCTION atlas_core.school_catering_immutable_revision_guard()",
    "type": 27,
    "function_sha256": "4bae35b7f9794c6eee84c36578944a21bcef6808f4679adac285c19a4a9b4c65"
  },
  {
    "table": "atlas_admin.recipe_composition_adjustment_revisions",
    "trigger": "recipe_composition_adjustment_revisions_immutable",
    "mode": "O",
    "definition": "CREATE TRIGGER recipe_composition_adjustment_revisions_immutable BEFORE DELETE OR UPDATE ON atlas_admin.recipe_composition_adjustment_revisions FOR EACH ROW EXECUTE FUNCTION atlas_core.rmvp_02b_guard_adjustment_history()",
    "type": 27,
    "function_sha256": "b286154d950ff68a662ea6c72dcd013f9dba65a64da197c51588ea3cdde3e55b"
  },
  {
    "table": "atlas_admin.recipe_composition_adjustments",
    "trigger": "recipe_composition_adjustments_immutable_identity",
    "mode": "O",
    "definition": "CREATE TRIGGER recipe_composition_adjustments_immutable_identity BEFORE DELETE OR UPDATE ON atlas_admin.recipe_composition_adjustments FOR EACH ROW EXECUTE FUNCTION atlas_core.rmvp_02b_guard_adjustment_history()",
    "type": 27,
    "function_sha256": "b286154d950ff68a662ea6c72dcd013f9dba65a64da197c51588ea3cdde3e55b"
  },
  {
    "table": "atlas_admin.recipe_line_revisions",
    "trigger": "recipe_line_revisions_immutable_lineage_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER recipe_line_revisions_immutable_lineage_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_admin.recipe_line_revisions FOR EACH ROW EXECUTE FUNCTION atlas_admin.pa_06e_h0a2_recipe_line_revision_guard()",
    "type": 31,
    "function_sha256": "f5664fcc17b159142785d0d545def46b9ade104c3cb97b22f58bffc3ac9a168a"
  },
  {
    "table": "atlas_admin.recipe_versions",
    "trigger": "recipe_versions_lifecycle_guard",
    "mode": "O",
    "definition": "CREATE TRIGGER recipe_versions_lifecycle_guard BEFORE INSERT OR DELETE OR UPDATE ON atlas_admin.recipe_versions FOR EACH ROW EXECUTE FUNCTION atlas_admin.pa_06e_h0a2_recipe_version_lifecycle_guard()",
    "type": 31,
    "function_sha256": "b8996555befbeb2458388150d170502796937c4014a47148de4721a003d2971a"
  },
  {
    "table": "atlas_planning.need_generation_runs",
    "trigger": "need_generation_runs_integrity",
    "mode": "O",
    "definition": "CREATE CONSTRAINT TRIGGER need_generation_runs_integrity AFTER INSERT OR DELETE OR UPDATE ON atlas_planning.need_generation_runs DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()",
    "type": 29,
    "function_sha256": "1bbd0739e8af4d017da4bf6373a79c8bf5b3cbe3052f7fb961a2569f851a8f8d"
  },
  {
    "table": "atlas_planning.need_generation_input_snapshots",
    "trigger": "need_generation_input_snapshots_integrity",
    "mode": "O",
    "definition": "CREATE CONSTRAINT TRIGGER need_generation_input_snapshots_integrity AFTER INSERT OR DELETE OR UPDATE ON atlas_planning.need_generation_input_snapshots DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()",
    "type": 29,
    "function_sha256": "1bbd0739e8af4d017da4bf6373a79c8bf5b3cbe3052f7fb961a2569f851a8f8d"
  },
  {
    "table": "atlas_planning.need_generation_recipe_selections",
    "trigger": "need_generation_recipe_selections_integrity",
    "mode": "O",
    "definition": "CREATE CONSTRAINT TRIGGER need_generation_recipe_selections_integrity AFTER INSERT OR DELETE OR UPDATE ON atlas_planning.need_generation_recipe_selections DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()",
    "type": 29,
    "function_sha256": "1bbd0739e8af4d017da4bf6373a79c8bf5b3cbe3052f7fb961a2569f851a8f8d"
  },
  {
    "table": "atlas_planning.need_generation_recipe_line_uses",
    "trigger": "need_generation_recipe_line_uses_integrity",
    "mode": "O",
    "definition": "CREATE CONSTRAINT TRIGGER need_generation_recipe_line_uses_integrity AFTER INSERT OR DELETE OR UPDATE ON atlas_planning.need_generation_recipe_line_uses DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()",
    "type": 29,
    "function_sha256": "1bbd0739e8af4d017da4bf6373a79c8bf5b3cbe3052f7fb961a2569f851a8f8d"
  },
  {
    "table": "atlas_planning.theoretical_need_lines",
    "trigger": "theoretical_need_lines_integrity",
    "mode": "O",
    "definition": "CREATE CONSTRAINT TRIGGER theoretical_need_lines_integrity AFTER INSERT OR DELETE OR UPDATE ON atlas_planning.theoretical_need_lines DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()",
    "type": 29,
    "function_sha256": "1bbd0739e8af4d017da4bf6373a79c8bf5b3cbe3052f7fb961a2569f851a8f8d"
  },
  {
    "table": "atlas_planning.need_generation_issues",
    "trigger": "need_generation_issues_integrity",
    "mode": "O",
    "definition": "CREATE CONSTRAINT TRIGGER need_generation_issues_integrity AFTER INSERT OR DELETE OR UPDATE ON atlas_planning.need_generation_issues DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()",
    "type": 29,
    "function_sha256": "1bbd0739e8af4d017da4bf6373a79c8bf5b3cbe3052f7fb961a2569f851a8f8d"
  },
  {
    "table": "atlas_planning.need_generation_release_snapshots",
    "trigger": "need_generation_release_snapshots_integrity",
    "mode": "O",
    "definition": "CREATE CONSTRAINT TRIGGER need_generation_release_snapshots_integrity AFTER INSERT OR DELETE OR UPDATE ON atlas_planning.need_generation_release_snapshots DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()",
    "type": 29,
    "function_sha256": "1bbd0739e8af4d017da4bf6373a79c8bf5b3cbe3052f7fb961a2569f851a8f8d"
  },
  {
    "table": "atlas_planning.need_generation_release_snapshot_lines",
    "trigger": "need_generation_release_snapshot_lines_integrity",
    "mode": "O",
    "definition": "CREATE CONSTRAINT TRIGGER need_generation_release_snapshot_lines_integrity AFTER INSERT OR DELETE OR UPDATE ON atlas_planning.need_generation_release_snapshot_lines DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()",
    "type": 29,
    "function_sha256": "1bbd0739e8af4d017da4bf6373a79c8bf5b3cbe3052f7fb961a2569f851a8f8d"
  },
  {
    "table": "atlas_planning.need_generation_release_snapshot_issues",
    "trigger": "need_generation_release_snapshot_issues_integrity",
    "mode": "O",
    "definition": "CREATE CONSTRAINT TRIGGER need_generation_release_snapshot_issues_integrity AFTER INSERT OR DELETE OR UPDATE ON atlas_planning.need_generation_release_snapshot_issues DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()",
    "type": 29,
    "function_sha256": "1bbd0739e8af4d017da4bf6373a79c8bf5b3cbe3052f7fb961a2569f851a8f8d"
  }
]$json$::jsonb $fixed$;

CREATE OR REPLACE FUNCTION pg_temp.cleanup_operational_manifest() RETURNS jsonb LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path='' AS $fixed$ SELECT $json$[
  {
    "table_name": "atlas_dispatch.delivery_confirmation_lines",
    "row_count": 0
  },
  {
    "table_name": "atlas_dispatch.delivery_confirmations",
    "row_count": 0
  },
  {
    "table_name": "atlas_dispatch.dispatch_load_line_applications",
    "row_count": 0
  },
  {
    "table_name": "atlas_dispatch.dispatch_load_lines",
    "row_count": 0
  },
  {
    "table_name": "atlas_dispatch.dispatch_loads",
    "row_count": 0
  },
  {
    "table_name": "atlas_dispatch.dispatch_plan_requirements",
    "row_count": 0
  },
  {
    "table_name": "atlas_dispatch.dispatch_plans",
    "row_count": 0
  },
  {
    "table_name": "atlas_dispatch.dispatch_stops",
    "row_count": 0
  },
  {
    "table_name": "atlas_dispatch.dispatch_trips",
    "row_count": 0
  },
  {
    "table_name": "atlas_dispatch.school_dispatch_release_line_sources",
    "row_count": 205
  },
  {
    "table_name": "atlas_dispatch.school_dispatch_release_lines",
    "row_count": 205
  },
  {
    "table_name": "atlas_dispatch.school_dispatch_releases",
    "row_count": 22
  },
  {
    "table_name": "atlas_evidence.evidence_applications",
    "row_count": 0
  },
  {
    "table_name": "atlas_evidence.supplier_receiving_evidence",
    "row_count": 0
  },
  {
    "table_name": "atlas_planning.attendance_approval_snapshot_lines",
    "row_count": 703
  },
  {
    "table_name": "atlas_planning.attendance_approval_snapshots",
    "row_count": 13
  },
  {
    "table_name": "atlas_planning.attendance_batches",
    "row_count": 8
  },
  {
    "table_name": "atlas_planning.attendance_lines",
    "row_count": 586
  },
  {
    "table_name": "atlas_planning.confirmed_need_approval_snapshots",
    "row_count": 13
  },
  {
    "table_name": "atlas_planning.confirmed_need_batches",
    "row_count": 16
  },
  {
    "table_name": "atlas_planning.confirmed_need_line_decision_continuity",
    "row_count": 1
  },
  {
    "table_name": "atlas_planning.confirmed_need_line_decisions",
    "row_count": 1108
  },
  {
    "table_name": "atlas_planning.confirmed_need_line_revision_contributions",
    "row_count": 1845
  },
  {
    "table_name": "atlas_planning.confirmed_need_line_revisions",
    "row_count": 1572
  },
  {
    "table_name": "atlas_planning.confirmed_need_lines",
    "row_count": 1311
  },
  {
    "table_name": "atlas_planning.confirmed_need_releases",
    "row_count": 13
  },
  {
    "table_name": "atlas_planning.confirmed_need_snapshot_lines",
    "row_count": 334
  },
  {
    "table_name": "atlas_planning.confirmed_need_validation_attempts",
    "row_count": 13
  },
  {
    "table_name": "atlas_planning.confirmed_need_validation_issues",
    "row_count": 0
  },
  {
    "table_name": "atlas_planning.confirmed_need_validation_lines",
    "row_count": 334
  },
  {
    "table_name": "atlas_planning.dispatch_requirement_line_revisions",
    "row_count": 0
  },
  {
    "table_name": "atlas_planning.dispatch_requirement_lines",
    "row_count": 0
  },
  {
    "table_name": "atlas_planning.dispatch_requirement_revisions",
    "row_count": 0
  },
  {
    "table_name": "atlas_planning.dispatch_requirements",
    "row_count": 0
  },
  {
    "table_name": "atlas_planning.need_generation_input_snapshots",
    "row_count": 20
  },
  {
    "table_name": "atlas_planning.need_generation_issues",
    "row_count": 986
  },
  {
    "table_name": "atlas_planning.need_generation_recipe_line_uses",
    "row_count": 2810
  },
  {
    "table_name": "atlas_planning.need_generation_recipe_selections",
    "row_count": 985
  },
  {
    "table_name": "atlas_planning.need_generation_release_snapshot_issues",
    "row_count": 986
  },
  {
    "table_name": "atlas_planning.need_generation_release_snapshot_lines",
    "row_count": 2818
  },
  {
    "table_name": "atlas_planning.need_generation_release_snapshots",
    "row_count": 20
  },
  {
    "table_name": "atlas_planning.need_generation_runs",
    "row_count": 20
  },
  {
    "table_name": "atlas_planning.pantry_need_approval_snapshot_lines",
    "row_count": 17
  },
  {
    "table_name": "atlas_planning.pantry_need_approval_snapshot_school_date_modes",
    "row_count": 16
  },
  {
    "table_name": "atlas_planning.pantry_need_approval_snapshots",
    "row_count": 12
  },
  {
    "table_name": "atlas_planning.pantry_need_batches",
    "row_count": 7
  },
  {
    "table_name": "atlas_planning.pantry_need_lines",
    "row_count": 5
  },
  {
    "table_name": "atlas_planning.pantry_need_school_date_modes",
    "row_count": 4
  },
  {
    "table_name": "atlas_planning.planning_input_evaluation_issues",
    "row_count": 76
  },
  {
    "table_name": "atlas_planning.planning_input_evaluations",
    "row_count": 20
  },
  {
    "table_name": "atlas_planning.planning_input_sets",
    "row_count": 16
  },
  {
    "table_name": "atlas_planning.purchase_demand_references",
    "row_count": 333
  },
  {
    "table_name": "atlas_planning.purchase_handoff_batches",
    "row_count": 10
  },
  {
    "table_name": "atlas_planning.purchase_handoff_line_revisions",
    "row_count": 333
  },
  {
    "table_name": "atlas_planning.purchase_handoff_lines",
    "row_count": 331
  },
  {
    "table_name": "atlas_planning.purchase_handoff_revisions",
    "row_count": 12
  },
  {
    "table_name": "atlas_planning.theoretical_need_lines",
    "row_count": 2818
  },
  {
    "table_name": "atlas_planning.weekly_menu_approval_snapshot_lines",
    "row_count": 1480
  },
  {
    "table_name": "atlas_planning.weekly_menu_approval_snapshots",
    "row_count": 7
  },
  {
    "table_name": "atlas_planning.weekly_menu_lines",
    "row_count": 1480
  },
  {
    "table_name": "atlas_planning.weekly_menus",
    "row_count": 7
  },
  {
    "table_name": "atlas_planning.wholesale_order_line_revisions",
    "row_count": 0
  },
  {
    "table_name": "atlas_planning.wholesale_order_lines",
    "row_count": 0
  },
  {
    "table_name": "atlas_planning.wholesale_orders",
    "row_count": 0
  },
  {
    "table_name": "atlas_procurement.fulfilment_allocation_line_revisions",
    "row_count": 0
  },
  {
    "table_name": "atlas_procurement.fulfilment_allocation_lines",
    "row_count": 0
  },
  {
    "table_name": "atlas_procurement.fulfilment_allocation_revisions",
    "row_count": 0
  },
  {
    "table_name": "atlas_procurement.fulfilment_allocations",
    "row_count": 0
  },
  {
    "table_name": "atlas_procurement.purchase_order_line_revisions",
    "row_count": 580
  },
  {
    "table_name": "atlas_procurement.purchase_order_lines",
    "row_count": 399
  },
  {
    "table_name": "atlas_procurement.purchase_order_revisions",
    "row_count": 93
  },
  {
    "table_name": "atlas_procurement.purchase_orders",
    "row_count": 54
  },
  {
    "table_name": "atlas_procurement.school_catering_allocation_families",
    "row_count": 331
  },
  {
    "table_name": "atlas_procurement.school_catering_allocation_family_contributions",
    "row_count": 671
  },
  {
    "table_name": "atlas_procurement.school_catering_allocation_family_revisions",
    "row_count": 671
  },
  {
    "table_name": "atlas_procurement.school_catering_allocation_supplier_splits",
    "row_count": 672
  }
]$json$::jsonb $fixed$;

CREATE OR REPLACE FUNCTION pg_temp.cleanup_business_adjustment_ids() RETURNS jsonb LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path='' AS $fixed$ SELECT $json$[
  "158084e3-cb3d-4042-8efb-3e84fdff9c79",
  "1fb79972-d243-7991-f03d-b511c064dd22",
  "389b8d1c-1465-421f-934b-3784e107fcd6",
  "3ab1c846-005c-73b4-825f-48ae91be8059",
  "773537b2-ee38-4817-9b4a-f11e19485df9",
  "9a0fe255-7820-48e7-a4b5-b84fc25e6c37",
  "c6c55ab7-bf47-0b47-b9a8-6c96374f6bdf",
  "d4ca494a-039d-49af-8771-f6b2c75b1cce",
  "da309ce6-5022-b4cd-eb82-6609c06b71ef"
]$json$::jsonb $fixed$;
