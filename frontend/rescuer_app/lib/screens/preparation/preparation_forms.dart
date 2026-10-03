import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../models/backend_models.dart';
import '../../widgets/app_components.dart';
import 'preparation_components.dart';

class PreparationLogin extends StatefulWidget {
  const PreparationLogin({super.key, required this.c});
  final RescuerController c;
  @override
  State<PreparationLogin> createState() => _PreparationLoginState();
}

class _PreparationLoginState extends State<PreparationLogin> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  bool obscure = true;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đăng nhập đối tác')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.navy, AppColors.navySoft],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                children: [
                  BrandMark(size: 70, light: true),
                  SizedBox(height: 16),
                  Text(
                    'ĐỐI TÁC CỨU HỘ 24/7',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Vững tay lái. Kết nối mọi hành trình.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sẵn sàng đồng hành',
              style: AppType.pageTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Cứu Hộ 24/7 Đối tác\nĐăng nhập bằng email và mật khẩu đã đăng ký.',
              textAlign: TextAlign.center,
              style: AppType.body,
            ),
            const SizedBox(height: 24),
            AppCard(
              child: Form(
                key: form,
                child: AutofillGroup(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: (v) => v == null || !v.trim().contains('@')
                            ? 'Nhập email hợp lệ'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: password,
                        obscureText: obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Nhập mật khẩu' : null,
                      ),
                      if (widget.c.error != null) ...[
                        const SizedBox(height: 16),
                        InfoBanner(
                          title: 'Chưa thể đăng nhập',
                          message: widget.c.error!,
                          icon: Icons.error_outline,
                          tone: BadgeTone.red,
                        ),
                      ],
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Đăng nhập',
                        icon: Icons.login,
                        loading: widget.c.working,
                        onPressed: () {
                          if (form.currentState!.validate()) {
                            widget.c.signIn(email.text, password.text);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sau khi đăng nhập, bạn có thể tạo hồ sơ, đăng ký xe và gửi giấy tờ để xét duyệt.',
              textAlign: TextAlign.center,
              style: AppType.caption,
            ),
          ],
        ),
      ),
    ),
  );
}

class PreparationProfile extends StatefulWidget {
  const PreparationProfile({super.key, required this.c});
  final RescuerController c;
  @override
  State<PreparationProfile> createState() => _PreparationProfileState();
}

class _PreparationProfileState extends State<PreparationProfile> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: widget.c.snapshot.profile?['full_name'] as String?,
  );
  late final phone = TextEditingController(
    text: widget.c.snapshot.profile?['contact_phone'] as String?,
  );
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (widget.c.snapshot.approved) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Thông tin cần được duyệt lại'),
          content: const Text(
            'Lưu thay đổi sẽ đưa hồ sơ về nháp và tắt online. Bạn cần gửi duyệt lại trước khi hoạt động.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Giữ thông tin'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lưu thay đổi'),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }
    await widget.c.saveProfile(name.text, phone.text);
  }

  @override
  Widget build(BuildContext context) => PreparationCard(
    title: 'Thông tin cá nhân',
    subtitle: 'Thông tin liên hệ của bạn được dùng cho hồ sơ đối tác.',
    icon: Icons.person_outline,
    children: [
      Form(
        key: form,
        child: Column(
          children: [
            TextFormField(
              controller: name,
              maxLength: 150,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nhập họ tên' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại liên hệ',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) =>
                  RegExp(r'^\+?[0-9]{8,15}$').hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Nhập 8–15 chữ số, có thể bắt đầu bằng +',
            ),
            const SizedBox(height: 18),
            AppButton(
              label: widget.c.snapshot.profile == null
                  ? 'Tạo hồ sơ'
                  : 'Lưu hồ sơ',
              icon: Icons.save_outlined,
              onPressed: widget.c.working || !widget.c.canEdit ? null : save,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: widget.c.snapshot.profile == null
            ? null
            : () => widget.c.openSection('vehicles'),
        child: const Text('Tiếp theo: thêm phương tiện'),
      ),
    ],
  );
}

class PreparationVehicles extends StatelessWidget {
  const PreparationVehicles({super.key, required this.c});
  final RescuerController c;
  Future<void> edit(BuildContext context, [Json? vehicle]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => VehicleEditor(c: c, vehicle: vehicle),
    );
  }

  @override
  Widget build(BuildContext context) => PreparationCard(
    title: 'Phương tiện cứu hộ',
    subtitle: 'Đăng ký biển số và mô tả phương tiện bạn sử dụng.',
    icon: Icons.local_shipping_outlined,
    children: [
      if (c.snapshot.profile == null) ...[
        const Text('Tạo hồ sơ cá nhân trước khi thêm xe.'),
        TextButton(
          onPressed: () => c.openSection('profile'),
          child: const Text('Tạo hồ sơ cá nhân'),
        ),
      ],
      if (c.snapshot.profile != null && c.snapshot.vehicles.isEmpty)
        const Text(
          'Bạn chưa có phương tiện. Thêm xe để tiếp tục chọn dịch vụ.',
        ),
      for (final v in c.snapshot.vehicles)
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      v['license_plate'] as String,
                      style: AppType.section,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sửa xe',
                    onPressed: c.working || !c.canEdit
                        ? null
                        : () => edit(context, v),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              Text(v['display_name'] as String),
              const SizedBox(height: 4),
              Text(
                vehicleKinds[v['kind']] ?? 'Phương tiện khác',
                style: AppType.caption,
              ),
              const SizedBox(height: 10),
              ReviewBadge(v['verification_status'] as String?),
              if (v['is_active'] != true)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Đã tắt hoạt động', style: AppType.caption),
                ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      AppButton(
        label: 'Thêm xe cứu hộ',
        icon: Icons.add,
        onPressed: c.working || !c.canEdit || c.snapshot.profile == null
            ? null
            : () => edit(context),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: c.snapshot.vehicles.isEmpty
            ? null
            : () => c.openSection('services'),
        child: const Text('Tiếp theo: chọn dịch vụ nhận đơn'),
      ),
    ],
  );
}

class VehicleEditor extends StatefulWidget {
  const VehicleEditor({super.key, required this.c, this.vehicle});
  final RescuerController c;
  final Json? vehicle;
  @override
  State<VehicleEditor> createState() => _VehicleEditorState();
}

class _VehicleEditorState extends State<VehicleEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: widget.vehicle?['display_name'] as String?,
  );
  late final plate = TextEditingController(
    text: widget.vehicle?['license_plate'] as String?,
  );
  late String kind = widget.vehicle?['kind'] as String? ?? 'service_motorbike';
  late bool active = widget.vehicle?['is_active'] != false;
  bool saving = false;
  @override
  void dispose() {
    name.dispose();
    plate.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || saving) return;
    setState(() => saving = true);
    if (widget.vehicle == null) {
      await widget.c.registerVehicle(kind, name.text, plate.text);
    } else {
      await widget.c.updateVehicle(
        widget.vehicle!,
        kind,
        name.text,
        plate.text,
        active,
      );
    }
    if (!mounted) return;
    if (widget.c.error == null) {
      Navigator.pop(context);
    } else {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.c,
    builder: (context, _) => Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.vehicle == null ? 'Thêm xe cứu hộ' : 'Sửa xe cứu hộ',
                style: AppType.pageTitle,
              ),
              const SizedBox(height: 16),
              if (widget.vehicle != null) ...[
                const Text(
                  'Lưu thay đổi sẽ đưa xe về nháp và yêu cầu duyệt lại dịch vụ.',
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: plate,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Biển số xe'),
                validator: (v) =>
                    RegExp(r'^[A-Z0-9]{1,20}$').hasMatch(
                      (v ?? '').toUpperCase().replaceAll(
                        RegExp(r'[\s.\-]'),
                        '',
                      ),
                    )
                    ? null
                    : 'Nhập biển số hợp lệ',
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Loại xe cứu hộ'),
                items: vehicleKinds.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: saving ? null : (v) => setState(() => kind = v!),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: name,
                maxLength: 150,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Tên / mô tả phương tiện',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Mô tả phương tiện của bạn'
                    : null,
              ),
              if (widget.vehicle != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Phương tiện hoạt động'),
                  value: active,
                  onChanged: saving ? null : (v) => setState(() => active = v),
                ),
              if (widget.c.error != null) ...[
                InfoBanner(
                  title: 'Chưa lưu được xe',
                  message: widget.c.error!,
                  icon: Icons.error_outline,
                  tone: BadgeTone.red,
                ),
                const SizedBox(height: 14),
              ],
              AppButton(
                label: 'Lưu xe',
                icon: Icons.save_outlined,
                loading: saving,
                onPressed: save,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PreparationServices extends StatefulWidget {
  const PreparationServices({super.key, required this.c});
  final RescuerController c;
  @override
  State<PreparationServices> createState() => _PreparationServicesState();
}

class _PreparationServicesState extends State<PreparationServices> {
  String? vehicle;
  String customerKind = 'motorbike';
  Set<String> selected = {};
  RescuerSnapshot? loaded;
  @override
  void initState() {
    super.initState();
    vehicle = widget.c.snapshot.vehicles.firstOrNull?['id'] as String?;
    sync();
  }

  void sync() {
    loaded = widget.c.snapshot;
    selected = widget.c.snapshot.capabilities
        .where(
          (c) =>
              c['vehicle_id'] == vehicle &&
              c['customer_vehicle_kind'] == customerKind &&
              c['is_enabled'] == true,
        )
        .map((c) => c['service_code'] as String)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    if (!identical(loaded, c.snapshot)) {
      if (!c.snapshot.vehicles.any((v) => v['id'] == vehicle)) {
        vehicle = c.snapshot.vehicles.firstOrNull?['id'] as String?;
      }
      sync();
    }
    return PreparationCard(
      title: 'Dịch vụ nhận đơn',
      subtitle: 'Chọn xe cứu hộ, loại xe khách bạn hỗ trợ và các dịch vụ có khả năng thực hiện.',
      icon: Icons.build_outlined,
      children: [
        if (c.snapshot.vehicles.isEmpty) ...[
          const Text('Thêm xe cứu hộ trước khi chọn dịch vụ.'),
          AppButton(
            label: 'Thêm phương tiện',
            onPressed: () => c.openSection('vehicles'),
          ),
        ] else ...[
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: vehicle,
            decoration: const InputDecoration(labelText: 'Xe cứu hộ của bạn'),
            items: c.snapshot.vehicles
                .map(
                  (v) => DropdownMenuItem(
                    value: v['id'] as String,
                    child: Text(
                      '${v['license_plate']} · ${v['display_name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: c.working
                ? null
                : (v) => setState(() {
                    vehicle = v;
                    sync();
                  }),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: customerKind,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Loại xe khách nhận hỗ trợ',
            ),
            items: customerVehicles.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: c.working
                ? null
                : (v) => setState(() {
                    customerKind = v!;
                    sync();
                  }),
          ),
          const SizedBox(height: 14),
          for (final code in [
            'towing',
            'repair',
            'battery',
            'tire',
            'fuel',
            'locksmith',
            ...c.snapshot.services
                .map((s) => s['code'] as String)
                .where(
                  (s) => ![
                    'towing',
                    'repair',
                    'battery',
                    'tire',
                    'fuel',
                    'locksmith',
                  ].contains(s),
                ),
          ])
            Builder(
              builder: (context) {
                final service = c.snapshot.services
                    .where((s) => s['code'] == code)
                    .firstOrNull;
                final cap = c.snapshot.capabilities
                    .where(
                      (r) =>
                          r['vehicle_id'] == vehicle &&
                          r['customer_vehicle_kind'] == customerKind &&
                          r['service_code'] == code,
                    )
                    .firstOrNull;
                final label = code == 'repair'
                    ? 'Sửa tại chỗ'
                    : code == 'locksmith'
                    ? 'Mở khóa xe'
                    : serviceLabels[code] ??
                          service?['name'] as String? ??
                          'Dịch vụ cứu hộ';
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(label),
                  subtitle: Text(
                    service == null
                        ? 'Chưa được hỗ trợ trong danh mục dịch vụ.'
                        : cap == null
                        ? 'Chọn để gửi xét duyệt năng lực.'
                        : cap['is_enabled'] == true
                        ? reviewLabels[cap['verification_status']] ??
                              'Chờ duyệt'
                        : 'Đã tắt · bật lại cần duyệt',
                  ),
                  value: selected.contains(code),
                  onChanged: service == null || c.working || !c.canEdit
                      ? null
                      : (v) => setState(() {
                          if (v == true) {
                            selected.add(code);
                          } else {
                            selected.remove(code);
                          }
                        }),
                );
              },
            ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Lưu dịch vụ',
            icon: Icons.save_outlined,
            onPressed: c.working || !c.canEdit || vehicle == null
                ? null
                : () => c.saveCapabilities(vehicle!, customerKind, selected),
          ),
          const SizedBox(height: 12),
          const Text(
            'Dịch vụ mới hoặc bật lại sẽ chờ xét duyệt. Không tự gán quyền nhận đơn.',
            style: AppType.caption,
          ),
          TextButton(
            onPressed: () => c.openSection('documents'),
            child: const Text('Tiếp theo: tải giấy tờ xác minh'),
          ),
        ],
      ],
    );
  }
}

class PreparationDocuments extends StatefulWidget {
  const PreparationDocuments({super.key, required this.c});
  final RescuerController c;
  @override
  State<PreparationDocuments> createState() => _PreparationDocumentsState();
}

class _PreparationDocumentsState extends State<PreparationDocuments> {
  String? vehicle;
  @override
  void initState() {
    super.initState();
    vehicle = widget.c.snapshot.vehicles.firstOrNull?['id'] as String?;
  }

  Widget document(String type, String label, IconData icon) {
    final c = widget.c;
    final rows = c.snapshot.documents
        .where(
          (d) =>
              d['document_type'] == type &&
              (type != 'vehicle_registration' || d['vehicle_id'] == vehicle),
        )
        .toList();
    rows.sort(
      (a, b) => (b['created_at'] as String? ?? '').compareTo(
        a['created_at'] as String? ?? '',
      ),
    );
    final latest = rows.firstOrNull;
    final complete = rows.any(c.snapshot.documentReady);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.navy),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: AppType.section)),
              Icon(
                complete ? Icons.check_circle : Icons.error_outline,
                color: complete ? AppColors.success : AppColors.orange,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            complete
                ? 'Đã có giấy tờ được tải lên, còn hiệu lực.'
                : latest != null && latest['uploaded_at'] == null
                ? 'Tệp chưa hoàn tất. Chọn lại cùng tệp để tiếp tục hoặc xác nhận nếu tệp đã tải lên.'
                : 'Chưa có giấy tờ hợp lệ. Chọn JPEG, PNG hoặc PDF tối đa 10 MB.',
            style: AppType.caption,
          ),
          if (latest != null) ...[
            const SizedBox(height: 8),
            ReviewBadge(
              latest['uploaded_at'] == null
                  ? null
                  : latest['verification_status'] as String?,
            ),
          ],
          const SizedBox(height: 12),
          AppButton(
            label: latest == null
                ? 'Chọn tệp & tải lên'
                : 'Tải bản mới / tiếp tục',
            icon: Icons.upload_file,
            kind: ButtonStyleKind.outline,
            onPressed:
                c.working ||
                    !c.canEdit ||
                    c.snapshot.profile == null ||
                    (type == 'vehicle_registration' && vehicle == null)
                ? null
                : () => c.uploadDocument(
                    type,
                    type == 'vehicle_registration' ? vehicle : null,
                  ),
          ),
          if (latest != null && latest['uploaded_at'] == null)
            TextButton(
              onPressed: c.working
                  ? null
                  : () => c.completeDocument(latest['id'] as String),
              child: const Text('Xác nhận tệp đã tải lên'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PreparationCard(
    title: 'Giấy tờ xác minh',
    subtitle: 'Tệp được lưu riêng theo tài khoản, không chia sẻ với khách hàng hoặc đối tác khác.',
    icon: Icons.folder_outlined,
    children: [
      if (widget.c.snapshot.profile == null) ...[
        const Text('Lưu hồ sơ trước khi tải giấy tờ.'),
        TextButton(
          onPressed: () => widget.c.openSection('profile'),
          child: const Text('Tạo hồ sơ cá nhân'),
        ),
      ],
      document(
        'identity',
        'Căn cước / giấy tờ định danh',
        Icons.badge_outlined,
      ),
      document('license', 'Giấy phép lái xe', Icons.credit_card_outlined),
      if (widget.c.snapshot.vehicles.isNotEmpty) ...[
        DropdownButtonFormField<String>(
          initialValue: vehicle,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Xe cần xác minh'),
          items: widget.c.snapshot.vehicles
              .map(
                (v) => DropdownMenuItem(
                  value: v['id'] as String,
                  child: Text(v['license_plate'] as String),
                ),
              )
              .toList(),
          onChanged: widget.c.working
              ? null
              : (v) => setState(() => vehicle = v),
        ),
        const SizedBox(height: 14),
      ] else ...[
        const Text('Thêm xe để tải giấy đăng ký phương tiện.'),
        TextButton(
          onPressed: () => widget.c.openSection('vehicles'),
          child: const Text('Thêm xe cứu hộ'),
        ),
      ],
      document(
        'vehicle_registration',
        'Đăng ký phương tiện',
        Icons.description_outlined,
      ),
      const Text(
        'Tệp đã hoàn tất không bị ghi đè. Upload không đồng nghĩa giấy tờ đã được duyệt.',
        style: AppType.caption,
      ),
      const SizedBox(height: 10),
      AppButton(
        label: 'Tiếp tục xét duyệt',
        onPressed: () => widget.c.openSection('review'),
      ),
    ],
  );
}
