-- Customer-owned regeneration of an expired bank QR intent.
-- Additive after GD6C. Never extends/reopens an old intent and never settles a payment.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';

do $preflight$
begin
  if to_regprocedure('private.process_verified_bank_transaction(jsonb)') is null
     or to_regprocedure('public.customer_select_bank_transfer(uuid,uuid,bigint,uuid)') is null
     or to_regclass('private.payment_bank_qr_snapshots') is null then
    raise exception 'BANK_REGENERATION_MISSING_PREREQUISITES';
  end if;
  if to_regprocedure('public.customer_regenerate_bank_transfer(uuid,uuid,bigint,uuid,bigint,uuid)') is not null then
    raise exception 'BANK_REGENERATION_ALREADY_EXISTS';
  end if;
  if exists(select 1 from pg_catalog.pg_publication where puballtables)
     or exists(select 1 from pg_catalog.pg_publication_namespace where pnnspid='private'::regnamespace)
     or exists(select 1 from pg_catalog.pg_publication_tables where schemaname='private'
       or (schemaname='public' and tablename='payment_events'))
     or not exists(select 1 from pg_catalog.pg_publication_tables
       where pubname='supabase_realtime' and schemaname='public' and tablename='payments')
     or pg_catalog.has_table_privilege('authenticated','public.payments','INSERT,UPDATE,DELETE')
     or pg_catalog.has_table_privilege('anon','public.payments','SELECT,INSERT,UPDATE,DELETE')
     or (select count(*) from pg_catalog.pg_class where oid in ('private.payment_bank_config'::regclass,
       'private.payment_bank_intents'::regclass,'private.payment_bank_qr_snapshots'::regclass,
       'private.bank_transactions'::regclass,'private.payment_rpc_receipts'::regclass,
       'public.payments'::regclass,'public.payment_events'::regclass) and relrowsecurity)<>7 then
    raise exception 'BANK_REGENERATION_SECURITY_DRIFT';
  end if;
end;
$preflight$;

-- Reuse the immutable actor/operation receipt namespace.
alter table private.payment_rpc_receipts
  drop constraint payment_rpc_receipts_operation_name_check;
alter table private.payment_rpc_receipts
  add constraint payment_rpc_receipts_operation_name_check check(operation_name in (
    'customer_select_payment_method','customer_select_bank_transfer','customer_regenerate_bank_transfer'));

-- A snapshot may be issued either during initial selection or during the narrow
-- awaiting-bank renewal transaction. Private ACLs and the intent guard remain the
-- write boundary; no table grant is added.
create or replace function private.payment_bank_qr_snapshot_guard() returns trigger
language plpgsql security invoker set search_path='' as $$
declare c private.payment_bank_config; i private.payment_bank_intents;
begin
  if tg_op<>'INSERT' then raise exception 'BANK_QR_SNAPSHOT_IMMUTABLE' using errcode='23514'; end if;
  select * into c from private.payment_bank_config where singleton and enabled for share;
  if not found then raise exception 'BANK_UNAVAILABLE' using errcode='P0001'; end if;
  select * into i from private.payment_bank_intents where id=new.intent_id for update;
  if not found or i.status<>'created' or i.expires_at<=pg_catalog.clock_timestamp()
     or not exists(select 1 from public.payments p where p.id=i.payment_id
       and p.customer_id=auth.uid() and ((p.method is null and p.status='pending')
         or (p.method='bank_transfer' and p.status='awaiting_payment'))) then
    raise exception 'BANK_INTENT_UNAVAILABLE' using errcode='P0001';
  end if;
  new.config_version:=c.version;
  new.bank_bin:=c.bank_bin; new.bank_code:=c.bank_code; new.bank_name:=c.bank_name;
  new.account_number:=c.account_number; new.account_name:=c.account_name;
  new.transfer_content:='BK'||pg_catalog.lpad(
    pg_catalog.nextval('private.payment_bank_transfer_seq'::regclass)::text,19,'0');
  new.qr_payload:=private.payment_bank_vietqr(
    c.bank_bin,c.account_number,i.expected_amount,new.transfer_content);
  return new;
end;
$$;

-- Preserve every GD6C transition. The only additions are:
-- * created -> ready is also valid for owned bank/awaiting payment;
-- * a new created intent may be inserted for that state after the old active row
--   was explicitly closed. The partial unique index still enforces one active row.
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
      return old;
    end if;
    if new.version::numeric<>old.version::numeric+1 then
      raise exception 'BANK_VERSION_INVALID' using errcode='23514';
    end if;
    if old.status='created' and new.status='ready' then
      if old.expires_at<=v_now
         or not exists(select 1 from private.payment_bank_qr_snapshots s where s.intent_id=old.id)
         or not exists(select 1 from public.payments p where p.id=old.payment_id
           and p.customer_id=auth.uid() and ((p.status='pending' and p.method is null)
             or (p.status='awaiting_payment' and p.method='bank_transfer'))) then
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
  select p.* into v_payment from public.payments p where p.id=new.payment_id;
  if not found then raise exception 'BANK_PAYMENT_NOT_ELIGIBLE' using errcode='23514'; end if;
  select r.* into v_request from public.rescue_requests r where r.id=v_payment.request_id for share;
  select a.* into v_assignment from public.rescue_request_assignments a where a.id=v_payment.assignment_id for share;
  select p.* into v_payment from public.payments p where p.id=new.payment_id for update;
  if not ((v_payment.status='pending' and v_payment.method is null)
       or (v_payment.status='awaiting_payment' and v_payment.method='bank_transfer'))
     or v_payment.amount_expected<=0 or v_payment.currency<>'VND'
     or v_request.status is distinct from 'completed' or v_assignment.state is distinct from 'completed'
     or v_request.customer_id is distinct from v_payment.customer_id
     or v_assignment.request_id is distinct from v_payment.request_id
     or v_assignment.rescuer_id is distinct from v_payment.rescuer_id
     or v_request.provider_id is distinct from v_payment.rescuer_id
     or v_assignment.completion_quote_id is distinct from v_payment.quote_id
     or auth.uid() is null or auth.uid() is distinct from v_payment.customer_id
     or exists(select 1 from private.payment_bank_intents x where x.payment_id=v_payment.id
       and x.status in ('created','ready','matched','verified')) then
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

-- Preserve GD6C settlement, initial bank selection and cash collection. A
-- renewal may only bump version while method/status remain bank/awaiting, and
-- only after a newer ready intent exists for the immutable payment snapshot.
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
      elsif old.status='awaiting_payment' and old.method='bank_transfer'
         and new.status='awaiting_payment' and new.method='bank_transfer' then
        if auth.uid() is null or auth.uid() is distinct from old.customer_id
           or new.version::numeric is distinct from old.version::numeric+1
           or (pg_catalog.to_jsonb(new)-array['version','updated_at']) is distinct from
              (pg_catalog.to_jsonb(old)-array['version','updated_at'])
           or not exists(select 1 from private.payment_bank_intents i
             join private.payment_bank_qr_snapshots s on s.intent_id=i.id
             where i.payment_id=old.id and i.request_id=old.request_id and i.status='ready'
               and i.expires_at>v_now and i.expected_amount=old.amount_expected and i.currency=old.currency
               and i.created_at>=old.updated_at)
           or not exists(select 1 from private.payment_bank_intents i
             where i.payment_id=old.id and i.status='expired' and i.updated_at>=old.updated_at)
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

-- Add the current immutable intent identifier to the existing owner-safe DTO.
create or replace function public.customer_get_bank_payment(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); p public.payments; i private.payment_bank_intents;
  s private.payment_bank_qr_snapshots; v_status text; v_enabled boolean;
begin
  if v_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if not exists(select 1 from public.rescue_requests r where r.id=p_request_id and r.customer_id=v_actor) then
    raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode='42501';
  end if;
  select * into p from public.payments where request_id=p_request_id and customer_id=v_actor;
  if not found or p.method is distinct from 'bank_transfer' then return null; end if;
  select b.* into i from private.payment_bank_intents b
    join private.payment_bank_qr_snapshots q on q.intent_id=b.id
    where b.payment_id=p.id order by b.created_at desc,b.id limit 1;
  if not found then raise exception 'BANK_INTENT_UNAVAILABLE' using errcode='P0001'; end if;
  select * into s from private.payment_bank_qr_snapshots where intent_id=i.id;
  select exists(select 1 from private.payment_bank_config c where c.singleton and c.enabled) into v_enabled;
  v_status:=case when i.status in ('created','ready') and i.expires_at<=pg_catalog.statement_timestamp()
    then 'expired' else i.status end;
  return pg_catalog.jsonb_build_object(
    'payment_id',p.id,'payment_code',p.payment_code,'request_id',p.request_id,
    'payment_status',p.status,'payment_method',p.method,'amount_expected',p.amount_expected::text,'currency',p.currency,
    'bank_intent_id',i.id,'bank_intent_status',v_status,'bank_reference',i.reference,
    'bank_code',s.bank_code,'bank_bin',s.bank_bin,'bank_name',s.bank_name,
    'account_number',s.account_number,'account_name',s.account_name,'transfer_content',s.transfer_content,
    'expires_at',i.expires_at,'server_time',pg_catalog.statement_timestamp(),
    'available',v_enabled,'qr_payload',case when v_enabled and v_status='ready' and p.status='awaiting_payment' then s.qr_payload end,
    'version',p.version::text,'bank_intent_version',i.version::text);
end;
$$;

create function public.customer_regenerate_bank_transfer(
  p_request_id uuid,
  p_payment_id uuid,
  p_expected_version bigint,
  p_expected_intent_id uuid,
  p_expected_intent_version bigint,
  p_operation_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid();
  r public.rescue_requests;
  p public.payments;
  c private.payment_bank_config;
  i private.payment_bank_intents;
  s private.payment_bank_qr_snapshots;
  n private.payment_bank_intents;
  receipt private.payment_rpc_receipts;
  v_name constant text:='customer_regenerate_bank_transfer';
  v_hash text;
  v_response jsonb;
  v_sequence bigint;
  v_now timestamptz;
  v_new_id uuid;
  v_config_version bigint;
  v_provider text;
  v_scope text;
begin
  if v_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if p_operation_id is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode='22023'; end if;
  if p_expected_version is null or p_expected_version<=0 then
    raise exception 'INVALID_EXPECTED_VERSION' using errcode='22023';
  end if;
  if p_expected_intent_id is null or p_expected_intent_version is null or p_expected_intent_version<=0 then
    raise exception 'INVALID_EXPECTED_INTENT_VERSION' using errcode='22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'payment-operation:'||v_actor::text||':'||p_operation_id::text,0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'bank-intent-operation:'||p_operation_id::text,0));

  -- Serialize with GD6C ingress before either side locks the request graph.
  select version,verification_provider,verification_scope
    into v_config_version,v_provider,v_scope
    from private.payment_bank_config where singleton;
  if v_provider is not null and v_scope is not null then
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
      'bank-ingest:'||pg_catalog.jsonb_build_array(v_provider,v_scope)::text,0));
  end if;

  -- Business lock order matches the verified processor: request -> assignment
  -- -> payment -> config -> intent.
  select * into r from public.rescue_requests
    where id=p_request_id and customer_id=v_actor for update;
  if not found then raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode='42501'; end if;
  perform 1 from public.rescue_request_assignments a where a.request_id=r.id for share;
  select * into p from public.payments
    where id=p_payment_id and request_id=p_request_id and customer_id=v_actor for update;
  if not found then raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode='42501'; end if;

  v_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(
    pg_catalog.jsonb_build_array(v_name,p_request_id,p_payment_id,p_expected_version,
      p_expected_intent_id,p_expected_intent_version)::text,'UTF8')),'hex');
  select * into receipt from private.payment_rpc_receipts
    where actor_id=v_actor and operation_id=p_operation_id;
  if found then
    if receipt.operation_name is distinct from v_name or receipt.payload_hash is distinct from v_hash
       or receipt.payment_id is distinct from p.id then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode='22023';
    end if;
    return pg_catalog.jsonb_build_object('payment',receipt.response_payment,'changed',false);
  end if;

  select * into c from private.payment_bank_config where singleton and enabled for share;
  if not found or c.version is distinct from v_config_version
     or c.verification_provider is distinct from v_provider
     or c.verification_scope is distinct from v_scope
     or p.currency<>'VND' or p.amount_expected not between 1 and 9999999999999 then
    raise exception 'BANK_UNAVAILABLE' using errcode='P0001';
  end if;
  select b.* into i from private.payment_bank_intents b
    join private.payment_bank_qr_snapshots q on q.intent_id=b.id
    where b.payment_id=p.id order by b.created_at desc,b.id limit 1 for update of b;
  if not found or i.id is distinct from p_expected_intent_id then
    raise exception 'BANK_INTENT_UNAVAILABLE' using errcode='P0001';
  end if;
  select * into s from private.payment_bank_qr_snapshots where intent_id=i.id;
  v_now:=pg_catalog.clock_timestamp();

  if p.status in ('paid','refunded') then raise exception 'PAYMENT_ALREADY_SETTLED' using errcode='P0001'; end if;
  if r.status<>'completed' or p.status<>'awaiting_payment' or p.method<>'bank_transfer' then
    raise exception 'PAYMENT_NOT_ELIGIBLE' using errcode='P0001';
  end if;
  if p.version<>p_expected_version then raise exception 'VERSION_CONFLICT' using errcode='P0001'; end if;
  if i.version<>p_expected_intent_version then
    raise exception 'BANK_INTENT_VERSION_CONFLICT' using errcode='P0001';
  end if;
  if i.status<>'ready' then raise exception 'BANK_INTENT_UNAVAILABLE' using errcode='P0001'; end if;
  if i.expires_at>v_now then raise exception 'BANK_INTENT_NOT_EXPIRED' using errcode='P0001'; end if;
  if p.version=9223372036854775807 or i.version=9223372036854775807 then
    raise exception 'PAYMENT_NOT_ELIGIBLE' using errcode='P0001';
  end if;
  if exists(select 1 from private.payment_bank_intents x where x.payment_id=p.id and x.id<>i.id
      and x.status in ('created','ready','matched','verified')) then
    raise exception 'BANK_INTENT_UNAVAILABLE' using errcode='P0001';
  end if;
  if exists(select 1 from private.bank_transactions t
      where t.direction='credit' and t.transfer_reference=s.transfer_content) then
    raise exception 'BANK_TRANSFER_RECONCILIATION_REQUIRED' using errcode='P0001';
  end if;

  begin
    update private.payment_bank_intents set status='expired',version=version+1 where id=i.id;
    v_new_id:=private.payment_bank_create_intent(p.id,p_operation_id,
      v_now+pg_catalog.make_interval(secs=>c.expiry_seconds));
    insert into private.payment_bank_qr_snapshots(intent_id) values(v_new_id);
    update private.payment_bank_intents set status='ready',version=version+1
      where id=v_new_id returning * into n;
    update public.payments set version=version+1
      where id=p.id and version=p.version and status='awaiting_payment' and method='bank_transfer'
      returning * into p;
    if not found then raise exception 'VERSION_CONFLICT' using errcode='40001'; end if;
    select coalesce(max(event_sequence),0)+1 into v_sequence
      from public.payment_events where payment_id=p.id;
    insert into public.payment_events(payment_id,request_id,event_type,actor_type,actor_id,
      old_status,new_status,amount,metadata,operation_id,payment_version,event_sequence)
    values(p.id,p.request_id,'bank_qr_created','customer',v_actor,
      'awaiting_payment','awaiting_payment',p.amount_expected,
      pg_catalog.jsonb_build_object('regenerated',true),p_operation_id,p.version,v_sequence);
    v_response:=public.customer_get_payment(p_request_id);
    insert into private.payment_rpc_receipts(
      actor_id,operation_id,operation_name,payload_hash,payment_id,response_payment)
    values(v_actor,p_operation_id,v_name,v_hash,p.id,v_response);
  exception when integrity_constraint_violation then
    raise exception 'PAYMENT_STATE_CONFLICT' using errcode='P0001';
  end;
  return pg_catalog.jsonb_build_object('payment',v_response,'changed',true);
end;
$$;

revoke all on function public.customer_regenerate_bank_transfer(uuid,uuid,bigint,uuid,bigint,uuid)
  from public,anon,authenticated;
revoke all on function private.payment_bank_qr_snapshot_guard(),private.payment_bank_intent_guard(),
  private.payment_core_guard() from public,anon,authenticated;
do $acl$
begin
  if exists(select 1 from pg_catalog.pg_roles where rolname='service_role') then
    revoke all on function public.customer_regenerate_bank_transfer(uuid,uuid,bigint,uuid,bigint,uuid),
      private.payment_bank_qr_snapshot_guard(),private.payment_bank_intent_guard(),
      private.payment_core_guard() from service_role;
  end if;
end;
$acl$;
grant execute on function public.customer_regenerate_bank_transfer(uuid,uuid,bigint,uuid,bigint,uuid)
  to authenticated;
comment on function public.customer_regenerate_bank_transfer(uuid,uuid,bigint,uuid,bigint,uuid) is
  'Owner-only expired bank QR regeneration. Closes the old ready intent, creates a new immutable snapshot and keeps payment awaiting; never settles.';
comment on function public.customer_get_bank_payment(uuid) is
  'Owner safe DTO including current intent id/version for exact regeneration concurrency; no mutation, verification or settlement.';
notify pgrst,'reload schema';
commit;
