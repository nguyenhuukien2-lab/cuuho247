import '../core/utils/display_code.dart';
import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/app_theme.dart';
import '../app/user_session.dart';
import '../services/request_details_service.dart';
import '../services/request_photo_service.dart';
import '../services/customer_request_review_service.dart';
import '../widgets/customer_request_review_card.dart';
import '../widgets/request_photos_card.dart';
import '../widgets/rescue_widgets.dart';
import '../widgets/customer_ui.dart';
import '../widgets/request_timeline.dart';
import '../widgets/request_location_card.dart';
import '../services/location_service.dart';

class HistoryDetailsScreen extends StatefulWidget {
  const HistoryDetailsScreen(
      {super.key,
      required this.requestId,
      required this.controller,
      this.repository = const SupabaseRequestDetailsRepository(),
      this.photoRepository = const SupabaseRequestPhotoRepository(),
      this.reviewRepository = const SupabaseCustomerRequestReviewRepository()});
  final String requestId;
  final AppController controller;
  final RequestDetailsRepository repository;
  final RequestPhotoRepository photoRepository;
  final CustomerRequestReviewRepository reviewRepository;

  @override
  State<HistoryDetailsScreen> createState() => _HistoryDetailsScreenState();
}

class _HistoryDetailsScreenState extends State<HistoryDetailsScreen> {
  RequestDetails? details;
  bool loading = true;
  String? error;
  late final String? owner;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    owner = UserSession.userId;
    widget.controller.addListener(sessionChanged);
    load();
  }

  void sessionChanged() {
    if (UserSession.userId != owner) {
      generation++;
      setState(() {
        details = null;
        loading = false;
        error = 'Phiên đăng nhập đã thay đổi. Vui lòng quay lại và đăng nhập.';
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(sessionChanged);
    super.dispose();
  }

  Future<void> load() async {
    final version = ++generation;
    setState(() {
      loading = true;
      error = null;
      details = null;
    });
    try {
      final result = await widget.repository.load(widget.requestId);
      if (!mounted || version != generation) return;
      setState(() => details = result);
    } catch (_) {
      if (!mounted || version != generation) return;
      setState(
          () => error = 'Không tải được chi tiết yêu cầu. Vui lòng thử lại.');
    } finally {
      if (mounted && version == generation) setState(() => loading = false);
    }
  }

  String text(dynamic value) => value == null || value.toString().trim().isEmpty
      ? 'Chưa có thông tin'
      : value.toString();

  String time(dynamic value) {
    final date =
        value is DateTime ? value : DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Chưa có thông tin';
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  String status(dynamic value) => switch (value) {
        'searching' => 'Đang tìm người cứu hộ',
        'accepted' => 'Đã tiếp nhận',
        'arriving' => 'Đang đến',
        'in_progress' => 'Đang cứu hộ',
        'completed' => 'Hoàn tất',
        'cancelled' => 'Đã hủy',
        _ => 'Chưa có thông tin',
      };

  @override
  Widget build(BuildContext context) {
    final data = details;
    final row = data?.request ?? {};
    final service = RescueService.values
        .where((s) => s.name == row['service_code'])
        .firstOrNull;
    final stage = RequestStage.values
        .where((s) => s.databaseValue == row['status'])
        .firstOrNull;
    return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết yêu cầu')),
        body: SafeArea(
            top: false,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null || data == null
                    ? SingleChildScrollView(
                        padding: AppSpacing.page,
                        child: CustomerEmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Thông tin lần cứu hộ',
                            message: error ??
                                'Không tìm thấy yêu cầu trong lịch sử của bạn.',
                            action: UserSession.userId == owner
                                ? OutlinedButton.icon(
                                    onPressed: load,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Thử lại'))
                                : null))
                    : ListView(padding: AppSpacing.page, children: [
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: AppColors.selected,
                                borderRadius: BorderRadius.circular(12)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Thông tin yêu cầu',
                                      style: TextStyle(color: AppColors.navy)),
                                  const SizedBox(height: 8),
                                  Text(status(row['status']),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall),
                                  const SizedBox(height: 12),
                                  if (stage != null) StatusPill(stage: stage),
                                ])),
                        const SizedBox(height: 16),
                        InfoRow('Mã đơn',
                            displayCode(row['request_code'] as String?)),
                        InfoRow('Dịch vụ cứu hộ',
                            service?.label ?? 'Chưa có thông tin'),
                        InfoRow(
                            'Phương tiện',
                            switch (row['vehicle_kind']) {
                              'car' => 'Ô tô',
                              'motorbike' => 'Xe máy',
                              'truck' => 'Xe tải',
                              'other' => 'Khác',
                              _ => 'Chưa có thông tin'
                            }),
                        InfoRow('Trạng thái cuối cùng', status(row['status'])),
                        InfoRow('Thời gian tạo', time(row['created_at'])),
                        if (row['status'] == 'completed' ||
                            row['status'] == 'cancelled')
                          InfoRow(
                              row['status'] == 'completed'
                                  ? 'Thời gian hoàn tất'
                                  : 'Thời gian hủy',
                              time(data.terminalTime)),
                        if (row['contact_name'] is String &&
                            (row['contact_name'] as String).isNotEmpty)
                          InfoRow(
                              'Liên hệ',
                              displayCustomerName(
                                  row['contact_name'] as String)),
                        if (row['contact_phone'] is String &&
                            (row['contact_phone'] as String).isNotEmpty)
                          InfoRow('Điện thoại', row['contact_phone'] as String),
                        if (row['description'] is String &&
                            (row['description'] as String).isNotEmpty)
                          InfoRow('Mô tả', row['description'] as String),
                        if (row['quoted_price'] is num) ...[
                          const Divider(height: 24),
                          InfoRow('Mã báo giá',
                              displayCode(row['quote_code'] as String?)),
                          InfoRow('Chi phí / báo giá',
                              money((row['quoted_price'] as num).toInt())),
                        ],
                        const Divider(height: 32),
                        RequestLocationCard(
                            address: text(row['location_text']),
                            coordinates: row['latitude'] is num &&
                                    row['longitude'] is num
                                ? RescueCoordinates(
                                    (row['latitude'] as num).toDouble(),
                                    (row['longitude'] as num).toDouble())
                                : null),
                        const SizedBox(height: 24),
                        RequestPhotosCard(
                            requestId: widget.requestId,
                            customerId: owner,
                            isActive: true,
                            repository: widget.photoRepository),
                        const SizedBox(height: 24),
                        const SectionTitle('Timeline trạng thái'),
                        const SizedBox(height: 12),
                        if (data.events.isEmpty)
                          const Text('Chưa có lịch sử trạng thái.',
                              style: TextStyle(color: AppColors.muted)),
                        for (var i = 0; i < data.events.length; i++)
                          TimelineEntry(
                              title: status(data.events[i]['status']),
                              last: i == data.events.length - 1,
                              subtitle:
                                  '${time(data.events[i]['occurred_at'])}${data.events[i]['is_initial_snapshot'] == true ? '\nTrạng thái lưu ban đầu; không xác định thời điểm chuyển trạng thái.' : ''}'),
                        if (row['status'] == 'completed') ...[
                          const Divider(height: 32),
                          CustomerRequestReviewCard(
                              key: ValueKey(widget.requestId),
                              requestId: widget.requestId,
                              controller: widget.controller,
                              repository: widget.reviewRepository),
                        ],
                      ])));
  }
}
