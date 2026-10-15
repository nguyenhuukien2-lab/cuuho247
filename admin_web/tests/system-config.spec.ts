import { expect, test } from '@playwright/test'
import type { Page } from '@playwright/test'
import type { SystemConfig, ConfigAudit, AccountControl } from '../src/lib/systemConfigApi'
import { paymentSession, timestamp } from './paymentFixtures'

import { fixture, fullFixture } from './systemConfigFixtures'
async function setup(page: Page) {
  await paymentSession(page)
  const state = { config: structuredClone(fixture), history: [] as ConfigAudit[], delay: 0, error: '', writeError: '', historyError: '',
    account: { user_id: 'a1500000-0000-4000-8000-000000000001', status: 'active', version: '0', suspended_until: null, tokens_valid_after: null } as AccountControl,
    calls: [] as { name: string; body: Record<string, unknown> }[] }
  await page.route('**/rest/v1/rpc/*system*', async (route) => {
    const name = new URL(route.request().url()).pathname.split('/').at(-1)!
    const body = route.request().postDataJSON() as Record<string, unknown>
    state.calls.push({ name, body })
    if (state.delay) await new Promise((resolve) => setTimeout(resolve, state.delay))
    const fail = state.error || (name.includes('apply') ? state.writeError : name.includes('audit') ? state.historyError : '')
    if (fail) return route.fulfill({ status: 403, contentType: 'application/json', body: JSON.stringify({ code: '42501', message: fail }) })
    let result: unknown = state.config
    if (name === 'admin_apply_system_config') {
      const before = structuredClone(state.config.values)
      state.config.values = { ...state.config.values, ...body.p_patch as SystemConfig['values'] }
      state.config.version = String(BigInt(state.config.version) + 1n)
      state.history.unshift({ id: '1', actor_id: 'test-super', action: 'config_update', target: 'system', version: state.config.version,
        before_value: before, after_value: state.config.values, reason: body.p_reason as string, created_at: timestamp })
      result = state.config
    } else if (name === 'admin_list_system_config_audit') result = { rows: state.history }
    else if (name === 'admin_get_system_account_control') result = state.account
    else if (name === 'admin_apply_system_account_control') {
      state.account = { ...state.account, status: body.p_status as AccountControl['status'], version: '1' }; result = state.account
    } else if (name === 'admin_apply_system_admin_access') {
      state.account = { ...state.account, admin_access: { role: body.p_role as string, status: body.p_status as string, updated_at: timestamp } }; result = state.account
    }
    return route.fulfill({ contentType: 'application/json', body: JSON.stringify(result) })
  })
  return state
}

test('overview renders five tabs and only saved summaries; keyboard navigation works', async ({ page }) => {
  const state = await setup(page); state.config = structuredClone(fullFixture)
  await page.goto('/settings')
  await expect(page.getByRole('tab')).toHaveCount(5)
  await expect(page.getByRole('tab', { name: 'Tổng quan', exact: true })).toHaveAttribute('aria-selected', 'true')
  await expect(page.getByRole('tabpanel', { name: 'Tổng quan' }).getByRole('heading')).toHaveCount(4)
  await expect(page.getByRole('tabpanel', { name: 'Tổng quan' }).locator('input,textarea,select')).toHaveCount(0)
  await expect(page.getByRole('region', { name: 'Thay đổi chưa lưu' })).toHaveCount(0)
  await page.getByRole('tab', { name: 'Tổng quan', exact: true }).focus()
  await page.keyboard.press('ArrowRight')
  await expect(page.getByRole('tab', { name: 'Customer', exact: true })).toBeFocused()
  await expect(page.getByLabel('Nội dung banner')).toBeVisible()
  await page.keyboard.press('End')
  await expect(page.getByRole('tab', { name: 'Bảo mật & quyền' })).toHaveAttribute('aria-selected', 'true')
})

test('dirty count survives all tabs, counts shared keys once and resets all drafts', async ({ page }) => {
  const state = await setup(page); state.config = structuredClone(fullFixture)
  await page.goto('/settings')
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await page.getByLabel('Nội dung banner').fill('Thông báo chưa lưu')
  await page.getByLabel('Số ảnh / yêu cầu').fill('2')
  await page.getByLabel('Bảo trì Customer').check()
  await page.getByLabel('Lý do thay đổi', { exact: true }).fill('Thay đổi nhiều tab')
  await expect(page.getByText('3 thay đổi chưa lưu', { exact: true })).toBeVisible()
  await expect(page.locator('.setting-row.is-dirty')).toHaveCount(3)
  for (const name of ['Rescuer', 'Thanh toán', 'Bảo mật & quyền', 'Tổng quan']) {
    await page.getByRole('tab', { name, exact: true }).click()
    await expect(page.getByText('3 thay đổi chưa lưu', { exact: true })).toBeVisible()
  }
  await expect(page.getByRole('tabpanel', { name: 'Tổng quan' }).locator('dl').first()).toContainText('Tắt')
  await page.getByRole('tab', { name: 'Bảo mật & quyền' }).click()
  await expect(page.getByLabel('Bảo trì Customer')).toBeChecked()
  await page.getByLabel('Bảo trì Customer').uncheck()
  await expect(page.getByText('2 thay đổi chưa lưu', { exact: true })).toBeVisible()
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await expect(page.getByLabel('Nội dung banner')).toHaveValue('Thông báo chưa lưu')
  await expect(page.getByLabel('Lý do thay đổi', { exact: true })).toHaveValue('Thay đổi nhiều tab')
  await page.getByRole('button', { name: 'Đặt lại', exact: true }).click()
  await expect(page.getByRole('region', { name: 'Thay đổi chưa lưu' })).toHaveCount(0)
  await expect(page.getByLabel('Nội dung banner')).toHaveValue('')
  await expect(page.getByLabel('Số ảnh / yêu cầu')).toHaveValue('3')
  await expect(page.locator('.setting-row.is-dirty')).toHaveCount(0)
  expect(state.calls.filter((c) => c.name === 'admin_get_system_config')).toHaveLength(1)
  expect(state.calls.some((c) => c.name.includes('apply'))).toBe(false)
})

test('restoring a numeric or equivalent permissions value clears dirty state', async ({ page }) => {
  const state = await setup(page); state.config = structuredClone(fullFixture)
  await page.goto('/settings')
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await page.getByLabel('Số ảnh / yêu cầu').fill('2')
  await expect(page.getByText('1 thay đổi chưa lưu', { exact: true })).toBeVisible()
  await page.getByLabel('Số ảnh / yêu cầu').fill('3')
  await expect(page.getByRole('region', { name: 'Thay đổi chưa lưu' })).toHaveCount(0)
  await page.getByRole('tab', { name: 'Bảo mật & quyền' }).click()
  await page.getByLabel('Vai trò được sửa từng nhóm').fill(JSON.stringify({ security: ['super_admin'], payment: ['finance', 'super_admin'], rescuer: ['operator', 'super_admin'], customer: ['operator', 'super_admin'] }))
  await expect(page.getByRole('region', { name: 'Thay đổi chưa lưu' })).toHaveCount(0)
})

test('reason and hidden-tab validation block save; pending save locks controls and clears on success', async ({ page }) => {
  const state = await setup(page)
  await page.goto('/settings')
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await page.getByLabel('Nội dung banner').fill('Banner mới')
  const save = page.getByRole('button', { name: 'Lưu thay đổi', exact: true })
  await expect(save).toBeDisabled()
  await page.getByLabel('Lý do thay đổi', { exact: true }).fill('    ')
  await expect(save).toBeDisabled()
  await page.getByLabel('Lý do thay đổi', { exact: true }).fill('Cập nhật banner')
  await page.getByLabel('Số ảnh / yêu cầu').fill('4')
  await page.getByRole('tab', { name: 'Rescuer', exact: true }).click()
  await expect(save).toBeDisabled()
  await expect(page.getByText('Có giá trị chưa hợp lệ.', { exact: false })).toBeVisible()
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await page.getByLabel('Số ảnh / yêu cầu').fill('3')
  state.delay = 600
  await save.click()
  await expect(page.getByRole('button', { name: 'Đang lưu...', exact: true })).toBeDisabled()
  await expect(page.getByRole('button', { name: 'Đặt lại', exact: true })).toBeDisabled()
  await expect(page.getByLabel('Nội dung banner')).toBeDisabled()
  await expect(page.getByRole('status')).toContainText('Đã lưu cấu hình')
  await expect(page.getByRole('region', { name: 'Thay đổi chưa lưu' })).toHaveCount(0)
  await expect(page.locator('.setting-row').filter({ hasText: 'Nội dung banner' })).toContainText('Hiện tại: Banner mới')
  expect(state.calls.filter((c) => c.name === 'admin_apply_system_config').map((c) => c.body)).toEqual([
    { p_patch: { 'customer.banner': 'Banner mới' }, p_expected_version: '1', p_reason: 'Cập nhật banner', p_confirm_dangerous: false },
  ])
})

test('cross-tab controls retain their original section permissions', async ({ page }) => {
  const state = await setup(page); state.config = structuredClone(fullFixture); state.config.editable_sections = ['customer', 'rescuer']
  await page.goto('/settings')
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await expect(page.getByLabel('Bảo trì Customer')).toBeEnabled()
  await expect(page.getByLabel('Dừng tạo yêu cầu khẩn cấp')).toHaveCount(0)
  await page.getByRole('tab', { name: 'Rescuer', exact: true }).click()
  await expect(page.getByLabel('Hiển thị thanh toán ngân hàng')).toBeEnabled()
  await expect(page.getByLabel('Cho phép xác nhận tiền mặt')).toHaveCount(0)
  await page.getByRole('tab', { name: 'Thanh toán', exact: true }).click()
  await expect(page.getByRole('tabpanel', { name: 'Thanh toán' }).locator('input,textarea,select')).toHaveCount(0)
  await page.getByRole('tab', { name: 'Bảo mật & quyền' }).click()
  await expect(page.getByLabel('UUID tài khoản')).toHaveCount(0)
})

test('private config is excluded from forms, overview and history', async ({ page }) => {
  const state = await setup(page); state.config = structuredClone(fullFixture)
  const privateKeys = ['payment.bank_account_private', 'payment.hmac_secret', 'payment.service_role', 'payment.db_url', 'payment.credential']
  for (const key of privateKeys) {
    state.config.values[key] = `PRIVATE-${key}`
    state.config.definitions.push({ key, section: 'payment', label: key, kind: 'text', minimum: 0, maximum: 500, dangerous: false })
  }
  state.history = [{ id: '1', actor_id: 'test-admin', action: 'config_update', target: 'system', version: '2', before_value: {}, after_value: state.config.values, reason: 'Kiểm tra lịch sử', created_at: timestamp }]
  await page.goto('/settings')
  for (const name of ['Tổng quan', 'Customer', 'Rescuer', 'Thanh toán', 'Bảo mật & quyền']) {
    await page.getByRole('tab', { name, exact: true }).click()
    await expect(page.locator('body')).not.toContainText('PRIVATE-')
    for (const key of privateKeys) await expect(page.getByLabel(key)).toHaveCount(0)
  }
  await page.getByRole('button', { name: 'Xem lịch sử', exact: true }).click()
  await expect(page.getByRole('dialog')).toContainText('Kiểm tra lịch sử')
  await expect(page.getByRole('dialog')).not.toContainText('PRIVATE-')
  await page.keyboard.press('Escape')
  await expect(page.getByRole('dialog')).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Xem lịch sử', exact: true })).toBeFocused()
})

test('account lookup drafts persist across tab switches', async ({ page }) => {
  const state = await setup(page)
  await page.goto('/settings')
  await page.getByRole('tab', { name: 'Bảo mật & quyền' }).click()
  await page.getByLabel('UUID tài khoản').fill(state.account.user_id)
  await page.getByRole('button', { name: 'Tra cứu tài khoản' }).click()
  await page.getByLabel('Trạng thái tài khoản').selectOption('locked')
  await page.getByLabel('Lý do kiểm soát tài khoản').fill('Chờ xác nhận khóa')
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await page.getByRole('tab', { name: 'Bảo mật & quyền' }).click()
  await expect(page.getByLabel('Trạng thái tài khoản')).toHaveValue('locked')
  await expect(page.getByLabel('Lý do kiểm soát tài khoản')).toHaveValue('Chờ xác nhận khóa')
  expect(state.calls.filter((c) => c.name === 'admin_get_system_account_control')).toHaveLength(1)
})

for (const viewport of [{ width: 1440, height: 1000 }, { width: 820, height: 900 }, { width: 390, height: 844 }]) {
  test(`responsive settings and fixed save bar at ${viewport.width}px`, async ({ page }, testInfo) => {
    await page.setViewportSize(viewport)
    const state = await setup(page); state.config = structuredClone(fullFixture)
    await page.goto('/settings')
    await expect(page.getByRole('heading', { name: 'Customer', exact: true })).toBeVisible()
    await page.screenshot({ path: testInfo.outputPath(`settings-overview-${viewport.width}.png`) })
    await page.getByRole('tab', { name: 'Customer', exact: true }).click()
    await page.getByLabel('Nội dung banner').fill('Hệ thống bảo trì từ 22:00 hôm nay')
    await page.getByLabel('Số ảnh / yêu cầu').fill('2')
    await page.getByLabel('Lý do thay đổi', { exact: true }).fill('Cập nhật thông báo bảo trì')
    const bar = page.getByRole('region', { name: 'Thay đổi chưa lưu' })
    const before = await bar.boundingBox()
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight))
    const after = await bar.boundingBox()
    expect(after!.y).toBeCloseTo(before!.y, 0)
    expect(after!.y + after!.height).toBeCloseTo(viewport.height, 0)
    const lastRow = await page.locator('[role=tabpanel]:not([hidden]) .setting-row').last().boundingBox()
    expect(lastRow!.y + lastRow!.height).toBeLessThanOrEqual(after!.y)
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true)
    await page.evaluate(() => { (document.activeElement as HTMLElement)?.blur(); window.scrollTo(0, 0) })
    await page.screenshot({ path: testInfo.outputPath(`settings-customer-${viewport.width}.png`) })
    if (viewport.width === 1440) {
      await page.getByRole('button', { name: 'Xem lịch sử', exact: true }).click()
      await page.screenshot({ path: testInfo.outputPath('settings-history-1440.png') })
      await page.getByRole('button', { name: 'Đóng lịch sử' }).click()
    }
    await page.getByRole('tab', { name: 'Bảo mật & quyền' }).click()
    await page.getByLabel('UUID tài khoản').fill(state.account.user_id)
    await page.getByRole('button', { name: 'Tra cứu tài khoản' }).click()
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true)
    await page.evaluate(() => { (document.activeElement as HTMLElement)?.blur(); window.scrollTo(0, 0) })
    await page.screenshot({ path: testInfo.outputPath(`settings-security-${viewport.width}.png`) })
  })
}

test('loads sections, current values and empty audit through production RPC adapter', async ({ page }) => {
  const state = await setup(page)
  await page.goto('/settings')
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await expect(page.getByRole('heading', { name: 'Cấu hình hệ thống' })).toBeVisible()
  for (const name of ['Tổng quan', 'Customer', 'Rescuer', 'Thanh toán', 'Bảo mật & quyền']) await expect(page.getByRole('tab', { name, exact: true })).toBeVisible()
  await page.getByRole('button', { name: 'Xem lịch sử', exact: true }).click()
  await expect(page.getByText('Chưa có thay đổi được ghi nhận.')).toBeVisible()
  await page.getByRole('button', { name: 'Đóng lịch sử' }).click()
  await expect(page.getByLabel('Số ảnh / yêu cầu')).toHaveValue('3')
  expect(state.calls.map((call) => call.name)).toEqual(expect.arrayContaining(['admin_get_system_config', 'admin_list_system_config_audit']))
})

test('validates numbers and required reason before issuing mutation', async ({ page }) => {
  const state = await setup(page)
  await page.goto('/settings')
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await page.getByLabel('Số ảnh / yêu cầu').fill('4')
  await page.getByLabel('Lý do thay đổi', { exact: true }).fill('test validation')
  await expect(page.getByRole('alert')).toContainText('Nhập số nguyên từ 0 đến 3')
  await expect(page.getByRole('button', { name: 'Lưu thay đổi', exact: true })).toBeDisabled()
  await page.getByLabel('Số ảnh / yêu cầu').fill('1.5')
  await expect(page.getByRole('button', { name: 'Lưu thay đổi', exact: true })).toBeDisabled()
  expect(state.calls.some((c) => c.name.includes('apply'))).toBe(false)
})

test('requires native confirmation, supports cancel, saves exact version and refreshes audit', async ({ page }) => {
  const state = await setup(page)
  await page.goto('/settings')
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await page.getByLabel('Bảo trì Customer').check()
  await page.getByLabel('Lý do thay đổi', { exact: true }).fill('Bảo trì kiểm thử')
  await page.getByRole('button', { name: 'Lưu thay đổi', exact: true }).click()
  await expect(page.getByRole('dialog')).toContainText('false → true')
  await page.getByRole('button', { name: 'Hủy', exact: true }).click()
  expect(state.calls.some((c) => c.name.includes('apply'))).toBe(false)
  await page.getByRole('button', { name: 'Lưu thay đổi', exact: true }).click()
  await page.getByRole('button', { name: 'Xác nhận lưu' }).click()
  await expect(page.getByText('Đã lưu cấu hình và ghi lịch sử.')).toBeVisible()
  await page.getByRole('button', { name: 'Xem lịch sử', exact: true }).click()
  await expect(page.locator('.system-audit-list')).toContainText('Bảo trì kiểm thử')
  expect(state.calls.find((c) => c.name === 'admin_apply_system_config')?.body).toEqual({ p_patch: { 'customer.maintenance': true }, p_expected_version: '1', p_reason: 'Bảo trì kiểm thử', p_confirm_dangerous: true })
  await expect(page.locator('.system-audit-list')).toContainText('Giá trị cũ')
})

test('safe edits save without confirmation and preserve unedited fields', async ({ page }) => {
  const state = await setup(page)
  await page.goto('/settings')
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await page.getByLabel('Nội dung banner').fill('Thông báo mới')
  await page.getByLabel('Lý do thay đổi', { exact: true }).fill('Cập nhật nội dung')
  await page.getByRole('button', { name: 'Lưu thay đổi', exact: true }).click()
  await expect(page.getByText('Đã lưu cấu hình và ghi lịch sử.')).toBeVisible()
  expect(state.calls.find((c) => c.name.includes('apply'))?.body.p_patch).toEqual({ 'customer.banner': 'Thông báo mới' })
  await expect(page.getByRole('dialog')).toHaveCount(0)
})

test('conflict blocks retry until reload and uses refreshed version', async ({ page }) => {
  const state = await setup(page)
  state.writeError = 'SYSTEM_CONFIG_VERSION_CONFLICT'
  await page.goto('/settings')
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await page.getByLabel('Nội dung banner').fill('stale')
  await page.getByLabel('Lý do thay đổi', { exact: true }).fill('Test conflict')
  await page.getByRole('button', { name: 'Lưu thay đổi', exact: true }).click()
  await expect(page.getByRole('alert')).toContainText('người khác thay đổi')
  await expect(page.getByRole('button', { name: 'Lưu thay đổi', exact: true })).toBeDisabled()
  state.writeError = ''; state.config.version = '9'
  await page.getByRole('button', { name: 'Tải lại', exact: true }).click()
  await expect(page.getByText(/Phiên bản 9/)).toBeVisible()
  await expect(page.getByLabel('Nội dung banner')).toHaveValue('')
})

test('readonly admin sees values without editable or account controls', async ({ page }) => {
  const state = await setup(page); state.config.editable_sections = []
  await page.goto('/settings')
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await expect(page.getByLabel('Bảo trì Customer')).toHaveCount(0)
  await expect(page.locator('.setting-row').filter({ hasText: 'Bảo trì Customer' })).toContainText('Hiện tại: Tắt')
  await expect(page.getByLabel('Số ảnh / yêu cầu')).toHaveCount(0)
  await page.getByRole('tab', { name: 'Bảo mật & quyền' }).click()
  await expect(page.getByRole('heading', { name: 'Khóa tài khoản & phiên truy cập' })).toHaveCount(0)
})

test('permission denial renders no form and supports retry', async ({ page }) => {
  const state = await setup(page); state.error = 'ADMIN_FORBIDDEN'
  await page.goto('/settings')
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await expect(page.getByRole('alert')).toContainText('không có quyền')
  await expect(page.getByLabel('Bảo trì Customer')).toHaveCount(0)
  state.error = ''
  await page.getByRole('button', { name: 'Tải lại', exact: true }).click()
  await expect(page.getByLabel('Bảo trì Customer')).toBeVisible()
})

test('loading, empty configuration and independent audit error states', async ({ page }) => {
  const state = await setup(page)
  let releaseLoad!: () => void
  const pendingLoad = new Promise<void>((resolve) => { releaseLoad = resolve })
  await page.route('**/rest/v1/rpc/admin_get_system_config', async (route) => { await pendingLoad; await route.fallback() })
  await page.goto('/settings')
  await expect(page.getByText('Đang tải cấu hình...')).toBeVisible()
  releaseLoad()
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await expect(page.getByLabel('Bảo trì Customer')).toBeVisible()
  state.config.definitions = []; state.historyError = 'Audit unavailable'
  await page.getByRole('button', { name: 'Tải lại', exact: true }).click()
  await expect(page.getByText('Chưa có cấu hình hệ thống.')).toBeVisible()
  await page.getByRole('button', { name: 'Xem lịch sử', exact: true }).click()
  await expect(page.getByRole('alert')).toContainText('Audit unavailable')
})

test('account lock and revoke are reviewed and carry exact target version', async ({ page }) => {
  const state = await setup(page)
  await page.goto('/settings')
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await page.getByRole('tab', { name: 'Bảo mật & quyền' }).click()
  await page.getByLabel('UUID tài khoản').fill(state.account.user_id)
  await page.getByRole('button', { name: 'Tra cứu tài khoản' }).click()
  await page.getByLabel('Trạng thái tài khoản').selectOption('locked')
  await page.getByLabel('Thu hồi JWT đã cấp').check()
  await page.getByLabel('Lý do kiểm soát tài khoản').fill('Tài khoản kiểm thử')
  await page.getByRole('button', { name: 'Áp dụng kiểm soát tài khoản', exact: true }).click()
  await expect(page.getByRole('dialog')).toContainText(state.account.user_id)
  await page.getByRole('button', { name: 'Xác nhận áp dụng' }).click()
  await expect(page.getByText('Hiện tại: locked · v1')).toBeVisible()
  expect(state.calls.find((c) => c.name === 'admin_apply_system_account_control')?.body).toMatchObject({ p_expected_version: '0', p_revoke_tokens: true, p_status: 'locked', p_confirm_dangerous: true })
})

test('settings requires authenticated Admin session', async ({ page }) => {
  await paymentSession(page, false)
  await page.goto('/settings')
  await expect(page).toHaveURL(/\/login$/)
})

test('role change uses server-side access RPC with timestamp guard and review', async ({ page }) => {
  const state = await setup(page)
  state.account.admin_access = { role: 'operator', status: 'active', updated_at: timestamp }
  await page.goto('/settings')
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await page.getByRole('tab', { name: 'Bảo mật & quyền' }).click()
  await page.getByLabel('UUID tài khoản').fill(state.account.user_id)
  await page.getByRole('button', { name: 'Tra cứu tài khoản' }).click()
  await page.getByLabel('Vai trò Admin').selectOption('support')
  await page.getByLabel('Lý do đổi quyền Admin').fill('Chuyển bộ phận hỗ trợ')
  await page.getByRole('button', { name: 'Lưu quyền Admin', exact: true }).click()
  await expect(page.getByRole('dialog')).toContainText('support')
  await page.getByRole('button', { name: 'Xác nhận đổi quyền', exact: true }).click()
  await expect(page.getByText('Hiện tại: support · active')).toBeVisible()
  expect(state.calls.find((c) => c.name === 'admin_apply_system_admin_access')?.body).toMatchObject({ p_role: 'support', p_expected_updated_at: timestamp, p_confirm_dangerous: true })
})

test('malformed config response shows a recoverable error instead of crashing the route', async ({ page }) => {
  const state = await setup(page)
  const errors: string[] = []
  page.on('pageerror', (e) => errors.push(e.message))
  await page.route('**/rest/v1/rpc/admin_get_system_config', (route) => route.fulfill({
    contentType: 'application/json', body: JSON.stringify({ success: true, changed: true }),
  }))
  await page.goto('/settings')
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await expect(page.getByRole('alert')).toContainText('Dữ liệu cấu hình không hợp lệ')
  await expect(page.getByLabel('Bảo trì Customer')).toHaveCount(0)
  await page.unroute('**/rest/v1/rpc/admin_get_system_config')
  await page.getByRole('button', { name: 'Tải lại', exact: true }).click()
  await expect(page.getByLabel('Bảo trì Customer')).toBeVisible()
  expect(state.calls.some((c) => c.name.includes('apply'))).toBe(false)
  expect(errors).toEqual([])
})

test('permission editor rejects nulls, invalid identifiers and duplicates but accepts valid roles', async ({ page }) => {
  const state = await setup(page)
  const groups = { customer: ['super_admin', 'operator'], rescuer: ['super_admin'], payment: ['super_admin'], security: ['super_admin'] }
  state.config.definitions.push({ key: 'security.role_permissions', section: 'security', label: 'Quyền theo nhóm', kind: 'permissions', minimum: null, maximum: null, dangerous: true })
  state.config.values['security.role_permissions'] = groups
  await page.goto('/settings')
  await page.getByRole('tab', { name: 'Customer', exact: true }).click()
  await page.getByRole('tab', { name: 'Bảo mật & quyền' }).click()
  await page.getByLabel('Quyền theo nhóm').fill('null')
  await page.getByLabel('Lý do thay đổi', { exact: true }).fill('permission matrix validation')
  for (const customer of [['super_admin', null], [null], ['config.read', null], ['config.read', 'config.write', null], ['super_admin', ''], ['super_admin', 'invalid'], ['super_admin', 1], ['super_admin', {}], ['super_admin', 'operator', 'operator']]) {
    await page.getByLabel('Quyền theo nhóm').fill(JSON.stringify({ ...groups, customer }))
    await expect(page.getByRole('button', { name: 'Lưu thay đổi', exact: true })).toBeDisabled()
  }
  expect(state.calls.some((c) => c.name.includes('apply'))).toBe(false)
  await page.getByLabel('Quyền theo nhóm').fill(JSON.stringify({ ...groups, customer: ['super_admin', 'support'] }))
  await page.getByRole('button', { name: 'Lưu thay đổi', exact: true }).click()
  await page.getByRole('button', { name: 'Xác nhận lưu', exact: true }).click()
  await expect(page.getByText('Đã lưu cấu hình và ghi lịch sử.')).toBeVisible()
  expect(state.calls.find((c) => c.name === 'admin_apply_system_config')?.body.p_patch).toEqual({ 'security.role_permissions': { ...groups, customer: ['super_admin', 'support'] } })
})
