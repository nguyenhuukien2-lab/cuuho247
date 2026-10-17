import { test, expect } from '@playwright/test'
import type { Page } from '@playwright/test'
import type { PartnerReview } from '../src/lib/partnerReviewApi'

const id = 'a1700000-0000-4000-8000-000000000001'
const vehicle = 'a1700000-0000-4000-8000-000000000011'
const created = '2026-10-17T03:00:00Z'
async function fixture(page: Page) {
  const user = { id, email: 'reviewer@example.invalid', aud: 'authenticated', role: 'authenticated', created_at: created }
  const payload = Buffer.from(JSON.stringify({ sub: id, role: 'authenticated', exp: Math.floor(Date.now() / 1000) + 3600 })).toString('base64url')
  await page.addInitScript((session) => localStorage.setItem('sb-admin-test-auth-token', JSON.stringify(session)), {
    access_token: `header.${payload}.signature`, refresh_token: 'test-refresh', expires_in: 3600,
    expires_at: Math.floor(Date.now() / 1000) + 3600, token_type: 'bearer', user,
  })
  const review: PartnerReview = {
    documents: ['identity', 'license', 'vehicle_registration'].map((type, index) => ({
      document_id: `doc-${index}`, document_type: type, vehicle_id: index === 2 ? vehicle : null,
      storage_path: `${id}/doc-${index}`, content_type: 'image/png', uploaded_at: created, created_at: created,
      expires_at: null, verification_status: 'submitted', review_reason: null,
    })),
    vehicles: [{ id: vehicle, kind: 'service_motorbike', display_name: 'Xe hỗ trợ', license_plate: '59A12345', verification_status: 'submitted', is_active: true, version: 1 }],
    capabilities: [{ vehicle_id: vehicle, service_code: 'tire', service_name: 'Vá lốp', customer_vehicle_kind: 'motorbike', verification_status: 'submitted', is_enabled: true, service_active: true, updated_at: created }],
    readiness: { checked_at: created, profile_approved: true, identity_approved: false, license_approved: false, can_online: false, can_receive_requests: false, eligible_vehicle_ids: [], vehicles: [{ vehicle_id: vehicle, vehicle_approved: false, registration_approved: false, service_approved: false, ready: false }] },
  }
  const state = { review, error: '', signedError: false, delay: 0, admin: true, calls: [] as { name: string; body: Record<string, unknown> }[] }
  await page.routeWebSocket('wss://admin-test.supabase.co/**', (socket) => socket.close())
  await page.route('https://admin-test.supabase.co/**', async (route) => {
    const request = route.request(), url = new URL(request.url()), name = url.pathname.split('/').pop()!
    const reply = (data: unknown, status = 200) => route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(data) })
    if (url.pathname.startsWith('/auth/')) return reply(user)
    if (name === 'is_admin') return reply(state.admin)
    if (name === 'admin_profiles') return reply([{ id, full_name: 'Reviewer', role: 'partner_reviewer' }])
    if (name === 'admin_rescuers_view') return reply([{ rescuer_id: id, rescuer_code: 'DT-000003', full_name: 'Nguyễn Hữu A', approval_status: 'approved', vehicle_count: 1, service_count: 1 }])
    if (name === 'admin_get_rescuer_review') {
      if (state.delay) await new Promise((resolve) => setTimeout(resolve, state.delay))
      return state.error ? reply({ message: state.error }, 403) : reply(review)
    }
    const body = request.postDataJSON() as Record<string, unknown>
    if (url.pathname.includes('/object/sign/')) {
      state.calls.push({ name: 'sign', body })
      return state.signedError ? reply({ message: 'Storage denied secret-token-must-not-render' }, 403) : reply({ signedURL: '/object/sign/rescuer-documents/fixture?token=temporary-test-token' })
    }
    if (name.startsWith('admin_review_rescuer_')) {
      state.calls.push({ name, body })
      if (state.error) return reply({ message: state.error }, 403)
      if (name.endsWith('document')) {
        const d = review.documents.find((d) => d.document_id === body.p_document_id)!
        d.verification_status = String(body.p_status); d.review_reason = body.p_reason as string | null
      } else if (name.endsWith('vehicle')) review.vehicles[0].verification_status = String(body.p_status)
      else review.capabilities[0].verification_status = String(body.p_status)
      review.readiness.can_online = review.documents.every((d) => d.verification_status === 'approved') && review.vehicles[0].verification_status === 'approved' && review.capabilities[0].verification_status === 'approved'
      return reply({ success: true, message: 'Đã cập nhật kiểm duyệt' })
    }
    return reply([])
  })
  return state
}
const section = (page: Page, title: string) => page.locator('section').filter({ has: page.getByRole('heading', { name: title, exact: true }) })

test('hiển thị dữ liệu thật; duyệt từng giấy tờ, xe và dịch vụ rồi reload readiness', async ({ page }) => {
  const state = await fixture(page)
  await page.goto('/rescuers/' + id)
  await expect(page.getByRole('heading', { name: 'Nguyễn Hữu A' })).toBeVisible()
  const documents = section(page, 'Giấy tờ')
  await expect(documents.locator('tbody tr')).toHaveCount(3)
  await expect(page.locator('body')).not.toContainText('Chưa kết nối dữ liệu')
  await expect(section(page, 'Phương tiện')).toContainText('59A12345')
  for (let i = 0; i < 3; i++) {
    const row = documents.locator('tbody tr').nth(i)
    await row.getByRole('button', { name: 'Duyệt', exact: true }).click()
    await page.getByRole('dialog').getByRole('button', { name: 'Xác nhận' }).click()
    await expect(row).toContainText('Đã duyệt')
  }
  for (const title of ['Phương tiện', 'Dịch vụ đã đăng ký']) {
    await section(page, title).getByRole('button', { name: 'Duyệt', exact: true }).click()
    await page.getByRole('dialog').getByRole('button', { name: 'Xác nhận' }).click()
    await expect(section(page, title)).toContainText('Đã duyệt')
  }
  await expect(section(page, 'Điều kiện hoạt động').locator('.key-values > div').filter({ hasText: 'Được phép Online' })).toContainText('Đủ điều kiện')
  expect(state.calls.filter((c) => c.name.endsWith('document'))).toHaveLength(3)
  expect(state.calls[0].body).toEqual({ p_document_id: 'doc-0', p_status: 'approved', p_expected_status: 'submitted', p_reason: null })
})

test('từ chối bắt buộc lý do và hiển thị lý do máy chủ trả về', async ({ page }) => {
  const state = await fixture(page)
  await page.goto('/rescuers/' + id)
  const row = section(page, 'Giấy tờ').locator('tbody tr').first()
  await row.getByRole('button', { name: 'Từ chối', exact: true }).click()
  const dialog = page.getByRole('dialog')
  await dialog.getByRole('textbox', { name: 'Lý do' }).fill('   ')
  await expect(dialog.getByRole('button', { name: 'Xác nhận' })).toBeDisabled()
  await dialog.getByRole('textbox', { name: 'Lý do' }).fill('  Ảnh mờ, cần chụp lại  ')
  await dialog.getByRole('button', { name: 'Xác nhận' }).click()
  await expect(row).toContainText('Đã từ chối')
  await expect(row).toContainText('Ảnh mờ, cần chụp lại')
  expect(state.calls[0].body.p_reason).toBe('Ảnh mờ, cần chụp lại')
})

test('signed URL yêu cầu 60 giây, biến mất khi hết hạn và tạo mới khi xem lại', async ({ page }) => {
  await page.clock.install()
  const state = await fixture(page)
  await page.goto('/rescuers/' + id)
  await section(page, 'Giấy tờ').getByRole('button', { name: 'Xem tài liệu' }).first().click()
  const dialog = page.getByRole('dialog', { name: 'Xem tài liệu' })
  await expect(dialog.getByRole('link')).toHaveAttribute('rel', 'noopener noreferrer')
  expect(state.calls.find((c) => c.name === 'sign')?.body).toEqual({ expiresIn: 60 })
  const initialSigns = state.calls.filter((c) => c.name === 'sign').length
  await page.clock.fastForward(61_000)
  await expect(dialog.getByRole('link')).toHaveCount(0)
  await expect(dialog).toContainText('Liên kết đã hết hạn')
  await dialog.getByRole('button', { name: 'Tạo lại liên kết' }).click()
  await expect(dialog.getByRole('link')).toBeVisible()
  expect(state.calls.filter((c) => c.name === 'sign')).toHaveLength(initialSigns + 1)
  expect(await page.evaluate(() => JSON.stringify(localStorage))).not.toContain('temporary-test-token')
})

test('loading, empty, lỗi quyền và lỗi Storage không lộ token', async ({ page }) => {
  const state = await fixture(page)
  state.delay = 700
  await page.goto('/rescuers/' + id)
  await expect(page.getByText('Đang tải dữ liệu...', { exact: true }).first()).toBeVisible()
  await section(page, 'Giấy tờ').getByRole('button', { name: 'Xem tài liệu' }).first().click()
  await page.getByRole('dialog').getByRole('button', { name: 'Đóng', exact: true }).click()
  state.signedError = true
  await section(page, 'Giấy tờ').getByRole('button', { name: 'Xem tài liệu' }).first().click()
  await expect(page.getByRole('dialog')).toContainText('Không thể mở tài liệu')
  await expect(page.locator('body')).not.toContainText('secret-token-must-not-render')
  await page.getByRole('dialog').getByRole('button', { name: 'Đóng', exact: true }).click()
  state.review.documents = []; state.review.vehicles = []; state.review.capabilities = []
  await page.getByRole('button', { name: 'Tải lại', exact: true }).first().click()
  await expect(page.getByText('Đối tác chưa tải giấy tờ')).toBeVisible()
  state.error = 'ADMIN_FORBIDDEN'
  await page.getByRole('button', { name: 'Tải lại', exact: true }).first().click()
  await expect(page.getByRole('alert')).toContainText('Chỉ Admin có quyền kiểm duyệt')
  await expect(page.getByRole('button', { name: 'Xem tài liệu' })).toHaveCount(0)
})

test('lỗi RPC không thay đổi trạng thái cục bộ', async ({ page }) => {
  const state = await fixture(page)
  await page.goto('/rescuers/' + id)
  const row = section(page, 'Giấy tờ').locator('tbody tr').first()
  await row.getByRole('button', { name: 'Duyệt', exact: true }).click()
  state.error = 'ADMIN_REVIEW_CONFLICT'
  await page.getByRole('dialog').getByRole('button', { name: 'Xác nhận' }).click()
  await expect(page.getByRole('dialog')).toContainText('Dữ liệu đã thay đổi')
  await expect(row).toContainText('Chờ duyệt')
})

test('chi tiết đối tác đọc được ở màn hình desktop và mobile', async ({ page }) => {
  await fixture(page)
  for (const width of [1440, 390]) {
    await page.setViewportSize({ width, height: 900 })
    await page.goto('/rescuers/' + id)
    await expect(section(page, 'Giấy tờ').locator('tbody tr')).toHaveCount(3)
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true)
    await page.screenshot({ path: `test-results/partner-review-${width}.png`, fullPage: true })
  }
})
