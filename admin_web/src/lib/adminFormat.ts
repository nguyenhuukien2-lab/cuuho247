import { formatCurrency } from './format'
import type { Numeric } from './adminTypes'

export const missing = 'Chưa có dữ liệu'
export const textValue = (value: string | null | undefined) => value?.trim() || missing
export const numberValue = (value: Numeric | undefined) => Number.isFinite(Number(value)) ? Number(value) : 0
export const countValue = (value: Numeric | undefined) => numberValue(value).toLocaleString('vi-VN')
export const moneyValue = (value: Numeric | undefined) => value === null || value === undefined || value === '' ? missing : formatCurrency(numberValue(value))
export const codeValue = (code: string | null | undefined) =>
  code?.trim() && !/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i.test(code) ? code.trim() : 'Chưa có mã'
export const dateValue = (value: string | null | undefined) => {
  if (!value || Number.isNaN(Date.parse(value))) return missing
  return new Intl.DateTimeFormat('vi-VN', { dateStyle: 'short', timeStyle: 'short', timeZone: 'Asia/Ho_Chi_Minh' }).format(new Date(value))
}
const statuses: Record<string, string> = {
  searching: 'Chờ điều phối', accepted: 'Đã nhận đơn', arriving: 'Đang di chuyển', in_progress: 'Đang cứu hộ',
  completed: 'Hoàn tất', cancelled: 'Đã hủy', draft: 'Bản nháp', submitted: 'Chờ duyệt',
  approved: 'Đã duyệt', rejected: 'Đã từ chối', suspended: 'Đã khóa', issued: 'Đã phát hành',
  superseded: 'Đã thay thế', active: 'Hoạt động', blocked: 'Đã khóa',
}
export const statusValue = (value: string | null | undefined) => value ? (statuses[value] ?? value) : missing
const services: Record<string, string> = { towing: 'Kéo xe', battery: 'Ắc quy', tire: 'Lốp xe', fuel: 'Tiếp nhiên liệu', locksmith: 'Mở khóa', mechanic: 'Sửa chữa', other: 'Khác' }
export const serviceValue = (value: string | null | undefined) => value ? (services[value] ?? value) : missing
export const canCancel = (status: string | null) => ['searching', 'accepted', 'arriving'].includes(status ?? '')
export const matchesSearch = (query: string, ...values: (string | null | undefined)[]) =>
  values.join(' ').toLocaleLowerCase('vi').includes(query.trim().toLocaleLowerCase('vi'))
export const newestFirst = <T extends { created_at: string | null }>(rows: T[]) =>
  [...rows].sort((a, b) => (Date.parse(b.created_at ?? '') || 0) - (Date.parse(a.created_at ?? '') || 0))
