import type { ReactNode } from 'react'

interface SettingRowProps {
  id: string
  label: string
  description?: string
  currentValue: string
  control: ReactNode
  dangerous?: boolean
  dirty?: boolean
  badge?: ReactNode
  helperText?: string | null
}

export function SettingRow({ id, label, description, currentValue, control, dangerous, dirty, badge, helperText }: SettingRowProps) {
  return <div className={`setting-row${dirty ? ' is-dirty' : ''}`} data-dirty={dirty || undefined}>
    <div className="setting-row-copy">
      <div className="setting-row-title"><label htmlFor={id}>{label}</label>{dangerous && <span className="system-danger">Cần xác nhận</span>}{badge}</div>
      {description && <p id={`${id}-description`}>{description}</p>}
      <small className="setting-current">Hiện tại: {currentValue}</small>
      {dirty && <span className="setting-dirty-label">Đã chỉnh sửa</span>}
    </div>
    <div className="setting-row-control">{control}{helperText && <small id={`${id}-error`} className="setting-validation" role="alert">{helperText}</small>}</div>
  </div>
}
