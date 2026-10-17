/** Internal server model only; amounts never pass through JS floating point. */
export interface NormalizedBankTransaction {
  provider: string;
  provider_scope: string;
  provider_transaction_id: string;
  provider_event_id?: string | null;
  delivery_id?: string | null;
  amount: string;
  currency: string;
  direction: 'credit' | 'debit';
  transfer_reference?: string | null;
  occurred_at: string;
  beneficiary_bank_bin?: string | null;
  beneficiary_account_number?: string | null;
  authentication_verified: true;
  signature_verified: boolean;
  authentication_method: 'signature' | 'token' | 'mtls';
  raw_payload_sha256: string;
  // received_at is assigned by the DB, never supplied in this input.
}

const allowed = new Set([
  'provider', 'provider_scope', 'provider_transaction_id', 'provider_event_id',
  'delivery_id', 'amount', 'currency', 'direction', 'transfer_reference', 'occurred_at',
  'beneficiary_bank_bin', 'beneficiary_account_number', 'authentication_verified',
  'signature_verified', 'authentication_method', 'raw_payload_sha256',
]);
function invalid(): never { throw new Error('BANK_NORMALIZED_INPUT_INVALID'); }
function text(row: Record<string, unknown>, key: string, max: number, optional = false): string | null {
  const value = row[key];
  if (optional && value == null) return null;
  if (typeof value !== 'string' || value.length === 0 || value.length > max || value.includes('\0')) invalid();
  return value as string;
}

/** Shape validation is NOT provider authentication. Call only after the adapter
 * has authenticated exact bytes. SQL independently rechecks this boundary.
 */
export function validateNormalizedTransaction(value: unknown): Readonly<NormalizedBankTransaction> {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) invalid();
  const row = value as Record<string, unknown>;
  if (Object.keys(row).some(key => !allowed.has(key))) invalid();
  if (new TextEncoder().encode(JSON.stringify(row)).byteLength > 8192) invalid();
  if (!/^[a-z][a-z0-9_]{0,63}$/.test(text(row, 'provider', 64)!)) invalid();
  text(row, 'provider_scope', 128);
  text(row, 'provider_transaction_id', 256);
  text(row, 'provider_event_id', 200, true);
  text(row, 'delivery_id', 200, true);
  text(row, 'transfer_reference', 128, true);
  text(row, 'beneficiary_bank_bin', 64, true);
  text(row, 'beneficiary_account_number', 128, true);
  const amount = text(row, 'amount', 19)!;
  if (!/^[1-9][0-9]{0,18}$/.test(amount) || BigInt(amount) > 9223372036854775807n) invalid();
  if (!/^[A-Z]{3}$/.test(text(row, 'currency', 3)!)) invalid();
  if (row.direction !== 'credit' && row.direction !== 'debit') invalid();
  if (row.authentication_verified !== true || typeof row.signature_verified !== 'boolean') invalid();
  if (!['signature', 'token', 'mtls'].includes(row.authentication_method as string)) invalid();
  if (row.authentication_method === 'signature' && row.signature_verified !== true) invalid();
  if (!/^[0-9a-f]{64}$/.test(text(row, 'raw_payload_sha256', 64)!)) invalid();
  const time = text(row, 'occurred_at', 40)!;
  const parts = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$/.exec(time);
  if (!parts || !Number.isFinite(Date.parse(time))) invalid();
  const [, year, month, day, hour, minute, second, zone] = parts!;
  const y = Number(year), m = Number(month), d = Number(day);
  const leap = y % 4 === 0 && (y % 100 !== 0 || y % 400 === 0);
  const days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (y < 1 || m < 1 || m > 12 || d < 1 || d > days[m - 1] || Number(hour) > 23 || Number(minute) > 59 || Number(second) > 59) invalid();
  if (zone !== 'Z' && (Number(zone.slice(1, 3)) > 14 || Number(zone.slice(4)) > 59 || (zone.slice(1, 3) === '14' && zone.slice(4) !== '00'))) invalid();
  return Object.freeze({ ...row }) as unknown as Readonly<NormalizedBankTransaction>;
}

export async function rawBodySha256(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new Uint8Array(bytes));
  return Array.from(new Uint8Array(digest), x => x.toString(16).padStart(2, '0')).join('');
}
