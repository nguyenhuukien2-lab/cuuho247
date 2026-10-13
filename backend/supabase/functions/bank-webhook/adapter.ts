import type { NormalizedBankTransaction } from './normalized.ts';

/** SERVER-ONLY integration boundary. There is deliberately no registered adapter.
 * Implement only against an actual provider's documented contract and official
 * fixtures. VietQR generation is not a transaction verification provider.
 */
export interface BankProviderAdapter {
  readonly provider: string;
  /** Authenticated merchant/account/environment; bind it to the beneficiary. */
  readonly providerScope: string;
  readonly contractDocumentation: string;
  readonly maximumBodyBytes: number;

  /** Verify exact bytes, required headers, timestamp/replay window (if supported),
   * account identity and final CREDIT event semantics BEFORE returning data.
   * Reject unknown/pending event types. Do not parse an HTTP body directly as
   * NormalizedBankTransaction or accept authentication flags from the provider.
   * Preserve the full bank_sequence_v1 transfer content without trimming,
   * lowercasing, substring extraction or removing characters.
   * Secrets come from server environment only. Never log headers/body/errors.
   */
  authenticateAndNormalize(input: {
    rawBody: Uint8Array;
    headers: Headers;
    receivedAt: Date;
  }): Promise<NormalizedBankTransaction>;
}

/** Future direct DB worker integration. Private schema must not be exposed in
 * PostgREST to make this work. The shipped migration gives no API role EXECUTE.
 * A reviewed least-privilege DB role/grant is a deployment prerequisite.
 */
export interface BankVerificationStore {
  processVerifiedTransaction(transaction: NormalizedBankTransaction): Promise<{
    result: string;
    changed: boolean;
  }>;
  recordAuthenticationFailure(provider: string, scope: string, bodySha256: string): Promise<void>;
}

// Intentionally no provider implementation, credentials, fake HMAC or DB client.
export const installedAdapter: BankProviderAdapter | null = null;
