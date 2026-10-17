-- Production-safe audit: SELECT only in a read-only transaction. No document paths/tokens.
begin read only;
with relations as (select n.nspname, c.relname, c.relkind, c.relrowsecurity
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','private') and c.relname ~ '(rescuer|verification|readiness)'
order by 1,2), functions as (select n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as arguments,
  pg_get_functiondef(p.oid) as definition
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','private') and
 (p.proname ~ '(readiness|approve.*(rescuer|document|vehicle)|review.*(document|vehicle|capability))'
  or p.proname in ('rescuer_require_vehicle','rescuer_require_profile','rescuer_set_online',
   'rescuer_discovery_context','rescuer_available_rows','admin_change_rescuer','system_domain_guard','system_session_allowed')) order by 1,2), policies as (
select schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check
from pg_policies where tablename in ('rescuer_profiles','rescuer_documents','rescuer_vehicles',
 'rescuer_service_capabilities') or (schemaname='storage' and tablename='objects') order by 1,2,3), buckets as (
select id,public,file_size_limit,allowed_mime_types from storage.buckets where id='rescuer-documents'), partners as (
select p.rescuer_code,p.full_name,p.verification_status,
 (select c.status from private.system_account_controls c where c.user_id=p.user_id) as account_control_status,
 (select jsonb_agg(jsonb_build_object('type',d.document_type,'status',d.verification_status,
   'uploaded',d.uploaded_at is not null,'expired',d.expires_at<=now())) from public.rescuer_documents d where d.rescuer_id=p.user_id) as documents,
 (select jsonb_agg(jsonb_build_object('kind',v.kind,'status',v.verification_status,'active',v.is_active))
   from public.rescuer_vehicles v where v.rescuer_id=p.user_id) as vehicles,
 (select jsonb_agg(jsonb_build_object('service',c.service_code,'status',c.verification_status,'enabled',c.is_enabled))
   from public.rescuer_service_capabilities c where c.rescuer_id=p.user_id) as capabilities
from public.rescuer_profiles p where p.full_name ilike '%Nguyễn Hữu A%')
select jsonb_build_object('relations',(select jsonb_agg(r) from relations r),
 'functions',(select jsonb_agg(f) from functions f),'policies',(select jsonb_agg(p) from policies p),
 'buckets',(select jsonb_agg(b) from buckets b),'partners',(select jsonb_agg(p) from partners p),
 'function_inventory',(select jsonb_agg(n.nspname||'.'||p.proname order by n.nspname,p.proname)
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname in ('public','private') and p.proname ~ '(rescuer|document|vehicle|capability|readiness|verification)'),
 'operation_flags',(select jsonb_object_agg(key,value) from private.system_config,
   lateral jsonb_each(values) where key in ('rescuer.maintenance','rescuer.online_enabled','security.kill_new_jobs'))) as audit;
rollback;
