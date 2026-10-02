import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/app_theme.dart';
import 'customer_ui.dart';
import '../app/user_session.dart';
import '../services/customer_request_review_service.dart';
import '../services/supabase_service.dart';

class CustomerRequestReviewCard extends StatefulWidget {
  const CustomerRequestReviewCard(
      {super.key,
      required this.requestId,
      required this.controller,
      this.repository = const SupabaseCustomerRequestReviewRepository()});
  final String requestId;
  final AppController controller;
  final CustomerRequestReviewRepository repository;
  @override
  State<CustomerRequestReviewCard> createState() =>
      _CustomerRequestReviewCardState();
}

class _CustomerRequestReviewCardState extends State<CustomerRequestReviewCard> {
  final comment = TextEditingController();
  CustomerRequestReview? review;
  int rating = 0;
  bool loading = true, sending = false, loadFailed = false;
  String? error;
  late final String? owner;
  int generation = 0;
  bool get currentSession => owner != null && owner == UserSession.userId;
  @override
  void initState() {
    super.initState();
    owner = UserSession.userId;
    widget.controller.addListener(sessionChanged);
    load();
  }

  void sessionChanged() {
    if (owner == UserSession.userId) return;
    generation++;
    comment.clear();
    setState(() {
      review = null;
      rating = 0;
      loading = false;
      sending = false;
      error = null;
    });
  }

  @override
  void dispose() {
    generation++;
    widget.controller.removeListener(sessionChanged);
    comment.dispose();
    super.dispose();
  }

  bool current(int version) =>
      mounted && version == generation && currentSession;
  Future<void> load() async {
    if (!currentSession) {
      setState(() => loading = false);
      return;
    }
    final version = ++generation;
    setState(() {
      loading = true;
      loadFailed = false;
      error = null;
    });
    try {
      final result = await widget.repository.load(widget.requestId);
      if (current(version)) setState(() => review = result);
    } catch (failure) {
      if (current(version))
        setState(() {
          loadFailed = true;
          error = failure is AppFailure
              ? failure.message
              : 'Không tải được đánh giá. Vui lòng thử lại.';
        });
    } finally {
      if (current(version)) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    if (sending || loading || !currentSession) return;
    if (rating == 0) {
      setState(() => error = 'Vui lòng chọn số sao.');
      return;
    }
    final version = ++generation;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final result = await widget.repository
          .submit(widget.requestId, rating: rating, comment: comment.text);
      if (current(version)) setState(() => review = result);
    } catch (failure) {
      if (current(version))
        setState(() => error = failure is AppFailure
            ? failure.message
            : 'Không gửi được đánh giá. Vui lòng thử lại.');
    } finally {
      if (current(version)) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!currentSession) return const SizedBox.shrink();
    final result = review;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Đánh giá sau cứu hộ',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (loading)
        const LinearProgressIndicator()
      else if (result != null) ...[
        Text('Đã đánh giá: ${result.rating}/5 sao'),
        Row(
            children: List.generate(
                5,
                (index) => Icon(
                    index < result.rating ? Icons.star : Icons.star_border,
                    color: AppColors.warning))),
        if (result.comment?.isNotEmpty == true) Text(result.comment!),
      ] else if (loadFailed) ...[
        InlineNotice(error!, onRetry: load, retryLabel: 'Thử tải lại'),
      ] else ...[
        const Text('Chọn số sao từ 1 đến 5'),
        Wrap(
            children: List.generate(
                5,
                (index) => IconButton(
                    tooltip: '${index + 1} sao',
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    iconSize: 32,
                    onPressed: sending
                        ? null
                        : () => setState(() {
                              rating = index + 1;
                              error = null;
                            }),
                    icon: Icon(index < rating ? Icons.star : Icons.star_border,
                        color: AppColors.warning)))),
        TextField(
            controller: comment,
            enabled: !sending,
            maxLength: 2000,
            minLines: 2,
            maxLines: 5,
            decoration:
                const InputDecoration(labelText: 'Nhận xét (tùy chọn)')),
        if (error != null) InlineNotice(error!),
        if (sending) const LinearProgressIndicator(),
        FilledButton(
            onPressed: sending ? null : submit,
            child: Text(sending
                ? 'Đang gửi…'
                : error == null
                    ? 'Gửi đánh giá'
                    : 'Thử lại')),
      ],
    ]);
  }
}
