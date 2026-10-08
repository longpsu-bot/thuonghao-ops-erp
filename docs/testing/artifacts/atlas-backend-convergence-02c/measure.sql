-- Local disposable database ONLY. Every sample and fixture rolls back.
-- Include after an existing guarded fixture, inside its transaction.
create temp table bench_answer(response jsonb);
grant select,insert on bench_answer to authenticated;
create function pg_temp.sample(api_name text, request jsonb) returns jsonb
language plpgsql set search_path='' as $$
declare plan jsonb; answer jsonb; elapsed numeric; started timestamptz;
begin
  started:=clock_timestamp();
  set local role authenticated;
  execute format('explain (analyze,buffers,settings,format json)
    insert into pg_temp.bench_answer select atlas_api.%I(%L::jsonb)',api_name,request::text)
    into plan;
  reset role;
  -- Keep all constraints enabled, including complete deferred membership checks.
  set constraints all immediate;
  select response into strict answer from pg_temp.bench_answer;
  elapsed:=1000*extract(epoch from clock_timestamp()-started);
  if answer->>'success' is distinct from 'true' then
    raise exception 'BENCHMARK_API_FAILURE % %',api_name,answer;
  end if;
  raise exception using errcode='ZC002',message='rollback measured sample';
exception when sqlstate 'ZC002' then
  return jsonb_build_object('api',api_name,'elapsed_ms',elapsed,'plan',plan,
    'success',answer->'success','returned_rows',coalesce(
      jsonb_array_length(answer->'rows'),jsonb_array_length(answer->'purchase_orders'),
      jsonb_array_length(answer#>'{workbench,lines}')),
    'response_bytes',octet_length(answer::text),'response_md5',md5(answer::text));
end;
$$;
create function pg_temp.read_request(contract text,subject uuid,payload jsonb) returns jsonb
language sql volatile set search_path='' as $$
  select jsonb_build_object('contract_version',contract,'requested_by_auth_subject',subject,
    'correlation_id',gen_random_uuid(),'payload',payload);
$$;
-- Sample 0 is first measured call; it is NOT a disk-cold measurement.
-- Same backend/fixture, no cache eviction, no other test workload in parallel.
create function pg_temp.measure(api_name text,request jsonb,sample_index integer) returns void
language plpgsql set search_path='' as $$
declare result jsonb;
begin
  result:=pg_temp.sample(api_name,request);
  raise notice 'MEASUREMENT %',result||jsonb_build_object('sample',sample_index);
end;
$$;
