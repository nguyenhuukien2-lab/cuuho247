-- DEVELOPMENT ONLY: run in the dev project's SQL Editor as postgres.
-- Replace the exact request UUID below, then run once per UI observation.
-- searching -> accepted -> arriving -> in_progress -> completed.
-- No RPC or permission is added to customer accounts.
begin;
do $$
declare
  target_id uuid := 'REPLACE_WITH_DEV_REQUEST_UUID';
  current_status text;
  next_status text;
begin
  select status into current_status from public.rescue_requests
    where id = target_id for update;
  if not found then raise exception 'DEV_REQUEST_NOT_FOUND'; end if;
  next_status := case current_status
    when 'searching' then 'accepted'
    when 'accepted' then 'arriving'
    when 'arriving' then 'in_progress'
    when 'in_progress' then 'completed'
  end;
  if next_status is null then raise exception 'DEV_REQUEST_ALREADY_TERMINAL'; end if;
  update public.rescue_requests set status = next_status where id = target_id;
  raise notice 'Development request moved from % to %', current_status, next_status;
end;
$$;
commit;
