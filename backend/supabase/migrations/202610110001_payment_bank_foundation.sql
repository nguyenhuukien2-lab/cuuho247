-- GD6A: private, provider-agnostic storage only. No public bank RPC or paid writer.
-- Apply AFTER GD1/GD2A/GD2B/GD3/GD4. No provider configuration or seed data.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if to_regprocedure('public.rescuer_confirm_cash_received(uuid,uuid,bigint,bigint,uuid)') is null
     or to_regprocedure('public.customer_select_payment_method(uuid,uuid,text,bigint,uuid)') is null
     or not exists(select 1 from pg_catalog.pg_publication_tables
       where pubname='supabase_realtime' and schemaname='public' and tablename='payments') then
    raise exception 'BANK_FOUNDATION_MISSING_PREREQUISITES';
  end if;
  if to_regclass('private.payment_bank_intents') is not null
     or to_regclass('private.bank_transactions') is not null
     or to_regclass('private.payment_webhook_receipts') is not null
     or to_regclass('private.payment_bank_audit') is not null
     or exists(select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
       where n.nspname='private' and p.proname in ('payment_bank_intent_guard',
       'payment_bank_create_intent','payment_bank_record_guard','payment_bank_audit_guard','payment_bank_append_audit')) then
    raise exception 'BANK_FOUNDATION_ALREADY_EXISTS';
  end if;
  if (select count(*) from pg_catalog.pg_class where oid in
       ('public.payments'::regclass,'public.payment_events'::regclass) and relrowsecurity)<>2
     or pg_catalog.has_table_privilege('authenticated','public.payments','INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
     or pg_catalog.has_table_privilege('anon','public.payments','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
     or pg_catalog.has_table_privilege('authenticated','public.payment_events','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
     or exists(select 1 from pg_catalog.pg_policy where polrelid='public.payment_events'::regclass)
     or (select count(*) from pg_catalog.pg_policy where polrelid='public.payments'::regclass)<>2
     or not exists(select 1 from pg_catalog.pg_trigger where tgrelid='public.payments'::regclass
       and tgname='payment_core_guard' and tgenabled='O') then
    raise exception 'BANK_FOUNDATION_SECURITY_DRIFT';
  end if;
  -- Reject broad/schema publications even when private has no tables yet.
  -- Check every publication, not just the one used by Supabase Realtime.
  if exists(select 1 from pg_catalog.pg_publication where puballtables)
     or exists(select 1 from pg_catalog.pg_publication_namespace
       where pnnspid='private'::regnamespace)
     or exists(select 1 from pg_catalog.pg_publication_tables
       where schemaname='private' or (schemaname='public' and tablename='payment_events')) then
    raise exception 'BANK_FOUNDATION_PUBLICATION_UNSAFE';
  end if;
end;
$preflight$;

create table private.payment_bank_intents (
  id uuid primary key default gen_random_uuid(),
  operation_id uuid not null unique,
  payment_id uuid not null,
  request_id uuid not null,
  reference text not null unique check(reference ~ '^BK-[0-9A-F]{32}$'),
  expected_amount bigint not null check(expected_amount>0),
  currency text not null check(currency='VND'),
  provider text check(provider ~ '^[a-z][a-z0-9_]{0,63}$'),
  provider_scope text check(length(provider_scope) between 1 and 128),
  provider_intent_id text check(length(provider_intent_id) between 1 and 256),
  status text not null default 'created'
    check(status in ('created','ready','expired','cancelled','matched','verified','failed')),
  expires_at timestamptz not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  version bigint not null default 1 check(version>0),
  constraint bank_intent_payment_request_fk foreign key(payment_id,request_id)
    references public.payments(id,request_id) on delete restrict,
  constraint bank_intent_id_payment_key unique(id,payment_id),
  constraint bank_intent_provider_identity_key unique(provider,provider_scope,provider_intent_id),
  constraint bank_intent_provider_pair check((provider is null and provider_scope is null and provider_intent_id is null)
    or (provider is not null and provider_scope is not null)),
  constraint bank_intent_times check(isfinite(created_at) and isfinite(updated_at)
    and isfinite(expires_at) and expires_at>created_at and updated_at>=created_at)
);
-- An elapsed TTL does not release this slot implicitly. Close/audit it first.
-- A verified intent reserves the slot permanently: never collect a second time.
create unique index bank_intent_one_active_payment on private.payment_bank_intents(payment_id)
  where status in ('created','ready','matched','verified');

create table private.payment_webhook_receipts (
  id uuid primary key default gen_random_uuid(),
  provider text not null check(provider ~ '^[a-z][a-z0-9_]{0,63}$'),
  provider_scope text not null check(length(provider_scope) between 1 and 128),
  delivery_id text not null check(length(delivery_id) between 1 and 256),
  event_id text check(length(event_id) between 1 and 256),
  body_sha256 text not null check(body_sha256 ~ '^[0-9a-f]{64}$'),
  signature_verified boolean not null default false,
  status text not null default 'received' check(status in ('received','processed','rejected','failed')),
  received_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  version bigint not null default 1 check(version>0),
  constraint bank_receipt_delivery_key unique(provider,provider_scope,delivery_id),
  constraint bank_receipt_event_key unique(provider,provider_scope,event_id),
  constraint bank_receipt_source_key unique(id,provider,provider_scope),
  constraint bank_receipt_times check(isfinite(received_at) and isfinite(updated_at) and updated_at>=received_at)
);

create table private.bank_transactions (
  id uuid primary key default gen_random_uuid(),
  provider text not null check(provider ~ '^[a-z][a-z0-9_]{0,63}$'),
  provider_scope text not null check(length(provider_scope) between 1 and 128),
  external_transaction_id text not null check(length(external_transaction_id) between 1 and 256),
  receipt_id uuid,
  amount bigint not null check(amount>0),
  currency text not null check(currency ~ '^[A-Z]{3}$'),
  direction text not null check(direction in ('credit','debit')),
  transfer_reference text check(length(transfer_reference) between 1 and 128),
  occurred_at timestamptz check(occurred_at is null or isfinite(occurred_at)),
  matched_payment_id uuid,
  matched_intent_id uuid,
  status text not null default 'unverified' check(status in ('unverified','matched','verified','rejected')),
  received_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  version bigint not null default 1 check(version>0),
  constraint bank_transaction_identity_key unique(provider,provider_scope,external_transaction_id),
  constraint bank_transaction_receipt_fk foreign key(receipt_id,provider,provider_scope)
    references private.payment_webhook_receipts(id,provider,provider_scope) on delete restrict,
  constraint bank_transaction_intent_fk foreign key(matched_intent_id,matched_payment_id)
    references private.payment_bank_intents(id,payment_id) on delete restrict,
  constraint bank_transaction_match_pair check(
    (matched_intent_id is null and matched_payment_id is null and status in ('unverified','rejected'))
    or (matched_intent_id is not null and matched_payment_id is not null and status in ('matched','verified'))),
  constraint bank_transaction_times check(isfinite(received_at) and isfinite(updated_at) and updated_at>=received_at)
);
create unique index bank_transaction_one_verified_payment on private.bank_transactions(matched_payment_id)
  where status='verified';

-- Safe internal lifecycle audit only: no arbitrary JSON, body, header or error text.
create table private.payment_bank_audit (
  id uuid primary key default gen_random_uuid(),
  intent_id uuid references private.payment_bank_intents(id) on delete restrict,
  transaction_id uuid references private.bank_transactions(id) on delete restrict,
  receipt_id uuid references private.payment_webhook_receipts(id) on delete restrict,
  old_status text,
  new_status text not null,
  resource_version bigint not null check(resource_version>0),
  actor_db_role name not null default current_user,
  recorded_at timestamptz not null default clock_timestamp() check(isfinite(recorded_at)),
  constraint bank_audit_one_resource check(num_nonnulls(intent_id,transaction_id,receipt_id)=1),
  unique(intent_id,resource_version),
  unique(transaction_id,resource_version),
  unique(receipt_id,resource_version)
);

alter table private.payment_bank_intents enable row level security;
alter table private.payment_webhook_receipts enable row level security;
alter table private.bank_transactions enable row level security;
alter table private.payment_bank_audit enable row level security;
revoke all on table private.payment_bank_intents,private.payment_webhook_receipts,
  private.bank_transactions,private.payment_bank_audit from public,anon,authenticated;

create function private.payment_bank_intent_guard() returns trigger
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
    -- Readiness, provider attachment, matching and verification are NOT enabled.
    if old.status<>'created' or new.status not in ('expired','cancelled','failed')
       or new.version::numeric<>old.version::numeric+1
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

-- Owner-only internal primitive, NOT a public/customer RPC and NOT bank readiness.
-- Caller supplies an operation UUID and a server policy expiry; no amount input.
create function private.payment_bank_create_intent(p_payment_id uuid,p_operation_id uuid,p_expires_at timestamptz)
returns uuid language plpgsql security invoker set search_path='' as $$
declare v_existing private.payment_bank_intents; v_request uuid; v_id uuid;
begin
  if p_operation_id is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode='22023'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('bank-intent-operation:'||p_operation_id::text,0));
  select i.* into v_existing from private.payment_bank_intents i where i.operation_id=p_operation_id;
  if found then
    if v_existing.payment_id is distinct from p_payment_id or v_existing.expires_at is distinct from p_expires_at then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode='22023';
    end if;
    return v_existing.id; -- Historical replay, including terminal/expired intents.
  end if;
  select p.request_id into v_request from public.payments p where p.id=p_payment_id;
  if not found then raise exception 'BANK_PAYMENT_NOT_ELIGIBLE' using errcode='23514'; end if;
  perform 1 from public.rescue_requests r where r.id=v_request for update;
  perform 1 from private.payment_bank_intents i where i.payment_id=p_payment_id
    and i.status in ('created','ready','matched','verified');
  if found then raise exception 'BANK_INTENT_ALREADY_ACTIVE' using errcode='P0001'; end if;
  insert into private.payment_bank_intents(payment_id,operation_id,expires_at)
    values(p_payment_id,p_operation_id,p_expires_at) returning id into v_id;
  return v_id;
end;
$$;

create function private.payment_bank_record_guard() returns trigger
language plpgsql security invoker set search_path='' as $$
declare v_now timestamptz:=pg_catalog.clock_timestamp();
begin
  if tg_op in ('DELETE','TRUNCATE') then
    raise exception 'BANK_RECORD_DELETE_FORBIDDEN' using errcode='23514';
  end if;
  if tg_op='UPDATE' then
    if (pg_catalog.to_jsonb(new)-array['status','version','updated_at']) is distinct from
       (pg_catalog.to_jsonb(old)-array['status','version','updated_at']) then
      raise exception 'BANK_RECORD_IMMUTABLE' using errcode='23514';
    end if;
    if new.status=old.status then
      if new.version<>old.version then raise exception 'BANK_VERSION_INVALID' using errcode='23514'; end if;
      return old;
    end if;
    if new.version::numeric<>old.version::numeric+1 then
      raise exception 'BANK_VERSION_INVALID' using errcode='23514';
    end if;
    if tg_table_name='bank_transactions' then
      if old.status<>'unverified' or new.status<>'rejected' then
        raise exception 'BANK_VERIFICATION_NOT_ENABLED' using errcode='23514';
      end if;
    elsif not ((old.status='received' and new.status in ('failed','rejected'))
          or (old.status='failed' and new.status='received')) then
      raise exception 'BANK_PROCESSING_NOT_ENABLED' using errcode='23514';
    end if;
    new.updated_at:=v_now;
    return new;
  end if;
  if new.version is distinct from 1::bigint then
    raise exception 'BANK_VERSION_INVALID' using errcode='23514';
  end if;
  if tg_table_name='bank_transactions' then
    if new.status is distinct from 'unverified' or new.matched_payment_id is not null or new.matched_intent_id is not null then
      raise exception 'BANK_VERIFICATION_NOT_ENABLED' using errcode='23514';
    end if;
    if new.receipt_id is not null and not exists(select 1 from private.payment_webhook_receipts r
      where r.id=new.receipt_id and r.provider=new.provider and r.provider_scope=new.provider_scope
        and r.signature_verified and r.status='received') then
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

create function private.payment_bank_audit_guard() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if tg_op<>'INSERT' then raise exception 'BANK_AUDIT_IMMUTABLE' using errcode='23514'; end if;
  if pg_catalog.pg_trigger_depth()<2 then
    raise exception 'BANK_AUDIT_TRIGGER_ONLY' using errcode='23514';
  end if;
  new.actor_db_role:=current_user;
  new.recorded_at:=pg_catalog.clock_timestamp();
  return new;
end;
$$;

create function private.payment_bank_append_audit() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if tg_op='UPDATE' and new.version=old.version then return null; end if;
  insert into private.payment_bank_audit(intent_id,transaction_id,receipt_id,old_status,new_status,resource_version)
  values(case when tg_table_name='payment_bank_intents' then new.id end,
    case when tg_table_name='bank_transactions' then new.id end,
    case when tg_table_name='payment_webhook_receipts' then new.id end,
    case when tg_op='UPDATE' then old.status end,new.status,new.version);
  return null;
end;
$$;

create trigger bank_intent_guard before insert or update or delete on private.payment_bank_intents
  for each row execute function private.payment_bank_intent_guard();
create trigger bank_intent_no_truncate before truncate on private.payment_bank_intents
  for each statement execute function private.payment_bank_intent_guard();
create trigger bank_transaction_guard before insert or update or delete on private.bank_transactions
  for each row execute function private.payment_bank_record_guard();
create trigger bank_transaction_no_truncate before truncate on private.bank_transactions
  for each statement execute function private.payment_bank_record_guard();
create trigger bank_receipt_guard before insert or update or delete on private.payment_webhook_receipts
  for each row execute function private.payment_bank_record_guard();
create trigger bank_receipt_no_truncate before truncate on private.payment_webhook_receipts
  for each statement execute function private.payment_bank_record_guard();
create trigger bank_audit_guard before insert or update or delete on private.payment_bank_audit
  for each row execute function private.payment_bank_audit_guard();
create trigger bank_audit_no_truncate before truncate on private.payment_bank_audit
  for each statement execute function private.payment_bank_audit_guard();
create trigger bank_intent_audit after insert or update on private.payment_bank_intents
  for each row execute function private.payment_bank_append_audit();
create trigger bank_transaction_audit after insert or update on private.bank_transactions
  for each row execute function private.payment_bank_append_audit();
create trigger bank_receipt_audit after insert or update on private.payment_webhook_receipts
  for each row execute function private.payment_bank_append_audit();

revoke all on function private.payment_bank_intent_guard(),
  private.payment_bank_create_intent(uuid,uuid,timestamptz),private.payment_bank_record_guard(),
  private.payment_bank_audit_guard(),private.payment_bank_append_audit() from public,anon,authenticated;
do $acl$
begin
  if exists(select 1 from pg_catalog.pg_roles where rolname='service_role') then
    revoke all on table private.payment_bank_intents,private.payment_webhook_receipts,
      private.bank_transactions,private.payment_bank_audit from service_role;
    revoke all on function private.payment_bank_intent_guard(),
      private.payment_bank_create_intent(uuid,uuid,timestamptz),private.payment_bank_record_guard(),
      private.payment_bank_audit_guard(),private.payment_bank_append_audit() from service_role;
  end if;
end;
$acl$;

comment on table private.payment_bank_intents is
  'GD6A internal reservations only; created is NOT ready. Immutable server reference/amount snapshot; no provider or beneficiary configured.';
comment on table private.bank_transactions is
  'Private immutable normalized observations; receipt optional for future polling sources. Matching/verification disabled. No public payment mutation.';
comment on table private.payment_webhook_receipts is
  'Future private inbox; exact-body SHA256 only, no raw body/header/secret retention. Signature flag is evidence from a future trusted adapter, not SQL verification.';
comment on table private.payment_bank_audit is
  'Append-only private lifecycle/version audit populated atomically by triggers; not published and not public.payment_events.';
comment on function private.payment_bank_create_intent(uuid,uuid,timestamptz) is
  'Owner-only SECURITY INVOKER primitive; same operation/payment/expiry returns same intent. No API grant, readiness, QR, method selection or settlement.';
commit;
