import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/cash_payment_controller.dart';
import '../../app/mobile_ui.dart';
import '../../app/rescuer_controller.dart';
import '../../core/utils/display_code.dart';
import '../../models/backend_models.dart';
import '../../models/payment_dto.dart';
import '../preparation/ui_v2_components.dart';
import 'rescuer_payment_widgets.dart';
export 'rescuer_payment_widgets.dart' show CashSummary, cashAmount, cashTime;

Future<void> openRescuerPayment(
  BuildContext context,
  RescuerController rescuer,
  JobAssignment assignment,
) async {
  final owner = rescuer.userId;
  final controller = CashPaymentController(
    source: rescuer.payments.source,
    requestId: assignment.requestId,
    assignmentId: assignment.id,
    completed: assignment.state == 'completed',
    canCollect: () =>
        rescuer.signedIn &&
        rescuer.userId == owner &&
        rescuer.snapshot.approved,
  );
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => RescuerCashScreen(
        controller: controller,
        rescuer: rescuer,
        requestCode: assignment.requestCode,
        onTripDetails: () {
          Navigator.of(context).pop();
          if (rescuer.userId != owner) return;
          rescuer.selectTab(3, refresh: false);
          unawaited(rescuer.loadHistoryDetail(assignment.id));
        },
      ),
    ),
  );
  if (rescuer.userId == owner) {
    await rescuer.historyPayments.refresh([assignment]);
    await rescuer.refreshJobPayment();
  }
}

/// Existing route name retained for callers; bank and pending are read-only.
class RescuerCashScreen extends StatefulWidget {
  const RescuerCashScreen({
    super.key,
    required this.controller,
    this.requestCode,
    this.onTripDetails,
    this.rescuer,
  });
  final CashPaymentController controller;
  final String? requestCode;
  final VoidCallback? onTripDetails;
  final RescuerController? rescuer;
  @override
  State<RescuerCashScreen> createState() => _RescuerCashScreenState();
}

class _RescuerCashScreenState extends State<RescuerCashScreen>
    with WidgetsBindingObserver {
  CashPaymentController get c => widget.controller;
  bool _dialogOpen = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(c.loadJobPayment());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      c.watcher.setForeground(state == AppLifecycleState.resumed);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_dialogOpen || !c.canConfirm) return;
    _dialogOpen = true;
    final reviewed = c.payment!;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RescuerCashConfirmDialog(
        controller: c,
        reviewed: reviewed,
        requestCode: widget.requestCode,
      ),
    );
    _dialogOpen = false;
    if (!mounted || accepted != true) return;
    await c.confirmCashReceived(reviewed);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final rescuer = widget.rescuer;
      return PopScope(
        canPop: !c.submitting,
        child: Scaffold(
          backgroundColor: RescueColors.background,
          appBar: PartnerHeader(
            page: 'Thanh toán',
            online: rescuer?.online ?? false,
            onBack: c.submitting ? null : () => Navigator.maybePop(context),
            onRefresh: c.submitting || c.watcher.loading
                ? null
                : c.refreshJobPayment,
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView(
                  key: ValueKey((
                    c.submitting,
                    c.payment?.status,
                    c.paymentError,
                    c.watcher.stale,
                  )),
                  padding: const EdgeInsets.all(16),
                  children: _body(c.payment),
                ),
              ),
            ),
          ),
          bottomNavigationBar: rescuer == null
              ? null
              : PartnerNavigationBar(
                  selectedIndex: rescuer.tab,
                  onSelected: c.submitting
                      ? null
                      : (index) {
                          Navigator.of(context).pop();
                          rescuer.selectTab(index);
                        },
                ),
        ),
      );
    },
  );

  List<Widget> _body(PaymentDto? p) {
    final w = c.watcher;
    if (!c.submitting && w.loading && (p == null || p.status == 'paid')) {
      return [
        const RescueFeedback(
          kind: RescueFeedbackKind.loading,
          title: 'Đang tải thanh toán',
          message: 'Đang kiểm tra số tiền và trạng thái giao dịch.',
        ),
      ];
    }
    if (w.error == 'PAYMENT_NOT_ACCESSIBLE' ||
        p == null && w.error == null ||
        p != null && p.assignmentId != c.assignmentId) {
      return [_error(CashIssue.unavailable)];
    }
    if (p == null) return [_error(CashIssue.failed)];
    if (c.submitting) {
      return _spaced([
        const PaymentStateHero(
          key: ValueKey('cash-confirming'),
          title: 'Đang xác nhận thanh toán…',
          message: 'Hệ thống đang ghi nhận kết quả thu tiền mặt. Vui lòng chờ cập nhật trạng thái.',
          icon: Icons.payments_outlined,
          busy: true,
        ),
        PaymentAmountCard(payment: p),
        CashSummary(payment: p, requestCode: widget.requestCode),
        const RescueButton(
          key: ValueKey('cash-processing'),
          label: 'Đang xử lý…',
          loading: true,
          onPressed: null,
        ),
      ]);
    }
    final issue =
        c.issue ??
        (w.error != null
            ? CashIssue.failed
            : w.stale
            ? CashIssue.offline
            : null);
    if (issue != null) return [_error(issue)];
    final bank = p.method == 'bank_transfer',
        cash = p.method == 'cash',
        paid = p.status == 'paid';
    return _spaced([
      if (paid && (cash || bank))
        PaymentStateHero(
          key: ValueKey(bank ? 'bank-paid' : 'cash-paid'),
          title: bank ? 'Khách đã thanh toán' : 'Đã nhận tiền mặt',
          success: true,
          message: bank
              ? 'Thanh toán chuyển khoản đã được hệ thống xác nhận.'
              : 'Đã xác nhận nhận đủ tiền mặt từ khách hàng.',
          icon: bank ? Icons.verified_outlined : Icons.check_circle_rounded,
        )
      else if (bank && p.status == 'verifying')
        const PaymentStateHero(
          key: ValueKey('bank-verifying'),
          title: 'Đang xác minh giao dịch',
          message:
              'Hệ thống đang kiểm tra giao dịch chuyển khoản của khách hàng.',
          icon: Icons.sync,
          busy: true,
        )
      else if (bank && p.status == 'awaiting_payment')
        const PaymentNotice(
          key: ValueKey('bank-waiting'),
          title: 'Trạng thái giao dịch',
          message: 'Đang chờ hệ thống xác minh',
          icon: Icons.sync,
        )
      else
        Row(
          children: [
            Icon(
              cash ? Icons.payments_outlined : Icons.receipt_long_outlined,
              color: RescueColors.navy,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                cash ? 'Thu tiền mặt' : 'Thanh toán dịch vụ',
                style: RescueType.section,
              ),
            ),
          ],
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: PaymentStatusBadge(payment: p),
      ),
      PaymentAmountCard(payment: p, dark: p.method == null),
      if (p.method == null)
        const PaymentNotice(
          key: ValueKey('payment-method'),
          title: 'Phương thức khách đã chọn',
          message: 'Chờ khách hàng chọn phương thức trên ứng dụng. Bạn chỉ xem thông tin thanh toán.',
          icon: Icons.lock_outline,
        ),
      CashSummary(payment: p, requestCode: widget.requestCode),
      if (paid && (cash || bank)) ...[
        const PaymentNotice(
          title: 'Đối soát hoàn tất',
          message: 'Trạng thái thanh toán đã được ghi nhận bởi hệ thống.',
          icon: Icons.verified_user_outlined,
        ),
        RescueButton(
          label: 'Xem chi tiết chuyến',
          icon: Icons.receipt_long_outlined,
          kind: RescueButtonKind.secondary,
          onPressed: widget.onTripDetails ?? () => Navigator.maybePop(context),
        ),
      ] else if (cash && p.status == 'awaiting_payment') ...[
        const PaymentNotice(
          title: 'Xác thực thu ngân thực địa',
          warning: true,
          message:
              'Chỉ xác nhận sau khi bạn đã nhận đủ tiền mặt từ khách hàng.',
          icon: Icons.health_and_safety_outlined,
        ),
        RescueButton(
          key: const ValueKey('collect-cash'),
          label: 'Xác nhận đã nhận đủ tiền',
          icon: Icons.check_circle_outline,
          loading: w.loading,
          onPressed: c.canConfirm ? _confirm : null,
        ),
        if (!c.canCollect())
          const Text(
            'Tài khoản hiện chưa thể xác nhận thu tiền.',
            style: RescueType.caption,
          ),
      ] else if (bank && ['awaiting_payment', 'verifying'].contains(p.status))
        const PaymentNotice(
          title: 'Hướng dẫn đối soát',
          warning: true,
          message: 'Trạng thái chuyển khoản do hệ thống xác minh. Bạn không cần thu thêm tiền mặt.',
          icon: Icons.shield_outlined,
        ),
      if (!paid)
        RescueButton(
          key: const ValueKey('refresh-payment'),
          label: 'Làm mới trạng thái',
          icon: Icons.refresh,
          kind: RescueButtonKind.outline,
          loading: w.loading,
          onPressed: c.refreshJobPayment,
        ),
      RescueButton(
        label: 'Quay lại đơn',
        icon: Icons.arrow_back,
        kind: RescueButtonKind.quiet,
        onPressed: () => Navigator.maybePop(context),
      ),
    ]);
  }

  List<Widget> _spaced(List<Widget> children) => [
    for (final child in children)
      Padding(padding: const EdgeInsets.only(bottom: 16), child: child),
  ];

  Widget _error(CashIssue issue) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PaymentStateHero(
        title: issue == CashIssue.unavailable
            ? 'Chưa có thông tin thanh toán'
            : 'Không thể cập nhật trạng thái',
        message: switch (issue) {
          CashIssue.unavailable => 'Thanh toán chưa sẵn sàng hoặc bạn không có quyền xem. Hãy tải lại trạng thái.',
          CashIssue.conflict =>
            'Thông tin thanh toán đã thay đổi. Tải lại trước khi xác nhận.',
          CashIssue.settled =>
            'Giao dịch đã được xử lý. Tải lại để xem kết quả.',
          CashIssue.timeout => 'Chưa xác định được kết quả xác nhận. Thử lại để đọc trạng thái mới nhất.',
          _ => 'Vui lòng kiểm tra kết nối mạng và thử lại. Trạng thái thanh toán cần được kiểm tra từ hệ thống.',
        },
        icon: issue == CashIssue.unavailable
            ? Icons.receipt_long_outlined
            : Icons.cloud_off,
      ),
      const SizedBox(height: 16),
      RescueButton(
        label: 'Thử lại',
        icon: Icons.refresh,
        loading: c.watcher.loading,
        onPressed: c.refreshJobPayment,
      ),
    ],
  );
}

class RescuerCashConfirmDialog extends StatefulWidget {
  const RescuerCashConfirmDialog({
    super.key,
    required this.controller,
    required this.reviewed,
    this.requestCode,
  });
  final CashPaymentController controller;
  final PaymentDto reviewed;
  final String? requestCode;
  @override
  State<RescuerCashConfirmDialog> createState() =>
      _RescuerCashConfirmDialogState();
}

class _RescuerCashConfirmDialogState extends State<RescuerCashConfirmDialog> {
  CashPaymentController get controller => widget.controller;
  PaymentDto get reviewed => widget.reviewed;
  String? get requestCode => widget.requestCode;
  bool _answered = false;

  void _answer(bool accepted) {
    if (_answered) return;
    _answered = true;
    Navigator.pop(context, accepted);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final valid =
          controller.canConfirm &&
          controller.payment?.paymentId == reviewed.paymentId &&
          controller.payment?.version == reviewed.version;
      final accessible =
          controller.watcher.requestId == controller.requestId &&
          controller.payment != null;
      return PopScope(
        canPop: !controller.submitting,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    size: 40,
                    color: RescueColors.accentPressed,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Xác nhận đã nhận tiền?',
                    textAlign: TextAlign.center,
                    style: RescueType.section,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Bạn xác nhận đã nhận đủ tiền mặt trực tiếp từ khách hàng?',
                    textAlign: TextAlign.center,
                    style: RescueType.body,
                  ),
                  const SizedBox(height: 16),
                  if (accessible) ...[
                    PaymentDetailRow('Mã đơn', displayCode(requestCode)),
                    PaymentDetailRow(
                      'Tổng tiền',
                      '${cashAmount(reviewed.amountExpected)} ${reviewed.currency}',
                    ),
                    const PaymentDetailRow('Phương thức', 'Tiền mặt'),
                  ],
                  const SizedBox(height: 12),
                  const PaymentNotice(
                    title: 'Xác nhận nhận đủ tiền',
                    warning: true,
                    message: 'Sau khi xác nhận, hệ thống sẽ ghi nhận thanh toán tiền mặt của đơn.',
                  ),
                  if (!valid) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Thông tin đã thay đổi hoặc kết nối bị gián đoạn. Quay lại để kiểm tra.',
                      style: RescueType.body,
                    ),
                  ],
                  const SizedBox(height: 20),
                  RescueButton(
                    key: const ValueKey('confirm-cash'),
                    label: 'Đã nhận đủ tiền',
                    icon: Icons.check_circle_outline,
                    onPressed: valid ? () => _answer(true) : null,
                  ),
                  const SizedBox(height: 8),
                  RescueButton(
                    label: 'Chưa nhận',
                    kind: RescueButtonKind.secondary,
                    onPressed: controller.submitting
                        ? null
                        : () => _answer(false),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
