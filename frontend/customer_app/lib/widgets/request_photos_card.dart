import 'package:flutter/material.dart';

import '../services/request_photo_service.dart';
import '../app/app_theme.dart';
import 'customer_ui.dart';

class RequestPhotosCard extends StatefulWidget {
  const RequestPhotosCard(
      {super.key,
      required this.requestId,
      required this.customerId,
      required this.isActive,
      this.repository = const SupabaseRequestPhotoRepository()});
  final String requestId;
  final String? customerId;
  final bool isActive;
  final RequestPhotoRepository repository;

  @override
  State<RequestPhotosCard> createState() => _RequestPhotosCardState();
}

class _RequestPhotosCardState extends State<RequestPhotosCard> {
  List<RequestPhoto> photos = [];
  String? error;
  bool loading = false;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) load();
  }

  @override
  void didUpdateWidget(covariant RequestPhotosCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.requestId != oldWidget.requestId ||
        widget.customerId != oldWidget.customerId ||
        widget.isActive != oldWidget.isActive) {
      generation++;
      photos = [];
      error = null;
      loading = false;
      if (widget.isActive) load();
    }
  }

  Future<void> load() async {
    final current = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.repository.list(widget.requestId);
      if (!mounted || current != generation) return;
      setState(() => photos = result);
    } catch (_) {
      if (!mounted || current != generation) return;
      setState(() => error = 'Không tải được ảnh sự cố. Vui lòng thử lại.');
    } finally {
      if (mounted && current == generation) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('Ảnh sự cố đã gửi',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20))),
          IconButton(
              tooltip: 'Tải lại ảnh',
              onPressed: loading || !widget.isActive ? null : load,
              icon: const Icon(Icons.refresh)),
        ]),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          InlineNotice(error!,
              onRetry: loading || !widget.isActive ? null : load),
        if (!loading && error == null && photos.isEmpty)
          const Text('Chưa có ảnh sự cố.'),
        LayoutBuilder(builder: (context, constraints) {
          final size = (constraints.maxWidth - 16) / 3;
          return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: photos
                  .map((photo) => ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: Image.network(
                        photo.url,
                        key: ValueKey(photo.id),
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                        semanticLabel: 'Ảnh sự cố đã gửi',
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : SizedBox.square(
                                    dimension: size,
                                    child: const ColoredBox(
                                        color: AppColors.background,
                                        child: Center(
                                            child: SizedBox.square(
                                                dimension: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2))))),
                        errorBuilder: (_, __, ___) => SizedBox(
                            width: size,
                            height: size,
                            child: Center(
                                child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.broken_image_outlined,
                                              color: AppColors.muted),
                                          const SizedBox(height: 8),
                                          const Text('Chưa tải được',
                                              style: TextStyle(fontSize: 12),
                                              textAlign: TextAlign.center),
                                        ])))),
                      )))
                  .toList());
        }),
      ]);
}
