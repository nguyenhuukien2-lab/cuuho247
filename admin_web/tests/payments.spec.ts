import { expect, test } from '@playwright/test'
import { readFileSync } from 'node:fs'
import { bankPage, overview, payment, paymentFixtureApi, paymentId, paymentSession, timestamp } from './paymentFixtures'

const screens = [
  { path: '/payments', title: 'Quản lý thanh toán', kind: 'overview' },
  { path: '/payments/list', title: 'Danh sách thanh toán', kind: 'list' },
  { path: '/payments/' + paymentId, title: 'Chi tiết thanh toán', kind: 'detail' },
  { path: '/payments/bank-transactions', title: 'Giao dịch ngân hàng', kind: 'bank' },
  { path: '/payments/operations', title: 'Vận hành thanh toán', kind: 'operations' },
]

test('production routes call only allowlisted payment RPCs and render their data', async ({ page }) => {
  const state = await paymentSession(page)
  const rpcByKind: Record<string, string> = {
    overview: '/rest/v1/rpc/admin_get_payment_overview',
    list: '/rest/v1/rpc/admin_list_payments',
    detail: '/rest/v1/rpc/admin_get_payment_detail',
    bank: '/rest/v1/rpc/admin_list_bank_transactions',
    operations: '/rest/v1/rpc/admin_list_payment_reconciliation',
  }
  for (const screen of screens) {
    await page.goto(screen.path)
    await expect(page.locator('.page-header h1')).toBeVisible()
    await expect.poll(() => state.calls.some((call) => call.path === rpcByKind[screen.kind])).toBe(true)
    await expect(page.getByRole('button', { name: /mark paid|xác nhận.*tiền|đánh dấu|xóa thanh toán|sửa.*tiền/i })).toHaveCount(0)
    await expect(page.locator('tbody tr, .payment-detail-grid, .payment-chart').first()).toBeVisible()
    await expect(page.locator('.side-nav a.active')).toBeVisible()
    await expect(page.locator('#payment-submenu a')).toHaveCount(4)
    await expect(page.locator('main nav')).toHaveCount(0)
  }
  const backendCalls = state.calls.filter((call) => call.path.startsWith('/rest/'))
  const allowed = ['/rest/v1/rpc/is_admin', '/rest/v1/rpc/has_admin_role', '/rest/v1/admin_profiles',
    '/rest/v1/rpc/admin_get_payment_overview', '/rest/v1/rpc/admin_list_payments',
    '/rest/v1/rpc/admin_get_payment_detail', '/rest/v1/rpc/admin_list_bank_transactions',
    '/rest/v1/rpc/admin_list_payment_reconciliation', '/rest/v1/rpc/admin_list_payment_refunds',
    '/rest/v1/rpc/admin_get_payment_operations_report']
  expect(backendCalls.length).toBeGreaterThan(0)
  expect(backendCalls.every((call) => allowed.includes(call.path))).toBe(true)
  expect(backendCalls.filter((call) => call.path.endsWith('/has_admin_role')).every((call) => JSON.stringify(call.body) === JSON.stringify({ required_roles: ['super_admin', 'finance'] }))).toBe(true)
  expect(state.calls.every((call) => !JSON.stringify(call.headers).includes('service_role') && !JSON.stringify(call.headers).includes('private'))).toBe(true)
  const source = readFileSync('src/lib/paymentApi.ts', 'utf8')
  expect(source).not.toMatch(/\.from\(|\.schema\(|\.insert\(|\.update\(|\.delete\(|import\.meta\.env|__payment_test__/)
})

test('an aborted lifecycle signal cannot suppress payment RPC dispatch', async ({ page }) => {
  const state = await paymentSession(page)
  await page.goto('/payments')
  await expect(page.locator('.payment-chart')).toBeVisible()
  const before = state.calls.filter((call) => call.path.endsWith('/admin_get_payment_overview')).length
  const result = await page.evaluate(async () => {
    const api = await import('/src/lib/paymentApi.ts')
    const controller = new AbortController()
    controller.abort()
    return api.getPaymentOverview({ from: '', to: '' }, controller.signal)
  })
  await expect.poll(() => state.calls.filter((call) => call.path.endsWith('/admin_get_payment_overview')).length).toBe(before + 1)
  expect(result.error).toBe('REQUEST_ABORTED')
})

for (const screen of screens) {
  test(`${screen.kind}: login required`, async ({ page }) => {
    await paymentSession(page, false)
    await page.goto(screen.path)
    await expect(page).toHaveURL(/\/login$/)
  })
  test(`${screen.kind}: finance permission denied`, async ({ page }) => {
    const state = await paymentSession(page)
    state.finance = false
    await page.goto(screen.path)
    await expect(page.getByRole('alert')).toContainText('Không có quyền xem thanh toán')
    await expect(page.locator('.stat-grid, .payment-detail-grid, table')).toHaveCount(0)
    state.finance = true
    await page.getByRole('alert').getByRole('button', { name: 'Tải lại' }).click()
    await expect(page.locator('tbody tr, .payment-detail-grid, .payment-chart').first()).toBeVisible()
  })
  test(`${screen.kind}: skeleton, empty, network error and retry`, async ({ page }) => {
    await paymentSession(page)
    const state = await paymentFixtureApi(page)
    state.delay = 600
    state.overview = { ...overview, total_paid: '0', cash_paid: '0', bank_paid: '0', pending_count: 0, verifying_count: 0, review_count: 0, recent: [], series: [] }
    state.list = { rows: [], total: 0, next_cursor: null }
    state.detail = null
    state.bank = { rows: [], total: 0, next_cursor: null }
    state.operations = { report: { bank_total: '0', cash_total: '0', refund_total: '0', paid_count: 0, unpaid_count: 0, rejected_transactions: 0, late_payments: 0, refund_pending: 0 }, reconciliation: { rows: [], total: null, next_cursor: null }, refunds: [] }
    await page.goto(screen.path)
    await expect(page.getByRole('status', { name: 'Đang tải thanh toán' })).toBeVisible()
    await expect(page.locator('.empty-state').first()).toBeVisible()
    await expect(page.locator('tbody tr')).toHaveCount(0)
    if (screen.kind === 'overview') await expect(page.locator('.stat-card').first().locator('.stat-value')).toHaveText('0 ₫')
    state.delay = 0
    state.error = 'NETWORK_ERROR with PRIVATE_ERROR_MUST_NOT_RENDER'
    await page.locator('.page-header').getByRole('button', { name: 'Tải lại' }).click()
    await expect(page.getByRole('alert')).toContainText('Không thể tải dữ liệu thanh toán')
    await expect(page.locator('main')).not.toContainText('PRIVATE_ERROR_MUST_NOT_RENDER')
    await expect(page.locator('.status-badge')).toHaveCount(0)
    state.error = null
    await page.getByRole('alert').getByRole('button', { name: 'Tải lại' }).click()
    await expect(page.locator('.empty-state').first()).toBeVisible()
  })
}

test('payment RPC failures do not become payment failures and 42501 means forbidden', async ({ page }) => {
  const state = await paymentSession(page)
  state.rpcError = 500
  await page.goto('/payments')
  await expect(page.getByRole('alert')).toContainText('Không thể tải dữ liệu thanh toán')
  await expect(page.locator('main')).not.toContainText('PRIVATE_ERROR_MUST_NOT_RENDER')
  state.rpcError = 403
  await page.getByRole('alert').getByRole('button', { name: 'Tải lại' }).click()
  await expect(page.getByRole('alert')).toContainText('Không có quyền xem thanh toán')
})

test('overview renders server aggregates, chart and recent payments, and passes date range', async ({ page }) => {
  await paymentSession(page)
  const state = await paymentFixtureApi(page)
  await page.goto('/payments')
  await expect(page.locator('.stat-value')).toHaveText(['1.200.000 ₫', '900.000 ₫', '300.000 ₫', '3', '2', '1'])
  await expect(page.locator('.payment-chart')).toBeVisible()
  await expect(page.locator('.status-donut strong')).toHaveText('25%')
  await page.getByText('Xem số liệu theo ngày', { exact: true }).click()
  await expect(page.locator('.payment-chart-data tbody tr')).toHaveCount(2)
  await expect(page.locator('.section-card').filter({ hasText: 'Thanh toán gần đây' })).toContainText('TT-000123')
  await page.getByLabel('Thống kê từ ngày').fill('2026-10-01')
  await page.getByLabel('Thống kê đến ngày').fill('2026-10-12')
  await page.getByRole('button', { name: 'Áp dụng thời gian' }).click()
  await expect.poll(() => state.calls.at(-1)?.query).toEqual({ from: '2026-10-01', to: '2026-10-12' })
})

test('payment list applies all filters, preserves bigint bounds, and uses server cursors', async ({ page }) => {
  await paymentSession(page)
  const state = await paymentFixtureApi(page)
  await page.goto('/payments/list')
  await expect(page.locator('tbody')).toContainText('TT-000123')
  await page.getByLabel('Tìm mã thanh toán, yêu cầu, tên').fill('  TT-000123  ')
  await page.getByLabel('Phương thức', { exact: true }).selectOption('cash')
  await page.getByLabel('Trạng thái', { exact: true }).selectOption('paid')
  await page.getByLabel('Tạo từ ngày').fill('2026-10-01')
  await page.getByLabel('Tạo đến ngày').fill('2026-10-12')
  await page.getByLabel('Dự kiến tối thiểu (VND)').fill('0')
  await page.getByLabel('Dự kiến tối đa (VND)').fill('9223372036854775807')
  await page.getByRole('button', { name: 'Áp dụng bộ lọc' }).click()
  await expect.poll(() => state.calls.at(-1)?.query).toEqual({ search: 'TT-000123', method: 'cash', status: 'paid', from: '2026-10-01', to: '2026-10-12', minAmount: '0', maxAmount: '9223372036854775807', cursor: null, limit: 20 })
  await expect(page.getByRole('button', { name: 'Sau', exact: true })).toBeEnabled()
  await page.getByRole('button', { name: 'Sau', exact: true }).click()
  await expect(page.locator('tbody')).toContainText('TT-000124')
  expect(state.calls.at(-1)?.query.cursor).toBe('cursor-next')
  await expect(page.getByRole('button', { name: 'Sau', exact: true })).toBeDisabled()
  await page.getByRole('button', { name: 'Trước', exact: true }).click()
  await expect(page.locator('tbody')).toContainText('TT-000123')
  await page.getByRole('button', { name: 'Sau', exact: true }).click()
  await expect(page.locator('tbody')).toContainText('TT-000124')
  await page.getByRole('button', { name: 'Xóa bộ lọc' }).click()
  await expect(page.locator('tbody')).toContainText('TT-000123')
  await expect(page.locator('.table-footer')).toContainText('Trang 1')
  expect(state.calls.at(-1)?.query.cursor).toBe(null)
  expect(state.calls.at(-1)?.query.search).toBe('')
})

test('invalid filters are rejected before loading and Enter applies valid filters', async ({ page }) => {
  await paymentSession(page)
  const state = await paymentFixtureApi(page)
  await page.goto('/payments/list')
  await expect(page.locator('tbody')).toContainText('TT-000123')
  const calls = state.calls.length
  await page.getByLabel('Tạo từ ngày').fill('2026-10-12')
  await page.getByLabel('Tạo đến ngày').fill('2026-10-01')
  await page.getByRole('button', { name: 'Áp dụng bộ lọc' }).click()
  await expect(page.getByRole('alert')).toContainText('Ngày kết thúc')
  expect(state.calls).toHaveLength(calls)
  await page.getByLabel('Tạo đến ngày').fill('2026-10-12')
  await page.getByLabel('Dự kiến tối thiểu (VND)').fill('-1')
  await page.getByRole('button', { name: 'Áp dụng bộ lọc' }).click()
  await expect(page.getByRole('alert')).toContainText('số nguyên không âm')
  await page.getByLabel('Dự kiến tối thiểu (VND)').fill('200')
  await page.getByLabel('Dự kiến tối đa (VND)').fill('100')
  await page.getByRole('button', { name: 'Áp dụng bộ lọc' }).click()
  await expect(page.getByRole('alert')).toContainText('Số tiền tối đa')
  expect(state.calls).toHaveLength(calls)
  await page.getByLabel('Dự kiến tối đa (VND)').fill('200')
  await page.getByLabel('Tìm mã thanh toán, yêu cầu, tên').press('Enter')
  await expect.poll(() => state.calls.length).toBe(calls + 1)
})

test('detail uses routed ID, safe fields, cash confirmation and timeline; no admin payment action', async ({ page }) => {
  await paymentSession(page)
  const state = await paymentFixtureApi(page)
  Object.assign(state.detail!, { webhook_secret: 'PRIVATE_CANARY', raw_provider_payload: 'PRIVATE_CANARY', service_role: 'PRIVATE_CANARY', bank_credential: 'PRIVATE_CANARY' })
  Object.assign(state.detail!.events![0], { metadata: { token: 'PRIVATE_CANARY' } })
  await page.goto('/payments/list')
  await page.getByRole('link', { name: 'Xem thanh toán TT-000123' }).click()
  await expect(page).toHaveURL(new RegExp('/payments/' + paymentId + '$'))
  await expect(page.getByRole('heading', { name: 'Chi tiết thanh toán · TT-000123' })).toBeVisible()
  expect(state.calls.at(-1)).toEqual({ kind: 'detail', query: { id: paymentId } })
  await expect(page.locator('.payment-detail-grid')).toContainText('Đối tác xác nhận tiền mặt')
  await expect(page.locator('.payment-detail-grid')).toContainText('12/10/26')
  await expect(page.locator('.payment-timeline')).toContainText('Đối tác xác nhận đã nhận tiền mặt')
  await expect(page.locator('.payment-people')).toContainText('customer@example.test')
  await expect(page.locator('main')).not.toContainText('PRIVATE_CANARY')
  await expect(page.locator('main')).not.toContainText('PAY-2024-0086')
  await expect(page.getByRole('button', { name: /xác nhận|mark paid|đánh dấu|sửa.*tiền|xóa thanh toán/i })).toHaveCount(0)
  await expect(page.getByRole('heading', { name: 'Chi tiết chuyển khoản ngân hàng' })).toHaveCount(0)
  state.detail = { ...payment, status: 'awaiting_payment', paid_at: null, amount_received: null }
  await page.locator('.page-header').getByRole('button', { name: 'Tải lại' }).click()
  await expect(page.getByText('Chưa có xác nhận đã thu tiền mặt.')).toBeVisible()
  await expect(page.getByText('Đối tác xác nhận tiền mặt', { exact: true })).toHaveCount(0)
})

test('paid payment creates only a versioned refund request', async ({ page }) => {
  await paymentSession(page)
  const state = await paymentFixtureApi(page)
  await page.goto('/payments/' + paymentId)
  await page.getByLabel('Số tiền hoàn').fill('100000')
  await page.getByLabel('Lý do hoàn tiền').selectOption('duplicate_payment')
  await page.getByRole('button', { name: 'Tạo yêu cầu hoàn tiền' }).click()
  await expect.poll(() => state.calls.find((call) => call.kind === 'requestPaidRefund')).toMatchObject({ query: {
    amount: '100000', reasonCode: 'duplicate_payment', payment: { id: paymentId, version: '4', status: 'paid' },
  } })
  const operationId = state.calls.find((call) => call.kind === 'requestPaidRefund')?.query.operationId
  expect(typeof operationId).toBe('string')
  await expect(page.getByRole('status')).toContainText('Đã tạo yêu cầu')
  await expect(page.locator('.payment-amount-banner .status-badge')).toHaveText('Đã thanh toán')
})

test('bank detail preserves backend status including BLOCKED and does not infer paid', async ({ page }) => {
  await paymentSession(page)
  const state = await paymentFixtureApi(page)
  state.detail = { ...payment, method: 'bank_transfer', status: 'awaiting_payment', amount_received: null, paid_at: null, cash_confirmation: null, events: null, bank: { state: 'BLOCKED', provider: null, reference: 'TEST-REFERENCE', bank_name: 'Ngân hàng kiểm thử', account_masked: '•••• 1234', expires_at: timestamp } }
  Object.assign(state.detail.bank!, { signature: 'PRIVATE_CANARY', webhook_secret: 'PRIVATE_CANARY', raw_payload: 'PRIVATE_CANARY' })
  await page.goto('/payments/' + paymentId)
  await expect(page.getByRole('heading', { name: 'Chi tiết chuyển khoản ngân hàng' })).toBeVisible()
  await expect(page.locator('.payment-detail-grid')).toContainText('BLOCKED')
  await expect(page.locator('.payment-detail-grid')).toContainText('•••• 1234')
  await expect(page.getByRole('heading', { name: 'Xác nhận tiền mặt' })).toHaveCount(0)
  await expect(page.locator('main')).not.toContainText('PRIVATE_CANARY')
  await expect(page.locator('.status-badge').filter({ hasText: 'Đã thanh toán' })).toHaveCount(0)
  for (const [status, label] of [['verifying', 'Đang xác minh'], ['paid', 'Đã thanh toán'], ['expired', 'Hết hạn']]) {
    state.detail.status = status
    await page.locator('.page-header').getByRole('button', { name: 'Tải lại' }).click()
    await expect(page.locator('.payment-amount-banner .status-badge')).toHaveText(label)
  }
})

test('all status badges reflect supplied status; unknown status is neutral', async ({ page }) => {
  await paymentSession(page)
  const state = await paymentFixtureApi(page)
  const statuses = ['pending', 'awaiting_payment', 'verifying', 'paid', 'failed', 'cancelled', 'expired', 'future_status']
  state.list.rows = statuses.map((status, index) => ({ ...payment, id: 'status-' + index, status }))
  await page.goto('/payments/list')
  await expect(page.locator('tbody tr td:nth-child(8)')).toHaveText(['Đang chờ', 'Chờ thanh toán', 'Đang xác minh', 'Đã thanh toán', 'Thất bại', 'Đã hủy', 'Hết hạn', 'Trạng thái chưa hỗ trợ'])
})

test('bank transactions renders only allowlisted fields and filter requests', async ({ page }) => {
  await paymentSession(page)
  const state = await paymentFixtureApi(page)
  Object.assign(state.bank.rows[0], { secret: 'PRIVATE_CANARY', signature: 'PRIVATE_CANARY', raw_token: 'PRIVATE_CANARY', raw_payload: { secret: 'PRIVATE_CANARY' } })
  await page.goto('/payments/bank-transactions')
  await expect(page.locator('tbody')).toContainText('TEST-TXN-001')
  await expect(page.locator('tbody')).toContainText('Khớp chính xác')
  await expect(page.locator('tbody')).toContainText('Đã xác minh')
  await expect(page.locator('.stat-value')).toHaveText(['1', '1', '0', '0', '0'])
  await expect(page.locator('main')).not.toContainText('PRIVATE_CANARY')
  await page.getByLabel('Tìm mã giao dịch, tham chiếu').fill('TEST-REFERENCE')
  await page.getByLabel('Giao dịch từ ngày').fill('2026-10-01')
  await page.getByLabel('Số tiền tối thiểu (VND)').fill('100000')
  await page.getByRole('button', { name: 'Áp dụng bộ lọc' }).click()
  await expect.poll(() => state.calls.at(-1)?.query.search).toBe('TEST-REFERENCE')
  await page.getByRole('link', { name: 'TT-000123', exact: true }).click()
  await expect(page).toHaveURL(new RegExp('/payments/' + paymentId + '$'))
})

test('payment operations uses controlled reconciliation and refund actions', async ({ page }) => {
  await paymentSession(page)
  const state = await paymentFixtureApi(page)
  await page.goto('/payments/operations')
  await expect(page.getByRole('heading', { name: 'Vận hành thanh toán' })).toBeVisible()
  await expect(page.locator('tbody').first()).toContainText('intent_expired')
  await expect(page.locator('tbody').first()).toContainText('Đã xác thực')
  await expect(page.locator('tbody').first()).toContainText('TT-000123')
  await expect(page.locator('main')).not.toContainText('service_role')
  await expect(page.getByRole('button', { name: /mark paid|đánh dấu.*paid|xác nhận.*đã trả/i })).toHaveCount(0)
  await page.getByLabel('Reference, giao dịch, payment').fill('BK-AAAA')
  await page.getByLabel('Trạng thái đối soát').selectOption('pending')
  await page.getByRole('button', { name: 'Áp dụng', exact: true }).click()
  await expect.poll(() => state.calls.at(-1)).toMatchObject({ kind: 'operations', query: { search: 'BK-AAAA', status: 'pending' } })
  await page.getByRole('button', { name: 'Chuyển sang hoàn tiền' }).click()
  await expect.poll(() => state.calls.some((call) => call.kind === 'resolve' && call.query.resolution === 'refund_required' && typeof call.query.operationId === 'string')).toBe(true)
  await expect(page.getByRole('button', { name: 'Tạo yêu cầu hoàn' })).toBeVisible()
  await page.getByRole('button', { name: 'Tạo yêu cầu hoàn' }).click()
  await expect.poll(() => state.calls.some((call) => call.kind === 'requestRefund' && typeof call.query.operationId === 'string')).toBe(true)
  await expect(page.getByRole('button', { name: 'Duyệt' })).toBeVisible()
})

test('refresh error or permission loss hides previously loaded financial data', async ({ page }) => {
  await paymentSession(page)
  const state = await paymentFixtureApi(page)
  await page.goto('/payments/list')
  await expect(page.locator('tbody')).toContainText('TT-000123')
  for (const error of ['NETWORK_ERROR', 'ADMIN_PAYMENT_PERMISSION_DENIED', 'ADMIN_PAYMENT_BACKEND_BLOCKED']) {
    state.error = error
    await page.locator('.page-header').getByRole('button', { name: 'Tải lại' }).click()
    await expect(page.locator('main')).not.toContainText('TT-000123')
    await expect(page.locator('main')).not.toContainText('24.000.000')
    state.error = null
    await page.locator('.page-header').getByRole('button', { name: 'Tải lại' }).click()
    await expect(page.locator('tbody')).toContainText('TT-000123')
  }
})

for (const width of [1920, 1440, 1366, 1024, 390]) {
  test(`five payment screens responsive at ${width}px`, async ({ page }, testInfo) => {
    test.setTimeout(60_000)
    await page.setViewportSize({ width, height: width === 390 ? 844 : 1080 })
    await paymentSession(page)
    const state = await paymentFixtureApi(page)
    state.bank = structuredClone(bankPage)
    const errors: string[] = []
    page.on('pageerror', (error) => errors.push(error.message))
    for (const screen of screens) {
      await page.goto(screen.path)
      await expect(page.getByRole('heading', { name: screen.title, exact: screen.kind !== 'detail' })).toBeVisible()
      await expect(page.locator('.payment-skeleton')).toHaveCount(0)
      await expect(page.locator('.payment-page .section-card').first()).toBeVisible()
      await page.evaluate(() => document.fonts.ready)
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
      if (screen.kind !== 'detail') {
        const table = page.locator('.payment-page .table-scroll').last()
        expect(await table.evaluate((element) => element.getBoundingClientRect().right <= innerWidth)).toBe(true)
        await table.evaluate((element) => { element.scrollLeft = element.scrollWidth })
        expect(await table.evaluate((element) => element.scrollWidth <= element.clientWidth || element.scrollLeft > 0)).toBe(true)
        await table.evaluate((element) => { element.scrollLeft = 0 })
      }
      await page.screenshot({ path: testInfo.outputPath(`${screen.kind}-${width}.png`), fullPage: true })
    }
    expect(errors).toEqual([])
    if (width === 390) {
      await page.getByRole('button', { name: 'Mở menu' }).click()
      await page.locator('#payment-submenu').getByRole('link', { name: 'Tổng quan', exact: true }).click()
      await expect(page.getByRole('dialog')).toHaveCount(0)
      await expect(page).toHaveURL(/\/payments$/)
    }
  })
}

test('payment sidebar supports keyboard, actions, history and direct detail URLs', async ({ page }) => {
  await paymentSession(page)
  await paymentFixtureApi(page)
  await page.goto('/payments')
  const toggle = page.getByRole('button', { name: 'Quản lý Thanh toán', exact: true })
  const submenu = page.locator('#payment-submenu')
  await expect(toggle).toHaveAttribute('aria-expanded', 'true')
  await toggle.focus()
  await page.keyboard.press('Enter')
  await expect(submenu).toBeHidden()
  await page.keyboard.press('Tab')
  await expect(page.getByRole('link', { name: 'Đánh giá dịch vụ', exact: true })).toBeFocused()
  await toggle.focus()
  await page.keyboard.press('Space')
  await page.keyboard.press('Tab')
  await expect(submenu.getByRole('link', { name: 'Tổng quan', exact: true })).toBeFocused()
  await submenu.getByRole('link', { name: 'Danh sách thanh toán', exact: true }).click()
  await expect(page).toHaveURL(/\/payments\/list$/)
  await page.getByRole('link', { name: 'Xem thanh toán TT-000123' }).click()
  await expect(page).toHaveURL(new RegExp('/payments/' + paymentId + '$'))
  await expect(submenu.locator('a.active')).toHaveText('Danh sách thanh toán')
  await expect(submenu.locator('a.active')).toHaveAttribute('aria-current', 'location')
  await expect(submenu.locator('a')).toHaveCount(4)
  await page.reload()
  await expect(page.getByRole('heading', { name: 'Chi tiết thanh toán · TT-000123' })).toBeVisible()
  await expect(toggle).toHaveAttribute('aria-expanded', 'true')
  await page.getByRole('link', { name: '← Danh sách', exact: true }).click()
  await expect(submenu.locator('a.active')).toHaveAttribute('aria-current', 'page')
  await submenu.getByRole('link', { name: 'Giao dịch ngân hàng', exact: true }).click()
  await expect(page.getByRole('heading', { name: 'Giao dịch ngân hàng', exact: true })).toBeVisible()
  await expect(submenu.locator('a.active')).toHaveText('Giao dịch ngân hàng')
  await page.goBack()
  await expect(submenu.locator('a.active')).toHaveText('Danh sách thanh toán')
  await page.goForward()
  await expect(submenu.locator('a.active')).toHaveText('Giao dịch ngân hàng')
  await page.getByRole('link', { name: 'TT-000123', exact: true }).click()
  await expect(page.getByRole('heading', { name: 'Chi tiết thanh toán · TT-000123' })).toBeVisible()
  await page.locator('.side-nav').getByRole('link', { name: 'Tổng quan', exact: true }).first().click()
  await expect(toggle).toHaveAttribute('aria-expanded', 'false')
  await toggle.click()
  await submenu.getByRole('link', { name: 'Tổng quan', exact: true }).click()
  await expect(page).toHaveURL(/\/payments$/)
})

test('mobile payment submenu closes the drawer and keeps the current section', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await paymentSession(page)
  await paymentFixtureApi(page)
  await page.goto('/payments/' + paymentId)
  const menu = page.getByRole('button', { name: 'Mở menu', exact: true })
  for (const label of ['Giao dịch ngân hàng', 'Danh sách thanh toán', 'Tổng quan']) {
    await menu.click()
    await expect(page.getByRole('button', { name: 'Quản lý Thanh toán' })).toHaveAttribute('aria-expanded', 'true')
    await expect(page.locator('#payment-submenu a')).toHaveCount(4)
    await page.locator('#payment-submenu').getByRole('link', { name: label, exact: true }).click()
    await expect(page.getByRole('dialog')).toHaveCount(0)
    await expect(menu).toBeFocused()
    await expect(page.locator('#payment-submenu a.active')).toHaveText(label)
  }
  await menu.click()
  await page.locator('#payment-submenu').scrollIntoViewIfNeeded()
  await page.screenshot({ path: testInfo.outputPath('payment-sidebar-mobile.png') })
  await page.keyboard.press('Escape')
  await expect(menu).toBeFocused()
  await expect(menu).toHaveAttribute('aria-expanded', 'false')
})
