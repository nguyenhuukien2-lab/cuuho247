import '../../app/mobile_ui.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/public_system_config.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../models/backend_models.dart';
import '../../widgets/app_components.dart';
import 'preparation_components.dart';
import 'preparation_forms.dart';
import 'active_job_panel.dart';
import 'gps_status_detail.dart';
import 'history_panel.dart';
import 'ui_v2_components.dart';
import 'account_overview.dart';
import 'new_request_preview.dart';
import 'partner_registration_screen.dart';

class PreparationScreen extends StatefulWidget {
  const PreparationScreen({
    super.key,
    required this.controller,
    this.startInProfile = false,
  });
  final RescuerController controller;
  final bool startInProfile;
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
    _accountOverview = !widget.startInProfile;
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
        _accountOverview = !widget.startInProfile;
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
                        : c.tab == 1
                        ? c.refreshRequests
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
                        RescueSpace.bottomSafe +
                            MediaQuery.viewPaddingOf(context).bottom,
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
        bottomNavigationBar: PartnerNavigationBar(
          selectedIndex: c.tab,
          onSelected: (index) {
            if (index == 4) setState(() => _accountOverview = true);
            c.selectTab(index);
          },
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
          PartnerHero(c: c),
          const SizedBox(height: 12),
          PreparationOnline(c: c, onEdit: _editSection),
          const SizedBox(height: 12),
          _currentWork(c),
          const SizedBox(height: 16),
          PreparationChecklist(c: c),
          const SizedBox(height: 16),
          const PartnerSection(
            title: 'Hiệu suất ca hôm nay',
            icon: Icons.query_stats,
            children: [
              Text(
                'Chưa có thống kê hoạt động trong ngày.',
                style: AppType.caption,
              ),
            ],
          ),
        ];

  Widget _currentWork(RescuerController c) => PartnerSection(
    key: const ValueKey('dashboard-current'),
    compact: true,
    title: c.hasActiveJob ? 'Ca đang xử lý' : 'Tiếp nhận cứu hộ',
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
        if (c.activeJob case final job?) ...[
          Text(
            serviceLabels[job.service] ?? 'Dịch vụ cứu hộ',
            style: AppType.section,
          ),
          if (job.address?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            LabeledValue(
              label: 'Vị trí hiện trường',
              value: job.address!,
              icon: Icons.near_me_outlined,
            ),
          ],
          const SizedBox(height: 14),
        ],
        AppButton(
          label: 'Tiếp tục tác nghiệp',
          icon: Icons.navigation_outlined,
          onPressed: () => c.selectTab(2),
        ),
      ] else ...[
        Text(
          c.jobStatus == JobStatus.empty
              ? 'Bạn đang rảnh'
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
              key: const ValueKey('dashboard-open-orders'),
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
            key: ValueKey(c.userId),
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
        PartnerSection(
          title: 'Đơn cứu hộ đang chờ tiếp nhận',
          icon: Icons.radar,
          background: RescueColors.containerHigh,
          children: [
            Text(
              c.locationReady ? 'GPS đã đồng bộ' : 'Đang chờ đồng bộ GPS',
              style: AppType.body,
            ),
            const SizedBox(height: 4),
            const Text(
              'Chỉ hiển thị đơn phù hợp với xe và dịch vụ của bạn',
              style: AppType.caption,
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
      PreparationFilterBar(
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
          title: 'Chưa có đơn phù hợp',
          message: 'Hãy bật Online và giữ GPS sẵn sàng',
          action: AppButton(
            label: 'Tải lại',
            kind: ButtonStyleKind.outline,
            onPressed: c.working ? null : c.refreshRequests,
          ),
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
    title: 'Kiểm tra sẵn sàng trước ca',
    subtitle:
        '${c.checklist.where((i) => i.complete).length}/${c.checklist.length} điều kiện đã đạt',
    icon: Icons.checklist,
    children: [
      LinearProgressIndicator(
        value: c.checklist.where((i) => i.complete).length / c.checklist.length,
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
                            'vehicles': 'Phương tiện cứu hộ',
                            'services': 'Dịch vụ đăng ký',
                            'documents': 'Giấy tờ & xác minh',
                            'gps': 'GPS & vị trí',
                            'review': 'Quyền hoạt động',
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
        .map((s) => s['service_code'])
        .toSet()
        .map(
          (code) =>
              code == 'tire' ? 'Vá lốp' : serviceLabels[code] ?? 'Dịch vụ khác',
        )
        .toSet()
        .toList();
    final synced = c.online && c.locationReady;
    return Container(
      key: const ValueKey('dashboard-work'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.circle,
                size: 12,
                color: c.online ? AppColors.success : Colors.white54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.online ? 'ĐANG TRỰC TUYẾN' : 'ĐANG NGOẠI TUYẾN',
                  style: RescueType.section.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
              Switch(
                value: c.online,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.success,
                onChanged:
                    !PublicSystemConfig.of(context).flag(
                          c.online
                              ? 'rescuer.offline_enabled'
                              : 'rescuer.online_enabled',
                        ) ||
                        (!c.online &&
                            PublicSystemConfig.of(
                              context,
                            ).flag('rescuer.maintenance', fallback: false)) ||
                        c.working ||
                        (!c.online && !c.canOnline)
                    ? null
                    : (v) => c.setOnline(v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.radar, color: Color(0xFFFFDBCA), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.hasActiveJob
                      ? 'Bạn đang có ca cứu hộ cần xử lý'
                      : c.online
                      ? 'Sẵn sàng tiếp nhận sự cố khẩn cấp'
                      : 'Bật online để tiếp nhận cứu hộ',
                  style: RescueType.body.copyWith(
                    color: const Color(0xFFFFDBCA),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            synced
                ? 'GPS đã đồng bộ cho phiên online. Các yêu cầu phù hợp sẽ được cập nhật từ hệ thống.'
                : c.gpsReady
                ? 'GPS thiết bị sẵn sàng. Vị trí chưa đồng bộ cho phiên online.'
                : 'Kiểm tra GPS và quyền vị trí trước khi hoạt động.',
            style: RescueType.caption.copyWith(color: const Color(0xFFD2E4FF)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  vehicle == null
                      ? 'Chưa chọn xe đang dùng'
                      : _vehicleLabel(vehicle),
                  style: RescueType.caption.copyWith(color: Colors.white),
                ),
              ),
              TextButton(
                key: const ValueKey('dashboard-choose-vehicle'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
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
          if (services.isNotEmpty)
            SingleChildScrollView(
              key: const ValueKey('work-services'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  for (final service in services.take(2))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: StatusBadge(label: service),
                    ),
                  if (services.length > 2)
                    Tooltip(
                      message: services.skip(2).join(' · '),
                      child: StatusBadge(
                        key: const ValueKey('work-services-more'),
                        label: '+${services.length - 2} dịch vụ',
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          AppButton(
            key: const ValueKey('toggle-online'),
            label: c.online ? 'Tạm dừng nhận đơn' : 'Bật Online',
            kind: c.online
                ? ButtonStyleKind.secondary
                : ButtonStyleKind.primary,
            icon: c.online
                ? Icons.pause_circle_outline
                : Icons.power_settings_new,
            loading: c.working && c.onlineProgress != null,
            onPressed:
                !PublicSystemConfig.of(context).flag(
                      c.online
                          ? 'rescuer.offline_enabled'
                          : 'rescuer.online_enabled',
                    ) ||
                    (!c.online &&
                        PublicSystemConfig.of(context)
                            .flag('rescuer.maintenance', fallback: false)) ||
                    c.working ||
                    (!c.online && !c.canOnline)
                ? null
                : () => c.setOnline(!c.online),
          ),
          GpsStatusDetail(c: c),
          TextButton.icon(
            key: const ValueKey('dashboard-gps'),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            icon: const Icon(Icons.gps_fixed, size: 18),
            label: const Text('Kiểm tra GPS'),
            onPressed: c.working ? null : () => onEdit('gps'),
          ),
          if (c.onlineProgress != null)
            Text(
              c.onlineProgress!,
              style: RescueType.caption.copyWith(color: Colors.white),
            ),
          if (c.onlineRecoveryRequired)
            const Text(
              'Cần kiểm tra phiên online và GPS.',
              style: TextStyle(color: Colors.white),
            ),
          if (!c.snapshot.approved) ...[
            const SizedBox(height: 8),
            Text(
              _reviewGuide(c),
              style: RescueType.caption.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              partnerApprovalMessage,
              style: RescueType.caption.copyWith(color: Colors.white70),
            ),
          ],
          if (!c.canOnline) ...[
            const SizedBox(height: 8),
            for (final blocker in c.onlineBlockers)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  blocker,
                  style: RescueType.caption.copyWith(
                    color: const Color(0xFFFFDBCA),
                  ),
                ),
              ),
          ],
        ],
      ),
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
      GpsStatusDetail(c: c, coordinates: true),
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
