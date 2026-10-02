import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/app_theme.dart';
import '../../models/rescuer_status.dart';
import '../../widgets/app_components.dart';

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

class RegistrationProgressScreen extends StatelessWidget {
  const RegistrationProgressScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    const steps = ['Hồ sơ', 'Giấy tờ', 'Phương tiện', 'Dịch vụ', 'Chờ duyệt'];
    final current = switch (state.partnerStatus) {
      PartnerReviewStatus.draft => state.fullName == null ? 0 : 1,
      PartnerReviewStatus.submitted => 4,
      PartnerReviewStatus.approved => 5,
      PartnerReviewStatus.rejected => 2,
      PartnerReviewStatus.suspended => 4,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký đối tác')),
      body: SafeArea(
        child: ScreenContent(
          bottomAction: AppButton(
            label: current == 0 ? 'Bắt đầu hồ sơ' : 'Tiếp tục đăng ký',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => _push(context, PartnerProfileScreen(state: state)),
          ),
          children: [
            const PageHeading(
              title: 'Hồ sơ đối tác',
              subtitle: 'Hoàn thiện lần lượt các thông tin cần thiết.',
            ),
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    _StepRow(
                      index: i + 1,
                      label: steps[i],
                      active: i < current,
                      current: i == current,
                    ),
                    if (i < steps.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 15),
                        child: Container(
                          width: 1,
                          height: 22,
                          color: i < current
                              ? AppColors.success
                              : AppColors.line,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text('Trạng thái hồ sơ', style: AppType.section),
                ),
                StatusBadge(
                  label: state.partnerStatus.label,
                  tone: _partnerTone(state.partnerStatus),
                ),
              ],
            ),
            const InfoBanner(
              title: 'Xác minh hồ sơ',
              message:
                  'Các trạng thái duyệt chỉ do quy trình xác minh cập nhật.',
              icon: Icons.verified_user_outlined,
            ),
            _NavigationCard(
              icon: Icons.person_outline_rounded,
              title: 'Thông tin đối tác',
              status: state.fullName == null ? 'Chưa hoàn thiện' : 'Đã nhập',
              onTap: () => _push(context, PartnerProfileScreen(state: state)),
            ),
            _NavigationCard(
              icon: Icons.folder_outlined,
              title: 'Giấy tờ xác minh',
              status: _documentSummary(state),
              onTap: () =>
                  _push(context, DocumentVerificationScreen(state: state)),
            ),
            _NavigationCard(
              icon: Icons.directions_car_outlined,
              title: 'Phương tiện cứu hộ',
              status: state.vehicleDisplayName == null
                  ? 'Chưa thêm phương tiện'
                  : state.vehicleStatus.label,
              onTap: () =>
                  _push(context, VehicleRegistrationScreen(state: state)),
            ),
            _NavigationCard(
              icon: Icons.handyman_outlined,
              title: 'Dịch vụ hỗ trợ',
              status: state.serviceCapabilities.isEmpty
                  ? 'Chưa chọn'
                  : 'Đã chọn',
              onTap: () =>
                  _push(context, ServiceCapabilitiesScreen(state: state)),
            ),
          ],
        ),
      ),
    );
  }

  String _documentSummary(AppState value) {
    if (value.identityStatus == DocumentReviewStatus.submitted ||
        value.licenseStatus == DocumentReviewStatus.submitted) {
      return 'Đang xem xét';
    }
    return 'Chưa gửi';
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.label,
    required this.active,
    required this.current,
  });
  final int index;
  final String label;
  final bool active;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.success
        : current
        ? AppColors.orange
        : AppColors.line;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active ? AppColors.successSoft : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          alignment: Alignment.center,
          child: active
              ? const Icon(Icons.check, color: AppColors.success, size: 18)
              : Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: current ? AppColors.warning : AppColors.muted,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: current || active ? AppColors.ink : AppColors.muted,
              fontSize: 14,
              fontWeight: current || active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        if (current)
          const StatusBadge(label: 'Tiếp theo', tone: BadgeTone.orange),
      ],
    );
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadii.md),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.navy, size: 21),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(status, style: AppType.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}

class PartnerProfileScreen extends StatefulWidget {
  const PartnerProfileScreen({super.key, required this.state});
  final AppState state;

  @override
  State<PartnerProfileScreen> createState() => _PartnerProfileScreenState();
}

class _PartnerProfileScreenState extends State<PartnerProfileScreen> {
  final formKey = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.state.fullName ?? '');
  late final phone = TextEditingController(
    text: widget.state.contactPhone ?? '',
  );
  late final email = TextEditingController(
    text: widget.state.contactEmail ?? '',
  );

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    super.dispose();
  }

  void save() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    widget.state.savePartnerProfile(
      name: name.text,
      phone: phone.text,
      email: email.text,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentVerificationScreen(state: widget.state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thông tin đối tác')),
    body: SafeArea(
      child: Form(
        key: formKey,
        child: ScreenContent(
          bottomAction: AppButton(
            label: 'Tiếp tục: giấy tờ',
            icon: Icons.arrow_forward_rounded,
            onPressed: save,
          ),
          children: [
            const PageHeading(
              title: 'Thông tin cá nhân',
              subtitle: 'Nhập thông tin liên hệ cho hồ sơ đối tác.',
            ),
            AppTextField(
              controller: name,
              label: 'Họ và tên',
              icon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập họ tên'
                  : null,
            ),
            AppTextField(
              controller: phone,
              label: 'Số điện thoại',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập số điện thoại'
                  : null,
            ),
            AppTextField(
              controller: email,
              label: 'Email (không bắt buộc)',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const InfoBanner(
              title: 'Lưu thông tin trên thiết bị',
              message: 'Hồ sơ chưa được gửi hoặc xác minh trên dịch vụ.',
              icon: Icons.info_outline_rounded,
              tone: BadgeTone.orange,
            ),
          ],
        ),
      ),
    ),
  );
}

class DocumentVerificationScreen extends StatelessWidget {
  const DocumentVerificationScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Giấy tờ xác minh')),
    body: SafeArea(
      child: ScreenContent(
        children: [
          const PageHeading(
            title: 'Xác minh hồ sơ',
            subtitle: 'Theo dõi trạng thái các giấy tờ cần thiết.',
          ),
          _DocumentCard(
            title: 'Giấy tờ định danh',
            description: 'Ảnh chụp rõ nét, còn hiệu lực.',
            status: state.identityStatus,
            requiredDocument: true,
          ),
          _DocumentCard(
            title: 'Giấy phép lái xe',
            description: 'Yêu cầu theo loại phương tiện và dịch vụ.',
            status: state.licenseStatus,
            requiredDocument: false,
          ),
          const InfoBanner(
            title: 'Tải giấy tờ',
            message: 'Chức năng tải tài liệu chưa khả dụng. Không có tệp nào được chọn hoặc gửi.',
            icon: Icons.upload_file_outlined,
            tone: BadgeTone.orange,
          ),
          AppButton(
            label: 'Tiếp tục: phương tiện',
            icon: Icons.arrow_forward_rounded,
            onPressed: () =>
                _push(context, VehicleRegistrationScreen(state: state)),
          ),
        ],
      ),
    ),
  );
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.title,
    required this.description,
    required this.status,
    required this.requiredDocument,
  });
  final String title;
  final String description;
  final DocumentReviewStatus status;
  final bool requiredDocument;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.blueSoft,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Icon(
                Icons.badge_outlined,
                color: AppColors.navy,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(description, style: AppType.caption),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: StatusBadge(
                label: status.label,
                tone: _documentTone(status),
              ),
            ),
            if (requiredDocument)
              const Text('Cần thiết', style: AppType.caption),
          ],
        ),
      ],
    ),
  );
}

BadgeTone _documentTone(DocumentReviewStatus status) => switch (status) {
  DocumentReviewStatus.notSubmitted => BadgeTone.neutral,
  DocumentReviewStatus.submitted => BadgeTone.blue,
  DocumentReviewStatus.approved => BadgeTone.green,
  DocumentReviewStatus.needsChanges => BadgeTone.orange,
};

class VehicleRegistrationScreen extends StatefulWidget {
  const VehicleRegistrationScreen({super.key, required this.state});
  final AppState state;

  @override
  State<VehicleRegistrationScreen> createState() =>
      _VehicleRegistrationScreenState();
}

class _VehicleRegistrationScreenState extends State<VehicleRegistrationScreen> {
  final formKey = GlobalKey<FormState>();
  late final displayName = TextEditingController(
    text: widget.state.vehicleDisplayName ?? '',
  );
  late final plate = TextEditingController(
    text: widget.state.vehiclePlate ?? '',
  );
  late String type = widget.state.vehicleServiceType;
  static const vehicleTypes = [
    'Xe máy hỗ trợ',
    'Ô tô hỗ trợ',
    'Xe kéo',
    'Xe cứu hộ',
    'Khác',
  ];

  @override
  void dispose() {
    displayName.dispose();
    plate.dispose();
    super.dispose();
  }

  void save() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    widget.state.saveVehicle(
      displayName: displayName.text,
      plate: plate.text,
      type: type,
    );
    _push(context, ServiceCapabilitiesScreen(state: widget.state));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Phương tiện cứu hộ')),
    body: SafeArea(
      child: Form(
        key: formKey,
        child: ScreenContent(
          bottomAction: AppButton(
            label: 'Tiếp tục: dịch vụ',
            icon: Icons.arrow_forward_rounded,
            onPressed: save,
          ),
          children: [
            const PageHeading(
              title: 'Thêm phương tiện',
              subtitle: 'Thông tin phương tiện bạn dùng để hỗ trợ.',
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Loại phương tiện', style: AppType.section),
                  const SizedBox(height: 11),
                  for (final vehicleType in vehicleTypes)
                    ListTile(
                      minTileHeight: 48,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        type == vehicleType
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: type == vehicleType
                            ? AppColors.navy
                            : AppColors.muted,
                      ),
                      title: Text(vehicleType, style: AppType.body),
                      onTap: () => setState(() => type = vehicleType),
                    ),
                ],
              ),
            ),
            AppTextField(
              controller: displayName,
              label: 'Tên hiển thị phương tiện',
              hint: 'Hãng xe hoặc mô tả ngắn',
              icon: Icons.directions_car_outlined,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập tên phương tiện'
                  : null,
            ),
            AppTextField(
              controller: plate,
              label: 'Biển số xe',
              hint: 'Nhập biển số',
              icon: Icons.pin_outlined,
              textCapitalization: TextCapitalization.characters,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập biển số xe'
                  : null,
            ),
            Row(
              children: [
                const Expanded(
                  child: Text('Trạng thái phương tiện', style: AppType.section),
                ),
                StatusBadge(
                  label: widget.state.vehicleStatus.label,
                  tone: _vehicleTone(widget.state.vehicleStatus),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

BadgeTone _vehicleTone(VehicleReviewStatus status) => switch (status) {
  VehicleReviewStatus.draft => BadgeTone.neutral,
  VehicleReviewStatus.submitted => BadgeTone.blue,
  VehicleReviewStatus.approved => BadgeTone.green,
  VehicleReviewStatus.rejected => BadgeTone.orange,
  VehicleReviewStatus.suspended => BadgeTone.red,
};

class ServiceCapabilitiesScreen extends StatefulWidget {
  const ServiceCapabilitiesScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ServiceCapabilitiesScreen> createState() =>
      _ServiceCapabilitiesScreenState();
}

class _ServiceCapabilitiesScreenState extends State<ServiceCapabilitiesScreen> {
  static const services = [
    'Vá lốp',
    'Kích bình',
    'Tiếp nhiên liệu',
    'Kéo xe',
    'Cứu hộ khác',
  ];
  late final selected = Set<String>.from(widget.state.serviceCapabilities);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dịch vụ hỗ trợ')),
    body: SafeArea(
      child: ScreenContent(
        bottomAction: AppButton(
          label: 'Lưu lựa chọn',
          icon: Icons.check_rounded,
          onPressed: () {
            widget.state.saveCapabilities(selected);
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
        children: [
          const PageHeading(
            title: 'Khả năng cứu hộ',
            subtitle: 'Chọn các dịch vụ bạn có thể hỗ trợ.',
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final service in services)
                  CheckboxListTile(
                    value: selected.contains(service),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        selected.add(service);
                      } else {
                        selected.remove(service);
                      }
                    }),
                    title: Text(service, style: AppType.body),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.navy,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    dense: true,
                  ),
              ],
            ),
          ),
          const InfoBanner(
            title: 'Lựa chọn trên thiết bị',
            message: 'Năng lực dịch vụ chưa được gửi hoặc xác minh.',
            icon: Icons.info_outline_rounded,
            tone: BadgeTone.orange,
          ),
          StatusBadge(
            label: 'Hồ sơ: ${widget.state.partnerStatus.label}',
            tone: _partnerTone(widget.state.partnerStatus),
          ),
        ],
      ),
    ),
  );
}

BadgeTone _partnerTone(PartnerReviewStatus status) => switch (status) {
  PartnerReviewStatus.draft => BadgeTone.neutral,
  PartnerReviewStatus.submitted => BadgeTone.blue,
  PartnerReviewStatus.approved => BadgeTone.green,
  PartnerReviewStatus.rejected => BadgeTone.orange,
  PartnerReviewStatus.suspended => BadgeTone.red,
};
