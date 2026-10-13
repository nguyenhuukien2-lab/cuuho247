# GD6C bank verification boundary

**BLOCKED ON REAL PROVIDER INTEGRATION.** The endpoint is an inactive Supabase
Edge Function shell. Every well-formed POST returns 503; it never acknowledges
a payment, writes an incoming transaction, or calls the private processor.
No config/environment switch can enable it. No production deployment performed.

`adapter.ts` defines the future server-only provider and store interfaces.
`normalized.ts` validates internal data, not webhook authenticity. Its boolean
flags must never be populated from public JSON. No signature algorithm is
implemented without a selected provider's official authentication contract.

Server sequence after real integration: limit body -> authenticate exact bytes
and provider timestamp/account -> normalize final credit -> hash exact bytes ->
private processor transaction commit -> provider-specific acknowledgement.
Authentication failure -> private auth-failure audit with hash only -> reject.
The failed delivery must not reserve a canonical event ID. Body hashes alone
are not authentication. No raw payload, headers, sender PII or secrets retained.

The migration grants no API role access, including service_role. Do not expose
the private schema via PostgREST. Real integration needs a reviewed least-
privilege database transport/role and provider-specific response/retry policy.
Keep Supabase's default JWT gateway behavior until the real provider contract
establishes the appropriate ingress authentication; no `verify_jwt=false` here.

Tests: `node --test backend/supabase/functions/bank-webhook/*_test.ts` (Node 24).
These are boundary tests and internal synthetic normalization fixtures only;
they are not invented provider payloads, signature fixtures or live bank calls.
