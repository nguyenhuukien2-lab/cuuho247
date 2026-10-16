import {
  type BankProviderAdapter,
  WebhookAuthenticationError,
  WebhookPayloadError,
} from './adapter.ts';
import {
  rawBodySha256,
  type NormalizedBankTransaction,
  validateNormalizedTransaction,
} from './normalized.ts';

const encoder = new TextEncoder();
const hmacPrefix = 'sha256=';
const maxTimestampSkewSeconds = 300;

export interface SePayAdapterOptions {
  secret?: string;
  providerScope?: string;
  beneficiaryBankBin?: string;
  testAccountNumber?: string;
  maximumBodyBytes?: number;
}

export interface SePayConfiguredBeneficiary {
  bankBin: string;
  accountNumber: string;
}

const sePayTestScope = 'sepay_test';

function authError(code: string): never {
  throw new WebhookAuthenticationError(code);
}

function payloadError(code: string): never {
  throw new WebhookPayloadError(code);
}

function requiredText(
  row: Record<string, unknown>,
  key: string,
  maxLength: number,
): string {
  const value = row[key];
  if (typeof value !== 'string' || value.length === 0 || value.length > maxLength || value.includes('\0')) {
    payloadError('invalid_payload');
  }
  return value;
}

function optionalText(
  row: Record<string, unknown>,
  key: string,
  maxLength: number,
): string | null {
  const value = row[key];
  if (value == null || value === '') return null;
  if (typeof value !== 'string' || value.length > maxLength || value.includes('\0')) {
    payloadError('invalid_payload');
  }
  return value;
}

function decodeSignature(value: string): Uint8Array | null {
  if (!/^sha256=[0-9a-fA-F]{64}$/.test(value)) return null;
  const bytes = new Uint8Array(32);
  for (let index = 0; index < bytes.length; index += 1) {
    bytes[index] = Number.parseInt(value.slice(hmacPrefix.length + index * 2, hmacPrefix.length + index * 2 + 2), 16);
  }
  return bytes;
}

/** Compares all supplied bytes before returning. Signature length is public. */
export function constantTimeEqual(left: Uint8Array, right: Uint8Array): boolean {
  const length = Math.max(left.length, right.length);
  let difference = left.length ^ right.length;
  for (let index = 0; index < length; index += 1) {
    difference |= (left[index] ?? 0) ^ (right[index] ?? 0);
  }
  return difference === 0;
}

function validAccountNumber(value: string | undefined): value is string {
  return typeof value === 'string' && value.length > 0 && value.length <= 128 && !value.includes('\0');
}

function assertSePayTestAccount(providerScope: string | undefined, testAccountNumber: string | undefined, accountNumber: string): void {
  if (providerScope !== sePayTestScope) return;
  if (!validAccountNumber(testAccountNumber)) throw new Error('test_beneficiary_configuration_unavailable');
  if (!constantTimeEqual(encoder.encode(accountNumber), encoder.encode(testAccountNumber))) {
    payloadError('test_beneficiary_mismatch');
  }
}

/** Test Mode only: replace authenticated SePay test beneficiary evidence with
 * the real beneficiary read from the owner-controlled database config. Live
 * scopes return the original immutable transaction without inspecting mapping
 * inputs, so a configured test secret can never alter live evidence.
 */
export function mapSePayTestBeneficiary(
  transaction: Readonly<NormalizedBankTransaction>,
  options: {
    providerScope?: string;
    testAccountNumber?: string;
    configuredBeneficiary?: SePayConfiguredBeneficiary;
  },
): Readonly<NormalizedBankTransaction> {
  if (options.providerScope !== sePayTestScope) return transaction;
  if (transaction.provider !== 'sepay' || transaction.provider_scope !== sePayTestScope
    || transaction.authentication_method !== 'signature' || !transaction.signature_verified) {
    throw new Error('test_beneficiary_mapping_unavailable');
  }
  assertSePayTestAccount(options.providerScope, options.testAccountNumber,
    transaction.beneficiary_account_number ?? '');
  const configured = options.configuredBeneficiary;
  if (!configured || !/^\d{6}$/.test(configured.bankBin) || !validAccountNumber(configured.accountNumber)) {
    throw new Error('test_beneficiary_mapping_unavailable');
  }
  return validateNormalizedTransaction({
    ...transaction,
    beneficiary_bank_bin: configured.bankBin,
    beneficiary_account_number: configured.accountNumber,
  });
}

async function expectedSignature(secret: string, timestamp: string, rawBody: Uint8Array): Promise<Uint8Array> {
  const prefix = encoder.encode(`${timestamp}.`);
  const signed = new Uint8Array(prefix.byteLength + rawBody.byteLength);
  signed.set(prefix);
  signed.set(rawBody, prefix.byteLength);
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  return new Uint8Array(await crypto.subtle.sign('HMAC', key, signed));
}

function transactionTime(value: string): string {
  const match = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/.exec(value);
  if (!match) payloadError('invalid_payload');
  const [, year, month, day, hour, minute, second] = match;
  const normalized = `${year}-${month}-${day}T${hour}:${minute}:${second}+07:00`;
  if (!Number.isFinite(Date.parse(normalized))) payloadError('invalid_payload');
  return normalized;
}

function transactionId(value: unknown): string {
  if (!Number.isSafeInteger(value) || (value as number) <= 0) payloadError('invalid_payload');
  return String(value);
}

function amount(value: unknown): string {
  if (!Number.isSafeInteger(value) || (value as number) <= 0) payloadError('invalid_payload');
  return String(value);
}

function transferReference(row: Record<string, unknown>, providerScope: string): string | null {
  const code = optionalText(row, 'code', 128);
  const content = requiredText(row, 'content', 4096);
  // A nonempty provider code is authoritative: never repair it from narration.
  if (code != null) return code;
  // Keep Test Mode's existing exact-content path; no narrative extraction or
  // beneficiary mapping is introduced for Live transactions.
  if (providerScope === sePayTestScope) return content.length <= 128 ? content : null;
  // Called ONLY after HMAC, freshness and incoming-credit checks. Count every
  // BK-like numeric occurrence (including malformed/lowercase/duplicate tokens)
  // before accepting a single exact uppercase canonical reference. Never trim,
  // case-fold or truncate the extracted identifier.
  const candidates = [...content.matchAll(/BK[0-9]+/gi)];
  if (candidates.length !== 1) return null;
  const candidate = candidates[0];
  if (!/^BK[0-9]{19}$/.test(candidate[0])) return null;
  const start = candidate.index!;
  const end = start + candidate[0].length;
  const separator = /^[ \t\r\n.,:;()/\-]$/;
  if ((start > 0 && !separator.test(content[start - 1]))
    || (end < content.length && !separator.test(content[end]))) return null;
  // PostgreSQL still checks configured provider/scope, exact reference, amount,
  // beneficiary, intent/time window, ownership and durable replay protections.
  return candidate[0];
}

function parsePayload(rawBody: Uint8Array): Record<string, unknown> {
  let value: unknown;
  try {
    value = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(rawBody));
  } catch {
    payloadError('invalid_json');
  }
  if (value == null || typeof value !== 'object' || Array.isArray(value)) payloadError('invalid_payload');
  return value as Record<string, unknown>;
}

export function createSePayAdapter(options: SePayAdapterOptions): BankProviderAdapter {
  const maximumBodyBytes = options.maximumBodyBytes ?? 64 * 1024;
  return {
    provider: 'sepay',
    providerScope: options.providerScope ?? '',
    contractDocumentation: 'https://developer.sepay.vn/vi/sepay-webhooks/xac-thuc',
    maximumBodyBytes,

    async authenticateAndNormalize({ rawBody, headers, receivedAt }): Promise<NormalizedBankTransaction> {
      const secret = options.secret;
      const signatureHeader = headers.get('x-sepay-signature');
      const timestampHeader = headers.get('x-sepay-timestamp');
      if (!secret) authError('webhook_secret_unavailable');
      if (!signatureHeader || !timestampHeader) authError('missing_signature');
      if (!/^\d{10}$/.test(timestampHeader)) authError('invalid_signature');
      const timestamp = Number(timestampHeader);
      if (!Number.isSafeInteger(timestamp) || Math.abs(Math.floor(receivedAt.getTime() / 1000) - timestamp) > maxTimestampSkewSeconds) {
        authError('expired_signature');
      }
      const supplied = decodeSignature(signatureHeader);
      const expected = await expectedSignature(secret, timestampHeader, rawBody);
      const signatureMatches = constantTimeEqual(expected, supplied ?? new Uint8Array(expected.length));
      if (supplied == null || !signatureMatches) authError('invalid_signature');

      const row = parsePayload(rawBody);
      const id = transactionId(row.id);
      const gateway = requiredText(row, 'gateway', 120);
      const accountNumber = requiredText(row, 'accountNumber', 128);
      const content = requiredText(row, 'content', 4096);
      if (row.transferType !== 'in') payloadError('invalid_direction');
      if (!options.providerScope || options.providerScope.length > 128 || !options.beneficiaryBankBin || !/^\d{6}$/.test(options.beneficiaryBankBin)) {
        throw new Error('provider_configuration_unavailable');
      }
      // Validate fields which are part of SePay's required webhook contract even
      // when they are not persisted in the normalized private model.
      void gateway;
      void content;
      // This gate is deliberately after successful HMAC verification. In Test
      // Mode the provider account must exactly match the dedicated Function
      // Secret before the server-side store is allowed to map it.
      assertSePayTestAccount(options.providerScope, options.testAccountNumber, accountNumber);
      optionalText(row, 'subAccount', 256);
      optionalText(row, 'description', 4096);
      optionalText(row, 'referenceCode', 256);

      try {
        return validateNormalizedTransaction({
          provider: 'sepay',
          provider_scope: options.providerScope,
          provider_transaction_id: id,
          provider_event_id: `transaction:${id}`,
          amount: amount(row.transferAmount),
          currency: 'VND',
          direction: 'credit',
          transfer_reference: transferReference(row, options.providerScope),
          occurred_at: transactionTime(requiredText(row, 'transactionDate', 19)),
          beneficiary_bank_bin: options.beneficiaryBankBin,
          beneficiary_account_number: accountNumber,
          authentication_verified: true,
          signature_verified: true,
          authentication_method: 'signature',
          raw_payload_sha256: await rawBodySha256(rawBody),
        });
      } catch (error) {
        if (error instanceof WebhookPayloadError) throw error;
        payloadError('invalid_payload');
      }
    },
  };
}
