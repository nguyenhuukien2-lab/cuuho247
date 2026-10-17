import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/partner_email_confirmation.dart';
import '../../services/partner_auth_validation.dart';

class PartnerEmailConfirmationScreen extends StatefulWidget {
  const PartnerEmailConfirmationScreen({super.key, required this.confirmation});
  final PartnerEmailConfirmation confirmation;
  @override
  State<PartnerEmailConfirmationScreen> createState() =>
      _PartnerEmailConfirmationScreenState();
}

class _PartnerEmailConfirmationScreenState
    extends State<PartnerEmailConfirmationScreen> {
  final _digits = List.generate(6, (_) => TextEditingController());
  final _focus = List.generate(6, (_) => FocusNode());
  final _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool get _complete =>
      _digits.every((digit) => RegExp(r'^[0-9]$').hasMatch(digit.text));

  void _clearCode() {
    for (final digit in _digits) {
      digit.clear();
    }
  }

  void _changed(int index, String value) {
    if (value.length > 1) {
      final start = value.length == 6 ? 0 : index;
      if (start == 0) _clearCode();
      for (var i = 0; i < value.length && start + i < 6; i++) {
        _digits[start + i].text = value[i];
      }
      _focus[(start + value.length).clamp(0, 5)].requestFocus();
    } else if (value.isNotEmpty && index < 5) {
      _focus[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focus[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_complete || widget.confirmation.busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final pending = widget.confirmation.verify(
      _digits.map((digit) => digit.text).join(),
    );
    setState(_clearCode);
    await pending;
    if (mounted &&
        widget.confirmation.stage != EmailConfirmationStage.verified) {
      _focus.first.requestFocus();
    }
  }

  @override
  void dispose() {
    _clearCode();
    for (final digit in _digits) {
      digit.dispose();
    }
    for (final focus in _focus) {
      focus.dispose();
    }
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.confirmation,
    builder: (context, _) {
      final c = widget.confirmation;
      final verified = c.stage == EmailConfirmationStage.verified;
      final needsEmail = partnerEmailError(c.email) != null;
      return PopScope(
        canPop: !c.busy,
        child: Scaffold(
          appBar: AppBar(title: const Text('Xác nhận email')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Icon(
                    verified
                        ? Icons.mark_email_read_outlined
                        : Icons.password_rounded,
                    size: 64,
                    color: const Color(0xFFF97316),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    verified ? 'Xác nhận email thành công' : 'Nhập mã xác nhận',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text('Cứu Hộ 24/7 · Dành cho Đối tác cứu hộ'),
                  const SizedBox(height: 16),
                  if (!needsEmail) ...[
                    Text(
                      c.maskedEmail,
                      key: const ValueKey('masked-confirmation-email'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (c.message != null) ...[
                    Semantics(liveRegion: true, child: Text(c.message!)),
                    const SizedBox(height: 16),
                  ],
                  if (verified)
                    FilledButton(
                      onPressed: c.dismiss,
                      child: const Text('Tiếp tục hoàn thiện hồ sơ đối tác'),
                    )
                  else if (needsEmail) ...[
                    Form(
                      key: _form,
                      child: TextFormField(
                        key: const ValueKey('confirmation-email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        validator: partnerEmailError,
                        decoration: const InputDecoration(
                          labelText: 'Email đã đăng ký',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        if (_form.currentState!.validate()) {
                          c.waitFor(_email.text);
                          FocusManager.instance.primaryFocus?.unfocus();
                        }
                      },
                      child: const Text('Tiếp tục'),
                    ),
                  ] else ...[
                    const Text(
                      'Nhập mã gồm 6 chữ số trong email. Kiểm tra cả hộp thư rác và chỉ sử dụng mã mới nhất.',
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        for (var i = 0; i < 6; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: Semantics(
                              label: 'Chữ số ${i + 1} trên 6',
                              child: TextField(
                                key: ValueKey('email-otp-$i'),
                                controller: _digits[i],
                                focusNode: _focus[i],
                                enabled: !c.busy && !c.canRetryVerification,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                                autocorrect: false,
                                enableSuggestions: false,
                                enableIMEPersonalizedLearning: false,
                                autofillHints: i == 0
                                    ? const [AutofillHints.oneTimeCode]
                                    : null,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 2,
                                  ),
                                ),
                                onChanged: (value) => _changed(i, value),
                                onSubmitted: (_) {
                                  if (_complete) _submit();
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (c.busy) ...[
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      key: const ValueKey('verify-email-otp'),
                      onPressed: !c.busy && _complete && !c.canRetryVerification
                          ? _submit
                          : null,
                      child: Text(
                        c.stage == EmailConfirmationStage.verifying
                            ? 'Đang xác nhận…'
                            : 'XÁC NHẬN',
                      ),
                    ),
                    if (c.canRetryVerification)
                      OutlinedButton(
                        onPressed: c.busy ? null : c.retryVerification,
                        child: const Text('Thử lại kết nối'),
                      ),
                    TextButton(
                      key: const ValueKey('resend-email-otp'),
                      onPressed: c.busy || c.resendSecondsRemaining > 0
                          ? null
                          : () {
                              setState(_clearCode);
                              c.resend();
                            },
                      child: Text(c.sending ? 'Đang gửi mã…' : 'Gửi lại mã'),
                    ),
                    if (c.resendSecondsRemaining > 0)
                      Text(
                        'Có thể gửi lại mã sau ${c.resendSecondsRemaining}s',
                        key: const ValueKey('email-otp-countdown'),
                      ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Xác nhận email không đồng nghĩa với việc hồ sơ đối tác đã được phê duyệt. Bạn chỉ được Online và nhận yêu cầu cứu hộ sau khi được quản trị viên xét duyệt.',
                  ),
                  if (!verified)
                    TextButton(
                      onPressed: c.busy ? null : c.dismiss,
                      child: const Text('Quay lại đăng nhập'),
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
