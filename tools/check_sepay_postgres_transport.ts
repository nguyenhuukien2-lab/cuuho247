// LOCAL disposable PostgreSQL only. Never reads BANK_DATABASE_URL.
import assert from 'node:assert/strict';
import postgres from 'npm:postgres@3.4.7';
import { validateNormalizedTransaction } from '../backend/supabase/functions/bank-webhook/normalized.ts';
import { logDiagnostic } from '../backend/supabase/functions/bank-webhook/diagnostics.ts';
import { createPostgresVerificationStore } from '../backend/supabase/functions/bank-webhook/postgres_store.ts';
import { createSePayAdapter } from '../backend/supabase/functions/bank-webhook/sepay.ts';
import { createBankWebhookHandler } from '../backend/supabase/functions/bank-webhook/handler.ts';

async function main() {
  const url = new URL(Deno.env.get('SEPAY_LOCAL_TEST_URL') ?? '');
  assert(['postgres:', 'postgresql:'].includes(url.protocol));
  assert(['localhost', '127.0.0.1', '[::1]'].includes(url.hostname));
  assert(/^\/(sepay_transport_test_[a-z0-9_]+|flutter_app_security_audit)$/.test(url.pathname));
  assert.equal(url.search, '');
  const sql = postgres(url.toString(), { max: 1, prepare: false, onnotice: () => {} });
  try {
    const normalized = validateNormalizedTransaction({
      provider: 'sepay', provider_scope: 'sepay_test',
      provider_transaction_id: '12345', provider_event_id: 'transaction:12345',
      amount: '100000', currency: 'VND', direction: 'credit',
      occurred_at: '2026-10-13T07:00:00+07:00',
      transfer_reference: 'SANDBOX-UNMATCHED',
      beneficiary_bank_bin: '970415', beneficiary_account_number: '0000000001',
      authentication_verified: true, authentication_method: 'signature',
      signature_verified: true, raw_payload_sha256: 'a'.repeat(64),
    });
    const [legacy] = await sql`select jsonb_typeof(${JSON.stringify(normalized)}::jsonb) as root_type`;
    const [typed] = await sql`select jsonb_typeof(${sql.json({ ...normalized })}::jsonb) as root_type`;
    assert.equal(legacy.root_type, 'string');
    assert.equal(typed.root_type, 'object');
    let reproduced = false;
    try {
      await sql`select private.process_verified_bank_transaction(${JSON.stringify(normalized)}::jsonb)`;
    } catch (error) {
      assert(error instanceof postgres.PostgresError);
      assert.equal(error.code, '22023');
      assert.equal(error.message, 'BANK_NORMALIZED_INPUT_INVALID');
      reproduced = true;
    }
    assert(reproduced);
    console.log('PASS legacy transport root=string -> SQLSTATE 22023 BANK_NORMALIZED_INPUT_INVALID; typed JSON root=object');
    if (Deno.args.includes('--full')) {
      assert(/^\/sepay_transport_test_[a-z0-9_]+$/.test(url.pathname));
      const [empty] = await sql`select not exists(select 1 from private.payment_bank_config) as ok`;
      assert.equal(empty.ok, true, 'Requires a fresh disposable database');
      const source = await Deno.readTextFile('backend/supabase/tests/payment_bank_verification_regression.sql');
      const marker = "select pg_temp.bank_error('untrusted evidence rejected',";
      assert(source.includes(marker));
      // Reuse the existing privileged disposable fixtures, not live data.
      await sql.unsafe("set payment.test_mode='local_disposable';\n" + source.split(marker)[0]).simple();
      const fixtures = await sql`select i,n from bank_inputs order by i`;
      await sql`update private.payment_bank_config set verification_provider='sepay', verification_scope='sepay_test'`;
      await sql`commit`;
      // Provider timestamps have second precision; ensure fixture intents exist
      // before the synthetic bank observation without relaxing time guards.
      await new Promise(resolve => setTimeout(resolve, 1100));
      const [clock] = await sql`select to_char(clock_timestamp() at time zone 'Asia/Ho_Chi_Minh', 'YYYY-MM-DD HH24:MI:SS') as bank_time`;
      const testAccount = '0000000001'; // Synthetic local Test Mode account only.
      const store = createPostgresVerificationStore(url.toString(), {
        providerScope: 'sepay_test',
        sePayTestAccountNumber: testAccount,
      });
      const secret = crypto.randomUUID(); // Disposable HMAC key, never printed.
      const encoder = new TextEncoder();
      const key = await crypto.subtle.importKey('raw', encoder.encode(secret),
        { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
      let outcome: { result: string; changed: boolean } | undefined;
      const observedStore = {
        ...store,
        async processVerifiedTransaction(transaction: Parameters<typeof store.processVerifiedTransaction>[0]) {
          outcome = await store.processVerifiedTransaction(transaction);
          return outcome;
        },
      };
      async function deliver(i: number, expected: string, patch: Record<string, unknown> = {}, bin?: string) {
        const fixture = fixtures.find(row => row.i === i)!;
        assert(fixture);
        const n = fixture.n;
        const adapter = createSePayAdapter({
          secret, providerScope: 'sepay_test', testAccountNumber: testAccount,
          beneficiaryBankBin: bin ?? n.beneficiary_bank_bin,
        });
        const handler = createBankWebhookHandler({ adapter, store: observedStore });
        // Official Test Mode shape, locally generated values. NOT a captured
        // production webhook; optional fields are empty like unmatched test data.
        const body = JSON.stringify({
          id: 100000 + i, gateway: 'Vietcombank', transactionDate: clock.bank_time,
          accountNumber: testAccount, subAccount: '', code: '',
          content: n.transfer_reference, transferType: 'in', description: '',
          transferAmount: Number(n.amount), referenceCode: `SBLOCAL${i}`, accumulated: 0,
          ...patch,
        });
        const timestamp = String(Math.floor(Date.now() / 1000));
        const signature = new Uint8Array(await crypto.subtle.sign('HMAC', key, encoder.encode(`${timestamp}.${body}`)));
        const response = await handler(new Request('https://local.invalid', {
          method: 'POST', body, headers: {
            'content-type': 'application/json', 'x-sepay-timestamp': timestamp,
            'x-sepay-signature': 'sha256=' + Array.from(signature, x => x.toString(16).padStart(2, '0')).join(''),
          },
        }));
        assert.equal(response.status, 200);
        assert.deepEqual(await response.json(), { success: true });
        assert.equal(outcome?.result, expected);
        assert.equal(outcome?.changed, expected === 'paid');
        console.log(`PASS HMAC -> adapter -> store -> PostgreSQL: ${expected}`);
      }
      await deliver(1, 'paid');
      await deliver(1, 'duplicate_event');
      await deliver(3, 'amount_mismatch', { transferAmount: 299999 });
      await deliver(4, 'reference_unmatched', { content: 'UNMATCHED-TEST' });
      await deliver(7, 'reference_unmatched', {
        gateway: 'VietinBank', content: 'TEST MODE',
      }, '970415');
      const rejectedFixture = fixtures.find(row => row.i === 5)!;
      const rejectedBody = JSON.stringify({
        id: 100005, gateway: 'Vietcombank', transactionDate: clock.bank_time,
        accountNumber: 'wrong-test-account', subAccount: '', code: '',
        content: rejectedFixture.n.transfer_reference, transferType: 'in', description: '',
        transferAmount: Number(rejectedFixture.n.amount), referenceCode: 'SBLOCAL5', accumulated: 0,
      });
      const rejectedTimestamp = String(Math.floor(Date.now() / 1000));
      const rejectedSignature = new Uint8Array(await crypto.subtle.sign(
        'HMAC', key, encoder.encode(`${rejectedTimestamp}.${rejectedBody}`),
      ));
      const rejectedAdapter = createSePayAdapter({
        secret, providerScope: 'sepay_test', testAccountNumber: testAccount,
        beneficiaryBankBin: rejectedFixture.n.beneficiary_bank_bin,
      });
      const rejectedHandler = createBankWebhookHandler({ adapter: rejectedAdapter, store: observedStore });
      const rejectedResponse = await rejectedHandler(new Request('https://local.invalid', {
        method: 'POST', body: rejectedBody, headers: {
          'content-type': 'application/json', 'x-sepay-timestamp': rejectedTimestamp,
          'x-sepay-signature': 'sha256=' + Array.from(rejectedSignature, x => x.toString(16).padStart(2, '0')).join(''),
        },
      }));
      assert.equal(rejectedResponse.status, 400);
      assert.deepEqual(await rejectedResponse.json(), { error: 'invalid_payload' });
      console.log('PASS signed wrong Test Mode account rejected before PostgreSQL processor');
      const [counts] = await sql`select
        (select count(*)::int from private.bank_transactions) as transactions,
        (select count(*)::int from private.bank_transactions where status='verified') as verified,
        (select count(*)::int from public.payment_events where event_type='bank_payment_verified') as paid_events,
        (select count(*)::int from public.payments where status='paid') as paid_payments`;
      assert.deepEqual({ ...counts }, { transactions: 4, verified: 1, paid_events: 1, paid_payments: 1 });
      console.log('PASS four unique transactions, three rejected, one settlement; replay creates no duplicate');
    }
  } finally {
    await sql.end({ timeout: 5 });
  }
}

try { await main(); }
catch (error) {
  logDiagnostic('BANK_WEBHOOK_INTERNAL_ERROR', 'process_transaction', error);
  console.error('FAIL local SePay transport regression (details suppressed)');
  Deno.exitCode = 1;
}
// Store owns an idle pool; all awaited calls above have committed. Exit the CLI
// so its socket closes before the caller drops the disposable database.
Deno.exit(Deno.exitCode);
