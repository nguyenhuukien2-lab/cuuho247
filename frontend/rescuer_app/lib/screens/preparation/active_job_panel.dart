import '../../app/mobile_ui.dart';
import '../../core/utils/display_code.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../widgets/app_components.dart';
import 'preparation_components.dart';
import 'job_progress_timeline.dart';
import 'job_finance_section.dart';
import 'ui_v2_components.dart';

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
        if (assignment != null) ...[
          NavyPanel(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MÃ ĐƠN · ${displayCode(assignment.requestCode)}',
                        style: RescueType.code,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        assignment.stateLabel,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        AppButton(
          kind: ButtonStyleKind.secondary,
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
            kind: RescueFeedbackKind.loading,
            title: 'Đang tải chuyến',
            message: 'Đang kiểm tra thông tin chuyến đã nhận.',
            icon: Icons.sync,
          ),
        if (c.jobStatus == JobStatus.error)
          PreparationEmpty(
            kind: RescueFeedbackKind.error,
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
              RescueStatusBadge(
                status: assignment.state,
                label: assignment.stateLabel,
              ),
              const SizedBox(height: 18),
              JobProgressTimeline(assignment: assignment),
              if (assignment.state == 'in_progress') ...[
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
                'Mã đơn: ${displayCode(assignment.requestCode)}',
                style: RescueType.code,
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
              if (job.contactPhone != null &&
                  RegExp(r'^\+?[0-9]{8,15}$').hasMatch(job.contactPhone!))
                AppButton(
                  label: 'Gọi ngay',
                  icon: Icons.phone_in_talk_outlined,
                  kind: ButtonStyleKind.secondary,
                  onPressed: () => _open(
                    context,
                    Uri(scheme: 'tel', path: job.contactPhone),
                    'Không mở được ứng dụng gọi điện. Bạn có thể sao chép số ở trên.',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          PreparationCard(
            title: 'Điểm cứu hộ',
            subtitle: 'Kiểm tra địa chỉ và vị trí với khách hàng.',
            icon: Icons.location_on_outlined,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.blueSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.pin_drop_rounded,
                      color: AppColors.orange,
                      size: 32,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vị trí điểm cứu hộ\nChưa tích hợp bản đồ trực tiếp',
                        style: AppType.body,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _field('Địa chỉ / địa điểm', job.address),
              if (job.latitude != null && job.longitude != null)
                _field(
                  'Tọa độ',
                  '${job.latitude!.toStringAsFixed(6)}, ${job.longitude!.toStringAsFixed(6)}',
                ),
              if (job.latitude != null && job.longitude != null) ...[
                const SizedBox(height: 8),
                AppButton(
                  kind: ButtonStyleKind.secondary,
                  label: 'Mở Google Maps',
                  icon: Icons.map_outlined,
                  onPressed: () => _open(
                    context,
                    Uri.https('www.google.com', '/maps/search/', {
                      'api': '1',
                      'query': '${job.latitude},${job.longitude}',
                    }),
                    'Không mở được bản đồ. Kiểm tra ứng dụng bản đồ hoặc trình duyệt.',
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text('Chưa có ảnh hiện trường.', style: AppType.caption),
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
        if (assignment?.nextState != null) ...[
          const SizedBox(height: 20),
          AppButton(
            key: const ValueKey('advance-job'),
            label: c.updatingJobState != null
                ? 'Đang cập nhật…'
                : switch (assignment!.nextState) {
                    'en_route' => 'ĐANG ĐẾN ĐIỂM CỨU HỘ',
                    'arrived' => 'XÁC NHẬN: ĐÃ ĐẾN NƠI',
                    _ => 'BẮT ĐẦU HỖ TRỢ',
                  },
            icon: Icons.navigation_outlined,
            loading: c.updatingJobState != null,
            onPressed: c.canAdvanceJob ? c.advanceJob : null,
          ),
          if (c.jobStatus == JobStatus.error)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Tải lại chuyến để tiếp tục cập nhật tiến độ.',
                style: AppType.caption,
              ),
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

  static Future<void> _open(
    BuildContext context,
    Uri uri,
    String message,
  ) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // A missing external application must not interrupt the job flow.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
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
