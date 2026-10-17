import {
  type BankProviderAdapter,
  type BankVerificationStore,
  WebhookAuthenticationError,
  WebhookPayloadError,
} from './adapter.ts';
import { rawBodySha256 } from './normalized.ts';
import { logDiagnostic, type DiagnosticStage } from './diagnostics.ts';

const bodyDeadlineMs = 5000;
const terminalProcessorResults = new Set([
  'paid', 'duplicate_event', 'identity_conflict', 'duplicate_transaction',
  'transaction_conflict', 'reference_unmatched', 'verification_disabled',
  'binding_mismatch', 'payment_ineligible', 'method_mismatch', 'already_paid',
  'intent_ineligible', 'intent_expired', 'not_credit', 'amount_mismatch',
  'currency_mismatch', 'config_mismatch', 'beneficiary_mismatch',
  'transaction_time_invalid', 'version_exhausted', 'already_allocated',
]);
const reply = (status: number, body: Record<string, boolean | string>, extra: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', ...extra },
  });

async function readBody(request: Request, maximumBodyBytes: number): Promise<Uint8Array> {
  const reader = request.body?.getReader();
  if (!reader) return new Uint8Array();
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    const deadline = new Promise<never>((_, reject) => {
      timer = setTimeout(() => reject(new WebhookPayloadError('invalid_request')), bodyDeadlineMs);
    });
    const chunks: Uint8Array[] = [];
    let total = 0;
    while (true) {
      const chunk = await Promise.race([reader.read(), deadline]);
      if (chunk.done) break;
      total += chunk.value.byteLength;
      if (total > maximumBodyBytes) throw new WebhookPayloadError('request_too_large');
      chunks.push(chunk.value);
    }
    const body = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) {
      body.set(chunk, offset);
      offset += chunk.byteLength;
    }
    return body;
  } finally {
    if (timer) clearTimeout(timer);
    reader.releaseLock();
  }
}

export function createBankWebhookHandler(options: {
  adapter: BankProviderAdapter;
  store: BankVerificationStore;
  now?: () => Date;
}): (request: Request) => Promise<Response> {
  const { adapter, store, now = () => new Date() } = options;

  return async (request: Request): Promise<Response> => {
    const startedAt = Date.now();
    const monitoredReply = async (
      status: number,
      body: Record<string, boolean | string>,
      resultCode: string,
      stage: DiagnosticStage,
      bodySha256?: string,
      extra: Record<string, string> = {},
    ) => {
      try {
        await store.recordWebhookAttempt?.({
          provider: adapter.provider,
          providerScope: adapter.providerScope,
          httpStatus: status,
          resultCode,
          stage,
          bodySha256,
          durationMs: Math.max(0, Math.min(300000, Date.now() - startedAt)),
        });
      } catch (error) {
        logDiagnostic('BANK_WEBHOOK_INTERNAL_ERROR', 'monitoring_audit', error);
      }
      return reply(status, body, extra);
    };
    if (request.method !== 'POST') {
      logDiagnostic('BANK_WEBHOOK_PAYLOAD_INVALID', 'request_validation');
      return await monitoredReply(405, { error: 'method_not_allowed' }, 'method_not_allowed', 'request_validation', undefined, { Allow: 'POST' });
    }
    const size = request.headers.get('content-length');
    if (size != null && (!/^\d+$/.test(size) || BigInt(size) > BigInt(adapter.maximumBodyBytes))) {
      logDiagnostic('BANK_WEBHOOK_PAYLOAD_INVALID', 'request_validation');
      return await monitoredReply(413, { error: 'request_too_large' }, 'request_too_large', 'request_validation');
    }
    if (request.headers.get('content-type')?.split(';')[0].trim().toLowerCase() !== 'application/json') {
      logDiagnostic('BANK_WEBHOOK_PAYLOAD_INVALID', 'request_validation');
      return await monitoredReply(415, { error: 'unsupported_media_type' }, 'unsupported_media_type', 'request_validation');
    }
    if (request.headers.has('content-encoding')) {
      logDiagnostic('BANK_WEBHOOK_PAYLOAD_INVALID', 'request_validation');
      return await monitoredReply(415, { error: 'unsupported_media_type' }, 'unsupported_media_type', 'request_validation');
    }

    let rawBody: Uint8Array;
    try {
      rawBody = await readBody(request, adapter.maximumBodyBytes);
    } catch (error) {
      logDiagnostic('BANK_WEBHOOK_PAYLOAD_INVALID', 'read_body', error);
      if (error instanceof WebhookPayloadError && error.code === 'request_too_large') {
        return await monitoredReply(413, { error: 'request_too_large' }, 'request_too_large', 'read_body');
      }
      return await monitoredReply(400, { error: 'invalid_request' }, 'invalid_request', 'read_body');
    }

    const bodySha256 = await rawBodySha256(rawBody);

    let stage: DiagnosticStage = 'authenticate_normalize';
    try {
      const transaction = await adapter.authenticateAndNormalize({
        rawBody,
        headers: request.headers,
        receivedAt: now(),
      });
      stage = 'process_transaction';
      const outcome = await store.processVerifiedTransaction(transaction);
      // Authenticated mismatches are terminal and are safely audited by the
      // private processor. Only an incomplete receipt should ask SePay to retry.
      if (!terminalProcessorResults.has(outcome.result)) {
        logDiagnostic('BANK_WEBHOOK_INTERNAL_ERROR', 'processor_result');
        return await monitoredReply(500, { error: 'internal_failure' }, 'internal_failure', 'processor_result', bodySha256);
      }
      return await monitoredReply(200, { success: true }, outcome.result, 'process_transaction', bodySha256);
    } catch (error) {
      if (error instanceof WebhookAuthenticationError) {
        logDiagnostic('BANK_WEBHOOK_HMAC_FAILED', 'authenticate_normalize', error);
        // Best-effort audit stores only a digest; never retain or log the body,
        // signature, secret, provider headers, or SQL error details.
        try {
          await store.recordAuthenticationFailure(
            adapter.provider,
            adapter.providerScope,
            bodySha256,
          );
        } catch (auditError) {
          logDiagnostic('BANK_WEBHOOK_INTERNAL_ERROR', 'authentication_audit', auditError);
        }
        return await monitoredReply(401, { error: 'invalid_signature' }, 'invalid_signature', 'authenticate_normalize', bodySha256);
      }
      if (error instanceof WebhookPayloadError) {
        logDiagnostic('BANK_WEBHOOK_PAYLOAD_INVALID', 'authenticate_normalize', error);
        return await monitoredReply(400, { error: 'invalid_payload' }, 'invalid_payload', 'authenticate_normalize', bodySha256);
      }
      logDiagnostic('BANK_WEBHOOK_INTERNAL_ERROR', stage, error);
      return await monitoredReply(500, { error: 'internal_failure' }, 'internal_failure', stage, bodySha256);
    }
  };
}
