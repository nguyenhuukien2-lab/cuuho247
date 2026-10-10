import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../widgets/customer_ui.dart';
import '../widgets/history_ui.dart';
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
    final controller = widget.controller;
    final items = controller.history
        .where((item) =>
            filter == HistoryFilter.all ||
            (filter == HistoryFilter.completed &&
                item.stage == RequestStage.completed) ||
            (filter == HistoryFilter.cancelled &&
                item.stage == RequestStage.cancelled))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final hasCounts = controller.history.isNotEmpty ||
        (!controller.loadingRequests && controller.loadError == null);
    final counts = hasCounts
        ? [
            controller.history.length,
            controller.history
                .where((r) => r.stage == RequestStage.completed)
                .length,
            controller.history
                .where((r) => r.stage == RequestStage.cancelled)
                .length
          ]
        : null;
    return Theme(
        data: Theme.of(context)
            .copyWith(scaffoldBackgroundColor: HistoryStyle.background),
        child: Material(
            color: HistoryStyle.background,
            child: Column(children: [
              HistoryHeader(onAccount: () => controller.selectTab(4)),
              Expanded(
                  child: ListView(
                      key: const PageStorageKey('history-scroll'),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                      children: [
                    HistorySummaryCard(
                        count: hasCounts ? controller.history.length : null,
                        completedCount: counts?[1]),
                    const SizedBox(height: 16),
                    HistoryFilterTabs(
                        selected: filter.index,
                        counts: counts,
                        onSelected: (index) => setState(
                            () => filter = HistoryFilter.values[index])),
                    if (controller.loadingRequests) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator()
                    ],
                    if (controller.loadError != null) ...[
                      const SizedBox(height: 16),
                      InlineNotice(controller.loadError!,
                          onRetry: controller.loadingRequests
                              ? null
                              : controller.refreshRequests)
                    ],
                    if (items.isEmpty &&
                        !controller.loadingRequests &&
                        controller.loadError == null) ...[
                      const SizedBox(height: 16),
                      HistoryEmptyState(
                          filterIndex: filter.index,
                          onRequest: controller.startRequest)
                    ],
                    for (final item in items) ...[
                      SizedBox(height: item == items.first ? 16 : 12),
                      HistoryTripCard(
                          request: item,
                          onDetails: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => HistoryDetailsScreen(
                                      requestId: item.id,
                                      controller: controller)))),
                    ],
                  ])),
            ])));
  }
}
