import { SectionCard } from '../ui/SectionCard'
import type { SystemConfig, Section } from '../../lib/systemConfigApi'
import { formatSettingValue } from './settingsPresentation'

const summaries: { tab: Section; title: string; items: [string, string][] }[] = [
  { tab: 'customer', title: 'Customer', items: [['Bảo trì', 'customer.maintenance'], ['Tạo yêu cầu', 'customer.requests_enabled'], ['Số ảnh tối đa', 'customer.max_photos']] },
  { tab: 'rescuer', title: 'Rescuer', items: [['Bảo trì', 'rescuer.maintenance'], ['Cho phép online', 'rescuer.online_enabled'], ['Cho phép offline', 'rescuer.offline_enabled'], ['Job đồng thời', 'rescuer.max_active_jobs']] },
  { tab: 'payment', title: 'Thanh toán', items: [['Tiền mặt', 'payment.cash_enabled'], ['Chuyển khoản', 'payment.bank_enabled'], ['QR hết hạn (giây)', 'payment.qr_expiry_seconds']] },
  { tab: 'security', title: 'Security', items: [['MFA Admin', 'security.admin_mfa_required'], ['Tuổi JWT tối đa (giây)', 'security.max_token_age_seconds']] },
]
export function SettingsOverview({ config, onSelect }: { config: SystemConfig; onSelect: (tab: Section) => void }) {
  const has = (key: string) => config.definitions.some((d) => d.key === key)
  const value = (key: string) => formatSettingValue(has(key) ? config.values[key] : undefined)
  const kills = config.definitions.filter((d) => ['security.kill_new_requests', 'security.kill_new_jobs', 'security.kill_new_bank_intents'].includes(d.key))
  return <><p className="settings-tab-note">Trạng thái đã lưu trên hệ thống. Chọn một nhóm để xem và chỉnh sửa.</p>
    <div className="system-config-grid settings-overview">{summaries.map(({ tab, title, items }) => <SectionCard key={tab} title={title} action={<button className="settings-text-button" onClick={() => onSelect(tab)} aria-label={`Xem cấu hình ${title}`}>Chi tiết →</button>}>
      <dl>{items.map(([label, key]) => <div key={key}><dt>{label}</dt><dd>{value(key)}</dd></div>)}
        {tab === 'security' && <><div><dt>Kill switch</dt><dd>{kills.length ? `${kills.filter((d) => config.values[d.key] === true).length}/${kills.length} đang bật` : 'Chưa có dữ liệu'}</dd></div>
          <div><dt>RBAC</dt><dd>{has('security.role_permissions') ? 'Đã cấu hình' : 'Theo phân quyền hiện tại'}</dd></div></>}
      </dl>
    </SectionCard>)}</div></>
}
