import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/app_theme.dart';
import '../widgets/rescue_widgets.dart';
import '../widgets/customer_ui.dart';
import 'history_details_screen.dart';

enum HistoryFilter { all, completed, cancelled }

class NewHistoryScreen extends StatefulWidget {
  const NewHistoryScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<NewHistoryScreen> createState() => _NewHistoryScreenState();
}

class _NewHistoryScreenState extends State<NewHistoryScreen> {
  HistoryFilter filter = HistoryFilter.all;
  @override
  Widget build(BuildContext context) {
    final items = widget.controller.history
        .where((item) =>
            filter == HistoryFilter.all ||
            (filter == HistoryFilter.completed &&
                item.stage == RequestStage.completed) ||
            (filter == HistoryFilter.cancelled &&
                item.stage == RequestStage.cancelled))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final groups = <String, List<RescueRequestData>>{};
    for (final item in items) {
      groups.putIfAbsent(customerDate(item.createdAt), () => []).add(item);
    }
    return ListView(
        key: const PageStorageKey('history-scroll'),
        padding: AppSpacing.page,
        children: [
          const ScreenHeader('Lịch sử cứu hộ',
              subtitle: 'Xem lại những lần hỗ trợ của bạn'),
          SegmentedButton<HistoryFilter>(
              segments: const [
                ButtonSegment(value: HistoryFilter.all, label: Text('Tất cả')),
                ButtonSegment(
                    value: HistoryFilter.completed, label: Text('Hoàn tất')),
                ButtonSegment(
                    value: HistoryFilter.cancelled, label: Text('Đã hủy')),
              ],
              selected: {
                filter
              },
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => filter = value.first)),
          if (widget.controller.loadingRequests) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator()
          ],
          if (widget.controller.loadError != null) ...[
            const SizedBox(height: 16),
            InlineNotice(widget.controller.loadError!,
                onRetry: widget.controller.loadingRequests
                    ? null
                    : widget.controller.refreshRequests)
          ],
          if (items.isEmpty &&
              !widget.controller.loadingRequests &&
              widget.controller.loadError == null)
            CustomerEmptyState(
                icon: Icons.history_rounded,
                title: 'Chưa có lịch sử phù hợp',
                message:
                    'Các yêu cầu đã hoàn thành hoặc hủy sẽ xuất hiện tại đây.',
                action: OutlinedButton.icon(
                    onPressed: widget.controller.startRequest,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Tạo yêu cầu cứu hộ'))),
          for (final group in groups.entries) ...[
            Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 8),
                child: Text(group.key,
                    style: const TextStyle(
                        color: AppColors.muted, fontWeight: FontWeight.w600))),
            for (final item in group.value)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _HistoryCard(
                      request: item,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => HistoryDetailsScreen(
                                  requestId: item.id,
                                  controller: widget.controller))))),
          ],
        ]);
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.request, required this.onTap});
  final RescueRequestData request;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: AppColors.selected,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Icon(serviceIcon(request.service),
                                  color: AppColors.navy)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(request.service.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                    customerDate(request.createdAt,
                                        includeTime: true),
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ])),
                          const Icon(Icons.chevron_right_rounded,
                              size: 22, color: AppColors.muted),
                        ]),
                    const SizedBox(height: 8),
                    StatusPill(stage: request.stage),
                    const SizedBox(height: 8),
                    Text(request.address,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(vehicleIcon(request.vehicle),
                                size: 22, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Text(request.vehicle.label,
                                style: const TextStyle(color: AppColors.muted)),
                          ]),
                          if (request.price != null)
                            Text(money(request.price),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy)),
                        ]),
                  ]))));
}
