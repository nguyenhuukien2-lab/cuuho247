-- Cứu Hộ 24/7: mẫu kiểm tra bảo mật CHỈ ĐỌC cho Supabase SQL Editor.
-- Chạy trên STAGING với dữ liệu GIẢ; KHÔNG dùng service_role, không chứa key/token.
-- Không phải migration, không tạo/sửa/xóa bảng, policy, dữ liệu hoặc tài khoản.
-- SQL Editor thường chạy vai trò postgres có thể bypass RLS. Các block SET LOCAL ROLE
-- authenticated + giả lập JWT claims chỉ là kiểm tra bổ trợ. Kết luận cuối cùng
-- PHẢI kiểm tra lại qua PostgREST/RPC/Storage/Realtime bằng JWT THẬT của từng user.
--
-- TRƯỚC KHI CHẠY: thay tất cả placeholder USER_ID_HERE_* bằng UUID auth.users.id
-- của fixture staging tương ứng, REQUEST_ID_HERE_B bằng UUID đơn của customer B.
-- USER_ID_HERE_A/B: hai khách; USER_ID_HERE_RESCUER_A/B: hai đối tác;
-- USER_ID_HERE_FINANCE/OPERATOR/SUPPORT/REVIEWER: admin active đúng role;
-- USER_ID_HERE_BLOCKED_ADMIN: admin status=blocked.
-- Dùng Replace All, không đổi tên placeholder thành dữ liệu thật trong Git.
-- Nếu chưa có đủ fixture, CHỈ chạy block đã thay placeholder; đừng kết luận PASS
-- từ 0 hàng khi fixture mục tiêu chưa tồn tại. Mỗi block BEGIN...ROLLBACK độc lập.
-- Nếu lỗi giữa block: chạy ROLLBACK; rồi RESET ROLE; trước khi thử tiếp.
-- Không chạy RPC mutation qua SQL Editor trong file này.

-- 00. Preflight cấu hình/fixture: SQL Editor đặc quyền, KHÔNG chứng minh RLS.
begin;
select 'fixture_customers' as test,
  exists(select 1 from public.customer_profiles where user_id='USER_ID_HERE_A'::uuid) as a_exists,
  exists(select 1 from public.customer_profiles where user_id='USER_ID_HERE_B'::uuid) as b_exists,
  exists(select 1 from public.rescue_requests
    where id='REQUEST_ID_HERE_B'::uuid and customer_id='USER_ID_HERE_B'::uuid) as b_request_exists;
select 'fixture_rescuers' as test,
  exists(select 1 from public.rescuer_profiles where user_id='USER_ID_HERE_RESCUER_A'::uuid) as a_exists,
  exists(select 1 from public.rescuer_profiles where user_id='USER_ID_HERE_RESCUER_B'::uuid) as b_exists;
select role,status,count(*) as fixture_count from public.admin_profiles
where id in ('USER_ID_HERE_FINANCE'::uuid,'USER_ID_HERE_OPERATOR'::uuid,
  'USER_ID_HERE_SUPPORT'::uuid,'USER_ID_HERE_REVIEWER'::uuid,
  'USER_ID_HERE_BLOCKED_ADMIN'::uuid)
group by role,status order by role,status;
select c.relname,c.relrowsecurity,c.relforcerowsecurity
from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in
  ('customer_profiles','customer_vehicles','customer_saved_addresses',
   'rescue_requests','request_status_events','rescue_request_photos',
   'customer_request_reviews','rescuer_profiles','rescuer_documents',
   'admin_profiles','admin_audit_logs') order by c.relname;
select id,public from storage.buckets
where id in ('rescue-request-photos','rescuer-documents') order by id;
select pubname,schemaname,tablename from pg_catalog.pg_publication_tables
where pubname='supabase_realtime' and tablename in
  ('rescue_requests','request_status_events','rescue_request_assignments',
   'rescuer_online_status','rescue_quotes','customer_request_reviews')
order by tablename;
rollback;

-- 01. Customer A: mỗi cột *_b_visible phải FALSE, a_visible phải TRUE.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','USER_ID_HERE_A',true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claims',
  json_build_object('sub','USER_ID_HERE_A','role','authenticated')::text,true);
select auth.uid()='USER_ID_HERE_A'::uuid as identity_ok,
  current_user='authenticated' as role_ok,
  public.is_admin() as is_admin_must_be_false;
select exists(select 1 from public.customer_profiles
    where user_id='USER_ID_HERE_A'::uuid) as profile_a_visible,
  exists(select 1 from public.customer_profiles
    where user_id='USER_ID_HERE_B'::uuid) as profile_b_visible,
  exists(select 1 from public.customer_vehicles
    where customer_id='USER_ID_HERE_B'::uuid) as vehicles_b_visible,
  exists(select 1 from public.customer_saved_addresses
    where customer_id='USER_ID_HERE_B'::uuid) as addresses_b_visible,
  exists(select 1 from public.rescue_requests
    where id='REQUEST_ID_HERE_B'::uuid) as request_b_visible,
  exists(select 1 from public.request_status_events
    where request_id='REQUEST_ID_HERE_B'::uuid) as events_b_visible,
  exists(select 1 from public.rescue_request_photos
    where request_id='REQUEST_ID_HERE_B'::uuid) as photos_b_visible,
  exists(select 1 from public.customer_request_reviews
    where request_id='REQUEST_ID_HERE_B'::uuid) as reviews_b_visible;
select count(*)=0 as admin_customers_hidden from public.admin_customers_view;
select count(*)=0 as admin_requests_hidden from public.admin_rescue_requests_view;
select count(*)=0 as admin_quotes_hidden from public.admin_quotes_view;
-- RPC thống kê chỉ đọc: 42501/ADMIN_FORBIDDEN là kết quả mong đợi.
do $$
declare denied boolean := false;
begin
  begin
    perform public.admin_get_dashboard_stats();
  exception when sqlstate '42501' then denied := true;
  end;
  if not denied then raise exception 'FAIL: customer called admin dashboard RPC'; end if;
end;
$$;
rollback;

-- 02. Rescuer A: hồ sơ/giấy tờ của B phải ẩn. B phải có giấy tờ thật
-- nếu muốn cột documents_b_visible là ca có ý nghĩa.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','USER_ID_HERE_RESCUER_A',true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claims',
  json_build_object('sub','USER_ID_HERE_RESCUER_A','role','authenticated')::text,true);
select auth.uid()='USER_ID_HERE_RESCUER_A'::uuid as identity_ok,
  public.is_admin() as is_admin_must_be_false,
  exists(select 1 from public.rescuer_profiles
    where user_id='USER_ID_HERE_RESCUER_A'::uuid) as own_profile_visible,
  exists(select 1 from public.rescuer_profiles
    where user_id='USER_ID_HERE_RESCUER_B'::uuid) as profile_b_visible,
  exists(select 1 from public.rescuer_documents
    where rescuer_id='USER_ID_HERE_RESCUER_B'::uuid) as documents_b_visible,
  exists(select 1 from public.rescue_requests
    where id='REQUEST_ID_HERE_B'::uuid) as customer_b_full_request_visible;
rollback;

-- 03. Finance: được xem quote/doanh thu; không có view điều phối/reviewer.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','USER_ID_HERE_FINANCE',true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claims',
  json_build_object('sub','USER_ID_HERE_FINANCE','role','authenticated')::text,true);
select public.is_admin() as active_admin_expected_true,
  public.has_admin_role(array['finance']) as finance_expected_true,
  public.has_admin_role(array['partner_reviewer']) as reviewer_expected_false,
  (public.admin_get_dashboard_stats()->>'revenue_visible')::boolean
    as revenue_visible_expected_true;
-- Cần fixture quote thật để "visible_quote_rows > 0" có ý nghĩa.
select count(*) as visible_quote_rows from public.admin_quotes_view;
select count(*)=0 as customers_view_hidden from public.admin_customers_view;
select count(*)=0 as rescuer_view_hidden from public.admin_rescuers_view;
rollback;

-- 04. Operator: điều phối; doanh thu và quote không được hiển thị.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','USER_ID_HERE_OPERATOR',true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claims',
  json_build_object('sub','USER_ID_HERE_OPERATOR','role','authenticated')::text,true);
select public.is_admin() as active_admin_expected_true,
  public.has_admin_role(array['operator']) as operator_expected_true,
  (public.admin_get_dashboard_stats()->>'revenue_visible')::boolean
    as revenue_visible_expected_false,
  (public.admin_get_dashboard_stats()->>'today_revenue')::numeric=0
    as hidden_revenue_is_zero;
select count(*)=0 as quotes_hidden from public.admin_quotes_view;
select count(*)=0 as documents_view_hidden from public.admin_rescuer_documents_view;
rollback;

-- 05. Support: xem khách/đơn; không thấy quote hoặc quyền mutation điều phối.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','USER_ID_HERE_SUPPORT',true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claims',
  json_build_object('sub','USER_ID_HERE_SUPPORT','role','authenticated')::text,true);
select public.is_admin() as active_admin_expected_true,
  public.has_admin_role(array['support']) as support_expected_true,
  public.has_admin_role(array['operator','super_admin']) as cancel_role_expected_false,
  (public.admin_get_dashboard_stats()->>'revenue_visible')::boolean
    as revenue_visible_expected_false;
select count(*)=0 as quotes_hidden from public.admin_quotes_view;
select count(*)=0 as rescuers_view_hidden from public.admin_rescuers_view;
rollback;

-- 06. Partner reviewer: xem đối tác/metadata; không xem quote/đơn điều phối.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','USER_ID_HERE_REVIEWER',true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claims',
  json_build_object('sub','USER_ID_HERE_REVIEWER','role','authenticated')::text,true);
select public.is_admin() as active_admin_expected_true,
  public.has_admin_role(array['partner_reviewer']) as reviewer_expected_true,
  public.has_admin_role(array['operator','super_admin']) as cancel_role_expected_false,
  (public.admin_get_dashboard_stats()->>'revenue_visible')::boolean
    as revenue_visible_expected_false;
select count(*)=0 as quotes_hidden from public.admin_quotes_view;
select count(*)=0 as requests_view_hidden from public.admin_rescue_requests_view;
rollback;

-- 07. Admin blocked: không còn quyền đọc view/RPC thống kê.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','USER_ID_HERE_BLOCKED_ADMIN',true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claims',
  json_build_object('sub','USER_ID_HERE_BLOCKED_ADMIN','role','authenticated')::text,true);
select public.is_admin() as is_admin_expected_false;
select count(*)=0 as profiles_hidden from public.admin_profiles;
select count(*)=0 as admin_requests_hidden from public.admin_rescue_requests_view;
select count(*)=0 as quotes_hidden from public.admin_quotes_view;
do $$
declare denied boolean := false;
begin
  begin
    perform public.admin_get_dashboard_stats();
  exception when sqlstate '42501' then denied := true;
  end;
  if not denied then raise exception 'FAIL: blocked admin called dashboard RPC'; end if;
end;
$$;
rollback;

-- 08. KHÔNG CHẠY: ví dụ RPC mutation có thể đổi trạng thái/log/audit.
-- Chỉ chạy thủ công với fixture STAGING, transaction riêng và hậu kiểm; rollback
-- DB không hoàn tác Storage upload, email/push hoặc dữ liệu đã phát qua Realtime.
-- select public.cancel_own_rescue_request(...);
-- select public.admin_cancel_request(...);
-- select public.admin_block_rescuer(...);
-- select public.admin_approve_rescuer(...);
-- select public.admin_reject_rescuer(...);
-- select public.admin_toggle_service(...);
-- select public.rescuer_claim_request(...);

-- Storage download, signed URL, payload Realtime, RPC discovery và mutation
-- trái quyền phải test qua JWT thật theo SECURITY_MANUAL_TESTS.md.
