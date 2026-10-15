import type { SystemConfig } from '../src/lib/systemConfigApi'
import { timestamp } from './paymentFixtures'
export const fixture: SystemConfig = {
  version: '1', updated_at: timestamp, editable_sections: ['customer', 'rescuer', 'payment', 'security'],
  values: { 'customer.maintenance': false, 'customer.max_photos': 3, 'customer.banner': '', 'rescuer.online_enabled': true, 'payment.cash_enabled': true, 'security.kill_new_requests': false },
  definitions: [
    { key: 'customer.maintenance', section: 'customer', label: 'Bảo trì Customer', kind: 'boolean', minimum: null, maximum: null, dangerous: true },
    { key: 'customer.max_photos', section: 'customer', label: 'Số ảnh / yêu cầu', kind: 'integer', minimum: 0, maximum: 3, dangerous: false },
    { key: 'customer.banner', section: 'customer', label: 'Nội dung banner', kind: 'text', minimum: 0, maximum: 500, dangerous: false },
    { key: 'rescuer.online_enabled', section: 'rescuer', label: 'Cho phép chuyển online', kind: 'boolean', minimum: null, maximum: null, dangerous: true },
    { key: 'payment.cash_enabled', section: 'payment', label: 'Cho phép chọn tiền mặt', kind: 'boolean', minimum: null, maximum: null, dangerous: true },
    { key: 'security.kill_new_requests', section: 'security', label: 'Dừng tạo yêu cầu khẩn cấp', kind: 'boolean', minimum: null, maximum: null, dangerous: true },
  ],
}

// Full public-safe catalog for grouping, permissions and responsive UI coverage.
export const fullFixture: SystemConfig = structuredClone(fixture)
const additional: [string, SystemConfig['definitions'][number]['section'], string, boolean | number | string, boolean, number | null, number | null][] = [
  ['customer.requests_enabled', 'customer', 'Cho phép tạo yêu cầu', true, true, null, null],
  ['customer.banner_enabled', 'customer', 'Hiển thị banner', false, false, null, null],
  ['rescuer.maintenance', 'rescuer', 'Bảo trì Rescuer', false, true, null, null],
  ['rescuer.offline_enabled', 'rescuer', 'Cho phép chuyển offline', true, true, null, null],
  ['rescuer.max_active_jobs', 'rescuer', 'Job đồng thời (V1 hỗ trợ 1)', 1, true, 1, 1],
  ['rescuer.quotes_enabled', 'rescuer', 'Cho phép báo giá mới', true, true, null, null],
  ['rescuer.quote_min_vnd', 'rescuer', 'Báo giá tối thiểu (VND)', 0, true, 0, 2147483647],
  ['rescuer.quote_max_vnd', 'rescuer', 'Báo giá tối đa (VND)', 2147483647, true, 0, 2147483647],
  ['rescuer.bank_payment_visible', 'rescuer', 'Hiển thị thanh toán ngân hàng', true, false, null, null],
  ['payment.bank_enabled', 'payment', 'Cho phép tạo QR ngân hàng mới', true, true, null, null],
  ['payment.cash_confirmation_enabled', 'payment', 'Cho phép xác nhận tiền mặt', true, true, null, null],
  ['payment.qr_expiry_seconds', 'payment', 'QR hết hạn (giây, chỉ QR mới)', 900, true, 60, 86400],
  ['payment.min_vnd', 'payment', 'Thanh toán tối thiểu (VND)', 1, true, 1, 2147483647],
  ['payment.max_vnd', 'payment', 'Thanh toán tối đa (VND)', 2147483647, true, 1, 9999999999999],
  ['business.platform_fee_bps', 'payment', 'Phí nền tảng dự kiến (basis points, 100 = 1%)', 0, true, 0, 10000],
  ['business.rescuer_commission_bps', 'payment', 'Hoa hồng đối tác dự kiến (basis points)', 0, true, 0, 10000],
  ['business.customer_cancellation_enabled', 'payment', 'Cho phép khách hủy yêu cầu', true, true, null, null],
  ['business.refunds_enabled', 'payment', 'Cho phép mở refund mới', true, true, null, null],
  ['business.late_refunds_enabled', 'payment', 'Cho phép mở refund late payment', true, true, null, null],
  ['security.kill_new_jobs', 'security', 'Dừng nhận job khẩn cấp', false, true, null, null],
  ['security.kill_new_bank_intents', 'security', 'Dừng tạo QR khẩn cấp', false, true, null, null],
  ['security.max_token_age_seconds', 'security', 'Tuổi JWT tối đa (0 = theo Auth hiện tại)', 0, true, 0, 86400],
  ['security.admin_mfa_required', 'security', 'Bắt buộc Admin AAL2 / MFA', false, true, null, null],
]
for (const [key, section, label, value, dangerous, minimum, maximum] of additional) {
  fullFixture.values[key] = value
  fullFixture.definitions.push({ key, section, label, dangerous, minimum, maximum, kind: typeof value === 'boolean' ? 'boolean' : typeof value === 'number' ? 'integer' : 'text' })
}
fullFixture.values['security.role_permissions'] = { customer: ['super_admin', 'operator'], rescuer: ['super_admin', 'operator'], payment: ['super_admin', 'finance'], security: ['super_admin'] }
fullFixture.definitions.push({ key: 'security.role_permissions', section: 'security', label: 'Vai trò được sửa từng nhóm', kind: 'permissions', minimum: null, maximum: null, dangerous: true })
