-- Persisted business codes. Apply AFTER the shared migrations and Admin foundation.
-- UUID primary/foreign keys, existing RLS, RPC arguments and service codes stay intact.
begin;
set local lock_timeout = '5s';
-- Avoid concurrent INSERT/UPDATE while synchronizing sequences and backfilling.
lock table public.customer_profiles, public.rescuer_profiles,
  public.rescue_requests, public.rescue_quotes, public.admin_profiles
  in access exclusive mode;

create or replace function public.format_display_code(prefix text, value bigint)
returns text language plpgsql immutable strict set search_path = '' as $$
begin
  if prefix !~ '^[A-Z]+$' or value < 1 then
    raise exception 'DISPLAY_CODE_INVALID_ARGUMENT' using errcode = '22023';
  end if;
  -- lpad alone truncates values above 999999; preserve all digits on growth.
  return prefix || '-' || pg_catalog.lpad(value::text, greatest(6, length(value::text)), '0');
end;
$$;
revoke all on function public.format_display_code(text,bigint) from public, anon, authenticated;

-- Only attached to the five tables below. No client can execute or consume sequences.
create or replace function private.assign_display_code() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_column text := tg_argv[0];
  v_sequence regclass := tg_argv[1]::regclass;
  v_prefix text := tg_argv[2];
  v_code text := pg_catalog.to_jsonb(new)->>v_column;
  v_exists boolean;
begin
  if tg_op = 'UPDATE' then
    if (pg_catalog.to_jsonb(old)->>v_column) is distinct from v_code then
      raise exception 'DISPLAY_CODE_IMMUTABLE' using errcode = '22023';
    end if;
    return new;
  end if;
  if v_code is null or pg_catalog.btrim(v_code) = '' then
    loop
      v_code := public.format_display_code(v_prefix, pg_catalog.nextval(v_sequence));
      -- Also skip a code explicitly imported after migration.
      execute pg_catalog.format('select exists(select 1 from %I.%I where %I = $1)',
        tg_table_schema, tg_table_name, v_column) into v_exists using v_code;
      exit when not v_exists;
    end loop;
    new := pg_catalog.jsonb_populate_record(new, pg_catalog.jsonb_build_object(v_column, v_code));
  end if;
  return new;
end;
$$;
revoke all on function private.assign_display_code() from public, anon, authenticated;

alter table public.customer_profiles add column if not exists customer_code text;
create sequence if not exists public.customer_code_seq as bigint start with 1;
revoke all on sequence public.customer_code_seq from public, anon, authenticated;
-- Fail atomically on conflicting imported codes rather than change an existing code.
do $backfill$
declare
  v_max bigint;
  v_last bigint;
  v_called boolean;
  v_row record;
  v_order text;
begin
  if exists(select 1 from public.customer_profiles where nullif(btrim(customer_code), '') is not null
      and case when customer_code ~ '^KH-[0-9]{6,}$'
        then substring(customer_code from 4)::numeric < 1 else true end) then
    raise exception 'DISPLAY_CODE_INVALID_EXISTING: customer_profiles.customer_code';
  end if;
  select coalesce(max(substring(customer_code from 4)::bigint), 0) into v_max
    from public.customer_profiles where nullif(btrim(customer_code), '') is not null;
  select last_value, is_called into v_last, v_called from public.customer_code_seq;
  -- Never rewind an existing sequence, including one advanced by rolled-back inserts.
  if v_max > 0 or v_called then
    perform pg_catalog.setval('public.customer_code_seq'::regclass, greatest(v_max, v_last), true);
  end if;
  v_order := case when exists(select 1 from information_schema.columns
      where table_schema='public' and table_name='customer_profiles' and column_name='created_at')
    then 'created_at nulls last, user_id' else 'user_id' end;
  for v_row in execute pg_catalog.format(
    'select user_id as identity from public.customer_profiles where nullif(btrim(customer_code), '''') is null order by %s', v_order)
  loop
    update public.customer_profiles
      set customer_code = public.format_display_code('KH', pg_catalog.nextval('public.customer_code_seq'::regclass))
      where user_id = v_row.identity;
  end loop;
end;
$backfill$;
-- Shared consistency constraints may have queued events during backfill.
set constraints all immediate;
alter table public.customer_profiles alter column customer_code set not null;
create unique index if not exists customer_profiles_customer_code_uidx on public.customer_profiles(customer_code);
do $constraint$
begin
  if not exists(select 1 from pg_catalog.pg_constraint
      where conrelid='public.customer_profiles'::regclass and conname='customer_profiles_customer_code_format') then
    alter table public.customer_profiles add constraint customer_profiles_customer_code_format
      check (customer_code ~ '^KH-[0-9]{6,}$' and substring(customer_code from 4)::numeric > 0);
  end if;
end;
$constraint$;
drop trigger if exists customer_profiles_display_code on public.customer_profiles;
create trigger customer_profiles_display_code before insert or update of customer_code on public.customer_profiles
  for each row execute function private.assign_display_code('customer_code', 'public.customer_code_seq', 'KH');

alter table public.rescuer_profiles add column if not exists rescuer_code text;
create sequence if not exists public.rescuer_code_seq as bigint start with 1;
revoke all on sequence public.rescuer_code_seq from public, anon, authenticated;
-- Fail atomically on conflicting imported codes rather than change an existing code.
do $backfill$
declare
  v_max bigint;
  v_last bigint;
  v_called boolean;
  v_row record;
  v_order text;
begin
  if exists(select 1 from public.rescuer_profiles where nullif(btrim(rescuer_code), '') is not null
      and case when rescuer_code ~ '^DT-[0-9]{6,}$'
        then substring(rescuer_code from 4)::numeric < 1 else true end) then
    raise exception 'DISPLAY_CODE_INVALID_EXISTING: rescuer_profiles.rescuer_code';
  end if;
  select coalesce(max(substring(rescuer_code from 4)::bigint), 0) into v_max
    from public.rescuer_profiles where nullif(btrim(rescuer_code), '') is not null;
  select last_value, is_called into v_last, v_called from public.rescuer_code_seq;
  -- Never rewind an existing sequence, including one advanced by rolled-back inserts.
  if v_max > 0 or v_called then
    perform pg_catalog.setval('public.rescuer_code_seq'::regclass, greatest(v_max, v_last), true);
  end if;
  v_order := case when exists(select 1 from information_schema.columns
      where table_schema='public' and table_name='rescuer_profiles' and column_name='created_at')
    then 'created_at nulls last, user_id' else 'user_id' end;
  for v_row in execute pg_catalog.format(
    'select user_id as identity from public.rescuer_profiles where nullif(btrim(rescuer_code), '''') is null order by %s', v_order)
  loop
    update public.rescuer_profiles
      set rescuer_code = public.format_display_code('DT', pg_catalog.nextval('public.rescuer_code_seq'::regclass))
      where user_id = v_row.identity;
  end loop;
end;
$backfill$;
-- Shared consistency constraints may have queued events during backfill.
set constraints all immediate;
alter table public.rescuer_profiles alter column rescuer_code set not null;
create unique index if not exists rescuer_profiles_rescuer_code_uidx on public.rescuer_profiles(rescuer_code);
do $constraint$
begin
  if not exists(select 1 from pg_catalog.pg_constraint
      where conrelid='public.rescuer_profiles'::regclass and conname='rescuer_profiles_rescuer_code_format') then
    alter table public.rescuer_profiles add constraint rescuer_profiles_rescuer_code_format
      check (rescuer_code ~ '^DT-[0-9]{6,}$' and substring(rescuer_code from 4)::numeric > 0);
  end if;
end;
$constraint$;
drop trigger if exists rescuer_profiles_display_code on public.rescuer_profiles;
create trigger rescuer_profiles_display_code before insert or update of rescuer_code on public.rescuer_profiles
  for each row execute function private.assign_display_code('rescuer_code', 'public.rescuer_code_seq', 'DT');

alter table public.rescue_requests add column if not exists request_code text;
create sequence if not exists public.request_code_seq as bigint start with 1;
revoke all on sequence public.request_code_seq from public, anon, authenticated;
-- Fail atomically on conflicting imported codes rather than change an existing code.
do $backfill$
declare
  v_max bigint;
  v_last bigint;
  v_called boolean;
  v_row record;
  v_order text;
begin
  if exists(select 1 from public.rescue_requests where nullif(btrim(request_code), '') is not null
      and case when request_code ~ '^CH-[0-9]{6,}$'
        then substring(request_code from 4)::numeric < 1 else true end) then
    raise exception 'DISPLAY_CODE_INVALID_EXISTING: rescue_requests.request_code';
  end if;
  select coalesce(max(substring(request_code from 4)::bigint), 0) into v_max
    from public.rescue_requests where nullif(btrim(request_code), '') is not null;
  select last_value, is_called into v_last, v_called from public.request_code_seq;
  -- Never rewind an existing sequence, including one advanced by rolled-back inserts.
  if v_max > 0 or v_called then
    perform pg_catalog.setval('public.request_code_seq'::regclass, greatest(v_max, v_last), true);
  end if;
  v_order := case when exists(select 1 from information_schema.columns
      where table_schema='public' and table_name='rescue_requests' and column_name='created_at')
    then 'created_at nulls last, id' else 'id' end;
  for v_row in execute pg_catalog.format(
    'select id as identity from public.rescue_requests where nullif(btrim(request_code), '''') is null order by %s', v_order)
  loop
    update public.rescue_requests
      set request_code = public.format_display_code('CH', pg_catalog.nextval('public.request_code_seq'::regclass))
      where id = v_row.identity;
  end loop;
end;
$backfill$;
-- Shared consistency constraints may have queued events during backfill.
set constraints all immediate;
alter table public.rescue_requests alter column request_code set not null;
create unique index if not exists rescue_requests_request_code_uidx on public.rescue_requests(request_code);
do $constraint$
begin
  if not exists(select 1 from pg_catalog.pg_constraint
      where conrelid='public.rescue_requests'::regclass and conname='rescue_requests_request_code_format') then
    alter table public.rescue_requests add constraint rescue_requests_request_code_format
      check (request_code ~ '^CH-[0-9]{6,}$' and substring(request_code from 4)::numeric > 0);
  end if;
end;
$constraint$;
drop trigger if exists rescue_requests_display_code on public.rescue_requests;
create trigger rescue_requests_display_code before insert or update of request_code on public.rescue_requests
  for each row execute function private.assign_display_code('request_code', 'public.request_code_seq', 'CH');

alter table public.rescue_quotes add column if not exists quote_code text;
create sequence if not exists public.quote_code_seq as bigint start with 1;
revoke all on sequence public.quote_code_seq from public, anon, authenticated;
-- Fail atomically on conflicting imported codes rather than change an existing code.
do $backfill$
declare
  v_max bigint;
  v_last bigint;
  v_called boolean;
  v_row record;
  v_order text;
begin
  if exists(select 1 from public.rescue_quotes where nullif(btrim(quote_code), '') is not null
      and case when quote_code ~ '^BG-[0-9]{6,}$'
        then substring(quote_code from 4)::numeric < 1 else true end) then
    raise exception 'DISPLAY_CODE_INVALID_EXISTING: rescue_quotes.quote_code';
  end if;
  select coalesce(max(substring(quote_code from 4)::bigint), 0) into v_max
    from public.rescue_quotes where nullif(btrim(quote_code), '') is not null;
  select last_value, is_called into v_last, v_called from public.quote_code_seq;
  -- Never rewind an existing sequence, including one advanced by rolled-back inserts.
  if v_max > 0 or v_called then
    perform pg_catalog.setval('public.quote_code_seq'::regclass, greatest(v_max, v_last), true);
  end if;
  v_order := case when exists(select 1 from information_schema.columns
      where table_schema='public' and table_name='rescue_quotes' and column_name='created_at')
    then 'created_at nulls last, id' else 'id' end;
  for v_row in execute pg_catalog.format(
    'select id as identity from public.rescue_quotes where nullif(btrim(quote_code), '''') is null order by %s', v_order)
  loop
    update public.rescue_quotes
      set quote_code = public.format_display_code('BG', pg_catalog.nextval('public.quote_code_seq'::regclass))
      where id = v_row.identity;
  end loop;
end;
$backfill$;
-- Shared consistency constraints may have queued events during backfill.
set constraints all immediate;
alter table public.rescue_quotes alter column quote_code set not null;
create unique index if not exists rescue_quotes_quote_code_uidx on public.rescue_quotes(quote_code);
do $constraint$
begin
  if not exists(select 1 from pg_catalog.pg_constraint
      where conrelid='public.rescue_quotes'::regclass and conname='rescue_quotes_quote_code_format') then
    alter table public.rescue_quotes add constraint rescue_quotes_quote_code_format
      check (quote_code ~ '^BG-[0-9]{6,}$' and substring(quote_code from 4)::numeric > 0);
  end if;
end;
$constraint$;
drop trigger if exists rescue_quotes_display_code on public.rescue_quotes;
create trigger rescue_quotes_display_code before insert or update of quote_code on public.rescue_quotes
  for each row execute function private.assign_display_code('quote_code', 'public.quote_code_seq', 'BG');

alter table public.admin_profiles add column if not exists admin_code text;
create sequence if not exists public.admin_code_seq as bigint start with 1;
revoke all on sequence public.admin_code_seq from public, anon, authenticated;
-- Fail atomically on conflicting imported codes rather than change an existing code.
do $backfill$
declare
  v_max bigint;
  v_last bigint;
  v_called boolean;
  v_row record;
  v_order text;
begin
  if exists(select 1 from public.admin_profiles where nullif(btrim(admin_code), '') is not null
      and case when admin_code ~ '^AD-[0-9]{6,}$'
        then substring(admin_code from 4)::numeric < 1 else true end) then
    raise exception 'DISPLAY_CODE_INVALID_EXISTING: admin_profiles.admin_code';
  end if;
  select coalesce(max(substring(admin_code from 4)::bigint), 0) into v_max
    from public.admin_profiles where nullif(btrim(admin_code), '') is not null;
  select last_value, is_called into v_last, v_called from public.admin_code_seq;
  -- Never rewind an existing sequence, including one advanced by rolled-back inserts.
  if v_max > 0 or v_called then
    perform pg_catalog.setval('public.admin_code_seq'::regclass, greatest(v_max, v_last), true);
  end if;
  v_order := case when exists(select 1 from information_schema.columns
      where table_schema='public' and table_name='admin_profiles' and column_name='created_at')
    then 'created_at nulls last, id' else 'id' end;
  for v_row in execute pg_catalog.format(
    'select id as identity from public.admin_profiles where nullif(btrim(admin_code), '''') is null order by %s', v_order)
  loop
    update public.admin_profiles
      set admin_code = public.format_display_code('AD', pg_catalog.nextval('public.admin_code_seq'::regclass))
      where id = v_row.identity;
  end loop;
end;
$backfill$;
-- Shared consistency constraints may have queued events during backfill.
set constraints all immediate;
alter table public.admin_profiles alter column admin_code set not null;
create unique index if not exists admin_profiles_admin_code_uidx on public.admin_profiles(admin_code);
do $constraint$
begin
  if not exists(select 1 from pg_catalog.pg_constraint
      where conrelid='public.admin_profiles'::regclass and conname='admin_profiles_admin_code_format') then
    alter table public.admin_profiles add constraint admin_profiles_admin_code_format
      check (admin_code ~ '^AD-[0-9]{6,}$' and substring(admin_code from 4)::numeric > 0);
  end if;
end;
$constraint$;
drop trigger if exists admin_profiles_display_code on public.admin_profiles;
create trigger admin_profiles_display_code before insert or update of admin_code on public.admin_profiles
  for each row execute function private.assign_display_code('admin_code', 'public.admin_code_seq', 'AD');

-- Append new view columns to preserve column order, dependencies and existing grants.
create or replace view public.admin_rescue_requests_view with (security_barrier=true,security_invoker=false) as
select r.id as request_id,r.request_code,
  r.customer_id,coalesce(nullif(c.full_name,''),r.contact_name) as customer_name,
  coalesce(c.phone,r.contact_phone) as customer_phone,u.email::text as customer_email,
  r.service_code as service_type,r.description as problem_description,
  v.display_name as vehicle_name,v.license_plate as vehicle_plate,r.status,
  r.location_text as pickup_address,r.latitude as pickup_lat,r.longitude as pickup_lng,
  null::text as destination_address, -- not stored in the shared schema
  r.created_at,coalesce(a.accepted_at,e.accepted_at) as accepted_at,
  coalesce(a.completed_at,e.completed_at) as completed_at,
  coalesce(a.rescuer_id,r.provider_id) as rescuer_id,p.full_name as rescuer_name,p.contact_phone as rescuer_phone,
  case when public.has_admin_role(array['super_admin','finance']) then q.total_vnd::numeric end as quote_amount,
  q.status as quote_status
from public.rescue_requests r
left join public.customer_profiles c on c.user_id=r.customer_id
left join auth.users u on u.id=r.customer_id
left join public.customer_vehicles v on v.id=r.vehicle_id and v.customer_id=r.customer_id
left join public.rescue_request_assignments a on a.request_id=r.id
left join public.rescuer_profiles p on p.user_id=coalesce(a.rescuer_id,r.provider_id)
left join public.rescue_quotes q on q.id=a.current_quote_id and q.assignment_id=a.id
left join lateral (
  select min(s.occurred_at) filter(where s.status='accepted' and not s.is_initial_snapshot) as accepted_at,
    min(s.occurred_at) filter(where s.status='completed' and not s.is_initial_snapshot) as completed_at
  from public.request_status_events s where s.request_id=r.id
) e on true
where (select public.has_admin_role(array['super_admin','operator','support']));

create or replace view public.admin_customers_view with (security_barrier=true,security_invoker=false) as
select c.user_id as customer_id,c.full_name,u.email::text as email,c.phone,
  null::text as avatar_url, -- absent; do not use untrusted Auth user_metadata
  (select count(*) from public.customer_vehicles v where v.customer_id=c.user_id) as vehicle_count,
  (select count(*) from public.customer_saved_addresses s where s.customer_id=c.user_id) as address_count,
  (select count(*) from public.rescue_requests r where r.customer_id=c.user_id) as request_count,
  (select count(*) from public.rescue_requests r where r.customer_id=c.user_id and r.status='completed') as completed_count,
  0::numeric as total_spent, -- no payment/settlement ledger; issued != paid
  c.created_at,null::text as status -- no customer status column
  ,c.customer_code
from public.customer_profiles c left join auth.users u on u.id=c.user_id
where (select public.has_admin_role(array['super_admin','operator','support']));

create or replace view public.admin_rescuers_view with (security_barrier=true,security_invoker=false) as
select p.user_id as rescuer_id,p.full_name,p.contact_phone as phone,u.email::text as email,
  p.verification_status as approval_status,coalesce(o.is_online,false) as online_status,o.last_seen_at,
  coalesce(o.is_online and p.verification_status='approved'
    and o.last_seen_at>=now()-interval '120 seconds',false) as is_available,
  (select count(*) from public.rescuer_vehicles v where v.rescuer_id=p.user_id) as vehicle_count,
  (select count(distinct c.service_code) from public.rescuer_service_capabilities c
    where c.rescuer_id=p.user_id and c.is_enabled and c.verification_status='approved') as service_count,
  (select count(*) from public.rescue_request_assignments a where a.rescuer_id=p.user_id and a.state='completed') as completed_jobs,
  coalesce((select round(avg(v.rating),2) from public.customer_request_reviews v
    join public.rescue_requests r on r.id=v.request_id where r.provider_id=p.user_id),0) as average_rating,
  p.created_at,p.version,p.rescuer_code
from public.rescuer_profiles p left join auth.users u on u.id=p.user_id
left join public.rescuer_online_status o on o.rescuer_id=p.user_id
where (select public.has_admin_role(array['super_admin','operator','partner_reviewer']));

create or replace view public.admin_quotes_view with (security_barrier=true,security_invoker=false) as
select q.id as quote_id,q.request_id,r.request_code,
  coalesce(nullif(c.full_name,''),r.contact_name) as customer_name,p.full_name as rescuer_name,
  r.service_code as service_type,q.total_vnd::numeric as amount,q.note,q.status,q.issued_at as created_at,
  q.currency,q.revision,(q.id=a.current_quote_id) as is_current,
  (q.id=a.completion_quote_id and a.state='completed') as is_completion_quote,q.quote_code
from public.rescue_quotes q join public.rescue_requests r on r.id=q.request_id
join public.rescue_request_assignments a on a.id=q.assignment_id
left join public.customer_profiles c on c.user_id=r.customer_id
left join public.rescuer_profiles p on p.user_id=q.rescuer_id
where (select public.has_admin_role(array['super_admin','finance']));

create or replace view public.admin_reviews_view with (security_barrier=true,security_invoker=false) as
select v.id as review_id,v.request_id,r.request_code,
  coalesce(nullif(c.full_name,''),r.contact_name) as customer_name,p.full_name as rescuer_name,
  v.rating,v.comment,v.created_at
from public.customer_request_reviews v join public.rescue_requests r on r.id=v.request_id
left join public.customer_profiles c on c.user_id=v.customer_id
left join public.rescue_request_assignments a on a.request_id=r.id
left join public.rescuer_profiles p on p.user_id=coalesce(a.rescuer_id,r.provider_id)
where (select public.has_admin_role(array['super_admin','operator','support']));

-- admin_services_view already returns the persisted service catalog code; keep it.

-- Extend existing RPC projections without changing authorization or UUID contracts.
create or replace function private.rescuer_profile_dto() returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('user_id',user_id,'rescuer_code',rescuer_code,'full_name',full_name,'contact_phone',contact_phone,
    'verification_status',verification_status,'submitted_at',submitted_at,'verified_at',verified_at,
    'version',version,'created_at',created_at,'updated_at',updated_at)
  from public.rescuer_profiles where user_id=auth.uid();
$$;

create or replace function private.rescuer_assignment_dto(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('assignment_id',a.id,'request_id',a.request_id,'request_code',r.request_code,'vehicle_id',a.vehicle_id,
    'state',a.state,'version',a.version,'accepted_at',a.accepted_at,'en_route_at',a.en_route_at,
    'arrived_at',a.arrived_at,'in_progress_at',a.in_progress_at,'completed_at',a.completed_at,
    'cancelled_at',a.cancelled_at,'cancellation_reason_code',a.cancellation_reason_code,
    'current_quote_id',a.current_quote_id,'quote_code',q.quote_code,'completion_quote_id',a.completion_quote_id,
    'total_vnd',q.total_vnd,'currency',q.currency)
  from public.rescue_request_assignments a join public.rescue_requests r on r.id=a.request_id
  left join public.rescue_quotes q on q.id=a.current_quote_id
  where a.id=p_id and a.rescuer_id=auth.uid();
$$;

create or replace function private.rescuer_quote_dto(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('quote_id',q.id,'quote_code',q.quote_code,'assignment_id',q.assignment_id,'request_id',q.request_id,
    'revision',q.revision,'status',q.status,'currency',q.currency,'total_vnd',q.total_vnd,
    'issued_at',q.issued_at,'assignment_version',a.version)
    || case when a.state in ('accepted','en_route','arrived','in_progress') and p.verification_status='approved'
      then jsonb_build_object('items',q.items,'note',q.note) else '{}'::jsonb end
  from public.rescue_quotes q
  join public.rescue_request_assignments a on a.id=q.assignment_id
  join public.rescuer_profiles p on p.user_id=q.rescuer_id
  where q.id=p_id and q.rescuer_id=auth.uid();
$$;

create or replace function private.rescuer_available_dto(p_id uuid,p_lat double precision,p_lon double precision,p_service text,p_kind text,p_distance integer)
returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object('request_id',p_id,'request_code',(select r.request_code from public.rescue_requests r where r.id=p_id),'approximate_location',jsonb_build_object(
    'latitude',p_lat,'longitude',p_lon,'cell_size_degrees',0.01,'precision','coarse'),
    'service_type',p_service,'vehicle_type',p_kind,'estimated_distance_km',p_distance);
$$;

-- Customers cannot SELECT rescue_quotes directly. Expose only codes for their own
-- requests, in one bounded batch. Do not expose notes/items or grant shared-table access.
create or replace function public.customer_request_display_codes(p_request_ids uuid[])
returns table(request_id uuid, quote_code text)
language sql stable security definer set search_path = '' as $$
  select r.id, q.quote_code
  from public.rescue_requests r
  left join public.rescue_request_assignments a on a.request_id = r.id
  left join public.rescue_quotes q on q.id = a.current_quote_id and q.assignment_id = a.id
  where r.customer_id = (select auth.uid()) and r.id = any(p_request_ids)
    and cardinality(p_request_ids) <= 100;
$$;
revoke all on function public.customer_request_display_codes(uuid[]) from public, anon, authenticated;
grant execute on function public.customer_request_display_codes(uuid[]) to authenticated;

notify pgrst, 'reload schema';
commit;
