-- GD2A only: two customer RPCs. No GD1 changes, grants on tables, or flow activation.
-- Apply after 202610100001_payment_core_security.sql in a reviewed environment.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if to_regclass('public.payments') is null or to_regclass('public.payment_events') is null
     or to_regclass('public.payment_code_seq') is null
     or to_regprocedure('private.payment_core_guard()') is null
     or to_regprocedure('private.payment_event_core_guard()') is null
     or to_regprocedure('auth.uid()') is null then
    raise exception 'PAYMENT_PREPARE_MISSING_PREREQUISITES';
  end if;
  if exists (select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('customer_prepare_payment', 'customer_get_payment')) then
    raise exception 'PAYMENT_PREPARE_ALREADY_EXISTS: review instead of overwriting';
  end if;
  if (select count(*) from pg_catalog.pg_class
      where oid in ('public.payments'::regclass, 'public.payment_events'::regclass) and relrowsecurity) <> 2
     or pg_catalog.has_table_privilege('authenticated', 'public.payments', 'INSERT,UPDATE,DELETE')
     or pg_catalog.has_table_privilege('anon', 'public.payments', 'SELECT,INSERT,UPDATE,DELETE')
     or pg_catalog.has_table_privilege('authenticated', 'public.payment_events', 'SELECT,INSERT,UPDATE,DELETE')
     or exists (select 1 from pg_catalog.pg_policy where polrelid = 'public.payment_events'::regclass)
     or (select count(*) from pg_catalog.pg_policy where polrelid = 'public.payments'::regclass) <> 2
     or not exists (select 1 from pg_catalog.pg_trigger where tgrelid = 'public.payments'::regclass
       and tgname = 'payment_core_guard' and tgenabled = 'O')
     or not exists (select 1 from pg_catalog.pg_trigger where tgrelid = 'public.payment_events'::regclass
       and tgname = 'payment_event_core_guard' and tgenabled = 'O') then
    raise exception 'PAYMENT_PREPARE_SECURITY_DRIFT';
  end if;
end;
$preflight$;

create function public.customer_get_payment(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_caller uuid := auth.uid();
  v_result jsonb;
begin
  if v_caller is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  -- Same error for unknown, NULL and another customer's request. Never resolve
  -- its assignment, quote or payment before checking request ownership.
  perform 1 from public.rescue_requests r where r.id = p_request_id and r.customer_id = v_caller;
  if not found then
    raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode = '42501';
  end if;
  select pg_catalog.jsonb_build_object(
    'payment_id', p.id, 'payment_code', p.payment_code, 'request_id', p.request_id,
    'assignment_id', p.assignment_id, 'quote_id', p.quote_id,
    'amount_expected', p.amount_expected::text, 'amount_received', p.amount_received::text,
    'currency', p.currency, 'method', p.method, 'status', p.status, 'version', p.version::text,
    'created_at', p.created_at, 'updated_at', p.updated_at,
    'paid_at', p.paid_at, 'cash_received_at', p.cash_received_at
  ) into v_result
  from public.payments p
  where p.request_id = p_request_id and p.customer_id = v_caller;
  -- SQL NULL (PostgREST JSON null), not an implicit prepare or empty object.
  return v_result;
end;
$$;
revoke all on function public.customer_get_payment(uuid) from public, anon, authenticated;

create function public.customer_prepare_payment(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_caller uuid := auth.uid();
  v_request public.rescue_requests;
  v_assignment public.rescue_request_assignments;
  v_quote public.rescue_quotes;
  v_payment public.payments;
begin
  if v_caller is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  -- Lock the owned parent even before a payment row exists. All calls for this
  -- request serialize here; foreign request IDs neither lock nor disclose it.
  select r.* into v_request from public.rescue_requests r
    where r.id = p_request_id and r.customer_id = v_caller for update;
  if not found then
    raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode = '42501';
  end if;

  -- Idempotent retry precedes CREATE eligibility checks. Never reset a stored
  -- snapshot, status, method, version, timestamps or audit (including future states).
  select p.* into v_payment from public.payments p where p.request_id = v_request.id;
  if found then
    if v_payment.customer_id is distinct from v_caller then
      raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode = '42501';
    end if;
    return public.customer_get_payment(v_request.id);
  end if;
  if v_request.status is distinct from 'completed' then
    raise exception 'PAYMENT_NOT_ELIGIBLE' using errcode = 'P0001';
  end if;

  select a.* into v_assignment from public.rescue_request_assignments a
    where a.request_id = v_request.id for update;
  if not found or v_assignment.state is distinct from 'completed'
     or v_assignment.request_id is distinct from v_request.id
     or v_assignment.rescuer_id is distinct from v_request.provider_id
     or v_assignment.completion_quote_id is null then
    raise exception 'PAYMENT_NOT_ELIGIBLE' using errcode = 'P0001';
  end if;
  select q.* into v_quote from public.rescue_quotes q
    where q.id = v_assignment.completion_quote_id for share;
  if not found or v_quote.assignment_id is distinct from v_assignment.id
     or v_quote.request_id is distinct from v_request.id
     or v_quote.rescuer_id is distinct from v_assignment.rescuer_id
     or v_assignment.current_quote_id is distinct from v_quote.id
     or v_quote.status is distinct from 'issued'
     or v_quote.currency is distinct from 'VND'
     or v_quote.total_vnd is null or v_quote.total_vnd < 0
     or v_request.quoted_price is distinct from v_quote.total_vnd then
    raise exception 'QUOTE_SNAPSHOT_INCONSISTENT' using errcode = 'P0001';
  end if;
  if v_quote.total_vnd = 0 then
    raise exception 'ZERO_AMOUNT_REQUIRES_POLICY' using errcode = 'P0001';
  end if;

  begin
    insert into public.payments(request_id, assignment_id, customer_id, rescuer_id,
      quote_id, amount_expected, currency, status, method)
    values(v_request.id, v_assignment.id, v_request.customer_id, v_assignment.rescuer_id,
      v_assignment.completion_quote_id, v_quote.total_vnd::bigint, 'VND', 'pending', null)
    on conflict (request_id) do nothing
    returning * into v_payment;
    if found then
      -- GD1 creates the TT code/server timestamps and validates the snapshot.
      -- Exactly one creation event in the same transaction as this INSERT.
      insert into public.payment_events(payment_id, request_id, event_type, actor_type, actor_id,
        old_status, new_status, amount, payment_version, event_sequence)
      values(v_payment.id, v_payment.request_id, 'payment_created', 'customer', v_caller,
        null, 'pending', v_payment.amount_expected, v_payment.version, 1);
    else
      -- Defensive fallback for another trusted insertion path. Do not catch
      -- unrelated unique violations as successful request retries.
      select p.* into v_payment from public.payments p
        where p.request_id = v_request.id and p.customer_id = v_caller;
      if not found then
        raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode = '42501';
      end if;
    end if;
  exception when integrity_constraint_violation then
    -- This block rolls back both writes. Do not return raw FK/row/constraint
    -- details from an unexpected snapshot or sequence-integrity failure.
    raise exception 'QUOTE_SNAPSHOT_INCONSISTENT' using errcode = 'P0001';
  end;
  return public.customer_get_payment(v_request.id);
end;
$$;
revoke all on function public.customer_prepare_payment(uuid) from public, anon, authenticated;

-- Also remove any service_role EXECUTE inherited from deployment defaults.
-- These are customer JWT entrypoints, not general server settlement APIs.
do $acl$
begin
  if exists (select 1 from pg_catalog.pg_roles where rolname = 'service_role') then
    revoke all on function public.customer_prepare_payment(uuid), public.customer_get_payment(uuid) from service_role;
  end if;
end;
$acl$;
grant execute on function public.customer_prepare_payment(uuid), public.customer_get_payment(uuid) to authenticated;
comment on function public.customer_prepare_payment(uuid) is
  'GD2A: owner-only, request-locked idempotent pending creation from completion quote with one atomic creation event.';
comment on function public.customer_get_payment(uuid) is
  'GD2A: owner-only read; SQL NULL when absent. Explicit safe DTO; bigint amounts/version serialized as decimal strings.';
notify pgrst, 'reload schema';
commit;
