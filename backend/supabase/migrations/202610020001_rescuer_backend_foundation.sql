-- Rescuer foundation. LOCAL FILE ONLY; review/test before deploying.
-- Depends on all six customer migrations through 202610010005.
-- No customer policy, function signature, status vocabulary or Storage grant changes.
begin;
set local lock_timeout = '5s';

-- Fail closed on known prerequisite drift; never silently merge existing objects.
do $preflight$
declare
  v_states text[];
  v_col record;
begin
  if to_regclass('public.rescue_requests') is null
     or to_regclass('public.rescue_services') is null
     or to_regclass('public.request_status_events') is null
     or to_regclass('public.customer_request_reviews') is null
     or to_regprocedure('auth.uid()') is null
     or to_regprocedure('public.cancel_own_rescue_request(uuid)') is null
     or to_regprocedure('public.create_customer_rescue_request(uuid,text,text,text,text,text,text,uuid,double precision,double precision)') is null then
    raise exception 'SCHEMA_MISMATCH: missing customer prerequisites';
  end if;
  for v_col in select * from (values
    ('id','uuid'), ('customer_id','uuid'), ('provider_id','uuid'),
    ('status','text'), ('service_code','text'), ('vehicle_kind','text'),
    ('latitude','double precision'), ('longitude','double precision'),
    ('contact_name','text'), ('contact_phone','text'), ('location_text','text'),
    ('description','text'), ('quoted_price','integer'), ('updated_at','timestamp with time zone')
  ) as required_columns(column_name,type_name) loop
    if not exists (
      select 1 from pg_catalog.pg_attribute a
      where a.attrelid = 'public.rescue_requests'::regclass
        and a.attname = v_col.column_name and not a.attisdropped
        and pg_catalog.format_type(a.atttypid,a.atttypmod) = v_col.type_name
    ) then raise exception 'SCHEMA_MISMATCH: rescue_requests column %', v_col.column_name; end if;
  end loop;
  select array_agg(m[1] order by m[1]) into v_states
  from pg_catalog.pg_constraint c,
    lateral regexp_matches(pg_catalog.pg_get_constraintdef(c.oid), '''([^'']+)''', 'g') m
  where c.conrelid = 'public.rescue_requests'::regclass
    and c.conname = 'rescue_requests_status_check' and c.contype = 'c';
  if v_states is distinct from array['accepted','arriving','cancelled','completed','in_progress','searching']::text[] then
    raise exception 'SCHEMA_MISMATCH: customer status vocabulary';
  end if;
  if not (select relrowsecurity from pg_catalog.pg_class where oid = 'public.rescue_requests'::regclass)
     or (select count(*) from pg_catalog.pg_policy where polrelid = 'public.rescue_requests'::regclass) <> 1
     or not exists (select 1 from pg_catalog.pg_policies
       where schemaname='public' and tablename='rescue_requests'
       and policyname='customers read own rescue requests' and cmd='SELECT'
       and roles = array['authenticated']::name[])
     or pg_catalog.has_table_privilege('authenticated','public.rescue_requests','UPDATE')
     or pg_catalog.has_table_privilege('authenticated','public.rescue_requests','INSERT')
     or pg_catalog.has_table_privilege('anon','public.rescue_requests','SELECT') then
    raise exception 'SCHEMA_MISMATCH: rescue_requests security requires review';
  end if;
  if not exists (select 1 from pg_catalog.pg_trigger where tgrelid='public.rescue_requests'::regclass
      and tgname='cuuho247_request_transition' and tgenabled='O')
     or not exists (select 1 from pg_catalog.pg_trigger where tgrelid='public.rescue_requests'::regclass
      and tgname='cuuho247_request_status_event' and tgenabled='O') then
    raise exception 'SCHEMA_MISMATCH: customer tracking triggers';
  end if;
  if to_regclass('public.rescuer_profiles') is not null
     or exists(select 1 from storage.buckets where id='rescuer-documents')
     or exists (select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
                where n.nspname in ('public','private') and p.proname like 'rescuer\_%' escape '\') then
    raise exception 'SCHEMA_MISMATCH: rescuer objects already exist';
  end if;
  if 'private' = any(regexp_split_to_array(coalesce(current_setting('pgrst.db_schemas',true),''), '\s*,\s*')) then
    raise exception 'SCHEMA_MISMATCH: private schema must not be exposed';
  end if;
end;
$preflight$;

create schema if not exists private;

create table public.rescuer_profiles (
  user_id uuid primary key references auth.users(id) on delete restrict,
  full_name text not null check (full_name = btrim(full_name) and length(full_name) between 1 and 150),
  contact_phone text not null check (contact_phone ~ '^\+?[0-9]{8,15}$'),
  verification_status text not null default 'draft'
    check (verification_status in ('draft','submitted','approved','rejected','suspended')),
  submitted_at timestamptz,
  verified_at timestamptz,
  verified_by uuid references auth.users(id) on delete restrict,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create table public.rescuer_vehicles (
  id uuid primary key default gen_random_uuid(),
  rescuer_id uuid not null references public.rescuer_profiles(user_id) on delete restrict,
  kind text not null check (kind in ('service_motorbike','service_car','tow_truck','recovery_truck','other')),
  display_name text not null check (display_name=btrim(display_name) and length(display_name) between 1 and 150),
  license_plate text not null check (length(license_plate) between 1 and 20 and license_plate ~ '^[A-Z0-9]+$'),
  verification_status text not null default 'draft'
    check (verification_status in ('draft','submitted','approved','rejected','suspended')),
  is_active boolean not null default true,
  version bigint not null default 1 check (version>0),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique(id,rescuer_id),
  unique(rescuer_id,license_plate)
);

create table public.rescuer_documents (
  id uuid primary key default gen_random_uuid(),
  rescuer_id uuid not null references public.rescuer_profiles(user_id) on delete restrict,
  document_type text not null check (document_type in ('identity','license','vehicle_registration')),
  vehicle_id uuid,
  storage_path text not null unique,
  content_type text not null check (content_type in ('image/jpeg','image/png','application/pdf')),
  byte_size integer not null check (byte_size between 1 and 10485760),
  uploaded_at timestamptz,
  verification_status text not null default 'submitted'
    check (verification_status in ('submitted','approved','rejected','expired')),
  expires_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  foreign key(vehicle_id,rescuer_id) references public.rescuer_vehicles(id,rescuer_id) on delete restrict,
  check ((document_type='vehicle_registration') = (vehicle_id is not null)),
  check (storage_path=rescuer_id::text || '/' || id::text),
  check (verification_status<>'approved' or uploaded_at is not null)
);
create index rescuer_documents_owner_idx on public.rescuer_documents(rescuer_id,document_type);
create index rescuer_documents_vehicle_idx on public.rescuer_documents(vehicle_id,rescuer_id);

create table public.rescuer_service_capabilities (
  rescuer_id uuid not null references public.rescuer_profiles(user_id) on delete restrict,
  vehicle_id uuid not null,
  service_code text not null references public.rescue_services(code) on delete restrict,
  customer_vehicle_kind text not null check (customer_vehicle_kind in ('motorbike','car','truck','other')),
  verification_status text not null default 'submitted'
    check (verification_status in ('submitted','approved','rejected','suspended')),
  is_enabled boolean not null default true,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  primary key(vehicle_id,service_code,customer_vehicle_kind),
  foreign key(vehicle_id,rescuer_id) references public.rescuer_vehicles(id,rescuer_id) on delete restrict
);
create index rescuer_capabilities_owner_idx on public.rescuer_service_capabilities(rescuer_id,vehicle_id);
create index rescuer_capabilities_service_idx on public.rescuer_service_capabilities(service_code);

create table public.rescuer_online_status (
  rescuer_id uuid primary key references public.rescuer_profiles(user_id) on delete restrict,
  is_online boolean not null default false,
  session_id uuid,
  vehicle_id uuid,
  last_seen_at timestamptz,
  updated_at timestamptz not null default clock_timestamp(),
  foreign key(vehicle_id,rescuer_id) references public.rescuer_vehicles(id,rescuer_id) on delete restrict,
  check (not is_online or (session_id is not null and vehicle_id is not null and last_seen_at is not null)),
  check ((session_id is null) = (vehicle_id is null))
);
create index rescuer_online_vehicle_idx on public.rescuer_online_status(vehicle_id,rescuer_id);

create table public.rescuer_locations (
  rescuer_id uuid primary key references public.rescuer_profiles(user_id) on delete restrict,
  session_id uuid not null,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy_m double precision not null check (accuracy_m between 0 and 10000),
  sequence bigint not null check (sequence>0),
  captured_at timestamptz not null check (isfinite(captured_at)),
  received_at timestamptz not null default clock_timestamp()
);

create table public.rescue_request_assignments (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references public.rescue_requests(id) on delete restrict,
  rescuer_id uuid not null references public.rescuer_profiles(user_id) on delete restrict,
  vehicle_id uuid not null,
  state text not null check (state in ('accepted','en_route','arrived','in_progress','completed','cancelled')),
  version bigint not null default 1 check (version>0),
  accepted_at timestamptz not null default clock_timestamp(),
  en_route_at timestamptz,
  arrived_at timestamptz,
  in_progress_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  updated_at timestamptz not null default clock_timestamp(),
  current_quote_id uuid,
  completion_quote_id uuid,
  cancellation_reason_code text check (cancellation_reason_code in
    ('unable_to_continue','safety_issue','vehicle_issue','customer_cancelled','system_cancelled')),
  unique(id,request_id,rescuer_id),
  foreign key(vehicle_id,rescuer_id) references public.rescuer_vehicles(id,rescuer_id) on delete restrict,
  check ((state='completed')=(completed_at is not null)),
  check ((state='cancelled')=(cancelled_at is not null)),
  check ((state='cancelled')=(cancellation_reason_code is not null)),
  check ((state='completed')=(completion_quote_id is not null)),
  check (en_route_at is null or en_route_at>=accepted_at),
  check (arrived_at is null or (en_route_at is not null and arrived_at>=en_route_at)),
  check (in_progress_at is null or (arrived_at is not null and in_progress_at>=arrived_at)),
  check (completed_at is null or (in_progress_at is not null and completed_at>=in_progress_at)),
  check (cancelled_at is null or cancelled_at>=coalesce(in_progress_at,arrived_at,en_route_at,accepted_at)),
  check (state not in ('en_route','arrived','in_progress','completed') or en_route_at is not null),
  check (state not in ('arrived','in_progress','completed') or arrived_at is not null),
  check (state not in ('in_progress','completed') or in_progress_at is not null)
);
create unique index rescuer_one_active_assignment on public.rescue_request_assignments(rescuer_id)
  where state in ('accepted','en_route','arrived','in_progress');
create index rescuer_history_idx on public.rescue_request_assignments(rescuer_id,accepted_at desc,id desc);
create index rescuer_assignment_vehicle_idx on public.rescue_request_assignments(vehicle_id,rescuer_id);
create index rescuer_discovery_requests_idx on public.rescue_requests(service_code,vehicle_kind,id)
  where status='searching' and provider_id is null and latitude is not null and longitude is not null;

create table public.rescuer_assignment_events (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.rescue_request_assignments(id) on delete restrict,
  version bigint not null check (version>0),
  event_kind text not null check (event_kind in ('claimed','status_changed','quote_issued','customer_cancelled')),
  previous_state text check (previous_state in ('accepted','en_route','arrived','in_progress','completed','cancelled')),
  state text not null check (state in ('accepted','en_route','arrived','in_progress','completed','cancelled')),
  actor_kind text not null check (actor_kind in ('rescuer','customer','system')),
  actor_id uuid,
  reason_code text check (reason_code in ('unable_to_continue','safety_issue','vehicle_issue','customer_cancelled','system_cancelled')),
  occurred_at timestamptz not null default clock_timestamp(),
  unique(assignment_id,version)
);

create table public.rescue_quotes (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null,
  request_id uuid not null,
  rescuer_id uuid not null,
  revision integer not null check (revision>0),
  status text not null default 'issued' check (status in ('issued','superseded')),
  currency text not null default 'VND' check (currency='VND'),
  total_vnd integer not null check (total_vnd>=0),
  items jsonb not null check (jsonb_typeof(items)='array' and jsonb_array_length(items) between 1 and 20),
  note text check (length(note)<=1000),
  issued_at timestamptz not null default clock_timestamp(),
  unique(assignment_id,revision),
  unique(id,assignment_id),
  foreign key(assignment_id,request_id,rescuer_id)
    references public.rescue_request_assignments(id,request_id,rescuer_id) on delete restrict
);
create unique index rescuer_one_issued_quote on public.rescue_quotes(assignment_id) where status='issued';
create index rescuer_quotes_owner_idx on public.rescue_quotes(rescuer_id);
create index rescuer_quotes_request_idx on public.rescue_quotes(request_id);
alter table public.rescue_request_assignments
  add constraint rescuer_current_quote_fk foreign key(current_quote_id,id)
    references public.rescue_quotes(id,assignment_id) on delete restrict,
  add constraint rescuer_completion_quote_fk foreign key(completion_quote_id,id)
    references public.rescue_quotes(id,assignment_id) on delete restrict;

create table private.rescuer_rpc_receipts (
  rescuer_id uuid not null references public.rescuer_profiles(user_id) on delete restrict,
  operation_id uuid not null,
  operation_name text not null,
  payload_hash text not null check (payload_hash ~ '^[0-9a-f]{64}$'),
  resource_id uuid not null,
  committed_at timestamptz not null default clock_timestamp(),
  primary key(rescuer_id,operation_id)
);
-- Small server-only limiter, no location history or request/customer identifiers.
create table private.rescuer_discovery_limits (
  rescuer_id uuid primary key references public.rescuer_profiles(user_id) on delete restrict,
  window_start timestamptz not null,
  attempts integer not null check (attempts between 1 and 30)
);

-- Owner SELECT only; no client writes to verification, assignment, quote or receipts.
alter table public.rescuer_profiles enable row level security;
alter table public.rescuer_documents enable row level security;
alter table public.rescuer_vehicles enable row level security;
alter table public.rescuer_service_capabilities enable row level security;
alter table public.rescuer_online_status enable row level security;
alter table public.rescuer_locations enable row level security;
alter table public.rescue_request_assignments enable row level security;
alter table public.rescuer_assignment_events enable row level security;
alter table public.rescue_quotes enable row level security;
alter table private.rescuer_rpc_receipts enable row level security;
alter table private.rescuer_discovery_limits enable row level security;
revoke all on public.rescuer_profiles, public.rescuer_documents, public.rescuer_vehicles,
  public.rescuer_service_capabilities, public.rescuer_online_status, public.rescuer_locations,
  public.rescue_request_assignments, public.rescuer_assignment_events, public.rescue_quotes,
  private.rescuer_rpc_receipts, private.rescuer_discovery_limits from public, anon, authenticated;
grant select on public.rescuer_profiles, public.rescuer_documents, public.rescuer_vehicles,
  public.rescuer_service_capabilities, public.rescuer_online_status, public.rescuer_locations to authenticated;
create policy rescuer_profile_owner_read on public.rescuer_profiles for select to authenticated
  using (user_id=(select auth.uid()));
create policy rescuer_document_owner_read on public.rescuer_documents for select to authenticated
  using (rescuer_id=(select auth.uid()));
create policy rescuer_vehicle_owner_read on public.rescuer_vehicles for select to authenticated
  using (rescuer_id=(select auth.uid()));
create policy rescuer_capability_owner_read on public.rescuer_service_capabilities for select to authenticated
  using (rescuer_id=(select auth.uid()));
create policy rescuer_online_owner_read on public.rescuer_online_status for select to authenticated
  using (rescuer_id=(select auth.uid()));
create policy rescuer_location_owner_read on public.rescuer_locations for select to authenticated
  using (rescuer_id=(select auth.uid()));
-- RPC-only tables intentionally have no policies or SELECT grants: default deny.

create function private.rescuer_touch_updated_at() returns trigger
language plpgsql security definer set search_path='' as $$
begin new.updated_at:=clock_timestamp(); return new; end;
$$;
create trigger rescuer_profile_updated before update on public.rescuer_profiles
  for each row execute function private.rescuer_touch_updated_at();
create trigger rescuer_vehicle_updated before update on public.rescuer_vehicles
  for each row execute function private.rescuer_touch_updated_at();
create trigger rescuer_capability_updated before update on public.rescuer_service_capabilities
  for each row execute function private.rescuer_touch_updated_at();
create trigger rescuer_online_updated before update on public.rescuer_online_status
  for each row execute function private.rescuer_touch_updated_at();
create trigger rescuer_assignment_updated before update on public.rescue_request_assignments
  for each row execute function private.rescuer_touch_updated_at();

create function private.rescuer_auth() returns uuid
language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  return v_uid;
end;
$$;

-- Advisory lock covers profile creation too; all mutation paths then lock profile.
-- Receipt lookup precedes expected_version/freshness, but never returns cached PII.
create function private.rescuer_begin_operation(p_name text,p_operation_id uuid,p_payload jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=private.rescuer_auth(); v_receipt record; v_hash text;
begin
  if p_operation_id is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode='22023'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('rescuer:'||v_uid::text,0));
  perform 1 from public.rescuer_profiles where user_id=v_uid for update;
  v_hash:=encode(sha256(convert_to(jsonb_build_array(p_name,p_payload)::text,'UTF8')),'hex');
  select operation_name,payload_hash,resource_id into v_receipt
    from private.rescuer_rpc_receipts where rescuer_id=v_uid and operation_id=p_operation_id;
  if found then
    if v_receipt.operation_name<>p_name or v_receipt.payload_hash<>v_hash then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode='22023';
    end if;
    return v_receipt.resource_id;
  end if;
  return null;
end;
$$;

create function private.rescuer_commit_receipt(p_name text,p_operation_id uuid,p_payload jsonb,p_resource_id uuid)
returns void language sql security definer set search_path='' as $$
  insert into private.rescuer_rpc_receipts(rescuer_id,operation_id,operation_name,payload_hash,resource_id)
  values(auth.uid(),p_operation_id,p_name,
    encode(sha256(convert_to(jsonb_build_array(p_name,p_payload)::text,'UTF8')),'hex'),p_resource_id);
$$;

create function private.rescuer_require_profile(p_approved boolean default false) returns void
language plpgsql security definer set search_path='' as $$
declare v_status text;
begin
  select verification_status into v_status from public.rescuer_profiles where user_id=private.rescuer_auth();
  if v_status is null then raise exception 'PROFILE_NOT_READY' using errcode='42501'; end if;
  if v_status='suspended' then raise exception 'PROFILE_SUSPENDED' using errcode='42501'; end if;
  if p_approved and v_status<>'approved' then raise exception 'PROFILE_NOT_READY' using errcode='42501'; end if;
end;
$$;

create function private.rescuer_busy(p_uid uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.rescue_request_assignments
    where rescuer_id=p_uid and state in ('accepted','en_route','arrived','in_progress'));
$$;
create function private.rescuer_require_idle() returns void
language plpgsql security definer set search_path='' as $$
begin
  if private.rescuer_busy(auth.uid()) then raise exception 'RESCUER_BUSY' using errcode='P0001'; end if;
end;
$$;

create function private.rescuer_profile_dto() returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('user_id',user_id,'full_name',full_name,'contact_phone',contact_phone,
    'verification_status',verification_status,'submitted_at',submitted_at,'verified_at',verified_at,
    'version',version,'created_at',created_at,'updated_at',updated_at)
  from public.rescuer_profiles where user_id=auth.uid();
$$;
create function private.rescuer_vehicle_dto(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('vehicle_id',id,'kind',kind,'display_name',display_name,'license_plate',license_plate,
    'verification_status',verification_status,'is_active',is_active,'version',version,
    'created_at',created_at,'updated_at',updated_at)
  from public.rescuer_vehicles where id=p_id and rescuer_id=auth.uid();
$$;
create function private.rescuer_online_dto() returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('is_online',is_online,'session_id',session_id,'vehicle_id',vehicle_id,
    'last_seen_at',last_seen_at,'updated_at',updated_at,'busy',private.rescuer_busy(auth.uid()))
  from public.rescuer_online_status where rescuer_id=auth.uid();
$$;
create function private.rescuer_location_dto() returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('session_id',session_id,'sequence',sequence,'received_at',received_at)
  from public.rescuer_locations where rescuer_id=auth.uid();
$$;
create function private.rescuer_assignment_dto(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('assignment_id',a.id,'request_id',a.request_id,'vehicle_id',a.vehicle_id,
    'state',a.state,'version',a.version,'accepted_at',a.accepted_at,'en_route_at',a.en_route_at,
    'arrived_at',a.arrived_at,'in_progress_at',a.in_progress_at,'completed_at',a.completed_at,
    'cancelled_at',a.cancelled_at,'cancellation_reason_code',a.cancellation_reason_code,
    'current_quote_id',a.current_quote_id,'completion_quote_id',a.completion_quote_id,
    'total_vnd',q.total_vnd,'currency',q.currency)
  from public.rescue_request_assignments a left join public.rescue_quotes q on q.id=a.current_quote_id
  where a.id=p_id and a.rescuer_id=auth.uid();
$$;
-- Historical quote retry returns only amounts/IDs, never note or arbitrary item text.
create function private.rescuer_quote_dto(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('quote_id',q.id,'assignment_id',q.assignment_id,'request_id',q.request_id,
    'revision',q.revision,'status',q.status,'currency',q.currency,'total_vnd',q.total_vnd,
    'issued_at',q.issued_at,'assignment_version',a.version)
    || case when a.state in ('accepted','en_route','arrived','in_progress') and p.verification_status='approved'
      then jsonb_build_object('items',q.items,'note',q.note) else '{}'::jsonb end
  from public.rescue_quotes q
  join public.rescue_request_assignments a on a.id=q.assignment_id
  join public.rescuer_profiles p on p.user_id=q.rescuer_id
  where q.id=p_id and q.rescuer_id=auth.uid();
$$;

create function public.rescuer_register_profile(p_full_name text,p_contact_phone text,p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=private.rescuer_auth(); v_payload jsonb:=jsonb_build_array(p_full_name,p_contact_phone);
begin
  if private.rescuer_begin_operation('register_profile',p_operation_id,v_payload) is not null then
    return private.rescuer_profile_dto();
  end if;
  if p_full_name is null or length(btrim(p_full_name)) not between 1 and 150
     or p_contact_phone is null or p_contact_phone !~ '^\+?[0-9]{8,15}$' then
    raise exception 'INVALID_PROFILE' using errcode='22023';
  end if;
  if exists(select 1 from public.rescuer_profiles where user_id=v_uid) then
    raise exception 'PROFILE_ALREADY_EXISTS' using errcode='P0001';
  end if;
  insert into public.rescuer_profiles(user_id,full_name,contact_phone) values(v_uid,btrim(p_full_name),p_contact_phone);
  insert into public.rescuer_online_status(rescuer_id) values(v_uid);
  perform private.rescuer_commit_receipt('register_profile',p_operation_id,v_payload,v_uid);
  return private.rescuer_profile_dto();
end;
$$;

create function public.rescuer_update_profile(p_full_name text,p_contact_phone text,p_expected_version bigint,p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_payload jsonb:=jsonb_build_array(p_full_name,p_contact_phone,p_expected_version);
begin
  if private.rescuer_begin_operation('update_profile',p_operation_id,v_payload) is not null then
    return private.rescuer_profile_dto();
  end if;
  perform private.rescuer_require_profile(); perform private.rescuer_require_idle();
  if p_full_name is null or length(btrim(p_full_name)) not between 1 and 150
     or p_contact_phone is null or p_contact_phone !~ '^\+?[0-9]{8,15}$' then
    raise exception 'INVALID_PROFILE' using errcode='22023';
  end if;
  update public.rescuer_profiles set full_name=btrim(p_full_name),contact_phone=p_contact_phone,
    verification_status='draft',submitted_at=null,verified_at=null,verified_by=null,version=version+1
    where user_id=auth.uid() and version=p_expected_version;
  if not found then raise exception 'VERSION_CONFLICT' using errcode='P0001'; end if;
  update public.rescuer_online_status set is_online=false,session_id=null,vehicle_id=null where rescuer_id=auth.uid();
  perform private.rescuer_commit_receipt('update_profile',p_operation_id,v_payload,auth.uid());
  return private.rescuer_profile_dto();
end;
$$;

create function public.rescuer_register_vehicle(p_kind text,p_display_name text,p_license_plate text,p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_payload jsonb:=jsonb_build_array(p_kind,p_display_name,p_license_plate); v_id uuid;
begin
  v_id:=private.rescuer_begin_operation('register_vehicle',p_operation_id,v_payload);
  if v_id is not null then return private.rescuer_vehicle_dto(v_id); end if;
  perform private.rescuer_require_profile(); perform private.rescuer_require_idle();
  if p_kind is null or p_kind not in ('service_motorbike','service_car','tow_truck','recovery_truck','other')
     or p_display_name is null or length(btrim(p_display_name)) not between 1 and 150
     or p_license_plate is null or length(p_license_plate) not between 1 and 20 or p_license_plate !~ '^[A-Z0-9]+$' then
    raise exception 'INVALID_VEHICLE' using errcode='22023';
  end if;
  if exists(select 1 from public.rescuer_vehicles where rescuer_id=auth.uid() and license_plate=p_license_plate) then
    raise exception 'VEHICLE_ALREADY_EXISTS' using errcode='P0001';
  end if;
  insert into public.rescuer_vehicles(rescuer_id,kind,display_name,license_plate)
    values(auth.uid(),p_kind,btrim(p_display_name),p_license_plate) returning id into v_id;
  perform private.rescuer_commit_receipt('register_vehicle',p_operation_id,v_payload,v_id);
  return private.rescuer_vehicle_dto(v_id);
end;
$$;

create function public.rescuer_set_capability(p_vehicle_id uuid,p_service_code text,p_customer_vehicle_kind text,p_enabled boolean,p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_payload jsonb:=jsonb_build_array(p_vehicle_id,p_service_code,p_customer_vehicle_kind,p_enabled); v_retry uuid;
begin
  v_retry:=private.rescuer_begin_operation('set_capability',p_operation_id,v_payload);
  if v_retry is null then
    perform private.rescuer_require_profile(); perform private.rescuer_require_idle();
    if not exists(select 1 from public.rescuer_vehicles where id=p_vehicle_id and rescuer_id=auth.uid()) then
      raise exception 'VEHICLE_NOT_READY' using errcode='42501';
    end if;
    if p_enabled is null or p_customer_vehicle_kind is null or p_customer_vehicle_kind not in ('motorbike','car','truck','other')
       or not exists(select 1 from public.rescue_services where code=p_service_code and is_active) then
      raise exception 'CAPABILITY_UNAVAILABLE' using errcode='22023';
    end if;
    insert into public.rescuer_service_capabilities(rescuer_id,vehicle_id,service_code,customer_vehicle_kind,is_enabled)
      values(auth.uid(),p_vehicle_id,p_service_code,p_customer_vehicle_kind,p_enabled)
      on conflict(vehicle_id,service_code,customer_vehicle_kind) do update
        set is_enabled=excluded.is_enabled,
          verification_status=case when excluded.is_enabled and not public.rescuer_service_capabilities.is_enabled
            then 'submitted' else public.rescuer_service_capabilities.verification_status end;
    perform private.rescuer_commit_receipt('set_capability',p_operation_id,v_payload,p_vehicle_id);
  end if;
  return (select jsonb_build_object('vehicle_id',vehicle_id,'service_code',service_code,
    'customer_vehicle_kind',customer_vehicle_kind,'is_enabled',is_enabled,'verification_status',verification_status)
    from public.rescuer_service_capabilities where vehicle_id=p_vehicle_id and service_code=p_service_code
      and customer_vehicle_kind=p_customer_vehicle_kind and rescuer_id=auth.uid());
end;
$$;

create function private.rescuer_require_vehicle(p_vehicle_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform private.rescuer_require_profile(true);
  if not exists(select 1 from public.rescuer_vehicles where id=p_vehicle_id and rescuer_id=auth.uid()
      and verification_status='approved' and is_active) then
    raise exception 'VEHICLE_NOT_READY' using errcode='42501';
  end if;
end;
$$;

create function public.rescuer_update_vehicle(p_vehicle_id uuid,p_kind text,p_display_name text,p_license_plate text,
  p_is_active boolean,p_expected_version bigint,p_operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_payload jsonb:=jsonb_build_array(p_vehicle_id,p_kind,p_display_name,p_license_plate,p_is_active,p_expected_version); v_id uuid;
begin
  v_id:=private.rescuer_begin_operation('update_vehicle',p_operation_id,v_payload);
  if v_id is not null then return private.rescuer_vehicle_dto(v_id); end if;
  perform private.rescuer_require_profile(); perform private.rescuer_require_idle();
  if not exists(select 1 from public.rescuer_vehicles where id=p_vehicle_id and rescuer_id=auth.uid()) then
    raise exception 'VEHICLE_NOT_READY' using errcode='42501';
  end if;
  if p_kind is null or p_kind not in ('service_motorbike','service_car','tow_truck','recovery_truck','other')
     or p_display_name is null or length(btrim(p_display_name)) not between 1 and 150 or p_is_active is null
     or p_license_plate is null or length(p_license_plate) not between 1 and 20 or p_license_plate !~ '^[A-Z0-9]+$' then
    raise exception 'INVALID_VEHICLE' using errcode='22023';
  end if;
  if exists(select 1 from public.rescuer_vehicles where rescuer_id=auth.uid() and license_plate=p_license_plate and id<>p_vehicle_id) then
    raise exception 'VEHICLE_ALREADY_EXISTS' using errcode='P0001';
  end if;
  update public.rescuer_vehicles set kind=p_kind,display_name=btrim(p_display_name),license_plate=p_license_plate,
    is_active=p_is_active,verification_status='draft',version=version+1
    where id=p_vehicle_id and rescuer_id=auth.uid() and version=p_expected_version;
  if not found then raise exception 'VERSION_CONFLICT' using errcode='P0001'; end if;
  update public.rescuer_service_capabilities set verification_status='submitted' where vehicle_id=p_vehicle_id;
  update public.rescuer_online_status set is_online=false,session_id=null,vehicle_id=null
    where rescuer_id=auth.uid() and vehicle_id=p_vehicle_id;
  perform private.rescuer_commit_receipt('update_vehicle',p_operation_id,v_payload,p_vehicle_id);
  return private.rescuer_vehicle_dto(p_vehicle_id);
end;
$$;

create function private.rescuer_document_dto(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('document_id',id,'document_type',document_type,'vehicle_id',vehicle_id,
    'storage_path',storage_path,'content_type',content_type,'byte_size',byte_size,
    'uploaded_at',uploaded_at,'verification_status',verification_status,'expires_at',expires_at)
    from public.rescuer_documents where id=p_id and rescuer_id=auth.uid();
$$;

create function public.rescuer_reserve_document(p_document_type text,p_vehicle_id uuid,p_content_type text,p_byte_size integer,p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_payload jsonb:=jsonb_build_array(p_document_type,p_vehicle_id,p_content_type,p_byte_size); v_id uuid;
begin
  v_id:=private.rescuer_begin_operation('reserve_document',p_operation_id,v_payload);
  if v_id is not null then return private.rescuer_document_dto(v_id); end if;
  perform private.rescuer_require_profile(); perform private.rescuer_require_idle();
  if p_document_type is null or p_document_type not in ('identity','license','vehicle_registration')
     or (p_document_type='vehicle_registration')<>(p_vehicle_id is not null)
     or p_content_type is null or p_content_type not in ('image/jpeg','image/png','application/pdf')
     or p_byte_size is null or p_byte_size not between 1 and 10485760 then
    raise exception 'INVALID_DOCUMENT' using errcode='22023';
  end if;
  if p_vehicle_id is not null and not exists(select 1 from public.rescuer_vehicles where id=p_vehicle_id and rescuer_id=auth.uid()) then
    raise exception 'VEHICLE_NOT_READY' using errcode='42501';
  end if;
  if (select count(*) from public.rescuer_documents where rescuer_id=auth.uid())>=30 then
    raise exception 'DOCUMENT_LIMIT_REACHED' using errcode='P0001';
  end if;
  v_id:=gen_random_uuid();
  insert into public.rescuer_documents(id,rescuer_id,document_type,vehicle_id,storage_path,content_type,byte_size)
    values(v_id,auth.uid(),p_document_type,p_vehicle_id,auth.uid()::text||'/'||v_id::text,p_content_type,p_byte_size);
  perform private.rescuer_commit_receipt('reserve_document',p_operation_id,v_payload,v_id);
  return private.rescuer_document_dto(v_id);
end;
$$;

create function public.rescuer_complete_document(p_document_id uuid,p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_payload jsonb:=jsonb_build_array(p_document_id); v_id uuid; v_d public.rescuer_documents;
begin
  v_id:=private.rescuer_begin_operation('complete_document',p_operation_id,v_payload);
  if v_id is not null then return private.rescuer_document_dto(v_id); end if;
  perform private.rescuer_require_profile(); perform private.rescuer_require_idle();
  select * into v_d from public.rescuer_documents where id=p_document_id and rescuer_id=auth.uid() for update;
  if not found then raise exception 'DOCUMENT_NOT_READY' using errcode='42501'; end if;
  if v_d.uploaded_at is null then
    if not exists(select 1 from storage.objects where bucket_id='rescuer-documents' and name=v_d.storage_path
      and metadata->>'mimetype'=v_d.content_type
      and metadata->>'size'=v_d.byte_size::text) then
      raise exception 'DOCUMENT_NOT_READY' using errcode='22023';
    end if;
    update public.rescuer_documents set uploaded_at=clock_timestamp() where id=v_d.id;
  end if;
  perform private.rescuer_commit_receipt('complete_document',p_operation_id,v_payload,v_d.id);
  return private.rescuer_document_dto(v_d.id);
end;
$$;

create function public.rescuer_submit_profile(p_expected_version bigint,p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_payload jsonb:=jsonb_build_array(p_expected_version); v_status text;
begin
  if private.rescuer_begin_operation('submit_profile',p_operation_id,v_payload) is not null then
    return private.rescuer_profile_dto();
  end if;
  perform private.rescuer_require_profile(); perform private.rescuer_require_idle();
  select verification_status into v_status from public.rescuer_profiles where user_id=auth.uid();
  if v_status not in ('draft','rejected') then raise exception 'INVALID_SUBMISSION_STATE' using errcode='22023'; end if;
  -- Conservative review prerequisites only, NOT automated verification.
  if exists(select 1 from (values('identity'),('license')) required(kind) where not exists(
      select 1 from public.rescuer_documents d where d.rescuer_id=auth.uid() and d.document_type=required.kind
        and d.uploaded_at is not null and d.verification_status in ('submitted','approved')
        and (d.expires_at is null or d.expires_at>clock_timestamp())))
     or not exists(select 1 from public.rescuer_vehicles v where v.rescuer_id=auth.uid() and v.is_active
       and v.verification_status in ('draft','submitted','approved') and exists(select 1 from public.rescuer_documents d
         where d.vehicle_id=v.id and d.rescuer_id=auth.uid() and d.document_type='vehicle_registration'
           and d.uploaded_at is not null and d.verification_status in ('submitted','approved')
           and (d.expires_at is null or d.expires_at>clock_timestamp()))) then
    raise exception 'DOCUMENT_NOT_READY' using errcode='22023';
  end if;
  update public.rescuer_profiles set verification_status='submitted',submitted_at=clock_timestamp(),version=version+1
    where user_id=auth.uid() and version=p_expected_version;
  if not found then raise exception 'VERSION_CONFLICT' using errcode='P0001'; end if;
  update public.rescuer_vehicles set verification_status='submitted',version=version+1
    where rescuer_id=auth.uid() and verification_status='draft' and exists(select 1 from public.rescuer_documents d
      where d.vehicle_id=public.rescuer_vehicles.id and d.uploaded_at is not null
        and d.verification_status in ('submitted','approved') and (d.expires_at is null or d.expires_at>clock_timestamp()));
  perform private.rescuer_commit_receipt('submit_profile',p_operation_id,v_payload,auth.uid());
  return private.rescuer_profile_dto();
end;
$$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
  values('rescuer-documents','rescuer-documents',false,10485760,array['image/jpeg','image/png','application/pdf']);
create policy rescuer_document_object_read on storage.objects for select to authenticated
  using(bucket_id='rescuer-documents' and exists(select 1 from public.rescuer_documents d
    where d.storage_path=name and d.rescuer_id=(select auth.uid())));
create policy rescuer_document_object_insert on storage.objects for insert to authenticated
  with check(bucket_id='rescuer-documents' and exists(select 1 from public.rescuer_documents d
    where d.storage_path=name and d.rescuer_id=(select auth.uid()) and d.uploaded_at is null));
create policy rescuer_document_guard_read on storage.objects as restrictive for select to authenticated
  using(bucket_id<>'rescuer-documents' or exists(select 1 from public.rescuer_documents d
    where d.storage_path=name and d.rescuer_id=(select auth.uid())));
create policy rescuer_document_guard_insert on storage.objects as restrictive for insert to authenticated
  with check(bucket_id<>'rescuer-documents' or exists(select 1 from public.rescuer_documents d
    where d.storage_path=name and d.rescuer_id=(select auth.uid()) and d.uploaded_at is null));
create policy rescuer_document_guard_update on storage.objects as restrictive for update to authenticated
  using(bucket_id<>'rescuer-documents') with check(bucket_id<>'rescuer-documents');
create policy rescuer_document_guard_delete on storage.objects as restrictive for delete to authenticated
  using(bucket_id<>'rescuer-documents');
create policy rescuer_document_guard_anon on storage.objects as restrictive for all to anon
  using(bucket_id<>'rescuer-documents') with check(bucket_id<>'rescuer-documents');

create function public.rescuer_set_online(p_online boolean,p_vehicle_id uuid,p_session_id uuid,p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_payload jsonb:=jsonb_build_array(p_online,p_vehicle_id,p_session_id); v_online public.rescuer_online_status;
begin
  if private.rescuer_begin_operation('set_online',p_operation_id,v_payload) is not null then
    return private.rescuer_online_dto();
  end if;
  perform private.rescuer_require_profile();
  if p_online is null then raise exception 'INVALID_ONLINE_STATUS' using errcode='22023'; end if;
  select * into v_online from public.rescuer_online_status where rescuer_id=auth.uid();
  if p_session_id is not null and p_session_id is distinct from v_online.session_id then
    raise exception 'STALE_ONLINE_SESSION' using errcode='P0001';
  end if;
  if p_online then
    perform private.rescuer_require_vehicle(p_vehicle_id);
    if private.rescuer_busy(auth.uid()) and exists(select 1 from public.rescue_request_assignments
        where rescuer_id=auth.uid() and state in ('accepted','en_route','arrived','in_progress') and vehicle_id<>p_vehicle_id) then
      raise exception 'RESCUER_BUSY' using errcode='P0001';
    end if;
    if p_session_id is not null and (not v_online.is_online or p_vehicle_id is distinct from v_online.vehicle_id) then
      raise exception 'STALE_ONLINE_SESSION' using errcode='P0001';
    end if;
    update public.rescuer_online_status set is_online=true,vehicle_id=p_vehicle_id,
      session_id=coalesce(p_session_id,gen_random_uuid()),last_seen_at=clock_timestamp() where rescuer_id=auth.uid();
  else
    update public.rescuer_online_status set is_online=false,
      session_id=case when private.rescuer_busy(auth.uid()) then session_id end,
      vehicle_id=case when private.rescuer_busy(auth.uid()) then vehicle_id end where rescuer_id=auth.uid();
  end if;
  perform private.rescuer_commit_receipt('set_online',p_operation_id,v_payload,auth.uid());
  return private.rescuer_online_dto();
end;
$$;

create function public.rescuer_update_location(p_session_id uuid,p_sequence bigint,p_latitude double precision,
  p_longitude double precision,p_accuracy_m double precision,p_captured_at timestamptz,p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_payload jsonb:=jsonb_build_array(p_session_id,p_sequence,p_latitude,p_longitude,p_accuracy_m,p_captured_at);
  v_online public.rescuer_online_status; v_location public.rescuer_locations; v_now timestamptz:=clock_timestamp();
begin
  if private.rescuer_begin_operation('update_location',p_operation_id,v_payload) is not null then
    return private.rescuer_location_dto();
  end if;
  select * into v_online from public.rescuer_online_status where rescuer_id=auth.uid();
  perform private.rescuer_require_vehicle(v_online.vehicle_id);
  if p_session_id is null or p_session_id is distinct from v_online.session_id
     or (not v_online.is_online and not private.rescuer_busy(auth.uid())) then
    raise exception 'STALE_ONLINE_SESSION' using errcode='P0001';
  end if;
  if p_sequence is null or p_sequence<=0 or p_latitude is null or not (p_latitude between -90 and 90)
     or p_longitude is null or not (p_longitude between -180 and 180)
     or p_accuracy_m is null or not (p_accuracy_m between 0 and 10000)
     or p_captured_at is null or not isfinite(p_captured_at) then
    raise exception 'INVALID_LOCATION' using errcode='22023';
  end if;
  select * into v_location from public.rescuer_locations where rescuer_id=auth.uid();
  if v_location.session_id=p_session_id and p_sequence<=v_location.sequence then
    if p_sequence=v_location.sequence and p_latitude=v_location.latitude and p_longitude=v_location.longitude
       and p_accuracy_m=v_location.accuracy_m and p_captured_at=v_location.captured_at then
      perform private.rescuer_commit_receipt('update_location',p_operation_id,v_payload,auth.uid());
      return private.rescuer_location_dto();
    end if;
    raise exception 'STALE_LOCATION_SEQUENCE' using errcode='P0001';
  end if;
  if p_captured_at<v_now-interval '5 minutes' or p_captured_at>v_now+interval '30 seconds' then
    raise exception 'LOCATION_NOT_FRESH' using errcode='22023';
  end if;
  insert into public.rescuer_locations(rescuer_id,session_id,sequence,latitude,longitude,accuracy_m,captured_at,received_at)
    values(auth.uid(),p_session_id,p_sequence,p_latitude,p_longitude,p_accuracy_m,p_captured_at,v_now)
    on conflict(rescuer_id) do update set session_id=excluded.session_id,sequence=excluded.sequence,
      latitude=excluded.latitude,longitude=excluded.longitude,accuracy_m=excluded.accuracy_m,
      captured_at=excluded.captured_at,received_at=excluded.received_at;
  update public.rescuer_online_status set last_seen_at=v_now where rescuer_id=auth.uid();
  perform private.rescuer_commit_receipt('update_location',p_operation_id,v_payload,auth.uid());
  return private.rescuer_location_dto();
end;
$$;

-- Discovery serializes with the caller's mutations. Coarse grid, distance and
-- radius all use the same cell centre; exact coordinates never affect ranking.
create function private.rescuer_discovery_context(p_vehicle_id uuid) returns public.rescuer_locations
language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=private.rescuer_auth(); v_l public.rescuer_locations; v_o public.rescuer_online_status; v_attempts integer;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('rescuer:'||v_uid::text,0));
  perform 1 from public.rescuer_profiles where user_id=v_uid for update;
  perform private.rescuer_require_vehicle(p_vehicle_id); perform private.rescuer_require_idle();
  select * into v_o from public.rescuer_online_status where rescuer_id=v_uid;
  select * into v_l from public.rescuer_locations where rescuer_id=v_uid;
  if not coalesce(v_o.is_online,false) or v_o.vehicle_id is distinct from p_vehicle_id
     or v_l.session_id is distinct from v_o.session_id or v_l.rescuer_id is null
     or v_o.last_seen_at<clock_timestamp()-interval '120 seconds'
     or v_l.received_at<clock_timestamp()-interval '120 seconds'
     or v_l.captured_at<clock_timestamp()-interval '120 seconds' or v_l.accuracy_m>100 then
    raise exception 'LOCATION_NOT_FRESH' using errcode='P0001';
  end if;
  insert into private.rescuer_discovery_limits(rescuer_id,window_start,attempts) values(v_uid,clock_timestamp(),1)
    on conflict(rescuer_id) do update set
      attempts=case when private.rescuer_discovery_limits.window_start<clock_timestamp()-interval '1 minute' then 1
        else least(private.rescuer_discovery_limits.attempts+1,30) end,
      window_start=case when private.rescuer_discovery_limits.window_start<clock_timestamp()-interval '1 minute'
        then clock_timestamp() else private.rescuer_discovery_limits.window_start end
    returning attempts into v_attempts;
  if v_attempts>=30 then raise exception 'DISCOVERY_RATE_LIMITED' using errcode='P0001'; end if;
  return v_l;
end;
$$;

create function private.rescuer_available_rows(p_vehicle_id uuid,p_lat double precision,p_lon double precision)
returns table(request_id uuid,latitude double precision,longitude double precision,service_type text,vehicle_type text,distance_km integer)
language sql stable security definer set search_path='' as $$
  with cells as (
    select r.id,r.service_code,r.vehicle_kind,
      least(89.995,floor(r.latitude/0.01)*0.01+0.005) as lat,
      least(179.995,floor(r.longitude/0.01)*0.01+0.005) as lon
    from public.rescue_requests r
    join public.rescue_services s on s.code=r.service_code and s.is_active
    where r.status='searching' and r.provider_id is null and r.customer_id<>auth.uid()
      and r.latitude is not null and r.longitude is not null
      and not exists(select 1 from public.rescue_request_assignments a where a.request_id=r.id)
      and exists(select 1 from public.rescuer_service_capabilities c where c.rescuer_id=auth.uid()
        and c.vehicle_id=p_vehicle_id and c.service_code=r.service_code and c.customer_vehicle_kind=r.vehicle_kind
        and c.verification_status='approved' and c.is_enabled)
  ), distances as (
    select *,6371.0*2*asin(sqrt(least(1.0,greatest(0.0,
      power(sin(radians(lat-p_lat)/2),2)+cos(radians(p_lat))*cos(radians(lat))*power(sin(radians(lon-p_lon)/2),2))))) as km
    from cells
  )
  select id,lat,lon,service_code,vehicle_kind,round(km)::integer from distances where km<=30;
$$;

create function private.rescuer_available_dto(p_id uuid,p_lat double precision,p_lon double precision,p_service text,p_kind text,p_distance integer)
returns jsonb language sql immutable set search_path='' as $$
  select jsonb_build_object('request_id',p_id,'approximate_location',jsonb_build_object(
    'latitude',p_lat,'longitude',p_lon,'cell_size_degrees',0.01,'precision','coarse'),
    'service_type',p_service,'vehicle_type',p_kind,'estimated_distance_km',p_distance);
$$;

create function public.rescuer_list_available_requests(p_vehicle_id uuid,p_limit integer default 20,p_cursor jsonb default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_l public.rescuer_locations; v_id uuid; v_distance integer; v_row record;
  v_items jsonb:='[]'; v_next jsonb; v_count integer:=0;
begin
  if p_limit is null or p_limit not between 1 and 50 then raise exception 'INVALID_LIMIT' using errcode='22023'; end if;
  v_l:=private.rescuer_discovery_context(p_vehicle_id);
  if p_cursor is not null then
    begin
      if jsonb_typeof(p_cursor)<>'object' or (p_cursor->>'session_id')::uuid is distinct from v_l.session_id
         or (p_cursor->>'sequence')::bigint is distinct from v_l.sequence then
        raise exception 'INVALID_CURSOR' using errcode='22023';
      end if;
      v_id:=(p_cursor->>'request_id')::uuid; v_distance:=(p_cursor->>'distance_km')::integer;
      if v_id is null or v_distance is null or v_distance not between 0 and 30 then
        raise exception 'INVALID_CURSOR' using errcode='22023';
      end if;
    exception when invalid_text_representation or numeric_value_out_of_range then
      raise exception 'INVALID_CURSOR' using errcode='22023';
    end;
  end if;
  for v_row in select * from private.rescuer_available_rows(p_vehicle_id,v_l.latitude,v_l.longitude)
      where v_id is null or (distance_km,request_id)>(v_distance,v_id)
      order by distance_km,request_id limit p_limit+1 loop
    v_count:=v_count+1;
    if v_count>p_limit then return jsonb_build_object('items',v_items,'next_cursor',v_next); end if;
    v_items:=v_items || jsonb_build_array(private.rescuer_available_dto(v_row.request_id,v_row.latitude,v_row.longitude,
      v_row.service_type,v_row.vehicle_type,v_row.distance_km));
    v_next:=jsonb_build_object('session_id',v_l.session_id,'sequence',v_l.sequence,'request_id',v_row.request_id,'distance_km',v_row.distance_km);
  end loop;
  return jsonb_build_object('items',v_items,'next_cursor',null);
end;
$$;

create function public.rescuer_get_available_request(p_request_id uuid,p_vehicle_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_l public.rescuer_locations; v_row record;
begin
  v_l:=private.rescuer_discovery_context(p_vehicle_id);
  select * into v_row from private.rescuer_available_rows(p_vehicle_id,v_l.latitude,v_l.longitude) where request_id=p_request_id;
  if not found then raise exception 'REQUEST_UNAVAILABLE' using errcode='P0001'; end if;
  return private.rescuer_available_dto(v_row.request_id,v_row.latitude,v_row.longitude,v_row.service_type,v_row.vehicle_type,v_row.distance_km);
end;
$$;

create function public.rescuer_claim_request(p_request_id uuid,p_vehicle_id uuid,p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_payload jsonb:=jsonb_build_array(p_request_id,p_vehicle_id); v_id uuid; v_l public.rescuer_locations;
begin
  v_id:=private.rescuer_begin_operation('claim_request',p_operation_id,v_payload);
  if v_id is not null then return private.rescuer_assignment_dto(v_id); end if;
  perform 1 from public.rescue_requests where id=p_request_id for update;
  v_l:=private.rescuer_discovery_context(p_vehicle_id);
  if not exists(select 1 from private.rescuer_available_rows(p_vehicle_id,v_l.latitude,v_l.longitude) where request_id=p_request_id) then
    raise exception 'REQUEST_UNAVAILABLE' using errcode='P0001';
  end if;
  insert into public.rescue_request_assignments(request_id,rescuer_id,vehicle_id,state)
    values(p_request_id,auth.uid(),p_vehicle_id,'accepted') returning id into v_id;
  update public.rescue_requests set provider_id=auth.uid(),status='accepted' where id=p_request_id and status='searching' and provider_id is null;
  if not found then raise exception 'REQUEST_UNAVAILABLE' using errcode='P0001'; end if;
  insert into public.rescuer_assignment_events(assignment_id,version,event_kind,state,actor_kind,actor_id)
    values(v_id,1,'claimed','accepted','rescuer',auth.uid());
  perform private.rescuer_commit_receipt('claim_request',p_operation_id,v_payload,v_id);
  return private.rescuer_assignment_dto(v_id);
end;
$$;

-- Request -> assignment locks follow the profile lock taken by begin_operation.
create function private.rescuer_lock_job(p_id uuid,p_expected_version bigint) returns public.rescue_request_assignments
language plpgsql security definer set search_path='' as $$
declare v_a public.rescue_request_assignments; v_request uuid;
begin
  perform private.rescuer_require_profile(true);
  select request_id into v_request from public.rescue_request_assignments where id=p_id and rescuer_id=auth.uid();
  if not found then raise exception 'REQUEST_UNAVAILABLE' using errcode='P0001'; end if;
  perform 1 from public.rescue_requests where id=v_request for update;
  select * into v_a from public.rescue_request_assignments where id=p_id and rescuer_id=auth.uid() for update;
  if v_a.state not in ('accepted','en_route','arrived','in_progress') then
    raise exception 'REQUEST_UNAVAILABLE' using errcode='P0001';
  end if;
  if p_expected_version is null or v_a.version<>p_expected_version then raise exception 'VERSION_CONFLICT' using errcode='P0001'; end if;
  return v_a;
end;
$$;

create function public.rescuer_get_active_job() returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=private.rescuer_auth();
begin
  perform private.rescuer_require_profile(true);
  return (select private.rescuer_assignment_dto(a.id) || jsonb_build_object(
    'service_type',r.service_code,'vehicle_type',r.vehicle_kind,'contact_name',r.contact_name,
    'contact_phone',r.contact_phone,'location_text',r.location_text,'latitude',r.latitude,'longitude',r.longitude,'description',r.description)
    from public.rescue_request_assignments a join public.rescue_requests r on r.id=a.request_id
    join public.rescuer_profiles p on p.user_id=a.rescuer_id and p.verification_status='approved'
    where a.rescuer_id=v_uid and a.state in ('accepted','en_route','arrived','in_progress') and r.provider_id=v_uid
      and r.status in ('accepted','arriving','in_progress'));
end;
$$;

create function public.rescuer_update_job_status(p_assignment_id uuid,p_target_state text,p_reason_code text,
  p_expected_version bigint,p_operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_payload jsonb:=jsonb_build_array(p_assignment_id,p_target_state,p_reason_code,p_expected_version);
  v_id uuid; v_a public.rescue_request_assignments; v_now timestamptz; v_total integer;
begin
  v_id:=private.rescuer_begin_operation('update_job_status',p_operation_id,v_payload);
  if v_id is not null then return private.rescuer_assignment_dto(v_id); end if;
  v_a:=private.rescuer_lock_job(p_assignment_id,p_expected_version);
  if p_target_state is null or not (
      (v_a.state='accepted' and p_target_state='en_route') or (v_a.state='en_route' and p_target_state='arrived')
      or (v_a.state='arrived' and p_target_state='in_progress') or (v_a.state='in_progress' and p_target_state='completed')
      or p_target_state='cancelled') then raise exception 'INVALID_STATUS_TRANSITION' using errcode='22023'; end if;
  if (p_target_state='cancelled' and (p_reason_code is null or p_reason_code not in ('unable_to_continue','safety_issue','vehicle_issue')))
     or (p_target_state<>'cancelled' and p_reason_code is not null) then
    raise exception 'INVALID_CANCELLATION_REASON' using errcode='22023';
  end if;
  if p_target_state='completed' then
    select total_vnd into v_total from public.rescue_quotes where id=v_a.current_quote_id and assignment_id=v_a.id and status='issued';
    if not found then raise exception 'QUOTE_REQUIRED' using errcode='P0001'; end if;
  end if;
  v_now:=clock_timestamp();
  update public.rescue_request_assignments set state=p_target_state,version=version+1,
    en_route_at=case when p_target_state='en_route' then v_now else en_route_at end,
    arrived_at=case when p_target_state='arrived' then v_now else arrived_at end,
    in_progress_at=case when p_target_state='in_progress' then v_now else in_progress_at end,
    completed_at=case when p_target_state='completed' then v_now else completed_at end,
    cancelled_at=case when p_target_state='cancelled' then v_now else cancelled_at end,
    completion_quote_id=case when p_target_state='completed' then current_quote_id else completion_quote_id end,
    cancellation_reason_code=p_reason_code where id=v_a.id;
  update public.rescue_requests set status=case p_target_state when 'en_route' then 'arriving' when 'arrived' then 'arriving' else p_target_state end,
    quoted_price=case when p_target_state='completed' then v_total else quoted_price end where id=v_a.request_id;
  insert into public.rescuer_assignment_events(assignment_id,version,event_kind,previous_state,state,actor_kind,actor_id,reason_code)
    values(v_a.id,v_a.version+1,'status_changed',v_a.state,p_target_state,'rescuer',auth.uid(),p_reason_code);
  perform private.rescuer_commit_receipt('update_job_status',p_operation_id,v_payload,v_a.id);
  return private.rescuer_assignment_dto(v_a.id);
end;
$$;

create function public.rescuer_create_quote(p_assignment_id uuid,p_items jsonb,p_note text,p_expected_version bigint,p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_payload jsonb:=jsonb_build_array(p_assignment_id,p_items,p_note,p_expected_version); v_id uuid;
  v_a public.rescue_request_assignments; v_item jsonb; v_total bigint:=0; v_qty bigint; v_price bigint; v_service text; v_revision integer;
begin
  v_id:=private.rescuer_begin_operation('create_quote',p_operation_id,v_payload);
  if v_id is not null then return private.rescuer_quote_dto(v_id); end if;
  v_a:=private.rescuer_lock_job(p_assignment_id,p_expected_version);
  if v_a.state not in ('arrived','in_progress') then raise exception 'INVALID_STATUS_TRANSITION' using errcode='22023'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' then raise exception 'INVALID_QUOTE' using errcode='22023'; end if;
  if jsonb_array_length(p_items) not between 1 and 20 or length(p_note)>1000 then raise exception 'INVALID_QUOTE' using errcode='22023'; end if;
  select service_code into v_service from public.rescue_requests where id=v_a.request_id;
  for v_item in select value from jsonb_array_elements(p_items) loop
    if jsonb_typeof(v_item)<>'object' then raise exception 'INVALID_QUOTE' using errcode='22023'; end if;
    if (v_item - array['service_code','quantity','unit_price_vnd'])<>'{}'::jsonb
       or jsonb_typeof(v_item->'service_code') is distinct from 'string'
       or v_item->>'service_code' is distinct from v_service
       or jsonb_typeof(v_item->'quantity') is distinct from 'number'
       or jsonb_typeof(v_item->'unit_price_vnd') is distinct from 'number'
       or (v_item->>'quantity') !~ '^[0-9]{1,3}$' or (v_item->>'unit_price_vnd') !~ '^[0-9]{1,10}$' then
      raise exception 'INVALID_QUOTE' using errcode='22023';
    end if;
    v_qty:=(v_item->>'quantity')::bigint; v_price:=(v_item->>'unit_price_vnd')::bigint;
    if v_qty not between 1 and 100 or v_price>2147483647 then raise exception 'INVALID_QUOTE' using errcode='22023'; end if;
    v_total:=v_total+v_qty*v_price;
    if v_total>2147483647 then raise exception 'INVALID_QUOTE' using errcode='22023'; end if;
  end loop;
  select coalesce(max(revision),0)+1 into v_revision from public.rescue_quotes where assignment_id=v_a.id;
  update public.rescue_quotes set status='superseded' where assignment_id=v_a.id and status='issued';
  insert into public.rescue_quotes(assignment_id,request_id,rescuer_id,revision,total_vnd,items,note)
    values(v_a.id,v_a.request_id,auth.uid(),v_revision,v_total::integer,p_items,p_note) returning id into v_id;
  update public.rescue_request_assignments set current_quote_id=v_id,version=version+1 where id=v_a.id;
  update public.rescue_requests set quoted_price=v_total::integer where id=v_a.request_id;
  insert into public.rescuer_assignment_events(assignment_id,version,event_kind,previous_state,state,actor_kind,actor_id)
    values(v_a.id,v_a.version+1,'quote_issued',v_a.state,v_a.state,'rescuer',auth.uid());
  perform private.rescuer_commit_receipt('create_quote',p_operation_id,v_payload,v_id);
  return private.rescuer_quote_dto(v_id);
end;
$$;

create function public.rescuer_get_job_history(p_assignment_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=private.rescuer_auth(); v_result jsonb;
begin
  select private.rescuer_assignment_dto(a.id) || jsonb_build_object('service_type',r.service_code,'vehicle_type',r.vehicle_kind,
    'events',coalesce((select jsonb_agg(jsonb_build_object('version',e.version,'event_kind',e.event_kind,
      'previous_state',e.previous_state,'state',e.state,'actor_kind',e.actor_kind,'reason_code',e.reason_code,'occurred_at',e.occurred_at)
      order by e.version) from public.rescuer_assignment_events e where e.assignment_id=a.id),'[]'::jsonb)) into v_result
    from public.rescue_request_assignments a join public.rescue_requests r on r.id=a.request_id
    where a.id=p_assignment_id and a.rescuer_id=v_uid and a.state in ('completed','cancelled');
  if v_result is null then raise exception 'REQUEST_UNAVAILABLE' using errcode='P0001'; end if;
  return v_result;
end;
$$;

create function public.rescuer_list_job_history(p_limit integer default 20,p_cursor jsonb default null,p_state_filter text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=private.rescuer_auth(); v_time timestamptz; v_id uuid; v_row record; v_count integer:=0; v_items jsonb:='[]'; v_next jsonb;
begin
  if p_limit is null or p_limit not between 1 and 50 or (p_state_filter is not null and p_state_filter not in ('completed','cancelled')) then
    raise exception 'INVALID_HISTORY_FILTER' using errcode='22023';
  end if;
  if p_cursor is not null then
    begin
      v_time:=(p_cursor->>'accepted_at')::timestamptz; v_id:=(p_cursor->>'assignment_id')::uuid;
      if jsonb_typeof(p_cursor)<>'object' or v_time is null or not isfinite(v_time) or v_id is null then
        raise exception 'INVALID_CURSOR' using errcode='22023';
      end if;
    exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow then
      raise exception 'INVALID_CURSOR' using errcode='22023';
    end;
  end if;
  for v_row in select id,accepted_at from public.rescue_request_assignments where rescuer_id=v_uid
      and state in ('completed','cancelled') and (p_state_filter is null or state=p_state_filter)
      and (v_id is null or (accepted_at,id)<(v_time,v_id)) order by accepted_at desc,id desc limit p_limit+1 loop
    v_count:=v_count+1;
    if v_count>p_limit then return jsonb_build_object('items',v_items,'next_cursor',v_next); end if;
    v_items:=v_items || jsonb_build_array(public.rescuer_get_job_history(v_row.id));
    v_next:=jsonb_build_object('accepted_at',v_row.accepted_at,'assignment_id',v_row.id);
  end loop;
  return jsonb_build_object('items',v_items,'next_cursor',null);
end;
$$;

-- Existing customer cancel RPC remains unchanged. No profile lock in this hook.
create function private.rescuer_sync_customer_cancel() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_a public.rescue_request_assignments; v_actor text;
begin
  if new.status<>'cancelled' or old.status='cancelled' then return new; end if;
  select * into v_a from public.rescue_request_assignments where request_id=new.id for update;
  if not found or v_a.state='cancelled' then return new; end if;
  v_actor:=case when auth.uid()=new.customer_id then 'customer' else 'system' end;
  update public.rescue_request_assignments set state='cancelled',version=version+1,cancelled_at=clock_timestamp(),
    cancellation_reason_code=case when v_actor='customer' then 'customer_cancelled' else 'system_cancelled' end where id=v_a.id;
  insert into public.rescuer_assignment_events(assignment_id,version,event_kind,previous_state,state,actor_kind,actor_id,reason_code)
    values(v_a.id,v_a.version+1,case when v_actor='customer' then 'customer_cancelled' else 'status_changed' end,
      v_a.state,'cancelled',v_actor,case when v_actor='customer' then auth.uid() end,
      case when v_actor='customer' then 'customer_cancelled' else 'system_cancelled' end);
  return new;
end;
$$;
create trigger rescuer_customer_cancel after update on public.rescue_requests
  for each row execute function private.rescuer_sync_customer_cancel();

-- Deferred checks examine the final transaction state, including customer cancel.
create function private.rescuer_quote_immutable() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_op='DELETE' then raise exception 'QUOTE_IMMUTABLE' using errcode='23514'; end if;
  if row(new.id,new.assignment_id,new.request_id,new.rescuer_id,new.revision,new.currency,new.total_vnd,new.items,new.note,new.issued_at)
     is distinct from row(old.id,old.assignment_id,old.request_id,old.rescuer_id,old.revision,old.currency,old.total_vnd,old.items,old.note,old.issued_at)
     or (new.status is distinct from old.status and not (old.status='issued' and new.status='superseded')) then
    raise exception 'QUOTE_IMMUTABLE' using errcode='23514';
  end if;
  return new;
end;
$$;
create trigger rescuer_quote_immutable before update or delete on public.rescue_quotes
  for each row execute function private.rescuer_quote_immutable();

-- Legacy requests without an assignment are deliberately left alone.
create function private.rescuer_check_consistency() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_request uuid; v_a public.rescue_request_assignments; v_r public.rescue_requests; v_q public.rescue_quotes; v_status text;
begin
  if tg_table_name='rescue_requests' then v_request:=new.id;
  else v_request:=new.request_id; end if;
  select * into v_a from public.rescue_request_assignments where request_id=v_request;
  if not found then return null; end if;
  select * into v_r from public.rescue_requests where id=v_request;
  v_status:=case v_a.state when 'en_route' then 'arriving' when 'arrived' then 'arriving' else v_a.state end;
  if v_r.id is null or v_r.provider_id is distinct from v_a.rescuer_id or v_r.status is distinct from v_status then
    raise exception 'ASSIGNMENT_REQUEST_INCONSISTENT' using errcode='23514';
  end if;
  if v_a.current_quote_id is not null then
    select * into v_q from public.rescue_quotes where id=v_a.current_quote_id and assignment_id=v_a.id;
    if v_q.id is null or v_q.status<>'issued' or v_r.quoted_price is distinct from v_q.total_vnd then
      raise exception 'ASSIGNMENT_QUOTE_INCONSISTENT' using errcode='23514';
    end if;
  elsif v_r.quoted_price is not null then
    raise exception 'ASSIGNMENT_QUOTE_INCONSISTENT' using errcode='23514';
  end if;
  if v_a.state='completed' and v_a.completion_quote_id is distinct from v_a.current_quote_id then
    raise exception 'COMPLETION_QUOTE_INCONSISTENT' using errcode='23514';
  end if;
  return null;
end;
$$;
create constraint trigger rescuer_request_consistent after insert or update on public.rescue_requests
  deferrable initially deferred for each row execute function private.rescuer_check_consistency();
create constraint trigger rescuer_assignment_consistent after insert or update on public.rescue_request_assignments
  deferrable initially deferred for each row execute function private.rescuer_check_consistency();
create constraint trigger rescuer_quote_consistent after insert or update on public.rescue_quotes
  deferrable initially deferred for each row execute function private.rescuer_check_consistency();

-- Scope ACL changes to functions created here; do not touch shared private helpers.
-- PostgreSQL grants EXECUTE to PUBLIC by default even for SECURITY DEFINER.
do $acl$
declare v_function record;
begin
  for v_function in select p.oid::regprocedure as signature,n.nspname from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('private','public') and p.proname like 'rescuer\_%' escape '\' loop
    execute format('revoke all on function %s from public, anon, authenticated',v_function.signature);
    if v_function.nspname='public' then
      execute format('grant execute on function %s to authenticated',v_function.signature);
    end if;
  end loop;
end;
$acl$;
notify pgrst, 'reload schema';
commit;
