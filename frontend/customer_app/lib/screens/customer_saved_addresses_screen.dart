import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/app_theme.dart';
import '../app/user_session.dart';
import '../services/customer_saved_address_service.dart';
import '../services/supabase_service.dart';
import '../widgets/customer_ui.dart';
import '../widgets/rescue_widgets.dart';

class CustomerSavedAddressesScreen extends StatefulWidget {
  const CustomerSavedAddressesScreen(
      {super.key,
      required this.controller,
      this.repository = const SupabaseCustomerSavedAddressRepository()});
  final AppController controller;
  final CustomerSavedAddressRepository repository;
  @override
  State<CustomerSavedAddressesScreen> createState() =>
      _CustomerSavedAddressesScreenState();
}

class _CustomerSavedAddressesScreenState
    extends State<CustomerSavedAddressesScreen> {
  List<CustomerSavedAddress> addresses = [];
  String? owner;
  String? error;
  bool loading = false;
  bool deleting = false;
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
      addresses = [];
      error = null;
      loading = false;
      deleting = false;
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
      mounted && generation == version && owner == UserSession.userId;
  Future<void> load() async {
    final version = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.repository.list();
      if (current(version)) setState(() => addresses = result);
    } catch (failure) {
      if (current(version))
        setState(() => error = failure is AppFailure
            ? failure.message
            : 'Không tải được danh sách địa chỉ. Vui lòng thử lại.');
    } finally {
      if (current(version)) setState(() => loading = false);
    }
  }

  Future<void> edit([CustomerSavedAddress? savedAddress]) async {
    final customer = owner;
    final result = await Navigator.of(context).push<CustomerSavedAddress>(
        MaterialPageRoute(
            builder: (_) => _AddressEditor(
                controller: widget.controller,
                repository: widget.repository,
                savedAddress: savedAddress)));
    if (!mounted || customer != UserSession.userId || result == null) return;
    setState(() {
      addresses = [result, ...addresses.where((item) => item.id != result.id)];
      error = null;
    });
    await load();
    if (!mounted || customer != UserSession.userId) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã lưu địa chỉ.')));
  }

  Future<void> remove(CustomerSavedAddress savedAddress) async {
    final customer = owner;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Xóa địa chỉ đã lưu?'),
                content: Text(
                    '${savedAddress.label} — ${savedAddress.address}\nĐịa chỉ này sẽ không còn trong danh sách chọn nhanh. Lịch sử yêu cầu cứu hộ vẫn được giữ.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Giữ lại')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error),
                      child: const Text('Xóa địa chỉ'))
                ]));
    if (!mounted || confirmed != true || customer != UserSession.userId) return;
    final version = ++generation;
    setState(() {
      deleting = true;
      error = null;
    });
    try {
      await widget.repository.delete(savedAddress.id);
      if (!current(version)) return;
      setState(
          () => addresses.removeWhere((item) => item.id == savedAddress.id));

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã xóa địa chỉ.')));
    } catch (failure) {
      if (current(version))
        setState(() => error = failure is AppFailure
            ? failure.message
            : 'Không xóa được địa chỉ. Vui lòng thử lại.');
    } finally {
      if (current(version)) setState(() => deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Địa chỉ đã lưu'), actions: [
        IconButton(
            tooltip: 'Tải lại danh sách địa chỉ',
            onPressed: owner == null || loading || deleting ? null : load,
            icon: const Icon(Icons.refresh_rounded))
      ]),
      body: SafeArea(
          top: false,
          child: owner == null
              ? const Center(
                  child: Text('Vui lòng đăng nhập để quản lý địa chỉ.'))
              : ListView(padding: AppSpacing.page, children: [
                  Text('Những địa điểm thường dùng',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (!loading && error == null)
                    Text('${addresses.length} địa chỉ đã lưu',
                        style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: loading || deleting ? null : () => edit(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Thêm địa chỉ')),
                  const SizedBox(height: 16),
                  if (loading || deleting) const LinearProgressIndicator(),
                  if (error != null)
                    InlineNotice(error!,
                        onRetry: loading || deleting ? null : load),
                  if (!loading && error == null && addresses.isEmpty)
                    const CustomerEmptyState(
                        icon: Icons.bookmark_border_rounded,
                        title: 'Chưa có địa chỉ đã lưu',
                        message: 'Thêm địa chỉ để chọn nhanh khi cần cứu hộ.'),
                  for (final item in addresses)
                    Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Icon(
                                        item.label == 'Nhà'
                                            ? Icons.home_outlined
                                            : Icons.bookmark_border_rounded,
                                        color: AppColors.navy),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(item.label,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium)),
                                  ]),
                                  const SizedBox(height: 8),
                                  Text(item.address),
                                  if (item.isDefault || item.latitude != null)
                                    Wrap(spacing: 8, children: [
                                      if (item.isDefault)
                                        const Chip(label: Text('Mặc định')),
                                      if (item.latitude != null)
                                        const Chip(label: Text('Có tọa độ')),
                                    ]),
                                  if (item.latitude != null)
                                    Text(
                                        'Tọa độ: ${item.latitude}, ${item.longitude}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  if (item.notes != null &&
                                      item.notes!.isNotEmpty)
                                    Text('Ghi chú: ${item.notes}'),
                                  const Divider(height: 16),
                                  Wrap(spacing: 8, children: [
                                    OutlinedButton.icon(
                                        onPressed: loading || deleting
                                            ? null
                                            : () => edit(item),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('Sửa địa chỉ')),
                                    TextButton.icon(
                                        onPressed: loading || deleting
                                            ? null
                                            : () => remove(item),
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Xóa'),
                                        style: TextButton.styleFrom(
                                            foregroundColor: AppColors.error)),
                                  ]),
                                ]))),
                ])));
}

class _AddressEditor extends StatefulWidget {
  const _AddressEditor(
      {required this.controller, required this.repository, this.savedAddress});
  final AppController controller;
  final CustomerSavedAddressRepository repository;
  final CustomerSavedAddress? savedAddress;
  @override
  State<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<_AddressEditor> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController brand;
  late final TextEditingController plate;
  late final TextEditingController color;
  late final TextEditingController notes;
  String label = 'Nhà';
  bool isDefault = false;
  late final String? owner;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    owner = UserSession.userId;
    final savedAddress = widget.savedAddress;
    label = savedAddress?.label ?? 'Nhà';
    isDefault = savedAddress?.isDefault ?? false;
    brand = TextEditingController(text: savedAddress?.address ?? '');
    plate =
        TextEditingController(text: savedAddress?.latitude?.toString() ?? '');
    color =
        TextEditingController(text: savedAddress?.longitude?.toString() ?? '');
    notes = TextEditingController(text: savedAddress?.notes ?? '');
    widget.controller.addListener(sessionChanged);
  }

  void sessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(sessionChanged);
    brand.dispose();
    plate.dispose();
    color.dispose();
    notes.dispose();
    super.dispose();
  }

  String? validateCoordinate(String text, String other, double limit) {
    if (text.trim().isEmpty && other.trim().isEmpty) return null;
    final value = double.tryParse(text.trim());
    if (value == null || !value.isFinite || value < -limit || value > limit)
      return 'Nhập cả vĩ độ và kinh độ hợp lệ hoặc để trống cả hai.';
    return null;
  }

  Future<void> save() async {
    if (saving ||
        owner == null ||
        owner != UserSession.userId ||
        !(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await widget.repository.save(
          id: widget.savedAddress?.id,
          label: label,
          address: brand.text,
          latitude: double.tryParse(plate.text.trim()),
          longitude: double.tryParse(color.text.trim()),
          notes: notes.text,
          isDefault: isDefault);
      if (!mounted || owner != UserSession.userId) return;
      Navigator.pop(context, result);
    } catch (failure) {
      if (!mounted || owner != UserSession.userId) return;
      setState(() => error = failure is AppFailure
          ? failure.message
          : 'Không lưu được địa chỉ. Thông tin đã nhập vẫn được giữ.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !saving,
      child: Scaffold(
          appBar: AppBar(
              title: Text(widget.savedAddress == null
                  ? 'Thêm địa chỉ'
                  : 'Sửa địa chỉ')),
          body: SafeArea(
              top: false,
              child: owner == null || owner != UserSession.userId
                  ? const Center(
                      child: Text(
                          'Phiên đăng nhập đã thay đổi. Vui lòng quay lại.'))
                  : Form(
                      key: formKey,
                      child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: AppSpacing.page,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const ScreenHeader('Thông tin địa chỉ',
                                    subtitle:
                                        'Lưu địa điểm để chọn nhanh khi cứu hộ'),
                                DropdownButtonFormField<String>(
                                    initialValue: label,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Tên gợi nhớ'),
                                    items: [
                                      'Nhà',
                                      'Công ty',
                                      'Trường học',
                                      'Khác'
                                    ]
                                        .map((value) => DropdownMenuItem(
                                            value: value, child: Text(value)))
                                        .toList(),
                                    onChanged: saving
                                        ? null
                                        : (value) =>
                                            setState(() => label = value!)),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: brand,
                                    enabled: !saving,
                                    maxLength: 1000,
                                    minLines: 2,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                        labelText: 'Địa chỉ',
                                        hintText:
                                            'Số nhà, đường, phường/xã, tỉnh/thành'),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Vui lòng nhập địa chỉ.'
                                            : null),
                                const SizedBox(height: 12),
                                SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Đặt làm mặc định'),
                                    value: isDefault,
                                    onChanged: saving
                                        ? null
                                        : (value) =>
                                            setState(() => isDefault = value)),
                                const SizedBox(height: 16),
                                const SectionTitle('Tọa độ',
                                    subtitle:
                                        'Tùy chọn. Để trống cả hai nếu chỉ dùng địa chỉ.'),
                                const SizedBox(height: 12),
                                TextFormField(
                                    controller: plate,
                                    enabled: !saving,
                                    maxLength: 30,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true, signed: true),
                                    decoration: const InputDecoration(
                                        labelText: 'Vĩ độ (tùy chọn)'),
                                    validator: (_) => validateCoordinate(
                                        plate.text, color.text, 90)),
                                const SizedBox(height: 12),
                                TextFormField(
                                    controller: color,
                                    enabled: !saving,
                                    maxLength: 50,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true, signed: true),
                                    decoration: const InputDecoration(
                                        labelText: 'Kinh độ (tùy chọn)'),
                                    validator: (_) => validateCoordinate(
                                        color.text, plate.text, 180)),
                                const SizedBox(height: 12),
                                TextFormField(
                                    controller: notes,
                                    enabled: !saving,
                                    maxLength: 1000,
                                    minLines: 2,
                                    maxLines: 5,
                                    decoration: const InputDecoration(
                                        labelText: 'Ghi chú (tùy chọn)')),
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
                                            : 'Lưu địa chỉ'))),
                              ]))))));
}
