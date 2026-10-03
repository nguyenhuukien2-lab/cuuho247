-- LOCAL DISPOSABLE SUPABASE DB ONLY. Never run against a linked/remote project.
-- Requires six customer migrations + rescuer foundation and a privileged local
-- connection. All fixtures, including trusted approvals, roll back at the end.
-- psql must receive -v rescuer_local_test=1 as an explicit local-only guard.
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
insert into auth.users(id,email) values
  ('f0000000-0000-4000-8000-000000000001','rescuer-sql-test@example.invalid'),
  ('f0000000-0000-4000-8000-000000000002','customer-sql-test@example.invalid'),
  ('f0000000-0000-4000-8000-000000000003','other-sql-test@example.invalid');
insert into public.rescuer_profiles(user_id,full_name,contact_phone,verification_status) values
  ('f0000000-0000-4000-8000-000000000001','Local approved fixture','0900000001','approved'),
  ('f0000000-0000-4000-8000-000000000003','Local draft fixture','0900000003','draft');
insert into public.rescuer_online_status(rescuer_id) values('f0000000-0000-4000-8000-000000000001');
insert into public.rescuer_vehicles(id,rescuer_id,kind,display_name,license_plate,verification_status) values
  ('f0000000-0000-4000-8000-000000000011','f0000000-0000-4000-8000-000000000001',
   'service_motorbike','Local test vehicle','LOCALTEST01','approved');
insert into public.rescuer_service_capabilities(rescuer_id,vehicle_id,service_code,customer_vehicle_kind,verification_status)
  values('f0000000-0000-4000-8000-000000000001','f0000000-0000-4000-8000-000000000011','tire','motorbike','approved');
insert into public.rescue_requests(id,customer_id,client_request_id,vehicle_kind,service_code,
  location_text,location_confirmed,latitude,longitude,contact_name,contact_phone,status) values
  ('f0000000-0000-4000-8000-000000000021','f0000000-0000-4000-8000-000000000002',gen_random_uuid(),
   'motorbike','tire','PRIVATE LOCAL ADDRESS',true,10.7712,106.6923,'PRIVATE LOCAL NAME','0900000002','searching');

set local role authenticated;
select set_config('request.jwt.claim.sub','f0000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"f0000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $test$
declare v_vehicle uuid:='f0000000-0000-4000-8000-000000000011';
  v_request uuid:='f0000000-0000-4000-8000-000000000021';
  v_session uuid; v_assignment uuid; v_claim_op uuid:=gen_random_uuid(); v_status_op uuid:=gen_random_uuid();
  v_quote_op uuid:=gen_random_uuid(); v_now timestamptz:=clock_timestamp(); v_first jsonb; v_result jsonb; v_item jsonb;
begin
  if (select count(*) from public.rescuer_profiles)<>1 then raise exception 'TEST_FAIL: cross-owner profile read'; end if;
  begin
    perform 1 from public.rescue_request_assignments;
    raise exception 'TEST_FAIL: assignment table readable';
  exception when insufficient_privilege then null; end;
  begin
    update public.rescuer_profiles set verification_status='approved';
    raise exception 'TEST_FAIL: direct approval writable';
  exception when insufficient_privilege then null; end;
  if exists(select 1 from public.rescue_requests) then raise exception 'TEST_FAIL: cross-owner request read'; end if;
  v_session:=(public.rescuer_set_online(true,v_vehicle,null,gen_random_uuid())->>'session_id')::uuid;
  v_first:=public.rescuer_update_location(v_session,1,10.77,106.69,10,v_now,gen_random_uuid());
  v_result:=public.rescuer_update_location(v_session,1,10.77,106.69,10,v_now,gen_random_uuid());
  if v_result is distinct from v_first then raise exception 'TEST_FAIL: duplicate GPS changed freshness'; end if;
  begin
    perform public.rescuer_update_location(v_session,1,10.78,106.69,10,v_now,gen_random_uuid());
    raise exception 'TEST_FAIL: changed duplicate GPS accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm<>'STALE_LOCATION_SEQUENCE' then raise; end if;
  end;
  v_result:=public.rescuer_get_available_request(v_request,v_vehicle);
  if (select count(*) from jsonb_object_keys(v_result))<>5
     or v_result ?| array['contact_name','contact_phone','customer_id','location_text','description','latitude','longitude']
     or v_result->'approximate_location'->>'precision'<>'coarse' then
    raise exception 'TEST_FAIL: discovery privacy';
  end if;
  v_result:=public.rescuer_claim_request(v_request,v_vehicle,v_claim_op);
  v_assignment:=(v_result->>'assignment_id')::uuid;
  if public.rescuer_claim_request(v_request,v_vehicle,v_claim_op) is distinct from v_result then
    raise exception 'TEST_FAIL: duplicate claim';
  end if;
  begin
    perform public.rescuer_claim_request(gen_random_uuid(),v_vehicle,v_claim_op);
    raise exception 'TEST_FAIL: changed idempotency payload accepted';
  exception when invalid_parameter_value then
    if sqlerrm<>'IDEMPOTENCY_CONFLICT' then raise; end if;
  end;
  if public.rescuer_get_active_job()->>'contact_phone'<>'0900000002' then raise exception 'TEST_FAIL: active DTO'; end if;
  perform public.rescuer_set_online(false,null,v_session,gen_random_uuid());
  if public.rescuer_get_active_job() is null then raise exception 'TEST_FAIL: offline lost job'; end if;
  begin
    perform public.rescuer_update_job_status(v_assignment,'completed',null,1,gen_random_uuid());
    raise exception 'TEST_FAIL: skipped lifecycle';
  exception when invalid_parameter_value then
    if sqlerrm<>'INVALID_STATUS_TRANSITION' then raise; end if;
  end;
  perform public.rescuer_update_job_status(v_assignment,'en_route',null,1,v_status_op);
  perform public.rescuer_update_job_status(v_assignment,'en_route',null,1,v_status_op);
  begin
    perform public.rescuer_update_job_status(v_assignment,'arrived',null,1,gen_random_uuid());
    raise exception 'TEST_FAIL: stale version accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm<>'VERSION_CONFLICT' then raise; end if;
  end;
  perform public.rescuer_update_job_status(v_assignment,'arrived',null,2,gen_random_uuid());
  begin
    perform public.rescuer_create_quote(v_assignment,
      '[{"service_code":"tire","quantity":100,"unit_price_vnd":2147483647}]',null,3,gen_random_uuid());
    raise exception 'TEST_FAIL: quote overflow accepted';
  exception when invalid_parameter_value then
    if sqlerrm<>'INVALID_QUOTE' then raise; end if;
  end;
  v_item:='[{"service_code":"tire","quantity":2,"unit_price_vnd":50000}]';
  v_result:=public.rescuer_create_quote(v_assignment,v_item,'PRIVATE LOCAL NOTE',3,v_quote_op);
  if (v_result->>'total_vnd')::integer<>100000 then raise exception 'TEST_FAIL: server quote total'; end if;
  perform public.rescuer_update_job_status(v_assignment,'in_progress',null,4,gen_random_uuid());
  perform public.rescuer_update_job_status(v_assignment,'completed',null,5,gen_random_uuid());
  if public.rescuer_get_active_job() is not null then raise exception 'TEST_FAIL: terminal PII remains'; end if;
  v_result:=public.rescuer_create_quote(v_assignment,v_item,'PRIVATE LOCAL NOTE',3,v_quote_op);
  if v_result ?| array['items','note'] then raise exception 'TEST_FAIL: quote retry leaked terminal note'; end if;
  v_result:=public.rescuer_get_job_history(v_assignment);
  if v_result ?| array['contact_name','contact_phone','customer_id','location_text','description','latitude','longitude','note']
     or v_result::text like '%PRIVATE LOCAL%' then raise exception 'TEST_FAIL: history PII'; end if;
end;
$test$;
reset role;
-- Force deferred invariants before rollback so this test actually exercises them.
set constraints all immediate;

-- Separate customer-cancellation regression, using the original customer RPC.
insert into public.rescue_requests(id,customer_id,client_request_id,vehicle_kind,service_code,
  location_text,location_confirmed,latitude,longitude,contact_name,contact_phone,status) values
  ('f0000000-0000-4000-8000-000000000022','f0000000-0000-4000-8000-000000000002',gen_random_uuid(),
   'motorbike','tire','PRIVATE CANCEL ADDRESS',true,10.7712,106.6923,'PRIVATE CANCEL NAME','0900000002','searching');
set constraints all deferred;
set local role authenticated;
select set_config('request.jwt.claim.sub','f0000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"f0000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $test$
declare v_vehicle uuid:='f0000000-0000-4000-8000-000000000011'; v_session uuid;
begin
  v_session:=(public.rescuer_set_online(true,v_vehicle,null,gen_random_uuid())->>'session_id')::uuid;
  perform public.rescuer_update_location(v_session,1,10.77,106.69,10,clock_timestamp(),gen_random_uuid());
  perform public.rescuer_claim_request('f0000000-0000-4000-8000-000000000022',v_vehicle,gen_random_uuid());
end;
$test$;
select set_config('request.jwt.claim.sub','f0000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"f0000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select public.cancel_own_rescue_request('f0000000-0000-4000-8000-000000000022');
reset role;
set constraints all immediate;
do $test$
begin
  if not exists(select 1 from public.rescue_request_assignments
      where request_id='f0000000-0000-4000-8000-000000000022' and state='cancelled' and version=2
        and cancellation_reason_code='customer_cancelled') then raise exception 'TEST_FAIL: customer cancel sync'; end if;
  if (select count(*) from public.rescuer_assignment_events e join public.rescue_request_assignments a on a.id=e.assignment_id
      where a.request_id='f0000000-0000-4000-8000-000000000022' and e.event_kind='customer_cancelled')<>1 then
    raise exception 'TEST_FAIL: duplicate cancel event';
  end if;
end;
$test$;
rollback;
\echo 'PASS: local rescuer regression; fixtures rolled back.'
