import { createBankWebhookHandler } from './handler.ts';
import { createPostgresVerificationStore } from './postgres_store.ts';
import { createSePayAdapter } from './sepay.ts';
import { logDiagnostic } from './diagnostics.ts';

try {
  const providerScope = Deno.env.get('SEPAY_PROVIDER_SCOPE');
  const testAccountNumber = Deno.env.get('SEPAY_TEST_ACCOUNT_NUMBER');
  const adapter = createSePayAdapter({
    secret: Deno.env.get('SEPAY_WEBHOOK_SECRET'),
    providerScope,
    beneficiaryBankBin: Deno.env.get('SEPAY_BENEFICIARY_BANK_BIN'),
    testAccountNumber,
  });
  const store = createPostgresVerificationStore(Deno.env.get('BANK_DATABASE_URL'), {
    providerScope,
    sePayTestAccountNumber: testAccountNumber,
  });

  Deno.serve(createBankWebhookHandler({ adapter, store }));
} catch (error) {
  logDiagnostic('BANK_WEBHOOK_INTERNAL_ERROR', 'startup', error);
  // Do not rethrow the original error: runtime logging could expose its URL,
  // password or stack. Startup failure still returns only a generic 500.
  Deno.serve(() => new Response(JSON.stringify({ error: 'internal_failure' }), {
    status: 500,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  }));
}
