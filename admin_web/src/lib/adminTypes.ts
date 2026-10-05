export type Numeric = number | string | null
export type ApiResult<T> = { data: T; error: null } | { data: null; error: string }
export interface AdminProfile {
  id: string; admin_code: string | null; full_name: string | null
}
export interface DashboardStats {
  total_customers?: Numeric; total_rescuers?: Numeric; today_requests?: Numeric
  active_requests?: Numeric; completed_requests?: Numeric; cancelled_requests?: Numeric
  today_revenue?: Numeric; online_rescuers?: Numeric; pending_rescuers?: Numeric; average_rating?: Numeric
  revenue_visible?: boolean; revenue_basis?: string
}
export interface Customer {
  customer_id: string; customer_code?: string | null; full_name: string | null
  email: string | null; phone: string | null; vehicle_count: Numeric; address_count: Numeric
  request_count: Numeric; completed_count: Numeric; total_spent: Numeric; created_at: string | null; status: string | null
}
export interface Rescuer {
  rescuer_id: string; rescuer_code?: string | null; full_name: string | null
  phone: string | null; email: string | null; approval_status: string | null
  online_status: boolean | null; is_available: boolean | null; last_seen_at: string | null
  vehicle_count: Numeric; service_count: Numeric; completed_jobs: Numeric; average_rating: Numeric; created_at: string | null
}
export interface RescueRequest {
  request_id: string; request_code: string | null; customer_id: string | null
  customer_name: string | null; customer_phone: string | null; customer_email: string | null
  service_type: string | null; problem_description: string | null; vehicle_name: string | null; vehicle_plate: string | null
  status: string | null; pickup_address: string | null; destination_address: string | null
  rescuer_id: string | null; rescuer_name: string | null; rescuer_phone: string | null
  quote_amount: Numeric; quote_status: string | null; created_at: string | null; accepted_at: string | null; completed_at: string | null
}
export interface Service {
  service_id: string; code: string | null; admin_code?: string | null; app_service_code: string | null
  name: string | null; description: string | null; icon: string | null
  base_price: Numeric; price_unit: string | null; is_active: boolean; is_featured: boolean; sort_order: Numeric
}
export interface Quote {
  quote_id: string; quote_code?: string | null; request_id: string; request_code: string | null
  customer_name: string | null; rescuer_name: string | null; service_type: string | null
  amount: Numeric; note: string | null; status: string | null; created_at: string | null
  is_current: boolean; is_completion_quote: boolean; revision: Numeric
}
export interface Review {
  review_id: string; request_id: string; request_code: string | null
  customer_name: string | null; rescuer_name: string | null; rating: Numeric; comment: string | null; created_at: string | null
}
export interface MutationResult { success: true; changed?: boolean; message: string }
