import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_theme.dart';
import '../../app/mobile_ui.dart';
import '../../app/rescuer_controller.dart';
import '../../models/backend_models.dart';
import '../../widgets/app_components.dart';
import 'preparation_components.dart';
import 'job_finance_section.dart';

class ActiveJobPanel extends StatefulWidget {
  const ActiveJobPanel({super.key, required this.c});
  final RescuerController c;

  @override
  State<ActiveJobPanel> createState() => _ActiveJobPanelState();
}

class _ActiveJobPanelState extends State<ActiveJobPanel> {
  GlobalKey _financeKey = GlobalKey();
  String? _financeAssignment;

  Future<void> _showQuoteForm() async {
    final target = _financeKey.currentContext;
    if (target != null) {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 250),
        alignment: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final job = c.jobStatus == JobStatus.ready ? c.activeJob : null;
    final assignment = job?.assignment ?? c.claimedAssignment;
    if (_financeAssignment != assignment?.id) {
      _financeAssignment = assignment?.id;
      _financeKey = GlobalKey();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (assignment != null) ...[
          PartnerSection(
            key: const ValueKey('active-job-header'),
            title: 'Hành động',
            icon: Icons.navigation_outlined,
            accent: AppColors.orange,
            children: [
              Text(
                'Mã đơn: ${preparationDisplayCode(assignment.requestCode, prefix: 'CH')}',
                style: AppType.section,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: RescueStatusBadge(
                  status: assignment.state,
                  label: assignment.stateLabel,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                c.jobStatus == JobStatus.ready
                    ? _nextGuide(assignment)
                    : 'Tải lại thông tin chuyến để tiếp tục thao tác.',
                style: AppType.body,
              ),
              if (assignment.nextState != null) ...[
                const SizedBox(height: 16),
                AppButton(
                  key: const ValueKey('advance-job'),
                  label: c.updatingJobState != null
                      ? 'Đang cập nhật…'
                      : assignment.nextActionLabel!,
                  icon: Icons.navigation_outlined,
                  loading: c.updatingJobState != null,
                  onPressed: c.canAdvanceJob ? c.advanceJob : null,
                ),
              ] else if (assignment.state == 'in_progress') ...[
                const SizedBox(height: 16),
                if (assignment.currentQuoteId == null)
                  AppButton(
                    key: const ValueKey('open-quote'),
                    label: c.sendingQuote ? 'Đang gửi báo giá…' : 'Tạo báo giá',
                    icon: Icons.receipt_long_outlined,
                    loading: c.sendingQuote,
                    onPressed: c.canSendQuote ? _showQuoteForm : null,
                  )
                else
                  AppButton(
                    key: const ValueKey('complete-job'),
                    label: 'Hoàn tất chuyến',
                    icon: Icons.task_alt,
                    loading: c.completingJob,
                    onPressed: c.canCompleteJob
                        ? () => showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) =>
                                CompleteJobDialog(c: c, confirmed: assignment),
                          )
                        : null,
                  ),
              ],

              if (job != null) ...[
                const Divider(height: 28),
                if (job.contactName?.trim().isNotEmpty == true)
                  _field('Khách hàng', job.contactName!),
                if (job.contactPhone?.trim().isNotEmpty == true)
                  _field('Số điện thoại', job.contactPhone!)
                else
                  const Text(
                    'Đơn chưa có số điện thoại liên hệ.',
                    style: AppType.body,
                  ),
                const SizedBox(height: 8),
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
                  )
                else if (job.contactPhone?.trim().isNotEmpty == true)
                  const Text(
                    'Số liên hệ chưa hỗ trợ gọi trực tiếp. Kiểm tra lại với khách hàng.',
                    style: AppType.caption,
                  ),
                const SizedBox(height: 12),
                if (_hasCoordinates(job))
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
                  )
                else
                  const Text(
                    'Chưa có GPS. Xác nhận điểm cứu hộ với khách.',
                    style: AppType.body,
                  ),
              ],
              if (assignment.state == 'in_progress') ...[
                const Divider(height: 28),
                JobFinanceSection(
                  key: _financeKey,
                  c: c,
                  assignment: assignment,
                  embedded: true,
                  showCompletionAction: false,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (c.jobStatus == JobStatus.loading) ...[
          const PreparationEmpty(
            kind: RescueFeedbackKind.loading,
            title: 'Đang tải chuyến',
            message: 'Đang kiểm tra thông tin chuyến đã nhận.',
            icon: Icons.sync,
          ),
          const SizedBox(height: 16),
        ],
        if (c.jobStatus == JobStatus.error) ...[
          PreparationEmpty(
            kind: RescueFeedbackKind.error,
            title: 'Chưa tải được thông tin chuyến',
            message: c.jobError ?? 'Kiểm tra kết nối rồi thử tải lại.',
            icon: Icons.cloud_off,
          ),
          const SizedBox(height: 16),
        ],
        if (c.jobStatus == JobStatus.empty) ...[
          PreparationEmpty(
            title: 'Chưa có chuyến đang xử lý',
            message:
                'Bật online và vào Đơn mới để nhận yêu cầu cứu hộ phù hợp.',
            icon: Icons.local_shipping_outlined,
            action: AppButton(
              label: 'Xem đơn mới',
              icon: Icons.assignment_outlined,
              onPressed: c.working ? null : () => c.selectTab(1),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (c.jobStatus == JobStatus.unavailable) ...[
          const PreparationEmpty(
            title: 'Chưa thể xem chuyến',
            message: 'Đăng nhập và kiểm tra trạng thái duyệt hồ sơ trước khi tiếp tục.',
            icon: Icons.verified_user_outlined,
          ),
          const SizedBox(height: 16),
        ],

        if (job != null) ...[
          PartnerSection(
            key: const ValueKey('active-job-info'),
            title: 'Thông tin chuyến',
            icon: Icons.assignment_outlined,
            children: [
              _field(
                'Dịch vụ',
                serviceLabels[job.service] ?? 'Chưa có thông tin dịch vụ',
              ),
              _field(
                'Loại xe',
                customerVehicles[job.vehicle] ?? 'Chưa có thông tin loại xe',
              ),
              _field(
                'Địa điểm',
                job.address?.trim().isNotEmpty == true
                    ? job.address!
                    : 'Đơn chưa có địa chỉ cứu hộ.',
              ),
              if (_hasCoordinates(job) &&
                  job.address?.trim().isNotEmpty != true)
                _field(
                  'Tọa độ cứu hộ',
                  '${job.latitude!.toStringAsFixed(6)}, ${job.longitude!.toStringAsFixed(6)}',
                ),
              if (job.assignment.acceptedAt != null)
                _field('Nhận lúc', _time(job.assignment.acceptedAt!)),
              if (job.description?.trim().isNotEmpty == true)
                _field('Ghi chú sự cố', job.description!),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (assignment != null) ...[
          PartnerSection(
            key: const ValueKey('active-job-progress'),
            title: 'Tiến trình',
            icon: Icons.route_outlined,
            children: [_ActiveJobTimeline(assignment: assignment)],
          ),
          const SizedBox(height: 16),
        ],
        AppButton(
          kind: ButtonStyleKind.quiet,
          label: 'Tải lại chuyến',
          icon: Icons.refresh,
          loading: c.jobStatus == JobStatus.loading,
          onPressed: c.working || !c.snapshot.approved
              ? null
              : c.refreshActiveJob,
        ),
      ],
    );
  }

  static String _nextGuide(JobAssignment assignment) =>
      switch (assignment.state) {
        'accepted' => 'Xác nhận điểm cứu hộ rồi bắt đầu di chuyển.',
        'en_route' => 'Tới điểm cứu hộ, bấm “Đã đến nơi”.',
        'arrived' => 'Kiểm tra sự cố và bắt đầu hỗ trợ.',
        'in_progress' =>
          assignment.currentQuoteId == null
              ? 'Gửi báo giá trước khi hoàn tất chuyến.'
              : assignment.hasQuote
              ? 'Hỗ trợ xong, xác nhận hoàn tất chuyến.'
              : 'Báo giá đã gửi. Tải lại chuyến để kiểm tra tổng tiền trước khi hoàn tất.',
        'completed' => 'Chuyến đã hoàn tất. Xem thông tin trong lịch sử.',
        'cancelled' => 'Chuyến đã hủy. Xem thông tin trong lịch sử.',
        _ => 'Tải lại chuyến để kiểm tra trạng thái hiện tại.',
      };

  static bool _hasCoordinates(ActiveJob job) =>
      job.latitude != null &&
      job.longitude != null &&
      job.latitude!.isFinite &&
      job.longitude!.isFinite &&
      job.latitude!.abs() <= 90 &&
      job.longitude!.abs() <= 180;

  static Future<void> _open(
    BuildContext context,
    Uri uri,
    String message,
  ) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Keep the original contact/map failure feedback.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  static Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.caption),
        const SizedBox(height: 4),
        SelectableText(value, style: AppType.body),
      ],
    ),
  );
}

String _time(DateTime value) {
  final t = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)} · ${two(t.day)}/${two(t.month)}/${t.year}';
}

/// Only server milestones have times; a quote is an action, not a new job state.
class _ActiveJobTimeline extends StatelessWidget {
  const _ActiveJobTimeline({required this.assignment});
  final JobAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('accepted', 'Đã nhận đơn', assignment.acceptedAt),
      ('en_route', 'Đang đến điểm cứu hộ', assignment.enRouteAt),
      ('arrived', 'Đã đến nơi', assignment.arrivedAt),
      ('in_progress', 'Đang hỗ trợ khách', assignment.inProgressAt),
      ('completed', 'Hoàn tất chuyến', assignment.completedAt),
      if (assignment.state == 'cancelled' || assignment.cancelledAt != null)
        ('cancelled', 'Đã hủy', assignment.cancelledAt),
    ];
    return Column(
      children: [
        for (final (state, label, time) in steps)
          if (state == assignment.state || time != null)
            Container(
              key: ValueKey('job-step-$state'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: state == assignment.state
                    ? RescueColors.selected
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(RescueRadius.control),
                border: state == assignment.state
                    ? Border.all(color: AppColors.orange)
                    : null,
              ),
              child: Semantics(
                label:
                    '$label: ${state == assignment.state
                        ? 'Hiện tại'
                        : time != null
                        ? 'Đã ghi nhận'
                        : 'Chưa ghi nhận'}',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      state == assignment.state
                          ? Icons.radio_button_checked
                          : time != null
                          ? Icons.check_rounded
                          : Icons.radio_button_unchecked,
                      color: state == assignment.state
                          ? AppColors.orange
                          : AppColors.muted,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: AppType.body.copyWith(
                              fontWeight: state == assignment.state
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: state == assignment.state
                                  ? AppColors.navy
                                  : AppColors.muted,
                            ),
                          ),
                          if (state == assignment.state)
                            const Text('Hiện tại', style: AppType.caption),
                          if (time != null)
                            Text(_time(time), style: AppType.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
