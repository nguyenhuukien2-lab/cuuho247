import 'stitch_customer_header.dart';
import '../core/utils/display_code.dart';
import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../services/customer_request_review_service.dart';
import '../services/customer_vehicle_service.dart';
import 'customer_ui.dart';
import 'rescue_widgets.dart';

abstract final class HistoryStyle {
  static const background = Color(0xFFF8F9FF);
  static const blue = Color(0xFF1D4ED8);
  static const darkBlue = Color(0xFF1D4ED8);
  static const navy = Color(0xFF0037B0);
  static const pale = Color(0xFFEEF4FF);
  static const ink = Color(0xFF0B1C30);
  static const muted = Color(0xFF434655);
  static const border = Color(0xFFE5EAF2);
  static const title = TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 18,
      height: 24 / 18,
      fontWeight: FontWeight.w700,
      color: ink);
  static const body = TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 14,
      height: 20 / 14,
      color: ink);
  static const caption = TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 12,
      height: 16 / 12,
      color: muted);
}

class HistoryHeader extends StatelessWidget {
  const HistoryHeader({super.key, required this.onAccount});
  final VoidCallback onAccount;
  @override
  Widget build(BuildContext context) =>
      StitchCustomerHeader(onAccount: onAccount);
}

class HistorySummaryCard extends StatelessWidget {
  const HistorySummaryCard(
      {super.key, required this.count, this.completedCount});
  final int? count, completedCount;
  @override
  Widget build(BuildContext context) => Container(
      key: const ValueKey('history-hero'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0037B0), HistoryStyle.blue])),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.history_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Expanded(
                child: Text('NHẬT KÝ CỨU HỘ',
                    style: HistoryStyle.title
                        .copyWith(color: Colors.white, fontSize: 15))),
          ]),
          const SizedBox(height: 12),
          if (count == null && completedCount == null)
            Text('Chưa tải được số chuyến',
                style: HistoryStyle.body.copyWith(color: Colors.white))
          else ...[
            IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  if (count != null)
                    Expanded(
                        child: _HistoryMetric(
                            label: 'Tổng số chuyến',
                            value: count!,
                            valueKey: const ValueKey('history-total'))),
                  if (count != null && completedCount != null)
                    const SizedBox(width: 10),
                  if (completedCount != null)
                    Expanded(
                        child: _HistoryMetric(
                            label: 'Chuyến hoàn tất',
                            value: completedCount!,
                            valueKey:
                                const ValueKey('history-completed-total'))),
                ])),
            const SizedBox(height: 10),
            Text('Thống kê từ các chuyến đã tải',
                style: HistoryStyle.caption.copyWith(color: Colors.white)),
          ],
        ],
      ));
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric(
      {required this.label, required this.value, required this.valueKey});
  final String label;
  final int value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: HistoryStyle.caption.copyWith(color: Colors.white)),
        const SizedBox(height: 5),
        Text('$value',
            key: valueKey,
            style:
                HistoryStyle.title.copyWith(fontSize: 28, color: Colors.white)),
      ]));
}

class HistoryFilterTabs extends StatelessWidget {
  const HistoryFilterTabs(
      {super.key,
      required this.selected,
      required this.counts,
      required this.onSelected});
  final int selected;
  final List<int>? counts;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: HistoryStyle.pale, borderRadius: BorderRadius.circular(999)),
      child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < 3; i++)
          Expanded(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Semantics(
              selected: i == selected,
              child: TextButton(
                  key: ValueKey('history-filter-$i'),
                  onPressed: () => onSelected(i),
                  style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 10),
                      foregroundColor:
                          selected == i ? Colors.white : HistoryStyle.muted,
                      backgroundColor:
                          selected == i ? HistoryStyle.darkBlue : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999))),
                  child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(const ['Tất cả', 'Hoàn tất', 'Đã hủy'][i],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        if (counts != null)
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                  color: selected == i
                                      ? Colors.white.withValues(alpha: .2)
                                      : HistoryStyle.pale,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text('${counts![i]}',
                                  key: ValueKey('history-count-$i'),
                                  style: const TextStyle(fontSize: 10))),
                      ])),
            ),
          )),
      ])));
}

class HistoryTripCard extends StatelessWidget {
  const HistoryTripCard(
      {super.key,
      required this.request,
      required this.onDetails,
      this.vehicleDetails,
      this.review,
      this.onReview});
  final RescueRequestData request;
  final VoidCallback onDetails;
  // Already loaded optional data only; list cards never fetch details/reviews.
  final CustomerVehicle? vehicleDetails;
  final CustomerRequestReview? review;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final vehicle = vehicleDetails?.id == request.vehicleId &&
            vehicleDetails?.kind == request.vehicle
        ? vehicleDetails
        : null;
    final code = request.requestCode?.trim();
    final hasCode = code != null && RegExp(r'^CH-[0-9]+$').hasMatch(code);
    final hasReview = request.stage == RequestStage.completed &&
        review?.requestId == request.id &&
        review!.rating >= 1 &&
        review!.rating <= 5;
    final canReview = request.stage == RequestStage.completed &&
        review == null &&
        onReview != null;
    return _HistorySurface(
      child: InkWell(
        onTap: onDetails,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: HistoryStyle.pale,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(serviceIcon(request.service),
                      color: HistoryStyle.blue, size: 22)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    LayoutBuilder(builder: (context, constraints) {
                      final title = Text(request.service.label,
                          style: HistoryStyle.title);
                      final badge = HistoryStatusBadge(stage: request.stage);
                      if (constraints.maxWidth >= 220 &&
                          MediaQuery.textScalerOf(context).scale(14) <= 18.2) {
                        return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: title),
                              const SizedBox(width: 8),
                              badge
                            ]);
                      }
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [title, const SizedBox(height: 6), badge]);
                    }),
                    const SizedBox(height: 4),
                    Text(customerDate(request.createdAt, includeTime: true),
                        style: HistoryStyle.caption),
                    const SizedBox(height: 3),
                    Text(
                        hasCode ? 'Mã đơn: ${displayCode(code)}' : 'Chưa có mã',
                        style: HistoryStyle.caption.copyWith(
                            color: HistoryStyle.navy,
                            fontWeight: FontWeight.w600)),
                  ])),
            ]),
            const SizedBox(height: 12),
            HistoryVehicleStrip(kind: request.vehicle, vehicle: vehicle),
            if (request.address.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: HistoryStyle.pale,
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            color: Color(0xFFBA1A1A), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('ĐỊA ĐIỂM CỨU HỘ',
                                  style: HistoryStyle.caption
                                      .copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(request.address.trim(),
                                  key: const ValueKey('history-location'),
                                  style: HistoryStyle.body),
                            ])),
                      ])),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1, color: HistoryStyle.border),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, constraints) {
              final content = <Widget>[
                if (request.price != null)
                  Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Chi phí dịch vụ',
                            style: HistoryStyle.caption),
                        const SizedBox(height: 3),
                        Text(money(request.price),
                            key: const ValueKey('history-cost'),
                            style: HistoryStyle.title.copyWith(
                                color: HistoryStyle.darkBlue, fontSize: 24)),
                      ]),
                TextButton.icon(
                    onPressed: onDetails,
                    style: TextButton.styleFrom(
                        backgroundColor: HistoryStyle.pale,
                        foregroundColor: HistoryStyle.darkBlue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        minimumSize: const Size(0, 40),
                        textStyle: HistoryStyle.body.copyWith(
                            fontSize: 12, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    iconAlignment: IconAlignment.end,
                    label: const Text('Xem chi tiết')),
              ];
              if (request.price == null)
                return Align(
                    alignment: Alignment.centerRight, child: content.last);
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(12) > 14)
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      content.first,
                      const SizedBox(height: 8),
                      Align(
                          alignment: Alignment.centerRight,
                          child: content.last),
                    ]);
              return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: content.first),
                const SizedBox(width: 12),
                content.last
              ]);
            }),
            if (hasReview || canReview) ...[
              const SizedBox(height: 8),
              Align(
                  alignment: Alignment.centerLeft,
                  child: hasReview
                      ? Container(
                          key: const ValueKey('history-review'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(999)),
                          child: Text('Đã đánh giá ${review!.rating}★',
                              style: HistoryStyle.caption.copyWith(
                                  color: const Color(0xFF15803D),
                                  fontWeight: FontWeight.w700)))
                      : TextButton.icon(
                          onPressed: onReview,
                          style: TextButton.styleFrom(
                              foregroundColor: HistoryStyle.darkBlue),
                          icon:
                              const Icon(Icons.star_outline_rounded, size: 18),
                          label: const Text('Đánh giá'))),
            ],
          ]),
        ),
      ),
    );
  }
}

class HistoryStatusBadge extends StatelessWidget {
  const HistoryStatusBadge({super.key, required this.stage});
  final RequestStage stage;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (stage) {
      RequestStage.completed => (
          'Hoàn tất',
          const Color(0xFF15803D),
          const Color(0xFFDCFCE7)
        ),
      RequestStage.cancelled => (
          'Đã hủy',
          const Color(0xFFB91C1C),
          const Color(0xFFFFDAD6)
        ),
      RequestStage.inProgress => (
          'Đang hỗ trợ',
          const Color(0xFF1D4ED8),
          const Color(0xFFFFF1E8)
        ),
      RequestStage.searching => (
          'Đang tìm',
          const Color(0xFFB45309),
          const Color(0xFFFEF3C7)
        ),
      RequestStage.accepted => (
          'Đã nhận',
          HistoryStyle.darkBlue,
          HistoryStyle.pale
        ),
      RequestStage.arriving => (
          'Đang đến',
          HistoryStyle.darkBlue,
          HistoryStyle.pale
        ),
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            textAlign: TextAlign.center,
            style: HistoryStyle.caption
                .copyWith(color: color, fontWeight: FontWeight.w700)));
  }
}

class HistoryVehicleStrip extends StatelessWidget {
  const HistoryVehicleStrip({super.key, this.kind, this.vehicle});
  final VehicleKind? kind;
  final CustomerVehicle? vehicle;

  String? _displayValue(String? input) {
    final value = input?.trim();
    if (value == null ||
        value.isEmpty ||
        RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
                caseSensitive: false)
            .hasMatch(value)) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final vehicleKind = kind ?? vehicle?.kind;
    if (vehicleKind == null) return const SizedBox.shrink();
    final name = _displayValue(vehicle?.brandModel);
    final plate = _displayValue(vehicle?.licensePlate);
    return Container(
        key: const ValueKey('history-vehicle'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
            color: HistoryStyle.pale, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(vehicleIcon(vehicleKind), color: HistoryStyle.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name?.isNotEmpty == true ? name! : vehicleKind.label,
                    style: HistoryStyle.body.copyWith(
                        color: HistoryStyle.navy, fontWeight: FontWeight.w600)),
                if (name?.isNotEmpty == true || plate?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                      [
                        vehicleKind.label,
                        if (plate?.isNotEmpty == true) 'Biển số: $plate'
                      ].join(' • '),
                      style: HistoryStyle.caption),
                ],
              ])),
        ]));
  }
}

class HistoryEmptyState extends StatelessWidget {
  const HistoryEmptyState(
      {super.key, required this.filterIndex, required this.onRequest});
  final int filterIndex;
  final VoidCallback onRequest;
  @override
  Widget build(BuildContext context) => _HistorySurface(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const CircleAvatar(
                radius: 32,
                backgroundColor: HistoryStyle.pale,
                child: Icon(Icons.history_rounded,
                    size: 32, color: HistoryStyle.blue)),
            const SizedBox(height: 16),
            Text(
                switch (filterIndex) {
                  1 => 'Chưa có chuyến hoàn tất',
                  2 => 'Không có chuyến nào đã hủy',
                  _ => 'Chưa có chuyến cứu hộ'
                },
                style: HistoryStyle.title.copyWith(fontSize: 18),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Các chuyến của bạn sẽ xuất hiện tại đây.',
                style: HistoryStyle.body, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: onRequest,
                style: FilledButton.styleFrom(
                    backgroundColor: HistoryStyle.blue,
                    foregroundColor: Colors.white),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Đặt cứu hộ')),
          ])));
}

class _HistorySurface extends StatelessWidget {
  const _HistorySurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      key: const ValueKey('history-card-surface'),
      width: double.infinity,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: HistoryStyle.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x080B3A66), blurRadius: 10, offset: Offset(0, 3)),
          ]),
      child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: child));
}
