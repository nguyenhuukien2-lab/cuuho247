import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/partner_auth_validation.dart';
import '../services/partner_email_auth.dart';

enum EmailConfirmationStage {
  idle,
  waiting,
  verifying,
  verified,
  invalid,
  expired,
  networkError,
}

const incorrectEmailOtp =
    'Mã xác nhận không chính xác. Vui lòng kiểm tra và thử lại.';
const expiredEmailOtp = 'Mã xác nhận đã hết hạn. Vui lòng yêu cầu mã mới.';
const newConfirmationCodeSent =
    'Mã xác nhận mới đã được gửi đến email của bạn.';

class PartnerEmailConfirmation extends ChangeNotifier {
  PartnerEmailConfirmation(
    this.auth, {
    required this.onVerified,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final PartnerEmailAuth auth;
  final Future<void> Function() onVerified;
  final DateTime Function() _now;
  EmailConfirmationStage stage = EmailConfirmationStage.idle;
  String? email, message;
  bool sending = false;
  DateTime? _resendAfter, _sentAt;
  Timer? _countdown;
  bool _otpAccepted = false, _disposed = false;
  int _generation = 0;
  bool get active => stage != EmailConfirmationStage.idle;
  bool get busy => sending || stage == EmailConfirmationStage.verifying;
  bool get canRetryVerification =>
      _otpAccepted && stage == EmailConfirmationStage.networkError;
  String get maskedEmail => maskPartnerEmail(email);
  int get resendSecondsRemaining {
    final milliseconds = _resendAfter?.difference(_now()).inMilliseconds ?? 0;
    return milliseconds <= 0 ? 0 : ((milliseconds + 999) ~/ 1000).clamp(0, 60);
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  void _startCountdown() {
    _countdown?.cancel();
    if (resendSecondsRemaining == 0) return;
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || resendSecondsRemaining == 0) _countdown?.cancel();
      if (!_disposed) notifyListeners();
    });
  }

  void _codeWasSent() {
    _sentAt = _now();
    _resendAfter = _now().add(const Duration(seconds: 60));
    _startCountdown();
  }

  void waitFor(String value, {bool codeSent = false}) {
    if (_disposed || busy) return;
    _generation++;
    email = value.trim();
    message = null;
    _otpAccepted = false;
    _sentAt = null;
    stage = EmailConfirmationStage.waiting;
    if (codeSent) _codeWasSent();
    _startCountdown();
    notifyListeners();
  }

  Future<void> verify(String code) async {
    if (_disposed || busy) return;
    if (partnerEmailError(email) != null) {
      message = 'Vui lòng nhập email đã đăng ký.';
      notifyListeners();
      return;
    }
    if (!_otpAccepted && !RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      stage = EmailConfirmationStage.invalid;
      message = incorrectEmailOtp;
      notifyListeners();
      return;
    }
    final generation = ++_generation;
    stage = EmailConfirmationStage.verifying;
    message = null;
    notifyListeners();
    try {
      // The submitted code is only an argument; never store or log it.
      if (!_otpAccepted) {
        await auth.verifyEmailOtp(email!, code);
        if (!_current(generation)) return;
        _otpAccepted = true;
      }
      if (!await auth.refreshEmailVerification() ||
          auth.accountEmail?.trim().toLowerCase() != email!.toLowerCase()) {
        throw const AuthException('Email not verified');
      }
      if (!_current(generation)) return;
      await onVerified();
      if (!_current(generation)) return;
      _countdown?.cancel();
      stage = EmailConfirmationStage.verified;
      message = 'Email đã được xác nhận. Tiếp tục hoàn thiện hồ sơ đối tác.';
    } catch (error) {
      if (!_current(generation)) return;
      if (error is AuthException &&
          error is! AuthRetryableFetchException &&
          error.statusCode != '429' &&
          !(error.statusCode?.startsWith('5') ?? false)) {
        // Auth may use otp_expired for BOTH invalid and expired codes. The local
        // window chooses wording only; Supabase alone accepts/rejects the OTP.
        final elapsed =
            _sentAt != null &&
            !_now().isBefore(_sentAt!.add(partnerEmailOtpLifetime));
        final explicitlyExpired =
            error.code == 'otp_expired' &&
            error.message.toLowerCase().contains('expired') &&
            !error.message.toLowerCase().contains('invalid');
        final expired =
            error.code == 'otp_expired' && (elapsed || explicitlyExpired);
        stage = expired
            ? EmailConfirmationStage.expired
            : EmailConfirmationStage.invalid;
        message = expired ? expiredEmailOtp : incorrectEmailOtp;
      } else if (error is AuthException && error.statusCode == '429') {
        stage = EmailConfirmationStage.waiting;
        message = 'Bạn xác nhận quá nhanh. Vui lòng chờ một lúc rồi thử lại.';
      } else {
        stage = EmailConfirmationStage.networkError;
        message =
            'Không thể kết nối để xác nhận email. Kiểm tra mạng rồi thử lại.';
      }
    }
    if (_current(generation)) notifyListeners();
  }

  Future<void> retryVerification() async {
    // If verifyOTP succeeded but getUser was offline, retry only getUser.
    if (canRetryVerification) await verify('');
  }

  Future<void> resend() async {
    if (_disposed || busy) return;
    if (partnerEmailError(email) != null) {
      message = 'Vui lòng nhập email đã đăng ký.';
      notifyListeners();
      return;
    }
    if (resendSecondsRemaining > 0) return;
    final generation = _generation;
    sending = true;
    message = null;
    notifyListeners();
    try {
      await auth.resendEmailConfirmation(email!);
      if (!_current(generation)) return;
      _otpAccepted = false;
      _codeWasSent();
      stage = EmailConfirmationStage.waiting;
      message = newConfirmationCodeSent;
    } catch (error) {
      if (!_current(generation)) return;
      if (error is AuthException &&
          (error.statusCode == '429' ||
              error.code == 'over_email_send_rate_limit')) {
        _resendAfter = _now().add(const Duration(seconds: 60));
        _startCountdown();
        message =
            'Bạn gửi yêu cầu quá nhanh. Vui lòng chờ một phút rồi thử lại.';
      } else {
        message = 'Chưa thể gửi mã xác nhận. Kiểm tra kết nối và thử lại sau.';
      }
    } finally {
      if (_current(generation)) {
        sending = false;
        notifyListeners();
      }
    }
  }

  void dismiss() {
    if (_disposed || busy) return;
    _generation++;
    _countdown?.cancel();
    stage = EmailConfirmationStage.idle;
    _otpAccepted = false;
    message = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _countdown?.cancel();
    super.dispose();
  }
}
