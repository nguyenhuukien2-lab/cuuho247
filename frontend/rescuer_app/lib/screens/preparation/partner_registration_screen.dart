import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../services/partner_auth_validation.dart';
import '../../widgets/app_components.dart';

const partnerApprovalMessage =
    'Tài khoản đối tác cần được quản trị viên duyệt trước khi bật online và nhận đơn.';
const partnerSeparateAccountMessage =
    'Dùng tài khoản đối tác riêng với tài khoản khách hàng. Không dùng cùng tài khoản để tạo rồi tự nhận đơn.';

class PartnerRegistrationScreen extends StatefulWidget {
  const PartnerRegistrationScreen({super.key, required this.c});
  final RescuerController c;

  @override
  State<PartnerRegistrationScreen> createState() =>
      _PartnerRegistrationScreenState();
}

class _PartnerRegistrationScreenState extends State<PartnerRegistrationScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController(),
      _confirmation = TextEditingController();
  bool _agreed = false,
      _termsError = false,
      _submitting = false,
      _attempted = false;
  bool _confirmationRequired = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final valid = _form.currentState!.validate();
    setState(() => _termsError = !_agreed);
    if (!valid || !_agreed) return;
    setState(() {
      _submitting = true;
      _attempted = true;
    });
    final result = await widget.c.signUp(
      email: _email.text,
      password: _password.text,
      name: _name.text,
      phone: _phone.text,
    );
    if (!mounted) return;
    if (result == PartnerRegistration.profileReady) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _confirmationRequired =
          result == PartnerRegistration.confirmationRequired;
    });
    // Clear secrets when the account no longer needs to be submitted.
    if (_confirmationRequired || widget.c.signedIn) {
      _password.clear();
      _confirmation.clear();
    }
  }

  Future<void> _showTerms() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Điều khoản cơ bản'),
      content: const SingleChildScrollView(
        child: Text(
          'Cung cấp thông tin và giấy tờ chính xác để xét duyệt. '
          'Chỉ bật online, nhận đơn khi hồ sơ, xe và dịch vụ được duyệt. '
          'Chỉ dùng thông tin khách hàng để hỗ trợ chuyến đã nhận. '
          'Dùng tài khoản đối tác riêng và không tự nhận yêu cầu do cùng tài khoản tạo.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.c,
    builder: (context, _) => PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đăng ký đối tác'),
          automaticallyImplyLeading: !_submitting,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Tài khoản đối tác Cứu Hộ 24/7',
                  style: AppType.pageTitle,
                ),
                const SizedBox(height: 12),
                const Text(partnerSeparateAccountMessage, style: AppType.body),
                const SizedBox(height: 16),
                const InfoBanner(
                  title: 'Cần duyệt trước khi nhận đơn',
                  message: partnerApprovalMessage,
                  icon: Icons.verified_user_outlined,
                ),
                const SizedBox(height: 20),
                if (_confirmationRequired) ...[
                  const Text(
                    'Xác nhận email để tiếp tục',
                    style: AppType.section,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Kiểm tra email xác nhận từ hệ thống, kể cả thư rác. Sau khi xác nhận, đăng nhập bằng tài khoản đối tác vừa đăng ký để tạo và hoàn thiện hồ sơ.',
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Quay lại đăng nhập',
                    onPressed: () => Navigator.pop(context),
                  ),
                ] else if (widget.c.signedIn && !_submitting) ...[
                  const Text(
                    'Tiếp tục hoàn thiện hồ sơ',
                    style: AppType.section,
                  ),
                  if (widget.c.error != null) ...[
                    const SizedBox(height: 12),
                    InfoBanner(
                      title: 'Chưa hoàn tất hồ sơ',
                      message: widget.c.error!,
                      tone: BadgeTone.red,
                    ),
                  ],
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Hoàn thiện hồ sơ đối tác',
                    onPressed: () => Navigator.pop(context),
                  ),
                ] else
                  AppCard(
                    child: Form(
                      key: _form,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              key: const ValueKey('register-name'),
                              controller: _name,
                              enabled: !_submitting,
                              maxLength: 150,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                labelText: 'Họ tên',
                              ),
                              validator: partnerNameError,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const ValueKey('register-phone'),
                              controller: _phone,
                              enabled: !_submitting,
                              keyboardType: TextInputType.phone,
                              autofillHints: const [
                                AutofillHints.telephoneNumber,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Số điện thoại',
                              ),
                              validator: partnerPhoneError,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const ValueKey('register-email'),
                              controller: _email,
                              enabled: !_submitting,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              validator: partnerEmailError,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const ValueKey('register-password'),
                              controller: _password,
                              enabled: !_submitting,
                              obscureText: true,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: const InputDecoration(
                                labelText: 'Mật khẩu',
                                helperText: 'Ít nhất 8 ký tự',
                              ),
                              validator: partnerPasswordError,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const ValueKey('register-confirmation'),
                              controller: _confirmation,
                              enabled: !_submitting,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Xác nhận mật khẩu',
                              ),
                              validator: (value) =>
                                  value != null &&
                                      value.isNotEmpty &&
                                      value == _password.text
                                  ? null
                                  : 'Mật khẩu xác nhận không khớp',
                            ),
                            const SizedBox(height: 12),
                            CheckboxListTile(
                              key: const ValueKey('register-terms'),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _agreed,
                              title: const Text('Tôi đồng ý điều khoản cơ bản'),
                              onChanged: _submitting
                                  ? null
                                  : (value) => setState(() {
                                      _agreed = value == true;
                                      _termsError = !_agreed;
                                    }),
                            ),
                            if (_termsError)
                              const Text(
                                'Bạn cần đồng ý điều khoản cơ bản',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            TextButton(
                              onPressed: _showTerms,
                              child: const Text('Xem điều khoản cơ bản'),
                            ),
                            if (_attempted && widget.c.error != null) ...[
                              const SizedBox(height: 12),
                              InfoBanner(
                                title: 'Chưa thể đăng ký',
                                message: widget.c.error!,
                                tone: BadgeTone.red,
                              ),
                            ],
                            const SizedBox(height: 20),
                            AppButton(
                              key: const ValueKey('register-submit'),
                              label: 'Tạo tài khoản đối tác',
                              icon: Icons.person_add_alt_1_outlined,
                              loading: _submitting,
                              onPressed: _submitting || widget.c.working
                                  ? null
                                  : _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
