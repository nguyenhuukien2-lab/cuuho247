import type { LucideIcon } from 'lucide-react'
import { ArrowUpRight, Bell, CheckCircle2, Clock3, ShieldCheck, Truck, Users, Wallet, XCircle, ClipboardList, BatteryCharging, CircleDot, Fuel, KeyRound, Wrench } from 'lucide-react'
import type { Tone } from '../../lib/uiTypes'
const icons: Record<string, LucideIcon> = { users: Users, shield: ShieldCheck, clipboard: ClipboardList, clock: Clock3, check: CheckCircle2, x: XCircle, wallet: Wallet, truck: Truck, battery: BatteryCharging, disc: CircleDot, fuel: Fuel, key: KeyRound, wrench: Wrench, bell: Bell }
export function StatCard({ label, value, note, tone = 'blue', icon = 'clipboard' }: { label: string; value: string; note?: string; tone?: Tone; icon?: string }) {
  const Icon = icons[icon] ?? ClipboardList
  return <article className="stat-card">
    <div className="stat-head"><span>{label}</span><span className={'icon-box ' + tone}><Icon size={17} strokeWidth={2.2} /></span></div>
    <strong className={'stat-value ' + tone}>{value}</strong>
    {note && <span className="stat-note"><ArrowUpRight size={13} /> {note}</span>}
  </article>
}
export function ServiceIcon({ name, size = 19 }: { name: string; size?: number }) { const Icon = icons[name] ?? Truck; return <Icon size={size} /> }
