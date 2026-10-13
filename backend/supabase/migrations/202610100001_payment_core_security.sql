-- Payment security foundation only. No public mutation RPC or settlement flow.
-- Requires the shared customer + rescuer foundation. Does not depend on Admin.
-- Apply to a reviewed environment only; never infer deployment from this file.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if to_regclass('public.rescue_requests') is null
     or to_regclass('public.rescue_request_assignments') is null
     or to_regclass('public.rescue_quotes') is null
     or to_regclass('public.customer_profiles') is null
     or to_regclass('public.rescuer_profiles') is null
     or to_regnamespace('private') is null
     or to_regprocedure('auth.uid()') is null
     or to_regprocedure('private.rescuer_check_consistency()') is null then
    raise exception 'PAYMENT_CORE_MISSING_PREREQUISITES';
  end if;
  if to_regclass('public.payments') is not null
     or to_regclass('public.payment_events') is not null
     or to_regclass('public.payment_code_seq') is not null then
    raise exception 'PAYMENT_CORE_ALREADY_EXISTS: review schema instead of overwriting';
  end if;
end;
$preflight$;

-- The PK on id alone is not a candidate key for a two-column ownership FK.
-- Existing rows remain valid because id is already unique. No backfill/DML.
alter table public.rescue_requests
  add constraint rescue_requests_payment_customer_key unique (id, customer_id);

create sequence public.payment_code_seq as bigint start with 1 no cycle;
revoke all on sequence public.payment_code_seq from public, anon, authenticated;

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  payment_code text not null unique,
  request_id uuid not null unique,
  assignment_id uuid not null,
  customer_id uuid not null references auth.users(id) on delete restrict,
  rescuer_id uuid not null references public.rescuer_profiles(user_id) on delete restrict,
  quote_id uuid not null,
  amount_expected bigint not null check (amount_expected >= 0),
  amount_received bigint check (amount_received >= 0),
  currency text not null default 'VND' check (currency = 'VND'),
  method text check (method in ('cash', 'bank_transfer')),
  status text not null default 'pending'
    check (status in ('pending', 'awaiting_payment', 'verifying', 'paid', 'failed', 'cancelled', 'refunded')),
  version bigint not null default 1 check (version > 0),
  cash_received_by uuid references public.rescuer_profiles(user_id) on delete restrict,
  cash_received_at timestamptz,
  paid_at timestamptz,
  verified_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  refunded_at timestamptz,
  failure_code text check (failure_code ~ '^[a-z][a-z0-9_]{0,63}$'),
  cancellation_reason_code text check (cancellation_reason_code ~ '^[a-z][a-z0-9_]{0,63}$'),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  constraint payments_code_format check (
    payment_code ~ '^TT-[0-9]{6,19}$' and substring(payment_code from 4)::numeric > 0
  ),
  constraint payments_request_customer_fk foreign key (request_id, customer_id)
    references public.rescue_requests(id, customer_id) on delete restrict,
  constraint payments_assignment_identity_fk foreign key (assignment_id, request_id, rescuer_id)
    references public.rescue_request_assignments(id, request_id, rescuer_id) on delete restrict,
  constraint payments_quote_assignment_fk foreign key (quote_id, assignment_id)
    references public.rescue_quotes(id, assignment_id) on delete restrict,
  constraint payments_id_request_key unique (id, request_id),
  constraint payments_method_status_check check (
    (status = 'pending' and method is null)
    or (status = 'cancelled')
    or (status in ('awaiting_payment', 'verifying', 'paid', 'failed', 'refunded') and method is not null)
  ),
  constraint payments_finite_timestamps check (
    isfinite(created_at) and isfinite(updated_at)
    and (cash_received_at is null or isfinite(cash_received_at))
    and (paid_at is null or isfinite(paid_at))
    and (verified_at is null or isfinite(verified_at))
    and (failed_at is null or isfinite(failed_at))
    and (cancelled_at is null or isfinite(cancelled_at))
    and (refunded_at is null or isfinite(refunded_at))
  )
);
alter table public.payments enable row level security;
revoke all on table public.payments from public, anon, authenticated;

create table public.payment_events (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null,
  request_id uuid not null,
  event_type text not null check (event_type in (
    'payment_created', 'payment_method_selected', 'cash_confirmation_started', 'cash_received',
    'bank_qr_created', 'bank_transfer_detected', 'bank_transfer_verifying', 'bank_payment_verified',
    'payment_failed', 'payment_cancelled', 'payment_refunded',
    'payment_method_change_rejected', 'bank_transfer_conflict', 'payment_recovery_started'
  )),
  actor_type text not null check (actor_type in ('customer', 'rescuer', 'admin', 'provider', 'system')),
  actor_id uuid references auth.users(id) on delete restrict,
  old_status text check (old_status in ('pending', 'awaiting_payment', 'verifying', 'paid', 'failed', 'cancelled', 'refunded')),
  new_status text check (new_status in ('pending', 'awaiting_payment', 'verifying', 'paid', 'failed', 'cancelled', 'refunded')),
  amount bigint check (amount >= 0),
  metadata jsonb not null default '{}'::jsonb
    check (jsonb_typeof(metadata) = 'object' and octet_length(metadata::text) <= 8192),
  created_at timestamptz not null default clock_timestamp(),
  operation_id uuid,
  payment_version bigint not null check (payment_version > 0),
  event_sequence bigint not null check (event_sequence > 0),
  constraint payment_events_payment_request_fk foreign key (payment_id, request_id)
    references public.payments(id, request_id) on delete restrict,
  constraint payment_events_sequence_key unique (payment_id, event_sequence),
  constraint payment_events_actor_check check (
    (actor_type in ('customer', 'rescuer', 'admin') and actor_id is not null)
    or (actor_type in ('provider', 'system') and actor_id is null)
  ),
  constraint payment_events_finite_timestamp check (isfinite(created_at))
);
alter table public.payment_events enable row level security;
revoke all on table public.payment_events from public, anon, authenticated;

-- Supabase installations may have default privileges for service_role.
-- This phase exposes no trusted API writer either. Owner/DB administration
-- remains the privileged migration/test boundary, not a frontend credential.
do $server_acl$
begin
  if exists (select 1 from pg_catalog.pg_roles where rolname = 'service_role') then
    revoke all on table public.payments, public.payment_events from service_role;
    revoke all on sequence public.payment_code_seq from service_role;
  end if;
end;
$server_acl$;

create index payments_customer_created_idx on public.payments(customer_id, created_at desc, id);
create index payments_rescuer_created_idx on public.payments(rescuer_id, created_at desc, id);
create index payments_status_created_idx on public.payments(status, created_at desc, id);

-- SECURITY INVOKER: no privileged callable helper. Only a writer already
-- authorized by table ACL/RLS can reach this trigger. No dynamic SQL.
create function private.payment_core_guard() returns trigger
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
    -- Fail closed until a later reviewed migration adds the trusted mutation
    -- contract and atomic audit. Do not implement a cash/bank/refund flow here.
    if (pg_catalog.to_jsonb(new) - 'updated_at') is distinct from
       (pg_catalog.to_jsonb(old) - 'updated_at') then
      raise exception 'PAYMENT_MUTATION_NOT_ENABLED' using errcode = '23514';
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

  -- Stable snapshot under parent locks; ownership itself is also enforced by
  -- immediate composite FKs even for privileged writers. Do not add grants
  -- on the private assignment/quote tables to make participant SELECT work.
  select * into v_request from public.rescue_requests where id = new.request_id for share;
  select * into v_assignment from public.rescue_request_assignments where id = new.assignment_id for share;
  select * into v_quote from public.rescue_quotes where id = new.quote_id for share;
  if v_request.id is null or v_assignment.id is null or v_quote.id is null
     or v_request.customer_id is distinct from new.customer_id
     or v_assignment.request_id is distinct from new.request_id
     or v_assignment.rescuer_id is distinct from new.rescuer_id
     or v_quote.assignment_id is distinct from new.assignment_id then
    -- Let the named FKs reject this row; never silently repair supplied IDs.
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
revoke all on function private.payment_core_guard() from public, anon, authenticated;

create trigger payment_core_guard before insert or update or delete on public.payments
  for each row execute function private.payment_core_guard();
create trigger payment_core_no_truncate before truncate on public.payments
  for each statement execute function private.payment_core_guard();

create function private.payment_event_core_guard() returns trigger
language plpgsql security invoker set search_path = '' as $$
declare v_version bigint;
begin
  if tg_op in ('UPDATE', 'DELETE', 'TRUNCATE') then
    raise exception 'PAYMENT_EVENT_IMMUTABLE' using errcode = '23514';
  end if;
  -- The row lock also serializes future privileged event insertion. Business
  -- writers must later allocate event_sequence and mutate/audit atomically.
  select p.version into v_version from public.payments p where p.id = new.payment_id for update;
  if found and new.payment_version is distinct from v_version then
    raise exception 'PAYMENT_EVENT_VERSION_MISMATCH' using errcode = '23514';
  end if;
  if new.actor_type in ('customer', 'rescuer', 'admin') then
    if auth.uid() is null or new.actor_id is distinct from auth.uid() then
      raise exception 'PAYMENT_EVENT_ACTOR_MISMATCH' using errcode = '23514';
    end if;
    new.actor_id := auth.uid();
  end if;
  new.created_at := pg_catalog.clock_timestamp();
  return new;
end;
$$;
revoke all on function private.payment_event_core_guard() from public, anon, authenticated;
do $helper_acl$
begin
  if exists (select 1 from pg_catalog.pg_roles where rolname = 'service_role') then
    revoke all on function private.payment_core_guard(), private.payment_event_core_guard() from service_role;
  end if;
end;
$helper_acl$;

create trigger payment_event_core_guard before insert or update or delete on public.payment_events
  for each row execute function private.payment_event_core_guard();
create trigger payment_event_core_no_truncate before truncate on public.payment_events
  for each statement execute function private.payment_event_core_guard();

grant select on table public.payments to authenticated;
create policy payments_customer_read on public.payments for select to authenticated
  using (customer_id = (select auth.uid()));
create policy payments_rescuer_read on public.payments for select to authenticated
  using (rescuer_id = (select auth.uid()));
-- No admin override, no event SELECT policy, no client write policies/grants.

comment on table public.payments is
  'Security foundation only: participant SELECT; no API mutation, pending-only insertion until a later reviewed flow migration.';
comment on table public.payment_events is
  'Immutable internal audit records; no direct client or Admin SELECT/DML. Future sanitized RPC required.';
notify pgrst, 'reload schema';
commit;
