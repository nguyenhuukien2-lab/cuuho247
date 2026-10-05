import '../app/mobile_ui.dart';
import '../core/utils/display_code.dart';
import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import 'booking_ui.dart';
import 'customer_ui.dart';
import 'rescue_widgets.dart';

const _title = RescueType.section;
const _caption = RescueType.caption;

class HistorySummaryCard extends StatelessWidget {
  const HistorySummaryCard({super.key, required this.count});
  final int? count;
  @override
  Widget build(BuildContext context) => Container(
      clipBehavior: Clip.antiAlias,
      decoration: RescueSurfaces.decoration(RescueCardKind.history),
      child: Stack(children: [
        Padding(
            padding: const EdgeInsets.all(RescueSpace.lg),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.shield_outlined, color: RescueColors.navy),
                SizedBox(width: 10),
                Expanded(
                    child: Text('Nhật Ký Cứu Hộ An Toàn',
                        style: TextStyle(
                            color: RescueColors.muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)))
              ]),
              const SizedBox(height: 20),
              const Text('Tổng chuyến',
                  style: TextStyle(color: RescueColors.ink, fontSize: 18)),
              const SizedBox(height: 4),
              if (count == null)
                const Text('Chưa có dữ liệu',
                    style: TextStyle(color: RescueColors.ink))
              else
                Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('$count',
                          key: const ValueKey('history-total'),
                          style: const TextStyle(
                              fontSize: 24,
                              height: 1.2,
                              color: RescueColors.ink,
                              fontWeight: FontWeight.w800)),
                      const Text('chuyến',
                          style: TextStyle(
                              color: RescueColors.muted, fontSize: 16)),
                    ]),
              const SizedBox(height: 8),
              const Text('Trong lịch sử đã tải',
                  style: TextStyle(color: RescueColors.muted, fontSize: 12)),
            ])),
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
          color: RescueColors.selected,
          borderRadius: BorderRadius.circular(RescueRadius.card)),
      child: Row(children: [
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
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 10),
                      foregroundColor:
                          selected == i ? Colors.white : BookingStyle.muted,
                      backgroundColor: selected == i
                          ? BookingStyle.blue
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(RescueRadius.card))),
                  child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 5,
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
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                  color: selected == i
                                      ? Colors.white.withValues(alpha: .2)
                                      : BookingStyle.pale,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text('${counts![i]}',
                                  key: ValueKey('history-count-$i'),
                                  style: const TextStyle(fontSize: 12))),
                      ])),
            ),
          )),
      ]));
}

class HistoryTripCard extends StatelessWidget {
  const HistoryTripCard(
      {super.key, required this.request, required this.onDetails});
  final RescueRequestData request;
  final VoidCallback onDetails;
  @override
  Widget build(BuildContext context) {
    final color = switch (request.service) {
      RescueService.battery => const Color(0xFFB45309),
      RescueService.tire => const Color(0xFF0E7490),
      _ => BookingStyle.blue,
    };
    return _HistorySurface(
        child: InkWell(
            onTap: onDetails,
            borderRadius: BorderRadius.circular(RescueRadius.card),
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: .1),
                                    borderRadius: BorderRadius.circular(16)),
                                child: Icon(serviceIcon(request.service),
                                    color: color, size: 26)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(request.service.label, style: _title),
                                  const SizedBox(height: 4),
                                  Text(
                                      customerDate(request.createdAt,
                                          includeTime: true),
                                      style: _caption),
                                ])),
                          ]),
                      const SizedBox(height: 10),
                      Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusPill(stage: request.stage),
                            Text('Mã đơn: ${displayCode(request.requestCode)}',
                                style: RescueType.code),
                          ]),
                      const SizedBox(height: 12),
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: BookingStyle.pale,
                              borderRadius: BorderRadius.circular(14)),
                          child: Row(children: [
                            const Icon(Icons.directions_car_outlined,
                                color: BookingStyle.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(request.vehicle.label,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)))
                          ])),
                      if (request.address.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: BookingStyle.pale.withValues(alpha: .6),
                                borderRadius: BorderRadius.circular(16)),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      color: BookingStyle.blue, size: 22),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        const Text('Địa điểm cứu hộ',
                                            style: _caption),
                                        Text(request.address,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                height: 1.4,
                                                fontWeight: FontWeight.w600)),
                                      ])),
                                ])),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (request.price != null)
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Chi phí / báo giá',
                                        style: _caption),
                                    Text(money(request.price),
                                        style: _title.copyWith(
                                            color: BookingStyle.blue)),
                                  ]),
                            FilledButton.tonal(
                                onPressed: onDetails,
                                style: RescueButtons.style(
                                    RescueButtonKind.secondary),
                                child: const Text('Xem chi tiết')),
                          ]),
                    ]))));
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
                backgroundColor: BookingStyle.pale,
                child: Icon(Icons.history_rounded,
                    size: 32, color: BookingStyle.blue)),
            const SizedBox(height: 16),
            Text(
                switch (filterIndex) {
                  1 => 'Chưa có chuyến hoàn tất',
                  2 => 'Không có chuyến nào đã hủy',
                  _ => 'Chưa có lịch sử cứu hộ'
                },
                style: _title,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Các chuyến cứu hộ sẽ xuất hiện tại đây.',
                style: _caption, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
                onPressed: onRequest,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo yêu cầu cứu hộ')),
          ])));
}

class WarrantyBanner extends StatelessWidget {
  const WarrantyBanner({super.key});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(RescueRadius.card),
          gradient: const LinearGradient(
              colors: [Color(0xFFDCE9FF), Color(0xFFE1F7ED)])),
      child: const Row(children: [
        CircleAvatar(
            radius: 24,
            backgroundColor: BookingStyle.green,
            child: Icon(Icons.support_agent_rounded,
                color: Colors.white, size: 26)),
        SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hỗ trợ sau cứu hộ',
              style: TextStyle(
                  color: Color(0xFF00714D), fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('Tổng đài 1900 6868 hỗ trợ sau cứu hộ.', style: _caption),
        ])),
      ]));
}

class _HistorySurface extends StatelessWidget {
  const _HistorySurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => RescueCard(
      kind: RescueCardKind.history, padding: EdgeInsets.zero, child: child);
}
