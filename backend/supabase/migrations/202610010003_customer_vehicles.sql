-- Expand customer vehicles; existing owner-only CRUD policies stay in force.
-- Apply after customer profiles, tracking and request photos migrations.
begin;

alter table public.customer_vehicles drop constraint customer_vehicles_kind_check;
alter table public.customer_vehicles add constraint customer_vehicles_kind_check
  check (kind in ('motorbike', 'car', 'truck', 'other'));
alter table public.customer_vehicles
  add column color text check (color is null or length(color) <= 50),
  add column notes text check (notes is null or length(notes) <= 1000);
-- display_name stores the brand/model label; preserve existing vehicle data.
alter table public.rescue_requests drop constraint rescue_requests_vehicle_kind_check;
alter table public.rescue_requests add constraint rescue_requests_vehicle_kind_check
  check (vehicle_kind in ('motorbike', 'car', 'truck', 'other'));

-- Keep the signature/permissions and all idempotency, contact, location and
-- service checks. Lock the owned vehicle until its type is saved on the request.
create or replace function public.create_customer_rescue_request(
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
  saved_vehicle_kind text;
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

  if p_vehicle_id is not null then
    select v.kind into saved_vehicle_kind from public.customer_vehicles v
    where v.id = p_vehicle_id and v.customer_id = caller_id for share;
    if not found then
      raise exception 'VEHICLE_NOT_OWNED' using errcode = '42501';
    end if;
    p_vehicle_kind := saved_vehicle_kind;
  end if;

  if p_vehicle_kind is null or p_vehicle_kind not in ('motorbike', 'car', 'truck', 'other') then
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


commit;
