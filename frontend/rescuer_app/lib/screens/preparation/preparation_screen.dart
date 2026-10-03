import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../models/backend_models.dart';
import '../../widgets/app_components.dart';
import 'preparation_components.dart';
import 'preparation_forms.dart';
import 'active_job_panel.dart';

class PreparationScreen extends StatefulWidget {
  const PreparationScreen({super.key, required this.controller});
  final RescuerController controller;
  @override
  State<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends State<PreparationScreen> {
  bool _dialogOpen = false;
  late int _shownClaimSerial;
  late int _shownJobUpdateSerial;
  @override
  void initState() {
    super.initState();
    _shownClaimSerial = widget.controller.claimSuccessSerial;
    _shownJobUpdateSerial = widget.controller.jobUpdateSerial;
    widget.controller.addListener(_locationPrompt);
    widget.controller.addListener(_claimPrompt);
    widget.controller.addListener(_jobUpdatePrompt);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_locationPrompt);
    widget.controller.removeListener(_claimPrompt);
    widget.controller.removeListener(_jobUpdatePrompt);
    super.dispose();
  }

  void _jobUpdatePrompt() {
    final c = widget.controller;
    if (c.jobUpdateSerial == _shownJobUpdateSerial) return;
    _shownJobUpdateSerial = c.jobUpdateSerial;
    final message = c.jobUpdateMessage;
    final failed = c.jobUpdateFailed;
    final uid = c.userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || message == null || uid == null || c.userId != uid) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: failed ? AppColors.danger : AppColors.navy,
          ),
        );
    });
  }

  void _claimPrompt() {
    final c = widget.controller;
    if (c.claimSuccessSerial == _shownClaimSerial) return;
    _shownClaimSerial = c.claimSuccessSerial;
    final uid = c.userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || uid == null || c.userId != uid) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Đã nhận đơn thành công.')),
        );
    });
  }

  void _locationPrompt() {
    final help = widget.controller.locationHelp;
    if (!mounted || help == null || _dialogOpen) return;
    _dialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      widget.controller.clearLocationHelp();
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(
            help == LocationHelp.disabled
                ? Icons.location_disabled
                : Icons.location_on_outlined,
            color: AppColors.orange,
          ),
          title: Text(
            help == LocationHelp.disabled
                ? 'Bật GPS để hoạt động'
                : help == LocationHelp.precision
                ? 'Cần vị trí chính xác'
                : 'Cho phép vị trí',
          ),
          content: Text(
            help == LocationHelp.disabled
                ? 'Mở Cài đặt vị trí và bật GPS. Sau đó quay lại ứng dụng và bấm kiểm tra GPS.'
                : 'Trong Cài đặt → Ứng dụng → Cứu Hộ 24/7 Đối tác → Quyền → Vị trí, chọn cho phép khi dùng ứng dụng và bật vị trí chính xác. Sau đó thử lại.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mở Cài đặt'),
            ),
          ],
        ),
      );
      _dialogOpen = false;
      if (open == true && mounted) {
        unawaited(widget.controller.openLocationSettings(help));
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      if (!c.signedIn && !c.loading) return PreparationLogin(c: c);
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Cứu Hộ 24/7 Đối tác',
            maxLines: 2,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'Tải lại hồ sơ',
              onPressed: c.working || c.loading ? null : c.refreshProfile,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: c.working || c.loading
                  ? null
                  : () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Đăng xuất?'),
                          content: const Text(
                            'Ứng dụng sẽ tắt online trước khi đăng xuất nếu có kết nối.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Ở lại'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Đăng xuất'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true) await c.signOut();
                    },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: c.loading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Đang tải hồ sơ đối tác…'),
                  ],
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: RefreshIndicator(
                    onRefresh: c.tab == 3
                        ? c.refreshActiveJob
                        : c.refreshProfile,
                    child: ListView(
                      key: ValueKey('${c.tab}-${c.accountSection}'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                      children: [
                        if (c.working) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: 12),
                        ],
                        if (c.error != null) ...[
                          InfoBanner(
                            title: 'Chưa thể hoàn tất',
                            message: c.error!,
                            icon: Icons.error_outline,
                            tone: BadgeTone.red,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (c.notice != null) ...[
                          InfoBanner(
                            title: 'Đã cập nhật',
                            message: c.notice!,
                            icon: Icons.check_circle_outline,
                            tone: BadgeTone.green,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (!c.snapshotLoaded) ...[
                          const PreparationEmpty(
                            title: 'Chưa tải được hồ sơ',
                            message: 'Kiểm tra mạng hoặc phiên đăng nhập rồi thử tải lại.',
                            icon: Icons.cloud_off,
                          ),
                          const SizedBox(height: 16),
                          AppButton(
                            label: 'Thử tải lại hồ sơ',
                            onPressed: c.working ? null : c.refreshProfile,
                          ),
                        ] else if (c.tab == 0)
                          ..._home(c)
                        else if (c.tab == 1)
                          ..._feed(c)
                        else if (c.tab == 3)
                          ActiveJobPanel(c: c)
                        else
                          ..._account(c),
                      ],
                    ),
                  ),
                ),
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: c.tab,
          onDestinationSelected: c.selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.radar_outlined),
              selectedIcon: Icon(Icons.radar),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Đơn mới',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Tài khoản',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping),
              label: 'Đang xử lý',
            ),
          ],
        ),
      );
    },
  );
  List<Widget> _home(RescuerController c) => [
    Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navySoft],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                color: AppColors.orange,
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                'ĐỒNG HÀNH CÙNG ĐỐI TÁC',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Xin chào, ${c.snapshot.profile?['full_name'] ?? 'đối tác mới'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hoàn thiện hồ sơ, chọn dịch vụ và sẵn sàng hỗ trợ người cần cứu hộ.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    ),
    const SizedBox(height: 18),
    PreparationCard(
      title: c.snapshot.profile == null
          ? 'Tạo hồ sơ người cứu hộ'
          : 'Trạng thái hồ sơ',
      subtitle: 'Thông tin được kiểm tra để bảo đảm chất lượng cứu hộ.',
      icon: Icons.verified_user_outlined,
      children: [
        ReviewBadge(c.snapshot.profile?['verification_status'] as String?),
        const SizedBox(height: 12),
        Text(_reviewGuide(c)),
        if (c.snapshot.profile == null) ...[
          const SizedBox(height: 14),
          AppButton(
            label: 'Tạo hồ sơ',
            onPressed: () => c.openSection('profile'),
          ),
        ],
      ],
    ),
    const SizedBox(height: 18),
    PreparationChecklist(c: c),
    const SizedBox(height: 18),
    PreparationOnline(c: c),
    if (c.hasActiveJob) ...[
      const SizedBox(height: 18),
      PreparationCard(
        title: 'Bạn có chuyến đang xử lý',
        subtitle: 'Xem thông tin khách hàng và điểm cứu hộ của chuyến đã nhận.',
        icon: Icons.local_shipping_outlined,
        children: [
          AppButton(
            label: 'Mở chuyến đang xử lý',
            onPressed: () => c.selectTab(3),
          ),
        ],
      ),
    ],
  ];
  List<Widget> _account(RescuerController c) => [
    const Text('Tài khoản đối tác', style: AppType.pageTitle),
    const SizedBox(height: 8),
    const Text(
      'Hoàn thiện từng phần để hồ sơ sẵn sàng xét duyệt.',
      style: AppType.body,
    ),
    const SizedBox(height: 18),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sectionLabels.entries
          .map(
            (e) => ChoiceChip(
              label: Text(e.value),
              avatar: Icon(sectionIcons[e.key], size: 18),
              selected: c.accountSection == e.key,
              onSelected: (_) => c.openSection(e.key),
            ),
          )
          .toList(),
    ),
    const SizedBox(height: 18),
    if (c.accountSection == 'profile')
      PreparationProfile(
        key: ValueKey('${c.userId}-${c.snapshot.profile?['version']}'),
        c: c,
      ),
    if (c.accountSection == 'vehicles') PreparationVehicles(c: c),
    if (c.accountSection == 'services')
      PreparationServices(key: ValueKey(c.userId), c: c),
    if (c.accountSection == 'documents') PreparationDocuments(c: c),
    if (c.accountSection == 'review') PreparationReview(c: c),
    if (c.accountSection == 'gps') PreparationGps(c: c),
  ];
  List<Widget> _feed(RescuerController c) {
    if (c.hasActiveJob) {
      return [
        const PreparationEmpty(
          title: 'Bạn đang xử lý một chuyến',
          message: 'Các đơn mới sẽ được tìm lại khi chuyến hiện tại kết thúc.',
          icon: Icons.local_shipping_outlined,
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'Xem chuyến đang xử lý',
          onPressed: () => c.selectTab(3),
        ),
      ];
    }
    if (c.snapshot.approved && c.jobStatus != JobStatus.empty) {
      return [
        PreparationEmpty(
          title: 'Kiểm tra chuyến trước khi nhận đơn',
          message:
              c.jobError ?? 'Đang kiểm tra xem bạn có chuyến chưa kết thúc.',
          icon: Icons.sync,
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'Kiểm tra lại chuyến',
          loading: c.jobStatus == JobStatus.loading,
          onPressed: c.working ? null : c.refreshActiveJob,
        ),
      ];
    }
    if (!c.canOnline) {
      return [
        const PreparationEmpty(
          title: 'Hoàn thiện để tìm đơn mới',
          message:
              'Hoàn tất các mục dưới đây, gửi duyệt và chọn xe đủ điều kiện.',
          icon: Icons.fact_check_outlined,
        ),
        const SizedBox(height: 18),
        PreparationChecklist(c: c),
        const SizedBox(height: 16),
        AppButton(
          label: 'Hoàn tất hồ sơ',
          onPressed: () =>
              c.openSection(c.snapshot.profile == null ? 'profile' : 'review'),
        ),
      ];
    }
    if (!c.online) {
      return [
        const PreparationEmpty(
          title: 'Bạn đang offline',
          message: 'Bật online tại Trang chủ để tìm yêu cầu cứu hộ phù hợp.',
          icon: Icons.radar,
        ),
        const SizedBox(height: 16),
        AppButton(label: 'Về Trang chủ', onPressed: () => c.selectTab(0)),
      ];
    }
    return [
      const Text('Đơn mới gần bạn', style: AppType.pageTitle),
      const SizedBox(height: 8),
      const Text(
        'Chỉ hiển thị khu vực gần đúng và khoảng cách ước tính.',
        style: AppType.caption,
      ),
      const SizedBox(height: 16),
      AppButton(
        label: 'Cập nhật đơn mới',
        icon: Icons.refresh,
        onPressed: c.working ? null : c.refreshRequests,
      ),
      const SizedBox(height: 18),
      if (c.feedStatus == FeedStatus.loading)
        const PreparationEmpty(
          title: 'Đang tìm yêu cầu phù hợp',
          message: 'Đang đồng bộ vị trí và danh sách đơn mới.',
          icon: Icons.radar,
        ),
      if (c.feedStatus == FeedStatus.empty)
        const PreparationEmpty(
          title: 'Chưa có đơn mới phù hợp',
          message: 'Bạn vẫn đang online. Danh sách sẽ được cập nhật khi có yêu cầu trong khu vực và đúng dịch vụ.',
        ),
      if (c.feedStatus == FeedStatus.error)
        PreparationEmpty(
          title: 'Chưa tải được đơn mới',
          message: c.feedError ?? 'Thử cập nhật GPS và tải lại.',
          icon: Icons.cloud_off,
        ),
      if (c.feedStatus == FeedStatus.unavailable) PreparationGps(c: c),
      for (final r in c.requests) ...[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.build_circle_outlined,
                    color: AppColors.orange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      serviceLabels[r.service] ?? 'Dịch vụ cứu hộ',
                      style: AppType.section,
                    ),
                  ),
                  StatusBadge(label: '≈ ${r.distanceKm} km'),
                ],
              ),
              const SizedBox(height: 14),
              Text(customerVehicles[r.vehicle] ?? 'Phương tiện khác'),
              const SizedBox(height: 6),
              Text(
                'Khu vực gần đúng: ${r.latitude.toStringAsFixed(3)}, ${r.longitude.toStringAsFixed(3)}',
              ),
              const SizedBox(height: 10),
              const Text(
                'Thông tin liên hệ và vị trí chính xác được bảo vệ.',
                style: AppType.caption,
              ),
              const SizedBox(height: 16),
              AppButton(
                key: ValueKey('claim-${r.id}'),
                label: c.claimingRequestId == r.id
                    ? 'Đang nhận đơn…'
                    : 'Nhận đơn',
                icon: Icons.check_circle_outline,
                loading: c.claimingRequestId == r.id,
                onPressed: c.canClaim ? () => c.claimRequest(r) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (c.cursor != null)
        AppButton(
          label: 'Xem thêm',
          kind: ButtonStyleKind.outline,
          onPressed: c.working ? null : () => c.refreshRequests(more: true),
        ),
    ];
  }
}

String _reviewGuide(
  RescuerController c,
) => switch (c.snapshot.profile?['verification_status']) {
  'approved' =>
    'Hồ sơ đã được duyệt. Kiểm tra xe và dịch vụ trước khi bật online.',
  'submitted' =>
    'Hồ sơ đang được kiểm tra. Bấm tải lại để cập nhật kết quả xét duyệt.',
  'rejected' => 'Kiểm tra lại thông tin và giấy tờ, bổ sung rồi gửi duyệt lại.',
  'suspended' =>
    'Tài khoản đang tạm ngưng. Vui lòng liên hệ hỗ trợ để được hướng dẫn.',
  _ =>
    'Lưu thông tin, thêm xe, chọn dịch vụ và tải giấy tờ trước khi gửi duyệt.',
};

class PreparationChecklist extends StatelessWidget {
  const PreparationChecklist({super.key, required this.c});
  final RescuerController c;
  @override
  Widget build(BuildContext context) => PreparationCard(
    title: 'Điều kiện nhận đơn',
    subtitle: 'Hoàn thiện lần lượt để sẵn sàng hoạt động.',
    icon: Icons.checklist,
    children: [
      LinearProgressIndicator(
        value: c.checklist.where((i) => i.complete).length / 6,
        minHeight: 6,
        borderRadius: BorderRadius.circular(8),
      ),
      const SizedBox(height: 12),
      for (final item in c.checklist)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item.complete ? Icons.check_circle : Icons.error_outline,
                color: item.complete ? AppColors.success : AppColors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(item.detail, style: AppType.caption),
                    if (!item.complete)
                      TextButton(
                        onPressed: () => c.openSection(item.section),
                        child: const Text('Hoàn tất ngay'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class PreparationOnline extends StatelessWidget {
  const PreparationOnline({super.key, required this.c});
  final RescuerController c;
  @override
  Widget build(BuildContext context) {
    final active = c.snapshot.vehicles
        .where((v) => v['is_active'] == true)
        .toList();
    return PreparationCard(
      title: 'Trạng thái hoạt động',
      subtitle: 'Giữ ứng dụng mở khi online để cập nhật vị trí.',
      icon: Icons.radar,
      children: [
        Row(
          children: [
            Icon(
              c.online && c.locationReady
                  ? Icons.circle
                  : Icons.circle_outlined,
              color: c.online && c.locationReady
                  ? AppColors.success
                  : AppColors.muted,
              size: 12,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.onlineRecoveryRequired
                    ? 'Cần kiểm tra phiên online'
                    : c.online && c.locationReady
                    ? 'Đang Online'
                    : c.online
                    ? 'Online · cần cập nhật GPS'
                    : 'Đang Offline',
                style: AppType.section,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (active.isNotEmpty)
          DropdownButtonFormField<String>(
            key: ValueKey('${c.selectedVehicle}-${c.online}'),
            isExpanded: true,
            initialValue: active.any((v) => v['id'] == c.selectedVehicle)
                ? c.selectedVehicle
                : null,
            decoration: const InputDecoration(
              labelText: 'Xe hoạt động',
              prefixIcon: Icon(Icons.local_shipping_outlined),
            ),
            items: active
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
            onChanged: c.online || c.working ? null : c.selectVehicle,
          ),
        if (c.onlineBlockers.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final missing in c.onlineBlockers)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $missing', style: AppType.caption),
            ),
        ],
        const SizedBox(height: 16),
        // Keep a native switch as well as a large primary action for accessibility.
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(c.online ? 'Đang online' : 'Đang offline'),
          subtitle: const Text('Vị trí chính xác sẽ được xin khi bật online.'),
          value: c.online,
          onChanged: c.working || (!c.online && !c.canOnline)
              ? null
              : c.setOnline,
        ),
        AppButton(
          label: c.online ? 'Tắt Online' : 'Bật Online',
          icon: c.online
              ? Icons.pause_circle_outline
              : Icons.power_settings_new,
          loading: c.working && c.onlineProgress != null,
          onPressed: c.working || (!c.online && !c.canOnline)
              ? null
              : () => c.setOnline(!c.online),
        ),
        if (c.onlineProgress != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(c.onlineProgress!, style: AppType.caption),
          ),
        if (c.online) ...[
          const SizedBox(height: 12),
          AppButton(
            label: 'Cập nhật GPS và đơn mới',
            kind: ButtonStyleKind.outline,
            onPressed: c.working ? null : c.refreshRequests,
          ),
        ],
        if (!c.canOnline) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => c.openSection('review'),
            child: const Text('Hoàn tất hồ sơ'),
          ),
        ],
      ],
    );
  }
}

class PreparationGps extends StatelessWidget {
  const PreparationGps({super.key, required this.c});
  final RescuerController c;
  @override
  Widget build(BuildContext context) => PreparationCard(
    title: 'GPS & quyền vị trí',
    subtitle: 'Chỉ dùng vị trí khi bạn sử dụng ứng dụng. Không yêu cầu quyền vị trí nền.',
    icon: Icons.my_location,
    children: [
      Text(
        c.gpsReady
            ? 'Vị trí thiết bị đã sẵn sàng.'
            : 'Bật GPS và cho phép vị trí chính xác để tìm yêu cầu gần bạn.',
      ),
      const SizedBox(height: 16),
      AppButton(
        label: 'Kiểm tra GPS',
        icon: Icons.gps_fixed,
        onPressed: c.working ? null : c.checkGps,
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => c.openLocationSettings(LocationHelp.permission),
        child: const Text('Mở Cài đặt quyền vị trí'),
      ),
      TextButton(
        onPressed: () => c.openLocationSettings(LocationHelp.disabled),
        child: const Text('Mở Cài đặt GPS'),
      ),
    ],
  );
}

class PreparationReview extends StatelessWidget {
  const PreparationReview({super.key, required this.c});
  final RescuerController c;
  @override
  Widget build(BuildContext context) => PreparationCard(
    title: 'Gửi hồ sơ xét duyệt',
    subtitle: 'Hồ sơ được kiểm tra trước khi bạn hoạt động.',
    icon: Icons.verified_user_outlined,
    children: [
      ReviewBadge(c.snapshot.profile?['verification_status'] as String?),
      const SizedBox(height: 12),
      Text(_reviewGuide(c)),
      const SizedBox(height: 18),
      if (!c.snapshot.documentsReady && !c.snapshot.approved) ...[
        const Text(
          'Cần giấy tờ cá nhân và đăng ký cho ít nhất một xe hoạt động.',
        ),
        TextButton(
          onPressed: () => c.openSection('documents'),
          child: const Text('Bổ sung giấy tờ'),
        ),
      ],
      AppButton(
        label: 'Gửi hồ sơ duyệt',
        icon: Icons.send_outlined,
        onPressed: c.working || !c.snapshot.canSubmit ? null : c.submitProfile,
      ),
      const SizedBox(height: 10),
      const Text(
        'Xe và dịch vụ cũng cần được duyệt. Gửi hồ sơ không tự bật quyền online.',
        style: AppType.caption,
      ),
    ],
  );
}
