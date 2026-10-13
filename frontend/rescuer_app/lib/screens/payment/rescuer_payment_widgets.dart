import 'package:flutter/material.dart';

import '../../app/mobile_ui.dart';
import '../../core/utils/display_code.dart';
import '../../models/payment_dto.dart';
import '../../widgets/app_components.dart';

String cashAmount(BigInt amount) => amount.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]}.',
);

String cashTime(DateTime? value) {
  if (value == null) return 'Chưa có thời gian xác nhận';
  final t = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)} · ${two(t.day)}/${two(t.month)}/${t.year}';
}

String paymentMethodLabel(String? method) => switch (method) {
  'cash' => 'Tiền mặt',
  'bank_transfer' => 'Chuyển khoản',
  null => 'Chờ khách chọn phương thức',
  _ => 'Phương thức chưa được hỗ trợ',
};

String paymentStatusLabel(PaymentDto p) => switch (p.status) {
  'paid' => 'Đã thanh toán',
  'awaiting_payment' => p.method == 'cash' ? 'Chờ thu tiền' : 'Chờ xác minh',
  'verifying' => 'Đang xác minh',
  'pending' => 'Chờ chọn phương thức',
  'failed' => 'Thanh toán không thành công',
  'cancelled' => 'Đã hủy thanh toán',
  'refunded' => 'Đã hoàn tiền',
  _ => 'Chưa xác định',
};

class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge({super.key, required this.payment});
  final PaymentDto payment;
  @override
  Widget build(BuildContext context) => StatusBadge(
    label: paymentStatusLabel(payment),
    tone: switch (payment.status) {
      'paid' => BadgeTone.green,
      'failed' || 'cancelled' => BadgeTone.red,
      'refunded' => BadgeTone.neutral,
      _ => BadgeTone.amber,
    },
    icon: payment.status == 'paid'
        ? Icons.check_circle_outline
        : Icons.schedule,
  );
}

class PaymentDetailRow extends StatelessWidget {
  const PaymentDetailRow(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: RescueType.caption),
              const SizedBox(height: 4),
              SelectableText(value, style: RescueType.code),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: RescueType.caption)),
            const SizedBox(width: 12),
            Expanded(
              child: SelectableText(
                value,
                textAlign: TextAlign.end,
                style: RescueType.code,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class PaymentAmountCard extends StatelessWidget {
  const PaymentAmountCard({
    super.key,
    required this.payment,
    this.dark = false,
  });
  final PaymentDto payment;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final paid = payment.status == 'paid';
    final amount = paid ? payment.amountReceived : payment.amountExpected;
    final foreground = dark ? Colors.white : RescueColors.navy;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: dark ? RescueColors.navy : RescueColors.surface,
        borderRadius: BorderRadius.circular(RescueRadius.card),
        border: Border.all(color: RescueColors.border),
      ),
      child: Column(
        children: [
          Text(
            paid ? 'SỐ TIỀN ĐÃ NHẬN' : 'TỔNG TIỀN CẦN THANH TOÁN',
            textAlign: TextAlign.center,
            style: RescueType.caption.copyWith(color: foreground),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(
                amount == null ? 'Chưa có số tiền' : cashAmount(amount),
                style: RescueType.page.copyWith(
                  fontSize: 32,
                  color: foreground,
                ),
              ),
              if (amount != null)
                Text(
                  payment.currency == 'VND' ? 'đ' : payment.currency,
                  style: RescueType.title.copyWith(
                    color: dark ? Colors.white : RescueColors.accentPressed,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            paid
                ? paymentMethodLabel(payment.method)
                : 'Số tiền cố định theo báo giá hệ thống',
            textAlign: TextAlign.center,
            style: RescueType.caption.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// Safe receipt only; no trace ID, beneficiary, bank reference or private data.
class CashSummary extends StatelessWidget {
  const CashSummary({super.key, required this.payment, this.requestCode});
  final PaymentDto payment;
  final String? requestCode;
  @override
  Widget build(BuildContext context) => RescueCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 20,
              color: RescueColors.navy,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                payment.status == 'paid'
                    ? 'Biên lai đối soát'
                    : 'Chi tiết thanh toán',
                style: RescueType.title,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PaymentDetailRow('Mã thanh toán', payment.paymentCode),
        PaymentDetailRow('Mã đơn cứu hộ', displayCode(requestCode)),
        PaymentDetailRow('Phương thức', paymentMethodLabel(payment.method)),
        PaymentDetailRow('Trạng thái', paymentStatusLabel(payment)),
        if (payment.status == 'paid')
          PaymentDetailRow('Thời gian xác nhận', cashTime(payment.paidAt)),
      ],
    ),
  );
}

class PaymentNotice extends StatelessWidget {
  const PaymentNotice({
    super.key,
    required this.title,
    required this.message,
    this.warning = false,
    this.icon = Icons.info_outline,
  });
  final String title, message;
  final bool warning;
  final IconData icon;
  @override
  Widget build(BuildContext context) => InfoBanner(
    title: title,
    message: message,
    icon: icon,
    tone: warning ? BadgeTone.orange : BadgeTone.blue,
  );
}

class PaymentStateHero extends StatelessWidget {
  const PaymentStateHero({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.success = false,
    this.busy = false,
  });
  final String title, message;
  final IconData icon;
  final bool success, busy;
  @override
  Widget build(BuildContext context) => RescueCard(
    child: Semantics(
      liveRegion: true,
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox.square(
            dimension: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: success
                        ? RescueColors.successSoft
                        : RescueColors.accentSoft,
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: success
                        ? RescueColors.successText
                        : RescueColors.navy,
                  ),
                ),
                if (busy)
                  SizedBox.square(
                    dimension: 94,
                    child: CircularProgressIndicator(
                      value: MediaQuery.disableAnimationsOf(context)
                          ? .7
                          : null,
                      strokeWidth: 3,
                      color: RescueColors.accent,
                      semanticsLabel: title,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: RescueType.section),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: RescueType.body),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
