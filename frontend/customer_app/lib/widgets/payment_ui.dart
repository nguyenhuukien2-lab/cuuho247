import 'package:flutter/material.dart';
import '../core/utils/payment_format.dart';
import '../models/payment_dto.dart';

/// Tokens scoped to the three customer cash screens, not the app-wide theme.
abstract final class PaymentStyle {
  static const blue = Color(0xFF0037B0), ink = Color(0xFF0B1C30);
  static const muted = Color(0xFF434655), background = Color(0xFFF8F9FF);
  static const pale = Color(0xFFEFF4FF), high = Color(0xFFDCE9FF);
  static const green = Color(0xFF006C49), mint = Color(0xFF6CF8BB);
  static const amber = Color(0xFF78350F), amberSoft = Color(0xFFFFF3CF);
  static const body = TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 14,
      height: 20 / 14,
      color: ink);
  static const title = TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 18,
      height: 24 / 18,
      fontWeight: FontWeight.w700,
      color: ink);
  static const caption = TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 12,
      height: 16 / 12,
      color: muted);
}

class PaymentHeader extends StatelessWidget {
  const PaymentHeader({super.key, required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => ColoredBox(
      color: PaymentStyle.blue,
      child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    IconButton(
                        tooltip: 'Quay lại',
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 24)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(title,
                            style: PaymentStyle.title
                                .copyWith(color: Colors.white))),
                  ])))));
}

class PaymentCard extends StatelessWidget {
  const PaymentCard(
      {super.key,
      required this.child,
      this.radius = 12,
      this.padding = const EdgeInsets.all(16),
      this.color = Colors.white});
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2)
          ]),
      child: child);
}

class PaymentAmountText extends StatelessWidget {
  const PaymentAmountText(
      {super.key,
      required this.amount,
      required this.currency,
      this.large = false,
      this.color = PaymentStyle.blue});
  final BigInt amount;
  final String currency;
  final bool large;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(paymentMoney(amount, currency),
      textAlign: TextAlign.center,
      style: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          color: color,
          fontSize: large ? 36 : 28,
          height: large ? 44 / 36 : 36 / 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -.5));
}

class PaymentSummaryCard extends StatelessWidget {
  const PaymentSummaryCard(
      {super.key, required this.payment, this.requestCode, this.serviceLabel});
  final PaymentDto payment;
  final String? requestCode, serviceLabel;
  @override
  Widget build(BuildContext context) => PaymentCard(
      radius: 20,
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              if (requestCode != null)
                Text('Mã cứu hộ: $requestCode',
                    style: PaymentStyle.caption.copyWith(
                        color: PaymentStyle.blue, fontWeight: FontWeight.w700)),
              Text(payment.paymentCode, style: PaymentStyle.caption),
            ]),
        const SizedBox(height: 20),
        Row(children: [
          const _IconBox(icon: Icons.receipt_long_outlined),
          const SizedBox(width: 16),
          Expanded(
              child: Text(serviceLabel ?? 'Thanh toán cứu hộ',
                  style: PaymentStyle.title)),
        ]),
        const SizedBox(height: 20),
        PaymentCard(
            color: PaymentStyle.pale,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('TỔNG THANH TOÁN', style: PaymentStyle.caption),
                  const SizedBox(height: 8),
                  PaymentAmountText(
                      amount: payment.amountExpected,
                      currency: payment.currency),
                  const SizedBox(height: 8),
                  const Text('Số tiền theo báo giá đã hoàn tất.',
                      style: PaymentStyle.caption),
                ])),
      ]));
}

class PaymentMethodCard extends StatelessWidget {
  const PaymentMethodCard(
      {super.key, required this.cash, this.onTap, this.bankAvailable = false});
  final bool cash;
  final bool bankAvailable;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      enabled: onTap != null,
      child: Material(
          color: cash ? Colors.white : PaymentStyle.pale,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _IconBox(
                            icon: cash
                                ? Icons.payments_outlined
                                : Icons.account_balance_outlined,
                            color: cash
                                ? PaymentStyle.mint.withValues(alpha: .6)
                                : PaymentStyle.high,
                            foreground:
                                cash ? PaymentStyle.green : PaymentStyle.muted),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(cash ? 'Tiền mặt' : 'Chuyển khoản ngân hàng',
                                  style: PaymentStyle.body.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                  cash
                                      ? 'Thanh toán trực tiếp cho đối tác cứu hộ'
                                      : bankAvailable
                                          ? 'Quét QR hoặc chuyển khoản theo thông tin ngân hàng'
                                          : 'Chưa hỗ trợ',
                                  style: PaymentStyle.caption),
                            ])),
                        const SizedBox(width: 4),
                        Icon(
                            cash || bankAvailable
                                ? Icons.chevron_right
                                : Icons.lock_outline,
                            color: PaymentStyle.muted,
                            size: 20),
                      ])))));
}

class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge({super.key, required this.paid});
  final bool paid;
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
              color: paid ? PaymentStyle.mint : PaymentStyle.amberSoft,
              borderRadius: BorderRadius.circular(100)),
          child: Text(paid ? 'Đã nhận tiền mặt' : 'Đang chờ đối tác xác nhận',
              textAlign: TextAlign.center,
              style: PaymentStyle.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: paid ? PaymentStyle.green : PaymentStyle.amber))));
}

class PaymentCashAwaitingSection extends StatelessWidget {
  const PaymentCashAwaitingSection({super.key, required this.payment});
  final PaymentDto payment;
  @override
  Widget build(BuildContext context) => Column(children: [
        PaymentCard(
            color: PaymentStyle.pale,
            child: Text('Mã thanh toán: ${payment.paymentCode}',
                style: PaymentStyle.body)),
        const SizedBox(height: 16),
        PaymentCard(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const _StatusHero(paid: false),
              const SizedBox(height: 16),
              const PaymentStatusBadge(paid: false),
              const SizedBox(height: 16),
              const Text('SỐ TIỀN CẦN THANH TOÁN', style: PaymentStyle.caption),
              const SizedBox(height: 4),
              PaymentAmountText(
                  amount: payment.amountExpected,
                  currency: payment.currency,
                  color: PaymentStyle.ink),
              const SizedBox(height: 12),
              const Text('Vui lòng thanh toán trực tiếp cho đối tác cứu hộ.',
                  style: PaymentStyle.body, textAlign: TextAlign.center),
            ])),
        const SizedBox(height: 16),
        const PaymentCard(
            color: PaymentStyle.high,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Quy trình xác nhận tiền mặt', style: PaymentStyle.title),
              SizedBox(height: 12),
              Text(
                  'Đối tác xác nhận sau khi nhận đủ tiền. Trạng thái thanh toán sẽ được cập nhật từ hệ thống.',
                  style: PaymentStyle.body),
              SizedBox(height: 8),
              Text('Bạn không cần thao tác xác nhận đã trả tiền trên ứng dụng.',
                  style: PaymentStyle.body),
            ])),
      ]);
}

class PaymentCashPaidSection extends StatelessWidget {
  const PaymentCashPaidSection(
      {super.key,
      required this.payment,
      required this.onDetails,
      this.requestCode});
  final PaymentDto payment;
  final VoidCallback onDetails;
  final String? requestCode;
  @override
  Widget build(BuildContext context) => Column(children: [
        PaymentCard(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const _StatusHero(paid: true),
              const SizedBox(height: 16),
              const PaymentStatusBadge(paid: true),
              const SizedBox(height: 12),
              Text('Đã thanh toán',
                  style: PaymentStyle.title
                      .copyWith(fontSize: 28, height: 36 / 28),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Đối tác đã xác nhận nhận tiền mặt.',
                  style: PaymentStyle.body, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              PaymentCard(
                  color: PaymentStyle.pale,
                  child: Column(children: [
                    const Text('SỐ TIỀN ĐÃ NHẬN', style: PaymentStyle.caption),
                    const SizedBox(height: 8),
                    if (payment.amountReceived != null)
                      PaymentAmountText(
                          amount: payment.amountReceived!,
                          currency: payment.currency,
                          large: true),
                    if (payment.amountReceived == null)
                      const Text('Chưa có thông tin số tiền đã nhận.',
                          style: PaymentStyle.body),
                  ])),
            ])),
        const SizedBox(height: 16),
        PaymentCard(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Thông tin thanh toán', style: PaymentStyle.title),
                  const SizedBox(height: 12),
                  if (requestCode != null)
                    _ReceiptRow('Mã cứu hộ', requestCode!),
                  _ReceiptRow('Mã thanh toán', payment.paymentCode),
                  const _ReceiptRow('Phương thức', 'Tiền mặt'),
                  _ReceiptRow('Thời gian nhận',
                      paymentTime(payment.cashReceivedAt ?? payment.paidAt)),
                ])),
        const SizedBox(height: 24),
        PaymentActionButton(
            label: 'Xem chi tiết đơn cứu hộ',
            onPressed: onDetails,
            color: const Color(0xFFF97316)),
      ]);
}

class PaymentActionButton extends StatelessWidget {
  const PaymentActionButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.loading = false,
      this.color = PaymentStyle.blue});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 56),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: const StadiumBorder()),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (loading) ...[
              const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
            ],
            Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: PaymentStyle.body.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700))),
          ])));
}

class PaymentConfirmationSheet extends StatelessWidget {
  const PaymentConfirmationSheet(
      {super.key,
      required this.payment,
      required this.onCancel,
      required this.onSubmit,
      required this.submitting,
      this.bank = false,
      this.error});
  final PaymentDto payment;
  final VoidCallback? onCancel, onSubmit;
  final bool submitting;
  final bool bank;
  final String? error;
  @override
  Widget build(BuildContext context) => SafeArea(
      child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: const Color(0xFFC4C5D7),
                            borderRadius: BorderRadius.circular(8)))),
                const SizedBox(height: 20),
                const Text('Xác nhận phương thức', style: PaymentStyle.caption),
                const SizedBox(height: 8),
                Text(bank ? 'Chuyển khoản ngân hàng' : 'Tiền mặt tại chỗ',
                    style: PaymentStyle.title),
                const SizedBox(height: 16),
                Text(
                    bank
                        ? 'Tạo mã QR cho ${paymentMoney(payment.amountExpected, payment.currency)} theo thông tin ngân hàng từ hệ thống. Phương thức không thể đổi sau khi chọn.'
                        : 'Thanh toán ${paymentMoney(payment.amountExpected, payment.currency)} trực tiếp cho đối tác cứu hộ.',
                    style: PaymentStyle.body),
                const SizedBox(height: 8),
                const Text('Chọn phương thức chưa có nghĩa là đã thanh toán.',
                    style: PaymentStyle.caption),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!,
                      style: PaymentStyle.body
                          .copyWith(color: const Color(0xFFBA1A1A))),
                ],
                const SizedBox(height: 20),
                PaymentActionButton(
                    key: ValueKey(bank ? 'confirm-bank' : 'confirm-cash'),
                    label: bank ? 'Tạo mã QR chuyển khoản' : 'Chọn tiền mặt',
                    loading: submitting,
                    onPressed: onSubmit),
                const SizedBox(height: 8),
                TextButton(
                    onPressed: submitting ? null : onCancel,
                    child: const Text('Hủy')),
              ])));
}

class _IconBox extends StatelessWidget {
  const _IconBox(
      {required this.icon,
      this.color = PaymentStyle.pale,
      this.foreground = PaymentStyle.blue});
  final IconData icon;
  final Color color, foreground;
  @override
  Widget build(BuildContext context) => Container(
      width: 48,
      height: 48,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: foreground, size: 26));
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.paid});
  final bool paid;
  @override
  Widget build(BuildContext context) => Container(
      width: 96,
      height: 96,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: paid
              ? PaymentStyle.mint.withValues(alpha: .4)
              : PaymentStyle.amberSoft),
      child: Container(
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: paid ? PaymentStyle.green : const Color(0xFFFFFBEB)),
          child: Icon(
              paid ? Icons.check_circle_outline : Icons.payments_outlined,
              size: 44,
              color: paid ? Colors.white : const Color(0xFFD97706))));
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(this.label, this.value);
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
