import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/app_theme.dart';
import '../../models/active_job.dart';
import '../../models/rescuer_status.dart';
import '../../widgets/app_components.dart';

class ActiveJobScreen extends StatelessWidget {
  const ActiveJobScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final job = state.activeJob;
    if (job == null) {
      return const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpace.lg),
            child: Center(
              child: StatePanel(
                kind: PanelKind.empty,
                title: 'Bạn chưa có đơn đang làm',
                message: 'Đơn được tiếp nhận sẽ xuất hiện tại đây.',
              ),
            ),
          ),
        ),
      );
    }

    final next = switch (job.status) {
      RescueJobStatus.accepted => RescueJobStatus.enRoute,
      RescueJobStatus.enRoute => RescueJobStatus.arrived,
      RescueJobStatus.arrived => RescueJobStatus.inProgress,
      RescueJobStatus.inProgress => null,
      _ => null,
    };
    final nextLabel = switch (job.status) {
      RescueJobStatus.accepted => 'Bắt đầu di chuyển',
      RescueJobStatus.enRoute => 'Đã đến nơi',
      RescueJobStatus.arrived => 'Bắt đầu xử lý',
      RescueJobStatus.inProgress => 'Tạo báo giá',
      _ => 'Xem báo giá',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Đang làm')),
      body: SafeArea(
        child: ScreenContent(
          bottomAction: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                label: nextLabel,
                icon: job.status == RescueJobStatus.inProgress
                    ? Icons.receipt_long_outlined
                    : Icons.arrow_forward_rounded,
                onPressed: () {
                  if (job.status == RescueJobStatus.inProgress) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => QuoteCreationScreen(state: state),
                      ),
                    );
                  } else if (next != null) {
                    state.setJobStatus(next);
                  }
                },
              ),
              if (job.quotedTotalVnd != null) ...[
                const SizedBox(height: AppSpace.sm),
                AppButton(
                  label: 'Hoàn tất đơn',
                  kind: ButtonStyleKind.secondary,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CompletionConfirmationScreen(state: state),
                    ),
                  ),
                ),
              ],
            ],
          ),
          children: [
            PageHeading(
              title: 'Theo dõi đơn',
              subtitle: 'Cập nhật trạng thái theo tiến trình xử lý.',
              trailing: StatusBadge(
                label: job.status.label,
                tone: job.status == RescueJobStatus.inProgress
                    ? BadgeTone.orange
                    : BadgeTone.blue,
              ),
            ),
            const MapPlaceholder(showApproximateArea: true, height: 220),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thông tin đơn', style: AppType.section),
                  const SizedBox(height: AppSpace.md),
                  _SafeJobFields(job: job),
                ],
              ),
            ),
            if (job.customerName != null ||
                job.customerPhone != null ||
                job.exactAddress != null ||
                job.description != null)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thông tin cần thiết', style: AppType.section),
                    const SizedBox(height: AppSpace.md),
                    if (job.customerName != null)
                      LabeledValue(
                        label: 'Tên khách hàng',
                        value: job.customerName!,
                      ),
                    if (job.customerPhone != null) ...[
                      const SizedBox(height: AppSpace.md),
                      LabeledValue(
                        label: 'Số điện thoại',
                        value: job.customerPhone!,
                      ),
                    ],
                    if (job.exactAddress != null) ...[
                      const SizedBox(height: AppSpace.md),
                      LabeledValue(label: 'Địa chỉ', value: job.exactAddress!),
                    ],
                    if (job.description != null) ...[
                      const SizedBox(height: AppSpace.md),
                      LabeledValue(label: 'Ghi chú', value: job.description!),
                    ],
                  ],
                ),
              ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tiến trình', style: AppType.section),
                  const SizedBox(height: AppSpace.md),
                  for (final status in const [
                    RescueJobStatus.accepted,
                    RescueJobStatus.enRoute,
                    RescueJobStatus.arrived,
                    RescueJobStatus.inProgress,
                  ])
                    _TimelineRow(
                      status: status,
                      current: job.status == status,
                      done: job.status.index > status.index,
                      timestamp: _timestampFor(job, status),
                    ),
                ],
              ),
            ),
            AppButton(
              label: 'Hủy đơn',
              kind: ButtonStyleKind.danger,
              onPressed: () => _confirmCancel(context, state),
            ),
          ],
        ),
      ),
    );
  }

  static String? _timestampFor(ActiveJob job, RescueJobStatus status) {
    final date = switch (status) {
      RescueJobStatus.accepted => job.acceptedAt,
      RescueJobStatus.enRoute => job.enRouteAt,
      RescueJobStatus.arrived => job.arrivedAt,
      RescueJobStatus.inProgress => job.inProgressAt,
      _ => null,
    };
    if (date == null) return null;
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmCancel(BuildContext context, AppState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy đơn đang làm?'),
        content: const Text('Trạng thái đơn sẽ chuyển thành đã hủy.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );
    if (confirmed == true) state.cancelJob();
  }
}

class _SafeJobFields extends StatelessWidget {
  const _SafeJobFields({required this.job});
  final ActiveJob job;

  @override
  Widget build(BuildContext context) => Column(
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
      LabeledValue(
        label: 'Vị trí gần đúng',
        value: job.preview.approximateLocation ?? 'Chưa có dữ liệu',
      ),
      if (job.preview.estimatedDistanceKm != null) ...[
        const SizedBox(height: AppSpace.md),
        LabeledValue(
          label: 'Khoảng cách ước tính',
          value: '${job.preview.estimatedDistanceKm!.toStringAsFixed(1)} km',
        ),
      ],
      if (job.quotedTotalVnd != null) ...[
        const Divider(height: AppSpace.xxl),
        if (job.quoteService?.isNotEmpty == true)
          LabeledValue(
            label: 'Dịch vụ chính trong báo giá',
            value: job.quoteService!,
          ),
        if (job.quoteExtras?.isNotEmpty == true) ...[
          const SizedBox(height: AppSpace.md),
          LabeledValue(label: 'Phụ phí / vật tư', value: job.quoteExtras!),
        ],
        if (job.quoteNote?.isNotEmpty == true) ...[
          const SizedBox(height: AppSpace.md),
          LabeledValue(label: 'Ghi chú báo giá', value: job.quoteNote!),
        ],
        const SizedBox(height: AppSpace.md),
        LabeledValue(
          label: 'Báo giá đề xuất',
          value: '${job.quotedTotalVnd} ₫',
        ),
      ],
    ],
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.status,
    required this.current,
    required this.done,
    this.timestamp,
  });
  final RescueJobStatus status;
  final bool current;
  final bool done;
  final String? timestamp;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.md),
    child: Row(
      children: [
        Icon(
          done
              ? Icons.check_circle
              : current
              ? Icons.radio_button_checked
              : Icons.circle_outlined,
          size: 19,
          color: done
              ? AppColors.success
              : current
              ? AppColors.orange
              : AppColors.line,
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Text(
            status.label,
            style: AppType.body.copyWith(
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        if (timestamp != null) Text(timestamp!, style: AppType.caption),
      ],
    ),
  );
}

class QuoteCreationScreen extends StatefulWidget {
  const QuoteCreationScreen({super.key, required this.state});
  final AppState state;

  @override
  State<QuoteCreationScreen> createState() => _QuoteCreationScreenState();
}

class _QuoteCreationScreenState extends State<QuoteCreationScreen> {
  final _service = TextEditingController();
  final _extras = TextEditingController();
  final _note = TextEditingController();
  final _amount = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _service.dispose();
    _extras.dispose();
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    widget.state.saveQuote(
      service: _service.text.trim(),
      extras: _extras.text.trim(),
      note: _note.text.trim(),
      totalVnd: int.parse(_amount.text),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tạo báo giá')),
    body: SafeArea(
      child: ScreenContent(
        bottomAction: AppButton(
          label: 'Lưu báo giá',
          icon: Icons.receipt_long,
          onPressed: _save,
        ),
        children: [
          const PageHeading(
            title: 'Báo giá đề xuất',
            subtitle: 'Nhập thông tin dịch vụ và tổng tiền.',
          ),
          Form(
            key: _form,
            child: Column(
              children: [
                AppTextField(
                  controller: _service,
                  label: 'Dịch vụ chính',
                  icon: Icons.build_outlined,
                  validator: _required,
                ),
                const SizedBox(height: AppSpace.md),
                AppTextField(
                  controller: _extras,
                  label: 'Phụ phí / vật tư nếu có',
                  icon: Icons.handyman_outlined,
                ),
                const SizedBox(height: AppSpace.md),
                AppTextField(
                  controller: _note,
                  label: 'Ghi chú ngắn',
                  icon: Icons.notes_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpace.md),
                AppTextField(
                  controller: _amount,
                  label: 'Tổng tiền (VND)',
                  icon: Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final amount = int.tryParse(value ?? '');
                    return amount == null || amount < 0
                        ? 'Nhập số tiền hợp lệ.'
                        : null;
                  },
                ),
              ],
            ),
          ),
          const InfoBanner(
            title: 'Lưu ý',
            message: 'Báo giá là đề xuất, chưa phải thanh toán.',
            tone: BadgeTone.orange,
            icon: Icons.info_outline,
          ),
        ],
      ),
    ),
  );

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Vui lòng nhập dịch vụ chính.'
      : null;
}

class CompletionConfirmationScreen extends StatefulWidget {
  const CompletionConfirmationScreen({super.key, required this.state});
  final AppState state;

  @override
  State<CompletionConfirmationScreen> createState() =>
      _CompletionConfirmationScreenState();
}

class _CompletionConfirmationScreenState
    extends State<CompletionConfirmationScreen> {
  bool confirmed = false;
  bool complete = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.state.activeJob;
    return Scaffold(
      appBar: AppBar(title: const Text('Hoàn tất đơn')),
      body: SafeArea(
        child: ScreenContent(
          bottomAction: AppButton(
            label: complete ? 'Về lịch sử' : 'Hoàn tất đơn',
            icon: complete ? Icons.history : Icons.check_rounded,
            onPressed: complete
                ? () {
                    widget.state.selectTab(3);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                : confirmed && job?.quotedTotalVnd != null
                ? () {
                    widget.state.completeJob();
                    setState(() => complete = true);
                  }
                : null,
          ),
          children: [
            PageHeading(
              title: complete ? 'Đã hoàn tất' : 'Xác nhận hoàn tất',
              subtitle: complete
                  ? 'Đơn đã chuyển vào lịch sử.'
                  : 'Kiểm tra tóm tắt trước khi kết thúc đơn.',
            ),
            if (complete)
              const StatePanel(
                kind: PanelKind.success,
                title: 'Hoàn tất đơn',
                message: 'Thông tin đơn đã được lưu trong lịch sử trên thiết bị này.',
                compact: true,
              )
            else if (job != null) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tóm tắt đơn', style: AppType.section),
                    const SizedBox(height: AppSpace.md),
                    _SafeJobFields(job: job),
                    const Divider(height: AppSpace.xxl),
                    LabeledValue(
                      label: 'Tổng báo giá',
                      value: job.quotedTotalVnd == null
                          ? 'Chưa có báo giá'
                          : '${job.quotedTotalVnd} ₫',
                    ),
                  ],
                ),
              ),
              CheckboxListTile(
                value: confirmed,
                onChanged: (value) =>
                    setState(() => confirmed = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Tôi xác nhận công việc đã hoàn tất.',
                  style: AppType.body,
                ),
              ),
            ] else
              const StatePanel(
                kind: PanelKind.empty,
                title: 'Không có đơn đang làm',
                message: 'Quay lại danh sách để xem trạng thái hiện tại.',
                compact: true,
              ),
          ],
        ),
      ),
    );
  }
}
