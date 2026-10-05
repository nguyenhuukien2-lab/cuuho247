-- DISPOSABLE LOCAL SUPABASE ONLY; apply foundation + manual-location migration first.
-- Uses privileged local fixtures, then authenticated RPCs; everything rolls back.
-- psql -X -v ON_ERROR_STOP=1 -v rescuer_local_test=1 -f this-file.sql
\set ON_ERROR_STOP on
\if :{?rescuer_local_test}
\if :rescuer_local_test
\else
\echo 'Refusing: rescuer_local_test must be true.'
\quit 3
\endif
\else
\echo 'Refusing: specify -v rescuer_local_test=1 only for a disposable local DB.'
\quit 3
\endif

begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
insert into auth.users(id,email)
select ('f1000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
  'manual-feed-'||n||'@example.invalid'
from unnest(array[1,2,3,101,102,103,104,105,106,107,108,109,110,111]) as fixture(n);
insert into public.rescuer_profiles(user_id,full_name,contact_phone,verification_status)
select ('f1000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
  'Local manual feed rescuer '||n,'090000000'||n,
  case when n=3 then 'draft' else 'approved' end
from generate_series(1,3) as fixture(n);
insert into public.rescuer_online_status(rescuer_id)
select ('f1000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid
from generate_series(1,2) as fixture(n);
insert into public.rescuer_vehicles(id,rescuer_id,kind,display_name,license_plate,verification_status)
select ('f1000000-0000-4000-8000-'||lpad((n+10)::text,12,'0'))::uuid,
  ('f1000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
  'service_car','Local manual vehicle '||n,'MANUALTEST0'||n,'approved'
from generate_series(1,2) as fixture(n);
insert into public.rescuer_service_capabilities(
  rescuer_id,vehicle_id,service_code,customer_vehicle_kind,verification_status
)
select ('f1000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
  ('f1000000-0000-4000-8000-'||lpad((n+10)::text,12,'0'))::uuid,
  'tire','car','approved'
from generate_series(1,2) as fixture(n);

-- One searching request per customer, respecting the existing unique constraint.
insert into public.rescue_requests(
  id,customer_id,client_request_id,vehicle_kind,service_code,location_text,
  location_confirmed,latitude,longitude,contact_name,contact_phone,status,provider_id
)
select ('f1000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
  ('f1000000-0000-4000-8000-'||lpad((case when n=109 then 1 else n end)::text,12,'0'))::uuid,
  gen_random_uuid(),case when n=107 then 'motorbike' else 'car' end,
  case when n=106 then 'battery' else 'tire' end,
  case when n=110 then E'\t\n' else '03 Quang Trung' end,true,
  case when n in (101,103) then 10.7712 when n=105 then 0.0 else null end,
  case when n in (101,104) then 106.6923 when n=105 then 0.0 else null end,
  'PRIVATE CUSTOMER','0900000101',case when n=108 then 'cancelled' else 'searching' end,
  case when n=111 then 'f1000000-0000-4000-8000-000000000002'::uuid end
from generate_series(101,111) as fixture(n);

set local role authenticated;
select set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"f1000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $test$
declare
  v_vehicle uuid:='f1000000-0000-4000-8000-000000000011';
  v_manual uuid:='f1000000-0000-4000-8000-000000000102';
  v_session uuid;
  v_page jsonb;
  v_item jsonb;
  v_cursor jsonb;
  v_seen uuid[]:=array[]::uuid[];
  v_expected uuid[]:=array[
    'f1000000-0000-4000-8000-000000000101'::uuid,
    'f1000000-0000-4000-8000-000000000102'::uuid,
    'f1000000-0000-4000-8000-000000000103'::uuid,
    'f1000000-0000-4000-8000-000000000104'::uuid
  ];
  v_result jsonb;
  v_claim_op uuid:=gen_random_uuid();
begin
  -- RLS still hides requests owned by other customers, even before discovery.
  if exists(select 1 from public.rescue_requests where customer_id<>auth.uid()) then
    raise exception 'TEST_FAIL: cross-owner request read';
  end if;
  begin
    perform private.rescuer_available_rows(v_vehicle,10.77,106.69);
    raise exception 'TEST_FAIL: private helper exposed';
  exception when insufficient_privilege then null; end;
  v_session:=(public.rescuer_set_online(true,v_vehicle,null,gen_random_uuid())->>'session_id')::uuid;
  begin
    perform public.rescuer_list_available_requests(v_vehicle);
    raise exception 'TEST_FAIL: discovery without rescuer GPS accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm<>'LOCATION_NOT_FRESH' then raise; end if;
  end;
  perform public.rescuer_update_location(v_session,1,10.77,106.69,10,clock_timestamp(),gen_random_uuid());

  -- Mixed pagination: GPS cursor -> explicit NULL cursor -> remaining manual rows.
  for i in 1..4 loop
    v_page:=public.rescuer_list_available_requests(v_vehicle,1,v_cursor);
    if jsonb_array_length(v_page->'items')<>1 then
      raise exception 'TEST_FAIL: missing pagination item %',i;
    end if;
    v_item:=v_page->'items'->0;
    v_seen:=array_append(v_seen,(v_item->>'request_id')::uuid);
    if v_item ?| array['location_text','contact_name','contact_phone','customer_id','description','latitude','longitude']
       or v_item::text like '%PRIVATE CUSTOMER%' or v_item::text like '%03 Quang Trung%' then
      raise exception 'TEST_FAIL: preclaim privacy';
    end if;
    if i=1 then
      if (v_item->>'estimated_distance_km')::integer is distinct from 1
         or coalesce(abs((v_item->'approximate_location'->>'latitude')::double precision-10.775),1)>0.00000001
         or coalesce(abs((v_item->'approximate_location'->>'longitude')::double precision-106.695),1)>0.00000001 then
        raise exception 'TEST_FAIL: real GPS estimate';
      end if;
    else
      if v_item->'estimated_distance_km' is distinct from 'null'::jsonb
         or v_item->'approximate_location'->'latitude' is distinct from 'null'::jsonb
         or v_item->'approximate_location'->'longitude' is distinct from 'null'::jsonb then
        raise exception 'TEST_FAIL: fake manual coordinates/distance';
      end if;
    end if;
    v_cursor:=nullif(v_page->'next_cursor','null'::jsonb);
    if i in (2,3) and (v_cursor is null or v_cursor->'distance_km' is distinct from 'null'::jsonb) then
      raise exception 'TEST_FAIL: manual cursor lost';
    end if;
  end loop;
  if v_seen is distinct from v_expected or v_cursor is not null then
    raise exception 'TEST_FAIL: pagination ordering/duplicates/filtering';
  end if;
  -- Far GPS, service/vehicle mismatch, cancelled, own, blank and provider-set rows excluded.
  v_page:=public.rescuer_list_available_requests(v_vehicle);
  if jsonb_array_length(v_page->'items')<>4 then raise exception 'TEST_FAIL: feed filters'; end if;
  v_cursor:=jsonb_build_object('session_id',v_session,'sequence',1,'request_id',v_manual,'distance_km',null);
  begin
    perform public.rescuer_list_available_requests(v_vehicle,1,v_cursor-'distance_km');
    raise exception 'TEST_FAIL: missing distance cursor accepted';
  exception when invalid_parameter_value then
    if sqlerrm<>'INVALID_CURSOR' then raise; end if;
  end;
  begin
    perform public.rescuer_list_available_requests(v_vehicle,1,v_cursor||jsonb_build_object('sequence',2));
    raise exception 'TEST_FAIL: stale cursor accepted';
  exception when invalid_parameter_value then
    if sqlerrm<>'INVALID_CURSOR' then raise; end if;
  end;

  v_item:=public.rescuer_get_available_request(v_manual,v_vehicle);
  if v_item->'estimated_distance_km' is distinct from 'null'::jsonb then
    raise exception 'TEST_FAIL: manual preview distance';
  end if;
  v_result:=public.rescuer_claim_request(v_manual,v_vehicle,v_claim_op);
  if v_result->>'state'<>'accepted' then raise exception 'TEST_FAIL: manual claim'; end if;
  if public.rescuer_claim_request(v_manual,v_vehicle,v_claim_op) is distinct from v_result then
    raise exception 'TEST_FAIL: duplicate manual claim';
  end if;
  v_result:=public.rescuer_get_active_job();
  if v_result->>'location_text' is distinct from '03 Quang Trung'
     or v_result->'latitude' is distinct from 'null'::jsonb
     or v_result->'longitude' is distinct from 'null'::jsonb then
    raise exception 'TEST_FAIL: manual active job';
  end if;
  begin
    perform public.rescuer_list_available_requests(v_vehicle);
    raise exception 'TEST_FAIL: busy rescuer discovery allowed';
  exception when sqlstate 'P0001' then
    if sqlerrm<>'RESCUER_BUSY' then raise; end if;
  end;
end;
$test$;
reset role;
set constraints all immediate;

-- A second approved rescuer cannot rediscover or claim the already-assigned row.
set local role authenticated;
select set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"f1000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $test$
declare v_vehicle uuid:='f1000000-0000-4000-8000-000000000012'; v_session uuid; v_page jsonb;
begin
  v_session:=(public.rescuer_set_online(true,v_vehicle,null,gen_random_uuid())->>'session_id')::uuid;
  perform public.rescuer_update_location(v_session,1,10.77,106.69,10,clock_timestamp(),gen_random_uuid());
  v_page:=public.rescuer_list_available_requests(v_vehicle);
  if exists(select 1 from jsonb_array_elements(v_page->'items') as item
      where item->>'request_id'='f1000000-0000-4000-8000-000000000102') then
    raise exception 'TEST_FAIL: assigned request still discoverable';
  end if;
  begin
    perform public.rescuer_claim_request('f1000000-0000-4000-8000-000000000102',v_vehicle,gen_random_uuid());
    raise exception 'TEST_FAIL: second rescuer claim accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm<>'REQUEST_UNAVAILABLE' then raise; end if;
  end;
  perform public.rescuer_set_online(false,null,v_session,gen_random_uuid());
  begin
    perform public.rescuer_claim_request('f1000000-0000-4000-8000-000000000103',v_vehicle,gen_random_uuid());
    raise exception 'TEST_FAIL: offline manual claim accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm<>'LOCATION_NOT_FRESH' then raise; end if;
  end;
end;
$test$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"f1000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
do $test$
begin
  begin
    perform public.rescuer_list_available_requests('f1000000-0000-4000-8000-000000000011');
    raise exception 'TEST_FAIL: draft rescuer discovery accepted';
  exception when insufficient_privilege then
    if sqlerrm<>'PROFILE_NOT_READY' then raise; end if;
  end;
end;
$test$;
reset role;
set constraints all immediate;
rollback;
\echo 'PASS: manual-location feed/preview/claim, pagination, privacy and eligibility; rolled back.'
