/// Formats decimal digits directly: preserves bigint precision on Flutter web.
String paymentMoney(BigInt amount, String currency) {
  final digits = amount.toString();
  final grouped = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.');
  return '$grouped ${currency == 'VND' ? 'đ' : currency}';
}

String paymentTime(DateTime? value) {
  if (value == null) return 'Chưa có thông tin';
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)} • '
      '${two(local.day)}/${two(local.month)}/${local.year}';
}
