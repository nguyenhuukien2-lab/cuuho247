// Bank verification + expired-intent regeneration: fresh PostgreSQL WASM RAM only, no URL or network client.
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
const root=process.cwd();
const read=async p=>(await readFile(resolve(root,p),'utf8')).replace(/^\uFEFF/,'');
assert(!process.argv.includes('--gd6b-preflight-workaround'), 'Removed workaround: run the actual migration source.');
const cache=resolve(root,'.cache_rescuer/temp/payment-core-security/node_modules/@electric-sql/pglite/dist');
const {PGlite}=await import(pathToFileURL(resolve(cache,'index.js')));
const {pgcrypto}=await import(pathToFileURL(resolve(cache,'contrib/pgcrypto.js')));
const db=new PGlite({extensions:{pgcrypto}});
const sharedOnly=process.argv.includes('--shared-only');
const migration='backend/supabase/migrations/202610110001_payment_bank_foundation.sql';
const bankTest='backend/supabase/tests/payment_bank_foundation_regression.sql';
const stages=new Map([
 ['202610100001_payment_core_security.sql','payment_core_security_regression.sql'],
 ['202610100002_payment_customer_prepare.sql','payment_customer_prepare_regression.sql'],
 ['202610100003_payment_customer_select_cash.sql','payment_customer_select_cash_regression.sql'],
 ['202610100004_payment_rescuer_cash.sql','payment_rescuer_cash_regression.sql'],
 ['202610100005_payment_realtime.sql','payment_realtime_regression.sql'],
]);
async function suite(path){
 const out=await db.exec(await read(path));
 const result=out.flatMap(x=>x.rows??[]).find(x=>typeof x.result==='string'&&x.result.endsWith('_PASS'));
 assert(result,`no PASS summary: ${path}`);
 console.log('PASS',path,result.assertions,'assertions');
}
async function rejection(sql,pattern){
 let caught=false;
 try{await db.exec(sql);}catch(e){caught=true;assert.match(e.message,pattern);await db.exec('rollback');}
 assert(caught,`expected rejection ${pattern}`);
}
const unchangedQuery=`select
 (select jsonb_agg(to_jsonb(a) order by a.attrelid,a.attnum) from pg_attribute a join pg_class c on c.oid=a.attrelid
   join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and a.attnum>0 and not a.attisdropped) columns,
 (select jsonb_agg(jsonb_build_array(p.oid,pg_get_functiondef(p.oid),p.proacl) order by p.oid)
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.prokind='f'
   and (n.nspname='public' or p.proname in ('payment_core_guard','payment_event_core_guard','payment_receipt_guard'))) functions,
 (select jsonb_agg(to_jsonb(p) order by p.oid) from pg_policy p) policies,
 (select jsonb_agg(jsonb_build_array(c.oid,c.relacl,c.relrowsecurity,c.relreplident) order by c.oid)
   from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public') public_acl,
 (select jsonb_agg(to_jsonb(c) order by c.oid) from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public') constraints,
 (select jsonb_agg(to_jsonb(t) order by t.pubname,t.schemaname,t.tablename) from pg_publication_tables t) publications`;
try{
 await db.exec(`
 create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
 create schema auth; create schema storage;
 create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',created_at timestamptz default now());
 create function auth.uid() returns uuid language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),
 nullif(current_setting('request.jwt.claims',true),'')::jsonb ->> 'sub')::uuid $$;
 create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text,metadata jsonb);
 alter table storage.objects enable row level security;
 grant usage on schema public,auth,storage to anon,authenticated,service_role;
 grant select,insert,update,delete on storage.objects to authenticated;
 set payment.test_mode='local_disposable';`);
 const paths=[];
 for(const dir of ['backend/supabase/migrations']){
  for(const name of await readdir(resolve(root,dir))) {
   if(sharedOnly && ['202610040001_admin_backend_foundation.sql','202610050001_display_codes.sql'].includes(name)) continue;
   if(name.endsWith('.sql')&&name<'202610110001_payment_bank_foundation.sql') paths.push(`${dir}/${name}`);
  }
 }
 paths.sort((a,b)=>a.split('/').at(-1).localeCompare(b.split('/').at(-1)));
 console.log('CONFIG',sharedOnly?'shared-only':'shared+admin/display-codes');
 console.log('ENGINE',(await db.query('select version() v')).rows[0].v);
 for(const path of paths){
  await db.exec(await read(path));
  const stage=stages.get(path.split('/').at(-1));
  if(stage) await suite('backend/supabase/tests/'+stage);
 }
 console.log('PASS existing GD1/GD2A/GD2B/GD3/GD4 unmodified at original migration stages');
 const before=await db.query(unchangedQuery);
 await db.exec(`alter default privileges in schema private grant all on tables to public,anon,authenticated,service_role;
  alter default privileges in schema private grant all on functions to public,anon,authenticated,service_role;`);
 await db.exec('create publication gd6a_unsafe_all for all tables');
 await rejection(await read(migration),/BANK_FOUNDATION_PUBLICATION_UNSAFE/);
 await db.exec('drop publication gd6a_unsafe_all');
 await db.exec('create publication gd6a_unsafe_schema for tables in schema private');
 await rejection(await read(migration),/BANK_FOUNDATION_PUBLICATION_UNSAFE/);
 await db.exec('drop publication gd6a_unsafe_schema');
 console.log('PASS broad and private-schema publication preflight refuses unsafe deployment');
 await db.exec(await read(migration));
 assert.deepEqual(await db.query(unchangedQuery),before);
 console.log('PASS public columns/functions/ACL/policies/constraints/publications and old guards unchanged');
 await suite(bankTest);
 await suite(bankTest);
 await suite('backend/supabase/tests/payment_realtime_regression.sql');
 for(const name of ['payment_bank_intents','payment_webhook_receipts','bank_transactions','payment_bank_audit']){
  assert.equal((await db.query(`select count(*)::int n from private.${name}`)).rows[0].n,0);
 }
 console.log('PASS fixtures and audit rollback; no seeded bank records');
 await rejection(await read(migration),/BANK_FOUNDATION_ALREADY_EXISTS/);
 await db.exec("set payment.test_mode=''");
 await rejection(await read(bankTest),/PAYMENT_TEST_REFUSED/);
 console.log('PASS migration rerun and test without opt-in refused');
 const cashContracts = await db.query(`select oid,pg_get_functiondef(oid) definition,proacl from pg_proc
   where oid in ('public.customer_select_payment_method(uuid,uuid,text,bigint,uuid)'::regprocedure,
     'public.rescuer_confirm_cash_received(uuid,uuid,bigint,bigint,uuid)'::regprocedure,
     'public.customer_get_payment(uuid)'::regprocedure) order by oid`);
 await db.exec(await read('backend/supabase/migrations/202610110002_payment_bank_qr.sql'));
 assert.deepEqual(await db.query(`select oid,pg_get_functiondef(oid) definition,proacl from pg_proc
   where oid in ('public.customer_select_payment_method(uuid,uuid,text,bigint,uuid)'::regprocedure,
     'public.rescuer_confirm_cash_received(uuid,uuid,bigint,bigint,uuid)'::regprocedure,
     'public.customer_get_payment(uuid)'::regprocedure) order by oid`),cashContracts);
 // Independent TLV decoder checks the SQL generator, including boundary amounts.
 function decode(value) {
   const result={}; let pos=0;
   while(pos<value.length) {
     const tag=value.slice(pos,pos+2), size=Number(value.slice(pos+2,pos+4));
     assert.match(tag,/^\d{2}$/); assert(size>0 && pos+4+size<=value.length);
     assert(!(tag in result)); result[tag]=value.slice(pos+4,pos+4+size); pos+=4+size;
   }
   assert.equal(pos,value.length); return result;
 }
 for(const amount of ['1','100000','9999999999999']) {
   const payload=(await db.query(`select private.payment_bank_vietqr('970436','123456789012',$1::bigint,'BK0000000000000000001') value`,[amount])).rows[0].value;
   const root=decode(payload), merchant=decode(root['38']), account=decode(merchant['01']);
   assert.equal(root['00'],'01'); assert.equal(root['01'],'12'); assert.equal(root['54'],amount);
   assert.equal(root['53'],'704'); assert.equal(root['58'],'VN');
   assert.equal(merchant['00'],'A000000727'); assert.equal(merchant['02'],'QRIBFTTA');
   assert.equal(account['00'],'970436'); assert.equal(account['01'],'123456789012');
   assert.equal(decode(root['62'])['08'],'BK0000000000000000001');
   if(amount==='100000') assert.equal(root['63'],'8CBA'); // independently computed CRC-CCITT fixture
 }
 console.log('PASS unchanged cash RPC definitions/ACL and independent QR TLV/CRC vectors');
 await db.exec("set payment.test_mode='local_disposable'");
 await suite('backend/supabase/tests/payment_bank_qr_regression.sql');
 await suite('backend/supabase/tests/payment_bank_qr_regression.sql');
 await suite('backend/supabase/tests/payment_realtime_regression.sql');
 console.log('PASS GD6B QR and post-GD6B cash regression');
 const gd6c='backend/supabase/migrations/202610110003_payment_bank_verification.sql';
 const contracts=await db.query(`select oid,pg_get_functiondef(oid) definition,proacl from pg_proc
   where oid in ('public.customer_get_payment(uuid)'::regprocedure,
   'public.customer_select_bank_transfer(uuid,uuid,bigint,uuid)'::regprocedure,
   'public.customer_select_payment_method(uuid,uuid,text,bigint,uuid)'::regprocedure,
   'public.rescuer_confirm_cash_received(uuid,uuid,bigint,bigint,uuid)'::regprocedure) order by oid`);
 await db.exec(await read(gd6c));
 assert.deepEqual(await db.query(`select oid,pg_get_functiondef(oid) definition,proacl from pg_proc
   where oid in ('public.customer_get_payment(uuid)'::regprocedure,
   'public.customer_select_bank_transfer(uuid,uuid,bigint,uuid)'::regprocedure,
   'public.customer_select_payment_method(uuid,uuid,text,bigint,uuid)'::regprocedure,
   'public.rescuer_confirm_cash_received(uuid,uuid,bigint,bigint,uuid)'::regprocedure) order by oid`),contracts);
 await suite('backend/supabase/tests/payment_bank_verification_regression.sql');
 await suite('backend/supabase/tests/payment_bank_qr_regression.sql');
 await suite('backend/supabase/tests/payment_realtime_regression.sql');
 await rejection(await read(gd6c),/BANK_VERIFICATION_ALREADY_EXISTS/);
 console.log('PASS GD6C, unchanged cash/bank RPC contracts, post-GD6C QR/cash/realtime');
 const regeneration='backend/supabase/migrations/202610130002_customer_bank_intent_regeneration.sql';
 await db.exec(await read(regeneration));
 await suite('backend/supabase/tests/payment_bank_regeneration_regression.sql');
 await suite('backend/supabase/tests/payment_bank_verification_regression.sql');
 await suite('backend/supabase/tests/payment_bank_qr_regression.sql');
 await suite('backend/supabase/tests/payment_realtime_regression.sql');
 await rejection(await read(regeneration),/BANK_REGENERATION_ALREADY_EXISTS/);
 console.log('PASS customer expired bank-intent regeneration and post-regeneration verification/QR/cash/realtime');
 console.log('NOT RUN: live Supabase/Auth/PostgREST, true multi-connection concurrency, provider/signature integration. No deployment or commit.');
}catch(e){console.error('FAIL',e.message,'SQLSTATE',e.code,'CONSTRAINT',e.constraint,'CONTEXT',e.where);process.exitCode=1;}
finally{await db.close();}
