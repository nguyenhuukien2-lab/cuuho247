import '../../app/mobile_ui.dart';
import '../../core/utils/display_code.dart';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../models/backend_models.dart';
import '../../widgets/app_components.dart';
import 'preparation_components.dart';
import 'ui_v2_components.dart';
import '../payment/job_payment_section.dart';

class HistoryPanel extends StatefulWidget {
  const HistoryPanel({super.key, required this.c});
  final RescuerController c;
  @override
  State<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends State<HistoryPanel> {
  String _filter = 'all';
  RescuerController get c => widget.c;
  List<HistoryJob> get _visible => c.historyItems
      .where((j) => _filter == 'all' || j.assignment.state == _filter)
      .toList();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        key: const ValueKey('history-summary'),
        width: double.infinity,
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
                const Icon(
                  Icons.query_stats,
                  color: AppColors.orange,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tổng kết hoạt động',
                    style: AppType.section.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if ([
              FeedStatus.ready,
              FeedStatus.empty,
            ].contains(c.historyStatus)) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _metric(
                        '${c.historyItems.length}',
                        'Chuyến đã tải',
                      ),
                    ),
                    Expanded(
                      child: _metric(
                        '${c.historyItems.where((j) => j.assignment.state == 'completed').length}',
                        'Hoàn tất',
                      ),
                    ),
                    Expanded(
                      child: _metric(
                        '${c.historyItems.where((j) => j.assignment.state == 'cancelled').length}',
                        'Đã hủy',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (c.historyItems.any(
                    (j) =>
                        j.assignment.state == 'completed' &&
                        j.assignment.totalVnd != null,
                  ) &&
                  c.historyItems
                      .where((j) => j.assignment.totalVnd != null)
                      .every((j) => j.assignment.currency == 'VND')) ...[
                Text(
                  'Chi phí đã ghi nhận',
                  style: AppType.caption.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  formatMoney(
                    c.historyItems
                        .where((j) => j.assignment.state == 'completed')
                        .fold<int>(
                          0,
                          (sum, j) => sum + (j.assignment.totalVnd ?? 0),
                        ),
                    'VND',
                  ),
                  style: AppType.pageTitle.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                c.historyCursor != null
                    ? 'Theo chuyến đã tải · còn lịch sử'
                    : 'Theo chuyến đã tải · chưa gồm thanh toán',
                style: AppType.caption.copyWith(color: Colors.white70),
              ),
            ] else
              Text(
                'Chuyến hoàn tất và đã hủy. Tải lịch sử để xem số liệu.',
                style: AppType.body.copyWith(color: Colors.white70),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      LocalFilterBar(
        labels: const {
          'all': 'Tất cả',
          'completed': 'Hoàn tất',
          'cancelled': 'Đã hủy',
        },
        selected: _filter,
        onSelect: (value) => setState(() => _filter = value),
      ),
      const SizedBox(height: 16),
      AppButton(
        kind: ButtonStyleKind.quiet,
        label: 'Tải lại lịch sử',
        icon: Icons.refresh,
        onPressed: c.working ? null : c.refreshHistory,
      ),
      const SizedBox(height: 16),
      if (c.historyStatus == FeedStatus.loading)
        const PreparationEmpty(
          kind: RescueFeedbackKind.loading,
          title: 'Đang tải lịch sử',
          message: 'Đang lấy các chuyến của bạn.',
          icon: Icons.sync,
        ),
      if (c.historyStatus == FeedStatus.empty)
        const PreparationEmpty(
          title: 'Chưa có lịch sử chuyến',
          message: 'Chuyến sẽ xuất hiện tại đây sau khi hoàn tất hoặc bị hủy.',
          icon: Icons.history,
        ),
      if (c.historyStatus == FeedStatus.error)
        PreparationEmpty(
          kind: RescueFeedbackKind.error,
          title: 'Chưa tải được lịch sử',
          message: c.historyError ?? 'Kiểm tra mạng và thử lại.',
          icon: Icons.cloud_off,
        ),
      if (c.historyStatus == FeedStatus.unavailable)
        const PreparationEmpty(
          title: 'Lịch sử của bạn',
          message: 'Bấm tải lại để xem những chuyến trước đây.',
          icon: Icons.history,
        ),
      if (c.historyStatus == FeedStatus.ready && _visible.isEmpty)
        const PreparationEmpty(
          title: 'Chưa có chuyến ở mục này',
          message: 'Chọn Tất cả hoặc tải thêm lịch sử để xem các chuyến khác.',
        ),
      for (final j in _visible) ...[
        AppCard(
          key: ValueKey('history-${j.assignment.id}'),
          kind: RescueCardKind.history,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: RescueColors.selected,
                    child: Icon(
                      serviceIcon(j.service),
                      color: AppColors.navy,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mã đơn: ${displayCode(j.assignment.requestCode)}',
                          style: RescueType.title,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${serviceLabels[j.service] ?? 'Dịch vụ cứu hộ'} · ${customerVehicles[j.vehicle] ?? 'Phương tiện khác'}',
                          style: AppType.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RescueStatusBadge(
                    status: j.assignment.state,
                    label: j.assignment.stateLabel,
                  ),
                  Text(
                    _time(
                      j.assignment.completedAt ??
                          j.assignment.cancelledAt ??
                          j.assignment.acceptedAt,
                    ),
                    style: AppType.caption,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RescueColors.selected,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const LabeledValue(
                  label: 'Địa điểm hỗ trợ',
                  value: 'Địa điểm không được cung cấp trong lịch sử',
                  icon: Icons.location_on_outlined,
                ),
              ),
              if (j.assignment.totalVnd != null) ...[
                const SizedBox(height: 12),
                const Text('Chi phí ca', style: AppType.caption),
                Text(
                  formatMoney(j.assignment.totalVnd, j.assignment.currency),
                  style: AppType.section,
                ),
              ],
              const Divider(height: 24),
              JobPaymentSection(
                key: ValueKey('history-payment-${j.assignment.id}'),
                c: c,
                assignment: j.assignment,
                history: true,
              ),
              const SizedBox(height: 8),
              AppButton(
                key: ValueKey('history-detail-${j.assignment.id}'),
                label: 'Xem chi tiết chuyến',
                icon: Icons.arrow_forward,
                kind: ButtonStyleKind.quiet,
                onPressed: c.working
                    ? null
                    : () => c.loadHistoryDetail(j.assignment.id),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      if (c.historyCursor != null)
        AppButton(
          kind: ButtonStyleKind.secondary,
          label: 'Xem thêm lịch sử',
          onPressed: c.working ? null : () => c.refreshHistory(more: true),
        ),
      if (c.historyDetailLoading)
        const PreparationEmpty(
          kind: RescueFeedbackKind.loading,
          title: 'Đang tải chi tiết',
          message: 'Đang kiểm tra thông tin chuyến.',
          icon: Icons.sync,
        ),
      if (c.historyDetailError != null)
        PreparationEmpty(
          kind: RescueFeedbackKind.error,
          title: 'Chưa tải được chi tiết',
          message: c.historyDetailError!,
          icon: Icons.cloud_off,
        ),
      if (c.historyDetail case final j?) ...[
        const SizedBox(height: 16),
        PreparationCard(
          title: 'Chi tiết chuyến đã kết thúc',
          kind: RescueCardKind.history,
          subtitle: j.assignment.stateLabel,
          icon: Icons.assignment_outlined,
          children: [
            SelectableText(
              'Mã đơn: ${displayCode(j.assignment.requestCode)}',
              style: RescueType.code,
            ),
            if (j.assignment.hasQuote)
              Text(
                'Mã báo giá: ${displayCode(j.assignment.quoteCode)}',
                style: RescueType.code,
              ),
            const SizedBox(height: 12),
            Text(
              formatMoney(j.assignment.totalVnd, j.assignment.currency),
              style: AppType.section,
            ),
            const SizedBox(height: 12),
            for (final event in j.events)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${_state(event.state)} · ${_time(event.occurredAt)}',
                  style: AppType.caption,
                ),
              ),
            JobPaymentSection(
              key: ValueKey('history-detail-payment-${j.assignment.id}'),
              c: c,
              assignment: j.assignment,
            ),
          ],
        ),
      ],
    ],
  );
  static Widget _metric(String value, String label) => Column(
    children: [
      Text(value, style: AppType.pageTitle.copyWith(color: Colors.white)),
      const SizedBox(height: 4),
      Text(
        label,
        textAlign: TextAlign.center,
        style: AppType.caption.copyWith(color: Colors.white70),
      ),
    ],
  );
  static String _state(String? s) =>
      const {
        'accepted': 'Đã nhận',
        'en_route': 'Đang di chuyển',
        'arrived': 'Đã đến nơi',
        'in_progress': 'Đang hỗ trợ',
        'completed': 'Đã hoàn tất',
        'cancelled': 'Đã hủy',
      }[s] ??
      'Cập nhật chuyến';
  static String _time(DateTime? value) {
    if (value == null) return 'Chưa có thời gian';
    final t = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)} · ${two(t.day)}/${two(t.month)}/${t.year}';
  }
}
