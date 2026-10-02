import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/app_theme.dart';
import '../../widgets/app_components.dart';
import '../onboarding/onboarding_screens.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});
  final AppState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final contact = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool submitting = false;
  String? message;

  @override
  void dispose() {
    contact.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      submitting = true;
      message = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      submitting = false;
      message = 'Đăng nhập chưa khả dụng khi dịch vụ xác thực chưa kết nối.';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    body: SafeArea(
      child: Form(
        key: formKey,
        child: ScreenContent(
          bottomAction: AppButton(
            label: 'Đăng nhập',
            icon: Icons.login_rounded,
            loading: submitting,
            onPressed: submit,
          ),
          children: [
            const Center(child: BrandMark(size: 68)),
            const Column(
              children: [
                Text(
                  'Chào mừng đối tác',
                  textAlign: TextAlign.center,
                  style: AppType.pageTitle,
                ),
                SizedBox(height: 6),
                Text(
                  'Đăng nhập để tiếp tục sử dụng ứng dụng.',
                  textAlign: TextAlign.center,
                  style: AppType.body,
                ),
              ],
            ),
            AppTextField(
              controller: contact,
              label: 'Số điện thoại hoặc email',
              icon: Icons.person_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập số điện thoại hoặc email'
                  : null,
            ),
            AppTextField(
              controller: password,
              label: 'Mật khẩu',
              icon: Icons.lock_outline_rounded,
              obscureText: obscure,
              suffixIcon: IconButton(
                tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Vui lòng nhập mật khẩu'
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ForgotPasswordScreen(state: widget.state),
                  ),
                ),
                child: const Text('Quên mật khẩu?'),
              ),
            ),
            if (message != null)
              InfoBanner(
                title: 'Chưa thể đăng nhập',
                message: message!,
                icon: Icons.cloud_off_outlined,
                tone: BadgeTone.orange,
              ),
            const Divider(height: 8),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Bạn muốn trở thành đối tác? ',
                    style: AppType.body,
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            RegistrationProgressScreen(state: widget.state),
                      ),
                    ),
                    child: const Text('Đăng ký đối tác'),
                  ),
                ],
              ),
            ),
            const Center(
              child: Text('Dành cho đối tác cứu hộ', style: AppType.caption),
            ),
          ],
        ),
      ),
    ),
  );
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final formKey = GlobalKey<FormState>();
  final contact = TextEditingController();
  bool submitting = false;
  String? error;

  @override
  void dispose() {
    contact.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      submitting = true;
      error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      submitting = false;
      error = 'Chưa thể gửi yêu cầu khi dịch vụ xác thực chưa kết nối.';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Khôi phục mật khẩu')),
    body: SafeArea(
      child: Form(
        key: formKey,
        child: ScreenContent(
          bottomAction: AppButton(
            label: 'Gửi yêu cầu',
            icon: Icons.send_outlined,
            loading: submitting,
            onPressed: submit,
          ),
          children: [
            const PageHeading(
              title: 'Quên mật khẩu?',
              subtitle: 'Nhập số điện thoại hoặc email đã đăng ký để tiếp tục.',
            ),
            AppTextField(
              controller: contact,
              label: 'Số điện thoại hoặc email',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập thông tin tài khoản'
                  : null,
            ),
            if (error != null)
              InfoBanner(
                title: 'Dịch vụ chưa khả dụng',
                message: error!,
                icon: Icons.error_outline_rounded,
                tone: BadgeTone.red,
              ),
          ],
        ),
      ),
    ),
  );
}
