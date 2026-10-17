-- Audited against linked project 2026-10-17. Local source only; no new tables/buckets.
begin;
set local lock_timeout='5s';

-- One derived checklist, shared by Admin, the partner and the Online/discovery gate.
create function private.rescuer_review_readiness(p_uid uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  with personal as (
    select coalesce((select verification_status='approved' from public.rescuer_profiles where user_id=p_uid),false) as profile_approved,
      exists(select 1 from public.rescuer_documents where rescuer_id=p_uid and document_type='identity'
        and uploaded_at is not null and verification_status='approved' and (expires_at is null or expires_at>now())) as identity_approved,
      exists(select 1 from public.rescuer_documents where rescuer_id=p_uid and document_type='license'
        and uploaded_at is not null and verification_status='approved' and (expires_at is null or expires_at>now())) as license_approved
  ), vehicles as (
    select v.id as vehicle_id, v.is_active and v.verification_status='approved' as vehicle_approved,
      exists(select 1 from public.rescuer_documents d where d.rescuer_id=p_uid and d.vehicle_id=v.id
        and d.document_type='vehicle_registration' and d.uploaded_at is not null and d.verification_status='approved'
        and (d.expires_at is null or d.expires_at>now())) as registration_approved,
      exists(select 1 from public.rescuer_service_capabilities c join public.rescue_services s on s.code=c.service_code
        where c.rescuer_id=p_uid and c.vehicle_id=v.id and c.is_enabled and c.verification_status='approved'
          and s.is_active) as service_approved
    from public.rescuer_vehicles v where v.rescuer_id=p_uid
  ), evaluated as (
    select v.*, p.profile_approved and p.identity_approved and p.license_approved
      and v.vehicle_approved and v.registration_approved and v.service_approved as ready
    from vehicles v cross join personal p
  ) select to_jsonb(p) || jsonb_build_object(
    'checked_at',now(),'can_online',exists(select 1 from evaluated where ready)
      and not (private.system_value('rescuer.maintenance'))::boolean and (private.system_value('rescuer.online_enabled'))::boolean,
    'can_receive_requests',not private.rescuer_busy(p_uid)
      and not (private.system_value('rescuer.maintenance'))::boolean and not (private.system_value('security.kill_new_jobs'))::boolean and exists(
      select 1 from evaluated e join public.rescuer_online_status o on o.rescuer_id=p_uid and o.vehicle_id=e.vehicle_id
      join public.rescuer_locations l on l.rescuer_id=p_uid and l.session_id=o.session_id
      where e.ready and o.is_online and o.last_seen_at>=now()-interval '120 seconds'
        and l.received_at>=now()-interval '120 seconds' and l.captured_at>=now()-interval '120 seconds' and l.accuracy_m<=100),
    'eligible_vehicle_ids',coalesce((select jsonb_agg(vehicle_id order by vehicle_id) from evaluated where ready),'[]'::jsonb),
    'vehicles',coalesce((select jsonb_agg(e order by e.vehicle_id) from evaluated e),'[]'::jsonb))
  from personal p;
$$;

create function public.rescuer_get_readiness() returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  perform private.system_require_session();
  return private.rescuer_review_readiness(private.rescuer_auth());
end;
$$;

create function public.admin_get_rescuer_review(p_rescuer_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  perform private.system_require_session();
  perform private.admin_require_role(array['super_admin','partner_reviewer']);
  if not exists(select 1 from public.rescuer_profiles where user_id=p_rescuer_id) then
    raise exception 'ADMIN_RESCUER_NOT_FOUND' using errcode='P0002';
  end if;
  return jsonb_build_object(
    'readiness',private.rescuer_review_readiness(p_rescuer_id),
    'documents',coalesce((select jsonb_agg(to_jsonb(d) || jsonb_build_object('review_reason',(
      select a.metadata->>'reason' from public.admin_audit_logs a
      where a.target_table='rescuer_documents' and a.target_id=d.document_id and a.action='review_rescuer_document'
      order by a.created_at desc,a.id desc limit 1)) order by d.created_at,d.document_id)
      from public.admin_rescuer_documents_view d where d.rescuer_id=p_rescuer_id),'[]'::jsonb),
    'vehicles',coalesce((select jsonb_agg(v order by v.created_at,v.id) from public.rescuer_vehicles v
      where v.rescuer_id=p_rescuer_id),'[]'::jsonb),
    'capabilities',coalesce((select jsonb_agg(to_jsonb(c) || jsonb_build_object('service_name',s.name,'service_active',s.is_active)
      order by c.vehicle_id,c.service_code,c.customer_vehicle_kind)
      from public.rescuer_service_capabilities c join public.rescue_services s on s.code=c.service_code
      where c.rescuer_id=p_rescuer_id),'[]'::jsonb));
end;
$$;

-- Match the existing partner mutation lock order; never strand an active job.
create function private.admin_lock_rescuer_review(p_uid uuid,p_status text,p_reason text) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform private.system_require_session();
  perform private.admin_require_role(array['super_admin','partner_reviewer']);
  if p_status is null or p_status not in ('approved','rejected') then
    raise exception 'ADMIN_INVALID_REVIEW_STATUS' using errcode='22023';
  end if;
  if p_status='rejected' and (p_reason is null or length(btrim(p_reason)) not between 1 and 2000) then
    raise exception 'ADMIN_REASON_REQUIRED' using errcode='22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('rescuer:'||p_uid::text,0));
  perform 1 from public.rescuer_profiles where user_id=p_uid for update;
  if not found then raise exception 'ADMIN_RESCUER_NOT_FOUND' using errcode='P0002'; end if;
  if private.rescuer_busy(p_uid) then raise exception 'ADMIN_RESCUER_BUSY' using errcode='P0001'; end if;
end;
$$;

create function public.admin_review_rescuer_document(p_document_id uuid,p_status text,p_expected_status text,p_reason text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_d public.rescuer_documents; v_uid uuid;
begin
  perform private.system_require_session();
  perform private.admin_require_role(array['super_admin','partner_reviewer']);
  select rescuer_id into v_uid from public.rescuer_documents where id=p_document_id;
  perform private.admin_lock_rescuer_review(v_uid,p_status,p_reason);
  select * into v_d from public.rescuer_documents where id=p_document_id for update;
  if not found then raise exception 'ADMIN_DOCUMENT_NOT_FOUND' using errcode='P0002'; end if;
  if v_d.verification_status is distinct from p_expected_status then
    raise exception 'ADMIN_REVIEW_CONFLICT' using errcode='40001';
  end if;
  if v_d.uploaded_at is null then raise exception 'DOCUMENT_NOT_READY' using errcode='22023'; end if;
  if p_status='approved' and (v_d.verification_status='expired' or v_d.expires_at<=now() or not exists(
    select 1 from storage.objects where bucket_id='rescuer-documents' and name=v_d.storage_path)) then
    raise exception 'DOCUMENT_NOT_READY' using errcode='22023';
  end if;
  if v_d.verification_status=p_status then
    return jsonb_build_object('success',true,'changed',false,'message','Giấy tờ đã có trạng thái này');
  end if;
  update public.rescuer_documents set verification_status=p_status where id=p_document_id;
  if p_status='rejected' then update public.rescuer_online_status set is_online=false where rescuer_id=v_uid; end if;
  perform public.admin_log_action('review_rescuer_document','rescuer_documents',p_document_id,
    jsonb_build_object('rescuer_id',v_uid,'before',v_d.verification_status,'after',p_status,'reason',nullif(btrim(p_reason),'')));
  return jsonb_build_object('success',true,'changed',true,'message','Đã cập nhật kiểm duyệt giấy tờ');
end;
$$;

create function public.admin_review_rescuer_vehicle(p_vehicle_id uuid,p_status text,p_expected_version bigint,p_reason text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_v public.rescuer_vehicles; v_uid uuid;
begin
  perform private.system_require_session();
  perform private.admin_require_role(array['super_admin','partner_reviewer']);
  select rescuer_id into v_uid from public.rescuer_vehicles where id=p_vehicle_id;
  perform private.admin_lock_rescuer_review(v_uid,p_status,p_reason);
  select * into v_v from public.rescuer_vehicles where id=p_vehicle_id for update;
  if not found then raise exception 'ADMIN_VEHICLE_NOT_FOUND' using errcode='P0002'; end if;
  if v_v.version is distinct from p_expected_version then raise exception 'ADMIN_REVIEW_CONFLICT' using errcode='40001'; end if;
  if v_v.verification_status=p_status then
    return jsonb_build_object('success',true,'changed',false,'message','Xe đã có trạng thái này');
  end if;
  if p_status='approved' and (not v_v.is_active or v_v.verification_status not in ('submitted','rejected')) then
    raise exception 'VEHICLE_NOT_READY' using errcode='22023';
  end if;
  update public.rescuer_vehicles set verification_status=p_status,version=version+1 where id=p_vehicle_id;
  if p_status='rejected' then update public.rescuer_online_status set is_online=false where rescuer_id=v_uid; end if;
  perform public.admin_log_action('review_rescuer_vehicle','rescuer_vehicles',p_vehicle_id,
    jsonb_build_object('rescuer_id',v_uid,'before',v_v.verification_status,'after',p_status,'reason',nullif(btrim(p_reason),''),
      'before_version',v_v.version,'after_version',v_v.version+1));
  return jsonb_build_object('success',true,'changed',true,'message','Đã cập nhật kiểm duyệt xe');
end;
$$;

create function public.admin_review_rescuer_capability(p_vehicle_id uuid,p_service_code text,p_customer_vehicle_kind text,
  p_status text,p_expected_updated_at timestamptz,p_reason text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_c public.rescuer_service_capabilities; v_uid uuid;
begin
  perform private.system_require_session();
  perform private.admin_require_role(array['super_admin','partner_reviewer']);
  select rescuer_id into v_uid from public.rescuer_vehicles where id=p_vehicle_id;
  perform private.admin_lock_rescuer_review(v_uid,p_status,p_reason);
  select * into v_c from public.rescuer_service_capabilities where vehicle_id=p_vehicle_id
    and service_code=p_service_code and customer_vehicle_kind=p_customer_vehicle_kind for update;
  if not found then raise exception 'ADMIN_CAPABILITY_NOT_FOUND' using errcode='P0002'; end if;
  if v_c.updated_at is distinct from p_expected_updated_at then raise exception 'ADMIN_REVIEW_CONFLICT' using errcode='40001'; end if;
  if v_c.verification_status=p_status then
    return jsonb_build_object('success',true,'changed',false,'message','Dịch vụ đã có trạng thái này');
  end if;
  if p_status='approved' and (not v_c.is_enabled or v_c.verification_status not in ('submitted','rejected')
    or not exists(select 1 from public.rescue_services where code=p_service_code and is_active)) then
    raise exception 'SERVICE_NOT_READY' using errcode='22023';
  end if;
  update public.rescuer_service_capabilities set verification_status=p_status where vehicle_id=p_vehicle_id
    and service_code=p_service_code and customer_vehicle_kind=p_customer_vehicle_kind;
  if p_status='rejected' then update public.rescuer_online_status set is_online=false where rescuer_id=v_uid; end if;
  perform public.admin_log_action('review_rescuer_capability','rescuer_service_capabilities',p_vehicle_id,
    jsonb_build_object('rescuer_id',v_uid,'service_code',p_service_code,'customer_vehicle_kind',p_customer_vehicle_kind,
      'before',v_c.verification_status,'after',p_status,'reason',nullif(btrim(p_reason),'')));
  return jsonb_build_object('success',true,'changed',true,'message','Đã cập nhật kiểm duyệt dịch vụ');
end;
$$;

-- Keep ongoing-job location updates available if a document expires mid-job.
-- New Online/discovery/claim operations use the derived approval checklist.
create or replace function private.rescuer_require_vehicle(p_vehicle_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform private.rescuer_require_profile(true);
  if not exists(select 1 from public.rescuer_vehicles where id=p_vehicle_id and rescuer_id=auth.uid()
      and verification_status='approved' and is_active) then
    raise exception 'VEHICLE_NOT_READY' using errcode='42501';
  end if;
  if not exists(select 1 from public.rescue_request_assignments where rescuer_id=auth.uid()
      and vehicle_id=p_vehicle_id and state in ('accepted','en_route','arrived','in_progress'))
    and not ((private.rescuer_review_readiness(auth.uid())->'eligible_vehicle_ids') ? p_vehicle_id::text) then
    raise exception 'RESCUER_REVIEW_NOT_READY' using errcode='42501';
  end if;
end;
$$;

-- Owners keep their existing read/upload rights. Only reviewers can read other
-- partners' uploaded documents. No write grants, public bucket or service key in UI.
create function public.admin_can_read_rescuer_document(p_path text) returns boolean
language sql stable security definer set search_path='' as $$
  select public.system_session_allowed() and public.has_admin_role(array['super_admin','partner_reviewer'])
    and exists(select 1 from public.rescuer_documents where storage_path=p_path and uploaded_at is not null);
$$;
create policy admin_rescuer_document_object_read on storage.objects for select to authenticated
  using(bucket_id='rescuer-documents' and public.admin_can_read_rescuer_document(name));
alter policy rescuer_document_guard_read on storage.objects
  using(bucket_id<>'rescuer-documents' or exists(select 1 from public.rescuer_documents d
    where d.storage_path=name and d.rescuer_id=(select auth.uid())) or public.admin_can_read_rescuer_document(name));

revoke all on function private.rescuer_review_readiness(uuid),private.admin_lock_rescuer_review(uuid,text,text),
  private.rescuer_require_vehicle(uuid),public.rescuer_get_readiness(),public.admin_get_rescuer_review(uuid),
  public.admin_review_rescuer_document(uuid,text,text,text),public.admin_review_rescuer_vehicle(uuid,text,bigint,text),
  public.admin_review_rescuer_capability(uuid,text,text,text,timestamptz,text),public.admin_can_read_rescuer_document(text)
  from public,anon,authenticated;
grant execute on function public.rescuer_get_readiness(),public.admin_get_rescuer_review(uuid),
  public.admin_review_rescuer_document(uuid,text,text,text),public.admin_review_rescuer_vehicle(uuid,text,bigint,text),
  public.admin_review_rescuer_capability(uuid,text,text,text,timestamptz,text),public.admin_can_read_rescuer_document(text)
  to authenticated;
notify pgrst,'reload schema';
commit;
