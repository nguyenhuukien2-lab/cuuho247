import '../core/utils/display_code.dart';
import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/app_theme.dart';
import '../app/user_session.dart';
import '../services/customer_profile_service.dart';
import '../services/supabase_service.dart';
import 'customer_ui.dart';
import 'account_ui.dart';

class CustomerProfileCard extends StatefulWidget {
  const CustomerProfileCard(
      {super.key,
      required this.controller,
      this.royal = false,
      this.vehicleCount,
      this.completedCount,
      this.repository = const SupabaseCustomerProfileRepository()});
  final AppController controller;
  final bool royal;
  final int? vehicleCount, completedCount;
  final CustomerProfileRepository repository;
  @override
  State<CustomerProfileCard> createState() => _CustomerProfileCardState();
}

class _CustomerProfileCardState extends State<CustomerProfileCard> {
  CustomerProfile? profile;
  String? owner, error;
  bool loading = false, saved = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    owner = UserSession.userId;
    widget.controller.addListener(sessionChanged);
    if (owner != null) load();
  }

  void sessionChanged() {
    if (owner == UserSession.userId) return;
    generation++;
    setState(() {
      owner = UserSession.userId;
      profile = null;
      error = null;
      loading = false;
      saved = false;
    });
    if (owner != null) load();
  }

  @override
  void dispose() {
    generation++;
    widget.controller.removeListener(sessionChanged);
    super.dispose();
  }

  bool current(int version) =>
      mounted && version == generation && owner == UserSession.userId;
  Future<void> load() async {
    final version = ++generation;
    setState(() {
      loading = true;
      error = null;
      saved = false;
    });
    try {
      final result = await widget.repository.load();
      if (!current(version) || result.userId != owner) return;
      setState(() => profile = result);
      widget.controller.applyCustomerProfile(result);
    } catch (failure) {
      if (current(version))
        setState(() => error = failure is AppFailure
            ? failure.message
            : 'Không tải được hồ sơ. Vui lòng thử lại.');
    } finally {
      if (current(version)) setState(() => loading = false);
    }
  }

  Future<void> edit() async {
    final data = profile;
    final customer = owner;
    if (data == null) return;
    final result = await Navigator.of(context).push<CustomerProfile>(
        MaterialPageRoute(
            builder: (_) => _ProfileEditor(
                controller: widget.controller,
                repository: widget.repository,
                profile: data)));
    if (!mounted ||
        customer != UserSession.userId ||
        result == null ||
        result.userId != customer) return;
    generation++;
    setState(() {
      profile = result;
      saved = true;
      error = null;
    });
    widget.controller.applyCustomerProfile(result);
  }

  @override
  Widget build(BuildContext context) {
    final data = profile;
    final name = displayCustomerName(data?.fullName ?? UserSession.fullName);
    if (widget.royal && owner != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CustomerAccountHeaderCard(
            name: name,
            phone: data?.phone ?? UserSession.phoneNumber,
            email: data?.email ?? UserSession.email,
            onEdit: data != null && !loading ? edit : null,
            onReload: data != null && !loading ? load : null,
            vehicleCount: widget.vehicleCount,
            completedCount: widget.completedCount),
        if (loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const Text('Đang tải hồ sơ…')
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          InlineNotice(error!, onRetry: loading ? null : load)
        ],
        if (saved)
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Đã lưu thông tin cá nhân.',
                  style: TextStyle(color: AppColors.success))),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (owner == null)
        CustomerEmptyState(
            icon: Icons.person_outline_rounded,
            title: 'Hồ sơ khách hàng',
            message: 'Đăng nhập để xem và cập nhật thông tin của bạn.',
            action: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                icon: const Icon(Icons.login),
                label: const Text('Đăng nhập / Đăng ký')))
      else ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.selected,
              child: Text(name.isEmpty ? '?' : name.substring(0, 1),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Mã khách hàng: ${displayCode(data?.customerCode)}',
                    style: const TextStyle(color: AppColors.muted)),
                Text(name.isEmpty ? 'Thông tin cá nhân' : name,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                    data?.phone?.isNotEmpty == true
                        ? data!.phone!
                        : 'Chưa cập nhật số điện thoại',
                    style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(
                    data?.email ??
                        UserSession.email ??
                        'Chưa có email đăng nhập',
                    style: const TextStyle(color: AppColors.muted)),
              ])),
        ]),
        if (loading) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text('Đang tải hồ sơ…')
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          InlineNotice(error!, onRetry: loading ? null : load)
        ],
        if (saved)
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Đã lưu thông tin cá nhân.',
                  style: TextStyle(color: AppColors.success))),
        if (data != null && !loading) ...[
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: edit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Chỉnh sửa thông tin'))),
            const SizedBox(width: 8),
            IconButton(
                tooltip: 'Tải lại hồ sơ',
                onPressed: load,
                icon: const Icon(Icons.refresh)),
          ]),
        ],
      ],
    ]);
  }
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor(
      {required this.controller,
      required this.repository,
      required this.profile});
  final AppController controller;
  final CustomerProfileRepository repository;
  final CustomerProfile profile;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name, phone;
  late final String? owner;
  bool saving = false;
  String? error;
  int generation = 0;
  bool get currentSession => owner != null && owner == UserSession.userId;
  @override
  void initState() {
    super.initState();
    owner = UserSession.userId;
    name = TextEditingController(text: widget.profile.fullName);
    phone = TextEditingController(text: widget.profile.phone ?? '');
    widget.controller.addListener(sessionChanged);
  }

  void sessionChanged() {
    if (!currentSession) generation++;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    generation++;
    widget.controller.removeListener(sessionChanged);
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving ||
        !currentSession ||
        !(formKey.currentState?.validate() ?? false)) return;
    final version = ++generation;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result =
          await widget.repository.save(fullName: name.text, phone: phone.text);
      if (!mounted ||
          !currentSession ||
          version != generation ||
          result.userId != owner) return;
      Navigator.pop(context, result);
    } catch (failure) {
      if (mounted && currentSession && version == generation)
        setState(() => error = failure is AppFailure
            ? failure.message
            : 'Không lưu được hồ sơ. Thông tin đã nhập vẫn được giữ.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !saving,
      child: Scaffold(
          appBar: AppBar(title: const Text('Chỉnh sửa thông tin')),
          body: SafeArea(
              top: false,
              child: !currentSession
                  ? const Center(
                      child: Text(
                          'Phiên đăng nhập đã thay đổi. Vui lòng quay lại.'))
                  : Form(
                      key: formKey,
                      child: SingleChildScrollView(
                          padding: AppSpacing.page,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const ScreenHeader('Thông tin cá nhân',
                                    subtitle:
                                        'Cập nhật tên và số điện thoại liên hệ'),
                                TextFormField(
                                    controller: name,
                                    enabled: !saving,
                                    maxLength: 100,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                        labelText: 'Họ tên',
                                        prefixIcon: Icon(Icons.person_outline)),
                                    validator: (value) =>
                                        validateCustomerName(value ?? '')),
                                const SizedBox(height: 12),
                                TextFormField(
                                    controller: phone,
                                    enabled: !saving,
                                    maxLength: 30,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                        labelText: 'Số điện thoại',
                                        prefixIcon: Icon(Icons.phone_outlined),
                                        helperText:
                                            'Có thể để trống nếu chưa cập nhật.'),
                                    validator: (value) =>
                                        validateCustomerPhone(value ?? '')),
                                const SizedBox(height: 16),
                                InfoRow(
                                    'Email đăng nhập',
                                    widget.profile.email ??
                                        'Chưa có email đăng nhập'),
                                const Text('Email không thể chỉnh sửa tại đây.',
                                    style: TextStyle(
                                        fontSize: 13, color: AppColors.muted)),
                                if (widget.profile.accountCreatedAt != null)
                                  InfoRow(
                                      'Ngày tạo tài khoản',
                                      customerDate(
                                          widget.profile.accountCreatedAt!)),
                                const SizedBox(height: 24),
                                if (error != null) ...[
                                  InlineNotice(error!),
                                  const SizedBox(height: 12)
                                ],
                                SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                        onPressed: saving ? null : save,
                                        icon: saving
                                            ? const SizedBox.square(
                                                dimension: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2))
                                            : const Icon(Icons.check_rounded),
                                        label: Text(saving
                                            ? 'Đang lưu…'
                                            : 'Lưu thay đổi'))),
                                TextButton(
                                    onPressed: saving
                                        ? null
                                        : () => Navigator.pop(context),
                                    child: const Text('Hủy chỉnh sửa')),
                              ]))))));
}
