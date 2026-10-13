-- GD6B: customer bank selection + VietQR payload only. No verification/settlement.
-- Apply manually after GD6A. No beneficiary seed; absent config fails closed.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';

do $preflight$
begin
  if to_regprocedure('private.payment_bank_create_intent(uuid,uuid,timestamptz)') is null
     or to_regprocedure('public.rescuer_confirm_cash_received(uuid,uuid,bigint,bigint,uuid)') is null then
    raise exception 'BANK_QR_MISSING_PREREQUISITES';
  end if;
  if to_regclass('private.payment_bank_config') is not null then
    raise exception 'BANK_QR_ALREADY_EXISTS';
  end if;
  if exists(select 1 from pg_catalog.pg_publication where puballtables)
     or exists(select 1 from pg_catalog.pg_publication_namespace where pnnspid='private'::regnamespace)
     or exists(select 1 from pg_catalog.pg_publication_tables
       where schemaname='private' or (schemaname='public' and tablename='payment_events'))
     or not exists(select 1 from pg_catalog.pg_publication_tables
       where pubname='supabase_realtime' and schemaname='public' and tablename='payments') then
    raise exception 'BANK_QR_PUBLICATION_UNSAFE';
  end if;
  if pg_catalog.has_table_privilege('authenticated','public.payments','INSERT,UPDATE,DELETE')
     or pg_catalog.has_table_privilege('anon','public.payments','SELECT,INSERT,UPDATE,DELETE')
     or (select count(*) from pg_catalog.pg_policy where polrelid='public.payments'::regclass)<>2
     or exists(select 1 from pg_catalog.pg_policy where polrelid='public.payment_events'::regclass)
     or (select count(*) from pg_catalog.pg_class where oid in ('public.payments'::regclass,
       'public.payment_events'::regclass,'private.payment_bank_intents'::regclass) and relrowsecurity)<>3 then
    raise exception 'BANK_QR_SECURITY_DRIFT';
  end if;
end;
$preflight$;

-- DB-owner managed only. Enable only after beneficiary and bank-app scan review.
create table private.payment_bank_config (
  singleton boolean primary key default true check(singleton),
  enabled boolean not null default false,
  bank_bin text not null check(bank_bin ~ '^[0-9]{6}$'),
  bank_code text not null check(bank_code ~ '^[A-Z0-9]{2,20}$'),
  bank_name text not null check(length(btrim(bank_name)) between 2 and 120),
  account_number text not null check(account_number ~ '^[0-9]{6,19}$'),
  account_name text not null check(length(btrim(account_name)) between 3 and 120),
  reference_policy text not null default 'bank_sequence_v1' check(reference_policy='bank_sequence_v1'),
  expiry_seconds integer not null default 900 check(expiry_seconds between 60 and 86400),
  version bigint not null default 1 check(version>0)
);
alter table private.payment_bank_config enable row level security;
create sequence private.payment_bank_transfer_seq as bigint no cycle;

-- 1:1 immutable beneficiary/QR extension of the GD6A intent. Never public/realtime.
create table private.payment_bank_qr_snapshots (
  intent_id uuid primary key references private.payment_bank_intents(id) on delete restrict,
  config_version bigint not null check(config_version>0),
  bank_bin text not null,
  bank_code text not null,
  bank_name text not null,
  account_number text not null,
  account_name text not null,
  transfer_content text not null unique check(transfer_content ~ '^BK[0-9]{19}$'),
  qr_payload text not null check(octet_length(qr_payload) between 50 and 512)
);
alter table private.payment_bank_qr_snapshots enable row level security;

create function private.payment_bank_tlv(p_tag text,p_value text)
returns text language plpgsql immutable strict security invoker set search_path='' as $$
begin
  if p_tag !~ '^[0-9]{2}$' or octet_length(p_value) not between 1 and 99
     or octet_length(p_value)<>length(p_value) then
    raise exception 'BANK_QR_VALUE_INVALID' using errcode='22023';
  end if;
  return p_tag||pg_catalog.lpad(octet_length(p_value)::text,2,'0')||p_value;
end;
$$;

create function private.payment_bank_crc16(p_value text)
returns text language plpgsql immutable strict security invoker set search_path='' as $$
declare v_crc integer:=65535; v_bytes bytea:=pg_catalog.convert_to(p_value,'UTF8'); i integer; j integer;
begin
  for i in 0..octet_length(v_bytes)-1 loop
    v_crc:=v_crc # (pg_catalog.get_byte(v_bytes,i)<<8);
    for j in 1..8 loop
      v_crc:=case when (v_crc & 32768)<>0 then ((v_crc<<1) # 4129) & 65535 else (v_crc<<1) & 65535 end;
    end loop;
  end loop;
  return pg_catalog.upper(pg_catalog.lpad(pg_catalog.to_hex(v_crc),4,'0'));
end;
$$;

create function private.payment_bank_vietqr(p_bin text,p_account text,p_amount bigint,p_content text)
returns text language plpgsql immutable security invoker set search_path='' as $$
declare v_payload text;
begin
  if p_bin is null or p_bin !~ '^[0-9]{6}$' or p_account is null or p_account !~ '^[0-9]{6,19}$'
     or p_amount is null or p_amount not between 1 and 9999999999999
     or p_content is null or p_content !~ '^[A-Z0-9]{1,25}$' then
    raise exception 'BANK_QR_VALUE_INVALID' using errcode='22023';
  end if;
  v_payload:='000201010212'||private.payment_bank_tlv('38',
    private.payment_bank_tlv('00','A000000727')||private.payment_bank_tlv('01',
      private.payment_bank_tlv('00',p_bin)||private.payment_bank_tlv('01',p_account))||
    private.payment_bank_tlv('02','QRIBFTTA'))||'5303704'||private.payment_bank_tlv('54',p_amount::text)||
    '5802VN'||private.payment_bank_tlv('62',private.payment_bank_tlv('08',p_content))||'6304';
  return v_payload||private.payment_bank_crc16(v_payload);
end;
$$;

create function private.payment_bank_config_guard() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if tg_op='UPDATE' then new.version:=old.version+1; else new.version:=1; end if;
  return new;
end;
$$;
create trigger bank_config_guard before insert or update on private.payment_bank_config
  for each row execute function private.payment_bank_config_guard();

create function private.payment_bank_qr_snapshot_guard() returns trigger
language plpgsql security invoker set search_path='' as $$
declare c private.payment_bank_config; i private.payment_bank_intents;
begin
  if tg_op<>'INSERT' then raise exception 'BANK_QR_SNAPSHOT_IMMUTABLE' using errcode='23514'; end if;
  select * into c from private.payment_bank_config where singleton and enabled for share;
  if not found then raise exception 'BANK_UNAVAILABLE' using errcode='P0001'; end if;
  select * into i from private.payment_bank_intents where id=new.intent_id for update;
  if not found or i.status<>'created' or i.expires_at<=pg_catalog.clock_timestamp()
     or not exists(select 1 from public.payments p where p.id=i.payment_id and p.method is null
       and p.status='pending' and p.customer_id=auth.uid()) then
    raise exception 'BANK_INTENT_UNAVAILABLE' using errcode='P0001';
  end if;
  new.config_version:=c.version;
  new.bank_bin:=c.bank_bin; new.bank_code:=c.bank_code; new.bank_name:=c.bank_name;
  new.account_number:=c.account_number; new.account_name:=c.account_name;
  -- 21 ASCII characters, exact-match key mapped uniquely to the immutable BK- UUID.
  new.transfer_content:='BK'||pg_catalog.lpad(pg_catalog.nextval('private.payment_bank_transfer_seq'::regclass)::text,19,'0');
  new.qr_payload:=private.payment_bank_vietqr(c.bank_bin,c.account_number,i.expected_amount,new.transfer_content);
  return new;
end;
$$;
create trigger bank_qr_snapshot_guard before insert or update or delete on private.payment_bank_qr_snapshots
  for each row execute function private.payment_bank_qr_snapshot_guard();
create trigger bank_qr_snapshot_no_truncate before truncate on private.payment_bank_qr_snapshots
  for each statement execute function private.payment_bank_qr_snapshot_guard();

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
      if old.status='pending' and old.method is null and new.method='bank_transfer'
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



-- Reuse the existing immutable, actor-scoped operation namespace.
alter table private.payment_rpc_receipts drop constraint payment_rpc_receipts_operation_name_check;
alter table private.payment_rpc_receipts add constraint payment_rpc_receipts_operation_name_check
  check(operation_name in ('customer_select_payment_method','customer_select_bank_transfer'));

create function public.customer_get_bank_capability(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_available boolean;
begin
  if v_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if not exists(select 1 from public.rescue_requests where id=p_request_id and customer_id=v_actor) then
    raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode='42501';
  end if;
  select exists(select 1 from public.payments p join public.rescue_requests r on r.id=p.request_id
    where p.request_id=p_request_id and p.customer_id=v_actor and r.status='completed'
      and p.method is null and p.status='pending' and p.currency='VND'
      and p.amount_expected between 1 and 9999999999999
      and exists(select 1 from private.payment_bank_config c where c.singleton and c.enabled)
      and not exists(select 1 from private.payment_bank_intents i where i.payment_id=p.id
        and i.status in ('created','ready','matched','verified')
        and (i.status<>'created' or i.expires_at<=pg_catalog.statement_timestamp()))) into v_available;
  return pg_catalog.jsonb_build_object('available',v_available);
end;
$$;

create function public.customer_get_bank_payment(p_request_id uuid)
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
  select b.* into i from private.payment_bank_intents b join private.payment_bank_qr_snapshots q on q.intent_id=b.id
    where b.payment_id=p.id order by b.created_at desc,b.id limit 1;
  if not found then raise exception 'BANK_INTENT_UNAVAILABLE' using errcode='P0001'; end if;
  select * into s from private.payment_bank_qr_snapshots where intent_id=i.id;
  select exists(select 1 from private.payment_bank_config c where c.singleton and c.enabled) into v_enabled;
  v_status:=case when i.status in ('created','ready') and i.expires_at<=pg_catalog.statement_timestamp()
    then 'expired' else i.status end;
  return pg_catalog.jsonb_build_object(
    'payment_id',p.id,'payment_code',p.payment_code,'request_id',p.request_id,
    'payment_status',p.status,'payment_method',p.method,'amount_expected',p.amount_expected::text,'currency',p.currency,
    'bank_intent_status',v_status,'bank_reference',i.reference,
    'bank_code',s.bank_code,'bank_bin',s.bank_bin,'bank_name',s.bank_name,
    'account_number',s.account_number,'account_name',s.account_name,'transfer_content',s.transfer_content,
    'expires_at',i.expires_at,'server_time',pg_catalog.statement_timestamp(),
    'available',v_enabled,'qr_payload',case when v_enabled and v_status='ready' and p.status='awaiting_payment' then s.qr_payload end,
    'version',p.version::text,'bank_intent_version',i.version::text);
end;
$$;

create function public.customer_select_bank_transfer(
  p_request_id uuid,p_payment_id uuid,p_expected_version bigint,p_operation_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); r public.rescue_requests; p public.payments;
  c private.payment_bank_config; i private.payment_bank_intents; v_id uuid;
  receipt private.payment_rpc_receipts; v_hash text; v_response jsonb; v_sequence bigint;
begin
  if v_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if p_operation_id is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode='22023'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('payment-operation:'||v_actor::text||':'||p_operation_id::text,0));
  -- Acquire helper's operation lock BEFORE request/payment to avoid inverse lock order.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('bank-intent-operation:'||p_operation_id::text,0));
  select * into r from public.rescue_requests where id=p_request_id and customer_id=v_actor for update;
  if not found then raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode='42501'; end if;
  perform 1 from public.rescue_request_assignments a where a.request_id=r.id for share;
  select * into p from public.payments where id=p_payment_id and request_id=p_request_id and customer_id=v_actor for update;
  if not found then raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode='42501'; end if;
  v_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.jsonb_build_array(
    'customer_select_bank_transfer',p_request_id,p_payment_id,p_expected_version)::text,'UTF8')),'hex');
  select * into receipt from private.payment_rpc_receipts where actor_id=v_actor and operation_id=p_operation_id;
  if found then
    if receipt.operation_name<>'customer_select_bank_transfer' or receipt.payload_hash<>v_hash or receipt.payment_id<>p.id then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode='22023';
    end if;
    return pg_catalog.jsonb_build_object('payment',receipt.response_payment,'changed',false);
  end if;
  if p_expected_version is null or p_expected_version<=0 then raise exception 'INVALID_EXPECTED_VERSION' using errcode='22023'; end if;
  if p.status in ('paid','refunded') then raise exception 'PAYMENT_ALREADY_SETTLED' using errcode='P0001'; end if;
  if r.status<>'completed' or p.status<>'pending' or p.method is not null then
    raise exception 'PAYMENT_NOT_ELIGIBLE' using errcode='P0001';
  end if;
  if p.version<>p_expected_version then raise exception 'VERSION_CONFLICT' using errcode='P0001'; end if;
  if p.amount_expected<=0 then raise exception 'ZERO_AMOUNT_REQUIRES_POLICY' using errcode='P0001'; end if;
  select * into c from private.payment_bank_config where singleton and enabled for share;
  if not found or p.currency<>'VND' or p.amount_expected>9999999999999 then
    raise exception 'BANK_UNAVAILABLE' using errcode='P0001';
  end if;
  if p.version=9223372036854775807 then raise exception 'PAYMENT_NOT_ELIGIBLE' using errcode='P0001'; end if;
  begin
    select * into i from private.payment_bank_intents where payment_id=p.id and status in ('created','ready','matched','verified') for update;
    if found then
      if i.status<>'created' or i.expires_at<=pg_catalog.clock_timestamp() then
        raise exception 'BANK_INTENT_UNAVAILABLE' using errcode='P0001';
      end if;
      v_id:=i.id; -- Reuse the unissued GD6A reservation; never change its reference/expiry.
    else
      -- A historical operation belonging to another primitive may not be adopted.
      if exists(select 1 from private.payment_bank_intents where operation_id=p_operation_id) then
        raise exception 'IDEMPOTENCY_CONFLICT' using errcode='22023';
      end if;
      v_id:=private.payment_bank_create_intent(p.id,p_operation_id,
        pg_catalog.clock_timestamp()+pg_catalog.make_interval(secs=>c.expiry_seconds));
    end if;
    insert into private.payment_bank_qr_snapshots(intent_id) values(v_id);
    update private.payment_bank_intents set status='ready',version=version+1 where id=v_id;
    update public.payments set method='bank_transfer',status='awaiting_payment',version=version+1 where id=p.id returning * into p;
    select coalesce(max(event_sequence),0)+1 into v_sequence from public.payment_events where payment_id=p.id;
    insert into public.payment_events(payment_id,request_id,event_type,actor_type,actor_id,
      old_status,new_status,amount,metadata,operation_id,payment_version,event_sequence)
    values(p.id,p.request_id,'bank_qr_created','customer',v_actor,'pending','awaiting_payment',p.amount_expected,
      pg_catalog.jsonb_build_object('old_method',null,'new_method','bank_transfer'),p_operation_id,p.version,v_sequence);
    v_response:=public.customer_get_payment(p_request_id);
    insert into private.payment_rpc_receipts(actor_id,operation_id,operation_name,payload_hash,payment_id,response_payment)
      values(v_actor,p_operation_id,'customer_select_bank_transfer',v_hash,p.id,v_response);
  exception when integrity_constraint_violation then
    raise exception 'PAYMENT_STATE_CONFLICT' using errcode='P0001';
  end;
  return pg_catalog.jsonb_build_object('payment',v_response,'changed',true);
end;
$$;

revoke all on table private.payment_bank_config,private.payment_bank_qr_snapshots from public,anon,authenticated;
revoke all on sequence private.payment_bank_transfer_seq from public,anon,authenticated;
revoke all on function private.payment_bank_tlv(text,text),private.payment_bank_crc16(text),
  private.payment_bank_vietqr(text,text,bigint,text),private.payment_bank_config_guard(),private.payment_bank_qr_snapshot_guard(),
  private.payment_core_guard(),private.payment_bank_intent_guard(),
  public.customer_get_bank_capability(uuid),public.customer_get_bank_payment(uuid),
  public.customer_select_bank_transfer(uuid,uuid,bigint,uuid) from public,anon,authenticated;
do $acl$
begin
  if exists(select 1 from pg_catalog.pg_roles where rolname='service_role') then
    revoke all on table private.payment_bank_config,private.payment_bank_qr_snapshots from service_role;
    revoke all on sequence private.payment_bank_transfer_seq from service_role;
    revoke all on function private.payment_bank_tlv(text,text),private.payment_bank_crc16(text),
      private.payment_bank_vietqr(text,text,bigint,text),private.payment_bank_config_guard(),private.payment_bank_qr_snapshot_guard(),
      private.payment_core_guard(),private.payment_bank_intent_guard(),
      public.customer_get_bank_capability(uuid),public.customer_get_bank_payment(uuid),
      public.customer_select_bank_transfer(uuid,uuid,bigint,uuid) from service_role;
  end if;
end;
$acl$;
grant execute on function public.customer_get_bank_capability(uuid),public.customer_get_bank_payment(uuid),
  public.customer_select_bank_transfer(uuid,uuid,bigint,uuid) to authenticated;
comment on table private.payment_bank_config is 'GD6B DB-owner beneficiary configuration. Empty by default. No secrets; never publish.';
comment on table private.payment_bank_qr_snapshots is 'GD6B immutable 1:1 intent beneficiary and QR snapshot. transfer_content is the unique bank-facing match key.';
comment on function public.customer_get_bank_payment(uuid) is 'Owner safe DTO; server-time effective expiry only, no payment mutation, verification or renewal.';
notify pgrst,'reload schema';
commit;
