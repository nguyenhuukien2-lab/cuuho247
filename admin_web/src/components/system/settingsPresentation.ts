import type { ConfigDefinition, ConfigValue, Section } from '../../lib/systemConfigApi'

export type SettingsTab = 'overview' | Section
export const settingsTabs: { id: SettingsTab; label: string }[] = [
  { id: 'overview', label: 'Tổng quan' }, { id: 'customer', label: 'Customer' },
  { id: 'rescuer', label: 'Rescuer' }, { id: 'payment', label: 'Thanh toán' },
  { id: 'security', label: 'Bảo mật & quyền' },
]

// Presentation allowlist: never render arbitrary private payment/config fields.
export const settingDescriptions: Record<string, string> = {
  'customer.banner': 'Thông báo ngắn dành cho khách hàng.',
  'customer.banner_enabled': 'Hiển thị nội dung banner trong ứng dụng Customer.',
  'customer.requests_enabled': 'Cho phép khách hàng gửi yêu cầu cứu hộ mới.',
  'customer.max_photos': 'Giới hạn ảnh đính kèm cho mỗi yêu cầu.',
  'customer.maintenance': 'Tạm dừng thao tác của Customer để bảo trì.',
  'rescuer.maintenance': 'Tạm dừng thao tác của đối tác để bảo trì.',
  'rescuer.online_enabled': 'Cho phép đối tác chuyển sang sẵn sàng nhận việc.',
  'rescuer.offline_enabled': 'Cho phép đối tác chuyển sang ngoại tuyến.',
  'rescuer.max_active_jobs': 'Số công việc đối tác có thể xử lý đồng thời.',
  'rescuer.quotes_enabled': 'Cho phép đối tác gửi báo giá mới.',
  'rescuer.quote_min_vnd': 'Mức tiền thấp nhất cho một báo giá.',
  'rescuer.quote_max_vnd': 'Mức tiền cao nhất cho một báo giá.',
  'rescuer.bank_payment_visible': 'Hiển thị phương thức ngân hàng cho đối tác.',
  'payment.cash_confirmation_enabled': 'Cho phép đối tác xác nhận đã nhận tiền mặt.',
  'payment.cash_enabled': 'Cho phép lựa chọn thanh toán tiền mặt.',
  'payment.bank_enabled': 'Cho phép tạo mã QR chuyển khoản mới.',
  'payment.qr_expiry_seconds': 'Thời hạn tính bằng giây, áp dụng cho QR mới.',
  'payment.min_vnd': 'Số tiền thanh toán tối thiểu, tính bằng VND.',
  'payment.max_vnd': 'Số tiền thanh toán tối đa, tính bằng VND.',
  'business.platform_fee_bps': 'Phí dự kiến cho báo giá mới; 100 basis points = 1%.',
  'business.rescuer_commission_bps': 'Hoa hồng dự kiến cho báo giá mới; 100 basis points = 1%.',
  'business.customer_cancellation_enabled': 'Cho phép khách hàng hủy yêu cầu.',
  'business.refunds_enabled': 'Cho phép mở yêu cầu hoàn tiền mới.',
  'business.late_refunds_enabled': 'Cho phép mở hoàn tiền cho thanh toán trễ.',
  'security.kill_new_requests': 'Dừng khẩn cấp việc tạo yêu cầu cứu hộ mới.',
  'security.kill_new_jobs': 'Dừng khẩn cấp việc nhận công việc mới.',
  'security.kill_new_bank_intents': 'Dừng khẩn cấp việc tạo QR ngân hàng mới.',
  'security.max_token_age_seconds': 'Tuổi JWT tối đa theo giây; 0 dùng chính sách Auth hiện tại.',
  'security.admin_mfa_required': 'Yêu cầu Admin đăng nhập với MFA / AAL2.',
  'security.role_permissions': 'Vai trò được sửa từng nhóm; bảo mật chỉ dành cho super_admin.',
}
export const isVisibleSetting = (key: string) => Object.hasOwn(settingDescriptions, key)

export const settingGroups: Record<Section, { title: string; keys: string[]; note?: string }[]> = {
  customer: [
    { title: 'Banner', keys: ['customer.banner', 'customer.banner_enabled'] },
    { title: 'Yêu cầu cứu hộ', keys: ['customer.requests_enabled', 'customer.max_photos'] },
    { title: 'Trạng thái hệ thống', keys: ['customer.maintenance', 'security.kill_new_requests'] },
  ],
  rescuer: [
    { title: 'Trạng thái đối tác', keys: ['rescuer.online_enabled', 'rescuer.offline_enabled', 'rescuer.maintenance'] },
    { title: 'Công việc', keys: ['rescuer.max_active_jobs', 'rescuer.quotes_enabled', 'rescuer.quote_min_vnd', 'rescuer.quote_max_vnd'] },
    { title: 'Thanh toán', keys: ['rescuer.bank_payment_visible', 'payment.cash_confirmation_enabled'] },
  ],
  payment: [
    { title: 'Phương thức', keys: ['payment.cash_enabled', 'payment.bank_enabled'] },
    { title: 'Bank / QR', keys: ['payment.qr_expiry_seconds', 'payment.min_vnd', 'payment.max_vnd'] },
    { title: 'Chính sách', keys: ['business.platform_fee_bps', 'business.rescuer_commission_bps', 'business.customer_cancellation_enabled', 'business.refunds_enabled', 'business.late_refunds_enabled'], note: 'V1 ghi nhận phí và hoa hồng cho báo giá mới, chưa tự thu phí hoặc khấu trừ hoa hồng.' },
  ],
  security: [
    { title: 'Bảo mật tài khoản', keys: ['security.max_token_age_seconds', 'security.admin_mfa_required'] },
    { title: 'Điều khiển khẩn cấp', keys: ['security.kill_new_requests', 'security.kill_new_jobs', 'security.kill_new_bank_intents', 'customer.maintenance', 'rescuer.maintenance'] },
    { title: 'RBAC · Vai trò & quyền', keys: ['security.role_permissions'] },
  ],
}

export function formatSettingValue(value: unknown): string {
  if (value === undefined || value === null) return 'Chưa có dữ liệu'
  if (typeof value === 'boolean') return value ? 'Bật' : 'Tắt'
  if (value === '') return 'Chưa nhập'
  return typeof value === 'object' ? JSON.stringify(value) : String(value)
}

function canonical(value: unknown): string {
  if (Array.isArray(value)) return JSON.stringify(value.map(canonical).sort())
  if (value && typeof value === 'object') return JSON.stringify(Object.entries(value).sort(([a], [b]) => a.localeCompare(b)).map(([k, v]) => [k, canonical(v)]))
  return JSON.stringify(value)
}

// Compare editor representations without changing validation or the save payload.
export function isSettingDirty(d: ConfigDefinition, draft: ConfigValue, current: ConfigValue): boolean {
  let value: ConfigValue = draft
  if (d.kind === 'integer' && typeof value === 'string' && /^\d+$/.test(value)) value = Number(value)
  if (d.kind === 'permissions' && typeof value === 'string') {
    try { value = JSON.parse(value) } catch { return true }
  }
  return canonical(value) !== canonical(current)
}
