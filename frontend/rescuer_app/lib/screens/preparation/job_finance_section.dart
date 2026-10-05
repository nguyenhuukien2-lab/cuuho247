import '../../app/mobile_ui.dart';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../models/backend_models.dart';
import '../../widgets/app_components.dart';
import 'preparation_components.dart';

class JobFinanceSection extends StatefulWidget {
  const JobFinanceSection({
    super.key,
    required this.c,
    required this.assignment,
    this.showCompletionAction = true,
    this.embedded = false,
  });
  final RescuerController c;
  final JobAssignment assignment;
  final bool showCompletionAction;
  final bool embedded;
  @override
  State<JobFinanceSection> createState() => _JobFinanceSectionState();
}

class _JobFinanceSectionState extends State<JobFinanceSection> {
  final _form = GlobalKey<FormState>();
  final _main = TextEditingController(),
      _extra = TextEditingController(),
      _note = TextEditingController();
  String? _error;
  @override
  void initState() {
    super.initState();
    _main.addListener(_previewChanged);
    _extra.addListener(_previewChanged);
  }

  void _previewChanged() => setState(() {});
  int? get _previewTotal {
    try {
      return QuoteDraft.parse(_main.text, _extra.text, '').total;
    } on RescuerFailure {
      return null;
    }
  }

  @override
  void dispose() {
    _main.dispose();
    _extra.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _amount(String? value, {bool optional = false}) {
    if (!optional && (value?.trim().isEmpty ?? true)) {
      return 'Nhập phí dịch vụ chính.';
    }
    try {
      QuoteDraft.parse(
        optional ? '0' : value ?? '',
        optional ? value ?? '' : '',
        '',
      );
    } on RescuerFailure catch (e) {
      return e.message;
    }
    return null;
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    QuoteDraft draft;
    try {
      draft = QuoteDraft.parse(_main.text, _extra.text, _note.text);
    } on RescuerFailure catch (e) {
      setState(() => _error = e.message);
      return;
    }
    setState(() => _error = null);
    await widget.c.sendQuote(draft);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c, a = widget.assignment;
    final quote =
        c.currentQuote?.id == a.currentQuoteId &&
            c.currentQuote?.assignmentId == a.id
        ? c.currentQuote
        : null;
    final children = <Widget>[
      if (a.currentQuoteId != null) ...[
        const Align(
          alignment: Alignment.centerLeft,
          child: StatusBadge(label: 'Báo giá đã gửi', tone: BadgeTone.green),
        ),
        const SizedBox(height: 10),
        Text(
          'Mã báo giá: ${preparationDisplayCode(a.quoteCode ?? quote?.quoteCode, prefix: 'BG')}',
          style: RescueType.title,
        ),
        const SizedBox(height: 12),
        const Text('Tổng báo giá', style: AppType.caption),
        const SizedBox(height: 4),
        Text(
          formatMoney(a.totalVnd, a.currency),
          style: AppType.pageTitle.copyWith(
            color: AppColors.orange,
            fontSize: 30,
          ),
        ),
        const SizedBox(height: 8),
        if (quote != null) ...[
          for (final item in quote.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${serviceLabels[item.serviceCode] ?? 'Dịch vụ'} · ${item.quantity} × ${formatMoney(item.unitPriceVnd, quote.currency)}',
              ),
            ),
          if (quote.note?.isNotEmpty == true)
            Text('Ghi chú: ${quote.note}', style: AppType.body),
        ],
        if (quote == null || quote.items.isEmpty)
          Text(
            a.totalVnd == null
                ? 'Tổng tiền chưa được cung cấp. Tải lại chuyến để kiểm tra báo giá.'
                : 'Hiện có tổng tiền; chi tiết dòng phí chưa được cung cấp.',
            style: AppType.caption,
          ),
        if (widget.showCompletionAction) ...[
          const SizedBox(height: 16),
          AppButton(
            key: const ValueKey('complete-job'),
            label: 'Hoàn tất chuyến',
            icon: Icons.task_alt,
            loading: c.completingJob,
            onPressed: c.canCompleteJob
                ? () => showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => CompleteJobDialog(c: c, confirmed: a),
                  )
                : null,
          ),
        ],
      ] else if (c.jobStatus == JobStatus.ready) ...[
        const Text('Chưa có báo giá', style: RescueType.title),
        const SizedBox(height: 4),
        const Text(
          'Nhập chi phí đã kiểm tra để gửi báo giá cho khách hàng.',
          style: AppType.body,
        ),
        const SizedBox(height: 16),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                key: const ValueKey('quote-main'),
                controller: _main,
                enabled: c.canSendQuote,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Phí dịch vụ chính',
                  suffixText: '₫',
                  helperText: 'Nhập số đồng, không có dấu phân cách',
                ),
                validator: _amount,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('quote-extra'),
                controller: _extra,
                enabled: c.canSendQuote,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Phí phụ thu (nếu có)',
                  suffixText: '₫',
                  helperText: 'Để trống nếu không có phụ thu',
                ),
                validator: (v) => _amount(v, optional: true),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('quote-note'),
                controller: _note,
                enabled: c.canSendQuote,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú báo giá (không bắt buộc)',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.orangeSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TỔNG CHI PHÍ DỰ KIẾN · CHƯA GỬI',
                      style: AppType.caption,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _previewTotal == null
                          ? 'Nhập chi phí để xem tổng'
                          : formatMoney(_previewTotal, 'VND'),
                      style: AppType.pageTitle.copyWith(
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                key: const ValueKey('send-quote'),
                label: 'Gửi báo giá cho khách',
                icon: Icons.send_outlined,
                loading: c.sendingQuote,
                onPressed: c.canSendQuote ? _send : null,
              ),
              const SizedBox(height: 10),
              const Text(
                'Cần gửi báo giá trước khi hoàn tất chuyến.',
                style: AppType.caption,
              ),
            ],
          ),
        ),
      ] else
        const Text(
          'Tải lại chuyến để kiểm tra báo giá trước khi tiếp tục.',
          style: AppType.caption,
        ),
    ];
    return widget.embedded
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Báo giá dịch vụ', style: AppType.section),
              const SizedBox(height: 12),
              ...children,
            ],
          )
        : PreparationCard(
            title: 'Báo giá dịch vụ',
            icon: Icons.receipt_long_outlined,
            children: children,
          );
  }
}

class CompleteJobDialog extends StatefulWidget {
  const CompleteJobDialog({
    super.key,
    required this.c,
    required this.confirmed,
  });
  final RescuerController c;
  final JobAssignment confirmed;
  @override
  State<CompleteJobDialog> createState() => _CompleteJobDialogState();
}

class _CompleteJobDialogState extends State<CompleteJobDialog> {
  bool _saving = false;
  String? _error;
  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final serial = widget.c.completionSuccessSerial, uid = widget.c.userId;
    await widget.c.completeJob(widget.confirmed);
    if (!mounted) return;
    if (widget.c.userId != uid || widget.c.completionSuccessSerial > serial) {
      Navigator.pop(context, widget.c.completionSuccessSerial > serial);
    } else {
      setState(() {
        _saving = false;
        _error =
            widget.c.error ?? 'Chưa hoàn tất. Hãy tải lại chuyến và thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.c,
    builder: (context, _) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Hoàn tất chuyến?'),
        icon: const Icon(Icons.task_alt, color: AppColors.orange),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Xác nhận bạn đã hỗ trợ khách hàng xong.'),
              const SizedBox(height: 16),
              Text(
                'Chi phí: ${formatMoney(widget.confirmed.totalVnd, widget.confirmed.currency)}',
                style: AppType.section,
              ),
              const SizedBox(height: 18),
              const TextField(
                enabled: false,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Ghi chú hoàn tất (không bắt buộc)',
                  hintText: 'Chưa hỗ trợ lưu ghi chú hoàn tất',
                  helperText:
                      'Ghi chú hoàn tất sẽ bổ sung khi hệ thống hỗ trợ.',
                  helperMaxLines: 3,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          AppButton(
            key: const ValueKey('confirm-completion'),
            expand: false,
            label: 'Xác nhận hoàn tất',
            loading: _saving,
            onPressed: _saving || widget.c.working ? null : _confirm,
          ),
        ],
      ),
    ),
  );
}
