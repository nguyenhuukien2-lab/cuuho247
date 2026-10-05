import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../models/backend_models.dart';
import '../../widgets/app_components.dart';

const _reviewLabels = {
  'draft': 'Hồ sơ nháp',
  'submitted': 'Đang chờ duyệt',
  'approved': 'Đã được duyệt',
  'rejected': 'Cần bổ sung hồ sơ',
  'suspended': 'Tạm ngưng hoạt động',
};
const _vehicleKinds = {
  'service_motorbike': 'Xe máy hỗ trợ',
  'service_car': 'Ô tô hỗ trợ',
  'tow_truck': 'Xe kéo',
  'recovery_truck': 'Xe cứu hộ chuyên dụng',
  'other': 'Phương tiện khác',
};
const _services = {
  'tire': 'Vá lốp',
  'battery': 'Kích bình',
  'fuel': 'Tiếp nhiên liệu',
  'towing': 'Kéo xe',
  'other': 'Cứu hộ khác',
};
const _customerVehicles = {
  'motorbike': 'Xe máy',
  'car': 'Ô tô',
  'truck': 'Xe tải',
  'other': 'Xe khác',
};

class ConnectedScreen extends StatelessWidget {
  const ConnectedScreen({super.key, required this.controller});
  final RescuerController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      if (!c.signedIn && !c.loading) return _Login(c: c);
      return Scaffold(
        appBar: AppBar(
          title: Text(c.tab == 1 ? 'Đơn mới' : 'Cứu Hộ 24/7 Đối tác'),
          actions: [
            IconButton(
              tooltip: 'Tải lại hồ sơ',
              onPressed: c.working || c.loading ? null : c.refreshProfile,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: c.working || c.loading ? null : c.signOut,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: c.loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (c.working) const LinearProgressIndicator(),
                      if (c.error != null) _Error(message: c.error!),
                      if (!c.snapshotLoaded && c.error != null)
                        AppButton(
                          label: 'Thử tải lại hồ sơ',
                          onPressed: c.working ? null : c.refreshProfile,
                        )
                      else if (c.snapshot.profile == null) ...[
                        const Text(
                          'Tạo hồ sơ người cứu hộ',
                          style: AppType.pageTitle,
                        ),
                        const SizedBox(height: 16),
                        _ProfileForm(c: c),
                      ] else if (c.tab == 1)
                        _Feed(c: c)
                      else ...[
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.snapshot.profile!['full_name'] as String,
                                style: AppType.section,
                              ),
                              const SizedBox(height: 8),
                              StatusBadge(
                                label:
                                    _reviewLabels[c
                                        .snapshot
                                        .profile!['verification_status']] ??
                                    'Chưa xác định',
                                tone: c.snapshot.approved
                                    ? BadgeTone.green
                                    : BadgeTone.orange,
                              ),
                              if (!c.snapshot.approved)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Hồ sơ và phương tiện cần được duyệt trước khi nhận thông báo đơn mới.',
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (c.tab == 0) _OnlinePanel(c: c),
                        if (c.tab == 2) ...[
                          _ProfileForm(
                            key: ValueKey(
                              '${c.userId}-${c.snapshot.profile!['version']}',
                            ),
                            c: c,
                          ),
                          const SizedBox(height: 16),
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Giấy tờ và xét duyệt',
                                  style: AppType.section,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  c.snapshot.canSubmit
                                      ? 'Giấy tờ đã sẵn sàng. Bạn có thể gửi hồ sơ để xét duyệt.'
                                      : 'Bước này chưa hỗ trợ tải giấy tờ. Cần căn cước, giấy phép lái xe và đăng ký xe đã được tải lên để gửi duyệt.',
                                ),
                                const SizedBox(height: 12),
                                AppButton(
                                  label: 'Gửi hồ sơ duyệt',
                                  onPressed: !c.working && c.snapshot.canSubmit
                                      ? c.submitProfile
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Phương tiện', style: AppType.section),
                          for (final v in c.snapshot.vehicles)
                            Card(
                              child: ListTile(
                                leading: const Icon(
                                  Icons.local_shipping_outlined,
                                ),
                                title: Text(v['display_name'] as String),
                                subtitle: Text(
                                  '${v['license_plate']} · ${_reviewLabels[v['verification_status']] ?? 'Chưa duyệt'}',
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          _VehicleForm(c: c),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: c.snapshot.profile == null
            ? null
            : NavigationBar(
                selectedIndex: c.tab,
                onDestinationSelected: c.selectTab,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.radar),
                    label: 'Trang chủ',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.assignment_outlined),
                    label: 'Đơn mới',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    label: 'Tài khoản',
                  ),
                ],
              ),
      );
    },
  );
}

class _Error extends StatelessWidget {
  const _Error({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: InfoBanner(
      title: 'Chưa thể hoàn tất',
      message: message,
      icon: Icons.error_outline,
      tone: BadgeTone.red,
    ),
  );
}

class _Login extends StatefulWidget {
  const _Login({required this.c});
  final RescuerController c;
  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đăng nhập đối tác')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: _form,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: BrandMark(size: 72)),
              const SizedBox(height: 24),
              const Text('Chào mừng đối tác', style: AppType.pageTitle),
              const SizedBox(height: 12),
              const Text('Sử dụng email và mật khẩu tài khoản đã đăng ký.'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v == null || !v.trim().contains('@')
                    ? 'Nhập email hợp lệ'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Nhập mật khẩu' : null,
              ),
              if (widget.c.error != null) _Error(message: widget.c.error!),
              const SizedBox(height: 24),
              AppButton(
                label: 'Đăng nhập',
                loading: widget.c.working,
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    widget.c.signIn(_email.text, _password.text);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({super.key, required this.c});
  final RescuerController c;
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.c.snapshot.profile?['full_name'] as String?,
  );
  late final _phone = TextEditingController(
    text: widget.c.snapshot.profile?['contact_phone'] as String?,
  );
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppCard(
    child: Form(
      key: _form,
      child: Column(
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Họ và tên'),
            maxLength: 150,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Nhập họ tên' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại liên hệ',
            ),
            validator: (v) =>
                !RegExp(r'^\+?[0-9]{8,15}$').hasMatch(v?.trim() ?? '')
                ? 'Nhập 8–15 chữ số, có thể bắt đầu bằng +'
                : null,
          ),
          if (widget.c.snapshot.approved)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Thay đổi thông tin sẽ đưa hồ sơ về trạng thái cần duyệt lại.',
              ),
            ),
          const SizedBox(height: 16),
          AppButton(
            label: widget.c.snapshot.profile == null
                ? 'Tạo hồ sơ'
                : 'Lưu hồ sơ',
            onPressed: widget.c.working || !widget.c.canEdit
                ? null
                : () {
                    if (_form.currentState!.validate()) {
                      widget.c.saveProfile(_name.text, _phone.text);
                    }
                  },
          ),
        ],
      ),
    ),
  );
}

class _VehicleForm extends StatefulWidget {
  const _VehicleForm({required this.c});
  final RescuerController c;
  @override
  State<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<_VehicleForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _plate = TextEditingController();
  String _kind = 'service_motorbike';
  @override
  void dispose() {
    _name.dispose();
    _plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppCard(
    child: Form(
      key: _form,
      child: Column(
        children: [
          const Text('Đăng ký phương tiện', style: AppType.section),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Loại phương tiện'),
            items: _vehicleKinds.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _kind = v);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            maxLength: 150,
            decoration: const InputDecoration(labelText: 'Tên phương tiện'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Nhập tên xe' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _plate,
            decoration: const InputDecoration(labelText: 'Biển số'),
            validator: (v) =>
                !RegExp(r'^[A-Z0-9]{1,20}$').hasMatch(
                  (v ?? '').toUpperCase().replaceAll(RegExp(r'[\s.\-]'), ''),
                )
                ? 'Nhập biển số hợp lệ'
                : null,
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Đăng ký xe',
            onPressed: widget.c.working || !widget.c.canEdit
                ? null
                : () async {
                    if (!_form.currentState!.validate()) return;
                    await widget.c.registerVehicle(
                      _kind,
                      _name.text,
                      _plate.text,
                    );
                    if (mounted && widget.c.error == null) {
                      _name.clear();
                      _plate.clear();
                    }
                  },
          ),
        ],
      ),
    ),
  );
}

class _OnlinePanel extends StatelessWidget {
  const _OnlinePanel({required this.c});
  final RescuerController c;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Trạng thái hoạt động', style: AppType.section),
        const SizedBox(height: 12),
        if (c.snapshot.eligibleVehicles.isNotEmpty)
          DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey('${c.selectedVehicle}-${c.online}'),
            initialValue:
                c.snapshot.eligibleVehicles.any(
                  (v) => v['id'] == c.selectedVehicle,
                )
                ? c.selectedVehicle
                : null,
            decoration: const InputDecoration(labelText: 'Xe hoạt động'),
            items: c.snapshot.eligibleVehicles
                .map(
                  (v) => DropdownMenuItem(
                    value: v['id'] as String,
                    child: Text('${v['display_name']} · ${v['license_plate']}'),
                  ),
                )
                .toList(),
            onChanged: c.online || c.working ? null : c.selectVehicle,
          )
        else
          const Text(
            'Chưa có xe kèm dịch vụ đã được duyệt. Đăng ký xe trong Tài khoản và chờ xét duyệt.',
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(c.online ? 'Đang online' : 'Đang offline'),
          subtitle: const Text('Cần quyền vị trí và GPS chính xác để tìm đơn.'),
          value: c.online,
          onChanged: c.working || (!c.online && !c.canOnline)
              ? null
              : c.setOnline,
        ),
        if (c.online) ...[
          Text(
            c.locationReady
                ? 'Vị trí đã được cập nhật.'
                : 'Cần cập nhật vị trí để xem đơn mới.',
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Cập nhật GPS và đơn mới',
            onPressed: c.working ? null : c.refreshRequests,
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Giữ ứng dụng mở để cập nhật vị trí. Tính năng nhận đơn sẽ được bổ sung ở bước sau.',
          style: AppType.caption,
        ),
      ],
    ),
  );
}

class _Feed extends StatelessWidget {
  const _Feed({required this.c});
  final RescuerController c;
  @override
  Widget build(BuildContext context) {
    if (!c.snapshot.approved) {
      return const InfoBanner(
        title: 'Hồ sơ chưa được duyệt',
        message:
            'Danh sách đơn mới sẽ khả dụng sau khi hồ sơ và xe được duyệt.',
        icon: Icons.hourglass_empty,
      );
    }
    if (!c.online || !c.canOnline) {
      return const InfoBanner(
        title: 'Đơn mới chưa khả dụng',
        message: 'Chọn xe đủ điều kiện và bật online tại Trang chủ.',
        icon: Icons.radar,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: 'Cập nhật đơn mới',
          onPressed: c.working ? null : c.refreshRequests,
        ),
        const SizedBox(height: 16),
        if (c.feedStatus == FeedStatus.loading)
          const Center(child: CircularProgressIndicator()),
        if (c.feedStatus == FeedStatus.error)
          _Error(message: c.feedError ?? 'Không thể tải đơn mới.'),
        if (c.feedStatus == FeedStatus.empty)
          const InfoBanner(
            title: 'Chưa có đơn mới phù hợp',
            message: 'Hiện chưa có yêu cầu phù hợp với xe, dịch vụ và khu vực của bạn.',
            icon: Icons.inbox_outlined,
          ),
        if (c.feedStatus == FeedStatus.unavailable)
          const Text('Cập nhật GPS để tải danh sách đơn mới.'),
        for (final request in c.requests) _RequestCard(request: request),
        if (c.cursor != null)
          AppButton(
            label: 'Xem thêm',
            onPressed: c.working ? null : () => c.refreshRequests(more: true),
          ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});
  final AvailableRequest request;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _services[request.service] ?? 'Dịch vụ cứu hộ',
            style: AppType.section,
          ),
          const SizedBox(height: 8),
          Text(_customerVehicles[request.vehicle] ?? 'Phương tiện khác'),
          Text(
            request.availableDistanceKm == null
                ? 'Chưa có khoảng cách ước tính'
                : 'Khoảng ${request.availableDistanceKm} km',
          ),
          if (request.hasApproximateLocation)
            Text(
              'Khu vực gần đúng: ${request.latitude!.toStringAsFixed(3)}, ${request.longitude!.toStringAsFixed(3)}',
            )
          else
            const Text('Chưa có tọa độ GPS'),
          const SizedBox(height: 8),
          const Text('Vị trí chỉ mang tính gần đúng.', style: AppType.caption),
        ],
      ),
    ),
  );
}
