begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select no_plan();

-- Exact expected outputs, not just pairwise agreement between duplicates.
select is(actual,expected,'D01 '||identity||': '||label)
from (values
  ('NULL',null::text,null::text),('empty','',''::text),('spaces','   ',null),
  ('ASCII','Atlas','Atlas'),('trim','  Atlas  ','Atlas'),
  ('Vietnamese NFC','Thượng Hảo','Thượng Hảo'),
  ('decomposed Vietnamese',U&'Ha\0309o','Hảo'),
  ('already normalized','Hảo','Hảo'),('blank after trim',' ',null),
  ('tabs retain current btrim contract',E'\t',E'\t')
) cases(label,input,raw_expected)
cross join lateral (select nullif(raw_expected,'') expected) expectation
cross join lateral (values
  ('03A',atlas_core.rmvp_03a_normalize_text(input)),
  ('03B',atlas_core.rmvp_03b_normalize_text(input)),
  ('Pantry',atlas_core.pantry_02_normalize_text(input))
) implementations(identity,actual);

select is(actual,expected,'D02 '||identity||': '||label)
from (values
  ('SQL NULL',null::jsonb),('JSON null','null'::jsonb),('object','{}'::jsonb),
  ('empty array','[]'::jsonb),('nested','{"a":{"b":[1,true,null]}}'::jsonb),
  ('array','[1,"x",false]'::jsonb),('number','72.123456'::jsonb),
  ('boolean','true'::jsonb),('Vietnamese UTF-8','"Thượng Hảo"'::jsonb),
  ('object order A','{"b":2,"a":1}'::jsonb),
  ('object order B','{"a":1,"b":2}'::jsonb)
) cases(label,input)
cross join lateral (select encode(extensions.digest(convert_to(
  coalesce(input,'null'::jsonb)::text,'UTF8'),'sha256'),'hex') expected) expectation
cross join lateral (values
  ('03A',atlas_core.rmvp_03a_sha256(input)),
  ('03B',atlas_core.rmvp_03b_sha256(input)),
  ('Pantry',atlas_core.pantry_02_sha256(input))
) implementations(identity,actual);
select is(atlas_core.rmvp_03a_sha256(null),
  '74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',
  'SQL NULL hashes UTF-8 JSON null in lowercase hex');

select is(actual,expected,'D03 '||identity||': '||label)
from (values
  ('NULL',null::text,null::date),('blank','',null),('spaces','   ',null),
  ('normal','2026-10-07','2026-10-07'::date),
  ('leap','2024-02-29','2024-02-29'::date),('non-leap','2023-02-29',null),
  ('month 13','2026-13-01',null),('month zero','2026-00-01',null),
  ('day 32','2026-01-32',null),('short month','2026-1-01',null),
  ('reversed','07-10-2026',null),('timestamp','2026-10-07T00:00:00Z',null),
  ('text','arbitrary text',null),('surrounding spaces',' 2026-10-07 ',null)
) cases(label,input,expected)
cross join lateral (values
  ('readiness',atlas_core.rmvp_03b_safe_date(input)),
  ('generation',atlas_core.rmvp_04_safe_date(input))
) implementations(identity,actual);

select ok(not has_function_privilege(role_name,p.oid,'EXECUTE'),
  role_name||' cannot execute private '||p.proname)
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
cross join (values('authenticated'),('anon'),('service_role')) roles(role_name)
where n.nspname='atlas_core' and p.proname in (
  'rmvp_03a_normalize_text','rmvp_03b_normalize_text','pantry_02_normalize_text',
  'rmvp_03a_sha256','rmvp_03b_sha256','pantry_02_sha256',
  'rmvp_03b_safe_date','rmvp_04_safe_date');
select ok(not has_function_privilege('atlas_need_generation_runtime',
  'atlas_core.rmvp_03b_safe_date(text)','EXECUTE'),'D03 generation cannot call readiness parser');
select ok(not has_function_privilege('atlas_planning_command_runtime',
  'atlas_core.rmvp_04_safe_date(text)','EXECUTE'),'D03 Planning cannot call generation parser');

-- Execute wrappers under their real invoker roles, including the asymmetric ACL.
grant atlas_planning_command_runtime,atlas_read_runtime to postgres with set true;
set local role atlas_planning_command_runtime;
select is(atlas_core.rmvp_03b_normalize_text(' Hảo '),'Hảo','Planning executes 03B normalizer');
select is(atlas_core.rmvp_03b_sha256(null),atlas_core.rmvp_03a_sha256(null),
  'Planning executes 03B hash and canonical hash');
select is(atlas_core.pantry_02_normalize_text(' Hảo '),'Hảo','Planning executes Pantry normalizer');
select is(atlas_core.pantry_02_sha256(null),atlas_core.rmvp_03a_sha256(null),'Planning executes Pantry hash');
reset role;
set local role atlas_read_runtime;
select is(atlas_core.pantry_02_normalize_text(' Hảo '),'Hảo','read executes Pantry normalizer');
select is(atlas_core.pantry_02_sha256(null),atlas_core.rmvp_03a_sha256(null),'read executes Pantry hash');
reset role;
select * from finish();
rollback;
