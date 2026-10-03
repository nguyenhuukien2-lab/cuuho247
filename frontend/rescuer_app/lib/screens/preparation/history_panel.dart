import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../models/backend_models.dart';
import '../../widgets/app_components.dart';
import 'preparation_components.dart';
import 'ui_v2_components.dart';

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
      NavyPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_month_outlined, color: Colors.white70),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'NHẬT KÝ TÁC NGHIỆP',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if ([
              FeedStatus.ready,
              FeedStatus.empty,
            ].contains(c.historyStatus)) ...[
              Text(
                '${c.historyItems.length} chuyến đã tải',
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (c.historyItems.any(
                    (j) =>
                        j.assignment.state == 'completed' &&
                        j.assignment.totalVnd != null,
                  ) &&
                  c.historyItems
                      .where((j) => j.assignment.totalVnd != null)
                      .every((j) => j.assignment.currency == 'VND')) ...[
                const Text(
                  'Chi phí ghi nhận · các chuyến hoàn tất',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
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
                  style: const TextStyle(
                    color: AppColors.orange,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                c.historyCursor != null
                    ? 'Còn lịch sử chưa tải. Số liệu chỉ tính danh sách đã tải.'
                    : 'Theo lịch sử đã đồng bộ. Chưa bao gồm thanh toán.',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ] else
              const Text(
                'Tải lịch sử để xem chuyến và chi phí được ghi nhận.',
                style: TextStyle(color: Colors.white70),
              ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      const Text('Lịch sử chuyến', style: AppType.pageTitle),
      const SizedBox(height: 8),
      const Text(
        'Các chuyến đã hoàn tất hoặc đã hủy và chi phí được ghi nhận.',
        style: AppType.body,
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
      if (c.historyStatus == FeedStatus.ready && _visible.isEmpty)
        const PreparationEmpty(
          title: 'Chưa có chuyến ở mục này',
          message: 'Chọn Tất cả hoặc tải thêm lịch sử để xem các chuyến khác.',
        ),
      for (final j in _visible) ...[
        PreparationCard(
          key: ValueKey('history-${j.assignment.id}'),
          title: serviceLabels[j.service] ?? 'Dịch vụ cứu hộ',
          subtitle: customerVehicles[j.vehicle] ?? 'Phương tiện khác',
          icon: Icons.history,
          children: [
            StatusBadge(
              label: j.assignment.stateLabel,
              tone: j.assignment.state == 'completed'
                  ? BadgeTone.green
                  : BadgeTone.red,
              icon: j.assignment.state == 'completed'
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
            ),
            const SizedBox(height: 12),
            Text(
              formatMoney(j.assignment.totalVnd, j.assignment.currency),
              style: AppType.pageTitle.copyWith(color: AppColors.orange),
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
