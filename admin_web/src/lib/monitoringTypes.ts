export type MonitoringStatus = 'healthy' | 'degraded' | 'critical'
export type AlertSeverity = 'info' | 'warning' | 'critical'
export type MonitoringSection = 'overview' | 'payment' | 'webhook' | 'rescue' | 'security' | 'alerts'

export interface MonitoringSummary {
  overall_status: MonitoringStatus
  webhook_status: MonitoringStatus
  webhook_4xx: number
  webhook_5xx: number
  payment_failures: number
  pending_payments: number
  rejected_transactions: number
  incomplete_receipts: number
  active_rescue_requests: number
  online_rescuers: number
  restricted_accounts: number
  recent_security_events: number
  open_alerts: number
  critical_alerts: number
}

export interface MonitoringAlert {
  key: string
  fingerprint: string
  severity: AlertSeverity
  category: string
  code: string
  title: string
  message: string
  detected_at: string | null
  entity_type: string | null
  entity_id: string | null
  detail: Record<string, string | number | boolean | null>
  acknowledged: boolean
  acknowledged_at: string | null
  acknowledged_by: string | null
}

export interface MonitoringEvent {
  id: string
  category: string
  code: string
  status: string
  severity: AlertSeverity
  occurred_at: string | null
  entity_type: string | null
  entity_id: string | null
  detail: Record<string, string | number | boolean | null>
}

export interface MonitoringDeliveryChannel {
  channel: 'admin_web' | 'telegram' | 'email'
  status: 'active' | 'requires_server_configuration'
  description: string
}

export interface MonitoringDashboard {
  generated_at: string | null
  window_hours: number
  can_acknowledge: boolean
  summary: MonitoringSummary
  alerts: MonitoringAlert[]
  payment_events: MonitoringEvent[]
  webhook_events: MonitoringEvent[]
  rescue_events: MonitoringEvent[]
  security_events: MonitoringEvent[]
  delivery_channels: MonitoringDeliveryChannel[]
}
