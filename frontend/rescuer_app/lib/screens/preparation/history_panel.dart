import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../models/backend_models.dart';
import '../../widgets/app_components.dart';
import 'preparation_components.dart';

class HistoryPanel extends StatelessWidget {
  const HistoryPanel({super.key, required this.c});
  final RescuerController c;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Lịch sử chuyến', style: AppType.pageTitle),
      const SizedBox(height: 8),
      const Text(
        'Các chuyến đã hoàn tất hoặc đã hủy và chi phí được ghi nhận.',
        style: AppType.body,
      ),
      const SizedBox(height: 16),
      AppButton(
        label: 'Tải lại lịch sử',
        icon: Icons.refresh,
        onPressed: c.working ? null : c.refreshHistory,
      ),
      const SizedBox(height: 16),
      if (c.historyStatus == FeedStatus.loading)
        const PreparationEmpty(
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
      for (final j in c.historyItems) ...[
        PreparationCard(
          key: ValueKey('history-${j.assignment.id}'),
          title: serviceLabels[j.service] ?? 'Dịch vụ cứu hộ',
          subtitle: customerVehicles[j.vehicle] ?? 'Phương tiện khác',
          icon: Icons.history,
          children: [
            StatusBadge(label: j.assignment.stateLabel),
            const SizedBox(height: 12),
            Text(
              formatMoney(j.assignment.totalVnd, j.assignment.currency),
              style: AppType.section,
            ),
            const SizedBox(height: 8),
            Text(
              'Thời gian: ${_time(j.assignment.completedAt ?? j.assignment.cancelledAt ?? j.assignment.acceptedAt)}',
              style: AppType.caption,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Xem chi tiết chuyến',
              kind: ButtonStyleKind.outline,
              onPressed: c.working
                  ? null
                  : () => c.loadHistoryDetail(j.assignment.id),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
      if (c.historyCursor != null)
        AppButton(
          label: 'Xem thêm lịch sử',
          onPressed: c.working ? null : () => c.refreshHistory(more: true),
        ),
      if (c.historyDetailLoading)
        const PreparationEmpty(
          title: 'Đang tải chi tiết',
          message: 'Đang kiểm tra thông tin chuyến.',
          icon: Icons.sync,
        ),
      if (c.historyDetailError != null)
        PreparationEmpty(
          title: 'Chưa tải được chi tiết',
          message: c.historyDetailError!,
          icon: Icons.cloud_off,
        ),
      if (c.historyDetail case final j?) ...[
        const SizedBox(height: 16),
        PreparationCard(
          title: 'Chi tiết chuyến đã kết thúc',
          subtitle: j.assignment.stateLabel,
          icon: Icons.assignment_outlined,
          children: [
            SelectableText(
              'Mã đơn: ${j.assignment.requestId}',
              style: AppType.caption,
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
          ],
        ),
      ],
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
