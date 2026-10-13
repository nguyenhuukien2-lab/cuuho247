import type { PaymentFilters, PaymentStatus } from './paymentTypes'

export const paymentStatuses: Record<PaymentStatus, [string, 'blue' | 'green' | 'orange' | 'red' | 'slate']> = {
  pending: ['Đang chờ', 'slate'], awaiting_payment: ['Chờ thanh toán', 'orange'],
  verifying: ['Đang xác minh', 'blue'], paid: ['Đã thanh toán', 'green'],
  failed: ['Thất bại', 'red'], cancelled: ['Đã hủy', 'slate'], expired: ['Hết hạn', 'slate'], refunded: ['Đã hoàn tiền', 'slate'],
}
export const defaultPaymentFilters: PaymentFilters = { search: '', method: '', status: '', from: '', to: '', minAmount: '', maxAmount: '' }
export const methodLabel = (method: string | null | undefined) => method === 'cash' ? 'Tiền mặt' : method === 'bank_transfer' ? 'Chuyển khoản' : '—'
export const paymentCount = (value: number | null | undefined) => value != null && Number.isSafeInteger(value) && value >= 0 ? value.toLocaleString('vi-VN') : '—'

export function paymentMoney(value: string | null | undefined): string {
  if (value == null || !/^\d+$/.test(value)) return '—'
  return new Intl.NumberFormat('vi-VN').format(BigInt(value)) + ' ₫'
}
export function validateFilters(filters: PaymentFilters) {
  if (filters.from && filters.to && filters.from > filters.to) return 'Ngày kết thúc phải bằng hoặc sau ngày bắt đầu.'
  if ([filters.minAmount, filters.maxAmount].some((value) => value !== '' && !/^\d+$/.test(value))) return 'Số tiền phải là số nguyên không âm.'
  if (filters.minAmount && filters.maxAmount && BigInt(filters.minAmount) > BigInt(filters.maxAmount)) return 'Số tiền tối đa phải bằng hoặc lớn hơn số tiền tối thiểu.'
  if (filters.provider && !/^[a-z][a-z0-9_]{0,63}$/.test(filters.provider)) return 'Nhà cung cấp chỉ gồm chữ thường, số và dấu gạch dưới.'
  return ''
}
