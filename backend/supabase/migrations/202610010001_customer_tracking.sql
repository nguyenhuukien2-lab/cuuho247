-- Customer tracking contract. Apply after 202609300001; no client status-write grant.
begin;

-- Lock before replacing the active index so concurrent creates cannot escape it.
lock table public.rescue_requests in access exclusive mode;
alter table public.rescue_requests drop constraint rescue_requests_status_check;
drop index public.rescue_requests_one_active_per_customer_uidx;
update public.rescue_requests set status = 'in_progress' where status = 'assisting';
alter table public.rescue_requests add constraint rescue_requests_status_check
  check (status in ('searching', 'accepted', 'arriving', 'in_progress', 'completed', 'cancelled'));
create unique index rescue_requests_one_active_per_customer_uidx
  on public.rescue_requests(customer_id)
  where status in ('searching', 'accepted', 'arriving', 'in_progress');

create table public.request_status_events (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.rescue_requests(id) on delete cascade,
  previous_status text check (previous_status in
    ('searching', 'accepted', 'arriving', 'in_progress', 'completed', 'cancelled')),
  status text not null check (status in
    ('searching', 'accepted', 'arriving', 'in_progress', 'completed', 'cancelled')),
  occurred_at timestamptz not null default clock_timestamp(),
  -- Existing rows only have a known current state; do not invent past transitions.
  is_initial_snapshot boolean not null default false
);
create index request_status_events_request_time_idx
  on public.request_status_events(request_id, occurred_at, id);
alter table public.request_status_events enable row level security;
revoke all on table public.request_status_events from public, anon, authenticated;
grant select on table public.request_status_events to authenticated;
create policy "customers read own request status events"
  on public.request_status_events for select to authenticated
  using (exists (
    select 1 from public.rescue_requests r
    where r.id = request_id and r.customer_id = (select auth.uid())
  ));

insert into public.request_status_events(request_id, status, occurred_at, is_initial_snapshot)
select id, status, updated_at, true from public.rescue_requests;

-- All trusted writers follow the same lifecycle. Customers still only have
-- SELECT plus the existing narrowly constrained create/cancel RPCs.
create function public.cuuho247_validate_request_transition()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if new.status is distinct from old.status and not (
    (old.status = 'searching' and new.status in ('accepted', 'cancelled'))
    or (old.status = 'accepted' and new.status in ('arriving', 'cancelled'))
    or (old.status = 'arriving' and new.status in ('in_progress', 'cancelled'))
    or (old.status = 'in_progress' and new.status in ('completed', 'cancelled'))
  ) then
    raise exception 'INVALID_REQUEST_STATUS_TRANSITION' using errcode = '22023';
  end if;
  new.updated_at := clock_timestamp();
  return new;
end;
$$;
revoke all on function public.cuuho247_validate_request_transition() from public, anon, authenticated;
create trigger cuuho247_request_transition
  before update on public.rescue_requests
  for each row execute function public.cuuho247_validate_request_transition();

create function public.cuuho247_record_request_status()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.request_status_events(request_id, status, occurred_at)
    values (new.id, new.status, new.created_at);
  elsif new.status is distinct from old.status then
    insert into public.request_status_events(request_id, previous_status, status, occurred_at)
    values (new.id, old.status, new.status, new.updated_at);
  end if;
  return new;
end;
$$;
revoke all on function public.cuuho247_record_request_status() from public, anon, authenticated;
create trigger cuuho247_request_status_event
  after insert or update on public.rescue_requests
  for each row execute function public.cuuho247_record_request_status();

-- Replace (not overload) the old signature: named calls without coordinates
-- remain valid through defaults, avoiding ambiguous PostgREST RPC resolution.
drop function public.create_customer_rescue_request(uuid, text, text, text, text, text, text, uuid);
create function public.create_customer_rescue_request(
  p_client_request_id uuid,
  p_vehicle_kind text,
  p_service_code text,
  p_location_text text,
  p_description text,
  p_contact_name text,
  p_contact_phone text,
  p_vehicle_id uuid default null,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns public.rescue_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  result public.rescue_requests;
begin
  if caller_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if p_client_request_id is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode = '22023';
  end if;
  -- Resolve an existing key before validating mutable catalog/vehicle data.
  select r.* into result
  from public.rescue_requests r
  where r.customer_id = caller_id and r.client_request_id = p_client_request_id;
  if found then return result; end if;

  -- A retry returns the original row above, even if its coordinates changed.
  if (p_latitude is null) <> (p_longitude is null)
     or (p_latitude is not null and not (p_latitude between -90 and 90))
     or (p_longitude is not null and not (p_longitude between -180 and 180)) then
    raise exception 'INVALID_COORDINATES' using errcode = '22023';
  end if;

  if p_vehicle_kind is null or p_vehicle_kind not in ('motorbike', 'car') then
    raise exception 'INVALID_VEHICLE_KIND' using errcode = '22023';
  end if;
  if p_location_text is null or length(trim(p_location_text)) = 0 then
    raise exception 'LOCATION_REQUIRED' using errcode = '22023';
  end if;
  if p_contact_name is null or length(trim(p_contact_name)) = 0
     or p_contact_phone is null or length(trim(p_contact_phone)) = 0 then
    raise exception 'CONTACT_REQUIRED' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.rescue_services s
    where s.code = p_service_code and s.is_active
  ) then
    raise exception 'SERVICE_UNAVAILABLE' using errcode = '22023';
  end if;
  if p_vehicle_id is not null and not exists (
    select 1 from public.customer_vehicles v
    where v.id = p_vehicle_id and v.customer_id = caller_id
  ) then
    raise exception 'VEHICLE_NOT_OWNED' using errcode = '42501';
  end if;

  select r.* into result
  from public.rescue_requests r
  where r.customer_id = caller_id
    and r.status in ('searching', 'accepted', 'arriving', 'in_progress')
  order by r.created_at desc limit 1;
  if found then return result; end if;

  begin
    insert into public.rescue_requests (
      customer_id, client_request_id, vehicle_id, vehicle_kind,
      service_code, location_text, location_confirmed, description,
      contact_name, contact_phone, status, latitude, longitude
    ) values (
      caller_id, p_client_request_id, p_vehicle_id, p_vehicle_kind,
      p_service_code, trim(p_location_text), true, coalesce(p_description, ''),
      trim(p_contact_name), trim(p_contact_phone), 'searching', p_latitude, p_longitude
    ) returning * into result;
    return result;
  exception when unique_violation then
    select r.* into result
    from public.rescue_requests r
    where r.customer_id = caller_id and r.client_request_id = p_client_request_id;
    if found then return result; end if;

    select r.* into result
    from public.rescue_requests r
    where r.customer_id = caller_id
      and r.status in ('searching', 'accepted', 'arriving', 'in_progress')
    order by r.created_at desc limit 1;
    if found then return result; end if;
    raise;
  end;
end;
$$;

revoke all on function public.create_customer_rescue_request(uuid, text, text, text, text, text, text, uuid, double precision, double precision) from public, anon;
grant execute on function public.create_customer_rescue_request(uuid, text, text, text, text, text, text, uuid, double precision, double precision) to authenticated;


-- Realtime uses the existing owner-only SELECT policy on rescue_requests.
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'rescue_requests'
  ) then
    alter publication supabase_realtime add table public.rescue_requests;
  end if;
end;
$$;
notify pgrst, 'reload schema';
commit;
