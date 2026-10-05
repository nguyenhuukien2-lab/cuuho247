import { supabase } from './supabase'
import type { ApiResult, AdminProfile, Customer, DashboardStats, MutationResult, Quote, RescueRequest, Rescuer, Review, Service } from './adminTypes'

export function apiError(error: unknown): string {
  if (error && typeof error === 'object' && 'message' in error && typeof error.message === 'string') return error.message
  return 'Không thể kết nối dữ liệu. Vui lòng thử lại.'
}

async function read<T>(operation: () => PromiseLike<{ data: T | null; error: unknown }>): Promise<ApiResult<T>> {
  try {
    const { data, error } = await operation()
    if (error) return { data: null, error: apiError(error) }
    return { data: data as T, error: null }
  } catch (error) { return { data: null, error: apiError(error) } }
}

// Fetch every server page before client-side filtering; never silently truncate at the API row limit.
async function list<T>(view: string, id: string, signal?: AbortSignal): Promise<ApiResult<T[]>> {
  try {
    const rows: T[] = []
    let offset = 0
    while (true) {
      let query = supabase.from(view).select('*', { count: 'exact' })
        .order(id, { ascending: true }).range(offset, offset + 199)
      if (signal) query = query.abortSignal(signal)
      const { data, error, count } = await query
      if (error) return { data: null, error: apiError(error) }
      const batch = (data ?? []) as T[]
      rows.push(...batch)
      offset += batch.length
      if (count !== null ? offset >= count : batch.length < 200) break
      if (batch.length === 0) return { data: null, error: 'Danh sách thay đổi trong khi tải. Vui lòng tải lại.' }
    }
    return { data: rows, error: null }
  } catch (error) { return { data: null, error: apiError(error) } }
}

function detail<T>(view: string, column: string, id: string, signal?: AbortSignal): Promise<ApiResult<T | null>> {
  return read<T | null>(() => {
    let query = supabase.from(view).select('*').eq(column, id)
    if (signal) query = query.abortSignal(signal)
    return query.maybeSingle()
  })
}

export function getDashboardStats(signal?: AbortSignal): Promise<ApiResult<DashboardStats>> {
  return read<DashboardStats>(() => {
    const query = supabase.rpc('admin_get_dashboard_stats')
    return signal ? query.abortSignal(signal) : query
  })
}
export const getAdminProfile = (id: string) => detail<AdminProfile>('admin_profiles', 'id', id)
export const getCustomers = (signal?: AbortSignal) => list<Customer>('admin_customers_view', 'customer_id', signal)
export const getRescuers = (signal?: AbortSignal) => list<Rescuer>('admin_rescuers_view', 'rescuer_id', signal)
export const getRescueRequests = (signal?: AbortSignal) => list<RescueRequest>('admin_rescue_requests_view', 'request_id', signal)
export const getServices = (signal?: AbortSignal) => list<Service>('admin_services_view', 'service_id', signal)
export const getQuotes = (signal?: AbortSignal) => list<Quote>('admin_quotes_view', 'quote_id', signal)
export const getReviews = (signal?: AbortSignal) => list<Review>('admin_reviews_view', 'review_id', signal)
export const getCustomer = (id: string, signal?: AbortSignal) => detail<Customer>('admin_customers_view', 'customer_id', id, signal)
export const getRescuer = (id: string, signal?: AbortSignal) => detail<Rescuer>('admin_rescuers_view', 'rescuer_id', id, signal)
export const getRescueRequest = (id: string, signal?: AbortSignal) => detail<RescueRequest>('admin_rescue_requests_view', 'request_id', id, signal)

async function mutate(rpc: string, params: Record<string, string | boolean>): Promise<ApiResult<MutationResult>> {
  const result = await read<MutationResult>(() => supabase.rpc(rpc, params))
  if (result.error) return result
  if (result.data?.success !== true) {
    return { data: null, error: result.data?.message || 'Máy chủ chưa xác nhận thao tác thành công.' }
  }
  return result
}
export const approveRescuer = (rescuerId: string) => mutate('admin_approve_rescuer', { rescuer_id: rescuerId })
export const rejectRescuer = (rescuerId: string, reason: string) => mutate('admin_reject_rescuer', { rescuer_id: rescuerId, reason: reason.trim() })
export const blockRescuer = (rescuerId: string, reason: string) => mutate('admin_block_rescuer', { rescuer_id: rescuerId, reason: reason.trim() })
export const cancelRequest = (requestId: string, reason: string) => mutate('admin_cancel_request', { request_id: requestId, reason: reason.trim() })
export const toggleService = (serviceId: string, isActive: boolean) => mutate('admin_toggle_service', { service_id: serviceId, is_active: isActive })
