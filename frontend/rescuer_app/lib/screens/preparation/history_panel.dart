import '../../app/mobile_ui.dart';
import '../../core/utils/display_code.dart';

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
      PartnerSection(
        title: 'Lịch sử chuyến',
        icon: Icons.history,
        children: [
          if ([
            FeedStatus.ready,
            FeedStatus.empty,
          ].contains(c.historyStatus)) ...[
            Text('${c.historyItems.length} chuyến đã tải', style: AppType.body),
            if (c.historyItems.any(
                  (j) =>
                      j.assignment.state == 'completed' &&
                      j.assignment.totalVnd != null,
                ) &&
                c.historyItems
                    .where((j) => j.assignment.totalVnd != null)
                    .every((j) => j.assignment.currency == 'VND')) ...[
              const SizedBox(height: 6),
              Text(
                'Chi phí đã ghi nhận: ${formatMoney(c.historyItems.where((j) => j.assignment.state == 'completed').fold<int>(0, (sum, j) => sum + (j.assignment.totalVnd ?? 0)), 'VND')}',
                style: AppType.body.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                c.historyCursor != null
                    ? 'Theo chuyến đã tải · còn lịch sử'
                    : 'Theo chuyến đã tải · chưa gồm thanh toán',
                style: AppType.caption,
              ),
            ],
          ] else
            const Text('Chuyến hoàn tất và đã hủy', style: AppType.caption),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          kind: RescueCardKind.history,
          child: ExpansionTile(
            key: ValueKey('expand-history-${j.assignment.id}'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 10),
            title: Text(
              'Mã đơn: ${displayCode(j.assignment.requestCode)}',
              style: AppType.code,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  serviceLabels[j.service] ?? 'Dịch vụ cứu hộ',
                  style: AppType.body,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    RescueStatusBadge(
                      status: j.assignment.state,
                      label: j.assignment.stateLabel,
                    ),
                    if (j.assignment.totalVnd != null)
                      Text(
                        formatMoney(
                          j.assignment.totalVnd,
                          j.assignment.currency,
                        ),
                        style: AppType.body.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
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
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  customerVehicles[j.vehicle] ?? 'Phương tiện khác',
                  style: AppType.body,
                ),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Xem chi tiết chuyến',
                kind: ButtonStyleKind.outline,
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
