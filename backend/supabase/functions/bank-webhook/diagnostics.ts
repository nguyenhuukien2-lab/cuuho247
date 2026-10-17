// Temporary production diagnostics. Never serialize an error, message, cause,
// stack, query, parameters, request, payload or environment values. Only exact
// allowlisted processor messages may map to a constant processorReasonCode.
export type DiagnosticCategory =
  | 'BANK_WEBHOOK_HMAC_FAILED'
  | 'BANK_WEBHOOK_PAYLOAD_INVALID'
  | 'BANK_WEBHOOK_DB_CONNECT_FAILED'
  | 'BANK_WEBHOOK_DB_PROCESSOR_FAILED'
  | 'BANK_WEBHOOK_INTERNAL_ERROR';

export type DiagnosticStage =
  | 'startup' | 'request_validation' | 'read_body' | 'authenticate_normalize'
  | 'process_transaction' | 'processor_result' | 'authentication_audit'
  | 'monitoring_audit'
  | 'configuration' | 'connect' | 'begin_transaction' | 'statement_timeout'
  | 'beneficiary_mapping' | 'processor_call' | 'auth_audit_call' | 'webhook_audit_call' | 'commit' | 'rollback';

const safeNames = new Set([
  'Error', 'TypeError', 'RangeError', 'SyntaxError', 'PostgresError',
  'WebhookAuthenticationError', 'WebhookPayloadError',
]);
const connectionCodes = new Set([
  'ECONNREFUSED', 'ECONNRESET', 'ETIMEDOUT', 'ENOTFOUND', 'EAI_AGAIN',
  'EHOSTUNREACH', 'ENETUNREACH', 'EPIPE', 'CONNECT_TIMEOUT',
  'CONNECTION_CLOSED', 'CONNECTION_ENDED', 'CONNECTION_DESTROYED',
  'CERT_HAS_EXPIRED', 'DEPTH_ZERO_SELF_SIGNED_CERT',
  'SELF_SIGNED_CERT_IN_CHAIN', 'UNABLE_TO_VERIFY_LEAF_SIGNATURE',
  'ERR_TLS_CERT_ALTNAME_INVALID',
]);
const safeCodes = new Set([
  ...connectionCodes, 'ERR_INVALID_URL', 'webhook_secret_unavailable',
  'missing_signature', 'invalid_signature', 'expired_signature',
  'invalid_payload', 'invalid_json', 'invalid_direction',
  'request_too_large', 'invalid_request',
]);

function property(error: unknown, field: string): unknown {
  try {
    if (error !== null && typeof error === 'object') {
      return (error as Record<string, unknown>)[field];
    }
  } catch { /* A hostile getter must not affect the response. */ }
  return undefined;
}

export function logDiagnostic(category: DiagnosticCategory, stage: DiagnosticStage, error?: unknown): void {
  try {
    const record: Record<string, string> = { category, provider: 'sepay', stage };
    const name = property(error, 'name');
    const code = property(error, 'code');
    if (typeof name === 'string' && safeNames.has(name)) record.errorName = name;
    if (typeof code === 'string') {
      if (safeCodes.has(code)) record.errorCode = code;
      else if (/^[0-9A-Z]{5}$/.test(code)) record.sqlState = code;
    }
    if (name === 'PostgresError' && code === '22023'
      && (stage === 'processor_call' || stage === 'process_transaction')
      && property(error, 'message') === 'BANK_NORMALIZED_INPUT_INVALID') {
      record.processorReasonCode = 'BANK_NORMALIZED_INPUT_INVALID';
    }
    console.error(JSON.stringify(record));
  } catch { /* Logging must never change transaction/HTTP behavior. */ }
}

export function logDatabaseFailure(stage: DiagnosticStage, error: unknown): void {
  const code = property(error, 'code');
  // Authentication/transport failures before the transaction callback are
  // connection failures; a server error executing BEGIN remains a BEGIN error.
  const connectFailure = stage === 'connect' || (stage === 'begin_transaction'
    && typeof code === 'string'
    && (connectionCodes.has(code) || /^(08|28)[0-9A-Z]{3}$/.test(code)));
  logDiagnostic(connectFailure ? 'BANK_WEBHOOK_DB_CONNECT_FAILED' : 'BANK_WEBHOOK_DB_PROCESSOR_FAILED',
    connectFailure ? 'connect' : stage, error);
}

/** Preserve the client's transaction behavior and the original thrown value. */
export async function observeTransaction<C, T>(
  begin: (work: (connection: C) => Promise<T>) => Promise<T>,
  work: (connection: C, setStage: (stage: DiagnosticStage) => void) => Promise<T>,
): Promise<T> {
  let stage: DiagnosticStage = 'begin_transaction';
  let callbackFailed = false;
  let callbackError: unknown;
  try {
    return await begin(async connection => {
      try {
        const result = await work(connection, next => { stage = next; });
        stage = 'commit';
        return result;
      } catch (error) {
        callbackFailed = true;
        callbackError = error;
        logDatabaseFailure(stage, error);
        stage = 'rollback';
        throw error;
      }
    });
  } catch (error) {
    // Successful rollback rethrows the callback error. A different error is
    // the client's rollback failure and needs its own diagnostic.
    if (!callbackFailed || error !== callbackError) logDatabaseFailure(stage, error);
    throw error;
  }
}
