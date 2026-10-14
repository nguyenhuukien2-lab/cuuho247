import { useCallback, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { getPaymentDetail, requestPaidPaymentRefund } from '../lib/paymentApi'
import type { PaymentDetail, PaymentPerson } from '../lib/paymentTypes'
import { dateValue, serviceValue, statusValue, textValue } from '../lib/adminFormat'
import { useAdminData } from '../hooks/useAdminData'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { EmptyState } from '../components/ui/EmptyState'
import { KeyValues, ReloadButton } from '../components/ui/AdminData'
import { PaymentState, PaymentStatusBadge } from '../components/payments/PaymentUI'
import { methodLabel, paymentMoney } from '../lib/paymentFormat'

function PersonCard({ title, person }: { title: string; person: PaymentPerson | null | undefined }) {
  return <SectionCard title={title}><KeyValues items={[
    ['Mã', textValue(person?.code)], ['Họ tên', textValue(person?.name)],
    ['Điện thoại', textValue(person?.phone)], ['Email', textValue(person?.email)],
  ]}/></SectionCard>
}

function PaymentInformation({ payment, paymentId }: { payment: PaymentDetail | null; paymentId: string }) {
  return <>
    <section className="payment-amount-banner" aria-label="Tóm tắt thanh toán">
      <div><span>Số tiền dự kiến</span><strong>{paymentMoney(payment?.amount_expected)}</strong></div>
      <div><span>Đã nhận</span><strong>{paymentMoney(payment?.amount_received)}</strong></div>
      <div><span>{methodLabel(payment?.method)}</span><PaymentStatusBadge status={payment?.status}/></div>
    </section>
    <div className="payment-detail-grid">
      <div>
        <SectionCard title="Thông tin định danh thanh toán"><KeyValues items={[
          ['ID', payment?.id ?? paymentId], ['Mã thanh toán', textValue(payment?.payment_code)],
          ['Yêu cầu', textValue(payment?.request_code || payment?.request_id)],
          ['Phương thức', methodLabel(payment?.method)], ['Trạng thái', <PaymentStatusBadge key="payment-status" status={payment?.status}/>],
          ['Số tiền dự kiến', paymentMoney(payment?.amount_expected)], ['Số tiền đã nhận', paymentMoney(payment?.amount_received)],
          ['Ngày tạo', dateValue(payment?.created_at)], ['Thanh toán lúc', dateValue(payment?.paid_at)],
          ['Cập nhật lúc', dateValue(payment?.updated_at)], ['Phiên bản', textValue(payment?.version)],
        ]}/></SectionCard>
        {payment?.method === 'cash' && <SectionCard title="Xác nhận tiền mặt">
          <PaymentStatusBadge status={payment.status}/>
          {payment.status === 'paid' ? <div className="payment-confirmation"><KeyValues items={[
            ['Người xác nhận', textValue(payment.cash_confirmation?.confirmed_by)],
            ['Xác nhận lúc', dateValue(payment.cash_confirmation?.confirmed_at)],
          ]}/>{!payment.cash_confirmation && <p className="muted-note">Chưa có thông tin người xác nhận tiền mặt.</p>}</div> : <p className="muted-note">Chưa có xác nhận đã thu tiền mặt.</p>}
        </SectionCard>}
        {payment?.method === 'bank_transfer' && <SectionCard title="Chi tiết chuyển khoản ngân hàng">
          <KeyValues items={[
            ['Trạng thái thanh toán', <PaymentStatusBadge key="bank-status" status={payment.status}/>],
            ['Trạng thái ngân hàng', textValue(payment.bank?.state)], ['Nhà cung cấp', textValue(payment.bank?.provider)],
            ['Tham chiếu', textValue(payment.bank?.reference)], ['Ngân hàng', textValue(payment.bank?.bank_name)],
            ['Tài khoản thụ hưởng', textValue(payment.bank?.account_masked)], ['Hết hạn lúc', dateValue(payment.bank?.expires_at)],
          ]}/>
          {!payment.bank && <p className="muted-note">Chưa có thông tin xác minh ngân hàng.</p>}
        </SectionCard>}
        <SectionCard title="Đơn cứu hộ liên kết"><KeyValues items={[
          ['Yêu cầu', textValue(payment?.request_code || payment?.request_id)], ['Dịch vụ', serviceValue(payment?.request?.service)],
          ['Phương tiện', textValue(payment?.request?.vehicle)], ['Trạng thái yêu cầu', statusValue(payment?.request?.status)],
          ['Hoàn thành lúc', dateValue(payment?.request?.completed_at)],
        ]}/></SectionCard>
        <div className="payment-people"><PersonCard title="Khách hàng" person={payment?.customer}/><PersonCard title="Đối tác cứu hộ" person={payment?.rescuer}/></div>
      </div>
      <div><SectionCard title="Nhật ký thanh toán" subtitle="Các sự kiện được ghi nhận theo thời gian">
        {payment?.events?.length ? <ol className="payment-timeline">{payment.events.map((event) => <li key={event.id}>
          <strong>{textValue(event.label)}</strong><time dateTime={event.created_at ?? undefined}>{dateValue(event.created_at)}</time>
          <small>{textValue(event.actor_name)}</small><div><PaymentStatusBadge status={event.status}/></div>
        </li>)}</ol> : <EmptyState title="Chưa có nhật ký thanh toán" description="Các sự kiện sẽ hiển thị khi có dữ liệu được cấp quyền tra cứu."/>}
      </SectionCard></div>
    </div>
  </>
}

export function PaymentDetailPage() {
  const { paymentId = '' } = useParams()
  const loader = useCallback((signal?: AbortSignal) => getPaymentDetail(paymentId, signal), [paymentId])
  const resource = useAdminData(loader)
  const payment = resource.error ? null : resource.data
  const [refundAmount, setRefundAmount] = useState('')
  const [refundReason, setRefundReason] = useState('customer_request')
  const [refundBusy, setRefundBusy] = useState(false)
  const [refundError, setRefundError] = useState('')
  const [refundCreated, setRefundCreated] = useState(false)
  const refundOperation = useRef('')
  const requestRefund = async () => {
    if (!payment || payment.status !== 'paid' || !payment.version || !/^[1-9][0-9]{0,18}$/.test(refundAmount)) return
    refundOperation.current ||= crypto.randomUUID()
    setRefundBusy(true); setRefundError('')
    const result = await requestPaidPaymentRefund(payment, refundAmount, refundReason, refundOperation.current)
    setRefundBusy(false)
    if (result.error) { setRefundError('Không thể tạo yêu cầu hoàn tiền. Hãy tải lại payment và kiểm tra số tiền khả dụng.'); return }
    refundOperation.current = ''
    setRefundCreated(true)
  }
  return <div className="payment-page">
    <PageHeader eyebrow="TÀI CHÍNH / THANH TOÁN / CHI TIẾT" title={payment?.payment_code ? `Chi tiết thanh toán · ${payment.payment_code}` : 'Chi tiết thanh toán'} description="Thông tin thanh toán và lịch sử ghi nhận của yêu cầu cứu hộ." actions={<><Link className="button button-white" to="/payments/list">← Danh sách</Link><ReloadButton resource={resource}/></>}/>
    <PaymentState resource={resource}>
      {!resource.error && !payment ? <SectionCard><EmptyState title="Không tìm thấy thanh toán" description="Thanh toán không tồn tại hoặc không thuộc phạm vi được cấp quyền."/></SectionCard> : <PaymentInformation payment={payment} paymentId={paymentId}/>}
      {payment?.status === 'paid' && <SectionCard title="Yêu cầu hoàn tiền" subtitle="Tạo record requested; payment gốc và trạng thái paid không bị thay đổi">
        <div className="payment-refund-request">
          <label className="payment-field"><span>Số tiền hoàn (VND)</span><input aria-label="Số tiền hoàn" inputMode="numeric" value={refundAmount} onChange={(event) => { setRefundAmount(event.target.value); setRefundCreated(false) }}/></label>
          <label className="payment-field"><span>Lý do</span><select aria-label="Lý do hoàn tiền" value={refundReason} onChange={(event) => setRefundReason(event.target.value)}><option value="customer_request">Khách hàng yêu cầu</option><option value="duplicate_payment">Thanh toán trùng</option><option value="service_dispute">Tranh chấp dịch vụ</option><option value="other_approved">Lý do khác đã phê duyệt</option></select></label>
          <button className="button button-blue" disabled={refundBusy || !/^[1-9][0-9]{0,18}$/.test(refundAmount)} onClick={() => void requestRefund()}>Tạo yêu cầu hoàn tiền</button>
        </div>
        {refundError && <p className="payment-filter-error" role="alert">{refundError}</p>}
        {refundCreated && <p className="muted-note" role="status">Đã tạo yêu cầu. <Link className="text-link" to="/payments/operations">Mở vận hành thanh toán để duyệt và xử lý.</Link></p>}
      </SectionCard>}
    </PaymentState>
  </div>
}
