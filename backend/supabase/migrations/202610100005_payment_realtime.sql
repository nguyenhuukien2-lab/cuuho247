-- GD4: publish only the existing participant-safe payment row. No ACL/RLS changes.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
do $publication$
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('payment-realtime-migration',0));
  if to_regclass('public.payments') is null
     or to_regprocedure('public.customer_get_payment(uuid)') is null
     or to_regprocedure('public.rescuer_get_job_payment(uuid)') is null then
    raise exception 'PAYMENT_REALTIME_MISSING_PREREQUISITES';
  end if;
  if not (select relrowsecurity from pg_catalog.pg_class where oid='public.payments'::regclass)
     or not pg_catalog.has_table_privilege('authenticated','public.payments','SELECT')
     or pg_catalog.has_table_privilege('authenticated','public.payments','INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
     or pg_catalog.has_table_privilege('anon','public.payments','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
     or pg_catalog.has_table_privilege('authenticated','public.payment_events','SELECT,INSERT,UPDATE,DELETE')
     or (select count(*) from pg_catalog.pg_policies where schemaname='public' and tablename='payments'
       and cmd='SELECT' and roles=array['authenticated']::name[])<>2
     or (select count(*) from pg_catalog.pg_policy where polrelid='public.payments'::regclass)<>2 then
    raise exception 'PAYMENT_REALTIME_SECURITY_DRIFT';
  end if;
  -- Fail closed if a future migration adds raw banking/internal data. Review
  -- the entire participant row before extending this explicit safe inventory.
  if exists(select 1 from pg_catalog.pg_attribute where attrelid='public.payments'::regclass
     and attnum>0 and not attisdropped and attname<>all(array[
       'id','payment_code','request_id','assignment_id','customer_id','rescuer_id','quote_id',
       'amount_expected','amount_received','currency','method','status','version',
       'cash_received_by','cash_received_at','paid_at','verified_at','failed_at','cancelled_at','refunded_at',
       'failure_code','cancellation_reason_code','created_at','updated_at'])) then
    raise exception 'PAYMENT_REALTIME_ROW_REQUIRES_SECURITY_REVIEW';
  end if;
  if exists(select 1 from pg_catalog.pg_publication where pubname='supabase_realtime' and puballtables)
     or exists(select 1 from pg_catalog.pg_publication_tables where pubname='supabase_realtime'
       and (schemaname='private' or (schemaname='public' and tablename='payment_events'))) then
    raise exception 'PAYMENT_REALTIME_PUBLICATION_REQUIRES_SECURITY_REVIEW';
  end if;
  if not exists(select 1 from pg_catalog.pg_publication where pubname='supabase_realtime') then
    create publication supabase_realtime;
  end if;
  if not exists(select 1 from pg_catalog.pg_publication_tables where pubname='supabase_realtime'
      and schemaname='public' and tablename='payments') then
    alter publication supabase_realtime add table public.payments;
  end if;
end;
$publication$;
commit;
