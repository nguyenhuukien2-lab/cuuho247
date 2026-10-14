-- Admin Payment Operations V2. Additive only: no SePay processor or payment settlement changes.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if pg_catalog.to_regprocedure('private.admin_require_role(text[])') is null
     or pg_catalog.to_regprocedure('private.admin_require_role_readonly(text[])') is null
     or pg_catalog.to_regclass('private.bank_transactions') is null
     or pg_catalog.to_regclass('private.payment_webhook_receipts') is null
     or pg_catalog.to_regclass('private.payment_bank_qr_snapshots') is null
     or pg_catalog.to_regprocedure('private.process_verified_bank_transaction(jsonb)') is null then
    raise exception 'ADMIN_PAYMENT_OPERATIONS_MISSING_PREREQUISITES';
  end if;
  if pg_catalog.to_regclass('private.payment_reconciliation_cases') is not null
     or pg_catalog.to_regclass('private.payment_refunds') is not null
     or pg_catalog.to_regclass('private.payment_operations_audit') is not null
     or pg_catalog.to_regclass('private.payment_admin_operation_receipts') is not null then
    raise exception 'ADMIN_PAYMENT_OPERATIONS_ALREADY_EXISTS';
  end if;
end;
$preflight$;

create table private.payment_reconciliation_cases (
  id uuid primary key default gen_random_uuid(),
  bank_transaction_id uuid not null unique references private.bank_transactions(id) on delete restrict,
  payment_id uuid not null references public.payments(id) on delete restrict,
  intent_id uuid not null,
  status text not null check(status in ('refund_required','dismissed')),
  reason_code text not null check(reason_code ~ '^[a-z][a-z0-9_]{0,63}$'),
  resolved_by uuid not null references public.admin_profiles(id) on delete restrict,
  resolved_at timestamptz not null default clock_timestamp(),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  version bigint not null default 1 check(version > 0),
  constraint payment_reconciliation_intent_payment_fk foreign key(intent_id,payment_id)
    references private.payment_bank_intents(id,payment_id) on delete restrict,
  constraint payment_reconciliation_times check(
    isfinite(resolved_at) and isfinite(created_at) and isfinite(updated_at)
    and resolved_at >= created_at and updated_at >= created_at)
);

create table private.payment_refunds (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete restrict,
  bank_transaction_id uuid references private.bank_transactions(id) on delete restrict,
  source_kind text not null check(source_kind in ('paid_payment','late_bank_transaction')),
  amount bigint not null check(amount > 0),
  currency text not null check(currency = 'VND'),
  reason_code text not null check(reason_code ~ '^[a-z][a-z0-9_]{0,63}$'),
  status text not null default 'requested'
    check(status in ('requested','approved','processing','refunded','failed')),
  requested_by uuid not null references public.admin_profiles(id) on delete restrict,
  approved_by uuid references public.admin_profiles(id) on delete restrict,
  processed_by uuid references public.admin_profiles(id) on delete restrict,
  requested_at timestamptz not null default clock_timestamp(),
  approved_at timestamptz,
  processing_at timestamptz,
  refunded_at timestamptz,
  failed_at timestamptz,
  evidence_reference text check(length(evidence_reference) between 1 and 128),
  failure_code text check(failure_code ~ '^[a-z][a-z0-9_]{0,63}$'),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  version bigint not null default 1 check(version > 0),
  constraint payment_refund_source_check check(
    (source_kind='paid_payment' and bank_transaction_id is null)
    or (source_kind='late_bank_transaction' and bank_transaction_id is not null)),
  constraint payment_refund_actor_separation check(approved_by is null or approved_by <> requested_by),
  constraint payment_refund_state_fields check(
    (status='requested' and approved_by is null and processed_by is null and approved_at is null
      and processing_at is null and refunded_at is null and failed_at is null
      and evidence_reference is null and failure_code is null)
    or (status='approved' and approved_by is not null and approved_at is not null
      and processed_by is null and processing_at is null and refunded_at is null and failed_at is null
      and evidence_reference is null and failure_code is null)
    or (status='processing' and approved_by is not null and approved_at is not null
      and processed_by is not null and processing_at is not null and refunded_at is null and failed_at is null
      and evidence_reference is null and failure_code is null)
    or (status='refunded' and approved_by is not null and processed_by is not null
      and refunded_at is not null and evidence_reference is not null and failure_code is null)
    or (status='failed' and approved_by is not null and processed_by is not null
      and failed_at is not null and evidence_reference is null and failure_code is not null)),
  constraint payment_refund_times check(
    isfinite(requested_at) and isfinite(created_at) and isfinite(updated_at)
    and (approved_at is null or isfinite(approved_at))
    and (processing_at is null or isfinite(processing_at))
    and (refunded_at is null or isfinite(refunded_at))
    and (failed_at is null or isfinite(failed_at))
    and requested_at=created_at and updated_at>=created_at)
);

create table private.payment_operations_audit (
  id uuid primary key default gen_random_uuid(),
  reconciliation_case_id uuid references private.payment_reconciliation_cases(id) on delete restrict,
  refund_id uuid references private.payment_refunds(id) on delete restrict,
  payment_id uuid not null references public.payments(id) on delete restrict,
  bank_transaction_id uuid references private.bank_transactions(id) on delete restrict,
  event_type text not null check(event_type in (
    'late_payment_refund_required','late_payment_dismissed','refund_requested',
    'refund_approved','refund_processing','refund_refunded','refund_failed')),
  old_status text,
  new_status text not null,
  amount bigint check(amount is null or amount > 0),
  reason_code text check(reason_code is null or reason_code ~ '^[a-z][a-z0-9_]{0,63}$'),
  actor_id uuid not null references public.admin_profiles(id) on delete restrict,
  operation_id uuid not null,
  recorded_at timestamptz not null default clock_timestamp() check(isfinite(recorded_at)),
  constraint payment_operations_audit_resource check(num_nonnulls(reconciliation_case_id,refund_id)=1),
  unique(actor_id,operation_id,event_type)
);

create table private.payment_admin_operation_receipts (
  actor_id uuid not null references public.admin_profiles(id) on delete restrict,
  operation_id uuid not null,
  operation_kind text not null check(operation_kind in (
    'resolve_late_payment','request_refund','transition_refund')),
  request_sha256 text not null check(request_sha256 ~ '^[0-9a-f]{64}$'),
  response jsonb not null check(jsonb_typeof(response)='object' and octet_length(response::text)<=8192),
  created_at timestamptz not null default clock_timestamp() check(isfinite(created_at)),
  primary key(actor_id,operation_id)
);

create index payment_reconciliation_status_created_idx
  on private.payment_reconciliation_cases(status,created_at desc,id);
create index payment_refunds_payment_created_idx on private.payment_refunds(payment_id,created_at desc,id);
create index payment_refunds_status_created_idx on private.payment_refunds(status,created_at desc,id);
create index payment_operations_audit_payment_idx
  on private.payment_operations_audit(payment_id,recorded_at,id);

alter table private.payment_reconciliation_cases enable row level security;
alter table private.payment_refunds enable row level security;
alter table private.payment_operations_audit enable row level security;
alter table private.payment_admin_operation_receipts enable row level security;
revoke all on table private.payment_reconciliation_cases,private.payment_refunds,
  private.payment_operations_audit,private.payment_admin_operation_receipts
  from public,anon,authenticated;
do $service_acl$
begin
  if exists(select 1 from pg_catalog.pg_roles where rolname='service_role') then
    revoke all on table private.payment_reconciliation_cases,private.payment_refunds,
      private.payment_operations_audit,private.payment_admin_operation_receipts from service_role;
  end if;
end;
$service_acl$;

create function private.payment_operations_immutable_guard() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if tg_op<>'INSERT' then
    raise exception 'PAYMENT_OPERATIONS_AUDIT_IMMUTABLE' using errcode='23514';
  end if;
  new.recorded_at:=pg_catalog.clock_timestamp();
  new.actor_id:=auth.uid();
  if new.actor_id is null then
    raise exception 'ADMIN_FORBIDDEN' using errcode='42501';
  end if;
  return new;
end;
$$;
create trigger payment_operations_audit_immutable before insert or update or delete
  on private.payment_operations_audit for each row execute function private.payment_operations_immutable_guard();
create trigger payment_operations_audit_no_truncate before truncate
  on private.payment_operations_audit for each statement execute function private.payment_operations_immutable_guard();

create function private.payment_admin_receipt_guard() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if tg_op<>'INSERT' then
    raise exception 'PAYMENT_OPERATION_RECEIPT_IMMUTABLE' using errcode='23514';
  end if;
  new.created_at:=pg_catalog.clock_timestamp();
  if new.actor_id is distinct from auth.uid() then
    raise exception 'PAYMENT_OPERATION_ACTOR_INVALID' using errcode='23514';
  end if;
  return new;
end;
$$;
create trigger payment_admin_receipt_immutable before insert or update or delete
  on private.payment_admin_operation_receipts for each row execute function private.payment_admin_receipt_guard();
create trigger payment_admin_receipt_no_truncate before truncate
  on private.payment_admin_operation_receipts for each statement execute function private.payment_admin_receipt_guard();

create function private.payment_reconciliation_guard() returns trigger
language plpgsql security invoker set search_path='' as $$
declare v_now timestamptz:=pg_catalog.clock_timestamp();
begin
  if tg_op in ('DELETE','TRUNCATE') then
    raise exception 'PAYMENT_RECONCILIATION_IMMUTABLE' using errcode='23514';
  end if;
  if tg_op='UPDATE' then
    raise exception 'PAYMENT_RECONCILIATION_TERMINAL' using errcode='23514';
  end if;
  new.resolved_by:=auth.uid();
  if new.resolved_by is null then raise exception 'ADMIN_FORBIDDEN' using errcode='42501'; end if;
  new.resolved_at:=v_now; new.created_at:=v_now; new.updated_at:=v_now; new.version:=1;
  return new;
end;
$$;
create trigger payment_reconciliation_guard before insert or update or delete
  on private.payment_reconciliation_cases for each row execute function private.payment_reconciliation_guard();
create trigger payment_reconciliation_no_truncate before truncate
  on private.payment_reconciliation_cases for each statement execute function private.payment_reconciliation_guard();

create function private.payment_refund_guard() returns trigger
language plpgsql security invoker set search_path='' as $$
declare v_now timestamptz:=pg_catalog.clock_timestamp(); v_actor uuid:=auth.uid();
begin
  if tg_op in ('DELETE','TRUNCATE') then
    raise exception 'PAYMENT_REFUND_DELETE_FORBIDDEN' using errcode='23514';
  end if;
  if v_actor is null then raise exception 'ADMIN_FORBIDDEN' using errcode='42501'; end if;
  if tg_op='INSERT' then
    if new.status is distinct from 'requested' then
      raise exception 'PAYMENT_REFUND_INITIAL_STATE_REQUIRED' using errcode='23514';
    end if;
    new.requested_by:=v_actor; new.requested_at:=v_now; new.created_at:=v_now;
    new.updated_at:=v_now; new.version:=1;
    new.approved_by:=null; new.processed_by:=null; new.approved_at:=null;
    new.processing_at:=null; new.refunded_at:=null; new.failed_at:=null;
    new.evidence_reference:=null; new.failure_code:=null;
    return new;
  end if;
  if (pg_catalog.to_jsonb(new)-array['status','version','updated_at','approved_by','processed_by',
      'approved_at','processing_at','refunded_at','failed_at','evidence_reference','failure_code'])
     is distinct from
     (pg_catalog.to_jsonb(old)-array['status','version','updated_at','approved_by','processed_by',
      'approved_at','processing_at','refunded_at','failed_at','evidence_reference','failure_code'])
     or new.version<>old.version+1 then
    raise exception 'PAYMENT_REFUND_IMMUTABLE_FIELDS' using errcode='23514';
  end if;
  if old.status='requested' and new.status='approved' then
    if v_actor=old.requested_by then
      raise exception 'PAYMENT_REFUND_TWO_PERSON_REQUIRED' using errcode='42501';
    end if;
    new.approved_by:=v_actor; new.approved_at:=v_now;
  elsif old.status='approved' and new.status='processing' then
    if v_actor=old.requested_by then
      raise exception 'PAYMENT_REFUND_TWO_PERSON_REQUIRED' using errcode='42501';
    end if;
    new.processed_by:=v_actor; new.processing_at:=v_now;
  elsif old.status='processing' and new.status='refunded' then
    if v_actor=old.requested_by or new.evidence_reference is null
       or pg_catalog.btrim(new.evidence_reference)='' then
      raise exception 'PAYMENT_REFUND_EVIDENCE_REQUIRED' using errcode='22023';
    end if;
    new.evidence_reference:=pg_catalog.btrim(new.evidence_reference);
    new.processed_by:=v_actor; new.refunded_at:=v_now; new.failure_code:=null;
  elsif old.status='processing' and new.status='failed' then
    if v_actor=old.requested_by or new.failure_code is null then
      raise exception 'PAYMENT_REFUND_FAILURE_EVIDENCE_REQUIRED' using errcode='22023';
    end if;
    new.processed_by:=v_actor; new.failed_at:=v_now; new.evidence_reference:=null;
  else
    raise exception 'PAYMENT_REFUND_TRANSITION_INVALID' using errcode='23514';
  end if;
  new.updated_at:=v_now;
  return new;
end;
$$;
create trigger payment_refund_guard before insert or update or delete
  on private.payment_refunds for each row execute function private.payment_refund_guard();
create trigger payment_refund_no_truncate before truncate
  on private.payment_refunds for each statement execute function private.payment_refund_guard();

create function public.admin_list_payment_reconciliation(
  p_search text default null,
  p_status text default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_limit integer default 50,
  p_cursor jsonb default null
) returns jsonb language plpgsql stable security definer set search_path=pg_catalog,public,private as $$
declare
  v_search text:=pg_catalog.lower(pg_catalog.btrim(coalesce(p_search,'')));
  v_limit integer:=least(greatest(coalesce(p_limit,50),1),100);
  v_cursor_at timestamptz; v_cursor_id uuid; v_rows jsonb; v_has_more boolean; v_next jsonb;
begin
  perform private.admin_require_role_readonly(array['super_admin','finance']);
  if pg_catalog.length(v_search)>128
     or (p_status is not null and p_status not in ('pending','refund_required','dismissed'))
     or (p_from is not null and not pg_catalog.isfinite(p_from))
     or (p_to is not null and not pg_catalog.isfinite(p_to))
     or (p_from is not null and p_to is not null and p_from>=p_to) then
    raise exception 'ADMIN_RECONCILIATION_INVALID_FILTER' using errcode='22023';
  end if;
  if p_cursor is not null then
    begin
      if pg_catalog.jsonb_typeof(p_cursor)<>'object' or not p_cursor ?& array['received_at','id']
         or exists(select 1 from pg_catalog.jsonb_object_keys(p_cursor) k where k not in ('received_at','id')) then
        raise exception 'invalid';
      end if;
      v_cursor_at:=(p_cursor->>'received_at')::timestamptz;
      v_cursor_id:=(p_cursor->>'id')::uuid;
    exception when others then
      raise exception 'ADMIN_RECONCILIATION_INVALID_CURSOR' using errcode='22023';
    end;
  end if;
  with candidates as (
    select t.id,t.provider,t.provider_scope,t.external_transaction_id,t.amount,t.currency,
      t.transfer_reference,t.occurred_at,t.received_at,t.version transaction_version,t.rejection_code,
      r.id receipt_id,r.status receipt_status,r.result_code,r.authentication_verified,r.signature_verified,
      i.id intent_id,p.id payment_id,p.payment_code,p.request_id,q.request_code,p.status payment_status,
      p.version payment_version,
      i.expires_at,c.id case_id,c.status reconciliation_status,c.reason_code,c.version case_version,
      c.resolved_by,c.resolved_at
    from private.bank_transactions t
    join private.payment_webhook_receipts r on r.id=t.receipt_id
    left join private.payment_bank_qr_snapshots s on s.transfer_content=t.transfer_reference
    left join private.payment_bank_intents i on i.id=s.intent_id
    left join public.payments p on p.id=i.payment_id
    left join public.rescue_requests q on q.id=p.request_id
    left join private.payment_reconciliation_cases c on c.bank_transaction_id=t.id
    where t.status='rejected' and t.matched_payment_id is null
      and (v_search='' or pg_catalog.strpos(pg_catalog.lower(pg_catalog.concat_ws(' ',
        t.external_transaction_id,t.transfer_reference,t.rejection_code,p.payment_code,q.request_code)),v_search)>0)
      and (p_status is null or p_status=coalesce(c.status,'pending'))
      and (p_from is null or t.received_at>=p_from) and (p_to is null or t.received_at<p_to)
      and (v_cursor_at is null or (t.received_at,t.id)<(v_cursor_at,v_cursor_id))
  ), page as (
    select * from candidates order by received_at desc,id desc limit v_limit+1
  ), kept as (
    select * from page order by received_at desc,id desc limit v_limit
  )
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'transaction_id',k.id,'provider',k.provider,'provider_scope',k.provider_scope,
      'provider_transaction_id',k.external_transaction_id,'amount',k.amount::text,'currency',k.currency,
      'reference',k.transfer_reference,'occurred_at',k.occurred_at,'received_at',k.received_at,
      'transaction_version',k.transaction_version::text,'rejection_code',k.rejection_code,
      'receipt',pg_catalog.jsonb_build_object('id',k.receipt_id,'status',k.receipt_status,
        'result_code',k.result_code,'authentication_verified',k.authentication_verified,
        'signature_verified',k.signature_verified),
      'candidate_payment_id',k.payment_id,'payment_code',k.payment_code,'request_id',k.request_id,
      'request_code',k.request_code,'payment_status',k.payment_status,'payment_version',k.payment_version::text,
      'intent_id',k.intent_id,
      'intent_expires_at',k.expires_at,'late_payment',k.rejection_code='intent_expired',
      'case_id',k.case_id,'reconciliation_status',coalesce(k.reconciliation_status,'pending'),
      'case_reason_code',k.reason_code,'case_version',k.case_version::text,
      'resolved_by',k.resolved_by,'resolved_at',k.resolved_at
    ) order by k.received_at desc,k.id desc),'[]'::jsonb),
    (select pg_catalog.count(*)>v_limit from page),
    (select pg_catalog.jsonb_build_object('received_at',z.received_at,'id',z.id)
      from kept z order by z.received_at,z.id limit 1)
  into v_rows,v_has_more,v_next from kept k;
  if not v_has_more then v_next:=null; end if;
  return pg_catalog.jsonb_build_object('rows',v_rows,'next_cursor',v_next,'has_more',v_has_more);
end;
$$;

create function public.admin_get_payment_operations_report(
  p_from timestamptz default null,p_to timestamptz default null
) returns jsonb language plpgsql stable security definer set search_path=pg_catalog,public,private as $$
declare v_from timestamptz:=coalesce(p_from,pg_catalog.statement_timestamp()-interval '30 days');
  v_to timestamptz:=coalesce(p_to,pg_catalog.statement_timestamp()); v_result jsonb;
begin
  perform private.admin_require_role_readonly(array['super_admin','finance']);
  if not pg_catalog.isfinite(v_from) or not pg_catalog.isfinite(v_to) or v_from>=v_to
     or v_to-v_from>interval '366 days' then
    raise exception 'ADMIN_PAYMENT_INVALID_DATE_RANGE' using errcode='22023';
  end if;
  select pg_catalog.jsonb_build_object(
    'bank_total',coalesce(pg_catalog.sum(p.amount_received) filter(where p.status='paid' and p.method='bank_transfer'),0)::text,
    'cash_total',coalesce(pg_catalog.sum(p.amount_received) filter(where p.status='paid' and p.method='cash'),0)::text,
    'paid_count',pg_catalog.count(*) filter(where p.status='paid'),
    'unpaid_count',pg_catalog.count(*) filter(where p.status<>'paid'),
    'rejected_transactions',(select pg_catalog.count(*) from private.bank_transactions t where t.status='rejected' and t.received_at>=v_from and t.received_at<v_to),
    'late_payments',(select pg_catalog.count(*) from private.bank_transactions t where t.status='rejected' and t.rejection_code='intent_expired' and t.received_at>=v_from and t.received_at<v_to),
    'refund_total',(select coalesce(pg_catalog.sum(f.amount),0)::text from private.payment_refunds f where f.status='refunded' and f.refunded_at>=v_from and f.refunded_at<v_to),
    'refund_pending',(select pg_catalog.count(*) from private.payment_refunds f where f.status in ('requested','approved','processing') and f.created_at>=v_from and f.created_at<v_to),
    'from',v_from,'to',v_to,'server_time',pg_catalog.statement_timestamp()
  ) into v_result from public.payments p where p.created_at>=v_from and p.created_at<v_to;
  return v_result;
end;
$$;

create function public.admin_list_payment_refunds(
  p_payment_id uuid default null,p_status text default null,p_from timestamptz default null,
  p_to timestamptz default null,p_limit integer default 100
) returns jsonb language plpgsql stable security definer set search_path=pg_catalog,public,private as $$
declare v_rows jsonb;
begin
  perform private.admin_require_role_readonly(array['super_admin','finance']);
  if (p_status is not null and p_status not in ('requested','approved','processing','refunded','failed'))
     or (p_from is not null and not pg_catalog.isfinite(p_from))
     or (p_to is not null and not pg_catalog.isfinite(p_to))
     or (p_from is not null and p_to is not null and p_from>=p_to)
     or coalesce(p_limit,100) not between 1 and 100 then
    raise exception 'ADMIN_REFUND_INVALID_FILTER' using errcode='22023';
  end if;
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'refund_id',x.id,'payment_id',x.payment_id,'payment_code',x.payment_code,
    'bank_transaction_id',x.bank_transaction_id,'source_kind',x.source_kind,
    'amount',x.amount::text,'currency',x.currency,'reason_code',x.reason_code,'status',x.status,
    'requested_by',x.requested_by,'approved_by',x.approved_by,'processed_by',x.processed_by,
    'requested_at',x.requested_at,'approved_at',x.approved_at,'processing_at',x.processing_at,
    'refunded_at',x.refunded_at,'failed_at',x.failed_at,
    'evidence_reference',x.evidence_reference,'failure_code',x.failure_code,
    'updated_at',x.updated_at,'version',x.version::text
  ) order by x.created_at desc,x.id desc),'[]'::jsonb) into v_rows
  from (select f.*,p.payment_code from private.payment_refunds f
    join public.payments p on p.id=f.payment_id
    where (p_payment_id is null or f.payment_id=p_payment_id)
      and (p_status is null or f.status=p_status)
      and (p_from is null or f.created_at>=p_from) and (p_to is null or f.created_at<p_to)
    order by f.created_at desc,f.id desc limit p_limit) x;
  return pg_catalog.jsonb_build_object('rows',v_rows);
end;
$$;

create function public.admin_get_payment_operations_timeline(p_payment_id uuid)
returns jsonb language plpgsql stable security definer set search_path=pg_catalog,public,private as $$
declare v_rows jsonb;
begin
  perform private.admin_require_role_readonly(array['super_admin','finance']);
  if not exists(select 1 from public.payments p where p.id=p_payment_id) then return null; end if;
  with timeline as (
    select e.id,e.created_at,e.event_type,e.actor_type,e.actor_id,e.old_status,e.new_status,e.amount
      from public.payment_events e where e.payment_id=p_payment_id
    union all
    select a.id,a.recorded_at,'bank_'||a.action,'system',null::uuid,a.old_status,a.new_status,null::bigint
      from private.payment_bank_audit a
      left join private.payment_bank_intents i on i.id=a.intent_id
      left join private.bank_transactions t on t.id=a.transaction_id
      left join private.bank_transactions rt on rt.receipt_id=a.receipt_id
      where i.payment_id=p_payment_id or t.matched_payment_id=p_payment_id
        or exists(select 1 from private.payment_bank_qr_snapshots s
          join private.payment_bank_intents bi on bi.id=s.intent_id
          where bi.payment_id=p_payment_id and s.transfer_content=t.transfer_reference)
        or rt.matched_payment_id=p_payment_id
        or exists(select 1 from private.payment_bank_qr_snapshots s
          join private.payment_bank_intents bi on bi.id=s.intent_id
          where bi.payment_id=p_payment_id and s.transfer_content=rt.transfer_reference)
    union all
    select a.id,a.recorded_at,a.event_type,'admin',a.actor_id,a.old_status,a.new_status,a.amount
      from private.payment_operations_audit a where a.payment_id=p_payment_id
  )
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'id',x.id,'timestamp',x.created_at,'event_type',x.event_type,'actor_type',x.actor_type,
    'actor_id',x.actor_id,'old_status',x.old_status,'new_status',x.new_status,
    'amount',case when x.amount is null then null else x.amount::text end
  ) order by x.created_at,x.id),'[]'::jsonb) into v_rows from timeline x;
  return pg_catalog.jsonb_build_object('rows',v_rows);
end;
$$;

create function public.admin_resolve_late_payment(
  p_bank_transaction_id uuid,p_expected_transaction_version bigint,p_expected_case_version bigint,
  p_resolution text,p_reason_code text,p_operation_id uuid
) returns jsonb language plpgsql volatile security definer set search_path=pg_catalog,public,private as $$
declare v_actor uuid:=auth.uid(); v_tx private.bank_transactions; v_receipt private.payment_webhook_receipts;
  v_intent private.payment_bank_intents; v_snapshot private.payment_bank_qr_snapshots;
  v_case private.payment_reconciliation_cases; v_hash text; v_existing private.payment_admin_operation_receipts;
  v_response jsonb;
begin
  perform private.admin_require_role(array['super_admin','finance']);
  if p_bank_transaction_id is null or p_operation_id is null or p_expected_transaction_version is null
     or p_expected_transaction_version<1 or p_resolution not in ('refund_required','dismissed')
     or p_reason_code is null or p_reason_code !~ '^[a-z][a-z0-9_]{0,63}$' then
    raise exception 'ADMIN_RECONCILIATION_INVALID_INPUT' using errcode='22023';
  end if;
  v_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.concat_ws('|',
    p_bank_transaction_id::text,p_expected_transaction_version::text,coalesce(p_expected_case_version::text,''),
    p_resolution,p_reason_code),'UTF8')),'hex');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('admin-payment-op:'||v_actor::text||':'||p_operation_id::text,0));
  select x.* into v_existing from private.payment_admin_operation_receipts x
    where x.actor_id=v_actor and x.operation_id=p_operation_id;
  if found then
    if v_existing.operation_kind<>'resolve_late_payment' or v_existing.request_sha256<>v_hash then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode='22023';
    end if;
    return v_existing.response;
  end if;
  select t.* into v_tx from private.bank_transactions t where t.id=p_bank_transaction_id for update;
  if not found or v_tx.status<>'rejected' or v_tx.rejection_code<>'intent_expired'
     or v_tx.matched_payment_id is not null then
    raise exception 'ADMIN_LATE_PAYMENT_NOT_ELIGIBLE' using errcode='P0001';
  end if;
  if v_tx.version<>p_expected_transaction_version then
    raise exception 'STALE_VERSION' using errcode='40001';
  end if;
  select r.* into v_receipt from private.payment_webhook_receipts r where r.id=v_tx.receipt_id for share;
  select i.* into v_intent
    from private.payment_bank_qr_snapshots s join private.payment_bank_intents i on i.id=s.intent_id
    where s.transfer_content=v_tx.transfer_reference;
  if not found then raise exception 'ADMIN_LATE_PAYMENT_EVIDENCE_REQUIRED' using errcode='23514'; end if;
  select s.* into v_snapshot from private.payment_bank_qr_snapshots s where s.intent_id=v_intent.id;
  if not v_receipt.authentication_verified or v_receipt.normalized_sha256 is distinct from v_tx.normalized_sha256
     or v_tx.direction<>'credit' or v_tx.amount<>v_intent.expected_amount or v_tx.currency<>v_intent.currency
     or v_tx.beneficiary_bank_bin is distinct from v_snapshot.bank_bin
     or v_tx.beneficiary_account_number is distinct from v_snapshot.account_number then
    raise exception 'ADMIN_LATE_PAYMENT_EVIDENCE_REQUIRED' using errcode='23514';
  end if;
  select c.* into v_case from private.payment_reconciliation_cases c
    where c.bank_transaction_id=v_tx.id for update;
  if found then
    if p_expected_case_version is null or v_case.version<>p_expected_case_version then
      raise exception 'STALE_VERSION' using errcode='40001';
    end if;
    raise exception 'ADMIN_RECONCILIATION_ALREADY_RESOLVED' using errcode='P0001';
  elsif p_expected_case_version is not null then
    raise exception 'STALE_VERSION' using errcode='40001';
  end if;
  insert into private.payment_reconciliation_cases(bank_transaction_id,payment_id,intent_id,status,reason_code,resolved_by)
    values(v_tx.id,v_intent.payment_id,v_intent.id,p_resolution,p_reason_code,v_actor) returning * into v_case;
  insert into private.payment_operations_audit(reconciliation_case_id,payment_id,bank_transaction_id,
    event_type,new_status,reason_code,actor_id,operation_id)
  values(v_case.id,v_case.payment_id,v_case.bank_transaction_id,
    case p_resolution when 'refund_required' then 'late_payment_refund_required' else 'late_payment_dismissed' end,
    p_resolution,p_reason_code,v_actor,p_operation_id);
  v_response:=pg_catalog.jsonb_build_object('case_id',v_case.id,'transaction_id',v_tx.id,
    'payment_id',v_case.payment_id,'status',v_case.status,'version',v_case.version::text,
    'resolved_at',v_case.resolved_at);
  insert into private.payment_admin_operation_receipts(actor_id,operation_id,operation_kind,request_sha256,response)
    values(v_actor,p_operation_id,'resolve_late_payment',v_hash,v_response);
  return v_response;
end;
$$;

create function public.admin_request_payment_refund(
  p_payment_id uuid,p_bank_transaction_id uuid,p_amount bigint,p_reason_code text,
  p_expected_payment_version bigint,p_operation_id uuid
) returns jsonb language plpgsql volatile security definer set search_path=pg_catalog,public,private as $$
declare v_actor uuid:=auth.uid(); v_payment public.payments; v_tx private.bank_transactions;
  v_case private.payment_reconciliation_cases; v_refund private.payment_refunds;
  v_source text; v_max bigint; v_reserved bigint; v_hash text;
  v_existing private.payment_admin_operation_receipts; v_response jsonb;
begin
  perform private.admin_require_role(array['super_admin','finance']);
  if p_payment_id is null or p_amount is null or p_amount<=0 or p_operation_id is null
     or p_expected_payment_version is null or p_expected_payment_version<1
     or p_reason_code is null or p_reason_code !~ '^[a-z][a-z0-9_]{0,63}$' then
    raise exception 'ADMIN_REFUND_INVALID_INPUT' using errcode='22023';
  end if;
  v_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.concat_ws('|',p_payment_id::text,
    coalesce(p_bank_transaction_id::text,''),p_amount::text,p_reason_code,p_expected_payment_version::text),'UTF8')),'hex');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('admin-payment-op:'||v_actor::text||':'||p_operation_id::text,0));
  select x.* into v_existing from private.payment_admin_operation_receipts x where x.actor_id=v_actor and x.operation_id=p_operation_id;
  if found then
    if v_existing.operation_kind<>'request_refund' or v_existing.request_sha256<>v_hash then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode='22023';
    end if;
    return v_existing.response;
  end if;
  select p.* into v_payment from public.payments p where p.id=p_payment_id for update;
  if not found or v_payment.version<>p_expected_payment_version then
    raise exception 'STALE_VERSION' using errcode='40001';
  end if;
  if p_bank_transaction_id is null then
    if v_payment.status<>'paid' or v_payment.amount_received<=0 then
      raise exception 'ADMIN_REFUND_PAYMENT_NOT_PAID' using errcode='P0001';
    end if;
    v_source:='paid_payment'; v_max:=v_payment.amount_received;
  else
    select t.* into v_tx from private.bank_transactions t where t.id=p_bank_transaction_id for update;
    select c.* into v_case from private.payment_reconciliation_cases c
      where c.bank_transaction_id=p_bank_transaction_id for share;
    if not found or v_tx.status<>'rejected' or v_tx.rejection_code<>'intent_expired'
       or v_case.status<>'refund_required' or v_case.payment_id<>p_payment_id then
      raise exception 'ADMIN_REFUND_LATE_PAYMENT_NOT_APPROVED' using errcode='P0001';
    end if;
    v_source:='late_bank_transaction'; v_max:=v_tx.amount;
  end if;
  select coalesce(pg_catalog.sum(f.amount),0) into v_reserved from private.payment_refunds f
    where f.payment_id=p_payment_id and f.source_kind=v_source
      and f.bank_transaction_id is not distinct from p_bank_transaction_id
      and f.status in ('requested','approved','processing','refunded');
  if p_amount>v_max-v_reserved then raise exception 'ADMIN_REFUND_AMOUNT_EXCEEDS_AVAILABLE' using errcode='22023'; end if;
  insert into private.payment_refunds(payment_id,bank_transaction_id,source_kind,amount,currency,
    reason_code,status,requested_by)
  values(p_payment_id,p_bank_transaction_id,v_source,p_amount,v_payment.currency,p_reason_code,'requested',v_actor)
  returning * into v_refund;
  insert into private.payment_operations_audit(refund_id,payment_id,bank_transaction_id,event_type,
    new_status,amount,reason_code,actor_id,operation_id)
  values(v_refund.id,p_payment_id,p_bank_transaction_id,'refund_requested','requested',p_amount,p_reason_code,v_actor,p_operation_id);
  v_response:=pg_catalog.jsonb_build_object('refund_id',v_refund.id,'payment_id',p_payment_id,
    'status',v_refund.status,'amount',v_refund.amount::text,'version',v_refund.version::text,
    'requested_at',v_refund.requested_at);
  insert into private.payment_admin_operation_receipts(actor_id,operation_id,operation_kind,request_sha256,response)
    values(v_actor,p_operation_id,'request_refund',v_hash,v_response);
  return v_response;
end;
$$;

create function public.admin_transition_payment_refund(
  p_refund_id uuid,p_expected_version bigint,p_action text,p_evidence_reference text,
  p_failure_code text,p_operation_id uuid
) returns jsonb language plpgsql volatile security definer set search_path=pg_catalog,public,private as $$
declare v_actor uuid:=auth.uid(); v_refund private.payment_refunds; v_old text; v_new text;
  v_hash text; v_existing private.payment_admin_operation_receipts; v_response jsonb; v_event text;
begin
  perform private.admin_require_role(array['super_admin','finance']);
  if p_refund_id is null or p_expected_version is null or p_expected_version<1 or p_operation_id is null
     or p_action not in ('approve','start_processing','record_refunded','record_failed')
     or (p_action='record_refunded' and (p_evidence_reference is null or pg_catalog.length(pg_catalog.btrim(p_evidence_reference)) not between 1 and 128))
     or (p_action='record_failed' and (p_failure_code is null or p_failure_code !~ '^[a-z][a-z0-9_]{0,63}$'))
     or (p_action<>'record_refunded' and p_evidence_reference is not null)
     or (p_action<>'record_failed' and p_failure_code is not null) then
    raise exception 'ADMIN_REFUND_TRANSITION_INVALID_INPUT' using errcode='22023';
  end if;
  v_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.concat_ws('|',p_refund_id::text,
    p_expected_version::text,p_action,coalesce(p_evidence_reference,''),coalesce(p_failure_code,'')),'UTF8')),'hex');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('admin-payment-op:'||v_actor::text||':'||p_operation_id::text,0));
  select x.* into v_existing from private.payment_admin_operation_receipts x where x.actor_id=v_actor and x.operation_id=p_operation_id;
  if found then
    if v_existing.operation_kind<>'transition_refund' or v_existing.request_sha256<>v_hash then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode='22023';
    end if;
    return v_existing.response;
  end if;
  select f.* into v_refund from private.payment_refunds f where f.id=p_refund_id for update;
  if not found or v_refund.version<>p_expected_version then raise exception 'STALE_VERSION' using errcode='40001'; end if;
  v_old:=v_refund.status;
  v_new:=case p_action when 'approve' then 'approved' when 'start_processing' then 'processing'
    when 'record_refunded' then 'refunded' else 'failed' end;
  update private.payment_refunds f set status=v_new,version=f.version+1,
    evidence_reference=case when p_action='record_refunded' then pg_catalog.btrim(p_evidence_reference) else null end,
    failure_code=case when p_action='record_failed' then p_failure_code else null end
    where f.id=p_refund_id returning * into v_refund;
  v_event:=case v_new when 'approved' then 'refund_approved' when 'processing' then 'refund_processing'
    when 'refunded' then 'refund_refunded' else 'refund_failed' end;
  insert into private.payment_operations_audit(refund_id,payment_id,bank_transaction_id,event_type,
    old_status,new_status,amount,reason_code,actor_id,operation_id)
  values(v_refund.id,v_refund.payment_id,v_refund.bank_transaction_id,v_event,v_old,v_new,
    v_refund.amount,case when v_new='failed' then p_failure_code else v_refund.reason_code end,v_actor,p_operation_id);
  v_response:=pg_catalog.jsonb_build_object('refund_id',v_refund.id,'payment_id',v_refund.payment_id,
    'status',v_refund.status,'amount',v_refund.amount::text,'version',v_refund.version::text,
    'updated_at',v_refund.updated_at);
  insert into private.payment_admin_operation_receipts(actor_id,operation_id,operation_kind,request_sha256,response)
    values(v_actor,p_operation_id,'transition_refund',v_hash,v_response);
  return v_response;
end;
$$;

-- Seven authenticated entry points. Revoke deployment/default privileges first;
-- the server-side role guard inside every RPC remains authoritative.
revoke all on function
  public.admin_list_payment_reconciliation(text,text,timestamptz,timestamptz,integer,jsonb),
  public.admin_get_payment_operations_report(timestamptz,timestamptz),
  public.admin_list_payment_refunds(uuid,text,timestamptz,timestamptz,integer),
  public.admin_get_payment_operations_timeline(uuid),
  public.admin_resolve_late_payment(uuid,bigint,bigint,text,text,uuid),
  public.admin_request_payment_refund(uuid,uuid,bigint,text,bigint,uuid),
  public.admin_transition_payment_refund(uuid,bigint,text,text,text,uuid)
  from public,anon,authenticated;
do $function_acl$
begin
  if exists(select 1 from pg_catalog.pg_roles where rolname='service_role') then
    revoke all on function
      public.admin_list_payment_reconciliation(text,text,timestamptz,timestamptz,integer,jsonb),
      public.admin_get_payment_operations_report(timestamptz,timestamptz),
      public.admin_list_payment_refunds(uuid,text,timestamptz,timestamptz,integer),
      public.admin_get_payment_operations_timeline(uuid),
      public.admin_resolve_late_payment(uuid,bigint,bigint,text,text,uuid),
      public.admin_request_payment_refund(uuid,uuid,bigint,text,bigint,uuid),
      public.admin_transition_payment_refund(uuid,bigint,text,text,text,uuid),
      private.payment_operations_immutable_guard(),
      private.payment_admin_receipt_guard(),
      private.payment_reconciliation_guard(),
      private.payment_refund_guard()
      from service_role;
  end if;
end;
$function_acl$;
grant execute on function public.admin_list_payment_reconciliation(text,text,timestamptz,timestamptz,integer,jsonb) to authenticated;
grant execute on function public.admin_get_payment_operations_report(timestamptz,timestamptz) to authenticated;
grant execute on function public.admin_list_payment_refunds(uuid,text,timestamptz,timestamptz,integer) to authenticated;
grant execute on function public.admin_get_payment_operations_timeline(uuid) to authenticated;
grant execute on function public.admin_resolve_late_payment(uuid,bigint,bigint,text,text,uuid) to authenticated;
grant execute on function public.admin_request_payment_refund(uuid,uuid,bigint,text,bigint,uuid) to authenticated;
grant execute on function public.admin_transition_payment_refund(uuid,bigint,text,text,text,uuid) to authenticated;

revoke all on function private.payment_operations_immutable_guard(),private.payment_admin_receipt_guard(),
  private.payment_reconciliation_guard(),private.payment_refund_guard() from public,anon,authenticated;

commit;
