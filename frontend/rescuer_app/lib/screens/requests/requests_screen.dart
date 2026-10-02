import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/app_theme.dart';
import '../../models/active_job.dart';
import '../../models/request_preview.dart';
import '../../models/rescuer_status.dart';
import '../../widgets/app_components.dart';
import '../active_job/active_job_screen.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key, required this.state});
  final AppState state;

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final preview = state.requestPreview;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              sliver: SliverList.list(
                children: [
                  const PageHeading(
                    title: 'Đơn mới',
                    subtitle: 'Yêu cầu phù hợp với dịch vụ bạn hỗ trợ.',
                  ),
                  const SizedBox(height: 17),
                  const InfoBanner(
                    title: 'Thông tin được giới hạn trước khi nhận',
                    message: 'Danh sách chỉ hiển thị vị trí gần đúng, dịch vụ, loại xe và khoảng cách ước tính.',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const _FilterChip(label: 'Phù hợp', selected: true),
                      _FilterChip(
                        label: state.isOnline
                            ? 'Đang trực tuyến'
                            : 'Đang offline',
                        selected: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  _FeedContent(
                    feedState: state.requestFeedState,
                    preview: preview,
                    onMap: () => _open(
                      context,
                      RequestMapScreen(state: state, preview: preview),
                    ),
                    onDetails: () => _open(
                      context,
                      RequestDetailsScreen(state: state, preview: preview),
                    ),
                    onRetry: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 38),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: selected ? AppColors.navy : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      border: Border.all(color: selected ? AppColors.navy : AppColors.line),
    ),
    alignment: Alignment.center,
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : AppColors.muted,
      ),
    ),
  );
}

class _FeedContent extends StatelessWidget {
  const _FeedContent({
    required this.feedState,
    required this.preview,
    required this.onMap,
    required this.onDetails,
    required this.onRetry,
  });
  final RequestFeedState feedState;
  final RequestPreview? preview;
  final VoidCallback onMap;
  final VoidCallback onDetails;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (feedState == RequestFeedState.ready && preview?.hasData == true) {
      return _RequestPreviewCard(
        preview: preview!,
        onMap: onMap,
        onDetails: onDetails,
      );
    }
    return switch (feedState) {
      RequestFeedState.loading => const StatePanel(
        kind: PanelKind.loading,
        title: 'Đang tải đơn phù hợp',
        message: 'Đang cập nhật danh sách đơn.',
      ),
      RequestFeedState.empty => StatePanel(
        kind: PanelKind.empty,
        title: 'Chưa có đơn phù hợp',
        message: 'Đơn mới sẽ hiển thị tại đây khi có yêu cầu phù hợp.',
        actionLabel: 'Mở bản đồ khu vực',
        onAction: onMap,
      ),
      RequestFeedState.expired => StatePanel(
        kind: PanelKind.unavailable,
        title: 'Danh sách cần cập nhật',
        message: 'Đơn có thể không còn khả dụng. Hãy tải lại danh sách.',
        actionLabel: 'Tải lại',
        onAction: onRetry,
      ),
      RequestFeedState.error => StatePanel(
        kind: PanelKind.error,
        title: 'Chưa tải được danh sách',
        message: 'Kết nối đang gặp sự cố. Vui lòng thử lại.',
        actionLabel: 'Thử lại',
        onAction: onRetry,
      ),
      RequestFeedState.unavailable => const StatePanel(
        kind: PanelKind.unavailable,
        title: 'Đơn mới chưa khả dụng',
        message:
            'Danh sách đơn sẽ xuất hiện khi dịch vụ nhận đơn được kết nối.',
      ),
      RequestFeedState.ready => const StatePanel(
        kind: PanelKind.empty,
        title: 'Chưa có đơn phù hợp',
        message: 'Đơn mới sẽ hiển thị tại đây khi có yêu cầu phù hợp.',
      ),
    };
  }
}

class _RequestPreviewCard extends StatelessWidget {
  const _RequestPreviewCard({
    required this.preview,
    required this.onMap,
    required this.onDetails,
  });
  final RequestPreview preview;
  final VoidCallback onMap;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(AppSpace.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.emergency_outlined, color: AppColors.orange, size: 21),
            SizedBox(width: 8),
            Expanded(child: Text('Yêu cầu cứu hộ', style: AppType.section)),
            StatusBadge(label: 'Đơn mới', tone: BadgeTone.blue),
          ],
        ),
        const SizedBox(height: 14),
        const MapPlaceholder(height: 148, showApproximateArea: true),
        const SizedBox(height: 14),
        _PreviewFields(preview: preview),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: 'Bản đồ',
              icon: Icons.map_outlined,
              kind: ButtonStyleKind.outline,
              onPressed: onMap,
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Xem chi tiết',
              icon: Icons.arrow_forward_rounded,
              onPressed: onDetails,
            ),
          ],
        ),
      ],
    ),
  );
}

class _PreviewFields extends StatelessWidget {
  const _PreviewFields({required this.preview});
  final RequestPreview preview;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _PreviewRow(
        icon: Icons.build_outlined,
        label: 'Dịch vụ',
        value: preview.serviceType,
      ),
      const Divider(height: 19),
      _PreviewRow(
        icon: Icons.directions_car_outlined,
        label: 'Loại xe',
        value: preview.vehicleType,
      ),
      const Divider(height: 19),
      _PreviewRow(
        icon: Icons.location_on_outlined,
        label: 'Vị trí gần đúng',
        value: preview.approximateLocation,
      ),
      const Divider(height: 19),
      _PreviewRow(
        icon: Icons.near_me_outlined,
        label: 'Khoảng cách ước tính',
        value: preview.estimatedDistanceKm == null
            ? null
            : '${preview.estimatedDistanceKm!.toStringAsFixed(1)} km',
      ),
    ],
  );
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.muted, size: 18),
      const SizedBox(width: 9),
      Expanded(child: Text(label, style: AppType.caption)),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          value ?? 'Chưa có dữ liệu',
          textAlign: TextAlign.end,
          style: AppType.body.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: value == null ? AppColors.muted : AppColors.ink,
          ),
        ),
      ),
    ],
  );
}

class RequestMapScreen extends StatelessWidget {
  const RequestMapScreen({super.key, required this.state, this.preview});
  final AppState state;
  final RequestPreview? preview;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bản đồ đơn mới')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          children: [
            Expanded(
              child: MapPlaceholder(
                height: double.infinity,
                showApproximateArea: preview?.approximateLocation != null,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            AppCard(
              child: preview?.hasData == true
                  ? _PreviewFields(preview: preview!)
                  : const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vị trí gần đúng', style: AppType.section),
                        SizedBox(height: 4),
                        Text(
                          'Chưa có đơn để hiển thị trên bản đồ.',
                          style: AppType.body,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpace.md),
            AppButton(
              label: 'Xem chi tiết nhận đơn',
              icon: Icons.arrow_forward_rounded,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      RequestDetailsScreen(state: state, preview: preview),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class RequestDetailsScreen extends StatelessWidget {
  const RequestDetailsScreen({super.key, required this.state, this.preview});
  final AppState state;
  final RequestPreview? preview;

  Future<void> _confirmAcceptance(BuildContext context) async {
    if (preview?.hasData != true) return;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (context) => const _AcceptanceConfirmation(),
    );
    if (accepted != true || !context.mounted) return;
    state.startLocalJob(
      ActiveJob(
        requestId: 'local-request',
        preview: preview!,
        status: RescueJobStatus.accepted,
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => ActiveJobScreen(state: state)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRequest = preview?.hasData == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đơn')),
      body: SafeArea(
        child: ScreenContent(
          bottomAction: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                label: 'Nhận đơn',
                icon: Icons.check_rounded,
                onPressed: hasRequest
                    ? () => _confirmAcceptance(context)
                    : null,
              ),
              const SizedBox(height: AppSpace.xs),
              AppButton(
                label: 'Quay lại',
                kind: ButtonStyleKind.quiet,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          children: [
            PageHeading(
              title: 'Thông tin đơn',
              subtitle: hasRequest
                  ? 'Thông tin cần thiết để cân nhắc tiếp nhận.'
                  : 'Thông tin đơn chưa khả dụng.',
            ),
            AppCard(
              child: hasRequest
                  ? _PreviewFields(preview: preview!)
                  : const StatePanel(
                      kind: PanelKind.unavailable,
                      title: 'Chưa có chi tiết đơn',
                      message: 'Thông tin sẽ hiển thị khi có yêu cầu phù hợp.',
                      compact: true,
                    ),
            ),
            const InfoBanner(
              title: 'Quyền riêng tư',
              message: 'Thông tin khách hàng sẽ hiển thị sau khi bạn nhận đơn.',
              icon: Icons.lock_outline_rounded,
              tone: BadgeTone.blue,
            ),
            if (!hasRequest)
              const Text(
                'Bạn chưa thể nhận đơn khi chưa có dữ liệu yêu cầu.',
                textAlign: TextAlign.center,
                style: AppType.caption,
              ),
          ],
        ),
      ),
    );
  }
}

class _AcceptanceConfirmation extends StatelessWidget {
  const _AcceptanceConfirmation();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Icon(
          Icons.fact_check_outlined,
          size: 42,
          color: AppColors.orange,
        ),
        const SizedBox(height: 13),
        const Text(
          'Bạn chắc chắn muốn nhận đơn này?',
          textAlign: TextAlign.center,
          style: AppType.section,
        ),
        const SizedBox(height: 8),
        const Text(
          'Đơn sẽ chuyển vào mục “Đang làm”.',
          textAlign: TextAlign.center,
          style: AppType.body,
        ),
        const SizedBox(height: 21),
        AppButton(
          label: 'Nhận đơn',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: AppSpace.sm),
        AppButton(
          label: 'Hủy',
          kind: ButtonStyleKind.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    ),
  );
}
