import 'stitch_customer_header.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_controller.dart';
import '../services/location_service.dart';

String bookingRequestCode(String? value) {
  final code = value?.trim();
  return code != null && RegExp(r'^CH-[A-Za-z0-9]+$').hasMatch(code)
      ? code
      : 'Chưa có mã';
}

/// Visuals scoped to the booking form; other tabs keep their existing theme.
abstract final class BookingFormStyle {
  static const blue = Color(0xFF1D4ED8), navy = Color(0xFF0037B0);
  static const pale = Color(0xFFEEF4FF), background = Color(0xFFF8F9FF);
  static const green = Color(0xFF006C49), ink = Color(0xFF0B1C30);
  static const muted = Color(0xFF434655), border = Color(0xFFE5EAF2);

  static ThemeData theme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
        colorScheme:
            base.colorScheme.copyWith(primary: blue, surface: Colors.white),
        cardTheme: CardThemeData(
            color: Colors.white,
            margin: EdgeInsets.zero,
            elevation: 1,
            shadowColor: navy.withValues(alpha: .08),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: border))),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
            filled: true,
            fillColor: pale,
            labelStyle: const TextStyle(color: muted, fontSize: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: border))),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                foregroundColor: blue,
                textStyle: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
                minimumSize: const Size(48, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)))),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: blue,
                textStyle: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600))));
  }
}

class BookingFormHeader extends StatelessWidget {
  const BookingFormHeader({super.key, required this.onAccount});
  final VoidCallback onAccount;
  @override
  Widget build(BuildContext context) =>
      StitchCustomerHeader(onAccount: onAccount);
}

class BookingSectionPreview extends StatelessWidget {
  const BookingSectionPreview(
      {super.key,
      required this.title,
      required this.value,
      required this.icon,
      required this.onEdit,
      this.action = 'Chỉnh sửa'});
  final String title, value, action;
  final IconData icon;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: BookingFormStyle.navy))),
              TextButton(onPressed: onEdit, child: Text(action)),
            ]),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 20, color: BookingFormStyle.blue),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, color: BookingFormStyle.muted))),
            ]),
          ])));
}

class BookingQuoteCard extends StatelessWidget {
  const BookingQuoteCard({super.key, this.request});
  final RescueRequestData? request;
  @override
  Widget build(BuildContext context) {
    final amount = request?.price;
    final code = request?.quoteCode?.trim();
    final hasCode = code != null && RegExp(r'^BG-[A-Za-z0-9]+$').hasMatch(code);
    return Card(
        key: const ValueKey('booking-quote-card'),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.receipt_long_outlined,
                    color: BookingFormStyle.blue, size: 22),
                SizedBox(width: 8),
                Expanded(
                    child: Text('Chi phí cứu hộ',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: BookingFormStyle.navy))),
              ]),
              const SizedBox(height: 12),
              if (amount == null) ...[
                const Text('Đối tác sẽ gửi báo giá trước khi thực hiện.',
                    style:
                        TextStyle(fontSize: 14, color: BookingFormStyle.muted)),
                const SizedBox(height: 10),
                const BookingFormBadge('Chưa có báo giá',
                    color: Color(0xFFB45309), background: Color(0xFFFEF3C7)),
              ] else ...[
                if (hasCode)
                  Text(code,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: BookingFormStyle.navy)),
                const SizedBox(height: 8),
                const BookingFormBadge('Đã có báo giá',
                    color: Color(0xFF15803D), background: Color(0xFFDCFCE7)),
                const SizedBox(height: 12),
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: BookingFormStyle.pale,
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tổng tiền',
                              style: TextStyle(
                                  fontSize: 12, color: BookingFormStyle.muted)),
                          Text(
                              '${NumberFormat.decimalPattern('vi_VN').format(amount)} đ',
                              key: const ValueKey('booking-real-total'),
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: BookingFormStyle.blue)),
                        ])),
              ],
            ])));
  }
}

class BookingFormBadge extends StatelessWidget {
  const BookingFormBadge(this.label,
      {super.key, required this.color, required this.background});
  final String label;
  final Color color, background;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: color)));
}

class BookingPickupPoint extends StatelessWidget {
  const BookingPickupPoint(
      {super.key,
      required this.address,
      required this.coordinates,
      this.onEdit});
  final String address;
  final RescueCoordinates? coordinates;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.radio_button_checked,
                size: 18, color: BookingFormStyle.blue)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ĐIỂM ĐÓN XE',
              style: TextStyle(
                  fontSize: 11,
                  color: BookingFormStyle.blue,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
              address.isNotEmpty
                  ? address
                  : coordinates?.label ?? 'Chưa chọn vị trí',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BookingFormStyle.ink)),
          if (coordinates?.isValid == true) ...[
            const SizedBox(height: 8),
            const BookingFormBadge('Tọa độ đã chọn',
                color: Color(0xFF15803D), background: Color(0xFFDCFCE7)),
          ],
          if (onEdit != null)
            TextButton(onPressed: onEdit, child: const Text('Đổi vị trí')),
        ])),
      ]);
}

class BookingSubmitButton extends StatelessWidget {
  const BookingSubmitButton(
      {super.key,
      required this.label,
      required this.loading,
      required this.onPressed});
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: FilledButton(
          key: const ValueKey('booking-submit-button'),
          onPressed: onPressed,
          style: FilledButton.styleFrom(
              elevation: 2,
              shadowColor: BookingFormStyle.blue.withValues(alpha: .18),
              backgroundColor: BookingFormStyle.blue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFDEE7F7),
              disabledForegroundColor: BookingFormStyle.muted,
              minimumSize: const Size(48, 56),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              textStyle: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (loading)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
            else
              const Icon(Icons.crisis_alert, size: 20),
            const SizedBox(width: 8),
            Flexible(
                child: Text(loading ? 'Đang xử lý...' : label,
                    textAlign: TextAlign.center)),
          ])));
}
