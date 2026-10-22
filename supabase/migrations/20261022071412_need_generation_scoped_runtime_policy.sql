-- End the temporary role-wide rehearsal exemption. PostgREST hoists this
-- command's setting across its transaction, including deferred constraints.
begin;
alter function atlas_api.execute_need_generation(jsonb) set statement_timeout='0';
alter role authenticated set statement_timeout='8s';
notify pgrst, 'reload schema';
notify pgrst, 'reload config';
commit;
