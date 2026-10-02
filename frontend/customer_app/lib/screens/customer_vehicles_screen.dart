import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/app_theme.dart';
import '../app/user_session.dart';
import '../services/customer_vehicle_service.dart';
import '../services/supabase_service.dart';
import '../widgets/rescue_widgets.dart';
import '../widgets/customer_ui.dart';

class CustomerVehiclesScreen extends StatefulWidget {
  const CustomerVehiclesScreen(
      {super.key,
      required this.controller,
      this.repository = const SupabaseCustomerVehicleRepository()});
  final AppController controller;
  final CustomerVehicleRepository repository;
  @override
  State<CustomerVehiclesScreen> createState() => _CustomerVehiclesScreenState();
}

class _CustomerVehiclesScreenState extends State<CustomerVehiclesScreen> {
  List<CustomerVehicle> vehicles = [];
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
      vehicles = [];
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
      if (current(version)) setState(() => vehicles = result);
    } catch (failure) {
      if (current(version))
        setState(() => error = failure is AppFailure
            ? failure.message
            : 'Không tải được danh sách xe. Vui lòng thử lại.');
    } finally {
      if (current(version)) setState(() => loading = false);
    }
  }

  Future<void> edit([CustomerVehicle? vehicle]) async {
    final customer = owner;
    final result = await Navigator.of(context).push<CustomerVehicle>(
        MaterialPageRoute(
            builder: (_) => _VehicleEditor(
                controller: widget.controller,
                repository: widget.repository,
                vehicle: vehicle)));
    if (!mounted || customer != UserSession.userId || result == null) return;
    setState(() {
      vehicles = [result, ...vehicles.where((item) => item.id != result.id)];
      error = null;
    });
    widget.controller.vehicleChanged(result.id, replacement: result);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã lưu xe.')));
  }

  Future<void> remove(CustomerVehicle vehicle) async {
    final customer = owner;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Xóa xe đã lưu?'),
                content: Text(
                    '${vehicle.label}\nXe này sẽ không còn trong danh sách chọn nhanh. Lịch sử yêu cầu cứu hộ vẫn được giữ.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Giữ lại')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error),
                      child: const Text('Xóa xe'))
                ]));
    if (!mounted || confirmed != true || customer != UserSession.userId) return;
    final version = ++generation;
    setState(() {
      deleting = true;
      error = null;
    });
    try {
      await widget.repository.delete(vehicle.id);
      if (!current(version)) return;
      setState(() => vehicles.removeWhere((item) => item.id == vehicle.id));
      widget.controller.vehicleChanged(vehicle.id);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã xóa xe.')));
    } catch (failure) {
      if (current(version))
        setState(() => error = failure is AppFailure
            ? failure.message
            : 'Không xóa được xe. Vui lòng thử lại.');
    } finally {
      if (current(version)) setState(() => deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Phương tiện của tôi'), actions: [
        IconButton(
            tooltip: 'Tải lại danh sách xe',
            onPressed: owner == null || loading || deleting ? null : load,
            icon: const Icon(Icons.refresh_rounded))
      ]),
      body: SafeArea(
          top: false,
          child: owner == null
              ? const Center(child: Text('Vui lòng đăng nhập để quản lý xe.'))
              : ListView(padding: AppSpacing.page, children: [
                  Text('Chọn nhanh xe cần hỗ trợ',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (!loading && error == null)
                    Text('${vehicles.length} phương tiện đã lưu',
                        style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: loading || deleting ? null : () => edit(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Thêm xe')),
                  const SizedBox(height: 16),
                  if (loading || deleting) const LinearProgressIndicator(),
                  if (error != null)
                    InlineNotice(error!,
                        onRetry: loading || deleting ? null : load),
                  if (!loading && error == null && vehicles.isEmpty)
                    const CustomerEmptyState(
                        icon: Icons.directions_car_outlined,
                        title: 'Chưa có xe đã lưu',
                        message: 'Thêm xe để chọn nhanh khi cần cứu hộ.'),
                  for (final vehicle in vehicles)
                    Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Icon(vehicleIcon(vehicle.kind),
                                        color: AppColors.navy),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(
                                            vehicle.brandModel.isEmpty
                                                ? 'Chưa có hãng/hiệu xe'
                                                : vehicle.brandModel,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium)),
                                  ]),
                                  const SizedBox(height: 8),
                                  Text(vehicle.kind.label,
                                      style: const TextStyle(
                                          color: AppColors.muted)),
                                  Text(
                                      'Biển số: ${vehicle.licensePlate.isEmpty ? 'Chưa cập nhật' : vehicle.licensePlate}'),
                                  Text(
                                      'Màu xe: ${vehicle.color.isEmpty ? 'Chưa cập nhật' : vehicle.color}'),
                                  if (vehicle.notes.isNotEmpty)
                                    Text('Ghi chú: ${vehicle.notes}'),
                                  const Divider(height: 16),
                                  Wrap(spacing: 8, children: [
                                    OutlinedButton.icon(
                                        onPressed: loading || deleting
                                            ? null
                                            : () => edit(vehicle),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('Sửa xe')),
                                    TextButton.icon(
                                        onPressed: loading || deleting
                                            ? null
                                            : () => remove(vehicle),
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Xóa'),
                                        style: TextButton.styleFrom(
                                            foregroundColor: AppColors.error)),
                                  ]),
                                ]))),
                ])));
}

class _VehicleEditor extends StatefulWidget {
  const _VehicleEditor(
      {required this.controller, required this.repository, this.vehicle});
  final AppController controller;
  final CustomerVehicleRepository repository;
  final CustomerVehicle? vehicle;
  @override
  State<_VehicleEditor> createState() => _VehicleEditorState();
}

class _VehicleEditorState extends State<_VehicleEditor> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController brand;
  late final TextEditingController plate;
  late final TextEditingController color;
  late final TextEditingController notes;
  late VehicleKind kind;
  late final String? owner;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    owner = UserSession.userId;
    final vehicle = widget.vehicle;
    kind = vehicle?.kind ?? VehicleKind.car;
    brand = TextEditingController(text: vehicle?.brandModel ?? '');
    plate = TextEditingController(text: vehicle?.licensePlate ?? '');
    color = TextEditingController(text: vehicle?.color ?? '');
    notes = TextEditingController(text: vehicle?.notes ?? '');
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
          id: widget.vehicle?.id,
          kind: kind,
          brandModel: brand.text,
          licensePlate: plate.text,
          color: color.text,
          notes: notes.text);
      if (!mounted || owner != UserSession.userId) return;
      Navigator.pop(context, result);
    } catch (failure) {
      if (!mounted || owner != UserSession.userId) return;
      setState(() => error = failure is AppFailure
          ? failure.message
          : 'Không lưu được xe. Thông tin đã nhập vẫn được giữ.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !saving,
      child: Scaffold(
          appBar: AppBar(
              title: Text(widget.vehicle == null ? 'Thêm xe' : 'Sửa xe')),
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
                                const ScreenHeader('Thông tin xe',
                                    subtitle:
                                        'Lưu xe để chọn nhanh khi tạo yêu cầu'),
                                DropdownButtonFormField<VehicleKind>(
                                    initialValue: kind,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Loại phương tiện'),
                                    items: VehicleKind.values
                                        .map((kind) => DropdownMenuItem(
                                            value: kind,
                                            child: Text(kind.label)))
                                        .toList(),
                                    onChanged: saving
                                        ? null
                                        : (value) =>
                                            setState(() => kind = value!)),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: brand,
                                    enabled: !saving,
                                    maxLength: 100,
                                    decoration: const InputDecoration(
                                        labelText: 'Hãng/hiệu xe',
                                        hintText:
                                            'Ví dụ: Honda Air Blade, Toyota Vios'),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Vui lòng nhập hãng/hiệu xe.'
                                            : null),
                                const SizedBox(height: 12),
                                TextFormField(
                                    controller: plate,
                                    enabled: !saving,
                                    maxLength: 30,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    decoration: const InputDecoration(
                                        labelText: 'Biển số (tùy chọn)')),
                                const SizedBox(height: 12),
                                TextFormField(
                                    controller: color,
                                    enabled: !saving,
                                    maxLength: 50,
                                    decoration: const InputDecoration(
                                        labelText: 'Màu xe (tùy chọn)')),
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
                                        label: Text(
                                            saving ? 'Đang lưu…' : 'Lưu xe'))),
                              ]))))));
}
