-- Admin foundation for the seven shared migrations through 202610020001.
-- Local source only. Apply once with the trusted migration role after review.
-- Existing app tables/columns/statuses/triggers are not replaced.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
declare v_name text;
begin
  foreach v_name in array array[
    'auth.users','public.customer_profiles','public.customer_vehicles',
    'public.customer_saved_addresses','public.customer_request_reviews',
    'public.rescue_services','public.rescue_requests','public.request_status_events',
    'public.rescuer_profiles','public.rescuer_vehicles','public.rescuer_service_capabilities',
    'public.rescuer_online_status','public.rescue_request_assignments','public.rescue_quotes'
  ] loop
    if to_regclass(v_name) is null then
      raise exception 'ADMIN_SCHEMA_MISMATCH: missing prerequisite %', v_name;
    end if;
  end loop;
  if to_regprocedure('auth.uid()') is null
     or to_regprocedure('private.rescuer_busy(uuid)') is null then
    raise exception 'ADMIN_SCHEMA_MISMATCH: shared Auth/rescuer functions missing';
  end if;
  foreach v_name in array array['admin_profiles','admin_audit_logs','admin_notifications','admin_service_catalog'] loop
    if to_regclass('public.' || v_name) is not null then
      raise exception 'ADMIN_OBJECT_ALREADY_EXISTS: %. Review instead of overwriting.', v_name;
    end if;
  end loop;
  if to_regprocedure('public.is_admin()') is not null
     or to_regprocedure('public.has_admin_role(text[])') is not null
     or exists(select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
       where n.nspname in ('public','private') and p.proname like 'admin\_%' escape '\') then
    raise exception 'ADMIN_FUNCTION_ALREADY_EXISTS: review conflicting functions';
  end if;
  if not exists(select 1 from information_schema.columns
      where table_schema='public' and table_name='rescuer_profiles' and column_name='verification_status' and data_type='text')
     or not exists(select 1 from information_schema.columns
      where table_schema='public' and table_name='rescue_quotes' and column_name='total_vnd' and data_type='integer')
     or not exists(select 1 from information_schema.columns
      where table_schema='public' and table_name='rescue_services' and column_name='code' and data_type='text') then
    raise exception 'ADMIN_SCHEMA_MISMATCH: expected verification_status / total_vnd / code';
  end if;
  if not exists(select 1 from pg_catalog.pg_trigger
      where tgrelid='public.rescue_requests'::regclass and tgname='cuuho247_request_status_event' and tgenabled='O')
     or not exists(select 1 from pg_catalog.pg_trigger
      where tgrelid='public.rescue_requests'::regclass and tgname='rescuer_customer_cancel' and tgenabled='O') then
    raise exception 'ADMIN_SCHEMA_MISMATCH: required request event/cancellation triggers missing';
  end if;
end;
$preflight$;

-- gen_random_uuid() is built into supported PostgreSQL; pgcrypto already exists
-- in the shared foundation. No additional extension is required here.
create table public.admin_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (length(btrim(full_name)) between 1 and 150),
  role text not null default 'operator'
    check (role in ('super_admin','operator','support','partner_reviewer','finance')),
  status text not null default 'active' check (status in ('active','blocked')),
  phone text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references auth.users(id) on delete set null,
  action text not null check (length(btrim(action)) between 1 and 100),
  target_table text,
  target_id uuid,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  ip_address text,
  user_agent text,
  created_at timestamptz not null default now()
);
create index admin_audit_time_idx on public.admin_audit_logs(created_at desc, id);
create index admin_audit_actor_time_idx on public.admin_audit_logs(admin_id, created_at desc);
create index admin_audit_target_idx on public.admin_audit_logs(target_table, target_id);
create table public.admin_notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(btrim(title)) between 1 and 200),
  body text not null check (length(btrim(body)) between 1 and 5000),
  target_type text not null check (target_type in ('all','customers','rescuers','single_customer','single_rescuer')),
  priority text not null default 'normal' check (priority in ('low','normal','high','emergency')),
  -- A single-recipient message must carry an actual target identity.
  target_user_id uuid references auth.users(id) on delete restrict,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  check ((target_type in ('single_customer','single_rescuer')) = (target_user_id is not null))
);
create index admin_notification_time_idx on public.admin_notifications(created_at desc, id);

-- The existing rescue_services has TEXT PK code and is referenced by both apps.
-- Keep it unchanged. This Admin-owned extension supplies UUID IDs and metadata.
create table public.admin_service_catalog (
  id uuid primary key default gen_random_uuid(),
  service_code text not null unique references public.rescue_services(code) on delete restrict,
  admin_code text not null unique,
  description text,
  icon text,
  base_price numeric(14,2) check (base_price is null or base_price >= 0),
  price_unit text,
  is_featured boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and exists(
    select 1 from public.admin_profiles a where a.id=auth.uid() and a.status='active'
  );
$$;
create function public.has_admin_role(required_roles text[]) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and exists(
    select 1 from public.admin_profiles a
    where a.id=auth.uid() and a.status='active' and a.role=any(required_roles)
  );
$$;

-- Internal role gate: lock the caller membership for the duration of mutations.
-- A concurrent demotion/block must wait rather than authorize a stale mutation.
create function private.admin_require_role(p_roles text[]) returns void
language plpgsql security definer set search_path = public as $$
declare v_role text; v_status text;
begin
  select a.role,a.status into v_role,v_status from public.admin_profiles a
    where a.id=auth.uid() for share;
  if not found or v_status<>'active' or not coalesce(v_role=any(p_roles),false) then
    raise exception 'ADMIN_FORBIDDEN' using errcode='42501';
  end if;
end;
$$;

create function public.admin_log_action(
  p_action text, p_target_table text default null, p_target_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'ADMIN_FORBIDDEN' using errcode='42501'; end if;
  if p_action is null or length(btrim(p_action)) not between 1 and 100
     or p_metadata is null or jsonb_typeof(p_metadata)<>'object' then
    raise exception 'ADMIN_INVALID_AUDIT_DATA' using errcode='22023';
  end if;
  insert into public.admin_audit_logs(admin_id,action,target_table,target_id,metadata)
    values(auth.uid(),p_action,p_target_table,p_target_id,
      p_metadata || jsonb_build_object('actor_id',auth.uid()));
end;
$$;

-- Triggers below are only on new Admin-owned tables.
create function private.admin_profile_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then
    perform private.admin_require_role(array['super_admin']);
    if tg_op='UPDATE' and old.id=auth.uid()
       and (new.role is distinct from old.role or new.status is distinct from old.status) then
      raise exception 'ADMIN_CANNOT_CHANGE_OWN_ACCESS' using errcode='22023';
    end if;
  end if;
  if tg_op='UPDATE' and (new.id is distinct from old.id or new.created_at is distinct from old.created_at) then
    raise exception 'ADMIN_PROFILE_IDENTITY_IMMUTABLE' using errcode='22023';
  end if;
  new.full_name:=btrim(new.full_name);
  new.updated_at:=clock_timestamp();
  return new;
end;
$$;
create function private.admin_profile_audit() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_before jsonb := '{}'::jsonb;
begin
  if tg_op='UPDATE' then v_before:=jsonb_build_object('role',old.role,'status',old.status); end if;
  -- Trusted SQL bootstrap has no JWT; record a NULL actor, not a forged admin ID.
  insert into public.admin_audit_logs(admin_id,action,target_table,target_id,metadata)
    values(auth.uid(),case tg_op when 'INSERT' then 'create_admin_profile' else 'update_admin_profile' end,
      'admin_profiles',new.id,jsonb_build_object(
        'before',v_before,'after',jsonb_build_object('role',new.role,'status',new.status),
        'source',case when auth.uid() is null then 'trusted_sql' else 'authenticated_admin' end));
  return new;
end;
$$;
create trigger admin_profile_guard before insert or update on public.admin_profiles
  for each row execute function private.admin_profile_guard();
create trigger admin_profile_audit after insert or update on public.admin_profiles
  for each row execute function private.admin_profile_audit();

create function private.admin_notification_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform private.admin_require_role(array['super_admin','operator','support']);
  new.created_by:=auth.uid();
  new.created_at:=clock_timestamp();
  new.title:=btrim(new.title);
  new.body:=btrim(new.body);
  if new.target_type='single_customer' and not exists(
    select 1 from public.customer_profiles c where c.user_id=new.target_user_id
  ) then raise exception 'ADMIN_CUSTOMER_NOT_FOUND' using errcode='P0002'; end if;
  if new.target_type='single_rescuer' and not exists(
    select 1 from public.rescuer_profiles r where r.user_id=new.target_user_id
  ) then raise exception 'ADMIN_RESCUER_NOT_FOUND' using errcode='P0002'; end if;
  return new;
end;
$$;
create function private.admin_notification_audit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.admin_log_action('send_notification','admin_notifications',new.id,
    jsonb_build_object('target_type',new.target_type,'target_user_id',new.target_user_id,'priority',new.priority));
  return new;
end;
$$;
create trigger admin_notification_guard before insert on public.admin_notifications
  for each row execute function private.admin_notification_guard();
create trigger admin_notification_audit after insert on public.admin_notifications
  for each row execute function private.admin_notification_audit();

create function private.admin_catalog_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.id is distinct from old.id or new.service_code is distinct from old.service_code
     or new.admin_code is distinct from old.admin_code or new.created_at is distinct from old.created_at then
    raise exception 'ADMIN_SERVICE_IDENTITY_IMMUTABLE' using errcode='22023';
  end if;
  new.updated_at:=clock_timestamp();
  return new;
end;
$$;
create function private.admin_catalog_audit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then
    perform public.admin_log_action('update_system_setting','admin_service_catalog',new.id,
      jsonb_build_object('scope','service_metadata','service_code',new.service_code,
        'before',to_jsonb(old)-'updated_at','after',to_jsonb(new)-'updated_at'));
  end if;
  return new;
end;
$$;
create trigger admin_catalog_guard before update on public.admin_service_catalog
  for each row execute function private.admin_catalog_guard();
create trigger admin_catalog_audit after update on public.admin_service_catalog
  for each row execute function private.admin_catalog_audit();

alter table public.admin_profiles enable row level security;
alter table public.admin_audit_logs enable row level security;
alter table public.admin_notifications enable row level security;
alter table public.admin_service_catalog enable row level security;
-- Already enabled by the customer migration; leave its owner-read policy intact.
alter table public.rescue_services enable row level security;

revoke all on public.admin_profiles, public.admin_audit_logs, public.admin_notifications,
  public.admin_service_catalog from public, anon, authenticated;
grant select on public.admin_profiles, public.admin_audit_logs, public.admin_notifications,
  public.admin_service_catalog to authenticated;
grant insert(id,full_name,role,status,phone,avatar_url) on public.admin_profiles to authenticated;
grant update(full_name,role,status,phone,avatar_url) on public.admin_profiles to authenticated;
grant insert(title,body,target_type,priority,target_user_id) on public.admin_notifications to authenticated;
grant update(description,icon,base_price,price_unit,is_featured) on public.admin_service_catalog to authenticated;

create policy admin_profiles_read on public.admin_profiles for select to authenticated using ((select public.is_admin()));
create policy admin_profiles_insert on public.admin_profiles for insert to authenticated
  with check ((select public.has_admin_role(array['super_admin'])));
create policy admin_profiles_update on public.admin_profiles for update to authenticated
  using ((select public.has_admin_role(array['super_admin'])))
  with check ((select public.has_admin_role(array['super_admin'])));
create policy admin_audit_read on public.admin_audit_logs for select to authenticated using ((select public.is_admin()));
-- No client INSERT, UPDATE or DELETE policy/grant on audit logs.
create policy admin_notifications_read on public.admin_notifications for select to authenticated using ((select public.is_admin()));
create policy admin_notifications_insert on public.admin_notifications for insert to authenticated
  with check ((select public.has_admin_role(array['super_admin','operator','support'])) and created_by=(select auth.uid()));
create policy admin_catalog_read on public.admin_service_catalog for select to authenticated using ((select public.is_admin()));
create policy admin_catalog_update on public.admin_service_catalog for update to authenticated
  using ((select public.has_admin_role(array['super_admin','operator'])))
  with check ((select public.has_admin_role(array['super_admin','operator'])));
create policy admin_services_read on public.rescue_services for select to authenticated using ((select public.is_admin()));
-- Status writes use the audited RPC below; no new direct shared-table UPDATE grant.
create policy admin_services_update on public.rescue_services for update to authenticated
  using ((select public.has_admin_role(array['super_admin','operator'])))
  with check ((select public.has_admin_role(array['super_admin','operator'])));


-- Security-barrier views deliberately use the migration owner's base-table
-- privileges, with an explicit auth.uid()-based role gate on EVERY view.
-- This avoids granting cross-owner access on the customer/rescuer app tables.
create view public.admin_rescue_requests_view with (security_barrier=true,security_invoker=false) as
select r.id as request_id,r.id::text as request_code, -- no separate code in schema
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

create view public.admin_customers_view with (security_barrier=true,security_invoker=false) as
select c.user_id as customer_id,c.full_name,u.email::text as email,c.phone,
  null::text as avatar_url, -- absent; do not use untrusted Auth user_metadata
  (select count(*) from public.customer_vehicles v where v.customer_id=c.user_id) as vehicle_count,
  (select count(*) from public.customer_saved_addresses s where s.customer_id=c.user_id) as address_count,
  (select count(*) from public.rescue_requests r where r.customer_id=c.user_id) as request_count,
  (select count(*) from public.rescue_requests r where r.customer_id=c.user_id and r.status='completed') as completed_count,
  0::numeric as total_spent, -- no payment/settlement ledger; issued != paid
  c.created_at,null::text as status -- no customer status column
from public.customer_profiles c left join auth.users u on u.id=c.user_id
where (select public.has_admin_role(array['super_admin','operator','support']));

create view public.admin_rescuers_view with (security_barrier=true,security_invoker=false) as
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
  p.created_at,p.version
from public.rescuer_profiles p left join auth.users u on u.id=p.user_id
left join public.rescuer_online_status o on o.rescuer_id=p.user_id
where (select public.has_admin_role(array['super_admin','operator','partner_reviewer']));

create view public.admin_quotes_view with (security_barrier=true,security_invoker=false) as
select q.id as quote_id,q.request_id,r.id::text as request_code,
  coalesce(nullif(c.full_name,''),r.contact_name) as customer_name,p.full_name as rescuer_name,
  r.service_code as service_type,q.total_vnd::numeric as amount,q.note,q.status,q.issued_at as created_at,
  q.currency,q.revision,(q.id=a.current_quote_id) as is_current,
  (q.id=a.completion_quote_id and a.state='completed') as is_completion_quote
from public.rescue_quotes q join public.rescue_requests r on r.id=q.request_id
join public.rescue_request_assignments a on a.id=q.assignment_id
left join public.customer_profiles c on c.user_id=r.customer_id
left join public.rescuer_profiles p on p.user_id=q.rescuer_id
where (select public.has_admin_role(array['super_admin','finance']));

create view public.admin_reviews_view with (security_barrier=true,security_invoker=false) as
select v.id as review_id,v.request_id,r.id::text as request_code,
  coalesce(nullif(c.full_name,''),r.contact_name) as customer_name,p.full_name as rescuer_name,
  v.rating,v.comment,v.created_at
from public.customer_request_reviews v join public.rescue_requests r on r.id=v.request_id
left join public.customer_profiles c on c.user_id=v.customer_id
left join public.rescue_request_assignments a on a.request_id=r.id
left join public.rescuer_profiles p on p.user_id=coalesce(a.rescuer_id,r.provider_id)
where (select public.has_admin_role(array['super_admin','operator','support']));

create view public.admin_services_view with (security_barrier=true,security_invoker=false) as
select m.id as service_id,m.admin_code as code,s.code as app_service_code,s.name,
  m.description,m.icon,m.base_price,m.price_unit,s.is_active,m.is_featured,s.sort_order,m.created_at,m.updated_at
from public.admin_service_catalog m join public.rescue_services s on s.code=m.service_code
where (select public.is_admin());

create view public.admin_rescuer_documents_view with (security_barrier=true,security_invoker=false) as
select d.id as document_id,d.rescuer_id,d.document_type,d.vehicle_id,d.storage_path,
  d.content_type,d.byte_size,d.uploaded_at,d.verification_status,d.expires_at,d.created_at
from public.rescuer_documents d
where (select public.has_admin_role(array['super_admin','partner_reviewer']));
-- Metadata only: existing restrictive Storage policies still deny downloading
-- other users' objects. A separately reviewed download gateway is required.

revoke all on public.admin_rescue_requests_view,public.admin_customers_view,
  public.admin_rescuers_view,public.admin_quotes_view,public.admin_reviews_view,
  public.admin_services_view,public.admin_rescuer_documents_view from public,anon,authenticated;
grant select on public.admin_rescue_requests_view,public.admin_customers_view,
  public.admin_rescuers_view,public.admin_quotes_view,public.admin_reviews_view,
  public.admin_services_view,public.admin_rescuer_documents_view to authenticated;

create function public.admin_get_dashboard_stats() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_day timestamptz:=((now() at time zone 'Asia/Ho_Chi_Minh')::date)::timestamp at time zone 'Asia/Ho_Chi_Minh';
  v_next timestamptz:=(((now() at time zone 'Asia/Ho_Chi_Minh')::date+1)::timestamp) at time zone 'Asia/Ho_Chi_Minh';
  v_finance boolean;
begin
  perform private.admin_require_role(array['super_admin','operator','support','partner_reviewer','finance']);
  v_finance:=public.has_admin_role(array['super_admin','finance']);
  return jsonb_build_object(
    'total_customers',(select count(*) from public.customer_profiles),
    'total_rescuers',(select count(*) from public.rescuer_profiles),
    'today_requests',(select count(*) from public.rescue_requests where created_at>=v_day and created_at<v_next),
    'active_requests',(select count(*) from public.rescue_requests where status in ('searching','accepted','arriving','in_progress')),
    'completed_requests',(select count(*) from public.rescue_requests where status='completed'),
    'cancelled_requests',(select count(*) from public.rescue_requests where status='cancelled'),
    'today_revenue',case when v_finance then (
      select coalesce(sum(q.total_vnd::numeric),0) from public.rescue_quotes q
      join public.rescue_requests r on r.id=q.request_id
      where q.status='issued' and q.issued_at>=v_day and q.issued_at<v_next and r.status<>'cancelled'
    ) else 0 end,
    'revenue_visible',v_finance,'revenue_basis','current_issued_quotes_not_payments',
    'online_rescuers',(select count(*) from public.rescuer_online_status o
      join public.rescuer_profiles p on p.user_id=o.rescuer_id
      where o.is_online and p.verification_status='approved' and o.last_seen_at>=now()-interval '120 seconds'),
    'pending_rescuers',(select count(*) from public.rescuer_profiles where verification_status='submitted'),
    'average_rating',(select coalesce(round(avg(rating),2),0) from public.customer_request_reviews),
    'timezone','Asia/Ho_Chi_Minh'
  );
end;
$$;

create function private.admin_change_rescuer(p_id uuid,p_target text,p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_profile public.rescuer_profiles; v_action text; v_message text;
begin
  if p_target='suspended' then
    perform private.admin_require_role(array['super_admin','operator']);
    v_action:='block_rescuer'; v_message:='Đã khóa đối tác cứu hộ';
  elsif p_target in ('approved','rejected') then
    perform private.admin_require_role(array['super_admin','partner_reviewer']);
    v_action:=case p_target when 'approved' then 'approve_rescuer' else 'reject_rescuer' end;
    v_message:=case p_target when 'approved' then 'Đã duyệt đối tác cứu hộ' else 'Đã từ chối hồ sơ đối tác' end;
  else raise exception 'ADMIN_INVALID_RESCUER_STATUS' using errcode='22023'; end if;
  if p_id is null then raise exception 'ADMIN_RESCUER_ID_REQUIRED' using errcode='22023'; end if;
  if p_target in ('rejected','suspended') and
    (p_reason is null or length(btrim(p_reason)) not between 1 and 2000) then
    raise exception 'ADMIN_REASON_REQUIRED' using errcode='22023';
  end if;
  -- Same lock namespace/order as existing rescuer mutation RPCs.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('rescuer:'||p_id::text,0));
  select * into v_profile from public.rescuer_profiles where user_id=p_id for update;
  if not found then raise exception 'ADMIN_RESCUER_NOT_FOUND' using errcode='P0002'; end if;
  if v_profile.verification_status=p_target then
    return jsonb_build_object('success',true,'changed',false,'message',v_message);
  end if;
  -- Existing active-job APIs require approved status. Do not strand a live job.
  if private.rescuer_busy(p_id) then raise exception 'ADMIN_RESCUER_BUSY' using errcode='P0001'; end if;
  if p_target in ('approved','rejected') and v_profile.verification_status<>'submitted' then
    raise exception 'ADMIN_RESCUER_NOT_SUBMITTED' using errcode='22023';
  end if;
  update public.rescuer_profiles set verification_status=p_target,
    verified_at=clock_timestamp(),verified_by=auth.uid(),version=version+1 where user_id=p_id;
  if p_target in ('rejected','suspended') then
    update public.rescuer_online_status set is_online=false where rescuer_id=p_id;
  end if;
  -- Approving a profile does not auto-approve vehicles/documents/capabilities.
  perform public.admin_log_action(v_action,'rescuer_profiles',p_id,
    jsonb_build_object('before',v_profile.verification_status,'after',p_target,
      'reason',nullif(btrim(p_reason),''),'before_version',v_profile.version,'after_version',v_profile.version+1));
  return jsonb_build_object('success',true,'changed',true,'message',v_message);
end;
$$;
create function public.admin_approve_rescuer(rescuer_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
begin return private.admin_change_rescuer(rescuer_id,'approved',null); end;
$$;
create function public.admin_reject_rescuer(rescuer_id uuid,reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin return private.admin_change_rescuer(rescuer_id,'rejected',reason); end;
$$;
create function public.admin_block_rescuer(rescuer_id uuid,reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin return private.admin_change_rescuer(rescuer_id,'suspended',reason); end;
$$;

create function public.admin_cancel_request(request_id uuid,reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_request public.rescue_requests; v_id uuid:=request_id; v_reason text:=btrim(reason);
begin
  perform private.admin_require_role(array['super_admin','operator']);
  if v_id is null or v_reason is null or length(v_reason) not between 1 and 2000 then
    raise exception 'ADMIN_REQUEST_ID_AND_REASON_REQUIRED' using errcode='22023';
  end if;
  select * into v_request from public.rescue_requests r where r.id=v_id for update;
  if not found then raise exception 'ADMIN_REQUEST_NOT_FOUND' using errcode='P0002'; end if;
  if v_request.status not in ('searching','accepted','arriving') then
    raise exception 'ADMIN_REQUEST_NOT_CANCELLABLE' using errcode='22023';
  end if;
  update public.rescue_requests r set status='cancelled',updated_at=clock_timestamp() where r.id=v_id;
  -- Existing triggers insert one tracking event and synchronize assignment
  -- version/state (system_cancelled unless caller is also the customer). No duplicate event here.
  -- request_status_events has no reason/created_by: retain them in the audit log.
  perform public.admin_log_action('cancel_request','rescue_requests',v_id,
    jsonb_build_object('reason',v_reason,'before',v_request.status,'after','cancelled',
      'customer_id',v_request.customer_id,'provider_id',v_request.provider_id));
  return jsonb_build_object('success',true,'message','Đã hủy yêu cầu cứu hộ');
end;
$$;

create function public.admin_toggle_service(service_id uuid,is_active boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_code text; v_old boolean; v_id uuid:=service_id; v_active boolean:=is_active;
begin
  perform private.admin_require_role(array['super_admin','operator']);
  if v_id is null or v_active is null then raise exception 'ADMIN_INVALID_SERVICE_INPUT' using errcode='22023'; end if;
  select m.service_code into v_code from public.admin_service_catalog m where m.id=v_id;
  if not found then raise exception 'ADMIN_SERVICE_NOT_FOUND' using errcode='P0002'; end if;
  select s.is_active into v_old from public.rescue_services s where s.code=v_code for update;
  if not found then raise exception 'ADMIN_SERVICE_NOT_FOUND' using errcode='P0002'; end if;
  if v_old is not distinct from v_active then
    return jsonb_build_object('success',true,'changed',false,'message','Đã cập nhật trạng thái dịch vụ');
  end if;
  update public.rescue_services s set is_active=v_active where s.code=v_code;
  perform public.admin_log_action('toggle_service','rescue_services',v_id,
    jsonb_build_object('app_service_code',v_code,'before',v_old,'after',v_active,'target_id_source','admin_service_catalog.id'));
  return jsonb_build_object('success',true,'changed',true,'message','Đã cập nhật trạng thái dịch vụ');
end;
$$;

revoke all on function public.is_admin(),public.has_admin_role(text[]),
  public.admin_log_action(text,text,uuid,jsonb),public.admin_get_dashboard_stats(),
  public.admin_approve_rescuer(uuid),public.admin_reject_rescuer(uuid,text),
  public.admin_block_rescuer(uuid,text),public.admin_cancel_request(uuid,text),
  public.admin_toggle_service(uuid,boolean),private.admin_require_role(text[]),
  private.admin_profile_guard(),private.admin_profile_audit(),
  private.admin_notification_guard(),private.admin_notification_audit(),
  private.admin_catalog_guard(),private.admin_catalog_audit(),
  private.admin_change_rescuer(uuid,text,text) from public,anon,authenticated;
grant execute on function public.is_admin(),public.has_admin_role(text[]),
  public.admin_get_dashboard_stats(),public.admin_approve_rescuer(uuid),
  public.admin_reject_rescuer(uuid,text),public.admin_block_rescuer(uuid,text),
  public.admin_cancel_request(uuid,text),public.admin_toggle_service(uuid,boolean) to authenticated;

-- Keep existing names/codes/activation. Newly introduced services stay disabled
-- until both apps and partner capability workflows are ready.
insert into public.rescue_services(code,name,is_active,sort_order) values
  ('towing','Cẩu & Kéo Xe Ô Tô',true,40),('battery','Kích Bình Ắc Quy',true,20),
  ('tire','Vá Vỏ & Thay Lốp',true,10),('fuel','Tiếp Nhiên Liệu',true,30),
  ('locksmith','Mở Khóa Ô Tô',false,60),('mechanic','Sửa Chữa Tại Chỗ',false,70)
on conflict(code) do nothing;
insert into public.admin_service_catalog(service_code,admin_code,description,icon,base_price,price_unit,is_featured) values
  ('towing','SRV-TOW-01','Cẩu kéo xe hỏng, xe tai nạn, xe không thể tự di chuyển.','truck',500000,'ca',true),
  ('battery','SRV-BAT-02','Kích bình, sạc bình 12V/24V lưu động.','battery',200000,'lần',false),
  ('tire','SRV-TYR-03','Vá vỏ, thay lốp sơ cua, hỗ trợ lốp xe khẩn cấp.','disc',250000,'ca',false),
  ('fuel','SRV-FUL-04','Giao xăng/dầu khẩn cấp khi xe hết nhiên liệu.','fuel',180000,'chuyến',false),
  ('locksmith','SRV-LCK-05','Hỗ trợ mở khóa cửa/cốp xe ô tô.','key',300000,'ca',false),
  ('mechanic','SRV-MEC-06','Kiểm tra và xử lý lỗi cơ bản tại hiện trường.','wrench',350000,'ca',false)
on conflict(service_code) do nothing;
insert into public.admin_service_catalog(service_code,admin_code)
select s.code,'LEGACY:'||s.code from public.rescue_services s
where not exists(select 1 from public.admin_service_catalog m where m.service_code=s.code)
on conflict(service_code) do nothing;

comment on table public.admin_service_catalog is 'Admin UUID/metadata extension; rescue_services.code remains the shared app contract.';
comment on function public.admin_log_action(text,text,uuid,jsonb) is 'Internal audit writer; no client EXECUTE privilege.';
comment on view public.admin_quotes_view is 'Issued/superseded quotes, not payment receipts. Gate: super_admin/finance.';
comment on view public.admin_customers_view is 'total_spent=0 until payment ledger exists; status/avatar_url unavailable (NULL).';
notify pgrst,'reload schema';
commit;
