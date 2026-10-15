import { expect, test } from '@playwright/test'
import type { Page } from '@playwright/test'
import { fixture as systemConfigFixture } from './systemConfigFixtures'

const id = '11111111-1111-4111-8111-111111111111'
const createdAt = '2026-10-04T03:00:00Z'

async function mockSupabase(page: Page, signedIn = true) {
  const user = { id, email: 'admin@example.test', aud: 'authenticated', role: 'authenticated', created_at: createdAt }
  const payload = Buffer.from(JSON.stringify({ sub: id, role: 'authenticated', exp: Math.floor(Date.now() / 1000) + 3600 })).toString('base64url')
  const session = { access_token: `header.${payload}.signature`, refresh_token: 'refresh', expires_in: 3600, expires_at: Math.floor(Date.now() / 1000) + 3600, token_type: 'bearer', user }
  if (signedIn) await page.addInitScript((value) => localStorage.setItem('sb-admin-test-auth-token', JSON.stringify(value)), session)

  const state = {
    views: {} as Record<string, Record<string, unknown>[]>,
    stats: {} as Record<string, unknown>,
    admin: true,
    calls: [] as { name: string; body: Record<string, unknown> }[],
  }

  await page.routeWebSocket('wss://admin-test.supabase.co/**', (socket) => {
    socket.onMessage((raw) => {
      const [join, ref, topic, event, body] = JSON.parse(String(raw))
      if (event === 'phx_join') {
        const bindings = (body.config.postgres_changes ?? []).map((entry: object, index: number) => ({ ...entry, id: index + 1 }))
        socket.send(JSON.stringify([join, ref, topic, 'phx_reply', { status: 'ok', response: { postgres_changes: bindings } }]))
      } else if (event === 'heartbeat' || event === 'phx_leave') {
        socket.send(JSON.stringify([join, ref, topic, 'phx_reply', { status: 'ok', response: {} }]))
      }
    })
  })

  await page.route('https://admin-test.supabase.co/**', async (route) => {
    const request = route.request()
    const url = new URL(request.url())
    const name = url.pathname.split('/').pop()!
    const headers = { 'access-control-allow-origin': '*', 'access-control-expose-headers': 'content-range' }
    const reply = (body: unknown, status = 200, extra = {}) => route.fulfill({ status, contentType: 'application/json', headers: { ...headers, ...extra }, body: JSON.stringify(body) })
    if (url.pathname.startsWith('/auth/v1/')) {
      if (name === 'logout') return route.fulfill({ status: 204, headers })
      return reply(name === 'user' ? user : session)
    }
    if (url.pathname.includes('/rpc/')) {
      if (name === 'is_admin') return reply(state.admin)
      if (name === 'admin_get_dashboard_stats') return reply(state.stats)
      if (name === 'admin_get_system_config') return reply(systemConfigFixture)
      if (name === 'admin_list_system_config_audit') return reply({ rows: [] })
      const body = request.postDataJSON() as Record<string, unknown>
      state.calls.push({ name, body })
      if (name === 'admin_cancel_request') state.views.admin_rescue_requests_view?.forEach((row) => { if (row.request_id === body.request_id) row.status = 'cancelled' })
      if (name === 'admin_toggle_service') state.views.admin_services_view?.forEach((row) => { if (row.service_id === body.service_id) row.is_active = body.is_active })
      return reply({ success: true, changed: true, message: 'Đã cập nhật từ máy chủ' })
    }
    let rows = state.views[name] ?? []
    for (const [key, value] of url.searchParams) if (value.startsWith('eq.')) rows = rows.filter((row) => row[key] === value.slice(3))
    if (request.headers().accept?.includes('vnd.pgrst.object')) return reply(rows[0] ?? null)
    const offset = Number(url.searchParams.get('offset') ?? 0)
    const limit = Math.min(Number(url.searchParams.get('limit') ?? 200), 100)
    const data = rows.slice(offset, offset + limit)
    return reply(data, 200, { 'content-range': data.length ? `${offset}-${offset + data.length - 1}/${rows.length}` : `*/${rows.length}` })
  })
  return state
}

test('bảo vệ route và tự vào dashboard khi session Admin hợp lệ', async ({ page }) => {
  await mockSupabase(page, false)
  await page.goto('/requests')
  await expect(page).toHaveURL(/\/login$/)

  const state = await mockSupabase(page)
  state.stats = { total_customers: 37, total_rescuers: 12, today_requests: 8 }
  await page.goto('/login')
  await expect(page.getByRole('heading', { name: 'Tổng quan hệ thống' })).toBeVisible()
  await expect(page.locator('.stat-card').filter({ hasText: 'Tổng khách hàng' }).locator('.stat-value')).toHaveText('37')
})

test('hủy đơn chỉ gửi RPC sau khi nhập lý do và reload dữ liệu thật', async ({ page }) => {
  const state = await mockSupabase(page)
  state.views.admin_rescue_requests_view = [{ request_id: id, request_code: 'CH-000042', customer_name: 'Khách cần hủy', status: 'searching', created_at: createdAt }]
  await page.goto('/requests')
  const row = page.getByRole('row').filter({ hasText: 'Khách cần hủy' })
  await expect(row).toContainText('CH-000042')
  await row.getByRole('button', { name: 'Hủy đơn' }).click()
  const dialog = page.getByRole('dialog')
  await dialog.getByRole('textbox', { name: 'Lý do' }).fill('   ')
  await expect(dialog.getByRole('button', { name: 'Xác nhận' })).toBeDisabled()
  await dialog.getByRole('textbox', { name: 'Lý do' }).fill('  Khách yêu cầu hủy  ')
  await dialog.getByRole('button', { name: 'Xác nhận' }).click()
  await expect(row).toContainText('Đã hủy')
  expect(state.calls).toEqual([{ name: 'admin_cancel_request', body: { request_id: id, reason: 'Khách yêu cầu hủy' } }])
  await expect(page.locator('body')).not.toContainText(id)
})

test('toggle dịch vụ gọi đúng RPC và các chức năng chưa có backend bị vô hiệu hóa', async ({ page }) => {
  const state = await mockSupabase(page)
  state.views.admin_services_view = [{ service_id: id, name: 'Kéo xe', code: 'SRV-TOW', is_active: true, base_price: 500000 }]
  await page.goto('/services')
  const toggle = page.getByRole('switch', { name: 'Bật tắt Kéo xe' })
  await toggle.click()
  await page.getByRole('dialog').getByRole('button', { name: 'Xác nhận' }).click()
  await expect(toggle).toHaveAttribute('aria-checked', 'false')
  expect(state.calls.at(-1)).toEqual({ name: 'admin_toggle_service', body: { service_id: id, is_active: false } })
  await page.getByRole('link', { name: 'Thông báo', exact: true }).click()
  await expect(page.getByRole('button', { name: 'Gửi thông báo · Chưa hỗ trợ' })).toBeDisabled()
})

test('dashboard tổng hợp toàn bộ yêu cầu theo giờ Việt Nam và đổi khoảng ngày', async ({ page }) => {
  await page.clock.setFixedTime(new Date('2026-10-12T05:00:00Z'))
  await page.setViewportSize({ width: 1440, height: 1100 })
  const state = await mockSupabase(page)
  state.stats = { total_customers: 12480, total_rescuers: 284, today_requests: 86, active_requests: 14, completed_requests: 68, cancelled_requests: 4, today_revenue: 48250000, online_rescuers: 142, pending_rescuers: 8, average_rating: 4.8 }
  const dates = ['2026-10-12T03:00:00Z', '2026-10-11T17:00:00Z', '2026-10-11T16:59:00Z', '2026-10-10T03:00:00Z', '2026-10-09T03:00:00Z', '2026-10-08T03:00:00Z', '2026-10-06T03:00:00Z', '2026-10-01T03:00:00Z']
  const statuses = ['completed', 'completed', 'accepted', 'searching', 'cancelled', 'completed', 'completed', 'unknown']
  state.views.admin_rescue_requests_view = dates.map((created_at, index) => ({ request_id: id + index, request_code: 'CH-00008' + index, customer_name: ['Nguyễn Minh Anh', 'Trần Hoàng Nam', 'Lê Thanh Hà'][index % 3], vehicle_plate: '43A-123.45', rescuer_name: 'Đội cứu hộ Đà Nẵng', service_type: index % 2 ? 'battery' : 'towing', status: statuses[index], created_at }))
  await page.goto('/')
  await expect(page.locator('.trend-summary > strong')).toHaveText('7')
  const daily = page.locator('table').filter({ has: page.locator('caption', { hasText: 'Số yêu cầu cứu hộ theo ngày' }) })
  await expect(daily.getByRole('row').filter({ hasText: '2026-10-12' }).locator('td')).toHaveText('2')
  await expect(daily.getByRole('row').filter({ hasText: '2026-10-11' }).locator('td')).toHaveText('1')
  await expect(page.locator('.status-donut strong')).toHaveText('50%')
  await expect(page.locator('.legend-list')).toContainText('Khác / Chưa xác định')
  await expect(page.locator('.dashboard-bottom tbody tr')).toHaveCount(5)
  await page.getByLabel('Khoảng thời gian biểu đồ').selectOption('14')
  await expect(page.locator('.trend-summary > strong')).toHaveText('8')
  await page.getByLabel('Khoảng thời gian biểu đồ').selectOption('7')
  await page.evaluate(() => document.fonts.ready)
  await page.screenshot({ path: 'test-results/stitch-dashboard-desktop.png', fullPage: true })
  await page.setViewportSize({ width: 390, height: 844 })
  await page.screenshot({ path: 'test-results/stitch-dashboard-mobile.png', fullPage: true })
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true)
})

test('dashboard phân biệt số liệu chưa có, quyền doanh thu và lỗi tải danh sách', async ({ page }) => {
  const state = await mockSupabase(page)
  state.stats = { total_customers: 0, revenue_visible: false, today_revenue: 999999 }
  await page.route('**/rest/v1/admin_rescue_requests_view*', (route) => route.fulfill({ status: 500, contentType: 'application/json', body: JSON.stringify({ message: 'Nguồn yêu cầu tạm ngưng' }) }))
  await page.goto('/')
  await expect(page.locator('.stat-card').filter({ hasText: 'Tổng khách hàng' }).locator('.stat-value')).toHaveText('0')
  await expect(page.locator('.stat-card').filter({ hasText: 'Tổng đối tác' }).locator('.stat-value')).toHaveText('—')
  await expect(page.locator('.stat-card').filter({ hasText: 'Báo giá hôm nay' })).toContainText('Tài khoản không có quyền xem số tiền')
  await expect(page.locator('.stat-card').filter({ hasText: 'Báo giá hôm nay' }).locator('.stat-value')).toHaveText('—')
  await expect(page.getByText('Chưa tải được thống kê yêu cầu')).toBeVisible()
  await expect(page.locator('.request-trend-chart')).toHaveCount(0)
})

test('điều hướng mobile, bàn phím và các trang admin không tràn màn hình', async ({ page }) => {
  test.setTimeout(90_000)
  const errors: string[] = []
  page.on('pageerror', (error) => errors.push(error.message))
  const state = await mockSupabase(page)
  state.views.admin_rescue_requests_view = [{ request_id: id, request_code: 'CH-000042', customer_name: 'Nguyễn Minh Anh', customer_phone: '0905123456', customer_email: 'minhanh@example.test', customer_id: id, rescuer_id: id, rescuer_name: 'Đội cứu hộ Đà Nẵng', vehicle_name: 'Mazda CX-5', vehicle_plate: '43A-123.45', service_type: 'towing', pickup_address: 'Cầu Rồng, Đà Nẵng', status: 'searching', created_at: createdAt }]
  state.views.admin_customers_view = [{ customer_id: id, customer_code: 'KH-000042', full_name: 'Nguyễn Minh Anh', phone: '0905123456', email: 'minhanh@example.test', status: 'active', created_at: createdAt }]
  state.views.admin_rescuers_view = [{ rescuer_id: id, rescuer_code: 'DT-000042', full_name: 'Đội cứu hộ Đà Nẵng', phone: '0905123456', email: 'cuuho@example.test', approval_status: 'submitted', online_status: true, created_at: createdAt }]
  state.views.admin_services_view = [{ service_id: id, name: 'Kéo xe sàn trượt', description: 'Hỗ trợ vận chuyển phương tiện an toàn đến garage.', code: 'SRV-TOW', is_active: true, base_price: 500000, price_unit: 'chuyến' }]
  state.views.admin_quotes_view = [{ quote_id: id, quote_code: 'BG-000042', request_id: id, request_code: 'CH-000042', customer_name: 'Nguyễn Minh Anh', rescuer_name: 'Đội cứu hộ Đà Nẵng', service_type: 'towing', amount: 500000, status: 'issued', is_current: true, created_at: createdAt }]
  state.views.admin_reviews_view = [{ review_id: id, request_code: 'CH-000042', customer_name: 'Nguyễn Minh Anh', rescuer_name: 'Đội cứu hộ Đà Nẵng', rating: 5, comment: 'Đội cứu hộ hỗ trợ nhanh và nhiệt tình.', created_at: createdAt }]
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/')
  const menu = page.getByRole('button', { name: 'Mở menu', exact: true })
  await menu.click()
  await expect(page.getByRole('dialog', { name: 'Điều hướng quản trị' })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Đóng menu', exact: true })).toBeFocused()
  await page.keyboard.press('Escape')
  await expect(menu).toBeFocused()
  await expect(menu).toHaveAttribute('aria-expanded', 'false')
  await menu.click()
  await page.getByRole('navigation').getByRole('link', { name: 'Khách hàng', exact: true }).click()
  await expect(page).toHaveURL(/\/customers$/)
  await expect(menu).toHaveAttribute('aria-expanded', 'false')
  for (const width of [390, 768, 1440]) {
    await page.setViewportSize({ width, height: 900 })
    for (const route of ['/', '/requests', '/customers', '/rescuers', '/services', '/quotes', '/reviews', '/map', '/settings', '/notifications', '/audit-logs', '/requests/' + id, '/customers/' + id, '/rescuers/' + id]) {
      await page.goto(route)
      await expect(page.locator('main h1')).toBeVisible()
      await expect(page.getByText('Đang tải dữ liệu...', { exact: true })).toHaveCount(0)
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), route + ' at ' + width).toBe(true)
    }
  }
  expect(errors).toEqual([])
  await page.keyboard.press('Control+k')
  await expect(page.getByRole('textbox', { name: 'Tra cứu yêu cầu' })).toBeFocused()
  await page.getByRole('textbox', { name: 'Tra cứu yêu cầu' }).fill('43A-123.45')
  await page.keyboard.press('Enter')
  await expect(page).toHaveURL(/\/requests\?search=43A-123.45$/)
})
