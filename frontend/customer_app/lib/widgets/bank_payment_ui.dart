import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/utils/payment_format.dart';
import '../models/bank_payment_dto.dart';
import '../models/payment_dto.dart';
import 'payment_ui.dart';

/// Customer Bank QR (Stitch bd756e87ab6a4299876b1ef8d40c649d).
/// Timers display server TTL and invalidate; only getter data determines status.
class BankPaymentSection extends StatefulWidget {
  const BankPaymentSection(
      {super.key,
      required this.payment,
      required this.bank,
      required this.loading,
      required this.regenerating,
      required this.stale,
      required this.onRefresh,
      required this.onRegenerate,
      this.error,
      this.requestCode});
  final PaymentDto payment;
  final BankPaymentDto? bank;
  final bool loading, regenerating, stale;
  final String? error, requestCode;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onRegenerate;
  @override
  State<BankPaymentSection> createState() => _BankPaymentSectionState();
}

class _BankPaymentSectionState extends State<BankPaymentSection> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _expiryRefetched = false;
  Duration get _remaining => widget.bank == null
      ? Duration.zero
      : widget.bank!.expiresAt.difference(widget.bank!.serverTime) - _elapsed;

  @override
  void initState() {
    super.initState();
    _bindTimer();
  }

  @override
  void didUpdateWidget(covariant BankPaymentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bank, widget.bank)) _bindTimer();
  }

  void _bindTimer() {
    _timer?.cancel();
    _elapsed = Duration.zero;
    _expiryRefetched = false;
    if (widget.bank?.ready != true) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _elapsed = Duration(seconds: timer.tick));
      if (_remaining <= Duration.zero && !_expiryRefetched) {
        _expiryRefetched = true;
        _timer?.cancel();
        unawaited(widget.onRefresh());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    final bank = widget.bank;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted || !identical(bank, widget.bank)) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã sao chép')));
    } catch (_) {
      if (!mounted || !identical(bank, widget.bank)) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Không thể sao chép. Vui lòng thử lại.')));
    }
  }

  Widget _field(String label, String value,
          {String? copyKey, bool copyEnabled = false}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label, style: PaymentStyle.caption),
                  const SizedBox(height: 4),
                  Text(value,
                      style: PaymentStyle.body
                          .copyWith(fontWeight: FontWeight.w700)),
                ])),
            if (copyKey != null)
              IconButton(
                  key: ValueKey(copyKey),
                  tooltip: 'Sao chép $label',
                  onPressed: copyEnabled ? () => _copy(value) : null,
                  icon: const Icon(Icons.copy_outlined)),
          ]));

  @override
  Widget build(BuildContext context) {
    final b = widget.bank;
    final terminal = ['paid', 'cancelled', 'refunded', 'failed']
        .contains(widget.payment.status);
    final valid = b != null && b.matches(widget.payment);
    final usable = valid &&
        b.ready &&
        !widget.stale &&
        widget.error == null &&
        !widget.loading &&
        _remaining > Duration.zero;
    final expired = valid &&
        b.intentStatus == 'expired' &&
        widget.payment.status == 'awaiting_payment';
    final status = switch (widget.payment.status) {
      'cancelled' => 'Thanh toán đã hủy',
      'refunded' => 'Thanh toán đã hoàn tiền',
      'failed' => 'Thanh toán không thành công',
      'paid' => 'Trạng thái từ hệ thống: đã thanh toán',
      'verifying' => 'Đang xác minh giao dịch',
      _ => !valid
          ? (widget.loading
              ? 'Đang tải thông tin chuyển khoản'
              : 'Chuyển khoản chưa khả dụng')
          : b.intentStatus == 'expired'
              ? 'Phiên thanh toán đã hết hạn.'
              : b.intentStatus == 'cancelled'
                  ? 'Yêu cầu chuyển khoản đã hủy'
                  : b.intentStatus == 'failed'
                      ? 'Không thể tạo thông tin chuyển khoản'
                      : !b.available || b.intentStatus != 'ready'
                          ? 'Chuyển khoản chưa khả dụng'
                          : widget.stale || widget.error != null
                              ? 'Chưa cập nhật được thông tin chuyển khoản'
                              : _remaining <= Duration.zero
                                  ? 'Đang cập nhật thời hạn QR'
                                  : 'Đang chờ thanh toán',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PaymentCard(
          color: PaymentStyle.pale,
          child: Column(children: [
            const Icon(Icons.account_balance_outlined,
                color: PaymentStyle.blue, size: 32),
            const SizedBox(height: 12),
            const Text('Chuyển khoản ngân hàng', style: PaymentStyle.title),
            const SizedBox(height: 8),
            Semantics(
                liveRegion: true,
                child: Text(status,
                    textAlign: TextAlign.center,
                    style: PaymentStyle.body.copyWith(
                        color: PaymentStyle.amber,
                        fontWeight: FontWeight.w700))),
            if (widget.loading)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator()),
            if (usable) ...[
              const SizedBox(height: 16),
              Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: AspectRatio(
                          aspectRatio: 1,
                          child: QrImageView(
                              key: const ValueKey('bank-qr'),
                              data: b.qrPayload!,
                              padding: const EdgeInsets.all(24),
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                              semanticsLabel: 'Mã QR chuyển khoản từ hệ thống',
                              errorStateBuilder: (_, __) => const Center(
                                  child: Text('Không thể hiển thị mã QR.')))))),
              const SizedBox(height: 12),
              Text(
                  'Thời gian còn lại: ${_remaining.inMinutes}:${(_remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: PaymentStyle.caption),
            ],
          ])),
      const SizedBox(height: 16),
      PaymentCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Thông tin chuyển khoản', style: PaymentStyle.title),
        const SizedBox(height: 12),
        PaymentAmountText(
            amount: widget.payment.amountExpected,
            currency: widget.payment.currency),
        _field('Mã thanh toán', widget.payment.paymentCode),
        if (widget.requestCode != null)
          _field('Mã cứu hộ', widget.requestCode!),
        if (valid) ...[
          _field('Ngân hàng', b.bankName),
          _field('Số tài khoản', b.accountNumber,
              copyKey: 'copy-bank-account', copyEnabled: usable),
          _field('Chủ tài khoản', b.accountName),
          _field('Nội dung chuyển khoản', b.transferContent,
              copyKey: 'copy-bank-content', copyEnabled: usable),
          _field('Thời hạn QR', paymentTime(b.expiresAt)),
        ],
      ])),
      if (!terminal) ...[
        const SizedBox(height: 16),
        PaymentCard(
            color: PaymentStyle.amberSoft,
            child: Text(
                b?.intentStatus == 'expired'
                    ? 'Không chuyển tiền theo mã đã hết hạn. Hãy tạo mã mới trước khi thanh toán.'
                    : 'Chuyển đúng số tiền và giữ nguyên nội dung. Mã QR không phải xác nhận đã nhận tiền.',
                style: PaymentStyle.body)),
      ],
      const SizedBox(height: 16),
      if (expired) ...[
        PaymentActionButton(
            key: const ValueKey('regenerate-bank'),
            label: 'Tạo mã mới',
            loading: widget.regenerating,
            onPressed: widget.regenerating ||
                    widget.loading ||
                    widget.stale ||
                    widget.error != null ||
                    !b.available
                ? null
                : widget.onRegenerate),
        const SizedBox(height: 12),
      ],
      PaymentActionButton(
          label: 'Kiểm tra thanh toán',
          loading: widget.loading,
          onPressed:
              widget.loading || widget.regenerating ? null : widget.onRefresh),
    ]);
  }
}

/// Stitch 59a97c6c9d9c443a87671e93a29f3f3c. Only an authoritative getter
/// `bank_transfer/verifying` can select this section; no timer starts it.
class BankPaymentVerifyingSection extends StatelessWidget {
  const BankPaymentVerifyingSection(
      {super.key, required this.payment, this.requestCode});
  final PaymentDto payment;
  final String? requestCode;

  @override
  Widget build(BuildContext context) {
    if (payment.method != 'bank_transfer' || payment.status != 'verifying') {
      return const SizedBox.shrink();
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(children: [
            SizedBox.square(
                dimension: 144,
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                      width: 112,
                      height: 112,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: PaymentStyle.pale)),
                  SizedBox.square(
                      dimension: 136,
                      child: CircularProgressIndicator(
                          key: const ValueKey('bank-verifying-spinner'),
                          value: MediaQuery.disableAnimationsOf(context)
                              ? .7
                              : null,
                          strokeWidth: 5,
                          color: const Color(0xFF1D4ED8),
                          backgroundColor: PaymentStyle.high,
                          semanticsLabel: 'Đang xác minh giao dịch')),
                  const Icon(Icons.shield_outlined,
                      color: PaymentStyle.blue, size: 40),
                ])),
            const SizedBox(height: 24),
            Semantics(
                liveRegion: true,
                header: true,
                child: Text('Đang xác minh giao dịch',
                    textAlign: TextAlign.center,
                    style: PaymentStyle.title
                        .copyWith(fontSize: 24, height: 32 / 24))),
            const SizedBox(height: 12),
            const Text('Hệ thống đang xác minh giao dịch với ngân hàng.',
                textAlign: TextAlign.center, style: PaymentStyle.body),
          ])),
      PaymentCard(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Thông tin đối chiếu', style: PaymentStyle.title),
            const SizedBox(height: 12),
            _BankReceiptRow('Số tiền cần thanh toán',
                paymentMoney(payment.amountExpected, payment.currency)),
            _BankReceiptRow('Mã thanh toán', payment.paymentCode),
            if (requestCode != null) _BankReceiptRow('Mã cứu hộ', requestCode!),
            const _BankReceiptRow('Phương thức', 'Chuyển khoản ngân hàng'),
          ])),
      const SizedBox(height: 16),
      const PaymentCard(
          color: PaymentStyle.pale,
          child: Text(
              'Bạn có thể quay lại hoặc cập nhật trạng thái. Không cần chuyển khoản thêm trong khi giao dịch đang được xác minh.',
              style: PaymentStyle.body)),
    ]);
  }
}

/// Stitch aba372441d284c2a90b4e4baf1051f53. Amount/time come exclusively
/// from the public payment getter. Optional bank data must match that snapshot.
class BankPaymentPaidSection extends StatelessWidget {
  const BankPaymentPaidSection(
      {super.key,
      required this.payment,
      required this.onDetails,
      this.bank,
      this.requestCode});
  final PaymentDto payment;
  final BankPaymentDto? bank;
  final String? requestCode;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    if (payment.method != 'bank_transfer' || payment.status != 'paid') {
      return const SizedBox.shrink();
    }
    final receiptBank = bank?.matches(payment) == true ? bank : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PaymentCard(
          radius: 16,
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PaymentStyle.mint.withValues(alpha: .4)),
                child: const DecoratedBox(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: PaymentStyle.green),
                    child: Icon(Icons.verified_outlined,
                        color: Colors.white, size: 34))),
            const SizedBox(height: 16),
            Semantics(
                liveRegion: true,
                header: true,
                child: Text('Thanh toán thành công',
                    textAlign: TextAlign.center,
                    style: PaymentStyle.title.copyWith(
                        fontSize: 24,
                        height: 32 / 24,
                        fontWeight: FontWeight.w800))),
            const SizedBox(height: 12),
            const Text('Thanh toán chuyển khoản đã được xác nhận.',
                textAlign: TextAlign.center, style: PaymentStyle.body),
            const SizedBox(height: 20),
            PaymentCard(
                color: PaymentStyle.pale,
                child: Column(children: [
                  const Text('SỐ TIỀN ĐÃ NHẬN', style: PaymentStyle.caption),
                  const SizedBox(height: 8),
                  if (payment.amountReceived != null)
                    PaymentAmountText(
                        amount: payment.amountReceived!,
                        currency: payment.currency)
                  else
                    const Text('Chưa có thông tin số tiền đã nhận.',
                        style: PaymentStyle.body),
                ])),
          ])),
      const SizedBox(height: 16),
      PaymentCard(
          radius: 16,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Thông tin thanh toán', style: PaymentStyle.title),
            const SizedBox(height: 12),
            _BankReceiptRow('Mã thanh toán', payment.paymentCode),
            if (requestCode != null) _BankReceiptRow('Mã cứu hộ', requestCode!),
            const _BankReceiptRow('Phương thức', 'Chuyển khoản ngân hàng'),
            _BankReceiptRow('Thời gian xác nhận', paymentTime(payment.paidAt)),
            if (receiptBank != null) ...[
              _BankReceiptRow('Ngân hàng', receiptBank.bankName),
              // This is the intent reference, not a provider transaction ID.
              _BankReceiptRow(
                  'Mã tham chiếu thanh toán', receiptBank.reference),
              _BankReceiptRow(
                  'Nội dung chuyển khoản', receiptBank.transferContent),
            ],
          ])),
      const SizedBox(height: 24),
      PaymentActionButton(
          label: 'Xem chi tiết đơn cứu hộ',
          color: const Color(0xFF1D4ED8),
          onPressed: onDetails),
    ]);
  }
}

/// Business terminal states only. Network failures never select this section.
class BankPaymentOutcomeSection extends StatelessWidget {
  const BankPaymentOutcomeSection(
      {super.key, required this.payment, this.requestCode});
  final PaymentDto payment;
  final String? requestCode;

  @override
  Widget build(BuildContext context) {
    if (payment.method != 'bank_transfer' ||
        !['failed', 'cancelled', 'refunded'].contains(payment.status)) {
      return const SizedBox.shrink();
    }
    final (title, description, icon) = switch (payment.status) {
      'failed' => (
          'Thanh toán không thành công',
          'Hệ thống ghi nhận thanh toán không thành công. Vui lòng cập nhật trạng thái trước khi thực hiện thao tác tiếp theo.',
          Icons.error_outline
        ),
      'cancelled' => (
          'Thanh toán đã hủy',
          'Thanh toán này đã được hủy. Không tiếp tục chuyển tiền theo mã QR cũ.',
          Icons.cancel_outlined
        ),
      _ => (
          'Thanh toán đã hoàn tiền',
          'Hệ thống ghi nhận thanh toán này đã được hoàn tiền.',
          Icons.undo_outlined
        ),
    };
    return PaymentCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Icon(icon, color: PaymentStyle.amber, size: 48),
      const SizedBox(height: 16),
      Semantics(
          liveRegion: true,
          child: Text(title,
              style: PaymentStyle.title, textAlign: TextAlign.center)),
      const SizedBox(height: 12),
      Text(description, style: PaymentStyle.body),
      const SizedBox(height: 16),
      _BankReceiptRow('Mã thanh toán', payment.paymentCode),
      if (requestCode != null) _BankReceiptRow('Mã cứu hộ', requestCode!),
      const _BankReceiptRow('Phương thức', 'Chuyển khoản ngân hàng'),
    ]));
  }
}

class _BankReceiptRow extends StatelessWidget {
  const _BankReceiptRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: PaymentStyle.caption),
        const SizedBox(height: 4),
        SelectableText(value,
            style: PaymentStyle.body.copyWith(fontWeight: FontWeight.w600)),
      ]));
}
