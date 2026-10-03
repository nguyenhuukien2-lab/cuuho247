import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../widgets/app_components.dart';
import 'preparation_components.dart';
import 'job_progress_timeline.dart';
import 'job_finance_section.dart';

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
            subtitle: 'Cập nhật trạng thái để khách hàng theo dõi tiến độ',
            icon: Icons.route_outlined,
            children: [
              StatusBadge(label: assignment.stateLabel),
              const SizedBox(height: 18),
              JobProgressTimeline(assignment: assignment),
              if (assignment.nextState != null) ...[
                const SizedBox(height: 16),
                AppButton(
                  key: const ValueKey('advance-job'),
                  label: c.updatingJobState != null
                      ? 'Đang cập nhật…'
                      : assignment.nextActionLabel!,
                  icon: switch (assignment.nextState) {
                    'en_route' => Icons.navigation_outlined,
                    'arrived' => Icons.place_outlined,
                    _ => Icons.handyman_outlined,
                  },
                  loading: c.updatingJobState != null,
                  onPressed: c.canAdvanceJob ? c.advanceJob : null,
                ),
                if (c.jobStatus == JobStatus.error) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Tải lại chuyến để tiếp tục cập nhật tiến độ.',
                    style: AppType.caption,
                  ),
                ],
              ] else if (assignment.state == 'in_progress') ...[
                const SizedBox(height: 16),
                const InfoBanner(
                  title: 'Đang hỗ trợ khách',
                  message: 'Tiến độ đã được cập nhật. Giữ liên lạc với khách hàng trong quá trình hỗ trợ.',
                  icon: Icons.handyman_outlined,
                  tone: BadgeTone.green,
                ),
              ],
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
        if (assignment?.state == 'in_progress') ...[
          const SizedBox(height: 16),
          JobFinanceSection(
            key: ValueKey(assignment!.id),
            c: c,
            assignment: assignment,
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
