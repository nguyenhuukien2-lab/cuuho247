-- GD6C provider-neutral engine. NO provider integration, seeds, secrets or API grants.
-- Verification defaults OFF, independently of the GD6B QR switch.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
do $preflight$
begin
  if to_regprocedure('public.customer_get_bank_payment(uuid)') is null then
    raise exception 'BANK_VERIFICATION_MISSING_PREREQUISITES';
  end if;
  if to_regprocedure('private.process_verified_bank_transaction(jsonb)') is not null then
    raise exception 'BANK_VERIFICATION_ALREADY_EXISTS';
  end if;
  if exists(select 1 from pg_catalog.pg_publication where puballtables)
     or exists(select 1 from pg_catalog.pg_publication_namespace where pnnspid='private'::regnamespace)
     or exists(select 1 from pg_catalog.pg_publication_tables where schemaname='private'
       or (schemaname='public' and tablename='payment_events')) then
    raise exception 'BANK_VERIFICATION_PUBLICATION_UNSAFE';
  end if;
  if pg_catalog.has_table_privilege('authenticated','public.payments','INSERT,UPDATE,DELETE')
     or pg_catalog.has_table_privilege('anon','public.payments','SELECT,INSERT,UPDATE,DELETE')
     or (select count(*) from pg_catalog.pg_class where oid in ('private.payment_bank_config'::regclass,
       'private.payment_bank_intents'::regclass,'private.bank_transactions'::regclass,
       'private.payment_webhook_receipts'::regclass,'private.payment_bank_audit'::regclass,
       'public.payments'::regclass,'public.payment_events'::regclass) and relrowsecurity)<>7 then
    raise exception 'BANK_VERIFICATION_SECURITY_DRIFT';
  end if;
end;
$preflight$;

alter table private.payment_bank_config
  add column verification_enabled boolean not null default false,
  add column verification_provider text check(verification_provider ~ '^[a-z][a-z0-9_]{0,63}$'),
  add column verification_scope text check(length(verification_scope) between 1 and 128),
  add column require_beneficiary boolean not null default true,
  add constraint bank_verification_config_complete check(not verification_enabled
    or (verification_provider is not null and verification_scope is not null));
-- Provider scope is an authenticated account/environment binding, never a secret.
-- Missing beneficiary is acceptable only after an explicit provider-contract review
-- establishes that scope itself identifies the exact configured BIN/account.
alter table private.payment_webhook_receipts
  add column authentication_verified boolean not null default false,
  add column authentication_method text check(authentication_method in ('signature','token','mtls')),
  add column normalized_sha256 text check(normalized_sha256 ~ '^[0-9a-f]{64}$'),
  add column result_code text check(result_code ~ '^[a-z][a-z0-9_]{0,63}$'),
  add constraint bank_receipt_auth_evidence check(not authentication_verified or
    (authentication_method is not null and normalized_sha256 is not null
      and (authentication_method<>'signature' or signature_verified)));
alter table private.bank_transactions
  add column beneficiary_bank_bin text check(length(beneficiary_bank_bin) between 1 and 64),
  add column beneficiary_account_number text check(length(beneficiary_account_number) between 1 and 128),
  add column normalized_sha256 text check(normalized_sha256 ~ '^[0-9a-f]{64}$'),
  add column rejection_code text check(rejection_code ~ '^[a-z][a-z0-9_]{0,63}$');
create unique index payment_events_one_bank_verified on public.payment_events(payment_id)
  where event_type='bank_payment_verified';

-- Reuse the append-only audit table for attempts as well as lifecycle versions.
alter table private.payment_bank_audit
  drop constraint payment_bank_audit_intent_id_resource_version_key,
  drop constraint payment_bank_audit_transaction_id_resource_version_key,
  drop constraint payment_bank_audit_receipt_id_resource_version_key,
  drop constraint bank_audit_one_resource,
  add column action text not null default 'lifecycle' check(action in
    ('lifecycle','webhook_received','auth_verified','auth_failed','duplicate','conflict',
     'transaction_normalized','match_succeeded','match_rejected','payment_transitioned')),
  add column reason_code text check(reason_code ~ '^[a-z][a-z0-9_]{0,63}$'),
  add column provider text check(provider ~ '^[a-z][a-z0-9_]{0,63}$'),
  add column provider_scope text check(length(provider_scope) between 1 and 128),
  add column body_sha256 text check(body_sha256 ~ '^[0-9a-f]{64}$'),
  add constraint bank_audit_one_resource check(num_nonnulls(intent_id,transaction_id,receipt_id)=1
    or (num_nonnulls(intent_id,transaction_id,receipt_id)=0 and action='auth_failed'
      and provider is not null and provider_scope is not null and body_sha256 is not null));
create unique index bank_audit_intent_lifecycle on private.payment_bank_audit(intent_id,resource_version) where action='lifecycle';
create unique index bank_audit_transaction_lifecycle on private.payment_bank_audit(transaction_id,resource_version) where action='lifecycle';
create unique index bank_audit_receipt_lifecycle on private.payment_bank_audit(receipt_id,resource_version) where action='lifecycle';
create or replace function private.payment_bank_audit_guard() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if tg_op<>'INSERT' then raise exception 'BANK_AUDIT_IMMUTABLE' using errcode='23514'; end if;
  if new.action='lifecycle' and pg_catalog.pg_trigger_depth()<2 then
    raise exception 'BANK_AUDIT_TRIGGER_ONLY' using errcode='23514';
  end if;
  new.actor_db_role:=current_user;
  new.recorded_at:=pg_catalog.clock_timestamp();
  return new;
end;
$$;

-- No canonical receipt for unauthenticated IDs: attackers cannot poison dedupe.
-- Only the future trusted adapter may call this owner-only primitive; body is
-- discarded. Provider/scope are server-selected, never taken from failed input.
create function private.record_bank_auth_failure(p_provider text,p_scope text,p_body_sha256 text)
returns void language sql security invoker set search_path='' as $$
  insert into private.payment_bank_audit(action,new_status,resource_version,reason_code,provider,provider_scope,body_sha256)
  values('auth_failed','rejected',1,'authentication_failed',p_provider,p_scope,p_body_sha256);
$$;

create or replace function private.payment_bank_record_guard() returns trigger
language plpgsql security invoker set search_path='' as $$
declare v_now timestamptz:=pg_catalog.clock_timestamp();
begin
  if tg_op in ('DELETE','TRUNCATE') then raise exception 'BANK_RECORD_DELETE_FORBIDDEN' using errcode='23514'; end if;
  if tg_op='UPDATE' then
    if tg_table_name='bank_transactions' then
      if (pg_catalog.to_jsonb(new)-array['status','version','updated_at','matched_payment_id','matched_intent_id','rejection_code'])
         is distinct from
         (pg_catalog.to_jsonb(old)-array['status','version','updated_at','matched_payment_id','matched_intent_id','rejection_code']) then
        raise exception 'BANK_RECORD_IMMUTABLE' using errcode='23514';
      end if;
      if new.status=old.status then
        if (pg_catalog.to_jsonb(new)-'updated_at') is distinct from (pg_catalog.to_jsonb(old)-'updated_at') then
          raise exception 'BANK_RECORD_IMMUTABLE' using errcode='23514';
        end if;
        return old;
      end if;
      if old.status<>'unverified' or new.status not in ('verified','rejected') then
        raise exception 'BANK_VERIFICATION_NOT_ENABLED' using errcode='23514';
      end if;
      if new.status='verified' then
        if new.rejection_code is not null or not exists(
          select 1 from private.payment_webhook_receipts r
          join private.payment_bank_intents i on i.id=new.matched_intent_id and i.payment_id=new.matched_payment_id
          join private.payment_bank_qr_snapshots s on s.intent_id=i.id
          join public.payments p on p.id=i.payment_id and p.request_id=i.request_id
          join private.payment_bank_config c on c.singleton
          where r.id=new.receipt_id and r.provider=new.provider and r.provider_scope=new.provider_scope
            and r.status='received' and r.authentication_verified and r.normalized_sha256=new.normalized_sha256
            and new.direction='credit' and new.amount=i.expected_amount and new.currency=i.currency
            and new.transfer_reference=s.transfer_content and new.occurred_at>=i.created_at
            and new.occurred_at<i.expires_at and new.occurred_at<=v_now
            and i.status='ready' and i.expires_at>v_now
            and p.status='awaiting_payment' and p.method='bank_transfer'
            and (i.provider is null or (i.provider=new.provider and i.provider_scope=new.provider_scope))
            and p.amount_expected=i.expected_amount and p.currency=i.currency
            and c.verification_enabled and c.reference_policy='bank_sequence_v1'
            and c.verification_provider=new.provider and c.verification_scope=new.provider_scope
            and c.bank_bin=s.bank_bin and c.account_number=s.account_number
            and (new.beneficiary_bank_bin is null or new.beneficiary_bank_bin=s.bank_bin)
            and (new.beneficiary_account_number is null or new.beneficiary_account_number=s.account_number)
            and (not c.require_beneficiary or (new.beneficiary_bank_bin is not null and new.beneficiary_account_number is not null))) then
          raise exception 'BANK_MATCH_EVIDENCE_REQUIRED' using errcode='23514';
        end if;
      end if;
    else
      if (pg_catalog.to_jsonb(new)-array['status','version','updated_at','result_code']) is distinct from
         (pg_catalog.to_jsonb(old)-array['status','version','updated_at','result_code']) then
        raise exception 'BANK_RECORD_IMMUTABLE' using errcode='23514';
      end if;
      if new.status=old.status then
        if new.version<>old.version or new.result_code is distinct from old.result_code then
          raise exception 'BANK_VERSION_INVALID' using errcode='23514';
        end if;
        return old;
      end if;
      if not ((old.status='received' and new.status in ('processed','failed','rejected'))
          or (old.status='failed' and new.status='received'))
         or (new.status='processed' and not new.authentication_verified) then
        raise exception 'BANK_PROCESSING_NOT_ENABLED' using errcode='23514';
      end if;
    end if;
    if new.version::numeric<>old.version::numeric+1 then raise exception 'BANK_VERSION_INVALID' using errcode='23514'; end if;
    new.updated_at:=v_now;
    return new;
  end if;
  if new.version is distinct from 1::bigint then raise exception 'BANK_VERSION_INVALID' using errcode='23514'; end if;
  if tg_table_name='bank_transactions' then
    if new.status is distinct from 'unverified' or new.matched_payment_id is not null or new.matched_intent_id is not null then
      raise exception 'BANK_VERIFICATION_NOT_ENABLED' using errcode='23514';
    end if;
    if new.receipt_id is not null and not exists(select 1 from private.payment_webhook_receipts r
      where r.id=new.receipt_id and r.provider=new.provider and r.provider_scope=new.provider_scope
        and (r.signature_verified or r.authentication_verified) and r.status='received') then
      raise exception 'BANK_RECEIPT_NOT_VERIFIED' using errcode='23514';
    end if;
  elsif new.status is distinct from 'received' then
    raise exception 'BANK_PROCESSING_NOT_ENABLED' using errcode='23514';
  end if;
  new.received_at:=v_now;
  new.updated_at:=v_now;
  return new;
end;
$$;

create or replace function private.payment_core_guard() returns trigger
language plpgsql security invoker set search_path = '' as $$
declare
  v_number text;
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_request public.rescue_requests;
  v_assignment public.rescue_request_assignments;
  v_quote public.rescue_quotes;
begin
  if tg_op in ('DELETE', 'TRUNCATE') then
    raise exception 'PAYMENT_DELETE_FORBIDDEN' using errcode = '23514';
  end if;
  if tg_op = 'UPDATE' then
    if row(new.id, new.payment_code, new.request_id, new.assignment_id, new.customer_id,
           new.rescuer_id, new.quote_id, new.amount_expected, new.currency, new.created_at)
       is distinct from
       row(old.id, old.payment_code, old.request_id, old.assignment_id, old.customer_id,
           old.rescuer_id, old.quote_id, old.amount_expected, old.currency, old.created_at) then
      raise exception 'PAYMENT_SNAPSHOT_IMMUTABLE' using errcode = '23514';
    end if;
    if (pg_catalog.to_jsonb(new) - 'updated_at') is distinct from
       (pg_catalog.to_jsonb(old) - 'updated_at') then
      if old.status='awaiting_payment' and old.method='bank_transfer'
         and new.status='paid' and new.method='bank_transfer' then
        if new.amount_received is distinct from old.amount_expected or old.amount_expected<=0
           or old.paid_at is not null or old.verified_at is not null or old.amount_received is not null
           or new.version::numeric is distinct from old.version::numeric+1
           or (pg_catalog.to_jsonb(new)-array['status','version','amount_received','paid_at','verified_at','updated_at'])
              is distinct from
              (pg_catalog.to_jsonb(old)-array['status','version','amount_received','paid_at','verified_at','updated_at'])
           or not exists(select 1 from private.bank_transactions t
             join private.payment_bank_intents i on i.id=t.matched_intent_id and i.payment_id=t.matched_payment_id
             join private.payment_webhook_receipts r on r.id=t.receipt_id
             join private.payment_bank_config c on c.singleton
             where t.matched_payment_id=old.id and i.request_id=old.request_id
               and t.status='verified' and i.status='verified' and r.authentication_verified
               and r.status='received' and t.amount=old.amount_expected and t.currency=old.currency
               and c.verification_enabled and c.verification_provider=t.provider and c.verification_scope=t.provider_scope)
        then raise exception 'PAYMENT_MUTATION_NOT_ENABLED' using errcode='23514'; end if;
        new.paid_at:=v_now;
        new.verified_at:=v_now;
      elsif old.status='pending' and old.method is null and new.method='bank_transfer'
         and new.status='awaiting_payment' then
        if auth.uid() is null or auth.uid() is distinct from old.customer_id
           or new.version::numeric is distinct from old.version::numeric+1
           or (pg_catalog.to_jsonb(new)-array['method','status','version','updated_at']) is distinct from
              (pg_catalog.to_jsonb(old)-array['method','status','version','updated_at'])
           or not exists(select 1 from private.payment_bank_intents i
             join private.payment_bank_qr_snapshots s on s.intent_id=i.id
             where i.payment_id=old.id and i.request_id=old.request_id and i.status='ready'
               and i.expires_at>v_now and i.expected_amount=old.amount_expected and i.currency=old.currency)
           or not exists(select 1 from private.payment_bank_config c where c.singleton and c.enabled) then
          raise exception 'PAYMENT_MUTATION_NOT_ENABLED' using errcode='23514';
        end if;
      elsif old.status='awaiting_payment' and old.method='cash'
         and new.status='paid' and new.method='cash' then
        if auth.uid() is null or auth.uid() is distinct from old.rescuer_id
           or new.cash_received_by is distinct from auth.uid()
           or new.amount_received is distinct from old.amount_expected
           or old.amount_expected<=0 or new.verified_at is not null
           or old.amount_received is not null or old.cash_received_by is not null
           or old.cash_received_at is not null or old.paid_at is not null or old.verified_at is not null
           or new.version::numeric is distinct from old.version::numeric+1
           or (pg_catalog.to_jsonb(new)-array['status','version','amount_received','cash_received_by','cash_received_at','paid_at','updated_at'])
              is distinct from
              (pg_catalog.to_jsonb(old)-array['status','version','amount_received','cash_received_by','cash_received_at','paid_at','updated_at'])
           or not exists(select 1 from public.rescuer_profiles r where r.user_id=auth.uid() and r.verification_status='approved')
           or not exists(select 1 from public.rescue_requests r
             join public.rescue_request_assignments a on a.id=old.assignment_id and a.request_id=r.id
             where r.id=old.request_id and r.status='completed' and a.state='completed'
               and a.rescuer_id=auth.uid() and r.provider_id=auth.uid()) then
          raise exception 'PAYMENT_MUTATION_NOT_ENABLED' using errcode='23514';
        end if;
        -- One authoritative server clock; discard even privileged supplied times.
        new.cash_received_at:=v_now;
        new.paid_at:=v_now;
      elsif old.status is distinct from 'pending' or old.method is not null
         or new.status is distinct from 'awaiting_payment' or new.method is distinct from 'cash'
         or new.version::numeric is distinct from old.version::numeric + 1
         or auth.uid() is null or auth.uid() is distinct from old.customer_id
         or (pg_catalog.to_jsonb(new) - array['method','status','version','updated_at']) is distinct from
            (pg_catalog.to_jsonb(old) - array['method','status','version','updated_at']) then
        raise exception 'PAYMENT_MUTATION_NOT_ENABLED' using errcode = '23514';
      end if;
    end if;
    new.updated_at := v_now;
    return new;
  end if;
  if new.payment_code is not null then
    raise exception 'PAYMENT_CODE_SERVER_ASSIGNED' using errcode = '23514';
  end if;
  if new.status is distinct from 'pending' or new.method is not null
     or new.version is distinct from 1::bigint or new.amount_received is not null
     or new.cash_received_by is not null or new.cash_received_at is not null
     or new.paid_at is not null or new.verified_at is not null or new.failed_at is not null
     or new.cancelled_at is not null or new.refunded_at is not null
     or new.failure_code is not null or new.cancellation_reason_code is not null then
    raise exception 'PAYMENT_INITIAL_STATE_REQUIRED' using errcode = '23514';
  end if;
  v_number := pg_catalog.nextval('public.payment_code_seq'::pg_catalog.regclass)::text;
  new.payment_code := 'TT-' || pg_catalog.lpad(v_number, greatest(6, pg_catalog.length(v_number)), '0');
  new.created_at := v_now;
  new.updated_at := v_now;
  select * into v_request from public.rescue_requests where id = new.request_id for share;
  select * into v_assignment from public.rescue_request_assignments where id = new.assignment_id for share;
  select * into v_quote from public.rescue_quotes where id = new.quote_id for share;
  if v_request.id is null or v_assignment.id is null or v_quote.id is null
     or v_request.customer_id is distinct from new.customer_id
     or v_assignment.request_id is distinct from new.request_id
     or v_assignment.rescuer_id is distinct from new.rescuer_id
     or v_quote.assignment_id is distinct from new.assignment_id then
    return new;
  end if;
  if v_request.status <> 'completed' or v_assignment.state <> 'completed'
     or v_request.provider_id is distinct from new.rescuer_id
     or v_assignment.completion_quote_id is distinct from new.quote_id
     or v_assignment.current_quote_id is distinct from new.quote_id
     or v_quote.status <> 'issued'
     or new.amount_expected is distinct from v_quote.total_vnd::bigint
     or new.currency is distinct from v_quote.currency
     or v_request.quoted_price is distinct from v_quote.total_vnd then
    raise exception 'PAYMENT_COMPLETION_SNAPSHOT_INVALID' using errcode = '23514';
  end if;
  return new;
end;
$$;
create or replace function private.payment_bank_intent_guard() returns trigger
language plpgsql security invoker set search_path='' as $$
declare
  v_payment public.payments;
  v_request public.rescue_requests;
  v_assignment public.rescue_request_assignments;
  v_now timestamptz:=pg_catalog.clock_timestamp();
begin
  if tg_op in ('DELETE','TRUNCATE') then
    raise exception 'BANK_RECORD_DELETE_FORBIDDEN' using errcode='23514';
  end if;
  if tg_op='UPDATE' then
    if (pg_catalog.to_jsonb(new)-array['status','version','updated_at']) is distinct from
       (pg_catalog.to_jsonb(old)-array['status','version','updated_at']) then
      raise exception 'BANK_INTENT_SNAPSHOT_IMMUTABLE' using errcode='23514';
    end if;
    if new.status=old.status then
      if new.version<>old.version then
        raise exception 'BANK_VERSION_INVALID' using errcode='23514';
      end if;
      return old; -- No-op changes neither timestamps nor audit/version.
    end if;
    -- GD6B readiness requires an immutable server-generated QR snapshot.
    if new.version::numeric<>old.version::numeric+1 then
      raise exception 'BANK_VERSION_INVALID' using errcode='23514';
    end if;
    if old.status='created' and new.status='ready' then
      if old.expires_at<=v_now or not exists(select 1 from private.payment_bank_qr_snapshots s where s.intent_id=old.id)
         or not exists(select 1 from public.payments p where p.id=old.payment_id
           and p.status='pending' and p.method is null and p.customer_id=auth.uid()) then
        raise exception 'BANK_INTENT_TRANSITION_NOT_ENABLED' using errcode='23514';
      end if;
    elsif old.status='ready' and new.status='verified' then
      if old.expires_at<=v_now or not exists(select 1 from private.bank_transactions t
        join public.payments p on p.id=t.matched_payment_id
        where t.matched_intent_id=old.id and t.matched_payment_id=old.payment_id
          and t.status='verified' and p.method='bank_transfer' and p.status='awaiting_payment') then
        raise exception 'BANK_INTENT_TRANSITION_NOT_ENABLED' using errcode='23514';
      end if;
    elsif old.status not in ('created','ready') or new.status not in ('expired','cancelled','failed')
       or (new.status='expired' and old.expires_at>v_now) then
      raise exception 'BANK_INTENT_TRANSITION_NOT_ENABLED' using errcode='23514';
    end if;
    new.updated_at:=v_now;
    return new;
  end if;
  if new.reference is not null then
    raise exception 'BANK_REFERENCE_SERVER_ASSIGNED' using errcode='23514';
  end if;
  if new.status is distinct from 'created' or new.version is distinct from 1::bigint
     or new.provider is not null or new.provider_scope is not null or new.provider_intent_id is not null then
    raise exception 'BANK_INTENT_INITIAL_STATE_REQUIRED' using errcode='23514';
  end if;
  -- Same parent-before-payment order as CASH; no profile/quote lock acquired later.
  select p.* into v_payment from public.payments p where p.id=new.payment_id;
  if not found then raise exception 'BANK_PAYMENT_NOT_ELIGIBLE' using errcode='23514'; end if;
  select r.* into v_request from public.rescue_requests r where r.id=v_payment.request_id for share;
  select a.* into v_assignment from public.rescue_request_assignments a where a.id=v_payment.assignment_id for share;
  select p.* into v_payment from public.payments p where p.id=new.payment_id for update;
  if v_payment.status is distinct from 'pending' or v_payment.method is not null
     or v_payment.amount_expected<=0 or v_payment.currency<>'VND'
     or v_request.status is distinct from 'completed' or v_assignment.state is distinct from 'completed'
     or v_request.customer_id is distinct from v_payment.customer_id
     or v_assignment.request_id is distinct from v_payment.request_id
     or v_assignment.rescuer_id is distinct from v_payment.rescuer_id
     or v_request.provider_id is distinct from v_payment.rescuer_id
     or v_assignment.completion_quote_id is distinct from v_payment.quote_id then
    raise exception 'BANK_PAYMENT_NOT_ELIGIBLE' using errcode='23514';
  end if;
  if (new.request_id is not null and new.request_id is distinct from v_payment.request_id)
     or (new.expected_amount is not null and new.expected_amount is distinct from v_payment.amount_expected)
     or (new.currency is not null and new.currency is distinct from v_payment.currency) then
    raise exception 'BANK_INTENT_SNAPSHOT_MISMATCH' using errcode='23514';
  end if;
  if new.expires_at is null or not pg_catalog.isfinite(new.expires_at) or new.expires_at<=v_now then
    raise exception 'BANK_INTENT_EXPIRY_INVALID' using errcode='23514';
  end if;
  new.request_id:=v_payment.request_id;
  new.expected_amount:=v_payment.amount_expected;
  new.currency:=v_payment.currency;
  new.reference:='BK-'||pg_catalog.upper(pg_catalog.replace(pg_catalog.gen_random_uuid()::text,'-',''));
  new.created_at:=v_now;
  new.updated_at:=v_now;
  return new;
end;
$$;
create or replace function private.payment_event_core_guard() returns trigger
language plpgsql security invoker set search_path='' as $$
declare v_payment public.payments;
begin
  if tg_op in ('UPDATE','DELETE','TRUNCATE') then
    raise exception 'PAYMENT_EVENT_IMMUTABLE' using errcode='23514';
  end if;
  select p.* into v_payment from public.payments p where p.id=new.payment_id for update;
  if found and new.payment_version is distinct from v_payment.version then
    raise exception 'PAYMENT_EVENT_VERSION_MISMATCH' using errcode='23514';
  end if;
  if new.actor_type in ('customer','rescuer','admin') then
    if auth.uid() is null or new.actor_id is distinct from auth.uid() then
      raise exception 'PAYMENT_EVENT_ACTOR_MISMATCH' using errcode='23514';
    end if;
    new.actor_id:=auth.uid();
  end if;
  if new.event_type='bank_payment_verified' then
    if v_payment.method is distinct from 'bank_transfer' or v_payment.status is distinct from 'paid'
       or new.actor_type is distinct from 'system' or new.actor_id is not null
       or new.request_id is distinct from v_payment.request_id
       or new.old_status is distinct from 'awaiting_payment' or new.new_status is distinct from 'paid'
       or new.amount is distinct from v_payment.amount_received or new.metadata<>'{}'::jsonb
       or new.operation_id is null or v_payment.verified_at is null
       or v_payment.paid_at is distinct from v_payment.verified_at
       or not exists(select 1 from private.bank_transactions t where t.id=new.operation_id
         and t.status='verified' and t.matched_payment_id=v_payment.id) then
      raise exception 'PAYMENT_BANK_EVENT_INVALID' using errcode='23514';
    end if;
    new.created_at:=v_payment.paid_at;
  elsif new.event_type='cash_received' then
    if v_payment.id is null or v_payment.method is distinct from 'cash'
       or v_payment.status is distinct from 'paid' or auth.uid() is null
       or new.actor_type is distinct from 'rescuer' or new.actor_id is distinct from v_payment.rescuer_id
       or v_payment.cash_received_by is distinct from auth.uid()
       or new.request_id is distinct from v_payment.request_id
       or new.old_status is distinct from 'awaiting_payment' or new.new_status is distinct from 'paid'
       or new.amount is distinct from v_payment.amount_expected
       or v_payment.amount_received is distinct from v_payment.amount_expected
       or v_payment.cash_received_at is null or v_payment.paid_at is distinct from v_payment.cash_received_at
       or v_payment.verified_at is not null or new.operation_id is null or new.metadata<>'{}'::jsonb then
      raise exception 'PAYMENT_CASH_EVENT_INVALID' using errcode='23514';
    end if;
    new.created_at:=v_payment.cash_received_at;
  else
    new.created_at:=pg_catalog.clock_timestamp();
  end if;
  return new;
end;
$$;
-- Input is a trusted adapter result, NOT a public request body. This function
-- does not perform cryptography and never trusts a customer-supplied boolean.
create function private.process_verified_bank_transaction(p_transaction jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  n jsonb:=p_transaction;
  c private.payment_bank_config;
  r private.payment_webhook_receipts;
  t private.bank_transactions;
  i private.payment_bank_intents;
  s private.payment_bank_qr_snapshots;
  p public.payments;
  v_hash text; v_delivery text; v_amount bigint; v_time timestamptz;
  v_reason text; v_sequence bigint; v_existing integer;
begin
  if n is null or pg_catalog.jsonb_typeof(n)<>'object' or pg_catalog.octet_length(n::text)>8192
     or exists(select 1 from pg_catalog.jsonb_object_keys(n) k where k<>all(array[
       'provider','provider_scope','provider_transaction_id','provider_event_id','delivery_id','amount','currency',
       'direction','transfer_reference','occurred_at','beneficiary_bank_bin','beneficiary_account_number',
       'authentication_verified','signature_verified','authentication_method','raw_payload_sha256']))
     or not n ?& array['provider','provider_scope','provider_transaction_id','amount','currency','direction',
       'occurred_at','authentication_verified','signature_verified','authentication_method','raw_payload_sha256']
     or exists(select 1 from pg_catalog.jsonb_each(n) e where e.key not in ('authentication_verified','signature_verified')
       and pg_catalog.jsonb_typeof(e.value) not in ('string','null'))
     or n->'authentication_verified' is distinct from 'true'::jsonb
     or n->'signature_verified' not in ('true'::jsonb,'false'::jsonb)
     or n->>'authentication_method' is null or n->>'authentication_method' not in ('signature','token','mtls')
     or (n->>'authentication_method'='signature' and n->'signature_verified'<>'true'::jsonb)
     or coalesce(n->>'provider','') !~ '^[a-z][a-z0-9_]{0,63}$'
     or coalesce(length(n->>'provider_scope'),0) not between 1 and 128
     or coalesce(length(n->>'provider_transaction_id'),0) not between 1 and 256
     or coalesce(n->>'amount','') !~ '^[1-9][0-9]{0,18}$'
     or coalesce(n->>'currency','') !~ '^[A-Z]{3}$'
     or coalesce(n->>'direction','') not in ('credit','debit')
     or coalesce(n->>'raw_payload_sha256','') !~ '^[0-9a-f]{64}$'
     or coalesce(n->>'occurred_at','') !~ '^\d{4}-\d{2}-\d{2}T([01]\d|2[0-3]):[0-5]\d:[0-5]\d(\.\d{1,6})?(Z|[+-](0\d|1[0-3]):[0-5]\d|[+-]14:00)$'
     or (n->>'provider_event_id' is not null and length(n->>'provider_event_id') not between 1 and 200)
     or (n->>'delivery_id' is not null and length(n->>'delivery_id') not between 1 and 200)
     or (n->>'transfer_reference' is not null and length(n->>'transfer_reference') not between 1 and 128)
     or (n->>'beneficiary_bank_bin' is not null and length(n->>'beneficiary_bank_bin') not between 1 and 64)
     or (n->>'beneficiary_account_number' is not null and length(n->>'beneficiary_account_number') not between 1 and 128)
  then raise exception 'BANK_NORMALIZED_INPUT_INVALID' using errcode='22023'; end if;
  begin
    v_amount:=(n->>'amount')::bigint;
    v_time:=(n->>'occurred_at')::timestamptz;
  exception when others then
    raise exception 'BANK_NORMALIZED_INPUT_INVALID' using errcode='22023';
  end;
  -- Provider/account serialization also covers different event IDs for the same
  -- transaction. Conservative V1 throughput; no HTTP/network while locks held.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'bank-ingest:'||pg_catalog.jsonb_build_array(n->>'provider',n->>'provider_scope')::text,0));
  select * into c from private.payment_bank_config where singleton;
  if not found or not c.verification_enabled
     or c.verification_provider is distinct from n->>'provider'
     or c.verification_scope is distinct from n->>'provider_scope' then
    raise exception 'BANK_VERIFICATION_DISABLED' using errcode='55000';
  end if;
  -- Receipt fallback policy: namespace-prefixed SHA256 of exact raw bytes, only
  -- when both identities are absent. Transaction identity is always mandatory.
  v_delivery:=case when n->>'delivery_id' is not null then 'delivery:'||(n->>'delivery_id')
    when n->>'provider_event_id' is not null then 'event:'||(n->>'provider_event_id')
    else 'body:'||(n->>'raw_payload_sha256') end;
  -- Digest semantic fields with fixed keys; optional omitted/null is equivalent.
  -- New deliveries may have different envelope bytes, never different facts.
  v_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.jsonb_build_array(
    n->>'provider',n->>'provider_scope',n->>'provider_transaction_id',v_amount::text,n->>'currency',
    n->>'direction',n->>'transfer_reference',pg_catalog.to_char(v_time at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US'),
    n->>'beneficiary_bank_bin',n->>'beneficiary_account_number')::text,'UTF8')),'hex');
  select count(*) into v_existing from private.payment_webhook_receipts w
    where w.provider=n->>'provider' and w.provider_scope=n->>'provider_scope'
      and (w.delivery_id=v_delivery or (n->>'provider_event_id' is not null and w.event_id=n->>'provider_event_id'));
  select * into r from private.payment_webhook_receipts w
    where w.provider=n->>'provider' and w.provider_scope=n->>'provider_scope'
      and (w.delivery_id=v_delivery or (n->>'provider_event_id' is not null and w.event_id=n->>'provider_event_id'))
    order by w.id limit 1 for update;
  if found then
    v_reason:=case when v_existing<>1 or r.body_sha256<>n->>'raw_payload_sha256'
      or r.normalized_sha256 is distinct from v_hash or r.event_id is distinct from n->>'provider_event_id'
      or not r.authentication_verified then 'identity_conflict'
      when r.status in ('received','failed') then 'receipt_incomplete' else 'duplicate_event' end;
    insert into private.payment_bank_audit(receipt_id,action,new_status,resource_version,reason_code)
      values(r.id,case when v_reason='duplicate_event' then 'duplicate' else 'conflict' end,r.status,r.version,v_reason);
    return pg_catalog.jsonb_build_object('result',v_reason,'changed',false);
  end if;
  insert into private.payment_webhook_receipts(provider,provider_scope,delivery_id,event_id,body_sha256,
    signature_verified,authentication_verified,authentication_method,normalized_sha256)
  values(n->>'provider',n->>'provider_scope',v_delivery,n->>'provider_event_id',n->>'raw_payload_sha256',
    (n->>'signature_verified')::boolean,true,n->>'authentication_method',v_hash) returning * into r;
  insert into private.payment_bank_audit(receipt_id,action,new_status,resource_version)
    values(r.id,'webhook_received',r.status,r.version),(r.id,'auth_verified',r.status,r.version);
  select * into t from private.bank_transactions b where b.provider=n->>'provider'
    and b.provider_scope=n->>'provider_scope' and b.external_transaction_id=n->>'provider_transaction_id' for update;
  if found then
    v_reason:=case when t.normalized_sha256 is distinct from v_hash then 'transaction_conflict' else 'duplicate_transaction' end;
    update private.payment_webhook_receipts set status=case when v_reason='transaction_conflict' then 'rejected' else 'processed' end,
      result_code=v_reason,version=version+1 where id=r.id returning * into r;
    insert into private.payment_bank_audit(receipt_id,action,new_status,resource_version,reason_code)
      values(r.id,case when v_reason='transaction_conflict' then 'conflict' else 'duplicate' end,r.status,r.version,v_reason);
    return pg_catalog.jsonb_build_object('result',v_reason,'changed',false);
  end if;
  insert into private.bank_transactions(provider,provider_scope,external_transaction_id,receipt_id,amount,currency,direction,
    transfer_reference,occurred_at,beneficiary_bank_bin,beneficiary_account_number,normalized_sha256)
  values(n->>'provider',n->>'provider_scope',n->>'provider_transaction_id',r.id,v_amount,n->>'currency',n->>'direction',
    n->>'transfer_reference',v_time,n->>'beneficiary_bank_bin',n->>'beneficiary_account_number',v_hash) returning * into t;
  insert into private.payment_bank_audit(transaction_id,action,new_status,resource_version)
    values(t.id,'transaction_normalized',t.status,t.version);

  -- bank_sequence_v1 is byte-exact ASCII BK + 19 digits. No trim, case folding,
  -- prefix/suffix extraction or fuzzy parsing, including in the adapter contract.
  select * into s from private.payment_bank_qr_snapshots q where q.transfer_content=t.transfer_reference;
  if not found then
    v_reason:='reference_unmatched';
  else
    select * into i from private.payment_bank_intents b where b.id=s.intent_id;
    -- Same parent -> assignment -> payment -> config -> intent order as GD6B.
    perform 1 from public.rescue_requests b where b.id=i.request_id for update;
    perform 1 from public.rescue_request_assignments b where b.request_id=i.request_id for share;
    select * into p from public.payments b where b.id=i.payment_id for update;
    select * into c from private.payment_bank_config where singleton for share;
    select * into i from private.payment_bank_intents b where b.id=s.intent_id for update;
    v_reason:=case
      when not c.verification_enabled or c.verification_provider is distinct from t.provider
        or c.verification_scope is distinct from t.provider_scope then 'verification_disabled'
      when p.id is null or p.request_id is distinct from i.request_id
        or (i.provider is not null and (i.provider<>t.provider or i.provider_scope<>t.provider_scope)) then 'binding_mismatch'
      when not exists(select 1 from public.rescue_requests b join public.rescue_request_assignments a
        on a.id=p.assignment_id and a.request_id=b.id where b.id=p.request_id and b.status='completed'
        and a.state='completed' and b.customer_id=p.customer_id and b.provider_id=p.rescuer_id
        and a.rescuer_id=p.rescuer_id and a.completion_quote_id=p.quote_id) then 'payment_ineligible'
      when p.method is distinct from 'bank_transfer' then 'method_mismatch'
      when p.status='paid' then 'already_paid'
      when p.status is distinct from 'awaiting_payment' then 'payment_ineligible'
      when i.status is distinct from 'ready' then 'intent_ineligible'
      when i.expires_at<=pg_catalog.clock_timestamp() then 'intent_expired'
      when t.direction<>'credit' then 'not_credit'
      when t.amount<>i.expected_amount or t.amount<>p.amount_expected then 'amount_mismatch'
      when t.currency<>i.currency or t.currency<>p.currency then 'currency_mismatch'
      when c.reference_policy<>'bank_sequence_v1' or t.transfer_reference !~ '^BK[0-9]{19}$' then 'reference_unmatched'
      when c.bank_bin<>s.bank_bin or c.account_number<>s.account_number then 'config_mismatch'
      when (c.require_beneficiary and (t.beneficiary_bank_bin is null or t.beneficiary_account_number is null))
        or (t.beneficiary_bank_bin is not null and t.beneficiary_bank_bin<>s.bank_bin)
        or (t.beneficiary_account_number is not null and t.beneficiary_account_number<>s.account_number) then 'beneficiary_mismatch'
      when t.occurred_at<i.created_at or t.occurred_at>=i.expires_at
        or t.occurred_at>pg_catalog.clock_timestamp() then 'transaction_time_invalid'
      when p.version=9223372036854775807 or i.version=9223372036854775807 then 'version_exhausted'
      when exists(select 1 from private.bank_transactions b where b.matched_payment_id=p.id and b.status='verified') then 'already_allocated'
      else null end;
  end if;
  if v_reason is not null then
    update private.bank_transactions set status='rejected',rejection_code=v_reason,version=version+1 where id=t.id returning * into t;
    update private.payment_webhook_receipts set status='processed',result_code=v_reason,version=version+1 where id=r.id;
    insert into private.payment_bank_audit(transaction_id,action,new_status,resource_version,reason_code)
      values(t.id,'match_rejected',t.status,t.version,v_reason);
    return pg_catalog.jsonb_build_object('result',v_reason,'changed',false);
  end if;
  update private.bank_transactions set status='verified',matched_intent_id=i.id,matched_payment_id=p.id,version=version+1
    where id=t.id returning * into t;
  update private.payment_bank_intents set status='verified',version=version+1 where id=i.id;
  update public.payments set status='paid',amount_received=t.amount,version=version+1
    where id=p.id and version=p.version and status='awaiting_payment' returning * into p;
  if not found then raise exception 'BANK_PAYMENT_STATE_CONFLICT' using errcode='40001'; end if;
  select coalesce(max(e.event_sequence),0)+1 into v_sequence from public.payment_events e where e.payment_id=p.id;
  insert into public.payment_events(payment_id,request_id,event_type,actor_type,old_status,new_status,
    amount,operation_id,payment_version,event_sequence)
    values(p.id,p.request_id,'bank_payment_verified','system','awaiting_payment','paid',t.amount,t.id,p.version,v_sequence);
  update private.payment_webhook_receipts set status='processed',result_code='paid',version=version+1 where id=r.id;
  insert into private.payment_bank_audit(transaction_id,action,new_status,resource_version)
    values(t.id,'match_succeeded',t.status,t.version),(t.id,'payment_transitioned',t.status,t.version);
  return pg_catalog.jsonb_build_object('result','paid','changed',true);
end;
$$;

revoke all on function private.process_verified_bank_transaction(jsonb),
  private.record_bank_auth_failure(text,text,text),private.payment_bank_record_guard(),
  private.payment_bank_audit_guard(),private.payment_bank_intent_guard(),private.payment_core_guard(),
  private.payment_event_core_guard() from public,anon,authenticated;
revoke all on table private.payment_bank_config,private.payment_bank_intents,private.payment_bank_qr_snapshots,
  private.bank_transactions,private.payment_webhook_receipts,private.payment_bank_audit from public,anon,authenticated;
do $acl$
begin
  if exists(select 1 from pg_catalog.pg_roles where rolname='service_role') then
    revoke all on function private.process_verified_bank_transaction(jsonb),
      private.record_bank_auth_failure(text,text,text),private.payment_bank_record_guard(),
      private.payment_bank_audit_guard(),private.payment_bank_intent_guard(),private.payment_core_guard(),
      private.payment_event_core_guard() from service_role;
    revoke all on table private.payment_bank_config,private.payment_bank_intents,private.payment_bank_qr_snapshots,
      private.bank_transactions,private.payment_webhook_receipts,private.payment_bank_audit from service_role;
  end if;
end;
$acl$;
comment on function private.process_verified_bank_transaction(jsonb) is
  'GD6C owner-only trusted normalized input; not cryptographic authentication. No API grant. Disabled until real provider integration is reviewed.';
comment on table private.bank_transactions is
  'Immutable private observations and terminal match outcomes. Exact-amount/reference verified allocation only; never publish.';
comment on table private.payment_webhook_receipts is
  'Authenticated canonical inbox; raw bytes SHA256 only. Authentication is adapter evidence, not verified by SQL. Never publish.';
commit;
