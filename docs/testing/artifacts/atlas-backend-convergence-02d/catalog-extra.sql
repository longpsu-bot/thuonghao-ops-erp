-- Additional effective definitions absent from the seven-section 02C manifest.
begin transaction read only;
select jsonb_build_object(
 'schemas',(select jsonb_agg(jsonb_build_array(nspname,pg_get_userbyid(nspowner),nspacl::text) order by nspname) from pg_namespace where nspname like 'atlas_%'),
 'constraints',(select jsonb_agg(jsonb_build_array(n.nspname,c.relname,k.conname,k.contype,k.condeferrable,k.condeferred,k.convalidated,pg_get_constraintdef(k.oid,true)) order by n.nspname,c.relname,k.conname) from pg_constraint k join pg_class c on c.oid=k.conrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname like 'atlas_%'),
 'triggers',(select jsonb_agg(jsonb_build_array(n.nspname,c.relname,t.tgname,t.tgenabled,pg_get_triggerdef(t.oid,true)) order by n.nspname,c.relname,t.tgname) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname like 'atlas_%' and not t.tgisinternal),
 'columns',(select jsonb_agg(jsonb_build_array(n.nspname,c.relname,a.attnum,a.attname,format_type(a.atttypid,a.atttypmod),a.attnotnull,a.attidentity,a.attgenerated,pg_get_expr(d.adbin,d.adrelid)) order by n.nspname,c.relname,a.attnum) from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where n.nspname like 'atlas_%' and c.relkind in ('r','p','v') and a.attnum>0 and not a.attisdropped),
 'views',(select jsonb_agg(jsonb_build_array(n.nspname,c.relname,pg_get_viewdef(c.oid,true)) order by n.nspname,c.relname) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname like 'atlas_%' and c.relkind='v'),
 'role_memberships',(select jsonb_agg(jsonb_build_array(r.rolname,m.rolname,g.rolname,a.admin_option,a.inherit_option,a.set_option) order by r.rolname,m.rolname,g.rolname) from pg_auth_members a join pg_roles r on r.oid=a.roleid join pg_roles m on m.oid=a.member join pg_roles g on g.oid=a.grantor where r.rolname like 'atlas_%' or m.rolname like 'atlas_%'),
 'default_acls',(select jsonb_agg(jsonb_build_array(pg_get_userbyid(d.defaclrole),n.nspname,d.defaclobjtype,d.defaclacl::text) order by pg_get_userbyid(d.defaclrole),n.nspname,d.defaclobjtype) from pg_default_acl d join pg_namespace n on n.oid=d.defaclnamespace where n.nspname like 'atlas_%')
);
rollback;
