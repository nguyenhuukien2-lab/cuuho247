export const formatCurrency = (value: number) => new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND', maximumFractionDigits: 0 }).format(value)
export const initials = (name: string) => name.split(' ').slice(-2).map((part) => part[0]).join('').toUpperCase()
