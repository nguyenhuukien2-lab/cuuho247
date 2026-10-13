import postgres from 'npm:postgres@3.4.7';
import type { BankVerificationStore } from './adapter.ts';
import type { NormalizedBankTransaction } from './normalized.ts';
import { logDiagnostic, observeTransaction } from './diagnostics.ts';
import { mapSePayTestBeneficiary } from './sepay.ts';

interface ProcessorRow {
  outcome: unknown;
}

interface BeneficiaryConfigRow {
  bank_bin: string;
  account_number: string;
}

export interface PostgresVerificationStoreOptions {
  providerScope?: string;
  sePayTestAccountNumber?: string;
}

function parseOutcome(value: unknown): { result: string; changed: boolean } {
  const parsed = typeof value === 'string' ? JSON.parse(value) : value;
  if (parsed == null || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error('invalid_processor_response');
  const row = parsed as Record<string, unknown>;
  if (typeof row.result !== 'string' || typeof row.changed !== 'boolean') throw new Error('invalid_processor_response');
  return { result: row.result, changed: row.changed };
}

export function createPostgresVerificationStore(
  databaseUrl?: string,
  options: PostgresVerificationStoreOptions = {},
): BankVerificationStore {
  if (!databaseUrl) {
    return {
      async processVerifiedTransaction() {
        logDiagnostic('BANK_WEBHOOK_DB_CONNECT_FAILED', 'configuration');
        throw new Error('database_unavailable');
      },
      async recordAuthenticationFailure() { /* No database transport configured. */ },
    };
  }

  // BANK_DATABASE_URL is configured as a server-only Function Secret.
  // A single lazy connection avoids
  // exhausting serverless connection limits. No private schema is exposed over
  // PostgREST and no service-role key is used by this transport.
  const sql = postgres(databaseUrl, {
    max: 1,
    connect_timeout: 10,
    idle_timeout: 20,
    prepare: false,
    // postgres defaults to console.log for server NOTICE objects; those may
    // contain SQL data and are deliberately excluded from diagnostics.
    onnotice: () => {},
  });

  return {
    async processVerifiedTransaction(transaction: NormalizedBankTransaction) {
      return await observeTransaction<postgres.TransactionSql, { result: string; changed: boolean }>(
        work => sql.begin(work), async (transactionSql, setStage) => {
        setStage('statement_timeout');
        await transactionSql`set local statement_timeout = '10s'`;
        let processorTransaction: Readonly<NormalizedBankTransaction> = transaction;
        if (options.providerScope === 'sepay_test') {
          setStage('beneficiary_mapping');
          const configured = await transactionSql<BeneficiaryConfigRow[]>`
            select bank_bin, account_number
            from private.payment_bank_config
            where singleton
              and verification_enabled
              and verification_provider = ${transaction.provider}
              and verification_scope = ${transaction.provider_scope}
              and require_beneficiary
          `;
          if (configured.length !== 1) throw new Error('test_beneficiary_mapping_unavailable');
          processorTransaction = mapSePayTestBeneficiary(transaction, {
            providerScope: options.providerScope,
            testAccountNumber: options.sePayTestAccountNumber,
            configuredBeneficiary: {
              bankBin: configured[0].bank_bin,
              accountNumber: configured[0].account_number,
            },
          });
        }
        setStage('processor_call');
        const rows = await transactionSql<ProcessorRow[]>`
          select private.process_verified_bank_transaction(${transactionSql.json({ ...processorTransaction })}::jsonb) as outcome
        `;
        setStage('processor_result');
        if (rows.length !== 1) throw new Error('invalid_processor_response');
        return parseOutcome(rows[0].outcome);
      });
    },

    async recordAuthenticationFailure(provider: string, scope: string, bodySha256: string) {
      await observeTransaction<postgres.TransactionSql, void>(
        work => sql.begin(work), async (transactionSql, setStage) => {
        setStage('statement_timeout');
        await transactionSql`set local statement_timeout = '10s'`;
        setStage('auth_audit_call');
        await transactionSql`
          select private.record_bank_auth_failure(${provider}::text, ${scope}::text, ${bodySha256}::text)
        `;
      });
    },
  };
}
