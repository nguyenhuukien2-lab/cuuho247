-- Customer app foundation: profiles, vehicles, service catalog and rescue requests.
-- Review and apply to the intended Supabase environment with the Supabase CLI.

begin;

-- Initial migration only: do not silently merge with existing tables/policies.
do $$
begin
  if to_regclass('public.customer_profiles') is not null
     or to_regclass('public.customer_vehicles') is not null
     or to_regclass('public.rescue_services') is not null
     or to_regclass('public.rescue_requests') is not null then
    raise exception 'EXISTING_SCHEMA_REQUIRES_REVIEW';
  end if;
end;
$$;

create extension if not exists pgcrypto;

create table if not exists public.customer_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_vehicles (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('motorbike', 'car')),
  display_name text,
  license_plate text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.rescue_services (
  code text primary key,
  name text not null,
  is_active boolean not null default true,
  sort_order integer not null default 0
);

insert into public.rescue_services(code, name, sort_order) values
  ('tire', 'Vá lốp', 10),
  ('battery', 'Kích bình', 20),
  ('fuel', 'Tiếp nhiên liệu', 30),
  ('towing', 'Kéo xe', 40),
  ('other', 'Khác', 50)
on conflict (code) do update set
  name = excluded.name,
  sort_order = excluded.sort_order;

create table if not exists public.rescue_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id) on delete cascade,
  client_request_id uuid not null,
  vehicle_id uuid references public.customer_vehicles(id) on delete set null,
  vehicle_kind text not null check (vehicle_kind in ('motorbike', 'car')),
  service_code text not null references public.rescue_services(code),
  location_text text not null check (length(trim(location_text)) > 0),
  latitude double precision check (latitude is null or latitude between -90 and 90),
  longitude double precision check (longitude is null or longitude between -180 and 180),
  location_confirmed boolean not null check (location_confirmed),
  description text not null default '',
  contact_name text not null check (length(trim(contact_name)) > 0),
  contact_phone text not null check (length(trim(contact_phone)) > 0),
  status text not null default 'searching' check (
    status in ('searching', 'accepted', 'arriving', 'assisting', 'completed', 'cancelled')
  ),
  provider_id uuid,
  quoted_price integer check (quoted_price is null or quoted_price >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists rescue_requests_customer_client_request_uidx
  on public.rescue_requests(customer_id, client_request_id);
create unique index if not exists rescue_requests_one_active_per_customer_uidx
  on public.rescue_requests(customer_id)
  where status in ('searching', 'accepted', 'arriving', 'assisting');
create index if not exists customer_vehicles_customer_idx
  on public.customer_vehicles(customer_id);
create index if not exists rescue_requests_customer_created_idx
  on public.rescue_requests(customer_id, created_at desc);

alter table public.customer_profiles enable row level security;
alter table public.customer_vehicles enable row level security;
alter table public.rescue_services enable row level security;
alter table public.rescue_requests enable row level security;

revoke all on table public.customer_profiles from public, anon, authenticated;
revoke all on table public.customer_vehicles from public, anon, authenticated;
revoke all on table public.rescue_services from public, anon, authenticated;
revoke all on table public.rescue_requests from public, anon, authenticated;

grant select, insert, update on table public.customer_profiles to authenticated;
grant select, insert, update, delete on table public.customer_vehicles to authenticated;
grant select on table public.rescue_services to authenticated;
grant select on table public.rescue_requests to authenticated;

create policy "customers read own profile"
  on public.customer_profiles for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "customers insert own profile"
  on public.customer_profiles for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "customers update own profile"
  on public.customer_profiles for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "customers read own vehicles"
  on public.customer_vehicles for select to authenticated
  using ((select auth.uid()) = customer_id);
create policy "customers insert own vehicles"
  on public.customer_vehicles for insert to authenticated
  with check ((select auth.uid()) = customer_id);
create policy "customers update own vehicles"
  on public.customer_vehicles for update to authenticated
  using ((select auth.uid()) = customer_id)
  with check ((select auth.uid()) = customer_id);
create policy "customers delete own vehicles"
  on public.customer_vehicles for delete to authenticated
  using ((select auth.uid()) = customer_id);

create policy "authenticated users read active services"
  on public.rescue_services for select to authenticated
  using (is_active);

create policy "customers read own rescue requests"
  on public.rescue_requests for select to authenticated
  using ((select auth.uid()) = customer_id);

create function public.cuuho247_handle_new_customer()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.customer_profiles(user_id, full_name, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'phone', '')
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

revoke all on function public.cuuho247_handle_new_customer() from public, anon, authenticated;

-- App-specific name avoids replacing another application's Auth trigger.
create trigger cuuho247_customer_profile_created
  after insert on auth.users
  for each row execute procedure public.cuuho247_handle_new_customer();

-- Cancellation is deliberately exposed as a constrained function instead of
-- granting customers arbitrary UPDATE access to status/provider/price fields.
create function public.cancel_own_rescue_request(request_id uuid)
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
  update public.rescue_requests
     set status = 'cancelled', updated_at = now()
   where id = request_id
     and customer_id = caller_id
     and status in ('searching', 'accepted')
  returning * into result;
  if result.id is null then
    raise exception 'REQUEST_NOT_CANCELLABLE' using errcode = 'P0001';
  end if;
  return result;
end;
$$;

revoke all on function public.cancel_own_rescue_request(uuid) from public, anon;
grant execute on function public.cancel_own_rescue_request(uuid) to authenticated;

-- The only customer write path for requests. It derives ownership from the
-- verified JWT, returns the same row for an idempotent retry, and serializes
-- competing submissions for the one-active-request constraint.
create function public.create_customer_rescue_request(
  p_client_request_id uuid,
  p_vehicle_kind text,
  p_service_code text,
  p_location_text text,
  p_description text,
  p_contact_name text,
  p_contact_phone text,
  p_vehicle_id uuid default null
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
    and r.status in ('searching', 'accepted', 'arriving', 'assisting')
  order by r.created_at desc limit 1;
  if found then return result; end if;

  begin
    insert into public.rescue_requests (
      customer_id, client_request_id, vehicle_id, vehicle_kind,
      service_code, location_text, location_confirmed, description,
      contact_name, contact_phone, status
    ) values (
      caller_id, p_client_request_id, p_vehicle_id, p_vehicle_kind,
      p_service_code, trim(p_location_text), true, coalesce(p_description, ''),
      trim(p_contact_name), trim(p_contact_phone), 'searching'
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
      and r.status in ('searching', 'accepted', 'arriving', 'assisting')
    order by r.created_at desc limit 1;
    if found then return result; end if;
    raise;
  end;
end;
$$;

revoke all on function public.create_customer_rescue_request(uuid, text, text, text, text, text, text, uuid) from public, anon;
grant execute on function public.create_customer_rescue_request(uuid, text, text, text, text, text, text, uuid) to authenticated;

commit;
