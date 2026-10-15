-- Additive hardening of confirmed V1/legacy RPC defects. No payment/data rewrites.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';

do $preflight$
declare f record; expected oid:=to_regprocedure('public.get_nearby_providers(double precision,double precision,double precision)');
begin
 if to_regprocedure('private.system_require_session()') is null
    or to_regclass('private.system_account_controls') is null then
   raise exception 'SYSTEM_HARDENING_REQUIRES_V1'; end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='get_nearby_providers' and p.oid is distinct from expected) then
   raise exception 'SYSTEM_NEARBY_UNREVIEWED_OVERLOAD'; end if;
 if expected is not null then
   select * into f from pg_proc where oid=expected;
   -- Exact definition fingerprint observed with the read-only production verifier.
   -- The second fingerprint permits an unchanged rerun of this migration.
   if md5(f.prosrc) not in ('af5414b09f7b0af0a260f5edf3cd8a6d','901af39b7c8a1bd78e94efc0dc037937')
      or pg_get_function_result(expected)<>'TABLE(id uuid, name text, vehicle_plate text, vehicle_type text, phone text, rating numeric, rating_count integer, distance_km double precision)' then
     raise exception 'SYSTEM_NEARBY_UNREVIEWED_DEFINITION'; end if;
 end if;
 if to_regclass('public.providers') is not null then
   if not exists(select 1 from pg_extension e join pg_namespace n on n.oid=e.extnamespace where e.extname='postgis' and n.nspname='public') then
     raise exception 'SYSTEM_NEARBY_POSTGIS_SCHEMA_MISMATCH'; end if;
   if (select count(*) from pg_attribute a where a.attrelid='public.providers'::regclass and not a.attisdropped
       and (a.attname,a.atttypid) in (('id','uuid'::regtype),('user_id','uuid'::regtype),('vehicle_type','text'::regtype),
         ('rating','numeric'::regtype),('rating_count','integer'::regtype),('is_available','boolean'::regtype)))<>6
      or not exists(select 1 from pg_attribute where attrelid='public.providers'::regclass and attname='location'
        and format_type(atttypid,atttypmod)='geography(Point,4326)' and not attisdropped) then
     raise exception 'SYSTEM_NEARBY_PROVIDER_SCHEMA_MISMATCH'; end if;
 end if;
end;
$preflight$;

create or replace function public.customer_request_display_codes(p_request_ids uuid[])
returns table(request_id uuid, quote_code text)
language plpgsql stable security definer set search_path='' as $$
begin
 perform private.system_require_session();
 return query
  select r.id, q.quote_code
  from public.rescue_requests r
  left join public.rescue_request_assignments a on a.request_id=r.id
  left join public.rescue_quotes q on q.id=a.current_quote_id and q.assignment_id=a.id
  where r.customer_id=(select auth.uid()) and r.id=any(p_request_ids)
    and cardinality(p_request_ids)<=100;
end;
$$;
revoke all on function public.customer_request_display_codes(uuid[]) from public,anon,authenticated,service_role;
grant execute on function public.customer_request_display_codes(uuid[]) to authenticated;

create or replace function public.get_nearby_providers(customer_lat double precision,customer_lng double precision,max_distance_km double precision default 10.0)
returns table(id uuid,name text,vehicle_plate text,vehicle_type text,phone text,rating numeric,rating_count integer,distance_km double precision)
language plpgsql stable security definer set search_path='' as $$
begin
 perform private.system_require_session();
 if not exists(select 1 from public.customer_profiles c where c.user_id=auth.uid())
    or exists(select 1 from public.rescuer_profiles r where r.user_id=auth.uid()) then
   raise exception 'SYSTEM_CUSTOMER_REQUIRED' using errcode='42501'; end if;
 if customer_lat is null or not (customer_lat between -90 and 90)
    or customer_lng is null or not (customer_lng between -180 and 180)
    or max_distance_km is null or not (max_distance_km>0 and max_distance_km<=100) then
   raise exception 'SYSTEM_NEARBY_INVALID_COORDINATES' using errcode='22023'; end if;
 -- Clean installations have no legacy provider data; discovery returns an empty set.
 -- No extension or legacy table is manufactured by this migration.
 if to_regclass('public.providers') is null then return; end if;
 -- Preserve the return signature, but withhold names, plates, phone numbers,
 -- account linkage and exact coordinates. The existing client has a name fallback.
 return query select p.id,null::text,null::text,p.vehicle_type,null::text,p.rating,p.rating_count,
   round((public.st_distance(p.location,public.st_setsrid(public.st_makepoint(customer_lng,customer_lat),4326)::public.geography)/1000.0)::numeric,1)::double precision
 from public.providers p
 where p.is_available=true
   and not exists(select 1 from private.system_account_controls c where c.user_id=p.user_id
     and (c.status='locked' or (c.status='suspended' and (c.suspended_until is null or c.suspended_until>statement_timestamp()))))
   and public.st_dwithin(p.location,public.st_setsrid(public.st_makepoint(customer_lng,customer_lat),4326)::public.geography,max_distance_km*1000)
 order by public.st_distance(p.location,public.st_setsrid(public.st_makepoint(customer_lng,customer_lat),4326)::public.geography),p.id;
end;
$$;
revoke all on function public.get_nearby_providers(double precision,double precision,double precision) from public,anon,authenticated,service_role;
grant execute on function public.get_nearby_providers(double precision,double precision,double precision) to authenticated;

-- Confirmed production bypass: a PUBLIC USING(true) policy plus table SELECT
-- exposed the same PII without the RPC. No current application uses direct DML.
do $providers_acl$
declare c record;
begin
 if to_regclass('public.providers') is not null then
   revoke all on table public.providers from public,anon,authenticated;
   for c in select attname from pg_attribute where attrelid='public.providers'::regclass and attnum>0 and not attisdropped loop
     execute format('revoke select(%1$I),insert(%1$I),update(%1$I),references(%1$I) on public.providers from public,anon,authenticated',c.attname);
   end loop;
 end if;
end;
$providers_acl$;
notify pgrst,'reload schema';
commit;
