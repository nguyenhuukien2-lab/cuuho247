-- Notifications & Monitoring V1. Additive observability only; payment settlement,
-- SePay matching and participant workflows remain unchanged.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';

do $preflight$
begin
  if pg_catalog.to_regprocedure('private.process_verified_bank_transaction(jsonb)') is null
     or pg_catalog.to_regprocedure('private.admin_require_role_readonly(text[])') is null
     or pg_catalog.to_regprocedure('private.system_value(text)') is null
     or pg_catalog.to_regclass('private.payment_webhook_receipts') is null
     or pg_catalog.to_regclass('private.bank_transactions') is null
     or pg_catalog.to_regclass('private.system_config_audit') is null
     or pg_catalog.to_regclass('public.payments') is null then
    raise exception 'SYSTEM_MONITORING_MISSING_PREREQUISITES';
  end if;
  if pg_catalog.to_regclass('private.system_webhook_attempts') is not null
     or pg_catalog.to_regprocedure('public.admin_get_system_monitoring(integer,integer)') is not null then
    raise exception 'SYSTEM_MONITORING_ALREADY_EXISTS';
  end if;
end;
$preflight$;

-- The Edge Function writes only allowlisted operational metadata. Payloads,
-- headers, signatures, account numbers and secrets have no columns here.
create table private.system_webhook_attempts (
  id bigint generated always as identity primary key,
  provider text not null check(provider ~ '^[a-z][a-z0-9_]{0,63}$'),
  provider_scope text not null check(length(provider_scope) between 1 and 128),
  http_status integer not null check(http_status in (200,400,401,405,413,415,500)),
  result_code text not null check(result_code ~ '^[a-z][a-z0-9_]{0,63}$'),
  stage text not null check(stage ~ '^[a-z][a-z0-9_]{0,63}$'),
  body_sha256 text check(body_sha256 ~ '^[0-9a-f]{64}$'),
  duration_ms integer not null check(duration_ms between 0 and 300000),
  occurred_at timestamptz not null default clock_timestamp() check(isfinite(occurred_at))
);
create index system_webhook_attempts_time_idx on private.system_webhook_attempts(occurred_at desc,id desc);
create index system_webhook_attempts_status_time_idx on private.system_webhook_attempts(http_status,occurred_at desc);

-- Acknowledgements are append-only and idempotent. They do not hide the source
-- incident; they only record that an authorized operator accepted the alert.
create table private.system_alert_acknowledgements (
  id uuid primary key default gen_random_uuid(),
  alert_key text not null check(length(alert_key) between 3 and 200),
  fingerprint text not null check(fingerprint ~ '^[0-9a-f]{64}$'),
  actor_id uuid not null references public.admin_profiles(id) on delete restrict,
  operation_id uuid not null,
  acknowledged_at timestamptz not null default clock_timestamp() check(isfinite(acknowledged_at)),
  unique(alert_key,fingerprint),
  unique(actor_id,operation_id)
);
create index system_alert_ack_time_idx on private.system_alert_acknowledgements(acknowledged_at desc,id);

alter table private.system_webhook_attempts enable row level security;
alter table private.system_alert_acknowledgements enable row level security;
revoke all on table private.system_webhook_attempts,private.system_alert_acknowledgements
  from public,anon,authenticated,service_role;
revoke all on sequence private.system_webhook_attempts_id_seq from public,anon,authenticated,service_role;

create function private.system_monitoring_immutable() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  raise exception 'SYSTEM_MONITORING_AUDIT_IMMUTABLE' using errcode='23514';
end;
$$;
create trigger system_webhook_attempts_immutable before update or delete or truncate
  on private.system_webhook_attempts for each statement execute function private.system_monitoring_immutable();
create trigger system_alert_ack_immutable before update or delete or truncate
  on private.system_alert_acknowledgements for each statement execute function private.system_monitoring_immutable();

create function private.record_bank_webhook_attempt(
  p_provider text,p_provider_scope text,p_http_status integer,p_result_code text,
  p_stage text,p_body_sha256 text,p_duration_ms integer
) returns void language plpgsql security invoker set search_path='' as $$
begin
  if p_provider is null or p_provider !~ '^[a-z][a-z0-9_]{0,63}$'
     or p_provider_scope is null or length(p_provider_scope) not between 1 and 128
     or p_http_status not in (200,400,401,405,413,415,500)
     or p_result_code is null or p_result_code !~ '^[a-z][a-z0-9_]{0,63}$'
     or p_stage is null or p_stage !~ '^[a-z][a-z0-9_]{0,63}$'
     or (p_body_sha256 is not null and p_body_sha256 !~ '^[0-9a-f]{64}$')
     or p_duration_ms is null or p_duration_ms not between 0 and 300000 then
    raise exception 'SYSTEM_WEBHOOK_ATTEMPT_INVALID' using errcode='22023';
  end if;
  insert into private.system_webhook_attempts(provider,provider_scope,http_status,result_code,stage,body_sha256,duration_ms)
  values(p_provider,p_provider_scope,p_http_status,p_result_code,p_stage,p_body_sha256,p_duration_ms);
end;
$$;

-- One authoritative alert rule set is reused by reads and acknowledgement
-- validation. Details are an explicit safe projection and never include digests,
-- transfer references, beneficiary/account data, raw metadata or config values.
create function private.system_monitoring_alerts(p_window_start timestamptz)
returns table(
  alert_key text,fingerprint text,severity text,category text,code text,title text,message text,
  detected_at timestamptz,entity_type text,entity_id text,detail jsonb
) language sql stable security definer set search_path='' as $$
with raw_alerts as (
  select 'config:bank_disabled'::text alert_key,'critical'::text severity,'payment'::text category,
    'bank_payment_config_disabled'::text code,'Thanh toán ngân hàng đang tắt'::text title,
    'Cấu hình nhận thanh toán ngân hàng đang bị vô hiệu hóa.'::text message,
    pg_catalog.statement_timestamp() detected_at,'payment_config'::text entity_type,null::text entity_id,
    pg_catalog.jsonb_build_object('config_version',c.version::text) detail,c.version::text fingerprint_source
  from private.payment_bank_config c where not c.enabled
  union all
  select 'config:bank_switch_disabled','critical','payment','bank_payment_config_disabled','Thanh toán ngân hàng bị khóa bởi hệ thống',
    'Cấu hình hệ thống payment.bank_enabled đang bị vô hiệu hóa.',pg_catalog.statement_timestamp(),
    'system_config',null,pg_catalog.jsonb_build_object('config_version',s.version::text),s.version::text
  from private.system_config s where (s.values->'payment.bank_enabled')::boolean is false
  union all
  select 'config:verification_disabled','critical','webhook','verification_disabled','Xác minh webhook đang tắt',
    'SePay có thể nhận webhook nhưng không thể xác minh và quyết toán giao dịch.',pg_catalog.statement_timestamp(),
    'payment_config',null,pg_catalog.jsonb_build_object('provider',c.verification_provider,'config_version',c.version::text),c.version::text
  from private.payment_bank_config c where not c.verification_enabled
  union all
  select 'webhook:401_burst','critical','webhook','multiple_invalid_signature','Webhook bị từ chối liên tục',
    'Có từ 3 lần webhook 401 trong 15 phút gần nhất.',pg_catalog.max(a.occurred_at),'webhook',null,
    pg_catalog.jsonb_build_object('attempt_count',pg_catalog.count(*),'http_status',401),
    pg_catalog.max(a.id)::text||':'||pg_catalog.count(*)::text
  from private.system_webhook_attempts a where a.http_status=401 and a.occurred_at>=pg_catalog.statement_timestamp()-interval '15 minutes'
  having pg_catalog.count(*)>=3
  union all
  select 'webhook:500_burst','critical','webhook','multiple_webhook_failures','Webhook lỗi máy chủ liên tục',
    'Có từ 3 lần webhook 500 trong 15 phút gần nhất.',pg_catalog.max(a.occurred_at),'webhook',null,
    pg_catalog.jsonb_build_object('attempt_count',pg_catalog.count(*),'http_status',500),
    pg_catalog.max(a.id)::text||':'||pg_catalog.count(*)::text
  from private.system_webhook_attempts a where a.http_status=500 and a.occurred_at>=pg_catalog.statement_timestamp()-interval '15 minutes'
  having pg_catalog.count(*)>=3
  union all
  select 'webhook:attempt:'||a.id::text,case when a.http_status=500 then 'critical' else 'warning' end,'webhook',a.result_code,
    case when a.http_status=500 then 'Webhook xử lý thất bại' else 'Webhook bị từ chối' end,
    'Một webhook trả về HTTP '||a.http_status::text||'.',a.occurred_at,'webhook_attempt',a.id::text,
    pg_catalog.jsonb_build_object('http_status',a.http_status,'stage',a.stage,'duration_ms',a.duration_ms),a.id::text||':'||a.http_status::text||':'||a.result_code
  from private.system_webhook_attempts a where a.http_status>=400 and a.occurred_at>=p_window_start
  union all
  select 'webhook:receipt:'||r.id::text,case when r.status='failed' then 'critical' else 'warning' end,'webhook',
    case when r.status='received' then 'webhook_not_processed' else coalesce(r.result_code,'receipt_'||r.status) end,
    case when r.status='received' then 'Webhook chưa được xử lý' else 'Webhook receipt không hoàn tất' end,
    case when r.status='received' then 'Receipt đã nhận quá 2 phút nhưng chưa chuyển trạng thái.' else 'Receipt kết thúc ở trạng thái '||r.status||'.' end,
    r.received_at,'webhook_receipt',r.id::text,
    pg_catalog.jsonb_build_object('provider',r.provider,'status',r.status,'result_code',r.result_code),r.version::text||':'||r.status
  from private.payment_webhook_receipts r
  where r.received_at>=p_window_start and (r.status in ('failed','rejected') or (r.status='received' and r.received_at<pg_catalog.statement_timestamp()-interval '2 minutes'))
  union all
  select 'payment:transaction:'||t.id::text,
    case when t.rejection_code in ('beneficiary_mismatch','config_mismatch') then 'critical' else 'warning' end,
    'payment',case when t.rejection_code in ('beneficiary_mismatch','config_mismatch') then t.rejection_code else 'reconciliation_required' end,
    case when t.rejection_code='beneficiary_mismatch' then 'Sai tài khoản thụ hưởng' when t.rejection_code='config_mismatch' then 'Cấu hình ngân hàng không khớp' else 'Giao dịch cần đối soát' end,
    'Giao dịch ngân hàng bị từ chối với mã '||coalesce(t.rejection_code,'unknown')||'.',t.received_at,'bank_transaction',t.id::text,
    pg_catalog.jsonb_build_object('provider',t.provider,'rejection_code',t.rejection_code,'amount',t.amount::text,'currency',t.currency),
    t.version::text||':'||coalesce(t.rejection_code,'unknown')
  from private.bank_transactions t left join private.payment_reconciliation_cases rc on rc.bank_transaction_id=t.id
  where t.status='rejected' and t.received_at>=p_window_start and rc.id is null
  union all
  select 'payment:awaiting:'||p.id::text,'warning','payment','payment_awaiting_too_long','Thanh toán chờ quá lâu',
    'Thanh toán chuyển khoản đã chờ lâu hơn thời hạn QR cộng 5 phút.',p.updated_at,'payment',p.id::text,
    pg_catalog.jsonb_build_object('payment_code',p.payment_code,'status',p.status,'amount_expected',p.amount_expected::text),p.version::text||':'||p.updated_at::text
  from public.payments p cross join private.payment_bank_config c
  where p.method='bank_transfer' and p.status='awaiting_payment'
    and p.updated_at<pg_catalog.statement_timestamp()-pg_catalog.make_interval(secs=>c.expiry_seconds+300)
  union all
  select 'payment:settlement:'||p.id::text,'critical','payment','payment_settlement_inconsistency','Sai lệch quyết toán thanh toán',
    'Thanh toán ngân hàng đã paid nhưng không có giao dịch verified tương ứng.',coalesce(p.paid_at,p.updated_at),'payment',p.id::text,
    pg_catalog.jsonb_build_object('payment_code',p.payment_code,'payment_status',p.status),p.version::text||':'||p.status
  from public.payments p where p.method='bank_transfer' and p.status='paid' and not exists(
    select 1 from private.bank_transactions t where t.matched_payment_id=p.id and t.status='verified')
  union all
  select 'payment:settlement-tx:'||t.id::text,'critical','payment','payment_settlement_inconsistency','Sai lệch quyết toán giao dịch',
    'Giao dịch verified nhưng thanh toán liên kết chưa ở trạng thái paid.',t.updated_at,'bank_transaction',t.id::text,
    pg_catalog.jsonb_build_object('payment_code',p.payment_code,'payment_status',p.status),t.version::text||':'||p.version::text
  from private.bank_transactions t join public.payments p on p.id=t.matched_payment_id
  where t.status='verified' and p.status<>'paid'
  union all
  select 'rescue:stale-online:'||o.rescuer_id::text,'warning','rescue','rescuer_presence_stale','Đối tác online mất tín hiệu',
    'Đối tác vẫn được đánh dấu online nhưng heartbeat đã quá 120 giây.',coalesce(o.last_seen_at,o.updated_at),'rescuer',o.rescuer_id::text,
    pg_catalog.jsonb_build_object('is_online',o.is_online,'last_seen_at',o.last_seen_at),o.updated_at::text
  from public.rescuer_online_status o where o.is_online and (o.last_seen_at is null or o.last_seen_at<pg_catalog.statement_timestamp()-interval '120 seconds')
  union all
  select 'payment:failed:'||p.id::text,'warning','payment','payment_failed','Thanh toán thất bại',
    'Một thanh toán đã chuyển sang trạng thái failed.',coalesce(p.failed_at,p.updated_at),'payment',p.id::text,
    pg_catalog.jsonb_build_object('payment_code',p.payment_code,'method',p.method,'failure_code',p.failure_code),p.version::text||':'||p.status
  from public.payments p where p.status='failed' and p.updated_at>=p_window_start
  union all
  select 'security:change:'||a.id::text,'info','security','security_configuration_changed','Cấu hình bảo mật đã thay đổi',
    'Một thay đổi cấu hình hoặc quyền truy cập đã được ghi vào audit.',a.created_at,'system_audit',a.target,
    pg_catalog.jsonb_build_object('action',a.action,'target',a.target,'version',a.version::text),a.id::text||':'||a.version::text
  from private.system_config_audit a where a.created_at>=p_window_start
), finalized as (
  select r.alert_key,
    pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(r.alert_key||'|'||r.fingerprint_source,'UTF8')),'hex') fingerprint,
    r.severity,r.category,r.code,r.title,r.message,r.detected_at,r.entity_type,r.entity_id,r.detail
  from raw_alerts r
)
select * from finalized;
$$;

create function public.admin_get_system_monitoring(p_window_hours integer default 24,p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_start timestamptz; v_alerts jsonb; v_payment jsonb; v_webhook jsonb; v_rescue jsonb; v_security jsonb;
  v_open integer; v_critical integer; v_warning integer; v_4xx integer; v_5xx integer; v_incomplete integer; v_webhook_status text; v_overall text;
begin
  perform private.system_require_session();
  perform private.admin_require_role_readonly(array['super_admin','operator','finance']);
  if p_window_hours is null or p_window_hours not between 1 and 168 or p_limit is null or p_limit not between 1 and 200 then
    raise exception 'SYSTEM_MONITORING_INVALID_FILTER' using errcode='22023';
  end if;
  v_start:=pg_catalog.statement_timestamp()-pg_catalog.make_interval(hours=>p_window_hours);

  select pg_catalog.count(*) filter(where ack.acknowledged_at is null)::integer,
    pg_catalog.count(*) filter(where ack.acknowledged_at is null and a.severity='critical')::integer,
    pg_catalog.count(*) filter(where ack.acknowledged_at is null and a.severity='warning')::integer
    into v_open,v_critical,v_warning
  from private.system_monitoring_alerts(v_start) a
  left join private.system_alert_acknowledgements ack on ack.alert_key=a.alert_key and ack.fingerprint=a.fingerprint;

  with rows as (
    select a.*,ack.actor_id,ack.acknowledged_at
    from private.system_monitoring_alerts(v_start) a
    left join private.system_alert_acknowledgements ack on ack.alert_key=a.alert_key and ack.fingerprint=a.fingerprint
    order by case a.severity when 'critical' then 1 when 'warning' then 2 else 3 end,a.detected_at desc,a.alert_key
    limit p_limit
  ) select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'key',r.alert_key,'fingerprint',r.fingerprint,'severity',r.severity,'category',r.category,'code',r.code,
      'title',r.title,'message',r.message,'detected_at',r.detected_at,'entity_type',r.entity_type,'entity_id',r.entity_id,
      'detail',r.detail,'acknowledged',r.acknowledged_at is not null,'acknowledged_at',r.acknowledged_at,'acknowledged_by',r.actor_id
    ) order by case r.severity when 'critical' then 1 when 'warning' then 2 else 3 end,r.detected_at desc),'[]'::jsonb)
    into v_alerts from rows r;

  select pg_catalog.count(*) filter(where http_status between 400 and 499)::integer,
    pg_catalog.count(*) filter(where http_status>=500)::integer into v_4xx,v_5xx
    from private.system_webhook_attempts where occurred_at>=v_start;
  select pg_catalog.count(*)::integer into v_incomplete from private.payment_webhook_receipts
    where status in ('failed','rejected') or (status='received' and received_at<pg_catalog.statement_timestamp()-interval '2 minutes');
  v_overall:=case when v_critical>0 then 'critical' when v_warning>0 then 'degraded' else 'healthy' end;
  v_webhook_status:=case when v_5xx>0 or exists(select 1 from private.system_monitoring_alerts(v_start) where category='webhook' and severity='critical') then 'critical'
    when v_4xx>0 or v_incomplete>0 then 'degraded' else 'healthy' end;

  with rows as (
    select 'transaction:'||t.id::text id,'payment'::text category,coalesce(t.rejection_code,'rejected') code,t.status,
      case when t.rejection_code in ('beneficiary_mismatch','config_mismatch') then 'critical' else 'warning' end severity,
      t.received_at occurred_at,'bank_transaction'::text entity_type,t.id::text entity_id,
      pg_catalog.jsonb_build_object('provider',t.provider,'amount',t.amount::text,'currency',t.currency,'rejection_code',t.rejection_code) detail
    from private.bank_transactions t where t.status='rejected' and t.received_at>=v_start
    union all
    select 'payment:'||p.id::text,'payment',case when p.status='failed' then coalesce(p.failure_code,'payment_failed') else 'payment_awaiting' end,p.status,
      case when p.status='failed' then 'warning' else 'info' end,p.updated_at,'payment',p.id::text,
      pg_catalog.jsonb_build_object('payment_code',p.payment_code,'method',p.method,'amount_expected',p.amount_expected::text)
    from public.payments p where p.updated_at>=v_start and p.status in ('failed','awaiting_payment','verifying')
    order by occurred_at desc limit p_limit
  ) select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by r.occurred_at desc),'[]'::jsonb) into v_payment from rows r;

  with rows as (
    select 'attempt:'||a.id::text id,'webhook'::text category,a.result_code code,a.http_status::text status,
      case when a.http_status>=500 then 'critical' when a.http_status>=400 then 'warning' else 'info' end severity,
      a.occurred_at,'webhook_attempt'::text entity_type,a.id::text entity_id,
      pg_catalog.jsonb_build_object('provider',a.provider,'http_status',a.http_status,'stage',a.stage,'duration_ms',a.duration_ms) detail
    from private.system_webhook_attempts a where a.occurred_at>=v_start
    union all
    select 'receipt:'||r.id::text,'webhook',coalesce(r.result_code,'webhook_not_processed'),r.status,
      case when r.status='failed' then 'critical' when r.status in ('received','rejected') then 'warning' else 'info' end,
      r.received_at,'webhook_receipt',r.id::text,
      pg_catalog.jsonb_build_object('provider',r.provider,'status',r.status,'result_code',r.result_code,
        'authentication_verified',r.authentication_verified,'signature_verified',r.signature_verified)
    from private.payment_webhook_receipts r where r.received_at>=v_start
      and (r.status<>'processed' or r.result_code<>'paid')
    order by occurred_at desc limit p_limit
  ) select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by r.occurred_at desc),'[]'::jsonb) into v_webhook from rows r;

  with rows as (
    select 'request:'||r.id::text id,'rescue'::text category,'active_rescue_request'::text code,r.status,'info'::text severity,
      r.updated_at occurred_at,'rescue_request'::text entity_type,r.id::text entity_id,
      pg_catalog.jsonb_build_object('request_code',r.request_code,'status',r.status,'service_code',r.service_code) detail
    from public.rescue_requests r where r.status in ('searching','accepted','arriving','in_progress')
    union all
    select 'rescuer:'||o.rescuer_id::text,'rescue',case when o.last_seen_at<pg_catalog.statement_timestamp()-interval '120 seconds' then 'rescuer_presence_stale' else 'rescuer_online' end,
      case when o.last_seen_at<pg_catalog.statement_timestamp()-interval '120 seconds' then 'stale' else 'online' end,
      case when o.last_seen_at<pg_catalog.statement_timestamp()-interval '120 seconds' then 'warning' else 'info' end,
      coalesce(o.last_seen_at,o.updated_at),'rescuer',o.rescuer_id::text,
      pg_catalog.jsonb_build_object('is_online',o.is_online,'last_seen_at',o.last_seen_at)
    from public.rescuer_online_status o where o.is_online
    order by occurred_at desc limit p_limit
  ) select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by r.occurred_at desc),'[]'::jsonb) into v_rescue from rows r;

  with rows as (
    select 'system:'||a.id::text id,'security'::text category,a.action code,'recorded'::text status,
      case when a.action in ('admin_access','account_control') then 'warning' else 'info' end severity,
      a.created_at occurred_at,'system_audit'::text entity_type,a.target entity_id,
      pg_catalog.jsonb_build_object('action',a.action,'target',a.target,'version',a.version::text) detail
    from private.system_config_audit a where a.created_at>=v_start
    union all
    select 'admin:'||a.id::text,'security',a.action,'recorded','info',a.created_at,'admin_audit',coalesce(a.target_id::text,a.target_table),
      pg_catalog.jsonb_build_object('action',a.action,'target_table',a.target_table)
    from public.admin_audit_logs a where a.created_at>=v_start
    union all
    select 'account:'||c.user_id::text,'security','account_'||c.status,c.status,'warning',c.updated_at,'account',c.user_id::text,
      pg_catalog.jsonb_build_object('status',c.status,'suspended_until',c.suspended_until,'tokens_revoked',c.tokens_valid_after is not null)
    from private.system_account_controls c where c.status in ('locked','suspended')
    order by occurred_at desc limit p_limit
  ) select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by r.occurred_at desc),'[]'::jsonb) into v_security from rows r;

  return pg_catalog.jsonb_build_object(
    'generated_at',pg_catalog.statement_timestamp(),'window_hours',p_window_hours,
    'can_acknowledge',public.has_admin_role(array['super_admin','operator']),
    'summary',pg_catalog.jsonb_build_object(
      'overall_status',v_overall,'webhook_status',v_webhook_status,'webhook_4xx',v_4xx,'webhook_5xx',v_5xx,
      'payment_failures',(select pg_catalog.count(*) from public.payments where status='failed' and updated_at>=v_start),
      'pending_payments',(select pg_catalog.count(*) from public.payments where status in ('pending','awaiting_payment','verifying')),
      'rejected_transactions',(select pg_catalog.count(*) from private.bank_transactions where status='rejected' and received_at>=v_start),
      'incomplete_receipts',v_incomplete,
      'active_rescue_requests',(select pg_catalog.count(*) from public.rescue_requests where status in ('searching','accepted','arriving','in_progress')),
      'online_rescuers',(select pg_catalog.count(*) from public.rescuer_online_status o join public.rescuer_profiles p on p.user_id=o.rescuer_id where o.is_online and p.verification_status='approved' and o.last_seen_at>=pg_catalog.statement_timestamp()-interval '120 seconds'),
      'restricted_accounts',(select pg_catalog.count(*) from (
        select user_id from private.system_account_controls where status in ('locked','suspended')
        union select id from public.admin_profiles where status='blocked'
        union select user_id from public.rescuer_profiles where verification_status='suspended') restricted),
      'recent_security_events',(select pg_catalog.count(*) from private.system_config_audit where created_at>=v_start)+(select pg_catalog.count(*) from public.admin_audit_logs where created_at>=v_start),
      'open_alerts',v_open,'critical_alerts',v_critical),
    'alerts',v_alerts,'payment_events',v_payment,'webhook_events',v_webhook,'rescue_events',v_rescue,'security_events',v_security,
    'delivery_channels',pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('channel','admin_web','status','active','description','Cảnh báo được tính và hiển thị từ RPC admin-only.'),
      pg_catalog.jsonb_build_object('channel','telegram','status','requires_server_configuration','description','Cần worker server-side và secret Telegram; không đặt token ở frontend.'),
      pg_catalog.jsonb_build_object('channel','email','status','requires_server_configuration','description','Cần provider email và credential server-side; không đặt API key ở frontend.')));
end;
$$;

create function public.admin_acknowledge_system_alert(p_alert_key text,p_fingerprint text,p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_existing private.system_alert_acknowledgements; v_start timestamptz:=pg_catalog.statement_timestamp()-interval '7 days';
begin
  perform private.system_require_session();
  perform private.admin_require_role(array['super_admin','operator']);
  if p_alert_key is null or length(p_alert_key) not between 3 and 200
     or p_fingerprint is null or p_fingerprint !~ '^[0-9a-f]{64}$' or p_operation_id is null then
    raise exception 'SYSTEM_ALERT_ACK_INVALID' using errcode='22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('system-alert:'||p_alert_key||':'||p_fingerprint,0));
  select * into v_existing from private.system_alert_acknowledgements where actor_id=v_actor and operation_id=p_operation_id;
  if found then
    if v_existing.alert_key<>p_alert_key or v_existing.fingerprint<>p_fingerprint then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode='22023';
    end if;
    return pg_catalog.jsonb_build_object('changed',false,'message','Cảnh báo đã được xác nhận.','acknowledged_at',v_existing.acknowledged_at);
  end if;
  if not exists(select 1 from private.system_monitoring_alerts(v_start) a where a.alert_key=p_alert_key and a.fingerprint=p_fingerprint) then
    raise exception 'SYSTEM_ALERT_STALE' using errcode='40001';
  end if;
  insert into private.system_alert_acknowledgements(alert_key,fingerprint,actor_id,operation_id)
  values(p_alert_key,p_fingerprint,v_actor,p_operation_id)
  on conflict(alert_key,fingerprint) do nothing;
  select * into v_existing from private.system_alert_acknowledgements where alert_key=p_alert_key and fingerprint=p_fingerprint;
  insert into public.admin_audit_logs(admin_id,action,target_table,metadata)
  values(v_actor,'acknowledge_system_alert','system_alerts',pg_catalog.jsonb_build_object(
    'alert_key',p_alert_key,'fingerprint',p_fingerprint,'acknowledged_by',v_existing.actor_id));
  return pg_catalog.jsonb_build_object('changed',v_existing.actor_id=v_actor,'message','Đã xác nhận cảnh báo.','acknowledged_at',v_existing.acknowledged_at);
end;
$$;

revoke all on function private.system_monitoring_immutable(),
  private.record_bank_webhook_attempt(text,text,integer,text,text,text,integer),
  private.system_monitoring_alerts(timestamptz) from public,anon,authenticated,service_role;
revoke all on function public.admin_get_system_monitoring(integer,integer),
  public.admin_acknowledge_system_alert(text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.admin_get_system_monitoring(integer,integer),
  public.admin_acknowledge_system_alert(text,text,uuid) to authenticated;

commit;
