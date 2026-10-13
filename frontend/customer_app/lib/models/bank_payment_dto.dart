import 'payment_dto.dart';

/// Allowlisted server DTO. No provider payload or client-built payment data.
class BankPaymentDto {
  BankPaymentDto.fromJson(Map<String, dynamic> row)
      : paymentId = _text(row, 'payment_id'),
        intentId = _text(row, 'bank_intent_id'),
        requestId = _text(row, 'request_id'),
        paymentCode = _text(row, 'payment_code'),
        status = _text(row, 'payment_status'),
        method = _text(row, 'payment_method'),
        intentStatus = _text(row, 'bank_intent_status'),
        reference = _text(row, 'bank_reference'),
        bankName = _text(row, 'bank_name'),
        bankBin = _text(row, 'bank_bin'),
        accountNumber = _text(row, 'account_number'),
        accountName = _text(row, 'account_name'),
        transferContent = _text(row, 'transfer_content'),
        currency = _text(row, 'currency'),
        amountExpected = _integer(row, 'amount_expected'),
        version = _integer(row, 'version'),
        intentVersion = _integer(row, 'bank_intent_version'),
        expiresAt = DateTime.parse(_text(row, 'expires_at')),
        serverTime = DateTime.parse(_text(row, 'server_time')),
        available = row['available'] == true,
        qrPayload = row['qr_payload'] as String? {
    if (method != 'bank_transfer' ||
        !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(intentId) ||
        currency != 'VND' ||
        !RegExp(r'^\d{6}$').hasMatch(bankBin) ||
        !RegExp(r'^\d{6,19}$').hasMatch(accountNumber) ||
        !RegExp(r'^BK\d{19}$').hasMatch(transferContent) ||
        (qrPayload != null &&
            (qrPayload!.length > 512 ||
                !qrPayload!.startsWith('000201010212') ||
                !RegExp(r'6304[0-9A-F]{4}$').hasMatch(qrPayload!)))) {
      throw const FormatException('Invalid bank payment DTO');
    }
  }
  final String paymentId, intentId, requestId, paymentCode, status, method;
  final String intentStatus;
  final String reference, bankName, bankBin, accountNumber, accountName;
  final String transferContent, currency;
  final BigInt amountExpected, version, intentVersion;
  final DateTime expiresAt, serverTime;
  final bool available;
  final String? qrPayload;
  bool get ready =>
      available &&
      intentStatus == 'ready' &&
      status == 'awaiting_payment' &&
      qrPayload != null;

  bool matches(PaymentDto p) =>
      paymentId == p.paymentId &&
      requestId == p.requestId &&
      paymentCode == p.paymentCode &&
      version == p.version &&
      method == p.method &&
      status == p.status &&
      amountExpected == p.amountExpected &&
      currency == p.currency;

  static String _text(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.isEmpty)
      throw const FormatException('Invalid bank DTO');
    return value;
  }

  static BigInt _integer(Map<String, dynamic> row, String key) {
    final text = _text(row, key);
    if (!RegExp(r'^[0-9]+$').hasMatch(text))
      throw const FormatException('Invalid bank integer');
    final value = BigInt.parse(text);
    if (value <= BigInt.zero || value > BigInt.parse('9223372036854775807')) {
      throw const FormatException('Invalid bank integer');
    }
    return value;
  }
}
