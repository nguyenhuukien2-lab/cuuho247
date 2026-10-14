import { useState } from 'react'
import { ChevronDown, Wallet } from 'lucide-react'
import { Link, matchPath } from 'react-router-dom'

const items = [
  { to: '/payments', label: 'Tổng quan' },
  { to: '/payments/list', label: 'Danh sách thanh toán' },
  { to: '/payments/bank-transactions', label: 'Giao dịch ngân hàng' },
  { to: '/payments/operations', label: 'Vận hành thanh toán' },
]

export function PaymentNavigation({ pathname, onNavigate }: { pathname: string; onNavigate?: () => void }) {
  const inPayments = !!matchPath('/payments/*', pathname)
  const [open, setOpen] = useState(inPayments)
  const current = items.find(({ to }) => matchPath(to, pathname))?.to
  const active = current ?? (matchPath('/payments/:paymentId', pathname) ? '/payments/list' : undefined)

  return <div className="payment-navigation">
    <button type="button" className={'nav-item payment-nav-toggle' + (inPayments ? ' in-payment-section' : '')} aria-expanded={open} aria-controls="payment-submenu" onClick={() => setOpen(!open)}>
      <Wallet size={18} strokeWidth={1.8} aria-hidden="true"/><span>Quản lý Thanh toán</span><ChevronDown className="payment-nav-chevron" size={16} aria-hidden="true"/>
    </button>
    <ul id="payment-submenu" className="payment-submenu" aria-label="Điều hướng thanh toán" hidden={!open}>
      {items.map(({ to, label }) => <li key={to}><Link to={to} onClick={onNavigate} className={'payment-nav-link' + (active === to ? ' active' : '')} aria-current={active === to ? (current ? 'page' : 'location') : undefined}>{label}</Link></li>)}
    </ul>
  </div>
}
