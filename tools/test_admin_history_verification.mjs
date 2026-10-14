// Read-only verifier tests: change expectations IN MEMORY, never alter any DB.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';

const sql = await readFile('backend/supabase/tests/verify_admin_history_readonly.sql', 'utf8');
const manifestPattern = /\$manifest\$([\s\S]*?)\$manifest\$::jsonb/;
const baseline = JSON.parse(sql.match(manifestPattern)[1]);
function execute(source) {
  const r = spawnSync('docker', ['exec', '-i', 'supabase_db_backend', 'psql', '-X', '-q', '-A', '-t',
    '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres', '-f', '-'],
  { input: source, encoding: 'utf8', windowsHide: true, maxBuffer: 1024 * 1024 });
  assert.equal(r.status, 0, r.stderr);
  return r.stdout.split('\n').filter(line => line.startsWith('OVERALL|'))[0].split('|');
}
const success = execute(sql);
assert.equal(success[3], 'PASS');
assert.equal(JSON.parse(success[5]).checks, 114);
assert.equal(JSON.parse(success[5]).history_repair_commands.length, 2);
console.log('PASS clean local catalog: 114 checks, two conditional repair commands');

const scenarios = [
  ['column nullability','columns:public.admin_profiles',x => { x.actual.find(c => c.name === 'role').not_null = false; }],
  ['PK definition','constraints:public.admin_profiles',x => { x.actual.find(c => c.type === 'p').definition = 'PRIMARY KEY (full_name)'; }],
  ['unique index','indexes:public.admin_profiles',x => { x.actual[0].unique = false; }],
  ['RLS expression','policies:public.admin_profiles',x => { x.actual[0].check = 'true'; }],
  ['disabled trigger','triggers:public.admin_profiles',x => { x.actual[0].enabled = 'D'; }],
  ['authorization function body','function:private.admin_require_role',x => { x.actual[0].body_sha256 = '0'.repeat(64); }],
  ['function execute privilege','function:public.customer_request_display_codes',x => { x.actual[0].anon_execute = true; }],
  ['BIGINT sequence precision','sequence:public.admin_code_seq',x => { x.actual.max = '9223372036854776000'; }],
  ['wrong display trigger function schema','display_trigger:public.customer_profiles',x => { x.actual.definition = x.actual.definition.replace('private.assign_display_code','public.assign_display_code'); }],
];
for (const [label, object, mutate] of scenarios) {
  const manifest = structuredClone(baseline);
  mutate(manifest.find(x => x.object === object));
  const altered = sql.replace(manifestPattern, () => '$manifest$' + JSON.stringify(manifest) + '$manifest$::jsonb');
  const result = execute(altered);
  assert.equal(result[3], 'FAIL', label);
  assert.equal(JSON.parse(result[5]).history_repair_commands.length, 0, label);
  console.log('PASS fail-closed: ' + label);
}
console.log('PASS 10 read-only verifier scenarios; no database objects/data were changed');
