import '../../app/mobile_ui.dart';

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
import 'new_request_preview.dart';
import 'partner_registration_screen.dart';

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
  bool _accountOverview = true;
  String? _lastAccountSection;
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
        _accountOverview = true;
        _lastAccountSection = null;
      }
      if (_lastAccountSection != c.accountSection) {
        if (_lastAccountSection != null) _accountOverview = false;
        _lastAccountSection = c.accountSection;
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
          online: c.online,
          onRefresh: c.working || c.loading
              ? null
              : c.tab == 2
              ? c.refreshActiveJob
              : c.tab == 3
              ? c.refreshHistory
              : c.tab == 1
              ? c.refreshRequests
              : c.refreshProfile,
          onBack: c.tab == 4 && !_accountOverview
              ? () {
                  setState(() => _accountOverview = true);
                  c.selectTab(4);
                }
              : null,
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
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        48 + MediaQuery.viewPaddingOf(context).bottom,
                      ),
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
                            kind: RescueFeedbackKind.error,
                            title: 'Chưa tải được hồ sơ',
                            message: 'Kiểm tra mạng hoặc phiên đăng nhập rồi thử tải lại.',
                            icon: Icons.cloud_off,
                          ),
                          const SizedBox(height: 16),
                          AppButton(
                            kind: ButtonStyleKind.secondary,
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
          height: 80,
          labelTextStyle: WidgetStatePropertyAll(
            AppType.status.copyWith(fontSize: 11, height: 1.15),
          ),
          onDestinationSelected: (index) {
            if (index == 4) setState(() => _accountOverview = true);
            c.selectTab(index);
          },
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
  List<Widget> _home(RescuerController c) => c.snapshot.profile == null
      ? [
          const Text('Hoàn thiện hồ sơ đối tác', style: AppType.pageTitle),
          const SizedBox(height: 12),
          const Text(partnerSeparateAccountMessage),
          const SizedBox(height: 16),
          const InfoBanner(
            title: 'Cần duyệt trước khi nhận đơn',
            message: partnerApprovalMessage,
            tone: BadgeTone.orange,
            icon: Icons.verified_user_outlined,
          ),
          const SizedBox(height: 16),
          PreparationProfile(key: ValueKey(c.userId), c: c),
        ]
      : [
          PreparationOnline(c: c, onEdit: _editSection),
          const SizedBox(height: 16),
          _currentWork(c),
          const SizedBox(height: 16),
          PartnerSection(
            key: const ValueKey('dashboard-orders'),
            title: 'Đơn mới phù hợp',
            icon: Icons.assignment_outlined,
            accent: AppColors.orange,
            children: [
              Text(_feedSummary(c), style: AppType.body),
              if (c.feedStatus == FeedStatus.ready && c.cursor != null)
                const Text('Trong danh sách đã tải', style: AppType.caption),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('dashboard-open-orders'),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Xem đơn mới'),
                  onPressed: c.working ? null : () => c.selectTab(1),
                ),
              ),
            ],
          ),
        ];

  String _feedSummary(RescuerController c) {
    if (c.hasActiveJob) return 'Tiếp tục chuyến trước khi nhận đơn mới.';
    if (!c.canOnline) return 'Hoàn thiện hồ sơ để tìm đơn.';
    if (!c.online) return 'Bật Online để tìm đơn phù hợp.';
    return switch (c.feedStatus) {
      FeedStatus.ready => 'Có ${c.requests.length} đơn phù hợp',
      FeedStatus.empty => 'Có 0 đơn phù hợp',
      FeedStatus.loading => 'Đang tìm đơn phù hợp',
      FeedStatus.error => 'Chưa tải được đơn mới',
      FeedStatus.unavailable => 'Mở Đơn mới để kiểm tra điều kiện.',
    };
  }

  Widget _currentWork(RescuerController c) => PartnerSection(
    key: const ValueKey('dashboard-current'),
    title: 'Công việc hiện tại',
    icon: Icons.local_shipping_outlined,
    accent: c.hasActiveJob ? AppColors.orange : AppColors.navy,
    children: [
      if (c.hasActiveJob) ...[
        Text(
          'Mã đơn: ${preparationDisplayCode((c.activeJob?.assignment ?? c.claimedAssignment)?.requestCode, prefix: 'CH')}',
          style: AppType.code,
        ),
        const SizedBox(height: 8),
        RescueStatusBadge(
          status: (c.activeJob?.assignment ?? c.claimedAssignment)?.state,
          label: (c.activeJob?.assignment ?? c.claimedAssignment)?.stateLabel,
        ),
        const SizedBox(height: 12),
        AppButton(label: 'Mở chuyến', onPressed: () => c.selectTab(2)),
      ] else ...[
        Text(
          c.jobStatus == JobStatus.empty
              ? 'Chưa có chuyến đang xử lý'
              : c.jobStatus == JobStatus.error
              ? 'Chưa kiểm tra được chuyến'
              : c.snapshot.approved
              ? 'Đang kiểm tra chuyến'
              : 'Duyệt hồ sơ để bắt đầu nhận đơn',
          style: AppType.body,
        ),
        if (c.jobStatus == JobStatus.empty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('current-open-orders'),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Xem đơn mới'),
              onPressed: c.working ? null : () => c.selectTab(1),
            ),
          ),
        if (c.jobStatus == JobStatus.error) ...[
          const SizedBox(height: 10),
          AppButton(
            label: 'Kiểm tra lại chuyến',
            kind: ButtonStyleKind.outline,
            onPressed: c.working ? null : c.refreshActiveJob,
          ),
        ],
      ],
    ],
  );

  List<Widget> _account(RescuerController c) => _accountOverview
      ? [
          AccountOverview(
            c: c,
            onEdit: _editSection,
            onLogout: c.working ? null : () => _logout(c),
          ),
        ]
      : [
          Text(
            sectionLabels[c.accountSection] ?? 'Hồ sơ đối tác',
            style: AppType.pageTitle,
          ),
          const SizedBox(height: 16),
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

  void _editSection(String section) {
    setState(() => _accountOverview = false);
    widget.controller.openSection(section);
  }

  List<Widget> _feed(RescuerController c, {bool embedded = false}) {
    if (c.hasActiveJob) {
      return [
        PreparationEmpty(
          embedded: embedded,
          title: 'Bạn đang xử lý một chuyến',
          message: 'Các đơn mới sẽ được tìm lại khi chuyến hiện tại kết thúc.',
          icon: Icons.local_shipping_outlined,
        ),
        const SizedBox(height: 16),
        if (!embedded)
          AppButton(
            label: 'Xem chuyến đang xử lý',
            onPressed: () => c.selectTab(2),
          ),
      ];
    }
    if (c.snapshot.approved && c.jobStatus != JobStatus.empty) {
      return [
        PreparationEmpty(
          embedded: embedded,
          title: 'Kiểm tra chuyến trước khi nhận đơn',
          message:
              c.jobError ?? 'Đang kiểm tra xem bạn có chuyến chưa kết thúc.',
          icon: Icons.sync,
        ),
        const SizedBox(height: 16),
        if (!embedded)
          AppButton(
            kind: ButtonStyleKind.secondary,
            label: 'Kiểm tra lại chuyến',
            loading: c.jobStatus == JobStatus.loading,
            onPressed: c.working ? null : c.refreshActiveJob,
          ),
      ];
    }
    if (!c.canOnline) {
      return [
        PreparationEmpty(
          embedded: embedded,
          title: 'Hoàn thiện để tìm đơn mới',
          message: 'Hồ sơ, xe và dịch vụ cần được duyệt.',
          icon: Icons.fact_check_outlined,
        ),
        const SizedBox(height: 18),
        if (!embedded) ...[
          PreparationChecklist(c: c),
          const SizedBox(height: 16),
        ],
        AppButton(
          label: 'Hoàn tất hồ sơ',
          onPressed: () =>
              _editSection(c.snapshot.profile == null ? 'profile' : 'review'),
        ),
      ];
    }
    if (!c.online) {
      return [
        PreparationEmpty(
          embedded: embedded,
          title: 'Bạn đang offline',
          message: 'Bật online tại Trang chủ để tìm yêu cầu cứu hộ phù hợp.',
          icon: Icons.radar,
        ),
        const SizedBox(height: 16),
        if (!embedded)
          AppButton(label: 'Về Trang chủ', onPressed: () => c.selectTab(0)),
      ];
    }
    return [
      if (!embedded) ...[
        const Text('Đơn mới phù hợp', style: AppType.pageTitle),
        const SizedBox(height: 16),
      ],
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
        kind: ButtonStyleKind.secondary,
        label: 'Cập nhật đơn mới',
        icon: Icons.refresh,
        onPressed: c.working ? null : c.refreshRequests,
      ),
      const SizedBox(height: 18),
      if (c.feedStatus == FeedStatus.loading)
        PreparationEmpty(
          embedded: embedded,
          kind: RescueFeedbackKind.loading,
          title: 'Đang tìm yêu cầu phù hợp',
          message: 'Đang đồng bộ vị trí và danh sách đơn mới.',
          icon: Icons.radar,
        ),
      if (c.feedStatus == FeedStatus.empty)
        PreparationEmpty(
          embedded: embedded,
          title: 'Chưa có yêu cầu phù hợp',
          message: 'Hãy bật online và giữ GPS sẵn sàng',
        ),
      if (c.feedStatus == FeedStatus.error)
        PreparationEmpty(
          embedded: embedded,
          kind: RescueFeedbackKind.error,
          title: 'Chưa tải được đơn mới',
          message: c.feedError ?? 'Thử cập nhật GPS và tải lại.',
          icon: Icons.cloud_off,
        ),
      if (c.feedStatus == FeedStatus.unavailable)
        TextButton.icon(
          onPressed: () => _editSection('gps'),
          icon: const Icon(Icons.my_location),
          label: const Text('Kiểm tra GPS'),
        ),
      if (c.feedStatus == FeedStatus.ready && !c.requests.any(_showRequest))
        PreparationEmpty(
          embedded: embedded,
          title: 'Không có đơn trong bộ lọc',
          message: 'Chọn Tất cả hoặc hiện lại đơn đã bỏ qua để xem danh sách.',
        ),
      for (final r in c.requests.where(_showRequest)) ...[
        NewRequestCard(
          embedded: embedded,
          request: r,
          onPreview: c.working ? null : () => _previewRequest(c, r),
          onIgnore: c.working
              ? null
              : () => setState(() => _ignoredRequests.add(r.id)),
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

  Future<void> _previewRequest(RescuerController c, AvailableRequest request) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        showDragHandle: false,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(RescueRadius.card),
          ),
        ),
        builder: (_) => NewRequestPreview(controller: c, request: request),
      );

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
  'pending' || 'submitted' =>
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
  const PreparationOnline({super.key, required this.c, required this.onEdit});
  final RescuerController c;
  final ValueChanged<String> onEdit;

  static String _vehicleLabel(Map<String, dynamic> vehicle) {
    final plate = vehicle['license_plate'] as String?;
    final name = vehicle['display_name'] as String?;
    return [
      if (plate?.trim().isNotEmpty == true) plate!,
      if (name?.trim().isNotEmpty == true) name!,
    ].join(' · ');
  }

  Future<void> _chooseVehicle(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => ListenableBuilder(
          listenable: c,
          builder: (context, _) => ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const Text('Chọn xe đang dùng', style: AppType.section),
              const SizedBox(height: 12),
              for (final vehicle in c.snapshot.vehicles.where(
                (v) => v['is_active'] == true,
              ))
                ListTile(
                  key: ValueKey('choose-vehicle-${vehicle['id']}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _vehicleLabel(vehicle).isEmpty
                        ? 'Xe chưa có thông tin hiển thị'
                        : _vehicleLabel(vehicle),
                  ),
                  subtitle: Text(
                    reviewLabels[vehicle['verification_status']] ??
                        'Chưa xác minh',
                  ),
                  trailing: vehicle['id'] == c.selectedVehicle
                      ? const Icon(Icons.check_circle, color: AppColors.success)
                      : null,
                  enabled: !c.online && !c.working,
                  onTap: () {
                    c.selectVehicle(vehicle['id'] as String);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final active = c.snapshot.vehicles
        .where((v) => v['is_active'] == true)
        .toList();
    final vehicle = active
        .where((v) => v['id'] == c.selectedVehicle)
        .firstOrNull;
    final services = c.snapshot.capabilities
        .where(
          (s) =>
              s['vehicle_id'] == c.selectedVehicle &&
              s['verification_status'] == 'approved' &&
              s['is_enabled'] == true,
        )
        .map((s) => serviceLabels[s['service_code']] ?? 'Dịch vụ đã duyệt')
        .toSet()
        .toList();
    final synced = c.online && c.locationReady;
    return PartnerSection(
      key: const ValueKey('dashboard-work'),
      title: 'Trạng thái làm việc',
      icon: Icons.radar,
      accent: synced && c.canOnline ? AppColors.success : AppColors.warning,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            StatusBadge(
              key: const ValueKey('work-online-status'),
              label: c.online ? 'Online' : 'Offline',
              tone: c.online ? BadgeTone.green : BadgeTone.orange,
              icon: Icons.circle,
            ),
            StatusBadge(
              label: synced
                  ? 'GPS đã đồng bộ'
                  : c.gpsReady
                  ? 'GPS sẵn sàng'
                  : 'GPS chưa sẵn sàng',
              tone: c.gpsReady ? BadgeTone.green : BadgeTone.orange,
              icon: Icons.my_location,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.local_shipping_outlined,
              size: 18,
              color: AppColors.muted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                vehicle == null
                    ? 'Chưa chọn xe đang dùng'
                    : _vehicleLabel(vehicle).isEmpty
                    ? 'Xe chưa có thông tin hiển thị'
                    : _vehicleLabel(vehicle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.body,
              ),
            ),
            TextButton(
              key: const ValueKey('dashboard-choose-vehicle'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: c.working || c.online
                  ? null
                  : active.isEmpty
                  ? () => onEdit('vehicles')
                  : () => _chooseVehicle(context),
              child: Text(active.isEmpty ? 'Thêm xe' : 'Đổi xe'),
            ),
          ],
        ),
        if (services.isEmpty)
          const Text(
            'Chưa có dịch vụ đã duyệt cho xe này',
            style: AppType.caption,
          )
        else
          Wrap(
            key: const ValueKey('work-services'),
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final service in services.take(2))
                StatusBadge(label: service),
              if (services.length > 2)
                Tooltip(
                  message: services.skip(2).join(' · '),
                  child: StatusBadge(
                    key: const ValueKey('work-services-more'),
                    label: '+${services.length - 2}',
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: AppButton(
                key: const ValueKey('toggle-online'),
                label: c.online ? 'Tắt Online' : 'Bật Online',
                kind: c.online
                    ? ButtonStyleKind.secondary
                    : ButtonStyleKind.primary,
                icon: c.online
                    ? Icons.pause_circle_outline
                    : Icons.power_settings_new,
                loading: c.working && c.onlineProgress != null,
                onPressed: c.working || (!c.online && !c.canOnline)
                    ? null
                    : () => c.setOnline(!c.online),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Kiểm tra GPS',
              child: TextButton.icon(
                key: const ValueKey('dashboard-gps'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.gps_fixed, size: 18),
                label: const Text('GPS'),
                onPressed: c.working ? null : () => onEdit('gps'),
              ),
            ),
          ],
        ),
        if (c.onlineProgress != null) ...[
          const SizedBox(height: 6),
          Text(c.onlineProgress!, style: AppType.caption),
        ],
        if (c.onlineRecoveryRequired) ...[
          const SizedBox(height: 6),
          const Text(
            'Cần kiểm tra phiên online và GPS.',
            style: AppType.caption,
          ),
        ],
        if (!c.snapshot.approved) ...[
          const SizedBox(height: 10),
          if ([
            'pending',
            'submitted',
          ].contains(c.snapshot.profile?['verification_status']))
            const Text('Chờ duyệt hồ sơ', style: AppType.body),
          ReviewBadge(c.snapshot.profile?['verification_status'] as String?),
          if (![
            'pending',
            'submitted',
          ].contains(c.snapshot.profile?['verification_status']))
            Text(_reviewGuide(c), style: AppType.body),
          const SizedBox(height: 6),
          const Text(partnerApprovalMessage, style: AppType.caption),
        ],
        if (!c.canOnline)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Điều kiện còn thiếu', style: AppType.body),
            iconColor: AppColors.warning,
            children: [
              for (final item in c.checklist.where((i) => !i.complete))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.error_outline,
                    color: AppColors.warning,
                  ),
                  title: Text(item.title, style: AppType.body),
                  subtitle: Text(item.detail, style: AppType.caption),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onEdit(item.section),
                ),
              for (final blocker in c.onlineBlockers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(blocker, style: AppType.caption),
                ),
            ],
          ),
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
        kind: ButtonStyleKind.secondary,
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
