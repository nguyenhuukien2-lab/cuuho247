// Run in a disposable copy with: npm install --no-save @electric-sql/pglite
// Run from repository root: node tools/check_photo_policies.mjs
// Real PostgreSQL RLS/PLpgSQL, minimal auth/storage fixtures. This does NOT
// emulate the Storage HTTP server, JWT verification or concurrent connections.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

const db = new PGlite();
const a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const request = '11111111-1111-4111-8111-111111111111';
const photo = n => `22222222-2222-4222-8222-${String(n).padStart(12, '0')}`;
let assertions = 0;
const check = (value, expected) => { assert.deepEqual(value, expected); assertions++; };
async function rejected(sql, params, code) {
  await assert.rejects(db.query(sql, params), error => error.code === code);
  assertions++;
}
async function identity(user, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [user]);
  await db.exec(`set role ${role}`);
}
async function reserve(n, type = 'image/png', size = 20) {
  const result = await db.query('select * from public.reserve_customer_request_photo($1,$2,$3,$4)',
    [request, photo(n), type, size]);
  return result.rows[0];
}
try {
  await db.exec(`
    create role authenticated; create role anon;
    create schema auth; create schema storage;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as
      'select nullif(current_setting(''request.jwt.claim.sub'', true), '''')::uuid';
    create table public.rescue_requests(id uuid primary key, customer_id uuid references auth.users(id));
    alter table public.rescue_requests enable row level security;
    grant usage on schema auth, storage to authenticated, anon;
    grant select on public.rescue_requests to authenticated;
    create policy owner_select on public.rescue_requests for select to authenticated
      using (customer_id = auth.uid());
    create table storage.buckets(id text primary key, name text, public boolean,
      file_size_limit bigint, allowed_mime_types text[]);
    create table storage.objects(id uuid primary key default gen_random_uuid(),
      bucket_id text references storage.buckets(id), name text, metadata jsonb,
      unique(bucket_id, name));
    alter table storage.objects enable row level security;
    grant select, insert, update, delete on storage.objects to authenticated, anon;
    -- Deliberately broad existing policy: migration must still protect its bucket.
    create policy existing_broad_policy on storage.objects for all to authenticated, anon
      using (true) with check (true);
    insert into auth.users values ('${a}'), ('${b}');
    insert into public.rescue_requests values ('${request}', '${a}');
  `);
  await db.exec(await readFile(new URL('../backend/supabase/migrations/202610010002_customer_request_photos.sql', import.meta.url), 'utf8'));
  const bucket = (await db.query('select * from storage.buckets')).rows[0];
  check(bucket.public, false);
  check(Number(bucket.file_size_limit), 5242880);
  check(bucket.allowed_mime_types, ['image/jpeg', 'image/png', 'image/webp']);

  await identity(a);
  const first = await reserve(1);
  check(first.storage_path, `${a}/${request}/${photo(1)}`);
  check(first.slot, 1);
  check((await reserve(1)).id, first.id);
  await rejected('select * from public.reserve_customer_request_photo($1,$2,$3,$4)',
    [request, photo(1), 'image/jpeg', 20], '22023');
  await rejected('select * from public.complete_customer_request_photo($1)', [photo(1)], '22023');
  await rejected('select * from public.reserve_customer_request_photo($1,$2,$3,$4)',
    [request, photo(4), 'text/html', 20], '23514');
  await rejected('select * from public.reserve_customer_request_photo($1,$2,$3,$4)',
    [request, photo(4), 'image/png', 5242881], '23514');
  const insert = 'insert into storage.objects(bucket_id, name, metadata) values ($1,$2,$3)';
  await rejected(insert, ['rescue-request-photos', `${a}/${request}/unreserved`, {}], '42501');
  await db.query(insert, ['rescue-request-photos', first.storage_path, { mimetype: 'image/png', size: 20 }]);
  const completed = (await db.query('select * from public.complete_customer_request_photo($1)', [photo(1)])).rows[0];
  check(completed.uploaded_at !== null, true);
  check((await db.query('select * from public.complete_customer_request_photo($1)', [photo(1)])).rows[0].uploaded_at, completed.uploaded_at);
  check((await db.query('select * from storage.objects')).rows.length, 1);
  check((await db.query('update storage.objects set metadata = $1 returning id', [{}])).rows.length, 0);
  check((await db.query('delete from storage.objects returning id')).rows.length, 0);
  await rejected('update public.rescue_request_photos set uploaded_at = now()', [], '42501');
  await rejected('delete from public.rescue_request_photos', [], '42501');
  const second = await reserve(2);
  await db.query(insert, ['rescue-request-photos', second.storage_path, { mimetype: 'image/png', size: 19 }]);
  await rejected('select * from public.complete_customer_request_photo($1)', [photo(2)], '22023');
  check((await reserve(3)).slot, 3);
  await rejected('select * from public.reserve_customer_request_photo($1,$2,$3,$4)',
    [request, photo(4), 'image/png', 20], '22023');
  check((await db.query('select * from public.rescue_request_photos')).rows.length, 3);

  await identity(b);
  check((await db.query('select * from public.rescue_request_photos')).rows.length, 0);
  check((await db.query('select * from storage.objects')).rows.length, 0);
  await rejected('select * from public.reserve_customer_request_photo($1,$2,$3,$4)',
    [request, photo(4), 'image/png', 20], '42501');
  await rejected('select * from public.complete_customer_request_photo($1)', [photo(1)], '42501');
  await rejected(insert, ['rescue-request-photos', `${a}/${request}/${photo(3)}`, {}], '42501');
  await identity('', 'anon');
  check((await db.query('select * from storage.objects')).rows.length, 0);
  await rejected('select * from public.rescue_request_photos', [], '42501');
  await rejected('select * from public.reserve_customer_request_photo($1,$2,$3,$4)',
    [request, photo(4), 'image/png', 20], '42501');
  await rejected(insert, ['rescue-request-photos', `${a}/${request}/${photo(3)}`, {}], '42501');
  console.log(`PASS: ${assertions} photo migration/RPC/RLS assertions (embedded PostgreSQL).`);
} finally {
  await db.close();
}
