-- GD3: rescuer CASH only. Local source; no automatic deployment.
-- Upgrades guards in this NEW migration; never rewrites GD1/GD2A/GD2B files.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
do $preflight$
begin
  if to_regprocedure('public.customer_select_payment_method(uuid,uuid,text,bigint,uuid)') is null
     or to_regprocedure('private.rescuer_begin_operation(text,uuid,jsonb)') is null
     or to_regprocedure('private.rescuer_commit_receipt(text,uuid,jsonb,uuid)') is null
     or to_regprocedure('private.rescuer_require_profile(boolean)') is null then
    raise exception 'PAYMENT_CASH_MISSING_PREREQUISITES';
  end if;
  if exists(select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in ('rescuer_get_job_payment','rescuer_confirm_cash_received')) then
    raise exception 'PAYMENT_CASH_ALREADY_EXISTS';
  end if;
  if (select count(*) from pg_catalog.pg_class where oid in ('public.payments'::regclass,
       'public.payment_events'::regclass,'private.rescuer_rpc_receipts'::regclass) and relrowsecurity)<>3
     or pg_catalog.has_table_privilege('authenticated','public.payments','INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
     or pg_catalog.has_table_privilege('anon','public.payments','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
     or pg_catalog.has_table_privilege('authenticated','public.payment_events','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
     or pg_catalog.has_table_privilege('anon','public.payment_events','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
     or pg_catalog.has_table_privilege('authenticated','private.rescuer_rpc_receipts','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
     or pg_catalog.has_table_privilege('anon','private.rescuer_rpc_receipts','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
     or exists(select 1 from pg_catalog.pg_policy where polrelid in
       ('public.payment_events'::regclass,'private.rescuer_rpc_receipts'::regclass))
     or (select count(*) from pg_catalog.pg_policies where schemaname='public' and tablename='payments'
       and cmd='SELECT' and roles=array['authenticated']::name[])<>2
     or (select count(*) from pg_catalog.pg_policy where polrelid='public.payments'::regclass)<>2
     or not exists(select 1 from pg_catalog.pg_trigger where tgrelid='public.payments'::regclass and tgname='payment_core_guard' and tgenabled='O')
     or not exists(select 1 from pg_catalog.pg_trigger where tgrelid='public.payment_events'::regclass and tgname='payment_event_core_guard' and tgenabled='O') then
    raise exception 'PAYMENT_CASH_SECURITY_DRIFT';
  end if;
end;
$preflight$;

-- One effective CASH collection for the lifetime of a payment, including retries.
create unique index payment_events_one_cash_received on public.payment_events(payment_id)
  where event_type='cash_received';

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
      if old.status='awaiting_payment' and old.method='cash'
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
revoke all on function private.payment_core_guard() from public,anon,authenticated;


-- Preserve all GD1 event behavior; CASH additionally binds to the settled row
-- and uses its server-generated settlement timestamp. No raw client event access.
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
  if new.event_type='cash_received' then
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
revoke all on function private.payment_event_core_guard() from public,anon,authenticated;

create function public.rescuer_get_job_payment(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_result jsonb;
begin
  if v_actor is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;
  select pg_catalog.jsonb_build_object(
    'payment_id',p.id,'payment_code',p.payment_code,'request_id',p.request_id,
    'assignment_id',p.assignment_id,'quote_id',p.quote_id,
    'amount_expected',p.amount_expected::text,'amount_received',p.amount_received::text,
    'currency',p.currency,'method',p.method,'status',p.status,'version',p.version::text,
    'created_at',p.created_at,'updated_at',p.updated_at,'paid_at',p.paid_at,'cash_received_at',p.cash_received_at
  ) into v_result from public.payments p
  join public.rescue_request_assignments a on a.id=p.assignment_id and a.request_id=p.request_id and a.rescuer_id=v_actor
  where p.request_id=p_request_id and p.rescuer_id=v_actor;
  if not found then
    raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode='42501';
  end if;
  return v_result;
end;
$$;
revoke all on function public.rescuer_get_job_payment(uuid) from public,anon,authenticated;

create function public.rescuer_confirm_cash_received(
  p_request_id uuid,p_payment_id uuid,p_amount_received bigint,p_expected_version bigint,p_operation_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid();
  v_request public.rescue_requests;
  v_assignment public.rescue_request_assignments;
  v_payment public.payments;
  v_name constant text:='rescuer_confirm_cash_received';
  v_payload jsonb:=pg_catalog.jsonb_build_array(p_request_id,p_payment_id,p_amount_received,p_expected_version);
  v_resource uuid;
  v_now timestamptz;
  v_sequence bigint;
  v_changed boolean:=false;
begin
  if v_actor is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;
  if p_operation_id is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode='22023';
  end if;
  -- Reuse the rescuer namespace and exact profile -> request -> assignment ->
  -- payment order. Never use rescuer_lock_job: it refuses completed jobs.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('rescuer:'||v_actor::text,0));
  perform 1 from public.rescuer_profiles r where r.user_id=v_actor for update;
  select r.* into v_request from public.rescue_requests r
    where r.id=p_request_id and exists(select 1 from public.payments p
      join public.rescue_request_assignments a on a.id=p.assignment_id and a.request_id=p.request_id
      where p.id=p_payment_id and p.request_id=r.id and p.rescuer_id=v_actor and a.rescuer_id=v_actor)
    for update of r;
  if not found then
    raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode='42501';
  end if;
  select a.* into v_assignment from public.rescue_request_assignments a
    where a.request_id=p_request_id and a.rescuer_id=v_actor for update;
  if not found then
    raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode='42501';
  end if;
  select p.* into v_payment from public.payments p
    where p.id=p_payment_id and p.request_id=p_request_id and p.rescuer_id=v_actor
      and p.assignment_id=v_assignment.id for update;
  if not found then
    raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode='42501';
  end if;
  -- Ownership is established BEFORE any receipt result or payload conflict.
  -- Helper reacquires only locks already held; no inverse/new profile lock.
  v_resource:=private.rescuer_begin_operation(v_name,p_operation_id,v_payload);
  if v_resource is not null then
    if v_resource is distinct from v_payment.id then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode='22023';
    end if;
    return pg_catalog.jsonb_build_object('payment',public.rescuer_get_job_payment(p_request_id),'changed',false);
  end if;
  perform private.rescuer_require_profile(true);
  if p_expected_version is null or p_expected_version<=0 then
    raise exception 'INVALID_EXPECTED_VERSION' using errcode='22023';
  end if;
  -- A new key cannot overwrite any other settlement; matching paid CASH may
  -- no-op only with current version, same actor/amount and fresh approval.
  if v_payment.status='refunded' or (v_payment.status='paid' and not (
      v_payment.method='cash' and v_payment.cash_received_by is not distinct from v_actor
      and v_payment.amount_received is not distinct from v_payment.amount_expected
      and p_amount_received is not distinct from v_payment.amount_expected
      and v_payment.cash_received_at is not null and v_payment.paid_at is not null
      and v_payment.verified_at is null)) then
    raise exception 'PAYMENT_ALREADY_SETTLED' using errcode='P0001';
  end if;
  if v_request.status is distinct from 'completed' or v_assignment.state is distinct from 'completed'
     or v_request.provider_id is distinct from v_actor
     or v_payment.method is distinct from 'cash' or v_payment.status not in ('awaiting_payment','paid') then
    raise exception 'PAYMENT_NOT_ELIGIBLE' using errcode='P0001';
  end if;
  if p_amount_received is null or p_amount_received<0 or p_amount_received is distinct from v_payment.amount_expected then
    raise exception 'PAYMENT_AMOUNT_MISMATCH' using errcode='P0001';
  end if;
  if p_expected_version is distinct from v_payment.version then
    raise exception 'VERSION_CONFLICT' using errcode='P0001';
  end if;
  if v_payment.amount_expected=0 then
    raise exception 'ZERO_AMOUNT_REQUIRES_POLICY' using errcode='P0001';
  end if;
  begin
    if v_payment.status='awaiting_payment' then
      if v_payment.version=9223372036854775807 then
        raise exception 'PAYMENT_NOT_ELIGIBLE' using errcode='P0001';
      end if;
      v_now:=pg_catalog.clock_timestamp();
      update public.payments set status='paid',amount_received=amount_expected,cash_received_by=v_actor,
        cash_received_at=v_now,paid_at=v_now,verified_at=null,version=version+1,updated_at=v_now
        where id=v_payment.id returning * into v_payment;
      -- The row guard owns the definitive server timestamp for all three fields.
      v_now:=v_payment.cash_received_at;
      select coalesce(max(e.event_sequence),0)+1 into v_sequence
        from public.payment_events e where e.payment_id=v_payment.id;
      insert into public.payment_events(payment_id,request_id,event_type,actor_type,actor_id,
        old_status,new_status,amount,operation_id,payment_version,event_sequence,created_at)
      values(v_payment.id,v_payment.request_id,'cash_received','rescuer',v_actor,
        'awaiting_payment','paid',v_payment.amount_expected,p_operation_id,v_payment.version,v_sequence,v_now);
      v_changed:=true;
    end if;
    -- New-key no-op consumes the key without a second collection/event.
    perform private.rescuer_commit_receipt(v_name,p_operation_id,v_payload,v_payment.id);
  exception when integrity_constraint_violation then
    raise exception 'PAYMENT_STATE_CONFLICT' using errcode='P0001';
  end;
  return pg_catalog.jsonb_build_object('payment',public.rescuer_get_job_payment(p_request_id),'changed',v_changed);
end;
$$;
revoke all on function public.rescuer_confirm_cash_received(uuid,uuid,bigint,bigint,uuid) from public,anon,authenticated;
do $acl$
begin
  if exists(select 1 from pg_catalog.pg_roles where rolname='service_role') then
    revoke all on function private.payment_core_guard(),private.payment_event_core_guard(),
      public.rescuer_get_job_payment(uuid),public.rescuer_confirm_cash_received(uuid,uuid,bigint,bigint,uuid) from service_role;
  end if;
end;
$acl$;
grant execute on function public.rescuer_get_job_payment(uuid),
  public.rescuer_confirm_cash_received(uuid,uuid,bigint,bigint,uuid) to authenticated;
comment on function public.rescuer_confirm_cash_received(uuid,uuid,bigint,bigint,uuid) is
  'GD3: assigned approved rescuer CASH collection only; receipt replay precedes approval/version; current safe DTO and changed boolean.';
comment on table public.payments is
  'GD3: participant SELECT, customer prepare/select CASH and assigned rescuer CASH paid via RPC. No bank settlement API.';
notify pgrst,'reload schema';
commit;
