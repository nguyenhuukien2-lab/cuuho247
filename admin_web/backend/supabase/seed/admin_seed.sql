-- Run after the Admin migration, using a trusted SQL connection.
-- Create a user in Supabase Auth first, copy auth.users.id, then replace
-- AUTH_USER_ID_HERE below. Never embed a real user ID or password in source.
--
-- insert into public.admin_profiles (id, full_name, role, status, phone)
-- values (
--   'AUTH_USER_ID_HERE'::uuid,
--   'Huu Kien Admin',
--   'super_admin',
--   'active',
--   '0900000000'
-- );
--
-- Bootstrap must have no user JWT (auth.uid() IS NULL), otherwise an existing
-- active super_admin is required. Auth user creation already creates the shared
-- customer profile; it does NOT grant admin access.
-- The profile trigger records bootstrap with source=trusted_sql and NULL actor.
begin;
set local lock_timeout='5s';
-- Existing service state/name is preserved; never reset a production toggle.
insert into public.rescue_services(code,name,is_active,sort_order) values
 ('towing','Cẩu & Kéo Xe Ô Tô',true,40),('battery','Kích Bình Ắc Quy',true,20),
 ('tire','Vá Vỏ & Thay Lốp',true,10),('fuel','Tiếp Nhiên Liệu',true,30),
 ('locksmith','Mở Khóa Ô Tô',false,60),('mechanic','Sửa Chữa Tại Chỗ',false,70)
on conflict(code) do nothing;

-- Idempotent seed: fill missing metadata only. Never overwrite customized price,
-- description, feature flag or UUID. An intentional price change belongs in an
-- audited Admin UPDATE or a separately reviewed migration.
insert into public.admin_service_catalog(service_code,admin_code,description,icon,base_price,price_unit,is_featured) values
 ('towing','SRV-TOW-01','Cẩu kéo xe hỏng, xe tai nạn, xe không thể tự di chuyển.','truck',500000,'ca',true),
 ('battery','SRV-BAT-02','Kích bình, sạc bình 12V/24V lưu động.','battery',200000,'lần',false),
 ('tire','SRV-TYR-03','Vá vỏ, thay lốp sơ cua, hỗ trợ lốp xe khẩn cấp.','disc',250000,'ca',false),
 ('fuel','SRV-FUL-04','Giao xăng/dầu khẩn cấp khi xe hết nhiên liệu.','fuel',180000,'chuyến',false),
 ('locksmith','SRV-LCK-05','Hỗ trợ mở khóa cửa/cốp xe ô tô.','key',300000,'ca',false),
 ('mechanic','SRV-MEC-06','Kiểm tra và xử lý lỗi cơ bản tại hiện trường.','wrench',350000,'ca',false)
on conflict(service_code) do update set
 description=coalesce(public.admin_service_catalog.description,excluded.description),
 icon=coalesce(public.admin_service_catalog.icon,excluded.icon),
 base_price=coalesce(public.admin_service_catalog.base_price,excluded.base_price),
 price_unit=coalesce(public.admin_service_catalog.price_unit,excluded.price_unit)
where public.admin_service_catalog.description is null or public.admin_service_catalog.icon is null
 or public.admin_service_catalog.base_price is null or public.admin_service_catalog.price_unit is null;
insert into public.admin_service_catalog(service_code,admin_code)
select s.code,'LEGACY:'||s.code from public.rescue_services s
where not exists(select 1 from public.admin_service_catalog m where m.service_code=s.code)
on conflict(service_code) do nothing;
commit;
