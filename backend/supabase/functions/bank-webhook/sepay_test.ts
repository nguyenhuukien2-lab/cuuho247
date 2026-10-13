import { test } from 'node:test';
import assert from 'node:assert/strict';
import type { BankVerificationStore } from './adapter.ts';
import { createBankWebhookHandler } from './handler.ts';
import type { NormalizedBankTransaction } from './normalized.ts';
import { createSePayAdapter, mapSePayTestBeneficiary } from './sepay.ts';

const encoder = new TextEncoder();
const secret = 'local-test-secret-never-used-in-production';
const timestamp = '1791849600'; // 2026-10-13T00:00:00Z
const now = () => new Date(Number(timestamp) * 1000);
const expected = {
  amount: '150000',
  reference: 'BK0000000000000000001',
  account: '0123456789',
};
const testAccount = '0000000001';
const liveScope = 'production:merchant-1';

function payload(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: 987654321,
    gateway: 'Vietcombank',
    transactionDate: '2026-10-13 07:00:00',
    accountNumber: expected.account,
    subAccount: null,
    code: expected.reference,
    content: expected.reference,
    transferType: 'in',
    description: 'Incoming transfer',
    transferAmount: Number(expected.amount),
    accumulated: 150000,
    referenceCode: 'FT263000000001',
    ...overrides,
  };
}

async function signature(rawBody: Uint8Array, signingSecret = secret): Promise<string> {
  const prefix = encoder.encode(`${timestamp}.`);
  const message = new Uint8Array(prefix.byteLength + rawBody.byteLength);
  message.set(prefix);
  message.set(rawBody, prefix.byteLength);
  const key = await crypto.subtle.importKey(
    'raw', encoder.encode(signingSecret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const digest = new Uint8Array(await crypto.subtle.sign('HMAC', key, message));
  return `sha256=${Array.from(digest, byte => byte.toString(16).padStart(2, '0')).join('')}`;
}

class MatchingStore implements BankVerificationStore {
  readonly processed: NormalizedBankTransaction[] = [];
  readonly outcomes: string[] = [];
  readonly authenticationFailures: string[] = [];
  readonly seen = new Set<string>();
  paidCount = 0;

  async processVerifiedTransaction(transaction: NormalizedBankTransaction) {
    this.processed.push(transaction);
    if (this.seen.has(transaction.provider_transaction_id)) {
      this.outcomes.push('duplicate_event');
      return { result: 'duplicate_event', changed: false };
    }
    this.seen.add(transaction.provider_transaction_id);
    if (transaction.amount !== expected.amount) {
      this.outcomes.push('amount_mismatch');
      return { result: 'amount_mismatch', changed: false };
    }
    if (transaction.transfer_reference !== expected.reference) {
      this.outcomes.push('reference_unmatched');
      return { result: 'reference_unmatched', changed: false };
    }
    if (transaction.beneficiary_account_number !== expected.account) {
      this.outcomes.push('beneficiary_mismatch');
      return { result: 'beneficiary_mismatch', changed: false };
    }
    this.paidCount += 1;
    this.outcomes.push('paid');
    return { result: 'paid', changed: true };
  }

  async recordAuthenticationFailure(_provider: string, _scope: string, bodySha256: string) {
    this.authenticationFailures.push(bodySha256);
  }
}

class TestMappingStore extends MatchingStore {
  private readonly providerScope: string;
  private readonly configuredTestAccount: string | undefined;

  constructor(providerScope: string, configuredTestAccount: string | undefined) {
    super();
    this.providerScope = providerScope;
    this.configuredTestAccount = configuredTestAccount;
  }

  override async processVerifiedTransaction(transaction: NormalizedBankTransaction) {
    const mapped = mapSePayTestBeneficiary(transaction, {
      providerScope: this.providerScope,
      testAccountNumber: this.configuredTestAccount,
      configuredBeneficiary: { bankBin: '970436', accountNumber: expected.account },
    });
    return await super.processVerifiedTransaction(mapped);
  }
}

function fixture(options: {
  configuredSecret?: string;
  maximumBodyBytes?: number;
  providerScope?: string;
  configuredTestAccount?: string;
} = {}) {
  const providerScope = options.providerScope ?? liveScope;
  const configuredTestAccount = options.configuredTestAccount;
  const store = new TestMappingStore(providerScope, configuredTestAccount);
  const adapter = createSePayAdapter({
    secret: options.configuredSecret === undefined ? secret : options.configuredSecret,
    providerScope,
    beneficiaryBankBin: '970436',
    testAccountNumber: configuredTestAccount,
    maximumBodyBytes: options.maximumBodyBytes,
  });
  return { store, handler: createBankWebhookHandler({ adapter, store, now }) };
}

async function requestFor(value: Record<string, unknown> | string, signatureOverride?: string | null): Promise<Request> {
  const body = typeof value === 'string' ? value : JSON.stringify(value);
  const bytes = encoder.encode(body);
  const headers = new Headers({
    'content-type': 'application/json',
    'x-sepay-timestamp': timestamp,
  });
  const signed = signatureOverride === undefined ? await signature(bytes) : signatureOverride;
  if (signed != null) headers.set('x-sepay-signature', signed);
  return new Request('https://local.invalid/functions/v1/bank-webhook', { method: 'POST', headers, body });
}

test('valid HMAC authenticates exact raw body and normalizes SePay transaction', async () => {
  const { handler, store } = fixture();
  const response = await handler(await requestFor(payload()));
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { success: true });
  assert.equal(store.paidCount, 1);
  assert.deepEqual(store.processed[0], {
    provider: 'sepay',
    provider_scope: liveScope,
    provider_transaction_id: '987654321',
    provider_event_id: 'transaction:987654321',
    amount: '150000',
    currency: 'VND',
    direction: 'credit',
    transfer_reference: expected.reference,
    occurred_at: '2026-10-13T07:00:00+07:00',
    beneficiary_bank_bin: '970436',
    beneficiary_account_number: expected.account,
    authentication_verified: true,
    signature_verified: true,
    authentication_method: 'signature',
    raw_payload_sha256: store.processed[0].raw_payload_sha256,
  });
  assert.match(store.processed[0].raw_payload_sha256, /^[0-9a-f]{64}$/);
});

test('sepay_test scope with exact secret account maps to server-configured production beneficiary', async () => {
  const { handler, store } = fixture({ providerScope: 'sepay_test', configuredTestAccount: testAccount });
  const response = await handler(await requestFor(payload({ accountNumber: testAccount })));
  assert.equal(response.status, 200);
  assert.equal(store.paidCount, 1);
  assert.equal(store.processed[0].provider_scope, 'sepay_test');
  assert.equal(store.processed[0].beneficiary_bank_bin, '970436');
  assert.equal(store.processed[0].beneficiary_account_number, expected.account);
});

test('sepay_test scope rejects a signed webhook with the wrong test account', async () => {
  const { handler, store } = fixture({ providerScope: 'sepay_test', configuredTestAccount: testAccount });
  const response = await handler(await requestFor(payload({ accountNumber: '9999999999' })));
  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: 'invalid_payload' });
  assert.equal(store.processed.length, 0);
  assert.equal(store.paidCount, 0);
});

test('sepay_test account rejection diagnostics never log either beneficiary account', async t => {
  const records: string[] = [];
  t.mock.method(console, 'error', (value: string) => records.push(value));
  const wrongAccount = 'wrong-test-account';
  const { handler } = fixture({ providerScope: 'sepay_test', configuredTestAccount: testAccount });
  assert.equal((await handler(await requestFor(payload({ accountNumber: wrongAccount })))).status, 400);
  assert.deepEqual(records.map(record => JSON.parse(record)), [{
    category: 'BANK_WEBHOOK_PAYLOAD_INVALID', provider: 'sepay',
    stage: 'authenticate_normalize', errorName: 'WebhookPayloadError',
  }]);
  for (const record of records) {
    assert.equal(record.includes(testAccount), false);
    assert.equal(record.includes(wrongAccount), false);
    assert.equal(record.includes(expected.account), false);
  }
});

test('live scope never maps even when the test account secret is present', async () => {
  const { handler, store } = fixture({ providerScope: liveScope, configuredTestAccount: testAccount });
  const response = await handler(await requestFor(payload({ accountNumber: testAccount })));
  assert.equal(response.status, 200);
  assert.deepEqual(store.outcomes, ['beneficiary_mismatch']);
  assert.equal(store.processed[0].beneficiary_account_number, testAccount);
  assert.equal(store.paidCount, 0);
});

test('sepay_test scope fails closed when SEPAY_TEST_ACCOUNT_NUMBER is missing', async () => {
  const { handler, store } = fixture({ providerScope: 'sepay_test' });
  const response = await handler(await requestFor(payload({ accountNumber: testAccount })));
  assert.equal(response.status, 500);
  assert.deepEqual(await response.json(), { error: 'internal_failure' });
  assert.equal(store.processed.length, 0);
  assert.equal(store.paidCount, 0);
});

test('invalid HMAC is rejected before sepay_test account validation or mapping', async () => {
  const { handler, store } = fixture({ providerScope: 'sepay_test', configuredTestAccount: testAccount });
  const raw = JSON.stringify(payload({ accountNumber: 'wrong-test-account' }));
  const response = await handler(await requestFor(raw, await signature(encoder.encode(raw), 'wrong-secret')));
  assert.equal(response.status, 401);
  assert.equal(store.processed.length, 0);
  assert.equal(store.paidCount, 0);
});

for (const [name, overrides, expectedResult] of [
  ['amount', { transferAmount: 149999 }, 'amount_mismatch'],
  ['reference', { code: 'BK0000000000000000002' }, 'reference_unmatched'],
] as const) {
  test(`sepay_test mapping still requires exact ${name}`, async () => {
    const { handler, store } = fixture({ providerScope: 'sepay_test', configuredTestAccount: testAccount });
    const response = await handler(await requestFor(payload({ accountNumber: testAccount, ...overrides })));
    assert.equal(response.status, 200);
    assert.deepEqual(store.outcomes, [expectedResult]);
    assert.equal(store.paidCount, 0);
  });
}

test('sepay_test mapped webhook replay remains idempotent', async () => {
  const { handler, store } = fixture({ providerScope: 'sepay_test', configuredTestAccount: testAccount });
  const value = payload({ accountNumber: testAccount });
  assert.equal((await handler(await requestFor(value))).status, 200);
  assert.equal((await handler(await requestFor(value))).status, 200);
  assert.deepEqual(store.outcomes, ['paid', 'duplicate_event']);
  assert.equal(store.paidCount, 1);
});

test('invalid HMAC returns 401 and cannot write a transaction or payment', async () => {
  const { handler, store } = fixture();
  const raw = JSON.stringify(payload());
  const response = await handler(await requestFor(raw, await signature(encoder.encode(raw), 'wrong-secret')));
  assert.equal(response.status, 401);
  assert.equal(store.processed.length, 0);
  assert.equal(store.paidCount, 0);
  assert.equal(store.authenticationFailures.length, 1);
});

test('missing HMAC returns 401 and cannot write a transaction or payment', async () => {
  const { handler, store } = fixture();
  const response = await handler(await requestFor(payload(), null));
  assert.equal(response.status, 401);
  assert.equal(store.processed.length, 0);
  assert.equal(store.paidCount, 0);
});

test('missing server secret fails closed before transaction processing', async () => {
  const { handler, store } = fixture({ configuredSecret: '' });
  const response = await handler(await requestFor(payload()));
  assert.equal(response.status, 401);
  assert.equal(store.processed.length, 0);
});

test('signed malformed JSON returns 400 after authentication', async () => {
  const { handler, store } = fixture();
  const response = await handler(await requestFor('{malformed'));
  assert.equal(response.status, 400);
  assert.equal(store.processed.length, 0);
});

for (const [name, overrides, expectedResult] of [
  ['wrong amount', { transferAmount: 149999 }, 'amount_mismatch'],
  ['wrong reference', { code: 'BK0000000000000000002' }, 'reference_unmatched'],
  ['wrong beneficiary', { accountNumber: '9999999999' }, 'beneficiary_mismatch'],
] as const) {
  test(`${name} is acknowledged but never paid`, async () => {
    const { handler, store } = fixture();
    const response = await handler(await requestFor(payload(overrides)));
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { success: true });
    assert.equal(store.paidCount, 0);
    assert.deepEqual(store.outcomes, [expectedResult]);
  });
}

test('duplicate webhook/replay is idempotent and cannot pay twice', async () => {
  const { handler, store } = fixture();
  const first = await handler(await requestFor(payload()));
  const replay = await handler(await requestFor(payload()));
  assert.equal(first.status, 200);
  assert.equal(replay.status, 200);
  assert.equal(store.processed.length, 2);
  assert.equal(store.paidCount, 1);
});

test('outgoing transaction is rejected as malformed payload', async () => {
  const { handler, store } = fixture();
  const response = await handler(await requestFor(payload({ transferType: 'out' })));
  assert.equal(response.status, 400);
  assert.equal(store.processed.length, 0);
});

test('internal processor failure returns generic 500 without details', async () => {
  const { handler, store } = fixture();
  store.processVerifiedTransaction = async () => { throw new Error('private SQL detail'); };
  const response = await handler(await requestFor(payload()));
  assert.equal(response.status, 500);
  assert.deepEqual(await response.json(), { error: 'internal_failure' });
});

test('method, media type and body size gates reject before processing', async () => {
  const { handler, store } = fixture({ maximumBodyBytes: 16 });
  assert.equal((await handler(new Request('https://local.invalid', { method: 'GET' }))).status, 405);
  assert.equal((await handler(new Request('https://local.invalid', { method: 'POST', body: '{}' }))).status, 415);
  assert.equal((await handler(new Request('https://local.invalid', {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: 'x'.repeat(17),
  }))).status, 413);
  assert.equal(store.processed.length, 0);
});

test('HTTP 500 diagnostics exclude SQL, credentials, account and raw body', async t => {
  const records: string[] = [];
  t.mock.method(console, 'error', (value: string) => records.push(value));
  const { handler, store } = fixture();
  store.processVerifiedTransaction = async () => {
    throw Object.assign(new Error(`postgres://user:password@host/db ${expected.account}`), {
      name: 'PostgresError', code: '42501', query: 'sensitive SQL',
      parameters: [payload(), secret],
    });
  };
  const response = await handler(await requestFor(payload()));
  assert.equal(response.status, 500);
  assert.deepEqual(await response.json(), { error: 'internal_failure' });
  assert.deepEqual(records.map(record => JSON.parse(record)), [{
    category: 'BANK_WEBHOOK_INTERNAL_ERROR', provider: 'sepay',
    stage: 'process_transaction', errorName: 'PostgresError', sqlState: '42501',
  }]);
});

test('HMAC and invalid payload diagnostics retain generic responses', async t => {
  const records: string[] = [];
  t.mock.method(console, 'error', (value: string) => records.push(value));
  const { handler, store } = fixture();
  assert.equal((await handler(await requestFor(payload(), null))).status, 401);
  assert.equal((await handler(await requestFor('{malformed'))).status, 400);
  assert.deepEqual(records.map(record => JSON.parse(record).category), [
    'BANK_WEBHOOK_HMAC_FAILED', 'BANK_WEBHOOK_PAYLOAD_INVALID',
  ]);
  assert.equal(store.processed.length, 0);
  for (const record of records) {
    assert.equal(record.includes(secret), false);
    assert.equal(record.includes(expected.account), false);
    assert.equal(record.includes('{malformed'), false);
  }
});
