import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handleBankWebhook } from './handler.ts';
import { installedAdapter } from './adapter.ts';
import { rawBodySha256, validateNormalizedTransaction } from './normalized.ts';

// Internal synthetic observation, not a provider webhook fixture.
const observation = {
  provider: 'test_only', provider_scope: 'disposable', provider_transaction_id: 't1',
  amount: '9007199254740993', currency: 'VND', direction: 'credit',
  transfer_reference: 'BK0000000000000000001', occurred_at: '2026-10-11T01:02:03Z',
  authentication_verified: true, signature_verified: false, authentication_method: 'token',
  raw_payload_sha256: 'a'.repeat(64),
};
test('lossless normalized amount and unchanged reference; immutable snapshot', () => {
  const n = validateNormalizedTransaction(observation);
  assert.equal(n.amount, '9007199254740993');
  assert.equal(n.transfer_reference, observation.transfer_reference);
  assert.equal(n.signature_verified, false); // token authentication is not a signature
  assert(Object.isFrozen(n));
});
for (const [key, bad] of [
  ['amount', 100000], ['amount', '0'], ['amount', '-1'], ['amount', '1.5'], ['amount', '1e3'],
  ['amount', '01'], ['amount', '9223372036854775808'], ['currency', 'vnd'],
  ['authentication_verified', false], ['authentication_verified', 'true'],
  ['signature_verified', null], ['authentication_method', 'signature'],
  ['provider_transaction_id', ''], ['provider_event_id', ''],
  ['occurred_at', '2026-02-30T01:02:03Z'], ['occurred_at', '2026-10-11'],
  ['occurred_at', '2026-10-11T24:00:00Z'], ['occurred_at', 'infinity'],
  ['occurred_at', '2026-10-11T01:02:03+15:00'], ['raw_payload_sha256', 'not-a-hash'],
  ['received_at', '2026-10-11T01:02:03Z'], ['raw_payload', { secret: 'not-retained' }],
] as const) test(`reject ${key}: ${JSON.stringify(bad)}`, () => {
  assert.throws(() => validateNormalizedTransaction({ ...observation, [key]: bad }), /BANK_NORMALIZED_INPUT_INVALID/);
});
test('missing authentication and transaction identity rejected', () => {
  const { authentication_verified: _, ...missingAuth } = observation;
  assert.throws(() => validateNormalizedTransaction(missingAuth));
  const { provider_transaction_id: __, ...missingId } = observation;
  assert.throws(() => validateNormalizedTransaction(missingId));
});
test('reference not trimmed, folded, or extracted by normalization', () => {
  for (const transfer_reference of [null, 'wrong', 'BK0000000000000000002', ' BK0000000000000000001', 'bk0000000000000000001']) {
    assert.equal(validateNormalizedTransaction({ ...observation, transfer_reference }).transfer_reference, transfer_reference);
  }
});
test('exact byte SHA256 vector and modified body integrity', async () => {
  assert.equal(await rawBodySha256(new TextEncoder().encode('abc')), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  assert.notEqual(await rawBodySha256(new TextEncoder().encode('{}')), await rawBodySha256(new TextEncoder().encode('{ }')));
});
test('no provider registered; method/content/body gates; POST never acknowledges', async () => {
  assert.equal(installedAdapter, null);
  assert.equal((await handleBankWebhook(new Request('https://local.invalid', { method: 'GET' }))).status, 405);
  assert.equal((await handleBankWebhook(new Request('https://local.invalid', { method: 'POST', body: '{}' }))).status, 415);
  for (const body of ['{}', JSON.stringify(observation), '{malformed']) {
    const response = await handleBankWebhook(new Request('https://local.invalid', { method: 'POST', headers: { 'content-type': 'application/json' }, body }));
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), { error: 'verification_unavailable' });
  }
  for (const declaredLength of ['65537', null]) {
    const headers = new Headers({ 'content-type': 'application/json' });
    if (declaredLength != null) headers.set('content-length', declaredLength);
    assert.equal((await handleBankWebhook(new Request('https://local.invalid', { method: 'POST', headers, body: 'x'.repeat(65537) }))).status, 413);
  }
});
