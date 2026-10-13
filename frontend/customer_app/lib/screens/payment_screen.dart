import 'dart:async';
import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../services/payment_service.dart';
import '../services/request_details_service.dart';
import '../widgets/payment_ui.dart';
import '../widgets/bank_payment_ui.dart';
import 'history_details_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen(
      {super.key,
      required this.requestId,
      required this.controller,
      this.repository});
  final String requestId;
  final AppController controller;
  final RequestDetailsRepository? repository;
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  Object? _route;
  String? _owner;
  RequestDetails? _details;
  bool _ready = false, _detailsLoading = false, _detailsFailed = false;
  int _generation = 0;
  bool get _owns =>
      widget.controller.ownsPaymentRoute(_route, widget.requestId, _owner);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_changed);
    _bind();
  }

  void _bind() {
    final generation = ++_generation;
    _ready = false;
    _details = null;
    _owner = widget.controller.payments.source?.userId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || generation != _generation) return;
      _route = widget.controller.bindPaymentRequest(widget.requestId);
      if (_owns && isPaymentRequestId(widget.requestId)) {
        unawaited(_loadDetails());
        await widget.controller.watchPayment(widget.requestId);
      }
      if (mounted && generation == _generation) setState(() => _ready = true);
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDetails() async {
    final generation = _generation;
    setState(() {
      _detailsLoading = true;
      _detailsFailed = false;
    });
    try {
      final details = await (widget.repository ??
              SupabaseRequestDetailsRepository(
                  client: widget.controller.client))
          .load(widget.requestId);
      if (!mounted || generation != _generation || !_owns) return;
      final row = details?.request;
      setState(() => _details =
          row?['id'] == widget.requestId && row?['customer_id'] == _owner
              ? details
              : null);
    } catch (_) {
      if (mounted && generation == _generation && _owns)
        setState(() => _detailsFailed = true);
    } finally {
      if (mounted && generation == _generation)
        setState(() => _detailsLoading = false);
    }
  }

  @override
  void didUpdateWidget(covariant PaymentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.requestId != widget.requestId) {
      oldWidget.controller.removeListener(_changed);
      oldWidget.controller.releasePaymentRequest(_route);
      _route = null;
      widget.controller.addListener(_changed);
      _bind();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.controller.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_changed);
    widget.controller.releasePaymentRequest(_route);
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!_owns) return;
    if (widget.controller.payments.requestId != widget.requestId) {
      await widget.controller.watchPayment(widget.requestId);
    } else {
      await widget.controller.refreshPayment();
    }
  }

  Future<void> _selectCash() => _selectMethod();
  Future<void> _selectBank() => _selectMethod(bank: true);

  Future<void> _selectMethod({bool bank = false}) async {
    final controller = widget.controller;
    final id = widget.requestId;
    final route = _route;
    final owner = _owner;
    if (!_owns) return;
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 480),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetContext) => AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final valid = controller.ownsPaymentRoute(route, id, owner);
              final payment = valid && controller.payments.requestId == id
                  ? controller.payments.payment
                  : null;
              final submitting = valid && controller.paymentSubmitting(id);
              if (payment == null ||
                  payment.method != null ||
                  payment.status != 'pending') {
                return SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text(
                              'Thông tin thanh toán đã thay đổi. Vui lòng xem trạng thái mới.'),
                          TextButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Đóng')),
                        ])));
              }
              return PopScope(
                  canPop: !submitting,
                  child: PaymentConfirmationSheet(
                      bank: bank,
                      payment: payment,
                      submitting: submitting,
                      error: controller.paymentCommandError(id) == null
                          ? null
                          : paymentErrorMessage(
                              controller.paymentCommandError(id)!),
                      onCancel:
                          submitting ? null : () => Navigator.pop(sheetContext),
                      onSubmit: submitting ||
                              (bank && !controller.payments.bankAvailable) ||
                              controller.payments.loading ||
                              controller.payments.stale ||
                              controller.paymentSelectionNeedsRefresh(id)
                          ? null
                          : () async {
                              if (controller.paymentSubmitting(id)) return;
                              final success = bank
                                  ? await controller.selectBankPayment(id)
                                  : await controller.selectCashPayment(id);
                              if (success && sheetContext.mounted)
                                Navigator.pop(sheetContext);
                            }));
            }));
  }

  Widget _message(String text, {VoidCallback? retry}) => PaymentCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(text, style: PaymentStyle.body),
        if (retry != null)
          TextButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại')),
      ]));

  List<Widget> _content() {
    if (!isPaymentRequestId(widget.requestId))
      return [_message('Mã yêu cầu không hợp lệ.')];
    if (!_ready) return [const Center(child: CircularProgressIndicator())];
    if (!_owns)
      return [
        _message(
            'Phiên đăng nhập đã thay đổi hoặc không có quyền truy cập. Vui lòng quay lại.')
      ];
    final controller = widget.controller;
    final watcher = controller.payments;
    final payment =
        watcher.requestId == widget.requestId ? watcher.payment : null;
    final error = controller.paymentCommandError(widget.requestId);
    if (watcher.error == 'PAYMENT_NOT_ACCESSIBLE' ||
        (error == 'PAYMENT_NOT_ACCESSIBLE' && payment == null)) {
      return [
        _message('Không thể truy cập thanh toán của yêu cầu này.',
            retry: _refresh)
      ];
    }
    final children = <Widget>[
      if (watcher.stale)
        _message('Dữ liệu có thể chưa được cập nhật.',
            retry: payment?.method == 'bank_transfer' &&
                    (watcher.error != null || watcher.bankError != null)
                ? null
                : _refresh),
      if (payment?.method == 'bank_transfer' &&
          (watcher.error != null || watcher.bankError != null))
        _message('Không thể cập nhật trạng thái.', retry: _refresh),
      if (error != null) _message(paymentErrorMessage(error)),
      if (payment?.status != 'paid')
        if (controller.paymentCommandNotice(widget.requestId)
            case final String notice)
          _message(notice),
    ];
    if (payment == null) {
      if (watcher.loading) {
        children.add(const Center(child: CircularProgressIndicator()));
      } else if (watcher.error != null) {
        children.add(
            _message('Không tải được thông tin thanh toán.', retry: _refresh));
      } else {
        children.add(_message('Chưa có thông tin thanh toán cho yêu cầu này.'));
        if (_detailsLoading)
          children.add(const Center(child: CircularProgressIndicator()));
        if (_detailsFailed)
          children.add(_message('Chưa xác minh được yêu cầu cứu hộ.',
              retry: _loadDetails));
        if (_details?.request['status'] == 'completed') {
          children.add(PaymentActionButton(
              label: 'Chuẩn bị thanh toán',
              loading: controller.paymentSubmitting(widget.requestId),
              onPressed: watcher.stale
                  ? null
                  : () => controller.preparePayment(widget.requestId)));
        }
      }
      return children;
    }
    final code = _details?.request['request_code'];
    final requestCode = code is String && code.trim().isNotEmpty ? code : null;
    if (payment.currency != 'VND' || payment.amountExpected <= BigInt.zero) {
      children.add(_message(
          'Thông tin số tiền chưa được hỗ trợ. Vui lòng tải lại.',
          retry: _refresh));
    } else if (payment.method == 'cash' && payment.status == 'paid') {
      children.add(PaymentCashPaidSection(
          payment: payment,
          requestCode: requestCode,
          onDetails: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => HistoryDetailsScreen(
                      requestId: widget.requestId, controller: controller)))));
    } else if (payment.method == 'cash' &&
        payment.status == 'awaiting_payment') {
      children.add(PaymentCashAwaitingSection(payment: payment));
    } else if (payment.method == 'bank_transfer' && payment.status == 'paid') {
      children.add(BankPaymentPaidSection(
          payment: payment,
          bank: watcher.bankPayment,
          requestCode: requestCode,
          onDetails: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => HistoryDetailsScreen(
                      requestId: widget.requestId, controller: controller)))));
    } else if (payment.method == 'bank_transfer' &&
        payment.status == 'verifying') {
      children.add(BankPaymentVerifyingSection(
          payment: payment, requestCode: requestCode));
    } else if (payment.method == 'bank_transfer' &&
        ['failed', 'cancelled', 'refunded'].contains(payment.status)) {
      children.add(BankPaymentOutcomeSection(
          payment: payment, requestCode: requestCode));
    } else if (payment.method == 'bank_transfer' &&
        payment.status == 'awaiting_payment') {
      children.add(BankPaymentSection(
          payment: payment,
          bank: watcher.bankPayment,
          requestCode: requestCode,
          loading: watcher.loading,
          regenerating: controller.paymentSubmitting(widget.requestId),
          stale: watcher.stale || watcher.error != null,
          error: watcher.bankError,
          onRegenerate: watcher.loading ||
                  watcher.stale ||
                  watcher.error != null ||
                  watcher.bankError != null ||
                  controller.paymentSubmitting(widget.requestId)
              ? null
              : () async {
                  await controller.regenerateBankPayment(widget.requestId);
                },
          onRefresh: _refresh));
    } else if (payment.method == null && payment.status == 'pending') {
      final service = RescueService.values
          .where((s) => s.name == _details?.request['service_code'])
          .firstOrNull;
      children.addAll([
        PaymentSummaryCard(
            payment: payment,
            requestCode: requestCode,
            serviceLabel: service?.label),
        const Text('Phương thức thanh toán', style: PaymentStyle.title),
        PaymentMethodCard(
            cash: true,
            onTap: watcher.loading ||
                    watcher.stale ||
                    controller.paymentSubmitting(widget.requestId) ||
                    controller.paymentMethodRetryBlocked(widget.requestId,
                        bank: false) ||
                    controller.paymentSelectionNeedsRefresh(widget.requestId)
                ? null
                : _selectCash),
        PaymentMethodCard(
            cash: false,
            bankAvailable: watcher.bankAvailable,
            onTap: !watcher.bankAvailable ||
                    watcher.loading ||
                    watcher.stale ||
                    controller.paymentSubmitting(widget.requestId) ||
                    controller.paymentSelectionNeedsRefresh(widget.requestId) ||
                    controller.paymentMethodRetryBlocked(widget.requestId,
                        bank: true)
                ? null
                : _selectBank),
        if (controller.paymentSubmitting(widget.requestId))
          const Center(child: CircularProgressIndicator()),
      ]);
    } else {
      children.add(_message(
          'Trạng thái thanh toán này chưa được hỗ trợ trên ứng dụng.',
          retry: _refresh));
    }
    children.add(TextButton.icon(
        onPressed: watcher.loading ? null : _refresh,
        icon: const Icon(Icons.refresh),
        label: const Text('Cập nhật thanh toán')));
    return children;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: PaymentStyle.background,
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(children: [
                PaymentHeader(
                    title: 'Thanh toán',
                    onBack: () => Navigator.maybePop(context)),
                Expanded(
                    child: SafeArea(
                        top: false,
                        child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              for (final child in _content()) ...[
                                child,
                                const SizedBox(height: 16)
                              ],
                            ]))),
              ]))));
}

String paymentErrorMessage(String code) => switch (code) {
      'BANK_UNAVAILABLE' => 'Chuyển khoản ngân hàng hiện chưa khả dụng.',
      'BANK_INTENT_UNAVAILABLE' =>
        'Thông tin chuyển khoản không còn khả dụng. Vui lòng tải lại.',
      'BANK_INTENT_NOT_EXPIRED' =>
        'Mã chuyển khoản vẫn còn hiệu lực. Chưa thể tạo mã mới.',
      'BANK_INTENT_VERSION_CONFLICT' ||
      'INVALID_EXPECTED_INTENT_VERSION' =>
        'Mã chuyển khoản đã thay đổi. Vui lòng cập nhật trước khi thử lại.',
      'BANK_TRANSFER_RECONCILIATION_REQUIRED' =>
        'Hệ thống đã ghi nhận giao dịch cho mã cũ và cần đối soát. Không chuyển tiền thêm; vui lòng chờ xác minh.',
      'PAYMENT_NOT_ELIGIBLE' => 'Yêu cầu này chưa đủ điều kiện tạo thanh toán.',
      'ZERO_AMOUNT_REQUIRES_POLICY' =>
        'Thanh toán có số tiền bằng 0 chưa được hỗ trợ.',
      'QUOTE_SNAPSHOT_INCONSISTENT' =>
        'Thông tin báo giá chưa nhất quán. Chưa thể tạo thanh toán.',
      'VERSION_CONFLICT' =>
        'Thanh toán đã thay đổi. Vui lòng xem dữ liệu mới trước khi thử lại.',
      'PAYMENT_ALREADY_SETTLED' ||
      'PAYMENT_STATE_CONFLICT' =>
        'Trạng thái đã thay đổi. Vui lòng cập nhật thanh toán.',
      'IDEMPOTENCY_CONFLICT' =>
        'Không thể gửi lại thao tác này. Vui lòng cập nhật thanh toán.',
      'PAYMENT_COMMAND_UNCERTAIN' =>
        'Chưa xác định được kết quả. Bạn có thể thử lại thao tác; ứng dụng sẽ dùng lại mã thao tác cũ.',
      'PAYMENT_NOT_ACCESSIBLE' =>
        'Không thể truy cập thanh toán của yêu cầu này.',
      _ =>
        'Chưa thể thực hiện thao tác thanh toán. Vui lòng tải lại và thử lại.',
    };
