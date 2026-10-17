import { expect, test } from '@playwright/test'
import { monitoringSession } from './monitoringFixtures'

test('renders health summary, all sections and server-side channel status', async ({ page }) => {
  await monitoringSession(page)
  await page.goto('/monitoring')
  await expect(page.getByRole('heading', { name: 'Giám sát hệ thống' })).toBeVisible()
  await expect(page.getByRole('tab')).toHaveCount(6)
  await expect(page.getByText('Nghiêm trọng', { exact: true })).toBeVisible()
  await expect(page.locator('.monitor-metric')).toHaveCount(8)
  await expect(page.locator('.monitor-metric').filter({ hasText: 'Webhook 4xx' })).toContainText('3')
  await expect(page.getByText('Admin Web', { exact: true })).toBeVisible()
  await expect(page.getByText('Cần cấu hình server')).toHaveCount(2)
  await expect(page.locator('body')).not.toContainText('body_sha256')
  await expect(page.locator('body')).not.toContainText('raw payload')
})

test('filters alerts, opens safe details and acknowledges through guarded RPC', async ({ page }) => {
  const state = await monitoringSession(page)
  await page.goto('/monitoring')
  await page.getByRole('tab', { name: /Nhật ký cảnh báo/ }).click()
  await page.getByLabel('Lọc mức độ').selectOption('warning')
  await expect(page.getByRole('row')).toHaveCount(2)
  await page.getByRole('button', { name: 'Chi tiết' }).click()
  await expect(page.getByRole('dialog').getByRole('heading', { name: 'Đối tác online mất tín hiệu' })).toBeVisible()
  await expect(page.getByText(/Đã xác nhận lúc/)).toBeVisible()
  await page.getByRole('button', { name: 'Đóng chi tiết' }).click()
  await page.getByLabel('Lọc mức độ').selectOption('critical')
  await page.getByLabel('Tìm cảnh báo').fill('máy chủ')
  await expect(page.getByRole('row')).toHaveCount(2)
  await page.getByRole('button', { name: 'Chi tiết' }).click()
  await page.getByRole('button', { name: 'Xác nhận đã tiếp nhận' }).click()
  await expect(page.getByRole('dialog')).toHaveCount(0)
  const ack = state.calls.find((call) => call.name === 'admin_acknowledge_system_alert')
  expect(ack?.body.p_alert_key).toBe('webhook:500_burst')
  expect(ack?.body.p_fingerprint).toBe('a'.repeat(64))
  expect(ack?.body.p_operation_id).toMatch(/^[0-9a-f-]{36}$/)
})

test('renders payment, webhook, rescue and security event drawers without sensitive fields', async ({ page }) => {
  await monitoringSession(page)
  await page.goto('/monitoring')
  for (const [tab, code] of [['Thanh toán', 'amount_mismatch'], ['Webhook', 'invalid_signature'], ['Cứu hộ', 'active_rescue_request'], ['Bảo mật', 'account_control']]) {
    await page.getByRole('tab', { name: tab, exact: true }).click()
    await expect(page.getByText(code, { exact: true })).toBeVisible()
    await page.getByRole('button', { name: 'Chi tiết' }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await expect(page.getByRole('dialog')).not.toContainText(/secret|signature value|payload|account_number/i)
    await page.getByRole('button', { name: 'Đóng chi tiết' }).click()
  }
})

test('fails closed for a restricted admin and never renders backend details', async ({ page }) => {
  const state = await monitoringSession(page)
  state.readError = true
  await page.goto('/monitoring')
  await expect(page.getByRole('alert')).toContainText('Bạn không có quyền xem Giám sát hệ thống.')
  await expect(page.locator('body')).not.toContainText('PRIVATE_ROLE_DETAIL')
})

test('mobile layout keeps monitoring navigation and drawer usable', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await monitoringSession(page)
  await page.goto('/monitoring')
  await page.getByRole('tab', { name: 'Webhook', exact: true }).click()
  await page.getByRole('button', { name: 'Chi tiết' }).click()
  await expect(page.getByRole('dialog')).toBeVisible()
  await expect(page.getByRole('button', { name: 'Đóng chi tiết' })).toBeVisible()
  await page.getByRole('button', { name: 'Đóng chi tiết' }).click()
})

test('missing production RPC shows safe unavailable state and retry sends the same named parameters', async ({ page }) => {
  const state = await monitoringSession(page)
  state.failure = { status: 404, code: 'PGRST202' }
  await page.goto('/monitoring')
  await expect(page.getByRole('alert')).toContainText('Dịch vụ giám sát chưa sẵn sàng.')
  await expect(page.locator('.monitor-metric')).toHaveCount(0)
  await expect(page.locator('body')).not.toContainText(/PRIVATE_|PGRST202|schema cache/)
  const before = state.calls.filter((call) => call.name === 'admin_get_system_monitoring').length
  state.failure = null
  await page.getByRole('alert').getByRole('button', { name: 'Tải lại' }).click()
  await expect(page.locator('.monitor-metric')).toHaveCount(8)
  const reads = state.calls.filter((call) => call.name === 'admin_get_system_monitoring')
  expect(reads.length).toBeGreaterThan(before)
  expect(reads.every((call) => JSON.stringify(call.body) === JSON.stringify({ p_window_hours: 24, p_limit: 100 }))).toBe(true)
})

for (const failure of [
  { status: 500, code: '42703' }, // schema drift
  { status: 500, code: '25006' }, // STABLE function attempted a write
  { status: 300, code: 'PGRST203' }, // ambiguous overload
  { status: 503, code: 'PGRST002' }, // backend/schema cache unavailable
]) {
  test(`sanitizes backend failure ${failure.code}`, async ({ page }) => {
    const state = await monitoringSession(page)
    state.failure = failure
    await page.goto('/monitoring')
    await expect(page.getByRole('alert')).toContainText('Dịch vụ giám sát tạm thời không khả dụng.')
    await expect(page.locator('body')).not.toContainText(/PRIVATE_/)
    await expect(page.locator('.monitor-health')).toHaveCount(0)
  })
}

test('expired authentication asks for login without exposing the backend message', async ({ page }) => {
  const state = await monitoringSession(page)
  state.failure = { status: 401, code: 'PGRST301' }
  await page.goto('/monitoring')
  await expect(page.getByRole('alert')).toContainText('Vui lòng đăng nhập lại.')
  await expect(page.locator('body')).not.toContainText(/PRIVATE_/)
})

test('network failure is safe and retry recovers', async ({ page }) => {
  await monitoringSession(page)
  await page.route('**/rest/v1/rpc/admin_get_system_monitoring', (route) => route.abort('failed'), { times: 1 })
  await page.goto('/monitoring')
  await expect(page.getByRole('alert')).toBeVisible()
  await expect(page.locator('.monitor-health')).toHaveCount(0)
  await page.getByRole('alert').getByRole('button', { name: 'Tải lại' }).click()
  await expect(page.locator('.monitor-metric')).toHaveCount(8)
})

for (const shape of ['null', 'missing-summary', 'bad-counter', 'missing-events', 'bad-alert', 'bad-status']) {
  test(`rejects incompatible DTO: ${shape}`, async ({ page }) => {
    const state = await monitoringSession(page)
    const data = structuredClone(state.data) as unknown as Record<string, unknown>
    if (shape === 'missing-summary') delete data.summary
    if (shape === 'bad-counter') (data.summary as Record<string, unknown>).pending_payments = '4'
    if (shape === 'missing-events') delete data.webhook_events
    if (shape === 'bad-alert') data.alerts = [{ severity: 'critical' }]
    if (shape === 'bad-status') (data.summary as Record<string, unknown>).overall_status = 'unknown'
    state.response = shape === 'null' ? null : data
    await page.goto('/monitoring')
    await expect(page.getByRole('alert')).toContainText('Dữ liệu giám sát chưa hợp lệ.')
    await expect(page.locator('.monitor-health')).toHaveCount(0)
  })
}

test('shows loading until a valid empty snapshot arrives', async ({ page }) => {
  const state = await monitoringSession(page)
  let release!: () => void
  state.waitForRead = new Promise<void>((resolve) => { release = resolve })
  state.data.alerts = []
  state.data.webhook_events = []
  state.data.summary.open_alerts = 0
  state.data.summary.critical_alerts = 0
  state.data.summary.overall_status = 'healthy'
  await page.goto('/monitoring')
  await expect(page.getByRole('status')).toContainText('Đang tải dữ liệu...')
  await expect(page.locator('.monitor-health')).toHaveCount(0)
  release()
  await expect(page.getByText('Không có cảnh báo phù hợp.')).toBeVisible()
  await page.getByRole('tab', { name: 'Webhook', exact: true }).click()
  await expect(page.getByText('Không có sự kiện bất thường trong khoảng thời gian này.')).toBeVisible()
})

test('permission loss on refresh hides stale metrics, badges and the open drawer', async ({ page }) => {
  const state = await monitoringSession(page)
  await page.goto('/monitoring')
  await page.getByRole('button', { name: 'Chi tiết' }).first().click()
  await expect(page.getByRole('dialog')).toBeVisible()
  state.readError = true
  await page.evaluate(() => window.dispatchEvent(new Event('focus')))
  await expect(page.getByRole('alert')).toContainText('Bạn không có quyền xem Giám sát hệ thống.')
  await expect(page.getByRole('dialog')).toHaveCount(0)
  await expect(page.locator('.monitor-metric')).toHaveCount(0)
  await expect(page.locator('.monitor-tabs span')).toHaveCount(0)
  await expect(page.locator('.monitor-updated')).toContainText('Chưa tải')
})
