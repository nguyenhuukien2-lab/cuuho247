import { expect, test } from '@playwright/test'
import type { Page } from '@playwright/test'

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
