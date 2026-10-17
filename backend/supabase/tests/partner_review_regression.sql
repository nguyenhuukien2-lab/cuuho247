-- Local disposable DB only. Fixtures and mutations roll back.
begin;
set local statement_timeout='60s';
do $$ begin
  if current_setting('partner_review.test_mode',true) is distinct from 'local_disposable' then
    raise exception 'PARTNER_REVIEW_TEST_REFUSED';
  end if;
end $$;
create temp table review_results(label text primary key);
grant select,insert on review_results to authenticated,anon;
create function pg_temp.ok(label text, result boolean) returns void language plpgsql as $$
begin
  if result is distinct from true then raise exception 'TEST_FAIL: %',label; end if;
  insert into pg_temp.review_results values(label);
end $$;
create function pg_temp.denied(label text, query text, expected text) returns void language plpgsql as $$
declare actual text;
begin
  begin execute query; exception when others then get stacked diagnostics actual=returned_sqlstate; end;
  perform pg_temp.ok(label,actual=expected);
end $$;
create function pg_temp.actor(uid text) returns void language sql as $$
  select set_config('request.jwt.claim.sub',uid,true);
  select set_config('request.jwt.claims',jsonb_build_object('sub',uid,'role','authenticated','aal','aal2',
    'iat',extract(epoch from now())::bigint)::text,true);
$$;
insert into auth.users(id,email) values
 ('a1700000-0000-4000-8000-000000000001','review-partner@example.invalid'),
 ('a1700000-0000-4000-8000-000000000002','review-admin@example.invalid'),
 ('a1700000-0000-4000-8000-000000000003','review-operator@example.invalid'),
 ('a1700000-0000-4000-8000-000000000004','review-other@example.invalid');
insert into public.admin_profiles(id,full_name,role) values
 ('a1700000-0000-4000-8000-000000000002','Reviewer','partner_reviewer'),
 ('a1700000-0000-4000-8000-000000000003','Operator','operator');
insert into public.rescuer_profiles(user_id,full_name,contact_phone,verification_status) values
 ('a1700000-0000-4000-8000-000000000001','Review fixture','0900000001','approved');
insert into public.rescuer_online_status(rescuer_id) values ('a1700000-0000-4000-8000-000000000001');
insert into public.rescuer_vehicles(id,rescuer_id,kind,display_name,license_plate,verification_status) values
 ('a1700000-0000-4000-8000-000000000011','a1700000-0000-4000-8000-000000000001','service_motorbike','Test vehicle','RVTEST01','submitted');
insert into public.rescuer_service_capabilities(rescuer_id,vehicle_id,service_code,customer_vehicle_kind) values
 ('a1700000-0000-4000-8000-000000000001','a1700000-0000-4000-8000-000000000011','tire','motorbike');
insert into public.rescuer_documents(id,rescuer_id,document_type,vehicle_id,storage_path,content_type,byte_size,uploaded_at)
select id::uuid,'a1700000-0000-4000-8000-000000000001',kind,vehicle::uuid,
 'a1700000-0000-4000-8000-000000000001/'||id,'image/png',100,now()
from (values
 ('a1700000-0000-4000-8000-000000000021','identity',null),
 ('a1700000-0000-4000-8000-000000000022','license',null),
 ('a1700000-0000-4000-8000-000000000023','vehicle_registration','a1700000-0000-4000-8000-000000000011')) d(id,kind,vehicle);
insert into storage.objects(bucket_id,name,metadata)
select 'rescuer-documents',storage_path,'{"mimetype":"image/png","size":100}'::jsonb
from public.rescuer_documents where rescuer_id='a1700000-0000-4000-8000-000000000001';

set local role anon;
select pg_temp.denied('anon cannot read review','select public.admin_get_rescuer_review(gen_random_uuid())','42501');
select pg_temp.denied('anon cannot review','select public.admin_review_rescuer_document(gen_random_uuid(),''approved'',''submitted'')','42501');
reset role;
select pg_temp.actor('a1700000-0000-4000-8000-000000000001');
set local role authenticated;
select pg_temp.ok('pending documents block readiness',not (public.rescuer_get_readiness()->>'can_online')::boolean);
select pg_temp.denied('partner cannot self approve','select public.admin_review_rescuer_document(''a1700000-0000-4000-8000-000000000021'',''approved'',''submitted'')','42501');
select pg_temp.denied('partner direct document update denied','update public.rescuer_documents set verification_status=''approved''','42501');
select pg_temp.denied('partner direct vehicle update denied','update public.rescuer_vehicles set verification_status=''approved''','42501');
select pg_temp.denied('partner direct capability update denied','update public.rescuer_service_capabilities set verification_status=''approved''','42501');
select pg_temp.denied('pending cannot Online','select public.rescuer_set_online(true,''a1700000-0000-4000-8000-000000000011'',null,gen_random_uuid())','42501');
select pg_temp.ok('owner can read own objects',(select count(*)=3 from storage.objects where bucket_id='rescuer-documents' and name like 'a1700000-%'));
reset role;
select pg_temp.actor('a1700000-0000-4000-8000-000000000004');
set local role authenticated;
select pg_temp.ok('other user cannot read objects',not exists(select 1 from storage.objects where bucket_id='rescuer-documents' and name like 'a1700000-%'));
select pg_temp.denied('non-admin cannot read detail','select public.admin_get_rescuer_review(''a1700000-0000-4000-8000-000000000001'')','42501');
reset role;
select pg_temp.actor('a1700000-0000-4000-8000-000000000003');
set local role authenticated;
select pg_temp.denied('operator cannot review','select public.admin_review_rescuer_document(''a1700000-0000-4000-8000-000000000021'',''approved'',''submitted'')','42501');
select pg_temp.ok('operator cannot read objects',not exists(select 1 from storage.objects where bucket_id='rescuer-documents' and name like 'a1700000-%'));
reset role;
select pg_temp.actor('a1700000-0000-4000-8000-000000000002');
set local role authenticated;
select pg_temp.ok('reviewer can read objects',(select count(*)=3 from storage.objects where bucket_id='rescuer-documents' and name like 'a1700000-%'));
select pg_temp.ok('all uploaded documents returned',jsonb_array_length(public.admin_get_rescuer_review('a1700000-0000-4000-8000-000000000001')->'documents')=3);
select pg_temp.denied('rejection requires reason','select public.admin_review_rescuer_document(''a1700000-0000-4000-8000-000000000021'',''rejected'',''submitted'',''  '')','22023');
select public.admin_review_rescuer_document('a1700000-0000-4000-8000-000000000021','rejected','submitted','Ảnh mờ');
select pg_temp.ok('rejection reason persisted',exists(select 1 from jsonb_array_elements(
 public.admin_get_rescuer_review('a1700000-0000-4000-8000-000000000001')->'documents') d
 where d->>'verification_status'='rejected' and d->>'review_reason'='Ảnh mờ'));
select pg_temp.denied('stale document decision rejected','select public.admin_review_rescuer_document(''a1700000-0000-4000-8000-000000000021'',''approved'',''submitted'')','40001');
select public.admin_review_rescuer_document('a1700000-0000-4000-8000-000000000021','approved','rejected');
select pg_temp.ok('one approved document insufficient',not (public.admin_get_rescuer_review('a1700000-0000-4000-8000-000000000001')->'readiness'->>'can_online')::boolean);
select public.admin_review_rescuer_document('a1700000-0000-4000-8000-000000000022','approved','submitted');
select public.admin_review_rescuer_document('a1700000-0000-4000-8000-000000000023','approved','submitted');
select pg_temp.ok('documents alone insufficient',not (public.admin_get_rescuer_review('a1700000-0000-4000-8000-000000000001')->'readiness'->>'can_online')::boolean);
select public.admin_review_rescuer_vehicle('a1700000-0000-4000-8000-000000000011','approved',1);
select pg_temp.denied('stale vehicle decision rejected','select public.admin_review_rescuer_vehicle(''a1700000-0000-4000-8000-000000000011'',''rejected'',1,''Wrong'')','40001');
select public.admin_review_rescuer_capability('a1700000-0000-4000-8000-000000000011','tire','motorbike','approved',
 (public.admin_get_rescuer_review('a1700000-0000-4000-8000-000000000001')->'capabilities'->0->>'updated_at')::timestamptz);
select pg_temp.ok('all approvals make backend ready',(public.admin_get_rescuer_review('a1700000-0000-4000-8000-000000000001')->'readiness'->>'can_online')::boolean);
reset role;
select pg_temp.actor('a1700000-0000-4000-8000-000000000001');
set local role authenticated;
select pg_temp.ok('partner refresh sees backend readiness',(public.rescuer_get_readiness()->>'can_online')::boolean);
select pg_temp.ok('approval alone does not imply live availability',not (public.rescuer_get_readiness()->>'can_receive_requests')::boolean);
select pg_temp.ok('partner can Online',(public.rescuer_set_online(true,'a1700000-0000-4000-8000-000000000011',null,gen_random_uuid())->>'is_online')::boolean);
select public.rescuer_update_location((select session_id from public.rescuer_online_status),1,10.77,106.69,10,now(),gen_random_uuid());
select pg_temp.ok('online with fresh GPS can receive requests',(public.rescuer_get_readiness()->>'can_receive_requests')::boolean);
select pg_temp.ok('ready partner passes discovery gate',public.rescuer_list_available_requests('a1700000-0000-4000-8000-000000000011') ? 'items');
reset role;
-- Expiry/disabled services must revoke readiness even without another Admin action.
update public.rescuer_documents set expires_at=now()-interval '1 second' where id='a1700000-0000-4000-8000-000000000022';
set local role authenticated;
select pg_temp.ok('expired document blocks readiness',not (public.rescuer_get_readiness()->>'can_online')::boolean);
select pg_temp.denied('expired cannot Online','select public.rescuer_set_online(true,''a1700000-0000-4000-8000-000000000011'',null,gen_random_uuid())','42501');
select pg_temp.denied('expired cannot discover','select public.rescuer_list_available_requests(''a1700000-0000-4000-8000-000000000011'')','42501');
reset role;
update public.rescuer_documents set expires_at=null where id='a1700000-0000-4000-8000-000000000022';
update public.rescue_services set is_active=false where code='tire';
set local role authenticated;
select pg_temp.ok('disabled catalog service blocks readiness',not (public.rescuer_get_readiness()->>'can_online')::boolean);
reset role;
update public.rescue_services set is_active=true where code='tire';
select pg_temp.actor('a1700000-0000-4000-8000-000000000002');
set local role authenticated;
select public.admin_review_rescuer_document('a1700000-0000-4000-8000-000000000021','rejected','approved','Cần xác minh lại');
reset role;
select pg_temp.ok('rejection turns partner offline',not (select is_online from public.rescuer_online_status where rescuer_id='a1700000-0000-4000-8000-000000000001'));
select pg_temp.ok('bucket remains private',not (select public from storage.buckets where id='rescuer-documents'));
select pg_temp.ok('review audit contains no storage path',not exists(select 1 from public.admin_audit_logs
 where action like 'review_rescuer_%' and metadata::text like '%storage_path%'));
insert into public.rescue_requests(id,customer_id,client_request_id,vehicle_kind,service_code,
 location_text,location_confirmed,latitude,longitude,contact_name,contact_phone,status) values
 ('a1700000-0000-4000-8000-000000000031','a1700000-0000-4000-8000-000000000004',gen_random_uuid(),
 'motorbike','tire','Local test address',true,10.77,106.69,'Local test customer','0900000004','searching');
set local role authenticated;
select public.admin_review_rescuer_document('a1700000-0000-4000-8000-000000000021','approved','rejected');
reset role;
select pg_temp.actor('a1700000-0000-4000-8000-000000000001');
set local role authenticated;
select public.rescuer_set_online(true,'a1700000-0000-4000-8000-000000000011',null,gen_random_uuid());
select public.rescuer_update_location((select session_id from public.rescuer_online_status),1,10.77,106.69,10,now(),gen_random_uuid());
select pg_temp.ok('ready partner can claim matching request',
 public.rescuer_claim_request('a1700000-0000-4000-8000-000000000031','a1700000-0000-4000-8000-000000000011',gen_random_uuid())->>'state'='accepted');
select pg_temp.ok('busy partner cannot receive another request',not (public.rescuer_get_readiness()->>'can_receive_requests')::boolean);
reset role;
select pg_temp.actor('a1700000-0000-4000-8000-000000000002');
set local role authenticated;
select pg_temp.denied('review cannot strand active job','select public.admin_review_rescuer_document(''a1700000-0000-4000-8000-000000000021'',''rejected'',''approved'',''Review again'')','P0001');
reset role;
update public.rescuer_documents set expires_at=now()-interval '1 second' where id='a1700000-0000-4000-8000-000000000022';
select pg_temp.actor('a1700000-0000-4000-8000-000000000001');
set local role authenticated;
select pg_temp.ok('expiry during active job preserves location updates',public.rescuer_update_location(
 (select session_id from public.rescuer_online_status),2,10.77,106.69,10,now(),gen_random_uuid()) ? 'sequence');
reset role;
set constraints all immediate;
select count(*) as passed from review_results;
rollback;
