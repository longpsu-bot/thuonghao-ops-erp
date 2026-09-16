-- Accept a truthful prior-reference adoption receipt as the initial drift baseline.
-- No historical business actions are fabricated; the private Staging package owns adoption.
set role atlas_owner;
do $adoption$
declare definition text;
 old_fragment constant text := $old$b.snapshot_contract_version='OPS-V1-MASTER-SNAPSHOT.v1' and b.import_status='COMPLETED'$old$;
 new_fragment constant text := $new$b.snapshot_contract_version in ('OPS-V1-MASTER-SNAPSHOT.v1','STAGING-REFERENCE-ADOPTION.v1') and b.import_status='COMPLETED'$new$;
begin
 select pg_get_functiondef('atlas_legacy.preview_master_data_snapshot(jsonb)'::regprocedure) into definition;
 if (length(definition)-length(replace(definition,old_fragment,'')))/length(old_fragment)<>1 then
   raise exception 'STAGING_ADOPTION_PREDECESSOR_DRIFT';
 end if;
 execute replace(definition,old_fragment,new_fragment);
end $adoption$;
reset role;
