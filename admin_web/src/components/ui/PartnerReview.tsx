import { useEffect, useRef, useState } from 'react'
import type { AdminAction } from '../../hooks/useAdminAction'
import type { ApiResult, MutationResult } from '../../lib/adminTypes'
import { dateValue, statusValue } from '../../lib/adminFormat'
import { documentLinkSeconds, reviewCapability, reviewDocument, reviewVehicle, signPartnerDocument } from '../../lib/partnerReviewApi'
import type { PartnerDocument, PartnerReview } from '../../lib/partnerReviewApi'
import { DataTable, KeyValues } from './AdminData'
import { SectionCard } from './SectionCard'

const documentNames: Record<string, string> = { identity: 'Căn cước / Giấy tờ tùy thân', license: 'Giấy phép lái xe', vehicle_registration: 'Đăng ký xe' }
const vehicleNames: Record<string, string> = { service_motorbike: 'Xe máy cứu hộ', service_car: 'Ô tô cứu hộ', tow_truck: 'Xe kéo', recovery_truck: 'Xe cứu hộ', motorbike: 'Xe máy', car: 'Ô tô', truck: 'Xe tải', other: 'Khác' }
const yes = (value: boolean) => value ? 'Đủ điều kiện' : 'Chưa đủ điều kiện'

function ReviewButtons({ label, status, approveDisabled = false, rejectDisabled = false, open, run }: {
  label: string; status: string; approveDisabled?: boolean; rejectDisabled?: boolean
  open: (action: AdminAction) => void; run: (status: string, reason: string) => Promise<ApiResult<MutationResult>>
}) {
  return <div className="row-actions">
    <button className="small-button" disabled={approveDisabled || status === 'approved'} onClick={() => open({ title: 'Duyệt ' + label, description: 'Xác nhận đã kiểm tra ' + label + '.', run: (reason) => run('approved', reason) })}>Duyệt</button>
    <button className="small-button danger" disabled={rejectDisabled || status === 'rejected'} onClick={() => open({ title: 'Từ chối ' + label, description: label, reason: true, run: (reason) => run('rejected', reason) })}>Từ chối</button>
  </div>
}

function DocumentPreview({ doc, close }: { doc: PartnerDocument; close: () => void }) {
  const dialog = useRef<HTMLDialogElement>(null)
  const [url, setUrl] = useState<string | null>(null)
  const [message, setMessage] = useState('Đang tạo liên kết tài liệu...')
  const [attempt, setAttempt] = useState(0)
  useEffect(() => { const element = dialog.current; element?.showModal(); return () => element?.close() }, [])
  useEffect(() => {
    let active = true
    let timer: ReturnType<typeof setTimeout> | undefined
    const started = Date.now()
    void signPartnerDocument(doc.storage_path).then((result) => {
      if (!active) return
      const remaining = documentLinkSeconds * 1000 - (Date.now() - started)
      if (result.error || !result.data) { setMessage(result.error || 'Không thể mở tài liệu.'); return }
      if (remaining <= 0) { setMessage('Liên kết đã hết hạn. Bấm tạo lại để xem.'); return }
      setUrl(result.data); setMessage('Liên kết có hiệu lực tối đa 60 giây. Không chia sẻ liên kết tài liệu.')
      timer = setTimeout(() => { setUrl(null); setMessage('Liên kết đã hết hạn. Bấm tạo lại để xem.') }, remaining)
    })
    return () => { active = false; clearTimeout(timer) }
  }, [doc.storage_path, attempt])
  return <dialog ref={dialog} className="admin-dialog" aria-label="Xem tài liệu" onCancel={(event) => { event.preventDefault(); close() }}>
    <h2>{documentNames[doc.document_type] || doc.document_type}</h2><p role="status">{message}</p>
    {url && <a className="button button-blue" href={url} target="_blank" rel="noopener noreferrer" referrerPolicy="no-referrer">Mở tài liệu trong tab mới</a>}
    <div className="button-pair"><button className="button button-white" onClick={close}>Đóng</button>{!url && <button className="button button-white" onClick={() => { setMessage('Đang tạo liên kết tài liệu...'); setAttempt(attempt + 1) }}>Tạo lại liên kết</button>}</div>
  </dialog>
}

export function PartnerReviewSections({ review, open }: { review: PartnerReview; open: (action: AdminAction) => void }) {
  const [preview, setPreview] = useState<PartnerDocument | null>(null)
  const plate = (id: string | null) => review.vehicles.find((v) => v.id === id)?.license_plate || '—'
  const ready = review.readiness
  return <>
    <SectionCard title="Điều kiện hoạt động"><KeyValues items={[
      ['Hồ sơ', yes(ready.profile_approved)], ['Căn cước đã duyệt, còn hạn', yes(ready.identity_approved)],
      ['Bằng lái đã duyệt, còn hạn', yes(ready.license_approved)], ['Được phép Online', yes(ready.can_online)],
      ['Kiểm tra tại máy chủ', dateValue(ready.checked_at)],
    ]}/><p>Nhận đơn còn cần phiên đăng nhập hợp lệ, vị trí mới, không bận đơn, dịch vụ phù hợp và hệ thống cho phép nhận đơn.</p></SectionCard>
    <SectionCard title="Giấy tờ"><DataTable rows={review.documents} rowKey={(d) => d.document_id} emptyTitle="Đối tác chưa tải giấy tờ" columns={[
      { label: 'Loại giấy tờ', render: (d) => <>{documentNames[d.document_type] || d.document_type}{d.vehicle_id && <div>Xe {plate(d.vehicle_id)}</div>}</> },
      { label: 'Tải lên / Hết hạn', render: (d) => <>{d.uploaded_at ? dateValue(d.uploaded_at) : 'Chưa hoàn tất upload'}<div>{d.expires_at ? dateValue(d.expires_at) : 'Không ghi hạn'}</div></> },
      { label: 'Trạng thái', render: (d) => <>{d.verification_status === 'expired' ? 'Hết hạn' : statusValue(d.verification_status)}{d.expires_at && Date.parse(d.expires_at) <= Date.now() && <div>Đã quá hạn sử dụng</div>}{d.review_reason && <div>Lý do: {d.review_reason}</div>}</> },
      { label: 'Thao tác', render: (d) => <><button className="small-button" disabled={!d.uploaded_at} onClick={() => setPreview(d)}>Xem tài liệu</button><ReviewButtons label={documentNames[d.document_type] || d.document_type} status={d.verification_status} open={open} approveDisabled={!d.uploaded_at || d.verification_status === 'expired' || (!!d.expires_at && Date.parse(d.expires_at) <= Date.now())} rejectDisabled={!d.uploaded_at} run={(s, r) => reviewDocument(d, s, r)}/></> },
    ]}/></SectionCard>
    <SectionCard title="Phương tiện"><DataTable rows={review.vehicles} rowKey={(v) => v.id} emptyTitle="Đối tác chưa đăng ký phương tiện" columns={[
      { label: 'Phương tiện', render: (v) => <>{v.display_name}<div>{vehicleNames[v.kind] || v.kind}</div><strong>{v.license_plate}</strong></> },
      { label: 'Kiểm duyệt', render: (v) => <>{statusValue(v.verification_status)}<div>{v.is_active ? 'Đang sử dụng' : 'Ngừng sử dụng'}</div></> },
      { label: 'Điều kiện', render: (v) => { const r = ready.vehicles.find((r) => r.vehicle_id === v.id); return r ? <>Đăng ký xe: {yes(r.registration_approved)}<div>Dịch vụ: {yes(r.service_approved)}</div><div>Online: {yes(r.ready)}</div></> : 'Chưa có kết quả kiểm tra' } },
      { label: 'Thao tác', render: (v) => <ReviewButtons label={'xe ' + v.license_plate} status={v.verification_status} open={open} approveDisabled={!v.is_active || !['submitted', 'rejected'].includes(v.verification_status)} run={(s, r) => reviewVehicle(v, s, r)}/> },
    ]}/></SectionCard>
    <SectionCard title="Dịch vụ đã đăng ký"><DataTable rows={review.capabilities} rowKey={(c) => [c.vehicle_id, c.service_code, c.customer_vehicle_kind].join(':')} emptyTitle="Đối tác chưa đăng ký dịch vụ" columns={[
      { label: 'Dịch vụ / Xe', render: (c) => <>{c.service_name}<div>{plate(c.vehicle_id)} · Hỗ trợ {vehicleNames[c.customer_vehicle_kind] || c.customer_vehicle_kind}</div></> },
      { label: 'Trạng thái', render: (c) => <>{statusValue(c.verification_status)}<div>{!c.is_enabled ? 'Đối tác đã tắt' : !c.service_active ? 'Dịch vụ hệ thống đang tắt' : 'Đã đăng ký'}</div></> },
      { label: 'Thao tác', render: (c) => <ReviewButtons label={'dịch vụ ' + c.service_name} status={c.verification_status} open={open} approveDisabled={!c.is_enabled || !c.service_active || !['submitted', 'rejected'].includes(c.verification_status)} run={(s, r) => reviewCapability(c, s, r)}/> },
    ]}/></SectionCard>
    {preview && <DocumentPreview key={preview.document_id} doc={preview} close={() => setPreview(null)}/>}
  </>
}
