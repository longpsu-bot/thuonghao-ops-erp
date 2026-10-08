-- Read-only effective target-state manifest after chronological replay.
begin transaction read only;
select 'FUNCTIONS';
select E'identity\towner\tsecurity\tconfig\tacl\tanon_execute\tauthenticated_execute\tservice_role_execute\tatlas_execute_roles\tdefinition_md5';
select concat_ws(E'\t',n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')',
 pg_get_userbyid(p.proowner),case when p.prosecdef then 'DEFINER' else 'INVOKER' end,
 coalesce(p.proconfig::text,'<null>'),coalesce(p.proacl::text,'<null>'),
 has_function_privilege('anon',p.oid,'EXECUTE'),
 has_function_privilege('authenticated',p.oid,'EXECUTE'),
 has_function_privilege('service_role',p.oid,'EXECUTE'),
 (select string_agg(r.rolname,',' order by r.rolname) from pg_roles r
  where r.rolname like 'atlas_%' and has_function_privilege(r.oid,p.oid,'EXECUTE')),
 md5(pg_get_functiondef(p.oid)))
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname like 'atlas_%' order by 1;
select 'RELATIONS';
select E'identity\towner\tkind\trls\tforce_rls\toptions\tacl\teffective_role_privileges';
select concat_ws(E'\t',n.nspname||'.'||c.relname,pg_get_userbyid(c.relowner),c.relkind,
 c.relrowsecurity,c.relforcerowsecurity,coalesce(c.reloptions::text,'<null>'),coalesce(c.relacl::text,'<null>'),
 (select jsonb_object_agg(r.rolname,jsonb_build_object(
  'select',has_table_privilege(r.oid,c.oid,'SELECT'),
  'insert',has_table_privilege(r.oid,c.oid,'INSERT'),
  'update',has_table_privilege(r.oid,c.oid,'UPDATE'),
  'delete',has_table_privilege(r.oid,c.oid,'DELETE')))::text
  from pg_roles r where r.rolname like 'atlas_%' or r.rolname in ('anon','authenticated','service_role')))
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname like 'atlas_%' and c.relkind in ('r','v','m','p') order by 1;
select 'ROLES';
select E'role\tlogin\tinherit\tsuperuser\tcreaterole\tcreatedb\treplication\tbypassrls';
select concat_ws(E'\t',rolname,rolcanlogin,rolinherit,rolsuper,rolcreaterole,rolcreatedb,rolreplication,rolbypassrls)
from pg_roles where rolname like 'atlas_%' order by rolname;
select 'POLICIES';
select E'relation\tpolicy\tpermissive\tcommand\troles\tusing\twith_check';
select concat_ws(E'\t',n.nspname||'.'||c.relname,p.polname,p.polpermissive,p.polcmd,
 array(select coalesce((select rolname from pg_roles where oid=role_oid),'PUBLIC')
 from unnest(p.polroles) role_oid order by 1)::text,
 coalesce(pg_get_expr(p.polqual,p.polrelid),'<null>'),coalesce(pg_get_expr(p.polwithcheck,p.polrelid),'<null>'))
from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace
where n.nspname like 'atlas_%' order by 1;
select 'INDEXES';
select E'schema\ttable\tindex\tdefinition';
select concat_ws(E'\t',schemaname,tablename,indexname,indexdef)
from pg_indexes where schemaname like 'atlas_%' order by schemaname,tablename,indexname;
select 'SCHEMA_PRIVILEGES';
select E'schema\trole\tusage\tcreate';
select concat_ws(E'\t',n.nspname,r.rolname,
 has_schema_privilege(r.oid,n.oid,'USAGE'),has_schema_privilege(r.oid,n.oid,'CREATE'))
from pg_namespace n cross join pg_roles r where n.nspname like 'atlas_%'
and (r.rolname like 'atlas_%' or r.rolname in ('anon','authenticated','service_role')) order by 1;
select 'DEFAULT_ACL';
select count(*) from pg_default_acl d join pg_namespace n on n.oid=d.defaclnamespace
where n.nspname like 'atlas_%';
rollback;
