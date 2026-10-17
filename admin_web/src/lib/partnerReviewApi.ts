import { supabase } from './supabase'
import type { ApiResult, MutationResult } from './adminTypes'

export interface PartnerReadiness {
  checked_at: string; profile_approved: boolean; identity_approved: boolean; license_approved: boolean
  can_online: boolean; can_receive_requests: boolean; eligible_vehicle_ids: string[]
  vehicles: { vehicle_id: string; vehicle_approved: boolean; registration_approved: boolean; service_approved: boolean; ready: boolean }[]
}
export interface PartnerDocument {
  document_id: string; document_type: string; vehicle_id: string | null; storage_path: string
  content_type: string; uploaded_at: string | null; created_at: string; expires_at: string | null
  verification_status: string; review_reason: string | null
}
export interface PartnerVehicle {
  id: string; kind: string; display_name: string; license_plate: string; verification_status: string
  is_active: boolean; version: number
}
export interface PartnerCapability {
  vehicle_id: string; service_code: string; service_name: string; customer_vehicle_kind: string
  verification_status: string; is_enabled: boolean; service_active: boolean; updated_at: string
}
export interface PartnerReview { documents: PartnerDocument[]; vehicles: PartnerVehicle[]; capabilities: PartnerCapability[]; readiness: PartnerReadiness }

function reviewError(error: unknown): string {
  const message = error && typeof error === 'object' && 'message' in error ? String(error.message) : ''
  if (/ADMIN_FORBIDDEN|42501/.test(message)) return 'Chỉ Admin có quyền kiểm duyệt đối tác mới được thực hiện thao tác này.'
  if (/SYSTEM_SESSION_DENIED/.test(message)) return 'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.'
  if (/CONFLICT/.test(message)) return 'Dữ liệu đã thay đổi. Đóng hộp thoại, tải lại và kiểm tra trước khi duyệt.'
  if (/BUSY/.test(message)) return 'Đối tác đang thực hiện đơn. Hãy kiểm duyệt sau khi đơn kết thúc.'
  if (/NOT_READY/.test(message)) return 'Chưa đủ điều kiện: kiểm tra upload, hạn giấy tờ và trạng thái xe/dịch vụ.'
  if (/REASON_REQUIRED/.test(message)) return 'Vui lòng nhập lý do từ chối.'
  if (/PGRST202|Could not find the function/.test(message)) return 'Backend chưa có API kiểm duyệt đầy đủ. Cần áp dụng migration đã kiểm thử trước khi sử dụng.'
  return 'Không thể tải hoặc cập nhật kiểm duyệt. Vui lòng thử lại.'
}

export async function getPartnerReview(id: string, signal?: AbortSignal): Promise<ApiResult<PartnerReview>> {
  try {
    const query = supabase.rpc('admin_get_rescuer_review', { p_rescuer_id: id })
    const { data, error } = await (signal ? query.abortSignal(signal) : query)
    if (error) return { data: null, error: reviewError(error) }
    if (!data || !Array.isArray(data.documents) || !Array.isArray(data.vehicles) || !Array.isArray(data.capabilities)
      || !Array.isArray(data.readiness?.vehicles) || !Array.isArray(data.readiness?.eligible_vehicle_ids)
      || typeof data.readiness.can_online !== 'boolean' || typeof data.readiness.can_receive_requests !== 'boolean') {
      return { data: null, error: 'Backend trả về dữ liệu kiểm duyệt không hợp lệ.' }
    }
    return { data, error: null }
  } catch (error) { return { data: null, error: reviewError(error) } }
}

async function review(rpc: string, params: Record<string, unknown>): Promise<ApiResult<MutationResult>> {
  try {
    const { data, error } = await supabase.rpc(rpc, params)
    if (error) return { data: null, error: reviewError(error) }
    return data?.success === true ? { data, error: null } : { data: null, error: 'Máy chủ chưa xác nhận kiểm duyệt thành công.' }
  } catch (error) { return { data: null, error: reviewError(error) } }
}
export const reviewDocument = (d: PartnerDocument, status: string, reason: string) => review('admin_review_rescuer_document', {
  p_document_id: d.document_id, p_status: status, p_expected_status: d.verification_status, p_reason: reason || null,
})
export const reviewVehicle = (v: PartnerVehicle, status: string, reason: string) => review('admin_review_rescuer_vehicle', {
  p_vehicle_id: v.id, p_status: status, p_expected_version: v.version, p_reason: reason || null,
})
export const reviewCapability = (c: PartnerCapability, status: string, reason: string) => review('admin_review_rescuer_capability', {
  p_vehicle_id: c.vehicle_id, p_service_code: c.service_code, p_customer_vehicle_kind: c.customer_vehicle_kind,
  p_status: status, p_expected_updated_at: c.updated_at, p_reason: reason || null,
})

export const documentLinkSeconds = 60
// No URL/token in logs, persistent storage, error strings or audit metadata.
export async function signPartnerDocument(path: string): Promise<ApiResult<string>> {
  try {
    const { data, error } = await supabase.storage.from('rescuer-documents').createSignedUrl(path, documentLinkSeconds)
    if (error || !data?.signedUrl) return { data: null, error: 'Không thể mở tài liệu. Kiểm tra quyền kiểm duyệt và thử lại.' }
    return { data: data.signedUrl, error: null }
  } catch { return { data: null, error: 'Không thể mở tài liệu. Vui lòng thử lại.' } }
}
