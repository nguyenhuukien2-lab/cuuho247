import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_theme.dart';
import '../../app/mobile_ui.dart';
import '../../app/rescuer_controller.dart';
import '../../models/backend_models.dart';
import '../../widgets/app_components.dart';
import '../payment/job_payment_section.dart';
import 'preparation_components.dart';
import 'job_finance_section.dart';
import 'job_progress_timeline.dart';
import 'gps_status_detail.dart';

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
            compact: true,
            title: 'Chuyến đang xử lý',
            icon: Icons.navigation_outlined,
            background: RescueColors.selected,
            children: [
              GpsStatusDetail(c: c),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Mã đơn: ${preparationDisplayCode(assignment.requestCode, prefix: 'CH')}',
                    style: RescueType.section,
                  ),
                  RescueStatusBadge(
                    status: assignment.state,
                    label: assignment.stateLabel,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                c.jobStatus == JobStatus.ready
                    ? 'Việc tiếp theo: ${_nextGuide(assignment)}'
                    : 'Tải lại thông tin chuyến để tiếp tục thao tác.',
                style: AppType.body,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (job != null) ...[
            Container(
              key: const ValueKey('active-job-map'),
              padding: const EdgeInsets.all(20),
              constraints: const BoxConstraints(minHeight: 220),
              decoration: BoxDecoration(
                color: RescueColors.containerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.orange,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _hasCoordinates(job)
                        ? 'Vị trí hiện trường'
                        : 'Chưa có vị trí hiện trường',
                    textAlign: TextAlign.center,
                    style: AppType.section,
                  ),
                  const SizedBox(height: 6),
                  if (_hasCoordinates(job)) ...[
                    Text(
                      '${job.latitude!.toStringAsFixed(6)}, ${job.longitude!.toStringAsFixed(6)}',
                      textAlign: TextAlign.center,
                      style: AppType.code,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Xem bản đồ tại vị trí thực tế trong Google Maps.',
                      textAlign: TextAlign.center,
                      style: AppType.caption,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      kind: ButtonStyleKind.secondary,
                      label: 'Mở Google Maps',
                      icon: Icons.near_me_outlined,
                      onPressed: () => _open(
                        context,
                        Uri.https('www.google.com', '/maps/search/', {
                          'api': '1',
                          'query': '${job.latitude},${job.longitude}',
                        }),
                        'Không mở được bản đồ. Kiểm tra ứng dụng bản đồ hoặc trình duyệt.',
                      ),
                    ),
                  ] else
                    const Text(
                      'Chưa có GPS. Xác nhận điểm cứu hộ với khách.',
                      textAlign: TextAlign.center,
                      style: AppType.body,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PartnerSection(
              key: const ValueKey('active-job-customer'),
              title: 'Thông tin hiện trường',
              icon: Icons.person_outline,
              children: [
                if (job.contactName?.trim().isNotEmpty == true)
                  _field('Khách hàng', job.contactName!),
                if (job.contactPhone?.trim().isNotEmpty == true)
                  _field('Số điện thoại', job.contactPhone!)
                else
                  const Text(
                    'Đơn chưa có số điện thoại liên hệ.',
                    style: AppType.body,
                  ),
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
                const Divider(height: 28),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final vehicle = LabeledValue(
                      label: 'Xe gặp sự cố',
                      value: customerVehicles[job.vehicle] ?? 'Chưa có loại xe',
                    );
                    final service = LabeledValue(
                      label: 'Phương án cứu hộ',
                      value: serviceLabels[job.service] ?? 'Dịch vụ cứu hộ',
                    );
                    if (constraints.maxWidth < 310 ||
                        MediaQuery.textScalerOf(context).scale(14) > 18) {
                      return Column(
                        children: [
                          vehicle,
                          const SizedBox(height: 12),
                          service,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: vehicle),
                        const SizedBox(width: 12),
                        Expanded(child: service),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                LabeledValue(
                  label: 'Vị trí thực địa',
                  icon: Icons.pin_drop_outlined,
                  value: job.address?.trim().isNotEmpty == true
                      ? job.address!
                      : 'Đơn chưa có địa chỉ cứu hộ.',
                ),
                if (job.description?.trim().isNotEmpty == true) ...[
                  const Divider(height: 28),
                  _field('Ghi chú sự cố', job.description!),
                ],
              ],
            ),
            const SizedBox(height: 20),
          ],
          PartnerSection(
            key: const ValueKey('active-job-progress'),
            title: 'Tiến trình tác nghiệp',
            icon: Icons.checklist,
            children: [JobProgressTimeline(assignment: assignment)],
          ),
          const SizedBox(height: 20),
          PartnerSection(
            key: const ValueKey('active-job-finance'),
            title: 'Bảng kê chi phí ca cứu hộ',
            icon: Icons.receipt_long_outlined,
            children: [
              if (assignment.state == 'in_progress')
                JobFinanceSection(
                  key: _financeKey,
                  c: c,
                  assignment: assignment,
                  embedded: true,
                  showCompletionAction: false,
                )
              else if (assignment.currentQuoteId != null) ...[
                Text(
                  'Mã báo giá: ${preparationDisplayCode(assignment.quoteCode, prefix: 'BG')}',
                  style: AppType.code,
                ),
                const SizedBox(height: 8),
                Text(
                  formatMoney(assignment.totalVnd, assignment.currency),
                  style: AppType.section,
                ),
                const SizedBox(height: 8),
                const StatusBadge(
                  label: 'Báo giá đã gửi',
                  tone: BadgeTone.green,
                ),
              ] else
                const Text('Chưa có báo giá', style: AppType.body),
            ],
          ),
          const SizedBox(height: 20),
          JobPaymentSection(
            key: const ValueKey('active-job-payment'),
            c: c,
            assignment: assignment,
          ),
          const SizedBox(height: 20),
          Column(
            key: const ValueKey('active-job-actions'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (assignment.nextState != null)
                AppButton(
                  key: const ValueKey('advance-job'),
                  label: c.updatingJobState != null
                      ? 'Đang cập nhật…'
                      : assignment.nextActionLabel!,
                  icon: Icons.navigation_outlined,
                  loading: c.updatingJobState != null,
                  onPressed: c.canAdvanceJob ? c.advanceJob : null,
                )
              else if (assignment.state == 'in_progress')
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
          ),
          const SizedBox(height: 12),
        ],
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
          PreparationEmpty(
            title: 'Chưa có chuyến đang xử lý',
            message: 'Vào tab Đơn mới để nhận chuyến',
            icon: Icons.local_shipping_outlined,
            action: AppButton(
              label: 'Xem đơn mới',
              icon: Icons.assignment_outlined,
              onPressed: c.working ? null : () => c.selectTab(1),
            ),
          ),
        if (c.jobStatus == JobStatus.unavailable)
          const PreparationEmpty(
            title: 'Chưa thể xem chuyến',
            message: 'Đăng nhập và kiểm tra trạng thái duyệt hồ sơ trước khi tiếp tục.',
            icon: Icons.verified_user_outlined,
          ),
        const SizedBox(height: 12),
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
        'accepted' => 'Bắt đầu di chuyển.',
        'en_route' => 'Xác nhận đã đến nơi.',
        'arrived' => 'Bắt đầu hỗ trợ.',
        'in_progress' =>
          assignment.currentQuoteId == null
              ? 'Tạo báo giá.'
              : assignment.hasQuote
              ? 'Hoàn tất hỗ trợ.'
              : 'Tải lại để kiểm tra báo giá.',
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
