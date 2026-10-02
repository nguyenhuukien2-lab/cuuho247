-- Apply after customer_tracking. Storage is private; clients use their own JWT.
begin;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('rescue-request-photos', 'rescue-request-photos', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table public.rescue_request_photos (
  id uuid primary key,
  request_id uuid not null references public.rescue_requests(id) on delete cascade,
  customer_id uuid not null references auth.users(id) on delete cascade,
  slot smallint not null check (slot between 1 and 3),
  storage_path text not null unique,
  content_type text not null check (content_type in ('image/jpeg', 'image/png', 'image/webp')),
  byte_size integer not null check (byte_size between 1 and 5242880),
  created_at timestamptz not null default now(),
  uploaded_at timestamptz,
  unique (request_id, slot),
  check (storage_path = customer_id::text || '/' || request_id::text || '/' || id::text)
);
alter table public.rescue_request_photos enable row level security;
revoke all on public.rescue_request_photos from public, anon, authenticated;
grant select on public.rescue_request_photos to authenticated;
create policy "customers read own request photos"
  on public.rescue_request_photos for select to authenticated
  using (customer_id = (select auth.uid()) and exists (
    select 1 from public.rescue_requests r
    where r.id = request_id and r.customer_id = (select auth.uid())
  ));

-- Reserve an immutable slot before uploading. Locking the parent serializes
-- concurrent reservations; the unique constraint also enforces the 3-photo cap.
create function public.reserve_customer_request_photo(
  p_request_id uuid, p_photo_id uuid, p_content_type text, p_byte_size integer
) returns public.rescue_request_photos
language plpgsql security definer set search_path = '' as $$
declare
  caller uuid := (select auth.uid());
  photo public.rescue_request_photos;
  free_slot smallint;
begin
  if caller is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  perform 1 from public.rescue_requests r
    where r.id = p_request_id and r.customer_id = caller for update;
  if not found then
    raise exception 'REQUEST_NOT_OWNED' using errcode = '42501';
  end if;
  select * into photo from public.rescue_request_photos
    where id = p_photo_id and request_id = p_request_id and customer_id = caller;
  if found then
    if photo.content_type is distinct from p_content_type or photo.byte_size is distinct from p_byte_size then
      raise exception 'PHOTO_RETRY_MISMATCH' using errcode = '22023';
    end if;
    return photo;
  end if;
  select n::smallint into free_slot from generate_series(1, 3) n
    where not exists (select 1 from public.rescue_request_photos p
      where p.request_id = p_request_id and p.slot = n) order by n limit 1;
  if free_slot is null then
    raise exception 'PHOTO_LIMIT_REACHED' using errcode = '22023';
  end if;
  insert into public.rescue_request_photos
    (id, request_id, customer_id, slot, storage_path, content_type, byte_size)
  values (p_photo_id, p_request_id, caller, free_slot,
    caller::text || '/' || p_request_id::text || '/' || p_photo_id::text,
    p_content_type, p_byte_size) returning * into photo;
  return photo;
end;
$$;

-- Only link a photo as uploaded after Storage confirms its object exists.
create function public.complete_customer_request_photo(p_photo_id uuid)
returns public.rescue_request_photos
language plpgsql security definer set search_path = '' as $$
declare
  photo public.rescue_request_photos;
begin
  select p.* into photo from public.rescue_request_photos p
    join public.rescue_requests r on r.id = p.request_id
    where p.id = p_photo_id and p.customer_id = (select auth.uid())
      and r.customer_id = (select auth.uid()) for update of p;
  if not found then
    raise exception 'PHOTO_NOT_OWNED' using errcode = '42501';
  end if;
  if photo.uploaded_at is not null then return photo; end if;
  if not exists (select 1 from storage.objects o
    where o.bucket_id = 'rescue-request-photos' and o.name = photo.storage_path
      and o.metadata->>'mimetype' = photo.content_type
      and (o.metadata->>'size')::bigint = photo.byte_size) then
    raise exception 'PHOTO_OBJECT_NOT_READY' using errcode = '22023';
  end if;
  update public.rescue_request_photos set uploaded_at = clock_timestamp()
    where id = photo.id returning * into photo;
  return photo;
end;
$$;
revoke all on function public.reserve_customer_request_photo(uuid, uuid, text, integer) from public, anon;
revoke all on function public.complete_customer_request_photo(uuid) from public, anon;
grant execute on function public.reserve_customer_request_photo(uuid, uuid, text, integer) to authenticated;
grant execute on function public.complete_customer_request_photo(uuid) to authenticated;

create policy "customers upload reserved request photos"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'rescue-request-photos' and exists (
    select 1 from public.rescue_request_photos p
    join public.rescue_requests r on r.id = p.request_id
    where p.storage_path = name and p.customer_id = (select auth.uid())
      and r.customer_id = (select auth.uid()) and p.uploaded_at is null
  ));
create policy "customers view own request photo objects"
  on storage.objects for select to authenticated
  using (bucket_id = 'rescue-request-photos' and exists (
    select 1 from public.rescue_request_photos p
    join public.rescue_requests r on r.id = p.request_id
    where p.storage_path = name and p.customer_id = (select auth.uid())
      and r.customer_id = (select auth.uid())
  ));
-- No client UPDATE/DELETE: objects and completed attachments are immutable.
-- Guard this bucket even if an existing permissive Storage policy is broad.
create policy "request photos require reserved owner on insert"
  on storage.objects as restrictive for insert to authenticated
  with check (bucket_id <> 'rescue-request-photos' or exists (
    select 1 from public.rescue_request_photos p
    join public.rescue_requests r on r.id = p.request_id
    where p.storage_path = name and p.customer_id = (select auth.uid())
      and r.customer_id = (select auth.uid()) and p.uploaded_at is null
  ));
create policy "request photos require owner on read"
  on storage.objects as restrictive for select to authenticated
  using (bucket_id <> 'rescue-request-photos' or exists (
    select 1 from public.rescue_request_photos p
    join public.rescue_requests r on r.id = p.request_id
    where p.storage_path = name and p.customer_id = (select auth.uid())
      and r.customer_id = (select auth.uid())
  ));
create policy "request photos cannot be overwritten"
  on storage.objects as restrictive for update to authenticated
  using (bucket_id <> 'rescue-request-photos')
  with check (bucket_id <> 'rescue-request-photos');
create policy "request photos cannot be deleted by customers"
  on storage.objects as restrictive for delete to authenticated
  using (bucket_id <> 'rescue-request-photos');
create policy "request photos reject anonymous access"
  on storage.objects as restrictive for all to anon
  using (bucket_id <> 'rescue-request-photos')
  with check (bucket_id <> 'rescue-request-photos');

notify pgrst, 'reload schema';
commit;
