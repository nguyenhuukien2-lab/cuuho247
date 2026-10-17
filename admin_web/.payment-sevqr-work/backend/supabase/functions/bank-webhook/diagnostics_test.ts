import { test } from 'node:test';
import assert from 'node:assert/strict';
import { logDiagnostic, observeTransaction } from './diagnostics.ts';

function databaseError(code: string) {
  return Object.assign(new Error('postgres://user:password@host/db account=0123456789'), {
    name: 'PostgresError', code, detail: 'sensitive payload',
    query: 'select sensitive_data', parameters: ['secret'],
  });
}

test('diagnostics serialize only approved metadata, never error details', t => {
  const records: string[] = [];
  t.mock.method(console, 'error', (value: string) => records.push(value));
  const error = databaseError('42501');
  Object.defineProperty(error, 'toJSON', { value: () => { throw new Error('must not serialize'); } });
  logDiagnostic('BANK_WEBHOOK_DB_PROCESSOR_FAILED', 'processor_call', error);
  assert.deepEqual(JSON.parse(records[0]), {
    category: 'BANK_WEBHOOK_DB_PROCESSOR_FAILED', provider: 'sepay',
    stage: 'processor_call', errorName: 'PostgresError', sqlState: '42501',
  });
});

test('unapproved names/codes and throwing getters cannot leak or break logging', t => {
  const records: string[] = [];
  t.mock.method(console, 'error', (value: string) => records.push(value));
  logDiagnostic('BANK_WEBHOOK_INTERNAL_ERROR', 'startup', {
    name: 'password', code: 'postgres://secret', stack: 'account number',
  });
  logDiagnostic('BANK_WEBHOOK_INTERNAL_ERROR', 'startup', {
    get name() { throw new Error('secret'); },
    get code() { throw new Error('secret'); },
  });
  for (const record of records) assert.deepEqual(JSON.parse(record), {
    category: 'BANK_WEBHOOK_INTERNAL_ERROR', provider: 'sepay', stage: 'startup',
  });
});

for (const code of ['ECONNREFUSED', 'EPIPE', '28P01', '08006', '42501']) {
  test(`pre-callback failure ${code} distinguishes connect from BEGIN`, async t => {
    const records: string[] = [];
    t.mock.method(console, 'error', (value: string) => records.push(value));
    const error = databaseError(code);
    let called = false;
    await assert.rejects(observeTransaction(
      async () => { throw error; },
      async () => { called = true; },
    ), value => value === error);
    assert.equal(called, false);
    const record = JSON.parse(records[0]);
    assert.equal(record.category, code === '42501'
      ? 'BANK_WEBHOOK_DB_PROCESSOR_FAILED' : 'BANK_WEBHOOK_DB_CONNECT_FAILED');
    assert.equal(record.stage, code === '42501' ? 'begin_transaction' : 'connect');
    assert.equal(record.sqlState ?? record.errorCode, code);
    if (code === 'EPIPE') assert.equal(record.sqlState, undefined);
  });
}

for (const stage of ['statement_timeout', 'processor_call', 'auth_audit_call', 'processor_result'] as const) {
  test(`${stage} failure preserves original error after successful rollback`, async t => {
    const records: string[] = [];
    t.mock.method(console, 'error', (value: string) => records.push(value));
    const error = databaseError('P0001');
    let rolledBack = false;
    await assert.rejects(observeTransaction<undefined, void>(
      async work => {
        try { return await work(undefined); }
        catch (caught) { rolledBack = true; throw caught; }
      },
      async (_connection, setStage) => { setStage(stage); throw error; },
    ), value => value === error);
    assert.equal(rolledBack, true);
    assert.equal(records.length, 1);
    assert.equal(JSON.parse(records[0]).stage, stage);
  });
}

test('commit failure is distinct from processor failure', async t => {
  const records: string[] = [];
  t.mock.method(console, 'error', (value: string) => records.push(value));
  const error = databaseError('40001');
  await assert.rejects(observeTransaction<undefined, number>(
    async work => { await work(undefined); throw error; },
    async (_connection, setStage) => { setStage('processor_call'); return 42; },
  ), value => value === error);
  assert.equal(records.length, 1);
  assert.equal(JSON.parse(records[0]).stage, 'commit');
});

test('rollback failure logs both failure boundaries and preserves client error', async t => {
  const records: string[] = [];
  t.mock.method(console, 'error', (value: string) => records.push(value));
  const processorError = databaseError('42501');
  const rollbackError = databaseError('08006');
  await assert.rejects(observeTransaction<undefined, void>(
    async work => {
      try { await work(undefined); }
      catch { throw rollbackError; }
    },
    async (_connection, setStage) => { setStage('processor_call'); throw processorError; },
  ), value => value === rollbackError);
  assert.deepEqual(records.map(record => JSON.parse(record).stage), ['processor_call', 'rollback']);
});

test('successful transaction result unchanged and no success log emitted', async t => {
  const records: string[] = [];
  t.mock.method(console, 'error', (value: string) => records.push(value));
  const result = { result: 'paid', changed: true };
  assert.equal(await observeTransaction(
    async work => await work(undefined), async () => result,
  ), result);
  assert.deepEqual(records, []);
});

test('console failure never replaces the original database error', async t => {
  t.mock.method(console, 'error', () => { throw new Error('logging unavailable'); });
  const error = databaseError('42501');
  await assert.rejects(observeTransaction(
    async () => { throw error; }, async () => undefined,
  ), value => value === error);
});

test('22023 exact allowlisted processor message maps to a constant reason only', t => {
  const records: string[] = [];
  t.mock.method(console, 'error', (value: string) => records.push(value));
  logDiagnostic('BANK_WEBHOOK_DB_PROCESSOR_FAILED', 'processor_call', Object.assign(
    databaseError('22023'), { message: 'BANK_NORMALIZED_INPUT_INVALID' },
  ));
  assert.deepEqual(JSON.parse(records[0]), {
    category: 'BANK_WEBHOOK_DB_PROCESSOR_FAILED', provider: 'sepay',
    stage: 'processor_call', errorName: 'PostgresError', sqlState: '22023',
    processorReasonCode: 'BANK_NORMALIZED_INPUT_INVALID',
  });
});

test('processor reason never copies message fragments, values, or unknown errors', t => {
  const records: string[] = [];
  t.mock.method(console, 'error', (value: string) => records.push(value));
  for (const message of [
    'BANK_NORMALIZED_INPUT_INVALID postgres://user:password@host/db',
    'account=0000000001', 'unknown SQL text',
  ]) {
    logDiagnostic('BANK_WEBHOOK_DB_PROCESSOR_FAILED', 'processor_call', Object.assign(
      databaseError('22023'), { message },
    ));
  }
  for (const record of records) assert.deepEqual(JSON.parse(record), {
    category: 'BANK_WEBHOOK_DB_PROCESSOR_FAILED', provider: 'sepay',
    stage: 'processor_call', errorName: 'PostgresError', sqlState: '22023',
  });
});
