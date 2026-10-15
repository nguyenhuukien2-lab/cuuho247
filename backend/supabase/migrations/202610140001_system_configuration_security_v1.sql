-- Local source only. No credentials, provider switch or payment settlement changes.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';

create table private.system_config_definitions (
  key text primary key,
  section text not null check(section in ('customer','rescuer','payment','security')),
  label text not null,
  kind text not null check(kind in ('boolean','integer','text','permissions')),
  default_value jsonb not null,
  minimum bigint, maximum bigint,
  public_apps text[] not null default '{}',
  dangerous boolean not null default true
);
insert into private.system_config_definitions
  (key,section,label,kind,default_value,minimum,maximum,public_apps,dangerous) values
 ('customer.maintenance','customer','Bảo trì Customer','boolean','false',null,null,'{customer}',true),
 ('customer.requests_enabled','customer','Cho phép tạo yêu cầu','boolean','true',null,null,'{customer}',true),
 ('customer.max_photos','customer','Số ảnh / yêu cầu (tối đa 3)','integer','3',0,3,'{customer}',false),
 ('customer.banner_enabled','customer','Hiển thị banner','boolean','false',null,null,'{customer}',false),
 ('customer.banner','customer','Nội dung banner','text','""',0,500,'{customer}',false),
 ('rescuer.maintenance','rescuer','Bảo trì Rescuer','boolean','false',null,null,'{rescuer}',true),
 ('rescuer.online_enabled','rescuer','Cho phép chuyển online','boolean','true',null,null,'{rescuer}',true),
 ('rescuer.offline_enabled','rescuer','Cho phép chuyển offline','boolean','true',null,null,'{rescuer}',true),
 ('rescuer.max_active_jobs','rescuer','Job đồng thời (V1 hỗ trợ 1)','integer','1',1,1,'{rescuer}',true),
 ('rescuer.quotes_enabled','rescuer','Cho phép báo giá mới','boolean','true',null,null,'{rescuer}',true),
 ('rescuer.quote_min_vnd','rescuer','Báo giá tối thiểu (VND)','integer','0',0,2147483647,'{rescuer}',true),
 ('rescuer.quote_max_vnd','rescuer','Báo giá tối đa (VND)','integer','2147483647',0,2147483647,'{rescuer}',true),
 ('rescuer.bank_payment_visible','rescuer','Hiển thị thanh toán ngân hàng','boolean','true',null,null,'{rescuer}',false),
 ('payment.cash_enabled','payment','Cho phép chọn tiền mặt','boolean','true',null,null,'{customer,rescuer}',true),
 ('payment.bank_enabled','payment','Cho phép tạo QR ngân hàng mới','boolean','true',null,null,'{customer,rescuer}',true),
 ('payment.cash_confirmation_enabled','payment','Cho phép xác nhận tiền mặt','boolean','true',null,null,'{rescuer}',true),
 ('payment.min_vnd','payment','Thanh toán tối thiểu (VND)','integer','1',1,2147483647,'{customer}',true),
 ('payment.max_vnd','payment','Thanh toán tối đa (VND)','integer','2147483647',1,9999999999999,'{customer}',true),
 ('payment.qr_expiry_seconds','payment','QR hết hạn (giây, chỉ QR mới)','integer','900',60,86400,'{customer}',true),
 ('business.platform_fee_bps','payment','Phí nền tảng dự kiến (basis points, 100 = 1%)','integer','0',0,10000,'{}',true),
 ('business.rescuer_commission_bps','payment','Hoa hồng đối tác dự kiến (basis points)','integer','0',0,10000,'{}',true),
 ('business.customer_cancellation_enabled','payment','Cho phép khách hủy yêu cầu','boolean','true',null,null,'{customer}',true),
 ('business.refunds_enabled','payment','Cho phép mở refund mới','boolean','true',null,null,'{}',true),
 ('business.late_refunds_enabled','payment','Cho phép mở refund late payment','boolean','true',null,null,'{}',true),
 ('security.kill_new_requests','security','Dừng tạo yêu cầu khẩn cấp','boolean','false',null,null,'{customer}',true),
 ('security.kill_new_jobs','security','Dừng nhận job khẩn cấp','boolean','false',null,null,'{rescuer}',true),
 ('security.kill_new_bank_intents','security','Dừng tạo QR khẩn cấp','boolean','false',null,null,'{customer}',true),
 ('security.max_token_age_seconds','security','Tuổi JWT tối đa (0 = theo Auth hiện tại)','integer','0',0,86400,'{}',true),
 ('security.admin_mfa_required','security','Bắt buộc Admin AAL2 / MFA','boolean','false',null,null,'{}',true),
 ('security.role_permissions','security','Vai trò được sửa từng nhóm','permissions',
  '{"customer":["super_admin","operator"],"rescuer":["super_admin","operator"],"payment":["super_admin","finance"],"security":["super_admin"]}',null,null,'{}',true);

create table private.system_config (
  singleton boolean primary key default true check(singleton),
  version bigint not null default 1 check(version>0),
  values jsonb not null check(jsonb_typeof(values)='object'),
  updated_at timestamptz not null default clock_timestamp(),
  updated_by uuid
);
insert into private.system_config(values)
 select jsonb_object_agg(key,case when key='payment.qr_expiry_seconds'
   then to_jsonb(coalesce((select expiry_seconds from private.payment_bank_config limit 1),900))
   else default_value end) from private.system_config_definitions;

create table private.system_account_controls (
  user_id uuid primary key references auth.users(id) on delete restrict,
  status text not null check(status in ('active','locked','suspended')),
  suspended_until timestamptz,
  tokens_valid_after timestamptz,
  version bigint not null check(version>0),
  updated_at timestamptz not null default clock_timestamp()
);
create table private.system_config_audit (
  id bigint generated always as identity primary key,
  actor_id uuid not null,
  action text not null,
  target text not null,
  version bigint not null,
  before_value jsonb not null,
  after_value jsonb not null,
  reason text not null check(length(btrim(reason)) between 5 and 500),
  created_at timestamptz not null default clock_timestamp()
);
create index system_config_audit_time on private.system_config_audit(id desc);
-- Prospective policy snapshot only; V1 never adds a charge or rewrites quote/payment amounts.
create table private.system_quote_policy_snapshots (
  quote_id uuid primary key references public.rescue_quotes(id) on delete restrict,
  config_version bigint not null,
  platform_fee_bps integer not null,
  rescuer_commission_bps integer not null,
  created_at timestamptz not null default clock_timestamp()
);

create function private.system_immutable() returns trigger
language plpgsql security definer set search_path='' as $$
begin raise exception 'SYSTEM_AUDIT_IMMUTABLE' using errcode='23514'; end;
$$;
create trigger system_audit_immutable before update or delete or truncate on private.system_config_audit
 for each statement execute function private.system_immutable();
create trigger system_quote_policy_immutable before update or delete or truncate on private.system_quote_policy_snapshots
 for each statement execute function private.system_immutable();

create function private.system_value(p_key text) returns jsonb
language sql stable security definer set search_path='' as $$
 select values->p_key from private.system_config where singleton
$$;

-- Explicit public projection: no arbitrary JSON, beneficiary, role matrix or credentials.
create function public.get_public_system_config(p_app text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if p_app is null or p_app not in ('customer','rescuer') then
   raise exception 'SYSTEM_INVALID_APP' using errcode='22023'; end if;
 select jsonb_build_object('version',s.version::text,'updated_at',s.updated_at,
   'values',(select coalesce(jsonb_object_agg(d.key,s.values->d.key),'{}'::jsonb)
     from private.system_config_definitions d where p_app=any(d.public_apps))) into result
 from private.system_config s where singleton;
 return result;
end;
$$;

-- Used both by restrictive RLS and definer RPCs (which otherwise bypass RLS).
create function public.system_session_allowed() returns boolean
language plpgsql stable security definer set search_path='' as $$
declare uid uuid:=auth.uid(); c private.system_account_controls;
 claims jsonb:=coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}');
 max_age integer; issued numeric;
begin
 if uid is null then return false; end if;
 select * into c from private.system_account_controls where user_id=uid;
 if c.status='locked' or (c.status='suspended' and
   (c.suspended_until is null or c.suspended_until>statement_timestamp())) then return false; end if;
 max_age:=(private.system_value('security.max_token_age_seconds'))::integer;
 if c.tokens_valid_after is not null or max_age>0 then
   if coalesce(claims->>'iat','') !~ '^[0-9]{1,12}$' then return false; end if;
   issued:=(claims->>'iat')::numeric;
   if issued>extract(epoch from statement_timestamp())+30 then return false; end if;
   if c.tokens_valid_after is not null and issued<=extract(epoch from c.tokens_valid_after) then return false; end if;
   if max_age>0 and extract(epoch from statement_timestamp())-issued>max_age then return false; end if;
 end if;
 if (private.system_value('security.admin_mfa_required'))::boolean and exists(
   select 1 from public.admin_profiles where id=uid and status='active') and
   coalesce(claims->>'aal','')<>'aal2' then return false; end if;
 return true;
end;
$$;
create function private.system_require_session() returns void
language plpgsql stable security definer set search_path='' as $$
begin
 if not public.system_session_allowed() then raise exception 'SYSTEM_SESSION_DENIED' using errcode='42501'; end if;
end;
$$;

create function private.system_require_permission(p_section text,p_permissions jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare actor_role text;
begin
 perform private.system_require_session();
 perform private.admin_require_role(array['super_admin','operator','support','partner_reviewer','finance']);
 select role into actor_role from public.admin_profiles where id=auth.uid();
 if not coalesce((p_permissions->p_section) ? actor_role,false) then
   raise exception 'SYSTEM_CONFIG_FORBIDDEN' using errcode='42501'; end if;
end;
$$;

create function public.admin_get_system_config() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform private.system_require_session();
 perform private.admin_require_role_readonly(array['super_admin','operator','support','partner_reviewer','finance']);
 select jsonb_build_object('version',s.version::text,'updated_at',s.updated_at,
   'values',s.values,'definitions',(select jsonb_agg(to_jsonb(d) order by d.section,d.key)
    from private.system_config_definitions d),
   'editable_sections',(select coalesce(jsonb_agg(e.key),'[]'::jsonb) from
    jsonb_each(s.values->'security.role_permissions') e where e.value ? a.role)) into result
 from private.system_config s join public.admin_profiles a on a.id=auth.uid() where singleton;
 return result;
end;
$$;

create function public.admin_apply_system_config(p_patch jsonb,p_expected_version bigint,p_reason text,p_confirm_dangerous boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s private.system_config; d private.system_config_definitions; k text; v jsonb; merged jsonb;
 roles jsonb; role_name text; group_name text;
begin
 perform private.system_require_session();
 perform private.admin_require_role(array['super_admin','operator','support','partner_reviewer','finance']);
 if p_patch is null or jsonb_typeof(p_patch)<>'object' or p_patch='{}' or
   length(btrim(p_reason)) not between 5 and 500 or p_reason is null or p_expected_version is null then
   raise exception 'SYSTEM_CONFIG_INVALID' using errcode='22023'; end if;
 select * into s from private.system_config where singleton for update;
 if s.version<>p_expected_version then raise exception 'SYSTEM_CONFIG_VERSION_CONFLICT' using errcode='40001'; end if;
 for k,v in select * from jsonb_each(p_patch) loop
   select * into d from private.system_config_definitions where key=k;
   if not found then raise exception 'SYSTEM_CONFIG_UNKNOWN_KEY' using errcode='22023'; end if;
   perform private.system_require_permission(d.section,s.values->'security.role_permissions');
   if d.dangerous and v is distinct from s.values->k and p_confirm_dangerous is distinct from true then
     raise exception 'SYSTEM_CONFIG_CONFIRMATION_REQUIRED' using errcode='22023'; end if;
   if v='null'::jsonb or (d.kind='boolean' and jsonb_typeof(v)<>'boolean') or
      (d.kind='text' and (jsonb_typeof(v)<>'string' or length(v#>>'{}')>d.maximum)) or
      (d.kind='integer' and (jsonb_typeof(v)<>'number' or (v#>>'{}') !~ '^[0-9]{1,13}$')) then
     raise exception 'SYSTEM_CONFIG_INVALID_VALUE: %',k using errcode='22023'; end if;
   if d.kind='integer' and (v::numeric<d.minimum or v::numeric>d.maximum) then
     raise exception 'SYSTEM_CONFIG_OUT_OF_RANGE: %',k using errcode='22023'; end if;
   if d.kind='permissions' then
     if jsonb_typeof(v)<>'object' or (select count(*) from jsonb_object_keys(v))<>4 or
       not (v ?& array['customer','rescuer','payment','security']) then
       raise exception 'SYSTEM_CONFIG_INVALID_PERMISSIONS' using errcode='22023'; end if;
     for group_name,roles in select * from jsonb_each(v) loop
       if jsonb_typeof(roles)<>'array' then raise exception 'SYSTEM_CONFIG_INVALID_PERMISSIONS' using errcode='22023'; end if;
       if jsonb_array_length(roles) not between 1 and 5 or not (roles ? 'super_admin') or
          (group_name='security' and roles<>'["super_admin"]') then
         raise exception 'SYSTEM_CONFIG_INVALID_PERMISSIONS' using errcode='22023'; end if;
       if exists(select 1 from jsonb_array_elements(roles) e(value) where jsonb_typeof(e.value) is distinct from 'string')
          or (select count(*)<>count(distinct e.value) from jsonb_array_elements(roles) e(value)) then
         raise exception 'SYSTEM_CONFIG_INVALID_PERMISSIONS' using errcode='22023'; end if;
       for role_name in select jsonb_array_elements_text(roles) loop
         if role_name is null or role_name not in ('super_admin','operator','support','partner_reviewer','finance') then
           raise exception 'SYSTEM_CONFIG_INVALID_PERMISSIONS' using errcode='22023'; end if;
       end loop;
     end loop;
   end if;
 end loop;
 merged:=s.values||p_patch;
 if (merged->'payment.min_vnd')::numeric>(merged->'payment.max_vnd')::numeric or
    (merged->'rescuer.quote_min_vnd')::numeric>(merged->'rescuer.quote_max_vnd')::numeric or
    (merged->'business.platform_fee_bps')::integer+(merged->'business.rescuer_commission_bps')::integer>10000 then
   raise exception 'SYSTEM_CONFIG_INCONSISTENT' using errcode='22023'; end if;
 if merged->'security.admin_mfa_required'='true' and s.values->'security.admin_mfa_required'='false' and
    coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'aal','')<>'aal2' then
   raise exception 'SYSTEM_MFA_ENROLLMENT_REQUIRED' using errcode='22023'; end if;
 if merged=s.values then return public.admin_get_system_config(); end if;
 -- Keep the one existing expiry source used by both select/regenerate. Never alter an intent snapshot.
 if merged->'payment.qr_expiry_seconds' is distinct from s.values->'payment.qr_expiry_seconds' then
   update private.payment_bank_config set expiry_seconds=(merged->'payment.qr_expiry_seconds')::integer;
 end if;
 update private.system_config set values=merged,version=version+1,updated_at=clock_timestamp(),updated_by=auth.uid() where singleton;
 insert into private.system_config_audit(actor_id,action,target,version,before_value,after_value,reason)
 values(auth.uid(),'config_update','system',s.version+1,s.values,merged,btrim(p_reason));
 return public.admin_get_system_config();
end;
$$;

create function public.admin_list_system_config_audit(p_before_id bigint default null,p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform private.system_require_session();
 perform private.admin_require_role_readonly(array['super_admin','operator','support','partner_reviewer','finance']);
 if p_limit is null or p_limit not between 1 and 100 or p_before_id<=0 then
   raise exception 'SYSTEM_CONFIG_INVALID' using errcode='22023'; end if;
 return jsonb_build_object('rows',(select coalesce(jsonb_agg(to_jsonb(x)||jsonb_build_object('id',x.id::text,'version',x.version::text) order by x.id desc),'[]') from
   (select * from private.system_config_audit where p_before_id is null or id<p_before_id order by id desc limit p_limit) x));
end;
$$;

create function public.admin_get_system_account_control(p_user_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare c private.system_account_controls;
begin
 perform private.system_require_session();
 perform private.admin_require_role_readonly(array['super_admin']);
 if not exists(select 1 from auth.users where id=p_user_id) then raise exception 'SYSTEM_ACCOUNT_NOT_FOUND' using errcode='P0002'; end if;
 select * into c from private.system_account_controls where user_id=p_user_id;
 return jsonb_build_object('user_id',p_user_id,'status',coalesce(c.status,'active'),'version',coalesce(c.version,0)::text,
   'suspended_until',c.suspended_until,'tokens_valid_after',c.tokens_valid_after,
   'admin_access',(select jsonb_build_object('role',role,'status',status,'updated_at',updated_at) from public.admin_profiles where id=p_user_id));
end;
$$;

create function public.admin_apply_system_admin_access(p_user_id uuid,p_role text,p_status text,
 p_expected_updated_at timestamptz,p_reason text,p_confirm_dangerous boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.admin_profiles; after_value jsonb;
begin
 perform private.system_require_session();
 perform private.admin_require_role(array['super_admin']);
 if p_confirm_dangerous is distinct from true then raise exception 'SYSTEM_CONFIG_CONFIRMATION_REQUIRED' using errcode='22023'; end if;
 if p_user_id=auth.uid() then raise exception 'SYSTEM_CANNOT_CHANGE_OWN_ACCESS' using errcode='22023'; end if;
 if p_role is null or p_role not in ('super_admin','operator','support','partner_reviewer','finance') or
   p_status is null or p_status not in ('active','blocked') or p_expected_updated_at is null or
   p_reason is null or length(btrim(p_reason)) not between 5 and 500 then
   raise exception 'SYSTEM_CONFIG_INVALID' using errcode='22023'; end if;
 select * into a from public.admin_profiles where id=p_user_id for update;
 if not found then raise exception 'SYSTEM_ADMIN_NOT_FOUND' using errcode='P0002'; end if;
 if a.updated_at<>p_expected_updated_at then raise exception 'SYSTEM_CONFIG_VERSION_CONFLICT' using errcode='40001'; end if;
 update public.admin_profiles set role=p_role,status=p_status where id=p_user_id
 returning jsonb_build_object('role',role,'status',status,'updated_at',updated_at) into after_value;
 insert into private.system_config_audit(actor_id,action,target,version,before_value,after_value,reason)
 values(auth.uid(),'admin_access',p_user_id::text,
  (select coalesce(max(version),0)+1 from private.system_config_audit where action='admin_access' and target=p_user_id::text),
  jsonb_build_object('role',a.role,'status',a.status,'updated_at',a.updated_at),after_value,btrim(p_reason));
 return public.admin_get_system_account_control(p_user_id);
end;
$$;
create function public.admin_apply_system_account_control(p_user_id uuid,p_status text,p_suspended_until timestamptz,
 p_revoke_tokens boolean,p_expected_version bigint,p_reason text,p_confirm_dangerous boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c private.system_account_controls; old_value jsonb;
begin
 perform private.system_require_session();
 perform private.admin_require_role(array['super_admin']);
 if p_confirm_dangerous is distinct from true then raise exception 'SYSTEM_CONFIG_CONFIRMATION_REQUIRED' using errcode='22023'; end if;
 if p_user_id=auth.uid() then raise exception 'SYSTEM_CANNOT_CHANGE_OWN_ACCESS' using errcode='22023'; end if;
 if p_status is null or p_status not in ('active','locked','suspended') or p_revoke_tokens is null or
   p_expected_version is null or p_expected_version<0 or p_reason is null or length(btrim(p_reason)) not between 5 and 500 or
   (p_suspended_until is not null and (p_status<>'suspended' or not isfinite(p_suspended_until) or p_suspended_until<=clock_timestamp())) then
   raise exception 'SYSTEM_CONFIG_INVALID' using errcode='22023'; end if;
 -- Locks the actual identity even when no control row exists (concurrent initial insert).
 perform 1 from auth.users where id=p_user_id for update;
 if not found then raise exception 'SYSTEM_ACCOUNT_NOT_FOUND' using errcode='P0002'; end if;
 select * into c from private.system_account_controls where user_id=p_user_id for update;
 if coalesce(c.version,0)<>p_expected_version then raise exception 'SYSTEM_CONFIG_VERSION_CONFLICT' using errcode='40001'; end if;
 old_value:=coalesce(to_jsonb(c),'{}');
 insert into private.system_account_controls(user_id,status,suspended_until,tokens_valid_after,version)
 values(p_user_id,p_status,p_suspended_until,case when p_revoke_tokens then clock_timestamp() else c.tokens_valid_after end,coalesce(c.version,0)+1)
 on conflict(user_id) do update set status=excluded.status,suspended_until=excluded.suspended_until,
   tokens_valid_after=excluded.tokens_valid_after,version=excluded.version,updated_at=clock_timestamp();
 select * into c from private.system_account_controls where user_id=p_user_id;
 insert into private.system_config_audit(actor_id,action,target,version,before_value,after_value,reason)
 values(auth.uid(),'account_control',p_user_id::text,c.version,old_value,to_jsonb(c),btrim(p_reason));
 return public.admin_get_system_account_control(p_user_id);
end;
$$;

-- Actual-write gates preserve idempotent replay and never stop processing existing bank receipts.
create function private.system_domain_guard() returns trigger
language plpgsql security definer set search_path='' as $$
declare s jsonb; enabled boolean; n bigint;
begin
 select values into s from private.system_config where singleton;
 if tg_table_name='rescue_requests' then
   if tg_op='INSERT' then
     if (s->'customer.maintenance')::boolean or not (s->'customer.requests_enabled')::boolean or
       (s->'security.kill_new_requests')::boolean then raise exception 'SYSTEM_REQUESTS_DISABLED' using errcode='P0001'; end if;
   elsif new.status='cancelled' and old.status is distinct from new.status and auth.uid()=old.customer_id and
       not (s->'business.customer_cancellation_enabled')::boolean then
     raise exception 'SYSTEM_CANCELLATION_DISABLED' using errcode='P0001';
   end if;
 elsif tg_table_name='rescue_request_photos' then
   perform 1 from public.rescue_requests where id=new.request_id for update;
   select count(*) into n from public.rescue_request_photos where request_id=new.request_id;
   if n>=(s->'customer.max_photos')::integer then raise exception 'PHOTO_LIMIT_REACHED' using errcode='22023'; end if;
 elsif tg_table_name='rescuer_online_status' then
   -- Provisioning an offline row and refreshing an unchanged presence remain possible.
   if new.is_online and (tg_op='INSERT' or old.is_online is distinct from new.is_online or old.vehicle_id is distinct from new.vehicle_id) then
     if (s->'rescuer.maintenance')::boolean or not (s->'rescuer.online_enabled')::boolean then
       raise exception 'SYSTEM_ONLINE_DISABLED' using errcode='P0001'; end if;
   elsif tg_op='UPDATE' and old.is_online and not new.is_online and auth.uid()=new.rescuer_id and
     not (s->'rescuer.offline_enabled')::boolean then raise exception 'SYSTEM_OFFLINE_DISABLED' using errcode='P0001'; end if;
 elsif tg_table_name='rescue_request_assignments' then
   if (s->'rescuer.maintenance')::boolean or (s->'security.kill_new_jobs')::boolean then
     raise exception 'SYSTEM_NEW_JOBS_DISABLED' using errcode='P0001'; end if;
   -- Existing partial unique indexes serialize the one-job V1 contract.
 elsif tg_table_name='rescue_quotes' then
   if not (s->'rescuer.quotes_enabled')::boolean then raise exception 'SYSTEM_QUOTES_DISABLED' using errcode='P0001'; end if;
   if new.total_vnd<(s->'rescuer.quote_min_vnd')::bigint or new.total_vnd>(s->'rescuer.quote_max_vnd')::bigint then
     raise exception 'SYSTEM_QUOTE_LIMIT' using errcode='22023'; end if;
 elsif tg_table_name='payments' then
   if tg_op='UPDATE' then
     if old.method is null and new.method='cash' and not (s->'payment.cash_enabled')::boolean then
       raise exception 'SYSTEM_CASH_DISABLED' using errcode='P0001'; end if;
     if new.method='cash' and new.status='paid' and old.status is distinct from new.status and
       not (s->'payment.cash_confirmation_enabled')::boolean then raise exception 'SYSTEM_CASH_CONFIRMATION_DISABLED' using errcode='P0001'; end if;
   end if;
   -- Limits apply at method selection, not settlement of a previously selected method.
   if tg_op='UPDATE' and old.method is null and new.method is not null and
     (new.amount_expected<(s->'payment.min_vnd')::bigint or new.amount_expected>(s->'payment.max_vnd')::bigint) then
     raise exception 'SYSTEM_PAYMENT_LIMIT' using errcode='22023'; end if;
 elsif tg_table_name='payment_bank_intents' then
   if not (s->'payment.bank_enabled')::boolean or (s->'security.kill_new_bank_intents')::boolean then
     raise exception 'SYSTEM_BANK_DISABLED' using errcode='P0001'; end if;
 elsif tg_table_name='payment_refunds' then
   if not (s->'business.refunds_enabled')::boolean or
     (new.source_kind='late_bank_transaction' and not (s->'business.late_refunds_enabled')::boolean) then
     raise exception 'SYSTEM_REFUNDS_DISABLED' using errcode='P0001'; end if;
 end if;
 return new;
end;
$$;
create trigger system_config_gate before insert or update on public.rescue_requests for each row execute function private.system_domain_guard();
create trigger system_config_gate before insert on public.rescue_request_photos for each row execute function private.system_domain_guard();
create trigger system_config_gate before insert or update on public.rescuer_online_status for each row execute function private.system_domain_guard();
create trigger system_config_gate before insert on public.rescue_request_assignments for each row execute function private.system_domain_guard();
create trigger system_config_gate before insert on public.rescue_quotes for each row execute function private.system_domain_guard();
create trigger system_config_gate before update on public.payments for each row execute function private.system_domain_guard();
create trigger system_config_gate before insert on private.payment_bank_intents for each row execute function private.system_domain_guard();
create trigger system_config_gate before insert on private.payment_refunds for each row execute function private.system_domain_guard();

create function private.system_bank_config_defaults() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 -- Provisioning after V1 reads the central default; existing reservations keep their exact expiry.
 new.expiry_seconds:=(private.system_value('payment.qr_expiry_seconds'))::integer;
 return new;
end;
$$;
create trigger system_config_defaults before insert on private.payment_bank_config for each row execute function private.system_bank_config_defaults();

create function private.system_snapshot_quote_policy() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into private.system_quote_policy_snapshots(quote_id,config_version,platform_fee_bps,rescuer_commission_bps)
 select new.id,version,(values->'business.platform_fee_bps')::integer,(values->'business.rescuer_commission_bps')::integer
 from private.system_config where singleton;
 return new;
end;
$$;
create trigger system_quote_policy after insert on public.rescue_quotes for each row execute function private.system_snapshot_quote_policy();

-- Secure existing exposed PL/pgSQL RPCs without changing signatures, grants,
-- volatility or their payment algorithms. Catalog preconditions fail on an unknown body shape.
do $secure_existing$
declare f record; body text; definition text;
begin
 for f in select p.oid,p.proname,p.prosrc from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   join pg_language l on l.oid=p.prolang
   where n.nspname='public' and l.lanname='plpgsql' and p.prosecdef and p.prorettype<>'trigger'::regtype
     and has_function_privilege('authenticated',p.oid,'execute')
     and p.proname not in ('get_public_system_config','system_session_allowed')
     and p.proname not like 'admin_%system%'
 loop
   if f.prosrc like '%private.system_require_session()%' then continue; end if;
   body:=regexp_replace(f.prosrc,'\mBEGIN\M','BEGIN IF auth.uid() IS NOT NULL THEN PERFORM private.system_require_session(); END IF;','i');
   if body=f.prosrc then raise exception 'SYSTEM_RPC_GUARD_UNSUPPORTED: %',f.proname; end if;
   definition:=replace(pg_get_functiondef(f.oid),f.prosrc,body);
   execute definition;
 end loop;
end;
$secure_existing$;

-- SQL membership helpers are also used by definer Admin views.
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path='' as $$
 select public.system_session_allowed() and exists(select 1 from public.admin_profiles where id=auth.uid() and status='active')
$$;
create or replace function public.has_admin_role(required_roles text[]) returns boolean
language sql stable security definer set search_path='' as $$
 select public.system_session_allowed() and exists(select 1 from public.admin_profiles where id=auth.uid() and status='active' and role=any(required_roles))
$$;

-- Prevent legacy direct Admin-profile DML; mutation now requires server-side role checks.
revoke insert,update,delete on public.admin_profiles from anon,authenticated;
do $revoke_columns$
declare c record;
begin
 for c in select attname from pg_attribute where attrelid='public.admin_profiles'::regclass and attnum>0 and not attisdropped loop
   execute format('revoke insert(%I),update(%I) on public.admin_profiles from anon,authenticated',c.attname,c.attname);
 end loop;
end;
$revoke_columns$;

-- Restrictive policies cannot broaden any existing participant/owner policy.
do $rls$
declare t record;
begin
 for t in select n.nspname,c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where (n.nspname='public' or (n.nspname='storage' and c.relname='objects'))
     and c.relkind='r' and c.relrowsecurity loop
   execute format('create policy system_session_gate on %I.%I as restrictive for all to authenticated using ((select public.system_session_allowed())) with check ((select public.system_session_allowed()))',t.nspname,t.relname);
 end loop;
end;
$rls$;

do $acl$
declare t text; f record;
begin
 foreach t in array array['system_config_definitions','system_config','system_account_controls','system_config_audit','system_quote_policy_snapshots'] loop
   execute format('alter table private.%I enable row level security',t);
   execute format('revoke all on private.%I from public,anon,authenticated,service_role',t);
 end loop;
 revoke all on sequence private.system_config_audit_id_seq from public,anon,authenticated,service_role;
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='private' and p.proname like 'system_%' loop
   execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
 end loop;
end;
$acl$;
revoke all on function public.get_public_system_config(text),public.system_session_allowed(),public.admin_get_system_config(),
 public.admin_apply_system_config(jsonb,bigint,text,boolean),public.admin_list_system_config_audit(bigint,integer),
 public.admin_get_system_account_control(uuid),public.admin_apply_system_account_control(uuid,text,timestamptz,boolean,bigint,text,boolean)
 ,public.admin_apply_system_admin_access(uuid,text,text,timestamptz,text,boolean)
 from public,anon,authenticated,service_role;
grant execute on function public.get_public_system_config(text) to anon,authenticated;
grant execute on function public.system_session_allowed(),public.admin_get_system_config(),
 public.admin_apply_system_config(jsonb,bigint,text,boolean),public.admin_list_system_config_audit(bigint,integer),
 public.admin_get_system_account_control(uuid),public.admin_apply_system_account_control(uuid,text,timestamptz,boolean,bigint,text,boolean) to authenticated;
revoke all on function public.admin_apply_system_admin_access(uuid,text,text,timestamptz,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.admin_apply_system_admin_access(uuid,text,text,timestamptz,text,boolean) to authenticated;
commit;
