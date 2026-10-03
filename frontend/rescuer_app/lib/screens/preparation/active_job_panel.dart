import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../widgets/app_components.dart';
import 'preparation_components.dart';

class ActiveJobPanel extends StatelessWidget {
  const ActiveJobPanel({super.key, required this.c});
  final RescuerController c;

  @override
  Widget build(BuildContext context) {
    final job = c.activeJob;
    final assignment = job?.assignment ?? c.claimedAssignment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Chuyến đang xử lý', style: AppType.pageTitle),
        const SizedBox(height: 8),
        const Text(
          'Thông tin của chuyến bạn đã nhận được hiển thị tại đây.',
          style: AppType.body,
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'Tải lại chuyến',
          icon: Icons.refresh,
          loading: c.jobStatus == JobStatus.loading,
          onPressed: c.working || !c.snapshot.approved
              ? null
              : c.refreshActiveJob,
        ),
        const SizedBox(height: 18),
        if (c.jobStatus == JobStatus.loading)
          const PreparationEmpty(
            title: 'Đang tải chuyến',
            message: 'Đang kiểm tra thông tin chuyến đã nhận.',
            icon: Icons.sync,
          ),
        if (c.jobStatus == JobStatus.error)
          PreparationEmpty(
            title: 'Chưa tải được thông tin chuyến',
            message: c.jobError ?? 'Kiểm tra kết nối rồi thử tải lại.',
            icon: Icons.cloud_off,
          ),
        if (c.jobStatus == JobStatus.empty)
          const PreparationEmpty(
            title: 'Chưa có chuyến đang xử lý',
            message: 'Bật online rồi vào Đơn mới để nhận yêu cầu phù hợp.',
            icon: Icons.local_shipping_outlined,
          ),
        if (c.jobStatus == JobStatus.unavailable)
          const PreparationEmpty(
            title: 'Chưa thể xem chuyến',
            message: 'Đăng nhập và kiểm tra trạng thái duyệt hồ sơ trước khi tiếp tục.',
            icon: Icons.verified_user_outlined,
          ),
        if (assignment != null) ...[
          const SizedBox(height: 16),
          PreparationCard(
            title: 'Trạng thái chuyến',
            subtitle: 'Chuyến được đồng bộ với hệ thống cứu hộ.',
            icon: Icons.route_outlined,
            children: [
              StatusBadge(label: _states[assignment.state] ?? 'Đang xử lý'),
              const SizedBox(height: 12),
              SelectableText(
                'Mã đơn: ${assignment.requestId}',
                style: AppType.caption,
              ),
              if (assignment.acceptedAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Nhận lúc: ${_time(assignment.acceptedAt!)}',
                  style: AppType.caption,
                ),
              ],
            ],
          ),
        ],
        if (job != null && c.jobStatus == JobStatus.ready) ...[
          const SizedBox(height: 16),
          PreparationCard(
            title: 'Yêu cầu cứu hộ',
            subtitle: 'Dịch vụ và phương tiện cần hỗ trợ.',
            icon: Icons.build_circle_outlined,
            children: [
              _field('Dịch vụ', serviceLabels[job.service] ?? 'Dịch vụ cứu hộ'),
              _field(
                'Xe khách',
                customerVehicles[job.vehicle] ?? 'Phương tiện khác',
              ),
              _field('Mô tả / ghi chú', job.description),
            ],
          ),
          const SizedBox(height: 16),
          PreparationCard(
            title: 'Liên hệ khách hàng',
            subtitle: 'Chỉ sử dụng thông tin liên hệ để hỗ trợ chuyến đã nhận.',
            icon: Icons.person_outline,
            children: [
              _field('Họ tên', job.contactName),
              _field('Số điện thoại', job.contactPhone),
            ],
          ),
          const SizedBox(height: 16),
          PreparationCard(
            title: 'Điểm cứu hộ',
            subtitle: 'Kiểm tra địa chỉ và vị trí với khách hàng.',
            icon: Icons.location_on_outlined,
            children: [
              _field('Địa chỉ / địa điểm', job.address),
              if (job.latitude != null && job.longitude != null)
                _field(
                  'Tọa độ',
                  '${job.latitude!.toStringAsFixed(6)}, ${job.longitude!.toStringAsFixed(6)}',
                ),
              const SizedBox(height: 8),
              const Text('Chưa có ảnh hiện trường.', style: AppType.caption),
            ],
          ),
        ],
        const SizedBox(height: 18),
        const Text(
          'Giữ liên lạc với khách hàng trong quá trình hỗ trợ.',
          style: AppType.caption,
        ),
      ],
    );
  }

  static const _states = {
    'accepted': 'Đã nhận đơn',
    'en_route': 'Đang đến điểm cứu hộ',
    'arrived': 'Đã đến điểm cứu hộ',
    'in_progress': 'Đang cứu hộ',
  };
  static String _time(DateTime value) {
    final t = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)} · ${two(t.day)}/${two(t.month)}/${t.year}';
  }

  static Widget _field(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.caption),
        const SizedBox(height: 4),
        SelectableText(
          value?.trim().isNotEmpty == true ? value! : 'Chưa được cung cấp',
          style: AppType.body,
        ),
      ],
    ),
  );
}
