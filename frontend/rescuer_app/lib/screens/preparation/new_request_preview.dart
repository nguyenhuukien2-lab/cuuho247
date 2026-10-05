import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/mobile_ui.dart';
import '../../app/rescuer_controller.dart';
import '../../models/backend_models.dart';
import '../../widgets/app_components.dart';
import 'preparation_components.dart';
import 'ui_v2_components.dart';

String _requestCode(AvailableRequest request) {
  final code = request.requestCode?.trim();
  return code != null && RegExp(r'^CH-[0-9]+$').hasMatch(code)
      ? code
      : 'Chưa có mã';
}

String _distance(AvailableRequest request) =>
    request.availableDistanceKm == null
    ? 'Chưa có khoảng cách ước tính'
    : 'Khoảng cách ước tính · ${request.availableDistanceKm} km';

const _privacyMessage =
    'Thông tin khách hàng và địa chỉ chi tiết chỉ hiển thị sau khi nhận đơn và được cấp quyền.';

class NewRequestCard extends StatelessWidget {
  const NewRequestCard({
    super.key,
    required this.request,
    required this.onPreview,
    required this.onIgnore,
    this.embedded = false,
  });
  final AvailableRequest request;
  final VoidCallback? onPreview, onIgnore;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RequestHeading(request: request),
        const SizedBox(height: 10),
        _RequestService(request: request),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: AppColors.muted,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                request.hasApproximateLocation
                    ? 'Khu vực cứu hộ gần đúng'
                    : 'Chưa có tọa độ GPS',
                style: AppType.caption,
              ),
            ),
          ],
        ),
        if (request.availableDistanceKm != null) ...[
          const SizedBox(height: 4),
          Text(_distance(request), style: AppType.caption),
        ],
        const SizedBox(height: 12),
        AppButton(
          key: ValueKey('preview-${request.id}'),
          label: 'Xem trước',
          icon: Icons.visibility_outlined,
          onPressed: onPreview,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            label: const Text('Bỏ qua'),
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: onIgnore,
          ),
        ),
      ],
    );
    return embedded
        ? Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                content,
              ],
            ),
          )
        : AppCard(kind: RescueCardKind.order, child: content);
  }
}

class _RequestHeading extends StatelessWidget {
  const _RequestHeading({required this.request});
  final AvailableRequest request;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text('Mã đơn: ${_requestCode(request)}', style: RescueType.title),
      const StatusBadge(label: 'Yêu cầu mới', tone: BadgeTone.orange),
    ],
  );
}

class _RequestService extends StatelessWidget {
  const _RequestService({required this.request});
  final AvailableRequest request;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: RescueColors.accentSoft,
          borderRadius: BorderRadius.circular(RescueRadius.control),
        ),
        child: Icon(serviceIcon(request.service), color: AppColors.orange),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              serviceLabels[request.service] ?? 'Dịch vụ cứu hộ',
              style: AppType.section,
            ),
            const SizedBox(height: 4),
            Text(
              'Loại xe: ${customerVehicles[request.vehicle] ?? 'Xe khác'}',
              style: AppType.body,
            ),
          ],
        ),
      ),
    ],
  );
}

class _RequestArea extends StatelessWidget {
  const _RequestArea({required this.request});
  final AvailableRequest request;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: RescueColors.selected,
      borderRadius: BorderRadius.circular(RescueRadius.control),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.location_on_outlined, color: AppColors.navy),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.hasApproximateLocation
                    ? 'Khu vực cứu hộ gần đúng'
                    : 'Chưa có tọa độ GPS',
                style: RescueType.title,
              ),
              const SizedBox(height: 4),
              Text(_distance(request), style: AppType.body),
              const SizedBox(height: 4),
              const Text(
                'Địa chỉ chi tiết được bảo vệ trước khi nhận.',
                style: AppType.caption,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Uses only AvailableRequest's existing pre-claim projection.
class NewRequestPreview extends StatefulWidget {
  const NewRequestPreview({
    super.key,
    required this.controller,
    required this.request,
  });
  final RescuerController controller;
  final AvailableRequest request;

  @override
  State<NewRequestPreview> createState() => _NewRequestPreviewState();
}

class _NewRequestPreviewState extends State<NewRequestPreview> {
  late final String? _openingUser = widget.controller.userId;
  bool _claiming = false, _attempted = false;

  AvailableRequest? _currentRequest() {
    for (final request in widget.controller.requests) {
      if (request.id == widget.request.id) return request;
    }
    return null;
  }

  Future<void> _claim() async {
    final c = widget.controller;
    final request = _currentRequest();
    if (_claiming ||
        c.userId != _openingUser ||
        !c.canClaim ||
        request == null) {
      return;
    }
    setState(() {
      _claiming = true;
      _attempted = true;
    });
    final serial = c.claimSuccessSerial;
    await c.claimRequest(request);
    if (!mounted) return;
    if (c.userId != _openingUser || c.claimSuccessSerial > serial) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _claiming = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final sameUser = c.signedIn && c.userId == _openingUser;
      final current = sameUser ? _currentRequest() : null;
      final request = current ?? widget.request;
      final canClaim = sameUser && current != null && c.canClaim && !_claiming;
      final busy = _claiming || c.working;
      return PopScope(
        canPop: !busy,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Xem trước yêu cầu',
                            style: AppType.section,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng',
                          onPressed: busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (sameUser) ...[
                            _RequestHeading(request: request),
                            const SizedBox(height: 16),
                            _RequestService(request: request),
                            const SizedBox(height: 16),
                            _RequestArea(request: request),
                            const SizedBox(height: 16),
                            const InfoBanner(
                              title: 'Quyền riêng tư của khách hàng',
                              message: _privacyMessage,
                              icon: Icons.lock_outline_rounded,
                            ),
                            if (request.hasApproximateLocation)
                              ExpansionTile(
                                title: const Text('Xem tọa độ khu vực'),
                                subtitle: const Text(
                                  'Vị trí gần đúng, không phải điểm đón chính xác',
                                  style: AppType.caption,
                                ),
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: const EdgeInsets.only(
                                  bottom: 12,
                                ),
                                children: [
                                  Text(
                                    '${request.latitude!.toStringAsFixed(3)}, ${request.longitude!.toStringAsFixed(3)}',
                                    style: AppType.body,
                                  ),
                                ],
                              ),
                          ],
                          if (_attempted && c.error != null)
                            InfoBanner(
                              title: 'Chưa nhận được đơn',
                              message: c.error!,
                              tone: BadgeTone.red,
                            ),
                          if (!sameUser)
                            const Text(
                              'Phiên đăng nhập đã thay đổi. Đóng xem trước để tải lại danh sách.',
                              style: AppType.body,
                            )
                          else if (current == null && !_claiming)
                            const Text(
                              'Yêu cầu không còn trong danh sách đơn mới. Đóng xem trước và tải lại.',
                              style: AppType.body,
                            )
                          else if (!c.canClaim && !_claiming && !c.working)
                            const Text(
                              'Kiểm tra online, GPS và chuyến đang xử lý trước khi nhận đơn.',
                              style: AppType.body,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppButton(
                          key: ValueKey('claim-${widget.request.id}'),
                          label: _claiming ? 'Đang nhận đơn…' : 'Nhận đơn',
                          icon: Icons.check_circle_outline,
                          loading: _claiming,
                          onPressed: canClaim ? _claim : null,
                        ),
                        const SizedBox(height: 8),
                        AppButton(
                          label: 'Để sau',
                          kind: ButtonStyleKind.outline,
                          onPressed: busy
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
