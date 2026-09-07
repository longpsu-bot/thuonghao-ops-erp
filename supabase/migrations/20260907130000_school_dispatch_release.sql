-- School/date/location Phiếu xuất kho preview and immutable explicit release.

reset role;
grant atlas_owner,atlas_read_runtime,atlas_dispatch_command_runtime,
  atlas_procurement_command_runtime to postgres with set true;
set role atlas_owner;

create table atlas_dispatch.school_dispatch_releases (
  school_dispatch_release_id uuid primary key default gen_random_uuid(),
  service_date date not null,
  school_id uuid not null references atlas_admin.schools(school_id) on delete restrict,
  delivery_location_id uuid not null
    references atlas_admin.delivery_locations(delivery_location_id) on delete restrict,
  release_status text not null,
  document_number text not null unique,
  source_fingerprint text not null,
  predecessor_release_id uuid
    references atlas_dispatch.school_dispatch_releases(school_dispatch_release_id)
    on delete restrict,
  school_name_snapshot text not null,
  delivery_location_name_snapshot text not null,
  delivery_address_snapshot text not null,
  note text,
  version bigint not null default 1,
  released_by_actor_id uuid not null
    references atlas_core.actors(actor_id) on delete restrict,
  released_at timestamptz not null,
  command_id uuid not null unique,
  created_at timestamptz not null default transaction_timestamp(),
  constraint school_dispatch_releases_status_check
    check (release_status in ('RELEASED','SUPERSEDED')),
  constraint school_dispatch_releases_version_check check (version>0),
  constraint school_dispatch_releases_fingerprint_check
    check (char_length(source_fingerprint)=64),
  constraint school_dispatch_releases_predecessor_self_check
    check (predecessor_release_id is null
      or predecessor_release_id<>school_dispatch_release_id),
  constraint school_dispatch_releases_note_check
    check (note is null or (note=btrim(note) and char_length(note) between 1 and 500))
);

create unique index school_dispatch_releases_current_scope_key
  on atlas_dispatch.school_dispatch_releases(
    service_date,school_id,delivery_location_id
  ) where release_status='RELEASED';
create unique index school_dispatch_releases_predecessor_key
  on atlas_dispatch.school_dispatch_releases(predecessor_release_id)
  where predecessor_release_id is not null;
create index school_dispatch_releases_scope_history_idx
  on atlas_dispatch.school_dispatch_releases(
    service_date,school_id,delivery_location_id,released_at desc
  );

create table atlas_dispatch.school_dispatch_release_lines (
  school_dispatch_release_line_id uuid primary key default gen_random_uuid(),
  school_dispatch_release_id uuid not null
    references atlas_dispatch.school_dispatch_releases(school_dispatch_release_id)
    on delete restrict,
  ingredient_id uuid not null
    references atlas_admin.ingredients(ingredient_id) on delete restrict,
  unit_id uuid not null references atlas_admin.units(unit_id) on delete restrict,
  quantity numeric(20,6) not null,
  ingredient_name_snapshot text not null,
  unit_code_snapshot text not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint school_dispatch_release_lines_quantity_check check (quantity>0),
  constraint school_dispatch_release_lines_scope_key unique(
    school_dispatch_release_id,ingredient_id,unit_id)
);

create table atlas_dispatch.school_dispatch_release_line_sources (
  school_dispatch_release_line_source_id uuid primary key default gen_random_uuid(),
  school_dispatch_release_line_id uuid not null
    references atlas_dispatch.school_dispatch_release_lines(school_dispatch_release_line_id)
    on delete restrict,
  confirmed_need_line_revision_id uuid not null
    references atlas_planning.confirmed_need_line_revisions(
      confirmed_need_line_revision_id) on delete restrict,
  confirmed_need_line_decision_id uuid not null
    references atlas_planning.confirmed_need_line_decisions(
      confirmed_need_line_decision_id) on delete restrict,
  allocation_family_revision_id uuid not null
    references atlas_procurement.school_catering_allocation_family_revisions(
      family_revision_id) on delete restrict,
  allocation_family_contribution_id uuid not null
    references atlas_procurement.school_catering_allocation_family_contributions(
      family_contribution_id) on delete restrict,
  allocation_supplier_split_id uuid not null
    references atlas_procurement.school_catering_allocation_supplier_splits(
      supplier_split_id) on delete restrict,
  purchase_order_id uuid not null
    references atlas_procurement.purchase_orders(purchase_order_id) on delete restrict,
  purchase_order_revision_id uuid not null
    references atlas_procurement.purchase_order_revisions(
      purchase_order_revision_id) on delete restrict,
  purchase_order_line_revision_id uuid not null
    references atlas_procurement.purchase_order_line_revisions(
      purchase_order_line_revision_id) on delete restrict,
  covered_quantity numeric(20,6) not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint school_dispatch_release_line_sources_quantity_check
    check (covered_quantity>0),
  constraint school_dispatch_release_line_sources_exact_key unique(
    school_dispatch_release_line_id,allocation_family_contribution_id,
    allocation_supplier_split_id,purchase_order_line_revision_id)
);

alter table atlas_dispatch.school_dispatch_releases enable row level security;
alter table atlas_dispatch.school_dispatch_releases force row level security;
alter table atlas_dispatch.school_dispatch_release_lines enable row level security;
alter table atlas_dispatch.school_dispatch_release_lines force row level security;
alter table atlas_dispatch.school_dispatch_release_line_sources enable row level security;
alter table atlas_dispatch.school_dispatch_release_line_sources force row level security;

reset role;
insert into atlas_core.capabilities(
  capability_id,capability_code,capability_name,owning_domain,capability_status
) values
  ('36a79e51-8fa8-44df-a81f-2b3f11302027','dispatch.school_release.read',
   'Read School dispatch release preview and history','DISPATCH','ACTIVE'),
  ('eedc9ba5-5642-4b9f-bfb3-a02bcfc32028','dispatch.school_release.release',
   'Release immutable School dispatch documents','DISPATCH','ACTIVE');
set role atlas_owner;

grant select on atlas_dispatch.school_dispatch_releases,
  atlas_dispatch.school_dispatch_release_lines,
  atlas_dispatch.school_dispatch_release_line_sources
to atlas_read_runtime,atlas_dispatch_command_runtime;
grant insert on atlas_dispatch.school_dispatch_releases,
  atlas_dispatch.school_dispatch_release_lines,
  atlas_dispatch.school_dispatch_release_line_sources
to atlas_dispatch_command_runtime;
grant update(release_status) on atlas_dispatch.school_dispatch_releases
to atlas_dispatch_command_runtime;

create policy school_dispatch_releases_read on atlas_dispatch.school_dispatch_releases
  for select to atlas_read_runtime,atlas_dispatch_command_runtime using(true);
create policy school_dispatch_release_lines_read
  on atlas_dispatch.school_dispatch_release_lines
  for select to atlas_read_runtime,atlas_dispatch_command_runtime using(true);
create policy school_dispatch_release_sources_read
  on atlas_dispatch.school_dispatch_release_line_sources
  for select to atlas_read_runtime,atlas_dispatch_command_runtime using(true);
create policy school_dispatch_releases_insert on atlas_dispatch.school_dispatch_releases
  for insert to atlas_dispatch_command_runtime with check(true);
create policy school_dispatch_releases_update on atlas_dispatch.school_dispatch_releases
  for update to atlas_dispatch_command_runtime
  using(release_status='RELEASED') with check(release_status='SUPERSEDED');
create policy school_dispatch_release_lines_insert
  on atlas_dispatch.school_dispatch_release_lines
  for insert to atlas_dispatch_command_runtime with check(true);
create policy school_dispatch_release_sources_insert
  on atlas_dispatch.school_dispatch_release_line_sources
  for insert to atlas_dispatch_command_runtime with check(true);

create function atlas_core.school_dispatch_release_immutable_guard()
returns trigger
language plpgsql
set search_path=''
as $$
begin
  if tg_table_name='school_dispatch_releases' then
    if tg_op='UPDATE'
       and old.release_status='RELEASED' and new.release_status='SUPERSEDED'
       and to_jsonb(old)-'release_status'=to_jsonb(new)-'release_status' then
      return new;
    end if;
  end if;
  raise exception using errcode='23514',
    message='School dispatch release history is immutable.';
end;
$$;

create trigger school_dispatch_releases_immutable
  before update or delete on atlas_dispatch.school_dispatch_releases
  for each row execute function atlas_core.school_dispatch_release_immutable_guard();
create trigger school_dispatch_release_lines_immutable
  before update or delete on atlas_dispatch.school_dispatch_release_lines
  for each row execute function atlas_core.school_dispatch_release_immutable_guard();
create trigger school_dispatch_release_sources_immutable
  before update or delete on atlas_dispatch.school_dispatch_release_line_sources
  for each row execute function atlas_core.school_dispatch_release_immutable_guard();

revoke execute on function atlas_core.school_dispatch_release_immutable_guard()
from public,anon,authenticated,service_role;

grant create on schema atlas_core,atlas_api to atlas_read_runtime;
reset role;
set role atlas_read_runtime;

create function atlas_core.school_dispatch_release_preview(
  p_service_date date,p_school_id uuid,p_delivery_location_id uuid
) returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  with scope as (
    select school.school_id,school.school_name,location.delivery_location_id,
      location.location_name,location.address_text
    from atlas_admin.schools school
    join atlas_admin.delivery_locations location
      on location.delivery_location_id=p_delivery_location_id
     and location.customer_id=school.customer_id
    where school.school_id=p_school_id
  ), contributions as materialized (
    select contribution.family_contribution_id,
      contribution.contribution_quantity,revision.family_revision_id,
      revision.source_fingerprint,revision.family_quantity,
      family.ingredient_id,family.unit_id,confirmed_revision.school_id,
      handoff_line.confirmed_need_line_revision_id,
      confirmed_line.current_confirmed_need_line_decision_id
        confirmed_need_line_decision_id
    from atlas_procurement.school_catering_allocation_families family
    join atlas_procurement.school_catering_allocation_family_revisions revision
      on revision.family_id=family.family_id and revision.is_current
     and revision.source_kind='PURCHASE_HANDOFF'
    join atlas_procurement.school_catering_allocation_family_contributions contribution
      on contribution.family_revision_id=revision.family_revision_id
     and contribution.purchase_handoff_line_revision_id is not null
    join atlas_planning.purchase_handoff_line_revisions handoff_line
      on handoff_line.purchase_handoff_line_revision_id=
        contribution.purchase_handoff_line_revision_id
    join atlas_planning.purchase_handoff_revisions handoff_revision
      on handoff_revision.purchase_handoff_revision_id=
        handoff_line.purchase_handoff_revision_id
     and handoff_revision.is_current
     and handoff_revision.revision_status='RELEASED_TO_PROCUREMENT'
    join atlas_planning.purchase_handoff_batches handoff_batch
      on handoff_batch.purchase_handoff_batch_id=
        handoff_revision.purchase_handoff_batch_id
     and handoff_batch.handoff_status='RELEASED_TO_PROCUREMENT'
    join atlas_planning.purchase_demand_references demand
      on demand.purchase_handoff_line_revision_id=
        handoff_line.purchase_handoff_line_revision_id
     and demand.source_kind='NEED_GENERATION'
    join atlas_planning.confirmed_need_line_revisions confirmed_revision
      on confirmed_revision.confirmed_need_line_revision_id=
        handoff_line.confirmed_need_line_revision_id
    join atlas_planning.confirmed_need_lines confirmed_line
      on confirmed_line.confirmed_need_line_id=confirmed_revision.confirmed_need_line_id
    where family.service_date=p_service_date
      and family.delivery_location_id=p_delivery_location_id
      and confirmed_revision.service_date=p_service_date
      and confirmed_revision.delivery_location_id=p_delivery_location_id
      and confirmed_line.current_confirmed_need_line_decision_id is not null
      and revision.source_fingerprint=atlas_core.school_catering_family_projection(
        family.service_date,family.delivery_location_id,
        family.ingredient_id,family.unit_id)->>'source_fingerprint'
  ), contribution_ranges as materialized (
    select contribution.*,
      coalesce(sum(contribution.contribution_quantity) over(
        partition by contribution.family_revision_id
        order by contribution.family_contribution_id
        rows between unbounded preceding and 1 preceding),0)::numeric(20,6)
        contribution_start,
      sum(contribution.contribution_quantity) over(
        partition by contribution.family_revision_id
        order by contribution.family_contribution_id
        rows between unbounded preceding and current row)::numeric(20,6)
        contribution_end
    from contributions contribution
  ), split_ranges as materialized (
    select split.*,
      coalesce(sum(split.allocated_quantity) over(
        partition by split.family_revision_id
        order by split.supplier_id
        rows between unbounded preceding and 1 preceding),0)::numeric(20,6)
        split_start,
      sum(split.allocated_quantity) over(
        partition by split.family_revision_id
        order by split.supplier_id
        rows between unbounded preceding and current row)::numeric(20,6)
        split_end
    from atlas_procurement.school_catering_allocation_supplier_splits split
    where split.family_revision_id in (
      select distinct contribution.family_revision_id from contributions contribution
    )
  ), coverage as materialized (
    select contribution.*,split.supplier_split_id,split.supplier_id,
      (least(contribution.contribution_end,split.split_end)-
        greatest(contribution.contribution_start,split.split_start))::numeric(20,6)
        covered_quantity,
      purchase.purchase_order_id,purchase.purchase_order_revision_id,
      purchase.purchase_order_line_revision_id
    from contribution_ranges contribution
    join split_ranges split
      on split.family_revision_id=contribution.family_revision_id
    left join lateral (
      select po.purchase_order_id,por.purchase_order_revision_id,
        line.purchase_order_line_revision_id
      from atlas_procurement.purchase_orders po
      join atlas_procurement.purchase_order_revisions por
        on por.purchase_order_id=po.purchase_order_id and por.is_current
       and por.revision_status='RELEASED_TO_SUPPLIER'
      join atlas_procurement.purchase_order_line_revisions line
        on line.purchase_order_revision_id=por.purchase_order_revision_id
       and line.school_catering_allocation_supplier_split_id=
         split.supplier_split_id
      where po.purchase_order_kind='SCHOOL_CATERING'
        and po.purchase_order_status='RELEASED_TO_SUPPLIER'
        and po.school_catering_service_date=p_service_date
        and po.supplier_id=split.supplier_id
        and not atlas_core.school_catering_po_draft_is_stale(
          po.purchase_order_id,por.purchase_order_revision_id)
      order by po.created_at desc limit 1
    ) purchase on true
    where contribution.school_id=p_school_id
      and least(contribution.contribution_end,split.split_end)>
        greatest(contribution.contribution_start,split.split_start)
  ), line_keys as (
    select ingredient_id,unit_id,sum(contribution_quantity)::numeric(20,6) quantity
    from contribution_ranges where school_id=p_school_id
    group by ingredient_id,unit_id
  ), lines as (
    select key.ingredient_id,ingredient.ingredient_name,key.unit_id,unit.unit_code,
      key.quantity,
      coalesce((select jsonb_agg(jsonb_build_object(
        'confirmed_need_line_revision_id',source.confirmed_need_line_revision_id,
        'confirmed_need_line_decision_id',source.confirmed_need_line_decision_id,
        'allocation_family_revision_id',source.family_revision_id,
        'allocation_family_contribution_id',source.family_contribution_id,
        'allocation_supplier_split_id',source.supplier_split_id,
        'purchase_order_id',source.purchase_order_id,
        'purchase_order_revision_id',source.purchase_order_revision_id,
        'purchase_order_line_revision_id',source.purchase_order_line_revision_id,
        'covered_quantity',source.covered_quantity::text
      ) order by source.family_contribution_id,source.supplier_split_id)
      from coverage source
      where source.ingredient_id=key.ingredient_id and source.unit_id=key.unit_id),
      '[]'::jsonb) sources
    from line_keys key
    join atlas_admin.ingredients ingredient on ingredient.ingredient_id=key.ingredient_id
    join atlas_admin.units unit on unit.unit_id=key.unit_id
  ), facts as (
    select coalesce(string_agg(concat_ws('|',
      confirmed_need_line_revision_id,confirmed_need_line_decision_id,
      family_revision_id,family_contribution_id,supplier_split_id,
      covered_quantity,purchase_order_id,purchase_order_revision_id,
      purchase_order_line_revision_id),';' order by family_contribution_id,
      supplier_split_id),'') value from coverage
  ), state as (
    select exists(select 1 from contribution_ranges where school_id=p_school_id)
        has_need,
      exists(select 1 from coverage where purchase_order_id is null) missing_po,
      atlas_core.school_catering_procurement_date_current(p_service_date)
        procurement_current,
      exists(
        select 1 from atlas_procurement.purchase_orders po
        join atlas_procurement.purchase_order_revisions por
          on por.purchase_order_id=po.purchase_order_id and por.is_current
        where po.purchase_order_kind='SCHOOL_CATERING'
          and po.school_catering_service_date=p_service_date
          and po.purchase_order_status='RELEASED_TO_SUPPLIER'
          and atlas_core.school_catering_po_commitment_state(
            po.purchase_order_id,por.purchase_order_revision_id)=
            'CANCELLATION_REQUIRED'
      ) cancellation_required
  )
  select jsonb_build_object(
    'service_date',p_service_date,'school_id',p_school_id,
    'delivery_location_id',p_delivery_location_id,
    'school_name',(select school_name from scope),
    'delivery_location_name',(select location_name from scope),
    'delivery_address',(select address_text from scope),
    'source_fingerprint',encode(extensions.digest(
      convert_to((select value from facts),'UTF8'),'sha256'),'hex'),
    'ready',(select has_need and not missing_po and procurement_current
      and exists(select 1 from scope) from state),
    'lines',coalesce((select jsonb_agg(jsonb_build_object(
      'ingredient_id',ingredient_id,'ingredient_name',ingredient_name,
      'unit_id',unit_id,'unit_code',unit_code,'quantity',quantity::text,
      'sources',sources) order by ingredient_name,ingredient_id,unit_id) from lines),
      '[]'::jsonb),
    'blockers',(select
      (case when not exists(select 1 from scope)
        then jsonb_build_array('SCHOOL_SCOPE_INVALID') else '[]'::jsonb end)
      || (case when not has_need
        then jsonb_build_array('NO_CURRENT_NEED') else '[]'::jsonb end)
      || (case when cancellation_required
        then jsonb_build_array('CANCELLATION_REQUIRED') else '[]'::jsonb end)
      || (case when missing_po
        then jsonb_build_array('PO_COVERAGE_INCOMPLETE') else '[]'::jsonb end)
      || (case when not procurement_current and not cancellation_required
        then jsonb_build_array('PROCUREMENT_NOT_CURRENT') else '[]'::jsonb end)
      from state),
    'warnings','[]'::jsonb);
$$;

create function atlas_core.school_dispatch_release_json(p_release_id uuid)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select jsonb_build_object(
    'school_dispatch_release_id',release.school_dispatch_release_id,
    'service_date',release.service_date,'school_id',release.school_id,
    'delivery_location_id',release.delivery_location_id,
    'status',release.release_status,'document_number',release.document_number,
    'source_fingerprint',release.source_fingerprint,
    'predecessor_release_id',release.predecessor_release_id,
    'school_name',release.school_name_snapshot,
    'delivery_location_name',release.delivery_location_name_snapshot,
    'delivery_address',release.delivery_address_snapshot,
    'note',release.note,'version',release.version,
    'released_by_actor_id',release.released_by_actor_id,
    'released_at',release.released_at,'export_ready',true,
    'lines',coalesce((select jsonb_agg(jsonb_build_object(
      'school_dispatch_release_line_id',line.school_dispatch_release_line_id,
      'ingredient_id',line.ingredient_id,
      'ingredient_name',line.ingredient_name_snapshot,
      'unit_id',line.unit_id,'unit_code',line.unit_code_snapshot,
      'quantity',line.quantity::text,
      'sources',coalesce((select jsonb_agg(jsonb_build_object(
        'confirmed_need_line_revision_id',source.confirmed_need_line_revision_id,
        'confirmed_need_line_decision_id',source.confirmed_need_line_decision_id,
        'allocation_family_revision_id',source.allocation_family_revision_id,
        'allocation_family_contribution_id',source.allocation_family_contribution_id,
        'allocation_supplier_split_id',source.allocation_supplier_split_id,
        'purchase_order_id',source.purchase_order_id,
        'purchase_order_revision_id',source.purchase_order_revision_id,
        'purchase_order_line_revision_id',source.purchase_order_line_revision_id,
        'covered_quantity',source.covered_quantity::text
      ) order by source.school_dispatch_release_line_source_id)
      from atlas_dispatch.school_dispatch_release_line_sources source
      where source.school_dispatch_release_line_id=
        line.school_dispatch_release_line_id),'[]'::jsonb)
    ) order by line.ingredient_name_snapshot,line.school_dispatch_release_line_id)
    from atlas_dispatch.school_dispatch_release_lines line
    where line.school_dispatch_release_id=release.school_dispatch_release_id),
    '[]'::jsonb)
  )
  from atlas_dispatch.school_dispatch_releases release
  where release.school_dispatch_release_id=p_release_id;
$$;

create function atlas_core.school_dispatch_actor_has_scope(
  p_actor_id uuid,p_school_id uuid,p_delivery_location_id uuid
) returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select atlas_core.school_catering_actor_has_scope(
    p_actor_id,null,p_school_id,p_delivery_location_id);
$$;

revoke execute on function
  atlas_core.school_dispatch_release_preview(date,uuid,uuid),
  atlas_core.school_dispatch_release_json(uuid),
  atlas_core.school_dispatch_actor_has_scope(uuid,uuid,uuid)
from public,anon,authenticated,service_role;
grant execute on function
  atlas_core.school_dispatch_release_preview(date,uuid,uuid),
  atlas_core.school_dispatch_release_json(uuid),
  atlas_core.school_dispatch_actor_has_scope(uuid,uuid,uuid)
to atlas_read_runtime,atlas_dispatch_command_runtime;

reset role;
set role atlas_owner;
grant create on schema atlas_core to atlas_procurement_command_runtime;
reset role;
set role atlas_procurement_command_runtime;

create function atlas_core.school_dispatch_lock_sources(
  p_service_date date,
  p_delivery_location_id uuid
)
returns void
language plpgsql
volatile
security definer
set search_path=''
as $$
begin
  perform 1
  from atlas_procurement.school_catering_allocation_families family
  where family.service_date=p_service_date
    and family.delivery_location_id=p_delivery_location_id
  order by family.family_id
  for share;

  perform 1
  from atlas_procurement.purchase_orders po
  where po.purchase_order_kind='SCHOOL_CATERING'
    and po.school_catering_service_date=p_service_date
  order by po.supplier_id,po.purchase_order_id
  for share;
end;
$$;

revoke execute on function atlas_core.school_dispatch_lock_sources(date,uuid)
from public,anon,authenticated,service_role;
grant execute on function atlas_core.school_dispatch_lock_sources(date,uuid)
to atlas_dispatch_command_runtime;

reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_procurement_command_runtime;
reset role;
set role atlas_read_runtime;

create function atlas_api.get_school_dispatch_release_workbench(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_name constant text := 'get_school_dispatch_release_workbench';
  v_actor jsonb; v_actor_id uuid; v_auth jsonb;
  v_start date; v_end date; v_search text; v_rows jsonb;
begin
  if request is null or jsonb_typeof(request)<>'object'
     or request-array['contract_version','requested_by_auth_subject','correlation_id',
       'payload']<>'{}'::jsonb
     or not (request ?& array['contract_version','requested_by_auth_subject',
       'correlation_id','payload'])
     or request->>'contract_version' is distinct from 'SCHOOL-DISPATCH-RELEASE.v1'
     or atlas_core.pa_05b_safe_uuid(request->>'requested_by_auth_subject') is null
     or atlas_core.pa_05b_safe_uuid(request->>'correlation_id') is null
     or jsonb_typeof(request->'payload')<>'object'
     or (request->'payload')-array['date_start','date_end','school_ids','search']
       <>'{}'::jsonb
     or not (request->'payload' ?& array['date_start','date_end','school_ids','search'])
     or jsonb_typeof(request#>'{payload,school_ids}')<>'array' then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'Provide a valid bounded School dispatch release scope.','DISPATCH',v_name);
  end if;
  begin
    v_start := nullif(btrim(request#>>'{payload,date_start}'),'')::date;
    v_end := nullif(btrim(request#>>'{payload,date_end}'),'')::date;
  exception when invalid_datetime_format or datetime_field_overflow then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'The School dispatch date range is invalid.','DISPATCH',v_name);
  end;
  v_search := nullif(btrim(request#>>'{payload,search}'),'');
  if v_start is null or v_end is null or v_end<v_start or v_end-v_start>30
     or exists(select 1 from jsonb_array_elements_text(
       request#>'{payload,school_ids}') value
       where atlas_core.pa_05b_safe_uuid(value) is null) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'Use an inclusive date range of at most 31 days and valid Schools.',
      'DISPATCH',v_name);
  end if;
  v_actor := atlas_core.pa_05b_resolve_actor(request,'DISPATCH',v_name);
  if v_actor ? 'error' then return v_actor->'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor->>'actor_id');
  v_auth := atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'dispatch.school_release.read','DISPATCH',v_name,null,null,null);
  if v_auth is not null then return v_auth; end if;

  with scopes as (
    select distinct confirmed.service_date,confirmed.school_id,
      confirmed.delivery_location_id
    from atlas_procurement.school_catering_allocation_family_revisions revision
    join atlas_procurement.school_catering_allocation_family_contributions contribution
      on contribution.family_revision_id=revision.family_revision_id
     and contribution.purchase_handoff_line_revision_id is not null
    join atlas_planning.purchase_handoff_line_revisions handoff
      on handoff.purchase_handoff_line_revision_id=
        contribution.purchase_handoff_line_revision_id
    join atlas_planning.confirmed_need_line_revisions confirmed
      on confirmed.confirmed_need_line_revision_id=
        handoff.confirmed_need_line_revision_id
    where revision.is_current and revision.source_kind='PURCHASE_HANDOFF'
      and confirmed.service_date between v_start and v_end
    union
    select distinct release.service_date,release.school_id,release.delivery_location_id
    from atlas_dispatch.school_dispatch_releases release
    where release.service_date between v_start and v_end
  ), visible as (
    select scope.*,preview.value preview,current_release.school_dispatch_release_id,
      current_release.source_fingerprint released_fingerprint,
      atlas_core.school_dispatch_release_json(
        current_release.school_dispatch_release_id) current_release,
      coalesce((select jsonb_agg(atlas_core.school_dispatch_release_json(
        history.school_dispatch_release_id) order by history.released_at desc)
        from atlas_dispatch.school_dispatch_releases history
        where history.service_date=scope.service_date
          and history.school_id=scope.school_id
          and history.delivery_location_id=scope.delivery_location_id),
        '[]'::jsonb) history
    from scopes scope
    cross join lateral (select atlas_core.school_dispatch_release_preview(
      scope.service_date,scope.school_id,scope.delivery_location_id) value) preview
    left join atlas_dispatch.school_dispatch_releases current_release
      on current_release.service_date=scope.service_date
     and current_release.school_id=scope.school_id
     and current_release.delivery_location_id=scope.delivery_location_id
     and current_release.release_status='RELEASED'
    where atlas_core.school_catering_actor_has_scope(
      v_actor_id,null,scope.school_id,scope.delivery_location_id)
      and (jsonb_array_length(request#>'{payload,school_ids}')=0
        or scope.school_id::text in (
          select jsonb_array_elements_text(request#>'{payload,school_ids}')))
      and (v_search is null
        or preview.value->>'school_name' ilike '%'||v_search||'%'
        or preview.value->>'delivery_location_name' ilike '%'||v_search||'%'
        or coalesce(current_release.document_number,'') ilike '%'||v_search||'%')
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'service_date',visible.service_date,'school_id',visible.school_id,
    'delivery_location_id',visible.delivery_location_id,
    'state',case
      when not (visible.preview->>'ready')::boolean then 'BLOCKED'
      when visible.school_dispatch_release_id is null then 'READY'
      when visible.released_fingerprint=visible.preview->>'source_fingerprint'
        then 'CURRENT'
      else 'REPLACEMENT_REQUIRED' end,
    'expected_version',coalesce((visible.current_release->>'version')::bigint,0),
    'preview',visible.preview,'current_release',visible.current_release,
    'history',visible.history,
    'allowed_actions',jsonb_build_object(
      'release',(visible.preview->>'ready')::boolean
        and visible.school_dispatch_release_id is null,
      'replace',(visible.preview->>'ready')::boolean
        and visible.school_dispatch_release_id is not null
        and visible.released_fingerprint<>visible.preview->>'source_fingerprint',
      'export',visible.school_dispatch_release_id is not null),
    'blockers',visible.preview->'blockers','warnings',visible.preview->'warnings'
  ) order by visible.service_date,visible.preview->>'school_name',visible.school_id),
  '[]'::jsonb) into v_rows from visible;
  return jsonb_build_object('success',true,
    'contract_version','SCHOOL-DISPATCH-RELEASE.v1',
    'date_start',v_start,'date_end',v_end,'rows',v_rows,
    'warnings','[]'::jsonb,'blockers','[]'::jsonb);
exception when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_READ_FAILURE',
    'The School dispatch release workbench could not be read safely.',
    'DISPATCH',v_name);
end;
$$;

revoke execute on function atlas_api.get_school_dispatch_release_workbench(jsonb)
from public,anon,service_role;
grant execute on function atlas_api.get_school_dispatch_release_workbench(jsonb)
to authenticated;

reset role;
set role atlas_owner;
revoke create on schema atlas_core,atlas_api from atlas_read_runtime;
grant create on schema atlas_api to atlas_dispatch_command_runtime;
grant execute on function atlas_core.school_catering_actor_has_scope(
  uuid,uuid,uuid,uuid) to atlas_dispatch_command_runtime;
reset role;
set role atlas_dispatch_command_runtime;

create function atlas_api.release_school_dispatch_document(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_name constant text := 'release_school_dispatch_document';
  v_actor jsonb; v_actor_id uuid; v_auth jsonb; v_begin jsonb; v_receipt uuid;
  v_receipt_request jsonb; v_date date; v_school_id uuid; v_location_id uuid;
  v_expected_version bigint; v_expected_fingerprint text; v_predecessor_id uuid;
  v_preview jsonb; v_current atlas_dispatch.school_dispatch_releases%rowtype;
  v_release_id uuid := gen_random_uuid(); v_document_number text;
  v_line jsonb; v_source jsonb; v_line_id uuid;
  v_event uuid; v_audit uuid; v_response jsonb; v_error jsonb;
begin
  if request is null or jsonb_typeof(request)<>'object'
     or request-array['contract_version','command_id','correlation_id','idempotency_key',
       'expected_version','requested_by_auth_subject','requested_at','reason_code',
       'reason_note','payload']<>'{}'::jsonb
     or not (request ?& array['contract_version','command_id','correlation_id',
       'idempotency_key','expected_version','requested_by_auth_subject','requested_at',
       'reason_code','reason_note','payload'])
     or request->>'contract_version' is distinct from 'SCHOOL-DISPATCH-RELEASE.v1'
     or atlas_core.pa_05b_safe_uuid(request->>'command_id') is null
     or atlas_core.pa_05b_safe_uuid(request->>'correlation_id') is null
     or atlas_core.pa_05b_safe_uuid(request->>'requested_by_auth_subject') is null
     or atlas_core.pa_05b_safe_timestamptz(request->>'requested_at') is null
     or atlas_core.pa_05b_safe_timestamptz(request->>'requested_at')>
       transaction_timestamp()+interval '60 seconds'
     or btrim(coalesce(request->>'idempotency_key',''))=''
     or request->>'reason_code' is distinct from
       'SCHOOL_DISPATCH_DOCUMENT_RELEASED'
     or (jsonb_typeof(request->'reason_note')<>'null' and (
       jsonb_typeof(request->'reason_note')<>'string'
       or char_length(request->>'reason_note') not between 1 and 500
       or request->>'reason_note'<>btrim(request->>'reason_note')))
     or jsonb_typeof(request->'payload')<>'object'
     or (request->'payload')-array['service_date','school_id',
       'delivery_location_id','expected_source_fingerprint',
       'predecessor_release_id']<>'{}'::jsonb
     or not (request->'payload' ?& array['service_date','school_id',
       'delivery_location_id','expected_source_fingerprint',
       'predecessor_release_id']) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'The bounded School dispatch release request is invalid.','DISPATCH',v_name);
  end if;
  begin
    v_date := nullif(btrim(request#>>'{payload,service_date}'),'')::date;
  exception when invalid_datetime_format or datetime_field_overflow then
    v_date := null;
  end;
  v_school_id := atlas_core.pa_05b_safe_uuid(request#>>'{payload,school_id}');
  v_location_id := atlas_core.pa_05b_safe_uuid(
    request#>>'{payload,delivery_location_id}');
  v_predecessor_id := atlas_core.pa_05b_safe_uuid(
    request#>>'{payload,predecessor_release_id}');
  v_expected_version := atlas_core.pa_05b_safe_bigint(request->>'expected_version');
  v_expected_fingerprint := request#>>'{payload,expected_source_fingerprint}';
  if v_date is null or v_school_id is null or v_location_id is null
     or v_expected_version is null or v_expected_version<0
     or char_length(coalesce(v_expected_fingerprint,''))<>64
     or ((request#>'{payload,predecessor_release_id}')<>'null'::jsonb
       and v_predecessor_id is null) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'The School/date/location identity and exact preview fingerprint are required.',
      'DISPATCH',v_name);
  end if;
  v_actor := atlas_core.pa_05b_resolve_actor(request,'DISPATCH',v_name);
  if v_actor ? 'error' then return v_actor->'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor->>'actor_id');
  v_auth := atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'dispatch.school_release.release','DISPATCH',v_name,null,null,null);
  if v_auth is not null then return v_auth; end if;
  if not atlas_core.school_dispatch_actor_has_scope(
      v_actor_id,v_school_id,v_location_id) then
    return atlas_core.pa_05b_command_error(request,'SCOPE_DENIED',
      'The actor is outside the requested School scope.','DISPATCH',v_name);
  end if;

  v_receipt_request := case when v_expected_version=0
    then jsonb_set(request,'{expected_version}','null'::jsonb) else request end;
  v_begin := atlas_core.pa_05b_begin_command(v_receipt_request,v_actor_id,v_name,
    'DISPATCH','school-dispatch-release:'||v_date||':'||v_school_id||':'||v_location_id);
  if v_begin->>'status' in ('REPLAY','ERROR') then return v_begin->'response'; end if;
  v_receipt := atlas_core.pa_05b_safe_uuid(v_begin->>'receipt_id');

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'school-dispatch-release:'||v_date||':'||v_school_id||':'||v_location_id,0));
  perform atlas_core.school_dispatch_lock_sources(v_date,v_location_id);
  select release.* into v_current
  from atlas_dispatch.school_dispatch_releases release
  where release.service_date=v_date and release.school_id=v_school_id
    and release.delivery_location_id=v_location_id
    and release.release_status='RELEASED' for update;

  if coalesce(v_current.version,0)<>v_expected_version
     or v_current.school_dispatch_release_id is distinct from v_predecessor_id then
    v_error := atlas_core.pa_05b_command_error(request,'STALE_VERSION',
      'The current School dispatch release no longer matches this request.',
      'DISPATCH',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  v_preview := atlas_core.school_dispatch_release_preview(
    v_date,v_school_id,v_location_id);
  if not coalesce((v_preview->>'ready')::boolean,false) then
    v_error := atlas_core.pa_05b_command_error(request,'PXK_NOT_READY',
      'The School dispatch document is blocked by current Planning or Procurement evidence.',
      'DISPATCH',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  if v_preview->>'source_fingerprint' is distinct from v_expected_fingerprint then
    v_error := atlas_core.pa_05b_command_error(request,'SOURCE_CHANGED',
      'The School dispatch preview changed. Reload before releasing.',
      'DISPATCH',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  if v_current.school_dispatch_release_id is not null
     and v_current.source_fingerprint=v_expected_fingerprint then
    v_error := atlas_core.pa_05b_command_error(request,'PXK_ALREADY_CURRENT',
      'The current released School dispatch document already matches this evidence.',
      'DISPATCH',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;

  if v_current.school_dispatch_release_id is not null then
    update atlas_dispatch.school_dispatch_releases set release_status='SUPERSEDED'
    where school_dispatch_release_id=v_current.school_dispatch_release_id;
  end if;
  v_document_number := format('PXK-%s-%s',to_char(v_date,'YYYYMMDD'),
    upper(substr(replace(v_release_id::text,'-',''),1,16)));
  insert into atlas_dispatch.school_dispatch_releases(
    school_dispatch_release_id,service_date,school_id,delivery_location_id,
    release_status,document_number,source_fingerprint,predecessor_release_id,
    school_name_snapshot,delivery_location_name_snapshot,
    delivery_address_snapshot,note,version,released_by_actor_id,released_at,command_id
  ) values(v_release_id,v_date,v_school_id,v_location_id,'RELEASED',
    v_document_number,v_expected_fingerprint,v_predecessor_id,
    v_preview->>'school_name',v_preview->>'delivery_location_name',
    v_preview->>'delivery_address',request->>'reason_note',1,v_actor_id,
    transaction_timestamp(),atlas_core.pa_05b_safe_uuid(request->>'command_id'));

  for v_line in select value from jsonb_array_elements(v_preview->'lines') loop
    insert into atlas_dispatch.school_dispatch_release_lines(
      school_dispatch_release_id,ingredient_id,unit_id,quantity,
      ingredient_name_snapshot,unit_code_snapshot
    ) values(v_release_id,(v_line->>'ingredient_id')::uuid,
      (v_line->>'unit_id')::uuid,(v_line->>'quantity')::numeric,
      v_line->>'ingredient_name',v_line->>'unit_code')
    returning school_dispatch_release_line_id into v_line_id;
    for v_source in select value from jsonb_array_elements(v_line->'sources') loop
      insert into atlas_dispatch.school_dispatch_release_line_sources(
        school_dispatch_release_line_id,confirmed_need_line_revision_id,
        confirmed_need_line_decision_id,allocation_family_revision_id,
        allocation_family_contribution_id,allocation_supplier_split_id,
        purchase_order_id,purchase_order_revision_id,
        purchase_order_line_revision_id,covered_quantity
      ) values(v_line_id,(v_source->>'confirmed_need_line_revision_id')::uuid,
        (v_source->>'confirmed_need_line_decision_id')::uuid,
        (v_source->>'allocation_family_revision_id')::uuid,
        (v_source->>'allocation_family_contribution_id')::uuid,
        (v_source->>'allocation_supplier_split_id')::uuid,
        (v_source->>'purchase_order_id')::uuid,
        (v_source->>'purchase_order_revision_id')::uuid,
        (v_source->>'purchase_order_line_revision_id')::uuid,
        (v_source->>'covered_quantity')::numeric);
    end loop;
  end loop;

  insert into atlas_audit.domain_events(
    event_type,source_domain,aggregate_type,aggregate_id,aggregate_version,
    command_receipt_id,command_id,correlation_id,actor_id,occurred_at,payload_summary
  ) values('SchoolDispatchDocumentReleased','DISPATCH','SchoolDispatchRelease',
    v_release_id,1,v_receipt,atlas_core.pa_05b_safe_uuid(request->>'command_id'),
    atlas_core.pa_05b_safe_uuid(request->>'correlation_id'),v_actor_id,
    transaction_timestamp(),jsonb_build_object('document_number',v_document_number,
      'service_date',v_date,'school_id',v_school_id,
      'delivery_location_id',v_location_id,'predecessor_release_id',v_predecessor_id))
  returning domain_event_id into v_event;
  insert into atlas_audit.audit_events(
    event_type,source_domain,aggregate_type,aggregate_id,
    aggregate_version_after,command_receipt_id,command_id,correlation_id,actor_id,
    reason_code,reason_note,after_summary,source_interface,occurred_at
  ) values('SchoolDispatchDocumentReleased','DISPATCH','SchoolDispatchRelease',
    v_release_id,1,v_receipt,atlas_core.pa_05b_safe_uuid(request->>'command_id'),
    atlas_core.pa_05b_safe_uuid(request->>'correlation_id'),v_actor_id,
    request->>'reason_code',request->>'reason_note',jsonb_build_object(
      'document_number',v_document_number,'status','RELEASED',
      'source_fingerprint',v_expected_fingerprint,
      'predecessor_release_id',v_predecessor_id),'atlas_api',transaction_timestamp())
  returning audit_event_id into v_audit;

  v_response := jsonb_build_object('success',true,
    'contract_version','SCHOOL-DISPATCH-RELEASE.v1',
    'command_id',request->>'command_id','correlation_id',request->>'correlation_id',
    'idempotency_status','COMPLETED','school_dispatch_release_id',v_release_id,
    'document_number',v_document_number,'new_version',1,
    'emitted_event_ids',jsonb_build_array(v_event),
    'audit_event_ids',jsonb_build_array(v_audit),
    'authoritative_readback',atlas_core.school_dispatch_release_json(v_release_id),
    'safe_operator_message','Đã phát hành Phiếu xuất kho cho trường.',
    'warnings','[]'::jsonb,'blockers','[]'::jsonb);
  return atlas_core.pa_05b_finish_command(v_receipt,v_response,true);
exception when serialization_failure or deadlock_detected or unique_violation then
  return atlas_core.pa_05b_command_error(request,'RETRYABLE_CONCURRENCY_FAILURE',
    'The School dispatch release could not acquire a safe transaction state. Retry the exact request.',
    'DISPATCH',v_name,true);
when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_COMMAND_FAILURE',
    'The School dispatch document could not be released safely.',
    'DISPATCH',v_name);
end;
$$;

revoke execute on function atlas_api.release_school_dispatch_document(jsonb)
from public,anon,service_role;
grant execute on function atlas_api.release_school_dispatch_document(jsonb)
to authenticated;

reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_dispatch_command_runtime;

reset role;
grant atlas_read_runtime,atlas_dispatch_command_runtime,
  atlas_procurement_command_runtime to postgres with set false;
