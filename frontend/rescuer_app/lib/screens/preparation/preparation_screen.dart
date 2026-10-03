import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../models/backend_models.dart';
import '../../widgets/app_components.dart';
import 'preparation_components.dart';
import 'preparation_forms.dart';
import 'active_job_panel.dart';
import 'history_panel.dart';
import 'ui_v2_components.dart';
import 'account_overview.dart';

class PreparationScreen extends StatefulWidget {
  const PreparationScreen({super.key, required this.controller});
  final RescuerController controller;
  @override
  State<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends State<PreparationScreen> {
  bool _dialogOpen = false;
  String _orderFilter = 'all';
  String? _displayUser;
  final Set<String> _ignoredRequests = {};
  final _accountEditor = GlobalKey();
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
      if (_displayUser != c.userId) {
        _displayUser = c.userId;
        _orderFilter = 'all';
        _ignoredRequests.clear();
      }
      if (!c.signedIn && !c.loading) return PreparationLogin(c: c);
      return Scaffold(
        appBar: PartnerHeader(
          page: const [
            'Trang Chủ',
            'Đơn Mới',
            'Đang Xử Lý',
            'Lịch Sử',
            'Tài Khoản',
          ][c.tab],
          onRefresh: c.working || c.loading
              ? null
              : c.tab == 2
              ? c.refreshActiveJob
              : c.tab == 3
              ? c.refreshHistory
              : c.tab == 1
              ? c.refreshRequests
              : c.refreshProfile,
          onLogout: c.working || c.loading ? null : () => _logout(c),
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
                    onRefresh: c.tab == 2
                        ? c.refreshActiveJob
                        : c.tab == 3
                        ? c.refreshHistory
                        : c.refreshProfile,
                    child: ListView(
                      key: ValueKey('${c.tab}-${c.accountSection}'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
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
                        else if (c.tab == 2)
                          ActiveJobPanel(c: c)
                        else if (c.tab == 3)
                          HistoryPanel(key: ValueKey(c.userId), c: c)
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
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping),
              label: 'Đang xử lý',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'Lịch sử',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Tài khoản',
            ),
          ],
        ),
      );
    },
  );
  List<Widget> _home(RescuerController c) => [
    PartnerHero(c: c),
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
    PreparationOnline(c: c),
    const SizedBox(height: 18),
    PreparationChecklist(c: c),
    const SizedBox(height: 18),
    if (!c.canOnline)
      AppButton(
        label: 'Hoàn tất điều kiện',
        icon: Icons.fact_check_outlined,
        onPressed: () => c.openSection(
          c.checklist
              .firstWhere((i) => !i.complete, orElse: () => c.checklist.last)
              .section,
        ),
      )
    else if (c.online && !c.hasActiveJob)
      AppButton(
        label: 'Xem yêu cầu cứu hộ mới',
        icon: Icons.notifications_active_outlined,
        onPressed: () => c.selectTab(1),
      )
    else if (!c.online && !c.hasActiveJob)
      AppButton(
        label: 'Bật online để nhận đơn',
        icon: Icons.power_settings_new,
        loading: c.working && c.onlineProgress != null,
        onPressed: c.working ? null : () => c.setOnline(true),
      ),
    if (c.hasActiveJob) ...[
      const SizedBox(height: 18),
      PreparationCard(
        title: 'Bạn có chuyến đang xử lý',
        subtitle: 'Xem thông tin khách hàng và điểm cứu hộ của chuyến đã nhận.',
        icon: Icons.local_shipping_outlined,
        children: [
          AppButton(
            label: 'Mở chuyến đang xử lý',
            onPressed: () => c.selectTab(2),
          ),
        ],
      ),
    ],
  ];
  List<Widget> _account(RescuerController c) => [
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountOverview(
          c: c,
          onEdit: _editSection,
          onLogout: c.working ? null : () => _logout(c),
        ),
        const SizedBox(height: 18),
        Wrap(
          key: _accountEditor,
          spacing: 8,
          runSpacing: 8,
          children: sectionLabels.entries
              .map(
                (e) => ChoiceChip(
                  label: Text(e.value),
                  avatar: Icon(sectionIcons[e.key], size: 18),
                  selected: c.accountSection == e.key,
                  labelStyle: TextStyle(
                    fontFamily: 'Roboto',
                    color: c.accountSection == e.key
                        ? Colors.white
                        : AppColors.navy,
                  ),
                  onSelected: (_) => _editSection(e.key),
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
      ],
    ),
  ];

  void _editSection(String section) {
    widget.controller.openSection(section);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final editor = _accountEditor.currentContext;
      if (mounted && editor != null) {
        Scrollable.ensureVisible(
          editor,
          duration: const Duration(milliseconds: 300),
          alignment: 0,
        );
      }
    });
  }

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
          onPressed: () => c.selectTab(2),
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
      const Text('Đơn cứu hộ trực tiếp', style: AppType.pageTitle),
      const SizedBox(height: 8),
      const Text(
        'Chỉ hiển thị khu vực gần đúng và khoảng cách ước tính.',
        style: AppType.caption,
      ),
      const SizedBox(height: 16),
      GpsSignalCard(c: c),
      const SizedBox(height: 16),
      LocalFilterBar(
        labels: const {
          'all': 'Tất cả',
          'towing': 'Kéo xe',
          'battery_tire': 'Kích bình / Vá lốp',
          'other': 'Dịch vụ khác',
        },
        selected: _orderFilter,
        onSelect: (filter) => setState(() => _orderFilter = filter),
      ),
      const SizedBox(height: 12),
      if (_ignoredRequests.isNotEmpty)
        TextButton.icon(
          onPressed: () => setState(_ignoredRequests.clear),
          icon: const Icon(Icons.undo_rounded),
          label: const Text('Hiện lại đơn đã bỏ qua trên thiết bị'),
        ),
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
      if (c.feedStatus == FeedStatus.ready && !c.requests.any(_showRequest))
        const PreparationEmpty(
          title: 'Không có đơn trong bộ lọc',
          message: 'Chọn Tất cả hoặc hiện lại đơn đã bỏ qua để xem danh sách.',
        ),
      for (final r in c.requests.where(_showRequest)) ...[
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
                  const StatusBadge(
                    label: 'Yêu cầu mới',
                    tone: BadgeTone.orange,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(customerVehicles[r.vehicle] ?? 'Phương tiện khác'),
              const SizedBox(height: 8),
              Text('Mã đơn: ${r.id}', style: AppType.caption),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.blueSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.orange,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Khu vực gần đúng: ${r.latitude.toStringAsFixed(3)}, ${r.longitude.toStringAsFixed(3)}',
                      style: AppType.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    StatusBadge(
                      label: 'Khoảng cách ước tính · ${r.distanceKm} km',
                      icon: Icons.route_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Thông tin liên hệ và vị trí chính xác được bảo vệ.',
                style: AppType.caption,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Bỏ qua',
                icon: Icons.close_rounded,
                kind: ButtonStyleKind.outline,
                onPressed: c.working
                    ? null
                    : () => setState(() => _ignoredRequests.add(r.id)),
              ),
              const SizedBox(height: 10),
              AppButton(
                key: ValueKey('claim-${r.id}'),
                label: c.claimingRequestId == r.id
                    ? 'Đang nhận đơn…'
                    : 'NHẬN ĐƠN NGAY',
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

  bool _showRequest(AvailableRequest r) =>
      !_ignoredRequests.contains(r.id) &&
      switch (_orderFilter) {
        'towing' => r.service == 'towing',
        'battery_tire' => ['battery', 'tire'].contains(r.service),
        'other' => !['towing', 'battery', 'tire'].contains(r.service),
        _ => true,
      };

  Future<void> _logout(RescuerController c) async {
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
    title: 'Điều kiện vận hành tiếp nhận',
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
                      const {
                            'profile': 'Hồ sơ đối tác',
                            'vehicles': 'Phương tiện chuyên dụng',
                            'services': 'Gói dịch vụ đăng ký',
                            'documents': 'Giấy tờ & Pháp lý',
                            'gps': 'Định vị viễn thông GPS',
                            'review': 'Hệ thống điều phối',
                          }[item.section] ??
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
      title: 'TRẠNG THÁI PHÁT TÍN HIỆU',
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
                    ? 'Đang trực tuyến'
                    : c.online
                    ? 'Online · cần cập nhật GPS'
                    : 'Đang Offline',
                style: AppType.section,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GpsSignalCard(c: c),
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
