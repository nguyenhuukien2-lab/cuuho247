begin;
create table public.customer_saved_addresses (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id) on delete cascade,
  label text not null check (label in ('Nhà', 'Công ty', 'Trường học', 'Khác')),
  address text not null check (length(trim(address)) between 1 and 1000),
  latitude double precision,
  longitude double precision,
  notes text check (notes is null or length(notes) <= 1000),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((latitude is null and longitude is null) or
    (latitude is not null and longitude is not null and
     latitude between -90 and 90 and longitude between -180 and 180))
);
create index customer_saved_addresses_owner_idx on public.customer_saved_addresses(customer_id);
create unique index customer_saved_addresses_one_default on public.customer_saved_addresses(customer_id) where is_default;
alter table public.customer_saved_addresses enable row level security;
revoke all on public.customer_saved_addresses from public, anon, authenticated;
grant select, insert, update, delete on public.customer_saved_addresses to authenticated;
create policy "customers read own addresses" on public.customer_saved_addresses for select to authenticated using (customer_id = (select auth.uid()));
create policy "customers insert own addresses" on public.customer_saved_addresses for insert to authenticated with check (customer_id = (select auth.uid()));
create policy "customers update own addresses" on public.customer_saved_addresses for update to authenticated using (customer_id = (select auth.uid())) with check (customer_id = (select auth.uid()));
create policy "customers delete own addresses" on public.customer_saved_addresses for delete to authenticated using (customer_id = (select auth.uid()));
-- Serialize changes per customer and switch the default in the same transaction.
-- Invoker rights preserve the owner-only RLS policies.
create function public.prepare_customer_saved_address() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if TG_OP = 'UPDATE' and new.customer_id <> old.customer_id then
    raise exception 'ADDRESS_OWNER_IMMUTABLE' using errcode = '42501';
  end if;
  perform 1 from public.customer_profiles where user_id = new.customer_id for update;
  if new.is_default then
    update public.customer_saved_addresses set is_default = false, updated_at = now()
      where customer_id = new.customer_id and id <> new.id and is_default;
  end if;
  new.updated_at := now();
  return new;
end;
$$;
create trigger prepare_customer_saved_address before insert or update on public.customer_saved_addresses
for each row execute function public.prepare_customer_saved_address();
revoke all on function public.prepare_customer_saved_address() from public, anon, authenticated;
commit;
