-- Admin Payment read RPCs: the mutation guard takes a row lock (FOR SHARE).
-- STABLE RPCs cannot take that lock. Reuse its role/status predicate without locking.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';

create function private.admin_require_role_readonly(p_roles text[])
returns void language plpgsql stable security definer set search_path='' as $$
declare v_role text; v_status text;
begin
  select a.role,a.status into v_role,v_status from public.admin_profiles a
    where a.id=auth.uid();
  if not found or v_status<>'active' or not coalesce(v_role=any(p_roles),false) then
    raise exception 'ADMIN_FORBIDDEN' using errcode='42501';
  end if;
end;
$$;
revoke all on function private.admin_require_role_readonly(text[]) from public,anon,authenticated;
create or replace function public.admin_get_payment_overview(
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_bucket text default 'day'
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_now timestamptz:=pg_catalog.statement_timestamp();
  v_from timestamptz:=coalesce(p_from,pg_catalog.statement_timestamp()-interval '30 days');
  v_to timestamptz:=coalesce(p_to,pg_catalog.statement_timestamp());
  v_step interval;
  v_summary jsonb;
  v_chart jsonb;
  v_recent jsonb;
begin
  perform private.admin_require_role_readonly(array['super_admin','finance']);
  if not pg_catalog.isfinite(v_from) or not pg_catalog.isfinite(v_to) or v_from>=v_to
     or v_to-v_from>interval '366 days' then
    raise exception 'ADMIN_PAYMENT_INVALID_DATE_RANGE' using errcode='22023';
  end if;
  if p_bucket not in ('day','week','month') then
    raise exception 'ADMIN_PAYMENT_INVALID_BUCKET' using errcode='22023';
  end if;
  v_step:=case p_bucket when 'day' then interval '1 day'
    when 'week' then interval '1 week' else interval '1 month' end;

  with payment_summary as (
    select
      (select pg_catalog.count(*) from public.payments p
        where p.created_at>=v_from and p.created_at<v_to) total_payment_count,
      pg_catalog.count(*) filter(where p.status='paid') paid_count,
      coalesce(pg_catalog.sum(p.amount_received) filter(where p.status='paid'),0) total_paid_amount,
      coalesce(pg_catalog.sum(p.amount_received) filter(where p.status='paid' and p.method='cash'),0) cash_paid_amount,
      coalesce(pg_catalog.sum(p.amount_received) filter(where p.status='paid' and p.method='bank_transfer'),0) bank_paid_amount
    from public.payments p where p.paid_at>=v_from and p.paid_at<v_to
  ), state_summary as (
    select pg_catalog.count(*) filter(where p.status in ('pending','awaiting_payment')) awaiting_count,
      pg_catalog.count(*) filter(where p.status='verifying') verifying_count,
      pg_catalog.count(*) filter(where p.status='failed') failed_count
    from public.payments p where p.created_at>=v_from and p.created_at<v_to
  ), rejected_transactions as (
    select pg_catalog.count(*) n from private.bank_transactions t
    where t.status='rejected' and coalesce(t.occurred_at,t.received_at)>=v_from
      and coalesce(t.occurred_at,t.received_at)<v_to
  ), terminal_intents as (
    select pg_catalog.count(*) n from private.payment_bank_intents i
    left join private.payment_bank_qr_snapshots s on s.intent_id=i.id
    where i.status in ('expired','failed') and i.created_at>=v_from and i.created_at<v_to
      and not exists(select 1 from private.bank_transactions t
        where t.status='rejected' and t.transfer_reference=s.transfer_content)
  ), conflicts as (
    select pg_catalog.count(*) n from private.payment_bank_audit a
    where a.action='conflict' and a.recorded_at>=v_from and a.recorded_at<v_to
  )
  select pg_catalog.jsonb_build_object(
    'total_payment_count',s.total_payment_count,
    'paid_count',s.paid_count,
    'total_paid_amount',s.total_paid_amount::text,
    'cash_paid_amount',s.cash_paid_amount::text,
    'bank_paid_amount',s.bank_paid_amount::text,
    'awaiting_count',q.awaiting_count,
    'verifying_count',q.verifying_count,
    'issue_count',q.failed_count+r.n+i.n+c.n
  ) into v_summary from payment_summary s cross join state_summary q
    cross join rejected_transactions r cross join terminal_intents i cross join conflicts c;

  with bounds as (
    select pg_catalog.date_trunc(p_bucket,v_from at time zone 'Asia/Ho_Chi_Minh') first_bucket,
      pg_catalog.date_trunc(p_bucket,(v_to-interval '1 microsecond') at time zone 'Asia/Ho_Chi_Minh') last_bucket
  ), buckets as (
    select g.bucket from bounds b cross join lateral
      pg_catalog.generate_series(b.first_bucket,b.last_bucket,v_step) g(bucket)
  ), paid as (
    select pg_catalog.date_trunc(p_bucket,p.paid_at at time zone 'Asia/Ho_Chi_Minh') bucket,
      coalesce(pg_catalog.sum(p.amount_received) filter(where p.method='cash'),0) cash_amount,
      coalesce(pg_catalog.sum(p.amount_received) filter(where p.method='bank_transfer'),0) bank_amount,
      coalesce(pg_catalog.sum(p.amount_received),0) paid_amount
    from public.payments p where p.status='paid' and p.paid_at>=v_from and p.paid_at<v_to
    group by 1
  ), awaiting as (
    select pg_catalog.date_trunc(p_bucket,p.created_at at time zone 'Asia/Ho_Chi_Minh') bucket,
      pg_catalog.count(*) awaiting_count
    from public.payments p where p.status in ('pending','awaiting_payment')
      and p.created_at>=v_from and p.created_at<v_to group by 1
  )
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'bucket',pg_catalog.to_char(b.bucket,'YYYY-MM-DD'),
    'cash_amount',coalesce(p.cash_amount,0)::text,
    'bank_amount',coalesce(p.bank_amount,0)::text,
    'paid_amount',coalesce(p.paid_amount,0)::text,
    'awaiting_count',coalesce(a.awaiting_count,0)
  ) order by b.bucket),'[]'::jsonb) into v_chart
  from buckets b left join paid p using(bucket) left join awaiting a using(bucket);

  select coalesce(pg_catalog.jsonb_agg(x.row order by x.created_at desc,x.payment_id desc),'[]'::jsonb)
  into v_recent from (
    select p.created_at,p.id payment_id,pg_catalog.jsonb_build_object(
      'payment_id',p.id,'payment_code',p.payment_code,'request_id',p.request_id,
      'request_code',r.request_code,
      'customer_name',coalesce(nullif(c.full_name,''),r.contact_name),
      'rescuer_name',rp.full_name,'method',p.method,'amount_expected',p.amount_expected::text,
      'amount_received',p.amount_received::text,'status',p.status,'paid_at',p.paid_at,
      'created_at',p.created_at,'updated_at',p.updated_at
    ) row
    from public.payments p join public.rescue_requests r on r.id=p.request_id
    left join public.customer_profiles c on c.user_id=p.customer_id
    left join public.rescuer_profiles rp on rp.user_id=p.rescuer_id
    where p.created_at>=v_from and p.created_at<v_to
    order by p.created_at desc,p.id desc limit 10
  ) x;
  return pg_catalog.jsonb_build_object('summary',v_summary,'chart',v_chart,
    'recent_payments',v_recent,'from',v_from,'to',v_to,'server_time',v_now);
end;
$$;

create or replace function public.admin_list_payments(
  p_search text default null,
  p_method text default null,
  p_status text default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_min_amount numeric default null,
  p_max_amount numeric default null,
  p_limit integer default 50,
  p_cursor jsonb default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_search text:=pg_catalog.lower(pg_catalog.btrim(coalesce(p_search,'')));
  v_limit integer:=least(greatest(coalesce(p_limit,50),1),100);
  v_cursor_at timestamptz;
  v_cursor_id uuid;
  v_rows jsonb;
  v_summary jsonb;
  v_has_more boolean;
  v_next jsonb;
begin
  perform private.admin_require_role_readonly(array['super_admin','finance']);
  if pg_catalog.length(v_search)>128
     or (p_method is not null and p_method not in ('cash','bank_transfer'))
     or (p_status is not null and p_status not in
       ('pending','awaiting_payment','verifying','paid','failed','cancelled','refunded'))
     or (p_from is not null and not pg_catalog.isfinite(p_from))
     or (p_to is not null and not pg_catalog.isfinite(p_to))
     or (p_from is not null and p_to is not null and p_from>=p_to)
     or p_min_amount<0 or p_max_amount<0
     or (p_min_amount is not null and p_max_amount is not null and p_min_amount>p_max_amount) then
    raise exception 'ADMIN_PAYMENT_INVALID_FILTER' using errcode='22023';
  end if;
  if p_cursor is not null then
    if pg_catalog.jsonb_typeof(p_cursor)<>'object'
       or not p_cursor ?& array['created_at','id']
       or exists(select 1 from pg_catalog.jsonb_object_keys(p_cursor) k where k not in ('created_at','id')) then
      raise exception 'ADMIN_PAYMENT_INVALID_CURSOR' using errcode='22023';
    end if;
    begin
      v_cursor_at:=(p_cursor->>'created_at')::timestamptz;
      v_cursor_id:=(p_cursor->>'id')::uuid;
    exception when others then
      raise exception 'ADMIN_PAYMENT_INVALID_CURSOR' using errcode='22023';
    end;
    if not pg_catalog.isfinite(v_cursor_at) then
      raise exception 'ADMIN_PAYMENT_INVALID_CURSOR' using errcode='22023';
    end if;
  end if;

  with filtered as (
    select p.*,r.request_code,
      coalesce(nullif(c.full_name,''),r.contact_name) customer_name,
      rp.full_name rescuer_name
    from public.payments p join public.rescue_requests r on r.id=p.request_id
    left join public.customer_profiles c on c.user_id=p.customer_id
    left join public.rescuer_profiles rp on rp.user_id=p.rescuer_id
    where (v_search='' or pg_catalog.strpos(pg_catalog.lower(pg_catalog.concat_ws(' ',
        p.payment_code,p.id::text,r.request_code,r.id::text,c.full_name,r.contact_name,rp.full_name)),v_search)>0)
      and (p_method is null or p.method=p_method)
      and (p_status is null or p.status=p_status)
      and (p_from is null or p.created_at>=p_from) and (p_to is null or p.created_at<p_to)
      and (p_min_amount is null or p.amount_expected>=p_min_amount)
      and (p_max_amount is null or p.amount_expected<=p_max_amount)
      and (v_cursor_at is null or (p.created_at,p.id)<(v_cursor_at,v_cursor_id))
  ), page as (
    select * from filtered order by created_at desc,id desc limit v_limit+1
  ), kept as (
    select * from page order by created_at desc,id desc limit v_limit
  )
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'payment_id',k.id,'payment_code',k.payment_code,'request_id',k.request_id,
      'request_code',k.request_code,'customer_id',k.customer_id,'customer_name',k.customer_name,
      'rescuer_id',k.rescuer_id,'rescuer_name',k.rescuer_name,'method',k.method,'status',k.status,
      'amount_expected',k.amount_expected::text,'amount_received',k.amount_received::text,
      'created_at',k.created_at,'paid_at',k.paid_at,'updated_at',k.updated_at,'version',k.version::text
    ) order by k.created_at desc,k.id desc),'[]'::jsonb),
    (select pg_catalog.count(*)>v_limit from page),
    (select pg_catalog.jsonb_build_object('created_at',z.created_at,'id',z.id)
      from kept z order by z.created_at,z.id limit 1)
  into v_rows,v_has_more,v_next from kept k;
  if not v_has_more then v_next:=null; end if;

  with filtered as (
    select p.* from public.payments p join public.rescue_requests r on r.id=p.request_id
    left join public.customer_profiles c on c.user_id=p.customer_id
    left join public.rescuer_profiles rp on rp.user_id=p.rescuer_id
    where (v_search='' or pg_catalog.strpos(pg_catalog.lower(pg_catalog.concat_ws(' ',
        p.payment_code,p.id::text,r.request_code,r.id::text,c.full_name,r.contact_name,rp.full_name)),v_search)>0)
      and (p_method is null or p.method=p_method) and (p_status is null or p.status=p_status)
      and (p_from is null or p.created_at>=p_from) and (p_to is null or p.created_at<p_to)
      and (p_min_amount is null or p.amount_expected>=p_min_amount)
      and (p_max_amount is null or p.amount_expected<=p_max_amount)
  )
  select pg_catalog.jsonb_build_object(
    'total_count',pg_catalog.count(*),
    'amount_expected',coalesce(pg_catalog.sum(f.amount_expected),0)::text,
    'amount_received',coalesce(pg_catalog.sum(f.amount_received),0)::text,
    'paid_count',pg_catalog.count(*) filter(where f.status='paid'),
    'review_count',pg_catalog.count(*) filter(where f.status='failed' or exists(
      select 1 from private.payment_bank_intents i
      left join private.payment_bank_qr_snapshots s on s.intent_id=i.id
      where i.payment_id=f.id and (i.status in ('expired','failed') or exists(
        select 1 from private.bank_transactions t where t.status='rejected'
          and t.transfer_reference=s.transfer_content))))
  ) into v_summary from filtered f;
  return pg_catalog.jsonb_build_object('rows',v_rows,'next_cursor',v_next,
    'has_more',v_has_more,'summary',v_summary);
end;
$$;

create or replace function public.admin_get_payment_detail(p_payment_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  p public.payments;
  r public.rescue_requests;
  c public.customer_profiles;
  rp public.rescuer_profiles;
  rv public.rescuer_vehicles;
  i private.payment_bank_intents;
  s private.payment_bank_qr_snapshots;
  t private.bank_transactions;
  v_can_contact boolean;
  v_timeline jsonb;
begin
  perform private.admin_require_role_readonly(array['super_admin','finance']);
  if p_payment_id is null then return null; end if;
  select x.* into p from public.payments x where x.id=p_payment_id;
  if not found then return null; end if;
  select x.* into r from public.rescue_requests x where x.id=p.request_id;
  select x.* into c from public.customer_profiles x where x.user_id=p.customer_id;
  select x.* into rp from public.rescuer_profiles x where x.user_id=p.rescuer_id;
  select x.* into rv from public.rescuer_vehicles x where x.id=(
    select a.vehicle_id from public.rescue_request_assignments a where a.id=p.assignment_id);
  v_can_contact:=public.has_admin_role(array['super_admin','operator','support']);
  if p.method='bank_transfer' then
    select x.* into i from private.payment_bank_intents x where x.payment_id=p.id
      order by x.created_at desc,x.id desc limit 1;
    if found then
      select x.* into s from private.payment_bank_qr_snapshots x where x.intent_id=i.id;
      select x.* into t from private.bank_transactions x
        where x.matched_payment_id=p.id or (s.transfer_content is not null and x.transfer_reference=s.transfer_content)
        order by (x.status='verified') desc,x.received_at desc,x.id desc limit 1;
    end if;
  end if;

  with timeline as (
    select e.id,e.created_at,e.event_type,e.actor_type,
      case when e.actor_type in ('customer','rescuer') then e.actor_id end actor_id,
      case e.event_type
        when 'payment_created' then 'Thanh toán được tạo'
        when 'payment_method_selected' then 'Khách hàng chọn phương thức thanh toán'
        when 'cash_confirmation_started' then 'Bắt đầu xác nhận tiền mặt'
        when 'cash_received' then 'Đối tác xác nhận đã nhận tiền mặt'
        when 'bank_qr_created' then 'Mã chuyển khoản ngân hàng được tạo'
        when 'bank_transfer_detected' then 'Đã ghi nhận giao dịch ngân hàng'
        when 'bank_transfer_verifying' then 'Giao dịch ngân hàng đang được xác minh'
        when 'bank_payment_verified' then 'Chuyển khoản ngân hàng đã được xác minh'
        when 'payment_failed' then 'Thanh toán thất bại'
        when 'payment_cancelled' then 'Thanh toán đã hủy'
        when 'payment_refunded' then 'Thanh toán đã hoàn tiền'
        when 'payment_method_change_rejected' then 'Đổi phương thức thanh toán bị từ chối'
        when 'bank_transfer_conflict' then 'Phát hiện xung đột giao dịch ngân hàng'
        when 'payment_recovery_started' then 'Bắt đầu khôi phục thanh toán'
        else 'Sự kiện thanh toán' end description,
      e.new_status result
    from public.payment_events e where e.payment_id=p.id
    union all
    select a.id,a.recorded_at,'bank_'||a.action,'system',null::uuid,
      case a.action when 'webhook_received' then 'Đã tiếp nhận sự kiện ngân hàng'
        when 'auth_verified' then 'Đã xác thực nguồn giao dịch ngân hàng'
        when 'duplicate' then 'Đã bỏ qua sự kiện ngân hàng trùng lặp'
        when 'conflict' then 'Phát hiện xung đột dữ liệu ngân hàng'
        when 'transaction_normalized' then 'Đã chuẩn hóa giao dịch ngân hàng'
        when 'match_succeeded' then 'Giao dịch ngân hàng khớp thanh toán'
        when 'match_rejected' then 'Giao dịch ngân hàng không khớp'
        when 'payment_transitioned' then 'Thanh toán chuyển sang đã thanh toán'
        else 'Cập nhật xác minh ngân hàng' end,
      coalesce(a.reason_code,a.new_status)
    from private.payment_bank_audit a
    where (i.id is not null and a.intent_id=i.id)
       or (t.id is not null and a.transaction_id=t.id)
  )
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'id',x.id,'timestamp',x.created_at,'event_type',x.event_type,
    'actor_type',x.actor_type,'actor_id',x.actor_id,'description',x.description,'result',x.result
  ) order by x.created_at,x.id),'[]'::jsonb) into v_timeline from timeline x;

  return pg_catalog.jsonb_build_object(
    'payment',pg_catalog.jsonb_build_object(
      'payment_id',p.id,'payment_code',p.payment_code,'request_id',p.request_id,
      'method',p.method,'status',p.status,'amount_expected',p.amount_expected::text,
      'amount_received',p.amount_received::text,'created_at',p.created_at,
      'updated_at',p.updated_at,'paid_at',p.paid_at,'version',p.version::text),
    'request',pg_catalog.jsonb_build_object(
      'request_id',r.id,'request_code',r.request_code,'service_code',r.service_code,
      'service_name',(select rs.name from public.rescue_services rs where rs.code=r.service_code),
      'vehicle_kind',r.vehicle_kind,'vehicle_name',(select cv.display_name from public.customer_vehicles cv where cv.id=r.vehicle_id),
      'vehicle_plate',(select cv.license_plate from public.customer_vehicles cv where cv.id=r.vehicle_id),
      'status',r.status,'final_cost',r.quoted_price::text,
      'completed_at',(select a.completed_at from public.rescue_request_assignments a where a.id=p.assignment_id)),
    'customer',pg_catalog.jsonb_build_object(
      'customer_id',p.customer_id,'customer_code',c.customer_code,
      'display_name',coalesce(nullif(c.full_name,''),r.contact_name),
      'email',case when v_can_contact then (select u.email::text from auth.users u where u.id=p.customer_id) end,
      'phone',case when v_can_contact then coalesce(c.phone,r.contact_phone) end),
    'rescuer',pg_catalog.jsonb_build_object(
      'rescuer_id',p.rescuer_id,'rescuer_code',rp.rescuer_code,'display_name',rp.full_name,
      'vehicle',pg_catalog.concat_ws(' · ',rv.display_name,rv.license_plate),
      'verification_status',rp.verification_status),
    'cash',case when p.method='cash' then pg_catalog.jsonb_build_object(
      'confirmed',p.status='paid' and p.cash_received_by is not null and p.cash_received_at is not null,
      'confirmed_by_rescuer_id',p.cash_received_by,
      'confirmed_by_name',case when p.cash_received_by=p.rescuer_id then rp.full_name end,
      'confirmed_at',p.cash_received_at,
      'amount',case when p.status='paid' then p.amount_received::text end) end,
    'bank',case when p.method='bank_transfer' then pg_catalog.jsonb_build_object(
      'bank_name',s.bank_name,'masked_account_number',case when s.account_number is null then null
        else '•••• '||pg_catalog.right(s.account_number,4) end,
      'account_name',s.account_name,'reference',s.transfer_content,
      'intent_status',case when i.status in ('created','ready') and i.expires_at<=pg_catalog.statement_timestamp()
        then 'expired' else i.status end,
      'expires_at',i.expires_at,'verification_status',coalesce(t.status,i.status),
      'provider',coalesce(t.provider,i.provider)) end,
    'timeline',v_timeline);
end;
$$;

create or replace function public.admin_list_bank_transactions(
  p_search text default null,
  p_provider text default null,
  p_verification_status text default null,
  p_match_result text default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_min_amount numeric default null,
  p_max_amount numeric default null,
  p_limit integer default 50,
  p_cursor jsonb default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_search text:=pg_catalog.lower(pg_catalog.btrim(coalesce(p_search,'')));
  v_limit integer:=least(greatest(coalesce(p_limit,50),1),100);
  v_cursor_at timestamptz;
  v_cursor_id uuid;
  v_rows jsonb;
  v_summary jsonb;
  v_has_more boolean;
  v_next jsonb;
begin
  perform private.admin_require_role_readonly(array['super_admin','finance']);
  if pg_catalog.length(v_search)>128
     or (p_provider is not null and p_provider!~'^[a-z][a-z0-9_]{0,63}$')
     or (p_verification_status is not null and p_verification_status not in ('unverified','matched','verified','rejected'))
     or (p_match_result is not null and p_match_result not in ('pending','matched','matched_exact','unmatched','duplicate','rejected'))
     or (p_from is not null and not pg_catalog.isfinite(p_from))
     or (p_to is not null and not pg_catalog.isfinite(p_to))
     or (p_from is not null and p_to is not null and p_from>=p_to)
     or p_min_amount<0 or p_max_amount<0
     or (p_min_amount is not null and p_max_amount is not null and p_min_amount>p_max_amount) then
    raise exception 'ADMIN_BANK_TRANSACTION_INVALID_FILTER' using errcode='22023';
  end if;
  if p_cursor is not null then
    if pg_catalog.jsonb_typeof(p_cursor)<>'object' or not p_cursor ?& array['received_at','id']
       or exists(select 1 from pg_catalog.jsonb_object_keys(p_cursor) k where k not in ('received_at','id')) then
      raise exception 'ADMIN_BANK_TRANSACTION_INVALID_CURSOR' using errcode='22023';
    end if;
    begin
      v_cursor_at:=(p_cursor->>'received_at')::timestamptz;
      v_cursor_id:=(p_cursor->>'id')::uuid;
    exception when others then
      raise exception 'ADMIN_BANK_TRANSACTION_INVALID_CURSOR' using errcode='22023';
    end;
    if not pg_catalog.isfinite(v_cursor_at) then
      raise exception 'ADMIN_BANK_TRANSACTION_INVALID_CURSOR' using errcode='22023';
    end if;
  end if;

  with source as (
    select t.*,w.event_id provider_event_id,
      coalesce(t.matched_payment_id,i.payment_id) resolved_payment_id,
      p.payment_code,coalesce(p.request_id,i.request_id) resolved_request_id,r.request_code,
      private.admin_payment_match_result(t.status,t.rejection_code) match_result,
      case when t.beneficiary_account_number is null then null
        else '•••• '||pg_catalog.right(t.beneficiary_account_number,4) end beneficiary_masked
    from private.bank_transactions t
    left join private.payment_webhook_receipts w on w.id=t.receipt_id
    left join private.payment_bank_qr_snapshots s on s.transfer_content=t.transfer_reference
    left join private.payment_bank_intents i on i.id=coalesce(t.matched_intent_id,s.intent_id)
    left join public.payments p on p.id=coalesce(t.matched_payment_id,i.payment_id)
    left join public.rescue_requests r on r.id=coalesce(p.request_id,i.request_id)
  ), filtered as (
    select * from source x where
      (v_search='' or pg_catalog.strpos(pg_catalog.lower(pg_catalog.concat_ws(' ',x.provider,
        x.external_transaction_id,x.provider_event_id,x.transfer_reference,x.payment_code,x.request_code)),v_search)>0)
      and (p_provider is null or x.provider=p_provider)
      and (p_verification_status is null or x.status=p_verification_status)
      and (p_match_result is null or x.match_result=p_match_result)
      and (p_from is null or coalesce(x.occurred_at,x.received_at)>=p_from)
      and (p_to is null or coalesce(x.occurred_at,x.received_at)<p_to)
      and (p_min_amount is null or x.amount>=p_min_amount)
      and (p_max_amount is null or x.amount<=p_max_amount)
      and (v_cursor_at is null or (x.received_at,x.id)<(v_cursor_at,v_cursor_id))
  ), page as (
    select * from filtered order by received_at desc,id desc limit v_limit+1
  ), kept as (
    select * from page order by received_at desc,id desc limit v_limit
  )
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'transaction_id',k.id,'provider',k.provider,
      'provider_transaction_id',k.external_transaction_id,'provider_event_id',k.provider_event_id,
      'payment_id',k.resolved_payment_id,'payment_code',k.payment_code,
      'request_id',k.resolved_request_id,'request_code',k.request_code,
      'amount',k.amount::text,'currency',k.currency,'reference',k.transfer_reference,
      'beneficiary_masked',k.beneficiary_masked,'occurred_at',k.occurred_at,
      'received_at',k.received_at,'verification_status',k.status,'match_result',k.match_result,
      'matched_at',case when k.status='verified' then k.updated_at end
    ) order by k.received_at desc,k.id desc),'[]'::jsonb),
    (select pg_catalog.count(*)>v_limit from page),
    (select pg_catalog.jsonb_build_object('received_at',z.received_at,'id',z.id)
      from kept z order by z.received_at,z.id limit 1)
  into v_rows,v_has_more,v_next from kept k;
  if not v_has_more then v_next:=null; end if;

  with source as (
    select t.*,w.event_id provider_event_id,p.payment_code,r.request_code,
      private.admin_payment_match_result(t.status,t.rejection_code) match_result
    from private.bank_transactions t
    left join private.payment_webhook_receipts w on w.id=t.receipt_id
    left join private.payment_bank_qr_snapshots s on s.transfer_content=t.transfer_reference
    left join private.payment_bank_intents i on i.id=coalesce(t.matched_intent_id,s.intent_id)
    left join public.payments p on p.id=coalesce(t.matched_payment_id,i.payment_id)
    left join public.rescue_requests r on r.id=coalesce(p.request_id,i.request_id)
  ), filtered as (
    select * from source x where
      (v_search='' or pg_catalog.strpos(pg_catalog.lower(pg_catalog.concat_ws(' ',x.provider,
        x.external_transaction_id,x.provider_event_id,x.transfer_reference,x.payment_code,x.request_code)),v_search)>0)
      and (p_provider is null or x.provider=p_provider)
      and (p_verification_status is null or x.status=p_verification_status)
      and (p_match_result is null or x.match_result=p_match_result)
      and (p_from is null or coalesce(x.occurred_at,x.received_at)>=p_from)
      and (p_to is null or coalesce(x.occurred_at,x.received_at)<p_to)
      and (p_min_amount is null or x.amount>=p_min_amount)
      and (p_max_amount is null or x.amount<=p_max_amount)
  )
  select pg_catalog.jsonb_build_object(
    'total_count',pg_catalog.count(*),
    'matched_count',pg_catalog.count(*) filter(where f.match_result in ('matched','matched_exact')),
    'unmatched_count',pg_catalog.count(*) filter(where f.match_result='unmatched'),
    'duplicate_count',pg_catalog.count(*) filter(where f.match_result='duplicate'),
    'rejected_count',pg_catalog.count(*) filter(where f.match_result='rejected')
  ) into v_summary from filtered f;
  return pg_catalog.jsonb_build_object('rows',v_rows,'next_cursor',v_next,
    'has_more',v_has_more,'summary',v_summary);
end;
$$;
notify pgrst,'reload schema';
commit;
