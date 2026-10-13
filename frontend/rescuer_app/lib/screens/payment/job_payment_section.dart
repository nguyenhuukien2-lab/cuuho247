import 'package:flutter/material.dart';

import '../../app/mobile_ui.dart';
import '../../app/rescuer_controller.dart';
import '../../models/backend_models.dart';
import '../../models/payment_dto.dart';
import 'rescuer_cash_screen.dart';
import 'rescuer_payment_widgets.dart';

/// Shared summary. Every action opens a route with its own authoritative getter.
class JobPaymentSection extends StatelessWidget {
  const JobPaymentSection({
    super.key,
    required this.c,
    required this.assignment,
    this.history = false,
  });
  final RescuerController c;
  final JobAssignment assignment;
  final bool history;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: history ? c.historyPayments : c.payments,
    builder: (context, _) {
      final state = c.historyPayments.stateFor(assignment.requestId);
      final scoped = c.payments.requestId == assignment.requestId;
      final PaymentDto? payment = history
          ? state.payment
          : scoped
          ? c.payments.payment
          : null;
      final loading = history ? state.loading : scoped && c.payments.loading;
      final error = history
          ? state.error
          : scoped
          ? c.payments.error
          : null;
      final unavailable =
          error == 'unavailable' || error == 'PAYMENT_NOT_ACCESSIBLE';
      Future<void> refresh() => history
          ? c.historyPayments.refresh([assignment])
          : c.loadJobPayment(assignment.requestId);
      return RescueCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Thanh toán', style: RescueType.section),
            const SizedBox(height: 12),
            if (loading) const LinearProgressIndicator(),
            if (error != null && !unavailable) ...[
              const PaymentNotice(
                title: 'Không thể cập nhật trạng thái',
                message:
                    'Kiểm tra kết nối và thử tải lại trạng thái thanh toán.',
                icon: Icons.cloud_off,
              ),
              RescueButton(
                label: 'Thử lại',
                onPressed: loading ? null : refresh,
              ),
            ] else if (payment != null &&
                payment.assignmentId == assignment.id &&
                !unavailable) ...[
              PaymentDetailRow(
                'Tổng tiền',
                '${cashAmount(payment.amountExpected)} ${payment.currency}',
              ),
              PaymentDetailRow(
                'Phương thức',
                paymentMethodLabel(payment.method),
              ),
              PaymentStatusBadge(payment: payment),
              PaymentDetailRow('Mã thanh toán', payment.paymentCode),
              RescueButton(
                key: ValueKey('open-payment-${assignment.id}'),
                label:
                    payment.method == 'cash' &&
                        payment.status == 'awaiting_payment'
                    ? 'Xác nhận đã nhận đủ tiền'
                    : 'Xem thanh toán',
                kind: RescueButtonKind.secondary,
                onPressed: loading
                    ? null
                    : () => openRescuerPayment(context, c, assignment),
              ),
            ] else if (!loading) ...[
              const Text(
                'Chưa có thông tin thanh toán',
                style: RescueType.body,
              ),
              RescueButton(
                label: 'Làm mới trạng thái',
                kind: RescueButtonKind.quiet,
                onPressed: refresh,
              ),
            ],
          ],
        ),
      );
    },
  );
}
