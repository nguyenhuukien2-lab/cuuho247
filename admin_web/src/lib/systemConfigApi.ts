import { supabase } from './supabase'
export type ConfigValue = boolean | number | string | Record<string, string[]>
export type Section = 'customer' | 'rescuer' | 'payment' | 'security'
export interface ConfigDefinition {
  key: string; section: Section; label: string; kind: 'boolean' | 'integer' | 'text' | 'permissions'
  minimum: number | null; maximum: number | null; dangerous: boolean
}
export interface SystemConfig {
  version: string; updated_at: string; values: Record<string, ConfigValue>
  definitions: ConfigDefinition[]; editable_sections: Section[]
}
export interface ConfigAudit {
  id: string; actor_id: string; action: string; target: string; version: string
  before_value: Record<string, unknown>; after_value: Record<string, unknown>; reason: string; created_at: string
}
export interface AccountControl {
  user_id: string; status: 'active' | 'locked' | 'suspended'; version: string
  suspended_until: string | null; tokens_valid_after: string | null
  admin_access?: { role: string; status: string; updated_at: string } | null
}
async function rpc<T>(name: string, params?: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.rpc(name, params)
  if (error) throw new Error(error.message)
  if (data === null) throw new Error('Máy chủ chưa trả kết quả. Vui lòng tải lại.')
  return data as T
}
function record(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
}
function parseSystemConfig(value: unknown): SystemConfig {
  const sections = ['customer', 'rescuer', 'payment', 'security']
  const invalid = () => { throw new Error('Dữ liệu cấu hình không hợp lệ. Vui lòng tải lại.') }
  if (!record(value) || typeof value.version !== 'string' || !/^[1-9][0-9]*$/.test(value.version) ||
    typeof value.updated_at !== 'string' || !Number.isFinite(Date.parse(value.updated_at)) ||
    !record(value.values) || !Array.isArray(value.definitions) || !Array.isArray(value.editable_sections) ||
    value.editable_sections.some((s) => typeof s !== 'string' || !sections.includes(s))) return invalid()
  const keys = new Set<string>()
  for (const d of value.definitions) {
    if (!record(d) || typeof d.key !== 'string' || keys.has(d.key) ||
      typeof d.label !== 'string' || typeof d.section !== 'string' || !sections.includes(d.section) ||
      !['boolean', 'integer', 'text', 'permissions'].includes(String(d.kind)) || typeof d.dangerous !== 'boolean' ||
      ![d.minimum, d.maximum].every((n) => n === null || (typeof n === 'number' && Number.isSafeInteger(n))) ||
      validateConfig(d as unknown as ConfigDefinition, value.values[d.key] as ConfigValue)) return invalid()
    keys.add(d.key)
  }
  return value as unknown as SystemConfig
}
export const getSystemConfig = async () => parseSystemConfig(await rpc<unknown>('admin_get_system_config'))
export const updateSystemConfig = async (patch: Record<string, ConfigValue>, version: string, reason: string, confirmed: boolean) =>
  parseSystemConfig(await rpc<unknown>('admin_apply_system_config', { p_patch: patch, p_expected_version: version, p_reason: reason, p_confirm_dangerous: confirmed }))
export const getSystemAudit = (beforeId: string | null = null) =>
  rpc<{ rows: ConfigAudit[] }>('admin_list_system_config_audit', { p_before_id: beforeId, p_limit: 30 })
export const getAccountControl = (id: string) => rpc<AccountControl>('admin_get_system_account_control', { p_user_id: id })
export const updateAccountControl = (a: AccountControl, status: AccountControl['status'], until: string | null, revoke: boolean, reason: string) =>
  rpc<AccountControl>('admin_apply_system_account_control', { p_user_id: a.user_id, p_status: status,
    p_suspended_until: until, p_revoke_tokens: revoke, p_expected_version: a.version, p_reason: reason, p_confirm_dangerous: true })
export const updateAdminAccess = (a: AccountControl, role: string, status: string, reason: string) =>
  rpc<AccountControl>('admin_apply_system_admin_access', { p_user_id: a.user_id, p_role: role, p_status: status,
    p_expected_updated_at: a.admin_access?.updated_at, p_reason: reason, p_confirm_dangerous: true })
export function validateConfig(d: ConfigDefinition, raw: ConfigValue): string | null {
  if (d.kind === 'boolean') return typeof raw === 'boolean' ? null : 'Chọn bật hoặc tắt.'
  if (d.kind === 'text') return typeof raw === 'string' && raw.length <= (d.maximum ?? 500) ? null : 'Nội dung quá dài.'
  if (d.kind === 'integer') {
    const v = typeof raw === 'string' && /^\d+$/.test(raw) ? Number(raw) : raw
    return typeof v === 'number' && Number.isSafeInteger(v) && v >= (d.minimum ?? 0) && v <= (d.maximum ?? Number.MAX_SAFE_INTEGER)
      ? null : `Nhập số nguyên từ ${d.minimum} đến ${d.maximum}.`
  }
  try {
    const v = typeof raw === 'string' ? JSON.parse(raw) : raw
    const groups = ['customer', 'rescuer', 'payment', 'security']
    const roles = ['super_admin', 'operator', 'support', 'partner_reviewer', 'finance']
    if (!v || Array.isArray(v) || Object.keys(v).length !== 4 || groups.some((k) => !Array.isArray(v[k]) || v[k].length < 1 || v[k].length > 5 || new Set(v[k]).size !== v[k].length || !v[k].includes('super_admin') || v[k].some((r: unknown) => typeof r !== 'string' || !roles.includes(r))) || JSON.stringify(v.security) !== '["super_admin"]') return 'Mỗi nhóm phải giữ super_admin; Security chỉ dành cho super_admin.'
    return null
  } catch { return 'JSON phân quyền không hợp lệ.' }
}
export function configError(e: unknown): string {
  const m = e instanceof Error ? e.message : 'Không thể kết nối. Vui lòng thử lại.'
  if (m.includes('VERSION_CONFLICT')) return 'Cấu hình đã được người khác thay đổi. Tải lại trước khi lưu.'
  if (m.includes('FORBIDDEN') || m.includes('DENIED')) return 'Bạn không có quyền thực hiện thao tác này.'
  if (m.includes('INCONSISTENT')) return 'Giới hạn min/max hoặc tổng phí và hoa hồng không hợp lệ.'
  if (m.includes('MFA_ENROLLMENT')) return 'Cần đăng nhập với MFA trước khi bật yêu cầu MFA.'
  return m
}
