const partnerEmailOtpLength = 6;
const partnerEmailOtpLifetime = Duration(
  seconds: int.fromEnvironment(
    'PARTNER_EMAIL_OTP_EXPIRY_SECONDS',
    defaultValue: 3600,
  ),
);

String maskPartnerEmail(String? email) {
  final parts = email?.trim().split('@');
  if (parts == null || parts.length != 2 || parts.first.isEmpty) return '';
  return '${parts.first.substring(0, 1)}***@${parts.last}';
}

/// Display only: Asia/Ho_Chi_Minh is UTC+07:00, without daylight saving.
/// Never use this client-provided string as a business/database timestamp.
String partnerRegistrationTime(DateTime instant) {
  final vn = instant.toUtc().add(const Duration(hours: 7));
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(vn.hour)}:${two(vn.minute)} - '
      '${two(vn.day)}/${two(vn.month)}/${vn.year}';
}

abstract interface class PartnerEmailAuth {
  String? get accountEmail;
  bool get emailVerified;
  Future<void> verifyEmailOtp(String email, String code);

  /// Fetch the user from Auth after verifyOTP, rather than trusting UI state.
  Future<bool> refreshEmailVerification();
  Future<void> resendEmailConfirmation(String email);
}
