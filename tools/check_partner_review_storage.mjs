// Real local Supabase Storage HTTP/RLS/expiry test. Never accepts a remote URL.
// Applies the reviewed SQL temporarily to the known local stack, then restores
// its prior functions/policies and removes only UUID fixtures created here.
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { createHmac, randomUUID } from 'node:crypto';
import { createClient } from '../admin_web/node_modules/@supabase/supabase-js/dist/index.mjs';

const container = 'supabase_db_backend';
const endpoint = 'http://127.0.0.1:54321';
function sql(query) {
  try {
    return execFileSync('docker', ['exec', '-i', container, 'psql', '-X', '-qAt', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'], {
      input: query, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'],
    }).trim();
  } catch { throw new Error('Local fixture SQL failed (details suppressed to protect credentials).'); }
}
const inspect = JSON.parse(execFileSync('docker', ['inspect', 'supabase_storage_backend'], { encoding: 'utf8' }))[0];
const env = Object.fromEntries(inspect.Config.Env.map((entry) => { const at = entry.indexOf('='); return [entry.slice(0, at), entry.slice(at + 1)]; }));
if (!env.PGRST_JWT_SECRET && !env.JWT_SECRET && !env.AUTH_JWT_SECRET) throw new Error('Local JWT configuration missing');
const secret = env.PGRST_JWT_SECRET || env.JWT_SECRET || env.AUTH_JWT_SECRET;
const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
function token(uid, role = 'authenticated') {
  const now = Math.floor(Date.now() / 1000);
  const raw = encode({ alg: 'HS256', typ: 'JWT' }) + '.' + encode({ sub: uid, role, aal: 'aal2', iat: now, exp: now + 600, iss: 'supabase' });
  return raw + '.' + createHmac('sha256', secret).update(raw).digest('base64url');
}
const anon = env.ANON_KEY || token(undefined, 'anon');
const partner = randomUUID(), reviewer = randomUUID(), outsider = randomUUID(), doc = randomUUID();
const path = `${partner}/${doc}`;
const client = (uid, role) => createClient(endpoint, anon, { auth: { persistSession: false, autoRefreshToken: false }, global: { headers: { Authorization: `Bearer ${token(uid, role)}` } } });
const ownerClient = client(partner), adminClient = client(reviewer), otherClient = client(outsider), service = client(undefined, 'service_role');
let applied = false, fixtures = false, uploaded = false, checks = 0;
function check(value, label) { if (!value) throw new Error(label); checks++; console.log('PASS ' + label); }
if (sql("select to_regprocedure('public.admin_get_rescuer_review(uuid)') is null") !== 't') {
  throw new Error('Refusing to replace an already-installed local review API. Use a clean local stack.');
}
const original = sql("select pg_get_functiondef('private.rescuer_require_vehicle(uuid)'::regprocedure)");
const originalPolicy = sql("select qual from pg_policies where schemaname='storage' and tablename='objects' and policyname='rescuer_document_guard_read'");
try {
  sql(readFileSync(new URL('../backend/supabase/migrations/202610170002_partner_review_readiness.sql', import.meta.url), 'utf8'));
  applied = true;
  sql(`begin;
    insert into auth.users(id,email) values ('${partner}','${partner}@example.invalid'),('${reviewer}','${reviewer}@example.invalid'),('${outsider}','${outsider}@example.invalid');
    insert into public.admin_profiles(id,full_name,role) values('${reviewer}','Local storage reviewer','partner_reviewer');
    insert into public.rescuer_profiles(user_id,full_name,contact_phone) values('${partner}','Local storage partner','0900000001');
    insert into public.rescuer_documents(id,rescuer_id,document_type,storage_path,content_type,byte_size)
      values('${doc}','${partner}','identity','${path}','image/png',68);
    commit;`);
  fixtures = true;
  // Actual bytes and metadata are written through Storage, not fabricated in SQL.
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=', 'base64');
  sql(`update public.rescuer_documents set byte_size=${png.length} where id='${doc}';`);
  const upload = await ownerClient.storage.from('rescuer-documents').upload(path, png, { contentType: 'image/png', cacheControl: '0' });
  check(!upload.error, 'owner uploads private document through Storage');
  uploaded = true;
  const complete = await ownerClient.rpc('rescuer_complete_document', { p_document_id: doc, p_operation_id: randomUUID() });
  check(!complete.error, 'owner completes upload using backend RPC');
  const denied = await otherClient.storage.from('rescuer-documents').createSignedUrl(path, 60);
  check(!!denied.error && !denied.data?.signedUrl, 'other partner cannot sign document');
  const read = await adminClient.rpc('admin_get_rescuer_review', { p_rescuer_id: partner });
  check(!read.error && read.data.documents.length === 1, 'reviewer reads actual document metadata via RPC');
  const sign = await adminClient.storage.from('rescuer-documents').createSignedUrl(path, 60);
  check(!sign.error && !!sign.data?.signedUrl, 'reviewer signs document with 60 second lifetime');
  const signed = sign.data.signedUrl;
  const claims = JSON.parse(Buffer.from(new URL(signed).searchParams.get('token').split('.')[1], 'base64url'));
  check(claims.exp - claims.iat === 60, 'signed token encodes exactly 60 seconds');
  const opened = await fetch(signed, { cache: 'no-store' });
  check(opened.ok && (await opened.arrayBuffer()).byteLength === png.length, 'signed URL serves actual uploaded bytes');
  const publicRead = await fetch(`${endpoint}/storage/v1/object/public/rescuer-documents/${path}`, { cache: 'no-store' });
  check(!publicRead.ok, 'public download stays denied');
  const selfApprove = await ownerClient.rpc('admin_review_rescuer_document', { p_document_id: doc, p_status: 'approved', p_expected_status: 'submitted' });
  check(!!selfApprove.error, 'partner cannot approve through HTTP API');
  const approved = await adminClient.rpc('admin_review_rescuer_document', { p_document_id: doc, p_status: 'approved', p_expected_status: 'submitted' });
  check(!approved.error && approved.data.success, 'reviewer approves through HTTP API');
  console.log('Waiting for real Storage token expiry; signed URL is kept only in memory.');
  while (Date.now() < (claims.exp + 2) * 1000) await new Promise((resolve) => setTimeout(resolve, 1000));
  const expired = await fetch(signed, { cache: 'no-store' });
  check(!expired.ok, 'Storage rejects expired signed URL');
  const renewed = await adminClient.storage.from('rescuer-documents').createSignedUrl(path, 60);
  check(!renewed.error && (await fetch(renewed.data.signedUrl, { cache: 'no-store' })).ok, 'reviewer can request a fresh signed URL');
  console.log(`PASS ${checks} real Storage/API checks`);
} catch (error) {
  // Only our fixed assertion labels are emitted; never HTTP error objects/URLs.
  console.error(error instanceof Error && !/https?:|token=|Bearer/.test(error.message) ? error.message : 'Local Storage test failed');
  process.exitCode = 1;
} finally {
  try {
    if (uploaded) {
      const removed = await service.storage.from('rescuer-documents').remove([path]);
      if (removed.error) throw new Error('Local fixture Storage cleanup failed');
    }
    if (fixtures) sql(`begin;
      delete from public.admin_audit_logs where admin_id='${reviewer}' or target_id='${reviewer}';
      delete from private.rescuer_rpc_receipts where rescuer_id='${partner}';
      delete from public.rescuer_documents where id='${doc}';
      delete from public.rescuer_profiles where user_id='${partner}';
      delete from public.admin_profiles where id='${reviewer}';
      delete from auth.users where id in ('${partner}','${reviewer}','${outsider}'); commit;`);
  } finally {
    if (applied) sql(`begin;
      drop policy admin_rescuer_document_object_read on storage.objects;
      alter policy rescuer_document_guard_read on storage.objects using (${originalPolicy});
      ${original};
      drop function public.admin_can_read_rescuer_document(text), public.admin_review_rescuer_document(uuid,text,text,text),
        public.admin_review_rescuer_vehicle(uuid,text,bigint,text),public.admin_review_rescuer_capability(uuid,text,text,text,timestamptz,text),
        public.admin_get_rescuer_review(uuid), public.rescuer_get_readiness(),private.admin_lock_rescuer_review(uuid,text,text),
        private.rescuer_review_readiness(uuid);
      notify pgrst,'reload schema'; commit;`);
    console.log('Local schema restored; no remote project was modified.');
  }
}
