-- GD2B: customer CASH selection only. Never edit the deployed GD1/GD2A files.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
do $preflight$
begin
  if to_regprocedure('public.customer_prepare_payment(uuid)') is null
     or to_regprocedure('public.customer_get_payment(uuid)') is null
     or to_regprocedure('private.payment_core_guard()') is null then
    raise exception 'PAYMENT_SELECT_MISSING_PREREQUISITES';
  end if;
  if to_regclass('private.payment_rpc_receipts') is not null
     or exists(select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
       where n.nspname='public' and p.proname='customer_select_payment_method') then
    raise exception 'PAYMENT_SELECT_ALREADY_EXISTS';
  end if;
  if (select count(*) from pg_catalog.pg_class where oid in
        ('public.payments'::regclass,'public.payment_events'::regclass) and relrowsecurity) <> 2
     or pg_catalog.has_table_privilege('authenticated','public.payments','INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
     or pg_catalog.has_table_privilege('anon','public.payments','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
     or pg_catalog.has_table_privilege('authenticated','public.payment_events','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
     or pg_catalog.has_table_privilege('anon','public.payment_events','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
     or exists(select 1 from pg_catalog.pg_policy where polrelid='public.payment_events'::regclass)
     or (select count(*) from pg_catalog.pg_policy where polrelid='public.payments'::regclass) <> 2
     or not exists(select 1 from pg_catalog.pg_trigger where tgrelid='public.payments'::regclass
       and tgname='payment_core_guard' and tgenabled='O') then
    raise exception 'PAYMENT_SELECT_SECURITY_DRIFT';
  end if;
end;
$preflight$;

-- Same actor/operation + SHA256 convention as private.rescuer_rpc_receipts.
-- Keep the original safe DTO to make a committed operation replay deterministic.
create table private.payment_rpc_receipts (
  actor_id uuid not null references auth.users(id) on delete restrict,
  operation_id uuid not null,
  operation_name text not null check(operation_name='customer_select_payment_method'),
  payload_hash text not null check(payload_hash ~ '^[0-9a-f]{64}$'),
  payment_id uuid not null references public.payments(id) on delete restrict,
  response_payment jsonb not null check(jsonb_typeof(response_payment)='object'
    and octet_length(response_payment::text)<=8192),
  committed_at timestamptz not null default clock_timestamp() check(isfinite(committed_at)),
  primary key(actor_id,operation_id)
);
alter table private.payment_rpc_receipts enable row level security;
revoke all on table private.payment_rpc_receipts from public,anon,authenticated;
create function private.payment_receipt_guard() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if tg_op <> 'INSERT' then
    raise exception 'PAYMENT_RECEIPT_IMMUTABLE' using errcode='23514';
  end if;
  if auth.uid() is null or new.actor_id is distinct from auth.uid()
     or not exists(select 1 from public.payments p where p.id=new.payment_id and p.customer_id=new.actor_id) then
    raise exception 'PAYMENT_RECEIPT_ACTOR_MISMATCH' using errcode='23514';
  end if;
  new.committed_at:=pg_catalog.clock_timestamp();
  return new;
end;
$$;
revoke all on function private.payment_receipt_guard() from public,anon,authenticated;
create trigger payment_receipt_guard before insert or update or delete on private.payment_rpc_receipts
  for each row execute function private.payment_receipt_guard();
create trigger payment_receipt_no_truncate before truncate on private.payment_rpc_receipts
  for each statement execute function private.payment_receipt_guard();

-- Preserve GD1 INSERT, identity, DELETE/TRUNCATE and server-time behavior.
-- Only the narrow CASH selection transition is added; no JWT/GUC bypass flag.
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
      if old.status is distinct from 'pending' or old.method is not null
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
revoke all on function private.payment_core_guard() from public,anon,authenticated;

create function public.customer_select_payment_method(
  p_request_id uuid,
  p_payment_id uuid,
  p_method text,
  p_expected_version bigint,
  p_operation_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid();
  v_request public.rescue_requests;
  v_payment public.payments;
  v_receipt private.payment_rpc_receipts;
  v_name constant text:='customer_select_payment_method';
  v_hash text;
  v_response jsonb;
  v_sequence bigint;
  v_changed boolean:=false;
begin
  if v_actor is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;
  if p_operation_id is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode='22023';
  end if;
  -- Same actor/key is serialized even when a caller tries another payment.
  -- Lock order: operation -> owned request -> payment; no assignment mutation.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'payment-operation:'||v_actor::text||':'||p_operation_id::text,0));
  select r.* into v_request from public.rescue_requests r
    where r.id=p_request_id and r.customer_id=v_actor for update;
  if not found then
    raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode='42501';
  end if;
  select p.* into v_payment from public.payments p
    where p.id=p_payment_id and p.request_id=p_request_id and p.customer_id=v_actor for update;
  if not found then
    raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode='42501';
  end if;
  -- Include the original expected version. Changing it on retry is a new payload.
  v_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(
    pg_catalog.jsonb_build_array(v_name,p_request_id,p_payment_id,p_method,p_expected_version)::text,'UTF8')),'hex');
  select r.* into v_receipt from private.payment_rpc_receipts r
    where r.actor_id=v_actor and r.operation_id=p_operation_id;
  if found then
    if v_receipt.operation_name is distinct from v_name or v_receipt.payload_hash is distinct from v_hash
       or v_receipt.payment_id is distinct from p_payment_id then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode='22023';
    end if;
    return pg_catalog.jsonb_build_object('payment',v_receipt.response_payment,'changed',false);
  end if;
  if p_method is distinct from 'cash' then
    raise exception 'METHOD_NOT_IMPLEMENTED' using errcode='22023';
  end if;
  if p_expected_version is null or p_expected_version<=0 then
    raise exception 'INVALID_EXPECTED_VERSION' using errcode='22023';
  end if;
  if v_payment.status in ('paid','refunded') then
    raise exception 'PAYMENT_ALREADY_SETTLED' using errcode='P0001';
  end if;
  if v_request.status is distinct from 'completed'
     or not ((v_payment.status='pending' and v_payment.method is null)
       or (v_payment.status='awaiting_payment' and v_payment.method='cash')) then
    raise exception 'PAYMENT_NOT_ELIGIBLE' using errcode='P0001';
  end if;
  if p_expected_version is distinct from v_payment.version then
    raise exception 'VERSION_CONFLICT' using errcode='P0001';
  end if;
  if v_payment.amount_expected=0 then
    raise exception 'ZERO_AMOUNT_REQUIRES_POLICY' using errcode='P0001';
  end if;
  begin
    if v_payment.status='pending' then
      if v_payment.version=9223372036854775807 then
        raise exception 'PAYMENT_NOT_ELIGIBLE' using errcode='P0001';
      end if;
      update public.payments set method='cash',status='awaiting_payment',version=version+1
        where id=v_payment.id returning * into v_payment;
      select coalesce(max(e.event_sequence),0)+1 into v_sequence
        from public.payment_events e where e.payment_id=v_payment.id;
      insert into public.payment_events(payment_id,request_id,event_type,actor_type,actor_id,
        old_status,new_status,amount,metadata,operation_id,payment_version,event_sequence)
      values(v_payment.id,v_payment.request_id,'payment_method_selected','customer',v_actor,
        'pending','awaiting_payment',v_payment.amount_expected,
        pg_catalog.jsonb_build_object('old_method',null,'new_method','cash'),
        p_operation_id,v_payment.version,v_sequence);
      v_changed:=true;
    end if;
    -- New key on existing CASH/awaiting is a no-op only at CURRENT version.
    -- Store its receipt too; never update timestamps or append another event.
    v_response:=public.customer_get_payment(p_request_id);
    insert into private.payment_rpc_receipts(actor_id,operation_id,operation_name,payload_hash,payment_id,response_payment)
    values(v_actor,p_operation_id,v_name,v_hash,v_payment.id,v_response);
  exception when integrity_constraint_violation then
    -- Roll back payment, event AND receipt; expose no raw constraint/row details.
    raise exception 'PAYMENT_STATE_CONFLICT' using errcode='P0001';
  end;
  return pg_catalog.jsonb_build_object('payment',v_response,'changed',v_changed);
end;
$$;
revoke all on function public.customer_select_payment_method(uuid,uuid,text,bigint,uuid) from public,anon,authenticated;
do $acl$
begin
  if exists(select 1 from pg_catalog.pg_roles where rolname='service_role') then
    revoke all on table private.payment_rpc_receipts from service_role;
    revoke all on function private.payment_receipt_guard(),private.payment_core_guard(),
      public.customer_select_payment_method(uuid,uuid,text,bigint,uuid) from service_role;
  end if;
end;
$acl$;
grant execute on function public.customer_select_payment_method(uuid,uuid,text,bigint,uuid) to authenticated;
comment on table private.payment_rpc_receipts is
  'Private immutable customer operation receipts. Exact payload replay; not cash collection receipts. No client access.';
comment on table public.payments is
  'GD2B: participant SELECT; pending prepare and owner CASH selection via RPC only. No collection/settlement API.';
comment on function public.customer_select_payment_method(uuid,uuid,text,bigint,uuid) is
  'GD2B CASH only. Returns {payment: GD2A safe DTO, changed: boolean}. Replay keeps original operation DTO; getter reads current state.';
notify pgrst,'reload schema';
commit;
