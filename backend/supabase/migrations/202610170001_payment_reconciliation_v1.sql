-- Evidence-bound SePay Live exception recovery. No configuration/permission seeds.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';

do $preflight$
declare v_definition text;
begin
  if pg_catalog.to_regprocedure('private.process_verified_bank_transaction(jsonb)') is null
     or pg_catalog.to_regprocedure('private.payment_bank_record_guard()') is null
     or pg_catalog.to_regprocedure('private.payment_bank_intent_guard()') is null
     or pg_catalog.to_regprocedure('private.payment_core_guard()') is null
     or pg_catalog.to_regprocedure('private.system_require_session()') is null
     or pg_catalog.to_regprocedure('private.admin_require_role(text[])') is null
     or pg_catalog.to_regclass('private.payment_reconciliation_cases') is null
     or pg_catalog.to_regclass('private.payment_refunds') is null then
    raise exception 'PAYMENT_RECONCILIATION_MISSING_PREREQUISITES';
  end if;
  if pg_catalog.to_regclass('private.payment_reconciliation_settlements') is not null
     or pg_catalog.to_regprocedure('public.admin_reconcile_bank_transaction(uuid,uuid,bigint,bigint,bigint,text,uuid)') is not null then
    raise exception 'PAYMENT_RECONCILIATION_ALREADY_EXISTS';
  end if;
  v_definition:=pg_catalog.pg_get_functiondef('private.payment_bank_record_guard()'::regprocedure);
  if pg_catalog.strpos(v_definition,'      if old.status<>''unverified'' or new.status not in (''verified'',''rejected'') then')=0 then
    raise exception 'RECONCILIATION_RECORD_GUARD_DRIFT';
  end if;
  v_definition:=pg_catalog.pg_get_functiondef('private.payment_bank_intent_guard()'::regprocedure);
  if pg_catalog.strpos(v_definition,'    elsif old.status=''ready'' and new.status=''verified'' then')=0 then
    raise exception 'RECONCILIATION_INTENT_GUARD_DRIFT';
  end if;
  v_definition:=pg_catalog.pg_get_functiondef('private.payment_core_guard()'::regprocedure);
  if pg_catalog.strpos(v_definition,'and r.status=''received'' and t.amount=old.amount_expected and t.currency=old.currency')=0 then
    raise exception 'RECONCILIATION_PAYMENT_GUARD_DRIFT';
  end if;
end;
$preflight$;

create table private.payment_reconcile_permissions (
  admin_id uuid primary key references public.admin_profiles(id),
  permission text not null default 'payment.reconcile' check(permission='payment.reconcile'),
  enabled boolean not null,
  version bigint not null check(version>0)
);
create table private.payment_reconcile_permission_audit (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.admin_profiles(id),
  admin_id uuid not null references public.admin_profiles(id),
  enabled boolean not null, version bigint not null, reason text not null,
  recorded_at timestamptz not null default clock_timestamp(),
  unique(admin_id,version)
);
create table private.payment_reconciliation_settlements (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null unique references private.bank_transactions(id),
  payment_id uuid not null unique references public.payments(id),
  intent_id uuid not null references private.payment_bank_intents(id),
  receipt_id uuid not null references private.payment_webhook_receipts(id),
  actor_id uuid not null references public.admin_profiles(id),
  operation_id uuid not null,
  reason text not null check(length(btrim(reason)) between 10 and 1000),
  request_sha256 text not null check(request_sha256 ~ '^[0-9a-f]{64}$'),
  transaction_version bigint not null check(transaction_version>0),
  payment_version bigint not null check(payment_version>0),
  intent_version bigint not null check(intent_version>0),
  occurred_at timestamptz not null check(isfinite(occurred_at)),
  processed_at timestamptz not null default clock_timestamp(),
  created_xid xid8 not null default pg_current_xact_id(),
  old_states jsonb not null,
  new_states jsonb not null,
  evidence jsonb not null,
  unique(actor_id,operation_id)
);
alter table private.payment_reconcile_permissions enable row level security;
alter table private.payment_reconcile_permission_audit enable row level security;
alter table private.payment_reconciliation_settlements enable row level security;
revoke all on private.payment_reconcile_permissions,private.payment_reconcile_permission_audit,
  private.payment_reconciliation_settlements from public,anon,authenticated,service_role;

create function private.payment_reconcile_immutable() returns trigger
language plpgsql set search_path='' as $$
begin raise exception 'PAYMENT_RECONCILIATION_AUDIT_IMMUTABLE' using errcode='23514'; end $$;
create trigger reconcile_settlement_immutable before update or delete or truncate
  on private.payment_reconciliation_settlements for each statement execute function private.payment_reconcile_immutable();
create trigger reconcile_permission_immutable before update or delete or truncate
  on private.payment_reconcile_permission_audit for each statement execute function private.payment_reconcile_immutable();

create function private.require_payment_reconcile() returns void
language plpgsql stable security definer set search_path='' as $$
begin
  perform private.system_require_session();
  if not exists(select 1 from public.admin_profiles a where a.id=auth.uid() and a.status='active'
    and (a.role='super_admin' or (a.role in ('finance','operator') and exists(
      select 1 from private.payment_reconcile_permissions g where g.admin_id=a.id and g.enabled and g.permission='payment.reconcile')))) then
    raise exception 'PAYMENT_RECONCILE_FORBIDDEN' using errcode='42501';
  end if;
end $$;

create function public.admin_set_payment_reconcile_permission(
  p_admin_id uuid,p_enabled boolean,p_expected_version bigint,p_reason text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_version bigint;
begin
  perform private.system_require_session();
  perform private.admin_require_role(array['super_admin']);
  if p_admin_id is null or p_enabled is null or p_expected_version is null or p_expected_version<0
    or p_reason is null or length(btrim(p_reason)) not between 10 and 1000 then
    raise exception 'RECONCILIATION_INVALID_INPUT' using errcode='22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('payment-reconcile-permission:'||p_admin_id::text,0));
  perform 1 from public.admin_profiles where id=p_admin_id and role in ('finance','operator') and status='active' for update;
  if not found then raise exception 'RECONCILIATION_ADMIN_INELIGIBLE' using errcode='22023'; end if;
  select version into v_version from private.payment_reconcile_permissions where admin_id=p_admin_id for update;
  if coalesce(v_version,0)<>p_expected_version then raise exception 'STALE_VERSION' using errcode='40001'; end if;
  v_version:=coalesce(v_version,0)+1;
  insert into private.payment_reconcile_permissions(admin_id,enabled,version) values(p_admin_id,p_enabled,v_version)
    on conflict(admin_id) do update set enabled=excluded.enabled,version=excluded.version;
  insert into private.payment_reconcile_permission_audit(actor_id,admin_id,enabled,version,reason)
    values(auth.uid(),p_admin_id,p_enabled,v_version,btrim(p_reason));
  return jsonb_build_object('permission','payment.reconcile','enabled',p_enabled,'version',v_version::text);
end $$;

-- Only canonical or legacy intent tokens retained in authenticated transaction
-- evidence bind a candidate. Amount/customer/time alone NEVER select a payment.
create function private.reconciliation_reference_tokens(p_reference text) returns text[]
language sql immutable set search_path='' as $$
  select coalesce(array_agg(distinct token),'{}'::text[]) from regexp_split_to_table(coalesce(p_reference,''),'[^A-Za-z0-9-]+') token
  where token ~ '^BK[0-9]{19}$' or token ~ '^BK-[A-F0-9]{32}$';
$$;

create function private.payment_reconciliation_candidates(p_transaction_id uuid,p_payment_id uuid default null)
returns table(payment_id uuid,intent_id uuid,payment_code text,request_code text,payment_status text,
  amount_expected text,reference text,intent_reference text,payment_version text,intent_version text,
  expires_at timestamptz,beneficiary_match boolean,reference_match boolean,time_match boolean,
  context_match boolean,eligible boolean,risk_flags text[])
language sql stable security definer set search_path='' as $$
with evidence as (
 select p.id payment_id,i.id intent_id,p.payment_code,r.request_code,p.status payment_status,
   p.amount_expected::text amount_expected,s.transfer_content reference,i.reference intent_reference,
   p.version::text payment_version,i.version::text intent_version,i.expires_at,
   coalesce(t.beneficiary_bank_bin=s.bank_bin and t.beneficiary_account_number=s.account_number
     and c.bank_bin=s.bank_bin and c.account_number=s.account_number,false) beneficiary_match,
   cardinality(private.reconciliation_reference_tokens(t.transfer_reference))=1
     and (s.transfer_content=any(private.reconciliation_reference_tokens(t.transfer_reference))
       or i.reference=any(private.reconciliation_reference_tokens(t.transfer_reference))) reference_match,
   coalesce(t.occurred_at>=i.created_at and t.occurred_at<i.expires_at and t.occurred_at<=statement_timestamp(),false) time_match,
   coalesce(r.status='completed' and a.state='completed' and r.customer_id=p.customer_id and r.provider_id=p.rescuer_id
     and a.request_id=p.request_id and a.rescuer_id=p.rescuer_id and a.completion_quote_id=p.quote_id
     and i.request_id=p.request_id,false) context_match,
   array_remove(array[
     case when t.provider<>'sepay' or t.provider_scope<>'sepay_live' or t.direction<>'credit' then 'not_sepay_live_credit' end,
     case when w.id is null or not w.authentication_verified or w.normalized_sha256 is distinct from t.normalized_sha256
       or t.normalized_sha256 is null or w.provider<>t.provider or w.provider_scope<>t.provider_scope
       or w.status<>'processed' or w.result_code is distinct from t.rejection_code then 'unverified_receipt' end,
     case when t.status<>'rejected' or t.matched_payment_id is not null then 'transaction_used_or_ineligible' end,
     case when t.rejection_code is null or t.rejection_code not in ('reference_unmatched','intent_expired') then 'rejection_requires_manual_review' end,
     case when t.amount<>p.amount_expected or t.amount<>i.expected_amount then 'amount_mismatch' end,
     case when t.currency<>'VND' or p.currency<>'VND' or i.currency<>'VND' then 'currency_mismatch' end,
     case when p.status<>'awaiting_payment' or p.method is distinct from 'bank_transfer' or p.amount_received is not null
       or p.paid_at is not null or p.verified_at is not null then 'payment_ineligible' end,
     case when i.status not in ('ready','expired') or exists(select 1 from private.payment_bank_intents other
       where other.payment_id=p.id and other.id<>i.id and other.status in ('created','ready','matched','verified')) then 'intent_superseded_or_ineligible' end,
     case when i.provider is not null and (i.provider<>t.provider or i.provider_scope<>t.provider_scope) then 'intent_provider_mismatch' end,
     case when c.singleton is null or not c.enabled or not c.verification_enabled
       or c.verification_provider is distinct from 'sepay' or c.verification_scope is distinct from 'sepay_live'
       or c.reference_policy<>'bank_sequence_v1' or (private.system_value('payment.bank_enabled'))::boolean is not true then 'verification_or_bank_disabled' end,
     case when exists(select 1 from private.bank_transactions used where used.matched_payment_id=p.id and used.status='verified')
       or exists(select 1 from public.payment_events e where e.payment_id=p.id and e.event_type='bank_payment_verified') then 'payment_already_allocated' end,
     case when exists(select 1 from private.payment_reconciliation_settlements x where x.transaction_id=t.id or x.payment_id=p.id)
       or exists(select 1 from private.payment_reconciliation_cases x where x.bank_transaction_id=t.id)
       or exists(select 1 from private.payment_refunds x where x.bank_transaction_id=t.id and x.status<>'failed') then 'already_reconciled_or_refunded' end,
     case when p.version=9223372036854775807 or i.version=9223372036854775807 or t.version=9223372036854775807 then 'version_exhausted' end
   ],null) initial_flags
 from private.bank_transactions t
 join private.payment_bank_intents i on (p_payment_id is not null and i.payment_id=p_payment_id)
   or (p_payment_id is null and (i.reference=any(private.reconciliation_reference_tokens(t.transfer_reference))
     or exists(select 1 from private.payment_bank_qr_snapshots s2 where s2.intent_id=i.id
       and s2.transfer_content=any(private.reconciliation_reference_tokens(t.transfer_reference)))))
 join public.payments p on p.id=i.payment_id
 join private.payment_bank_qr_snapshots s on s.intent_id=i.id
 join public.rescue_requests r on r.id=p.request_id
 join public.rescue_request_assignments a on a.id=p.assignment_id
 left join private.payment_webhook_receipts w on w.id=t.receipt_id
 left join private.payment_bank_config c on c.singleton
 where t.id=p_transaction_id
), flagged as (
 select e.*, initial_flags||array_remove(array[
   case when not beneficiary_match then 'beneficiary_mismatch' end,
   case when not reference_match then 'reference_evidence_missing_or_ambiguous' end,
   case when not time_match then 'transfer_outside_intent_window' end,
   case when not context_match then 'request_context_mismatch' end],null) flags from evidence e
)
select payment_id,intent_id,payment_code,request_code,payment_status,amount_expected,reference,intent_reference,
 payment_version,intent_version,expires_at,beneficiary_match,reference_match,time_match,context_match,
 cardinality(flags)=0,flags from flagged;
$$;

create function public.admin_list_reconciliation_exceptions(p_limit integer default 50,p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_rows jsonb; v_count bigint;
begin
  perform private.system_require_session();
  perform private.require_payment_reconcile();
  if p_limit is null or p_limit not between 1 and 100 or p_offset is null or p_offset not between 0 and 100000 then
    raise exception 'RECONCILIATION_INVALID_INPUT' using errcode='22023'; end if;
  select count(*) into v_count from private.bank_transactions t where t.status='rejected'
    and t.provider='sepay' and t.provider_scope='sepay_live'
    and not exists(select 1 from private.payment_reconciliation_cases c where c.bank_transaction_id=t.id);
  select coalesce(jsonb_agg(to_jsonb(x)),'[]') into v_rows from (
    select t.id,t.external_transaction_id,t.provider,t.provider_scope,t.amount::text,t.currency,t.direction,
      t.transfer_reference reference,t.status,t.rejection_code,t.occurred_at,t.received_at,t.version::text,
      case when t.rejection_code='amount_mismatch' then 'manual_review_refund_required'
        when t.rejection_code='beneficiary_mismatch' then 'beneficiary_blocked'
        else 'evidence_review_required' end policy
    from private.bank_transactions t where t.status='rejected' and t.provider='sepay' and t.provider_scope='sepay_live'
      and not exists(select 1 from private.payment_reconciliation_cases c where c.bank_transaction_id=t.id)
    order by t.received_at desc,t.id limit p_limit offset p_offset
  ) x;
  return jsonb_build_object('permission','payment.reconcile','pending_count',v_count,'rows',v_rows);
end $$;

create function public.admin_preview_payment_reconciliation(p_transaction_id uuid,p_payment_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_tx jsonb; v_candidates jsonb;
begin
  perform private.system_require_session();
  perform private.require_payment_reconcile();
  select jsonb_build_object('id',t.id,'external_transaction_id',t.external_transaction_id,'provider',t.provider,
    'provider_scope',t.provider_scope,'amount',t.amount::text,'currency',t.currency,'direction',t.direction,
    'reference',t.transfer_reference,'status',t.status,'rejection_code',t.rejection_code,'occurred_at',t.occurred_at,
    'received_at',t.received_at,'version',t.version::text,'receipt_id',w.id,'receipt_status',w.status,
    'authentication_verified',w.authentication_verified,'already_reconciled',exists(
      select 1 from private.payment_reconciliation_settlements x where x.transaction_id=t.id)) into v_tx
    from private.bank_transactions t left join private.payment_webhook_receipts w on w.id=t.receipt_id where t.id=p_transaction_id;
  if v_tx is null then raise exception 'RECONCILIATION_NOT_FOUND' using errcode='P0002'; end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.eligible desc,x.expires_at desc),'[]') into v_candidates
    from private.payment_reconciliation_candidates(p_transaction_id,p_payment_id) x;
  return jsonb_build_object('transaction',v_tx,'candidates',v_candidates);
end $$;

-- Narrow extensions to existing guards: only a fully validated immutable allocation
-- inserted by the guarded RPC in THIS transaction can authorize these transitions.
-- Historical receipt and normalized transaction facts are never rewritten.
do $guards$
declare v_definition text; v_anchor text; v_replacement text;
begin
  v_definition:=pg_get_functiondef('private.payment_bank_record_guard()'::regprocedure);
  v_anchor:='      if old.status<>''unverified'' or new.status not in (''verified'',''rejected'') then';
  v_replacement:=$body$
      if old.status='rejected' and new.status='verified' then
        if new.rejection_code is not null or new.version<>old.version+1 or not exists(
          select 1 from private.payment_reconciliation_settlements x where x.transaction_id=old.id
            and x.payment_id=new.matched_payment_id and x.intent_id=new.matched_intent_id
            and x.transaction_version=old.version and x.receipt_id=old.receipt_id
            and x.created_xid=pg_current_xact_id() and x.actor_id=auth.uid()) then
          raise exception 'RECONCILIATION_EVIDENCE_REQUIRED' using errcode='23514';
        end if;
        new.updated_at:=v_now;
        return new;
      end if;
$body$||v_anchor;
  if position(v_anchor in v_definition)=0 then raise exception 'RECONCILIATION_RECORD_GUARD_DRIFT'; end if;
  execute replace(v_definition,v_anchor,v_replacement);
  v_definition:=pg_get_functiondef('private.payment_bank_intent_guard()'::regprocedure);
  v_anchor:='    elsif old.status=''ready'' and new.status=''verified'' then';
  v_replacement:=$body$
    elsif old.status in ('ready','expired') and new.status='verified' and exists(
      select 1 from private.payment_reconciliation_settlements x join private.bank_transactions t on t.id=x.transaction_id
      where x.intent_id=old.id and x.payment_id=old.payment_id and x.intent_version=old.version
        and x.created_xid=pg_current_xact_id() and x.actor_id=auth.uid()
        and t.status='verified' and t.matched_payment_id=old.payment_id and t.matched_intent_id=old.id) then
      null;
$body$||v_anchor;
  if position(v_anchor in v_definition)=0 then raise exception 'RECONCILIATION_INTENT_GUARD_DRIFT'; end if;
  execute replace(v_definition,v_anchor,v_replacement);
  v_definition:=pg_get_functiondef('private.payment_core_guard()'::regprocedure);
  v_anchor:='and r.status=''received'' and t.amount=old.amount_expected and t.currency=old.currency';
  v_replacement:=$body$and (r.status='received' or exists(select 1 from private.payment_reconciliation_settlements x
                 where x.transaction_id=t.id and x.payment_id=old.id and x.receipt_id=r.id
                   and x.payment_version=old.version and x.created_xid=pg_current_xact_id() and x.actor_id=auth.uid()))
               and t.amount=old.amount_expected and t.currency=old.currency$body$;
  if position(v_anchor in v_definition)=0 then raise exception 'RECONCILIATION_PAYMENT_GUARD_DRIFT'; end if;
  execute replace(v_definition,v_anchor,v_replacement);
end $guards$;

create function public.admin_reconcile_bank_transaction(
  p_transaction_id uuid,p_payment_id uuid,p_expected_transaction_version bigint,p_expected_payment_version bigint,
  p_expected_intent_version bigint,p_reason text,p_operation_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare t private.bank_transactions; p public.payments; i private.payment_bank_intents;
  x private.payment_reconciliation_settlements; v_candidate record; v_hash text; v_sequence bigint; v_request uuid;
  v_actor_role text; v_grant_enabled boolean;
begin
  perform private.system_require_session();
  perform private.require_payment_reconcile();
  -- Lock role and explicit grant against concurrent revocation.
  perform private.admin_require_role(array['super_admin','finance','operator']);
  select role into v_actor_role from public.admin_profiles where id=auth.uid();
  if v_actor_role<>'super_admin' then
    select enabled into v_grant_enabled from private.payment_reconcile_permissions where admin_id=auth.uid() for share;
    if not found or not v_grant_enabled then
      raise exception 'PAYMENT_RECONCILE_FORBIDDEN' using errcode='42501';
    end if;
  end if;
  if p_transaction_id is null or p_payment_id is null or p_operation_id is null
    or p_expected_transaction_version is null or p_expected_transaction_version<1
    or p_expected_payment_version is null or p_expected_payment_version<1
    or p_expected_intent_version is null or p_expected_intent_version<1
    or p_reason is null or length(btrim(p_reason)) not between 10 and 1000 then
    raise exception 'RECONCILIATION_INVALID_INPUT' using errcode='22023'; end if;
  v_hash:=encode(sha256(convert_to(jsonb_build_array(p_transaction_id,p_payment_id,p_expected_transaction_version,
    p_expected_payment_version,p_expected_intent_version,btrim(p_reason))::text,'UTF8')),'hex');
  perform pg_advisory_xact_lock(hashtextextended('reconcile-op:'||auth.uid()::text||':'||p_operation_id::text,0));
  select * into x from private.payment_reconciliation_settlements where actor_id=auth.uid() and operation_id=p_operation_id;
  if found then
    if x.request_sha256<>v_hash then raise exception 'IDEMPOTENCY_CONFLICT' using errcode='22023'; end if;
    return jsonb_build_object('changed',false,'payment_id',x.payment_id,'transaction_id',x.transaction_id,'status','paid','audit_id',x.id);
  end if;
  -- Same provider serialization as webhook ingestion; parent-first locks match
  -- customer bank selection/regeneration. No network calls while locked.
  perform pg_advisory_xact_lock(hashtextextended('bank-ingest:'||jsonb_build_array('sepay','sepay_live')::text,0));
  select request_id into v_request from public.payments where id=p_payment_id;
  perform 1 from public.rescue_requests where id=v_request for update;
  perform 1 from public.rescue_request_assignments where request_id=v_request for share;
  select * into p from public.payments where id=p_payment_id for update;
  perform 1 from private.payment_bank_config where singleton for share;
  perform 1 from private.system_config for share;
  select * into t from private.bank_transactions where id=p_transaction_id for update;
  if p.id is null or t.id is null then raise exception 'RECONCILIATION_NOT_FOUND' using errcode='P0002'; end if;
  if p.version<>p_expected_payment_version or t.version<>p_expected_transaction_version then
    raise exception 'STALE_VERSION' using errcode='40001'; end if;
  select * into v_candidate from private.payment_reconciliation_candidates(t.id,p.id) c where c.eligible;
  if not found then raise exception 'RECONCILIATION_EVIDENCE_REQUIRED' using errcode='23514'; end if;
  select * into i from private.payment_bank_intents where id=v_candidate.intent_id for update;
  if i.version<>p_expected_intent_version then raise exception 'STALE_VERSION' using errcode='40001'; end if;
  perform 1 from private.payment_webhook_receipts where id=t.receipt_id for share;
  -- Recheck after acquiring all resource locks, never trust the preview/DTO.
  if not exists(select 1 from private.payment_reconciliation_candidates(t.id,p.id) c where c.intent_id=i.id and c.eligible) then
    raise exception 'RECONCILIATION_EVIDENCE_REQUIRED' using errcode='23514'; end if;
  insert into private.payment_reconciliation_settlements(transaction_id,payment_id,intent_id,receipt_id,actor_id,
    operation_id,reason,request_sha256,transaction_version,payment_version,intent_version,occurred_at,old_states,new_states,evidence)
  values(t.id,p.id,i.id,t.receipt_id,auth.uid(),p_operation_id,btrim(p_reason),v_hash,t.version,p.version,i.version,t.occurred_at,
    jsonb_build_object('payment',p.status,'transaction',t.status,'intent',i.status,'rejection_code',t.rejection_code),
    jsonb_build_object('payment','paid','transaction','verified','intent','verified','payment_version',(p.version+1)::text,
      'transaction_version',(t.version+1)::text,'intent_version',(i.version+1)::text),
    jsonb_build_object('provider',t.provider,'provider_scope',t.provider_scope,'external_transaction_id',t.external_transaction_id,
      'direction',t.direction,'amount',t.amount::text,'amount_expected',p.amount_expected::text,'currency',t.currency,
      'reference',t.transfer_reference,'intent_reference',i.reference,'canonical_reference',v_candidate.reference,
      'beneficiary_exact',true,'reference_bound',true,'within_intent_window',true,'request_context_valid',true,
      'authentication_verified',true,'request_id',p.request_id,'intent_created_at',i.created_at,'intent_expires_at',i.expires_at))
    returning * into x;
  update private.bank_transactions set status='verified',matched_payment_id=p.id,matched_intent_id=i.id,
    rejection_code=null,version=version+1 where id=t.id;
  update private.payment_bank_intents set status='verified',version=version+1 where id=i.id;
  update public.payments set status='paid',amount_received=t.amount,version=version+1 where id=p.id;
  select coalesce(max(event_sequence),0)+1 into v_sequence from public.payment_events where payment_id=p.id;
  insert into public.payment_events(payment_id,request_id,event_type,actor_type,old_status,new_status,amount,
    operation_id,payment_version,event_sequence) values(p.id,p.request_id,'bank_payment_verified','system',
      'awaiting_payment','paid',t.amount,t.id,p.version+1,v_sequence);
  insert into private.payment_bank_audit(transaction_id,action,new_status,resource_version)
    values(t.id,'match_succeeded','verified',t.version+1),(t.id,'payment_transitioned','verified',t.version+1);
  return jsonb_build_object('changed',true,'payment_id',p.id,'transaction_id',t.id,'status','paid','audit_id',x.id);
end $$;

revoke all on function private.payment_reconcile_immutable(),private.require_payment_reconcile(),
  private.reconciliation_reference_tokens(text),private.payment_reconciliation_candidates(uuid,uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.admin_set_payment_reconcile_permission(uuid,boolean,bigint,text),
  public.admin_list_reconciliation_exceptions(integer,integer),public.admin_preview_payment_reconciliation(uuid,uuid),
  public.admin_reconcile_bank_transaction(uuid,uuid,bigint,bigint,bigint,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.admin_set_payment_reconcile_permission(uuid,boolean,bigint,text),
  public.admin_list_reconciliation_exceptions(integer,integer),public.admin_preview_payment_reconciliation(uuid,uuid),
  public.admin_reconcile_bank_transaction(uuid,uuid,bigint,bigint,bigint,text,uuid) to authenticated;
commit;
