import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/app_controller.dart';
import '../services/supabase_service.dart';
import '../widgets/rescue_widgets.dart';
import '../widgets/customer_ui.dart';

class NewAuthScreen extends StatefulWidget {
  const NewAuthScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<NewAuthScreen> createState() => _NewAuthScreenState();
}

class _NewAuthScreenState extends State<NewAuthScreen> {
  final formKey = GlobalKey<FormState>();
  final phone = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final email = TextEditingController();
  bool register = false;
  bool loading = false;
  bool obscure = true;
  String? errorMessage;

  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    name.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (loading) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => loading = true);
    try {
      if (register) {
        final result = await SupabaseService.signUp(
          email: email.text.trim(),
          password: password.text,
          fullName: name.text.trim(),
          phone: phone.text.trim(),
        );
        if (!mounted) return;
        if (result.needsEmailConfirmation) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Đã đăng ký. Hãy xác nhận email trước khi đăng nhập.')));
          setState(() => register = false);
          return;
        }
      } else {
        await SupabaseService.signIn(
            email: email.text.trim(), password: password.text);
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              register ? 'Đăng ký thành công.' : 'Đăng nhập thành công.')));
    } on AppFailure catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = error.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: SingleChildScrollView(
                padding: AppSpacing.page,
                child: Form(
                    key: formKey,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                              onPressed: () => Navigator.canPop(context)
                                  ? Navigator.pop(context)
                                  : Navigator.pushReplacementNamed(
                                      context, '/'),
                              icon: const Icon(Icons.arrow_back_rounded)),
                          const SizedBox(height: 16),
                          Row(children: [
                            Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    color: AppColors.navy,
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Icon(
                                    Icons.health_and_safety_rounded,
                                    color: Colors.white)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text('Cứu Hộ 24/7',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall)),
                          ]),
                          const SizedBox(height: 24),
                          SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                    value: false, label: Text('Đăng nhập')),
                                ButtonSegment(
                                    value: true, label: Text('Đăng ký'))
                              ],
                              selected: {
                                register
                              },
                              showSelectedIcon: false,
                              onSelectionChanged: (value) =>
                                  setState(() => register = value.first)),
                          const SizedBox(height: 22),
                          if (!widget.controller.backendConfigured) ...[
                            const Text(
                                'Đăng nhập đang tạm thời chưa khả dụng. Vui lòng thử lại sau.',
                                style: TextStyle(color: AppColors.error)),
                            const SizedBox(height: 12),
                          ],
                          AnimatedSwitcher(
                              duration: customerMotion(context),
                              child: register
                                  ? Column(
                                      key: const ValueKey('register'),
                                      children: [
                                          TextFormField(
                                              controller: name,
                                              enabled: !loading,
                                              textInputAction:
                                                  TextInputAction.next,
                                              decoration: const InputDecoration(
                                                  labelText: 'Họ và tên',
                                                  prefixIcon: Icon(Icons
                                                      .person_outline_rounded)),
                                              validator: (value) => register &&
                                                      (value == null ||
                                                          value.trim().isEmpty)
                                                  ? 'Vui lòng nhập họ tên'
                                                  : null),
                                          const SizedBox(height: 12),
                                          const SizedBox.shrink()
                                        ])
                                  : const SizedBox.shrink(
                                      key: ValueKey('login'))),
                          TextFormField(
                              controller: email,
                              enabled: !loading,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined)),
                              validator: (value) =>
                                  value == null || !value.contains('@')
                                      ? 'Vui lòng nhập email hợp lệ'
                                      : null),
                          const SizedBox(height: 12),
                          if (register) ...[
                            TextFormField(
                                controller: phone,
                                enabled: !loading,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                    labelText: 'Số điện thoại',
                                    prefixIcon: Icon(Icons.phone_outlined)),
                                validator: (value) =>
                                    value == null || value.trim().length < 9
                                        ? 'Vui lòng nhập số điện thoại hợp lệ'
                                        : null),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                              controller: password,
                              enabled: !loading,
                              obscureText: obscure,
                              decoration: InputDecoration(
                                  labelText: 'Mật khẩu',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => obscure = !obscure),
                                      icon: Icon(obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined))),
                              validator: (value) =>
                                  value == null || value.length < 6
                                      ? 'Mật khẩu cần ít nhất 6 ký tự'
                                      : null),
                          const SizedBox(height: 12),
                          const SizedBox(height: 24),
                          if (errorMessage != null) ...[
                            InlineNotice(errorMessage!,
                                onRetry: loading ? null : submit),
                            const SizedBox(height: 12),
                          ],
                          PrimaryButton(
                              label: register ? 'Tạo tài khoản' : 'Đăng nhập',
                              icon: register
                                  ? Icons.person_add_alt_1_rounded
                                  : Icons.login_rounded,
                              loading: loading,
                              onPressed: widget.controller.backendConfigured
                                  ? submit
                                  : null),
                          const SizedBox(height: 14),
                          Center(
                              child: TextButton(
                                  onPressed: () =>
                                      Navigator.pushNamedAndRemoveUntil(
                                          context, '/', (route) => false),
                                  child: const Text(
                                      'Tiếp tục sử dụng không cần đăng nhập'))),
                        ])))),
      );
}
