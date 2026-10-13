/// GD2A/GD3 safe DTO. Money and versions stay lossless on Flutter web too.
class PaymentDto {
  PaymentDto.fromJson(Map<String, dynamic> row)
      : paymentId = _text(row, 'payment_id'),
        paymentCode = _text(row, 'payment_code'),
        requestId = _text(row, 'request_id'),
        assignmentId = _text(row, 'assignment_id'),
        quoteId = _text(row, 'quote_id'),
        amountExpected = _integer(row['amount_expected']),
        amountReceived = row['amount_received'] == null
            ? null
            : _integer(row['amount_received']),
        currency = _text(row, 'currency'),
        method = row['method'] as String?,
        status = _text(row, 'status'),
        version = _integer(row['version'], positive: true),
        createdAt = DateTime.parse(_text(row, 'created_at')),
        updatedAt = DateTime.parse(_text(row, 'updated_at')),
        paidAt = _date(row['paid_at']),
        cashReceivedAt = _date(row['cash_received_at']);

  final String paymentId, paymentCode, requestId, assignmentId, quoteId;
  final BigInt amountExpected, version;
  final BigInt? amountReceived;
  final String currency, status;
  final String? method;
  final DateTime createdAt, updatedAt;
  final DateTime? paidAt, cashReceivedAt;

  static String _text(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.isEmpty) {
      throw const FormatException('Invalid payment DTO');
    }
    return value;
  }

  static BigInt _integer(Object? value, {bool positive = false}) {
    // RPC contract explicitly serializes bigint as decimal strings.
    if (value is! String || !RegExp(r'^[0-9]+$').hasMatch(value)) {
      throw const FormatException('Invalid payment integer');
    }
    final parsed = BigInt.parse(value);
    if (parsed < (positive ? BigInt.one : BigInt.zero) ||
        parsed > BigInt.parse('9223372036854775807')) {
      throw const FormatException('Payment integer out of range');
    }
    return parsed;
  }

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
