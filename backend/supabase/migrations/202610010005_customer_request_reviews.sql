begin;
create table public.customer_request_reviews (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references public.rescue_requests(id) on delete cascade,
  customer_id uuid not null references auth.users(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text check (comment is null or length(comment) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index customer_request_reviews_owner_idx on public.customer_request_reviews(customer_id);
alter table public.customer_request_reviews enable row level security;
revoke all on public.customer_request_reviews from public, anon, authenticated;
grant select on public.customer_request_reviews to authenticated;
grant insert (request_id, customer_id, rating, comment) on public.customer_request_reviews to authenticated;
grant update (rating, comment) on public.customer_request_reviews to authenticated;
create policy "customers read own request reviews" on public.customer_request_reviews for select to authenticated
using (customer_id = (select auth.uid()) and exists (
  select 1 from public.rescue_requests r where r.id = request_id and r.customer_id = (select auth.uid())));
create policy "customers review own completed requests" on public.customer_request_reviews for insert to authenticated
with check (customer_id = (select auth.uid()) and exists (
  select 1 from public.rescue_requests r where r.id = request_id and r.customer_id = (select auth.uid()) and r.status = 'completed'));
create policy "customers update own completed request reviews" on public.customer_request_reviews for update to authenticated
using (customer_id = (select auth.uid()))
with check (customer_id = (select auth.uid()) and exists (
  select 1 from public.rescue_requests r where r.id = request_id and r.customer_id = (select auth.uid()) and r.status = 'completed'));
-- No DELETE grant or policy. Neither customer nor request identity is editable.
-- Lock the request while checking its status, including direct REST mutations.
create function public.validate_customer_request_review() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null or new.customer_id <> (select auth.uid()) then
    raise exception 'REVIEW_NOT_OWNED' using errcode = '42501';
  end if;
  if TG_OP = 'UPDATE' and (new.id <> old.id or new.request_id <> old.request_id
      or new.customer_id <> old.customer_id or new.created_at <> old.created_at) then
    raise exception 'REVIEW_IDENTITY_IMMUTABLE' using errcode = '42501';
  end if;
  perform 1 from public.rescue_requests r where r.id = new.request_id
    and r.customer_id = (select auth.uid()) and r.status = 'completed' for share;
  if not found then
    raise exception 'REVIEW_REQUIRES_OWN_COMPLETED_REQUEST' using errcode = '42501';
  end if;
  new.comment := nullif(trim(new.comment), '');
  new.updated_at := now();
  return new;
end;
$$;
create trigger validate_customer_request_review before insert or update on public.customer_request_reviews
for each row execute function public.validate_customer_request_review();
revoke all on function public.validate_customer_request_review() from public, anon, authenticated;

create function public.submit_customer_request_review(p_request_id uuid, p_rating integer, p_comment text default null)
returns public.customer_request_reviews
language plpgsql security invoker set search_path = '' as $$
declare
  caller uuid := (select auth.uid());
  result public.customer_request_reviews;
begin
  if caller is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501'; end if;
  if p_rating is null or p_rating not between 1 and 5 or length(p_comment) > 2000 then
    raise exception 'INVALID_REVIEW' using errcode = '22023';
  end if;
  insert into public.customer_request_reviews(request_id, customer_id, rating, comment)
  values (p_request_id, caller, p_rating, nullif(trim(p_comment), ''))
  on conflict (request_id) do update set rating = excluded.rating, comment = excluded.comment
  returning * into result;
  return result;
end;
$$;
revoke all on function public.submit_customer_request_review(uuid, integer, text) from public, anon, authenticated;
grant execute on function public.submit_customer_request_review(uuid, integer, text) to authenticated;
commit;
