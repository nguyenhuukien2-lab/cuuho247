# SePay Live final production preflight

PRODUCTION PREFLIGHT: **PASS**

Production observations completed at **2026-10-15 16:51:29 UTC**. All application
database queries ran inside `BEGIN ... READ ONLY`, with a 15-second statement
timeout, and ended with `ROLLBACK`. No migration, deployment, db push, commit,
webhook delivery, payment/intent creation, or money transfer was performed.
Implementation files were not changed in this preflight.

## New migration

`backend/supabase/migrations/202610150002_vietinbank_sepay_transfer_description.sql`

This is the only pending migration. All 25 predecessors have matching local and
production versions and names, including `202610140001` and `202610150001`.

## Read-only production verification

| Check | Result |
| --- | --- |
| Predecessor migration history, versions and names | PASS: 25 aligned |
| New migration local only / remote pending | PASS: 202610150002 only |
| Provider / scope | PASS: sepay / sepay_live |
| Bank payments enabled | PASS: true |
| Verification enabled | PASS: true |
| require_beneficiary | PASS: true |
| VietinBank BIN and canonical reference policy | PASS |
| Existing beneficiary and full configuration fingerprints unchanged | PASS |
| Relevant predecessor function contracts and bodies | PASS: 33 functions |
| Payment/intent/config/receipt/transaction schema | PASS: 8 tables |
| Conflict with System Configuration/Security migrations | NONE |
| Old QR snapshots unchanged during preflight | PASS: 9 rows, same fingerprint |
| Paid payments unchanged during preflight | PASS: 3 rows, same fingerprint |
| Bank transactions unchanged during preflight | PASS: 13 rows, same fingerprint |
| Webhook receipts unchanged during preflight | PASS: 13 rows, same fingerprint |
| Production schema/functions/history/reference sequence unchanged | PASS |
| Edge Function Live secret/config compatibility | PASS |

The catalog comparison used the tested local disposable database and restored
the three predecessor definitions inside a local transaction that was rolled
back. Production functions match canonical source bodies, signatures, return
types, volatility, security mode, search_path and client EXECUTE privileges.
The session/account-state guard remains present in the customer QR getter.

Two observed schema differences were inspected: production uses the names
`payments_pkey1`, `payments_method_check1`, and `payments_status_check1` rather
than unsuffixed names; PostgreSQL also initially displayed `auth.users` with
different qualification. Explicit `search_path=''` resolved the display
difference. Normalizing only those three reviewed names yielded identical
constraints, index definitions/validity, columns, RLS and triggers. None of these
names is referenced by the new migration. No schema repair is needed.

Unchanged fingerprints mean unchanged across this preflight's observations;
they are not a claim that no authorized operator ever changed historical config.
The migration itself contains no top-level application data DML and no settlement
call. It replaces exactly three function definitions. It does not modify old
snapshots, paid payments, bank transactions, receipts or bank configuration.

## New/regenerated behavior only

The new snapshot description is `SEVQR ` plus canonical `BK[0-9]{19}` only for
VietinBank / SePay Live configuration. Canonical transfer_content stays 21 bytes.
Snapshot UPDATE/DELETE remains rejected. New QR memo generation occurs on new
snapshot INSERT, including the existing controlled regeneration flow.

The getter adds the read-only `transfer_description` DTO field for all snapshots:
old snapshots return their original canonical memo; new snapshots return the
SEVQR memo derived from their stored QR. Thus there is an additive read-response
change for old snapshots, but no historical QR rewrite or changed old memo.

## Edge Function compatibility

The deployed `bank-webhook` is ACTIVE, version 31, with `verify_jwt=false` and
application-level SePay HMAC verification. Its downloaded source matches HEAD
for all seven runtime TypeScript files. Six also match the current workspace;
the sole pending runtime difference is the reviewed `sepay.ts` fallback.

The existing names `SEPAY_WEBHOOK_SECRET`, `SEPAY_PROVIDER_SCOPE`,
`SEPAY_BENEFICIARY_BANK_BIN`, and `BANK_DATABASE_URL` are present. The CLI's SHA-256
secret metadata confirms scope `sepay_live` and BIN `970415`, matching production
database configuration. Secret values were not retrieved or printed. The fix
does not alter HMAC, database transport, secret names, or require new secrets.
No synthetic webhook was sent to production for this preflight.

## Exact migration list expected state

Observed using `supabase migration list --linked --workdir backend`:

```text
Local        | Remote
202609300001 | 202609300001
202610010001 | 202610010001
202610010002 | 202610010002
202610010003 | 202610010003
202610010004 | 202610010004
202610010005 | 202610010005
202610020001 | 202610020001
202610040001 | 202610040001
202610050001 | 202610050001
202610050002 | 202610050002
202610100001 | 202610100001
202610100002 | 202610100002
202610100003 | 202610100003
202610100004 | 202610100004
202610100005 | 202610100005
202610110001 | 202610110001
202610110002 | 202610110002
202610110003 | 202610110003
202610120001 | 202610120001
202610120002 | 202610120002
202610130001 | 202610130001
202610130002 | 202610130002
202610130003 | 202610130003
202610140001 | 202610140001
202610150001 | 202610150001
202610150002 |
```

For a separately authorized future `supabase db push --linked --workdir backend`,
the exact expected migration list is:

```text
202610150002_vietinbank_sepay_transfer_description.sql
```

No other migration should be proposed. No `db push` command, including dry-run,
was executed. This expectation is derived from actual remote history and the
local migration directory. It does not deploy the separate Edge/Flutter changes.

## Disposable scan-only QR

- PNG: `tools/.work/sepay-live/scan-test/sepay-scan-only-2000.png`
- SVG: `tools/.work/sepay-live/scan-test/sepay-scan-only-2000.svg`
- Payload: `tools/.work/sepay-live/scan-test/sepay-scan-only-2000.txt`
- Amount: **2000 VND**.
- Bank BIN: `970415`; dummy account: `000000000000` (not the production beneficiary).
- Synthetic reference: `BK9999999999999999999`, exactly 21 characters.
- Expected scanned memo: **`SEVQR BK9999999999999999999`**, exactly **27 ASCII characters**.

```text
00020101021238560010A0000007270126000697041501120000000000000208QRIBFTTA5303704540420005802VN62310827SEVQR BK9999999999999999999630418D7
```

The payload was generated by the actual new encoder in the local disposable DB,
without creating a snapshot, payment, or intent. Independent TLV and CRC16 checks
pass. The QR uses the installed Dart QR library, M correction and a four-module
quiet zone. The PNG is visibly labeled SCAN TEST ONLY / DO NOT PAY.

The synthetic reference was checked absent from all production QR snapshots. Its
numeric suffix exceeds the production sequence's maximum `9223372036854775807`;
the current canonical generator cannot issue it. Production sequence increment
is 1 and cycling is disabled. The dummy account also differs from production.

Use only to inspect the bank app's scanned fields. Do not submit a transfer.
Because the account is deliberately synthetic, an app may reject the account
before showing its memo; that outcome is inconclusive about memo compatibility.

## Deployment decision

SAFE TO DEPLOY: **NO, pending the remaining bank-app scan acceptance gate.**

The production database/configuration/history and Edge compatibility preflight
passes with no implementation blocker. The remaining external check is that the
intended banking app accepts and preserves the full 27-character memo. This
session produced the artifact but cannot claim a banking-app scan occurred.
If that check passes, the reviewed migration and adapter have no identified
production-preflight blocker. Recheck history if production changes meanwhile.

Local evidence is under `tools/.work/sepay-live/`: `production-before.json`,
`production-after.json`, `production-unchanged-check.json`,
`production-secrets-check.json`, `predecessor-catalog.json`,
`catalog-differences.json`, `production-migration-list.txt`, and
`deployed-source-comparison.json`. These contain metadata/fingerprints rather
than secret or beneficiary values. Downloaded code is isolated in
`deployed-source/`; working source was not overwritten.
