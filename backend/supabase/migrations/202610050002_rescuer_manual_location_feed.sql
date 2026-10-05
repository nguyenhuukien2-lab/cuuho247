-- Forward-only fix: keep the original migration and discovery/claim authorization.
begin;

-- Used by list, preview and claim RPCs. Never expose the entered address here.
create or replace function private.rescuer_available_rows(
  p_vehicle_id uuid, p_lat double precision, p_lon double precision
)
returns table(
  request_id uuid, latitude double precision, longitude double precision,
  service_type text, vehicle_type text, distance_km integer
)
language sql stable security definer set search_path='' as $$
  with eligible as (
    select r.id, r.service_code, r.vehicle_kind,
      (r.latitude is not null and r.longitude is not null) as has_gps,
      -- PostgreSQL LEAST ignores NULL; guard both coordinates explicitly.
      case when r.latitude is not null and r.longitude is not null
        then least(89.995, floor(r.latitude/0.01)*0.01+0.005) end as lat,
      case when r.latitude is not null and r.longitude is not null
        then least(179.995, floor(r.longitude/0.01)*0.01+0.005) end as lon
    from public.rescue_requests r
    join public.rescue_services s on s.code=r.service_code and s.is_active
    where r.status='searching' and r.provider_id is null and r.customer_id<>auth.uid()
      and (
        (r.latitude is not null and r.longitude is not null)
        or nullif(btrim(r.location_text, E' \t\n\r'), '') is not null
      )
      and not exists(
        select 1 from public.rescue_request_assignments a where a.request_id=r.id
      )
      and exists(
        select 1 from public.rescuer_service_capabilities c
        where c.rescuer_id=auth.uid() and c.vehicle_id=p_vehicle_id
          and c.service_code=r.service_code and c.customer_vehicle_kind=r.vehicle_kind
          and c.verification_status='approved' and c.is_enabled
      )
  ), distances as (
    select *, case when has_gps and p_lat is not null and p_lon is not null then
      6371.0*2*asin(sqrt(least(1.0, greatest(0.0,
        power(sin(radians(lat-p_lat)/2), 2)
        + cos(radians(p_lat))*cos(radians(lat))*power(sin(radians(lon-p_lon)/2), 2)
      )))) end as km
    from eligible
  )
  select id, lat, lon, service_code, vehicle_kind, round(km)::integer
  from distances
  where (has_gps and km<=30) or not has_gps;
$$;

-- NULL distances sort last. Existing numeric cursors continue to work;
-- manual cursors contain an explicit JSON null, never a made-up distance.
create or replace function public.rescuer_list_available_requests(
  p_vehicle_id uuid, p_limit integer default 20, p_cursor jsonb default null
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_l public.rescuer_locations;
  v_id uuid;
  v_distance integer;
  v_row record;
  v_items jsonb:='[]';
  v_next jsonb;
  v_count integer:=0;
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception 'INVALID_LIMIT' using errcode='22023';
  end if;
  -- Retains approved profile/vehicle, idle, online, fresh GPS and rate limiting.
  v_l:=private.rescuer_discovery_context(p_vehicle_id);
  if p_cursor is not null then
    begin
      if jsonb_typeof(p_cursor)<>'object'
         or (p_cursor->>'session_id')::uuid is distinct from v_l.session_id
         or (p_cursor->>'sequence')::bigint is distinct from v_l.sequence
         or not (p_cursor ? 'distance_km')
         or jsonb_typeof(p_cursor->'distance_km') not in ('number','null') then
        raise exception 'INVALID_CURSOR' using errcode='22023';
      end if;
      v_id:=(p_cursor->>'request_id')::uuid;
      v_distance:=(p_cursor->>'distance_km')::integer;
      if v_id is null or (v_distance is not null and v_distance not between 0 and 30) then
        raise exception 'INVALID_CURSOR' using errcode='22023';
      end if;
    exception when invalid_text_representation or numeric_value_out_of_range then
      raise exception 'INVALID_CURSOR' using errcode='22023';
    end;
  end if;

  for v_row in
    select * from private.rescuer_available_rows(p_vehicle_id, v_l.latitude, v_l.longitude)
    where v_id is null
      or (v_distance is not null and (
        distance_km is null or (distance_km, request_id)>(v_distance, v_id)
      ))
      or (v_distance is null and distance_km is null and request_id>v_id)
    order by distance_km asc nulls last, request_id
    limit p_limit+1
  loop
    v_count:=v_count+1;
    if v_count>p_limit then
      return jsonb_build_object('items', v_items, 'next_cursor', v_next);
    end if;
    -- Preserve the installed DTO (including any public-code enrichment).
    v_items:=v_items || jsonb_build_array(private.rescuer_available_dto(
      v_row.request_id, v_row.latitude, v_row.longitude,
      v_row.service_type, v_row.vehicle_type, v_row.distance_km
    ));
    v_next:=jsonb_build_object(
      'session_id', v_l.session_id, 'sequence', v_l.sequence,
      'request_id', v_row.request_id, 'distance_km', v_row.distance_km
    );
  end loop;
  return jsonb_build_object('items', v_items, 'next_cursor', null);
end;
$$;

-- CREATE OR REPLACE preserves existing ACLs; keep the helper private explicitly.
revoke all on function private.rescuer_available_rows(uuid,double precision,double precision)
  from public, anon, authenticated;
notify pgrst, 'reload schema';
commit;
