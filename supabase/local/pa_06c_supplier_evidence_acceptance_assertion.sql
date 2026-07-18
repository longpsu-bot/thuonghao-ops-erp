do $pa_06c_acceptance_assertion$
begin
  if (select count(*) from atlas_evidence.supplier_receiving_evidence
      where purchase_order_line_revision_id = 'b6c30000-0000-0000-0000-000000000703') <> 2 then
    raise exception 'PA-06C exact replay duplicated or omitted Supplier Evidence.';
  end if;

  if not exists (
    select 1 from atlas_evidence.supplier_receiving_evidence
    where command_id = 'b6c90000-0000-0000-0000-000000000101'
      and evidence_quantity = 4
      and evidence_reference = 'PA06C-EVIDENCE-001'
  ) or not exists (
    select 1 from atlas_evidence.supplier_receiving_evidence
    where command_id = 'b6c90000-0000-0000-0000-000000000104'
      and evidence_quantity = 6
      and evidence_reference = 'PA06C-EVIDENCE-002'
  ) then
    raise exception 'PA-06C Supplier Evidence command results are incomplete.';
  end if;

  if (select count(*) from atlas_evidence.evidence_applications
      where fulfilment_allocation_line_revision_id = 'b6c30000-0000-0000-0000-000000000603') <> 2
     or (select coalesce(sum(applied_quantity), 0) from atlas_evidence.evidence_applications
         where fulfilment_allocation_line_revision_id = 'b6c30000-0000-0000-0000-000000000603'
           and application_status = 'VALID') <> 10 then
    raise exception 'PA-06C exact replay or stale recovery produced an invalid application total.';
  end if;

  if not exists (
    select 1 from atlas_core.command_receipts
    where command_id = 'b6c90000-0000-0000-0000-000000000103'
      and outcome = 'FAILED_NON_RETRYABLE'
      and error_code = 'STALE_VERSION'
  ) or not exists (
    select 1 from atlas_core.command_receipts
    where command_id = 'b6c90000-0000-0000-0000-000000000105'
      and outcome = 'FAILED_NON_RETRYABLE'
      and error_code = 'STALE_VERSION'
  ) then
    raise exception 'PA-06C stale command receipts are missing.';
  end if;

  if (select count(*) from atlas_audit.domain_events
      where command_id in (
        'b6c90000-0000-0000-0000-000000000101',
        'b6c90000-0000-0000-0000-000000000102',
        'b6c90000-0000-0000-0000-000000000104',
        'b6c90000-0000-0000-0000-000000000106'
      )) <> 4
     or (select count(*) from atlas_audit.audit_events
         where command_id in (
           'b6c90000-0000-0000-0000-000000000101',
           'b6c90000-0000-0000-0000-000000000102',
           'b6c90000-0000-0000-0000-000000000104',
           'b6c90000-0000-0000-0000-000000000106'
         )) <> 4 then
    raise exception 'PA-06C command/event/audit counts are inconsistent.';
  end if;
end;
$pa_06c_acceptance_assertion$;
