# Admin payment UI V1

Date: 2026-10-12. App: `admin_web`. Scope: read-only payment frontend.

The four frontend screens now call the read-only Admin Payment V1 RPCs defined by `202610120001_admin_payment_read_api.sql`. No provider integration, deployment, or commit was performed. Runtime database validation remains blocked by the pre-existing GD6C syntax error documented in `admin_payment_backend_implementation.md`.

## Stitch source and layout

Project: `4094609055269816912`. All four screens were retrieved with Stitch MCP `get_screen`; their HTML and screenshots were downloaded and inspected.

| Screen | Stitch ID | Route |
| --- | --- | --- |
| Quản lý thanh toán - Tổng quan | `f128302ff4a84c749936b253fba2ae4e` | `/payments` |
| Danh sách thanh toán | `abd58b54b9bf44009d4d130dcfbb54f0` | `/payments/list` |
| Chi tiết thanh toán | `78126fe966f74249892219f1f7c45552` | `/payments/:paymentId` |
| Giao dịch ngân hàng | `000a41e549d0414c8e1433793e66f628` | `/payments/bank-transactions` |

Reference analysis and implementation:

- Shared dark sidebar, light topbar, pale surface, white rounded cards, blue emphasis, compact tables and colored status badges. Reused the existing Admin shell and `--admin-*` tokens, Inter/Plus Jakarta Sans fonts, `PageHeader`, `StatCard`, `SectionCard`, `DataTable`, `KeyValues`, `StatusBadge`, `EmptyState`, and `ReloadButton`. No second design system or chart package.
- Overview: six KPI cards, wide time-series area chart with narrower method-share card, recent payments table underneath. KPI grid has six columns on wide desktop, three on intermediate desktop, and two on mobile. Series is supplied by the future server contract, never synthesized from a paginated list. The method share uses the returned cash/bank aggregates. No fake trend percentages.
- List: four summary cards, search/method/status/date/amount filters, wide table, previous/next pagination. Summary fields are optional server aggregates for the entire filtered result, never page sums. Missing aggregates render `—`.
- Detail: amount/status banner; identification, method-specific information, linked request and two person cards on the left; audit timeline on the right. The columns stack on smaller screens. Unlike the design example, only the actual payment method's block is shown; no sample `PAY-2024-0086` is embedded in application code.
- Bank: five summary cards above filters and provider transaction table. Only sanitized provider, transaction/payment/request identifiers, amount, reference, timestamp and match/verification outcomes can render. The design's raw webhook drawer and operational actions are excluded from read-only V1.
- The sidebar now follows the Stitch payment group: `Quản lý Thanh toán` expands to exactly `Tổng quan`, `Danh sách thanh toán`, and `Giao dịch ngân hàng`. The group opens on payment routes and highlights the current screen; detail highlights the list as its parent section. Detail opens from table actions/links and has no sidebar entry. No payment reconciliation, log, or configuration entries are exposed. The former content tabs are removed. Existing routes, topbar, lazy loading and `AdminRoute` are preserved. Styling lives in `src/styles/payment-navigation.css` (this file was absent in the checkout when navigation work resumed).

## Implemented behavior

Overview exposes total confirmed amount, confirmed cash, confirmed bank, pending count, verifying count and review count. Money is formatted from integer strings using `BigInt`; absent values are not zero. The chart includes a readable table of exact daily amounts. Values outside JavaScript's safe integer range use the table instead of an imprecise chart. A genuine server zero remains zero.

List columns: payment code/ID, request code/ID, customer, rescuer, method, expected amount, received amount, status, paid time, updated time, detail link. Filters apply on form submission/Enter and validate date order and nonnegative integer bounds. Clear resets filters and pagination. Search is trimmed; bigint amount bounds remain strings. Pagination sends limit 20 plus an opaque cursor and tracks prior cursors. Applying filters resets to page one; there is no client-side filtering over a partial result.

Detail obtains its key from `useParams().paymentId`, passes it to the adapter, and builds links using the returned payment ID. The adapter boundary can accept a code only if a reviewed future API supports resolving one. Displays payment ID/code/request/method/status/expected/received/created/paid/updated/version, request service/vehicle/status/completion, explicitly selected person fields, and sanitized timeline entries. Cash confirmation actor/time appear only for cash with backend status `paid`. Awaiting cash never shows a confirmation just because a field is present. Bank states such as `BLOCKED` remain backend states and are not converted to payment failure or success.

Supports `pending`, `awaiting_payment`, `verifying`, `paid`, `failed`, `cancelled`, `expired`; also preserves `refunded`, which exists in the local payment schema. Unknown payment status is displayed neutrally. Filter options are vocabulary, not fabricated payment records. No status is inferred from time, receipt amount, network failure or a provider transaction.

All four pages have loading skeletons, empty states, generic error + retry, permission denied + retry, and a distinct backend-unavailable notice. On errors or permission loss, previously loaded financial content is hidden. Backend-unavailable views show an explanatory notice and empty structural UI, with no fake KPI amounts or transaction rows. Requests are abortable through `useAdminData`; there is no payment/private realtime subscription. Existing hook polling/focus refresh only repeats the same permitted adapter operation.

## Backend connection

The production adapter calls these exact read-only RPCs with the current authenticated Supabase session:

```text
admin_get_payment_overview
admin_list_payments
admin_get_payment_detail
admin_list_bank_transactions
```

Each RPC performs the finance/super-admin check on the server through `private.admin_require_role`. The browser role check remains useful for presentation but is not the security boundary. SQL permission errors `42501` map to `ADMIN_PAYMENT_PERMISSION_DENIED`; network and other server errors map to a generic retryable load error. The adapter does not query `payments`, `payment_events`, or any private table directly and has no write operation.

The overview uses server aggregates and chart buckets. List and bank screens send validated filters and opaque keyset cursors. Detail sends only the routed payment UUID. The adapter maps an explicit field allowlist and ignores extra response fields.

The migration and complete security contract are documented in `docs/admin_payment_backend_implementation.md`. The frontend source is connected to the real RPC contract. No API was deployed, and fresh-chain backend execution is currently blocked by the unchanged syntax defect in the older GD6C migration.
## Security and scope

- No `from('payments')`, `payment_events`, `private.bank_transactions`, `.schema('private')`, payment writes or RLS bypass in the module.
- No service-role client, provider integration, mark-paid, confirm-cash, confirm-bank, amount-edit or delete-payment action.
- Response objects are not dumped with JSON rendering. Components render only selected fields; tests put secret canaries into extra top-level, bank and audit metadata fields and assert they do not render. A future server must still exclude these fields before sending any response.
- The existing `AdminRoute` and Supabase client were reused without changing authorization behavior for other Admin modules.
- No customer/rescuer app edits, database migrations, deploys or commits. The workspace already contained unrelated modifications and partial payment helper files; those changes were preserved and only the module scope was extended.

## Responsive validation

Playwright covers all four screens at **1920, 1440, 1366, 1024 and 390 px**. Assertions verify document width stays within the viewport, table containers remain inside the page and overflowing tables can scroll horizontally. Detail/chart columns stack, filters collapse to two then one column, and the existing mobile drawer remains functional. Tests generate 20 full-page screenshots under `admin_web/test-results/payments-four-payment-screens-responsive-at-*`. Desktop overview and mobile detail were also visually inspected against the Stitch layout. This is responsive adaptation to the existing Admin system; the source Stitch shell itself uses fixed desktop offsets.

## Tests, lint and build

Package manager: npm (`admin_web/package-lock.json`). `npm test` and `npm run test:e2e` both run the existing Playwright suite.

New tests are in `tests/payments.spec.ts`, with fixture data and test-only module substitution in `tests/paymentFixtures.ts`.

- Production adapter tests cover all four real RPC calls, auth redirects, finance denial/retry, permission-RPC errors, allowlisted network calls, mapped server responses, and absence of payment mutations/private queries.
- Fixture component/route tests cover six overview KPIs, chart/share/recent data, exact money, date range, list filters/validation/Enter, server cursor pagination including previous-then-next and filter reset, routed detail IDs, safe fields, cash confirmation, bank `BLOCKED`/awaiting/verifying/paid/expired, supported status mapping, provider rows, stale data hidden on error/denial, loading/empty/error/retry and the responsive matrix.
- Fixture API substitution is implemented by Playwright intercepting the development module request. It exists only in tests; no fixture flag, endpoint, bypass, mock provider or operational sample data is imported into production source.
- `npm test`: **PASS — 35/35** (29 payment tests + 6 existing Admin tests), Edge headless, approximately 1.6 minutes. Navigation coverage includes the exact three submenu entries, keyboard collapse/expand, hidden links skipped by Tab, direct detail/reload, action links from list/bank, browser Back/Forward, and mobile drawer close/focus restoration. Desktop and mobile sidebar screenshots were inspected against the saved Stitch reference.
- `npm run lint`: **PASS**, no warnings or errors in the final run.
- `npm run build`: **PASS** (`tsc -b && vite build`). Vite reports a size warning for the shared main chunk (~554 kB minified); payment pages are lazy chunks. No unrelated bundle restructuring was done.

## Files changed by this task

Paths relative to the repository root; edits to existing dirty files are limited to payment integration.

```text
admin_web/src/app/lazyPages.tsx
admin_web/src/app/router.tsx
admin_web/package.json
admin_web/src/main.tsx
admin_web/src/components/layout/PaymentNavigation.tsx
admin_web/src/components/layout/Sidebar.tsx
admin_web/src/components/layout/Topbar.tsx
admin_web/src/components/payments/PaymentUI.tsx
admin_web/src/components/payments/PaymentCharts.tsx
admin_web/src/hooks/usePaymentQuery.ts
admin_web/src/lib/paymentApi.ts
admin_web/src/lib/paymentTypes.ts
admin_web/src/lib/paymentFormat.ts
admin_web/src/pages/PaymentOverviewPage.tsx
admin_web/src/pages/PaymentListPage.tsx
admin_web/src/pages/PaymentDetailPage.tsx
admin_web/src/pages/BankTransactionsPage.tsx
admin_web/src/styles/payments.css
admin_web/src/styles/payment-navigation.css
admin_web/tests/paymentFixtures.ts
admin_web/tests/payments.spec.ts
docs/admin_payment_ui_implementation.md
```

Downloaded Stitch references are scratch artifacts in `.tmp/admin-payment-stitch/`; build output and Playwright screenshots are generated artifacts, not source changes.

## Completion boundary

Sidebar/routes, all four frontend presentations, the read-only migration, and frontend RPC connection are implemented. No production API availability or provider readiness is inferred from local source. Fresh-chain backend execution remains blocked at the unchanged GD6C syntax error, so the new migration and SQL regression are not reported as runtime-passing. No deployment or commit was performed.
