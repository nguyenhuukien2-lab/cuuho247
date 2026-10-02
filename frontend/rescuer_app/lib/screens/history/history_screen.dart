import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/app_theme.dart';
import '../../models/active_job.dart';
import '../../models/rescuer_status.dart';
import '../../widgets/app_components.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Lịch sử')),
      body: SafeArea(
        child: state.history.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(AppSpace.lg),
                child: Center(
                  child: StatePanel(
                    kind: PanelKind.empty,
                    title: 'Chưa có đơn trong lịch sử',
                    message: 'Đơn đã hoàn tất hoặc đã hủy sẽ hiển thị tại đây.',
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                itemCount: state.history.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpace.md),
                itemBuilder: (context, index) {
                  final job = state.history[index];
                  return _HistoryCard(
                    job: job,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HistoryDetailScreen(job: job),
                      ),
                    ),
                  );
                },
              ),
      ),
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.job, required this.onTap});
  final ActiveJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.preview.serviceType ?? 'Dịch vụ',
                    style: AppType.section,
                  ),
                ),
                StatusBadge(
                  label: job.status.label,
                  tone: job.status == RescueJobStatus.completed
                      ? BadgeTone.green
                      : BadgeTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              job.preview.vehicleType ?? 'Loại xe chưa có dữ liệu',
              style: AppType.body,
            ),
            if (job.quotedTotalVnd != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text('Báo giá: ${job.quotedTotalVnd} ₫', style: AppType.body),
            ],
            const SizedBox(height: AppSpace.sm),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Xem tóm tắt',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 5),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppColors.navy,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key, required this.job});
  final ActiveJob job;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tóm tắt đơn')),
    body: SafeArea(
      child: ScreenContent(
        children: [
          PageHeading(
            title: job.preview.serviceType ?? 'Chi tiết lịch sử',
            subtitle: 'Tóm tắt an toàn của đơn đã kết thúc.',
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledValue(
                  label: 'Dịch vụ',
                  value: job.preview.serviceType ?? 'Chưa có dữ liệu',
                ),
                const SizedBox(height: AppSpace.md),
                LabeledValue(
                  label: 'Loại xe',
                  value: job.preview.vehicleType ?? 'Chưa có dữ liệu',
                ),
                const SizedBox(height: AppSpace.md),
                LabeledValue(label: 'Trạng thái', value: job.status.label),
                if (job.finishedAt != null) ...[
                  const SizedBox(height: AppSpace.md),
                  LabeledValue(
                    label: 'Thời điểm kết thúc',
                    value: _formatDate(job.finishedAt!),
                  ),
                ],
                if (job.quotedTotalVnd != null) ...[
                  const SizedBox(height: AppSpace.md),
                  LabeledValue(
                    label: 'Tổng báo giá đề xuất',
                    value: '${job.quotedTotalVnd} ₫',
                  ),
                ],
              ],
            ),
          ),
          const InfoBanner(
            title: 'Quyền riêng tư',
            message: 'Lịch sử chỉ hiển thị tóm tắt dịch vụ và trạng thái.',
          ),
        ],
      ),
    ),
  );

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
