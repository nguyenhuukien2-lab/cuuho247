import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_controller.dart';
import '../services/location_service.dart';
import 'booking_ui.dart';
import 'customer_ui.dart';
import 'request_location_card.dart';
import 'rescue_widgets.dart';

String trackingHeadline(RequestStage stage) => switch (stage) {
      RequestStage.searching => 'Đang tìm đối tác gần bạn',
      RequestStage.accepted => 'Đối tác đã tiếp nhận yêu cầu',
      RequestStage.arriving => 'Kỹ thuật viên đang di chuyển đến',
      RequestStage.inProgress => 'Đối tác đang hỗ trợ',
      RequestStage.completed => 'Yêu cầu đã hoàn tất',
      RequestStage.cancelled => 'Yêu cầu đã hủy',
    };

class TrackingCard extends StatelessWidget {
  const TrackingCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0F1D4ED8),
                  blurRadius: 20,
                  offset: Offset(0, 4))
            ]),
        child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: Padding(padding: const EdgeInsets.all(16), child: child)),
      );
}

class TrackingStatusCard extends StatelessWidget {
  const TrackingStatusCard({super.key, required this.request});
  final RescueRequestData request;
  @override
  Widget build(BuildContext context) => TrackingCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
            Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: BookingStyle.pale,
                          borderRadius: BorderRadius.circular(30)),
                      child: Text('Mã đơn #${request.id}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: BookingStyle.muted))),
                  if (!request.stage.isTerminal)
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(30)),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle,
                                  size: 7, color: BookingStyle.green),
                              SizedBox(width: 6),
                              Text('Trực tiếp',
                                  style: TextStyle(
                                      color: Color(0xFF00714D),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700))
                            ])),
                ]),
            const SizedBox(height: 14),
            AnimatedSwitcher(
                duration: customerMotion(context),
                child: Align(
                    key: ValueKey(request.stage),
                    alignment: Alignment.centerLeft,
                    child: Text(trackingHeadline(request.stage),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            color: BookingStyle.ink)))),
            const SizedBox(height: 6),
            Text(
                switch (request.stage) {
                  RequestStage.searching =>
                    'Yêu cầu đã được gửi. Vui lòng giữ liên lạc.',
                  RequestStage.accepted =>
                    'Đối tác sẽ liên hệ để xác nhận hỗ trợ.',
                  RequestStage.arriving =>
                    'Giữ máy và bật đèn cảnh báo sự cố (hazard).',
                  RequestStage.inProgress =>
                    'Theo dõi tiến trình và kiểm tra báo giá.',
                  RequestStage.completed =>
                    'Bạn có thể xem chi tiết và đánh giá trong lịch sử.',
                  RequestStage.cancelled =>
                    'Bạn có thể xem lại yêu cầu trong lịch sử.',
                },
                style: const TextStyle(
                    fontSize: 12, color: BookingStyle.muted, height: 1.5)),
            if (request.hasServerUpdateTime)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      'Cập nhật ${customerDate(request.updatedAt, includeTime: true)}',
                      style: const TextStyle(
                          fontSize: 12, color: BookingStyle.muted))),
            if (!request.stage.isTerminal) ...[
              const SizedBox(height: 14),
              const LiveMetricsGrid()
            ],
          ]));
}

/// The current request model has no telemetry; do not simulate a countdown.
class LiveMetricsGrid extends StatelessWidget {
  const LiveMetricsGrid({super.key});
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: BookingStyle.pale, borderRadius: BorderRadius.circular(14)),
      child: const Row(children: [
        Icon(Icons.sensors, color: BookingStyle.blue, size: 20),
        SizedBox(width: 8),
        Expanded(
            child: Text('Đang cập nhật',
                style: TextStyle(color: BookingStyle.muted, fontSize: 12)))
      ]));
}

class TrackingMapCard extends StatelessWidget {
  const TrackingMapCard({super.key, required this.request});
  final RescueRequestData request;
  @override
  Widget build(BuildContext context) => TrackingCard(
          child: RequestLocationCard(
        address: request.address,
        coordinates: request.latitude != null && request.longitude != null
            ? RescueCoordinates(request.latitude!, request.longitude!)
            : null,
      ));
}

/// An accepted stage confirms assignment, but the current model exposes no
/// rescuer profile or phone. Keep the missing-data state explicit and brief.
class RescuerInfoCard extends StatelessWidget {
  const RescuerInfoCard({super.key});
  @override
  Widget build(BuildContext context) => TrackingCard(
          child: Row(children: [
        Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: BookingStyle.pale,
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.engineering_outlined,
                color: BookingStyle.blue, size: 28)),
        const SizedBox(width: 12),
        const Expanded(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Kỹ thuật viên',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: BookingStyle.ink)),
              SizedBox(height: 4),
              Text('Chưa có dữ liệu',
                  style: TextStyle(fontSize: 12, color: BookingStyle.muted)),
            ])),
      ]));
}

class TrackingTimeline extends StatelessWidget {
  const TrackingTimeline({super.key, required this.request});
  final RescueRequestData request;
  static const labels = [
    'Đã gửi yêu cầu',
    'Đang tìm xe cứu hộ gần nhất',
    'KTV tiếp nhận đơn',
    'Đang trên đường tới',
    'Đang hỗ trợ tại chỗ',
    'Hoàn tất & nghiệm thu'
  ];
  static const icons = [
    Icons.send_outlined,
    Icons.search,
    Icons.assignment_turned_in_outlined,
    Icons.local_shipping_outlined,
    Icons.build_outlined,
    Icons.task_alt
  ];
  static int currentStep(RequestStage stage) => switch (stage) {
        RequestStage.searching => 1,
        RequestStage.accepted => 2,
        RequestStage.arriving => 3,
        RequestStage.inProgress => 4,
        RequestStage.completed => 5,
        RequestStage.cancelled => -1,
      };
  @override
  Widget build(BuildContext context) {
    final current = currentStep(request.stage);
    final created = request.createdAt.toLocal();
    final time =
        '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
    return TrackingCard(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Expanded(
            child: Text('Tiến trình cứu hộ',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: BookingStyle.ink))),
        const SizedBox(width: 8),
        Text(current < 0 ? 'Đã hủy' : 'Bước ${current + 1} / 6',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: current < 0
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF00714D)))
      ]),
      const Divider(height: 24, color: BookingStyle.pale),
      for (var i = 0; i < labels.length; i++)
        TimelineStep(
          key: ValueKey('tracking-timeline-$i'),
          title: labels[i],
          icon: icons[i],
          done: request.stage == RequestStage.completed ||
              (current >= 0 && i < current) ||
              (current < 0 && i == 0),
          current: current == i && request.stage != RequestStage.completed,
          last: i == labels.length - 1,
          time: i == 0 ? time : null,
          subtitle: i == 0 ? request.service.label : null,
        ),
    ]));
  }
}

class TimelineStep extends StatelessWidget {
  const TimelineStep(
      {super.key,
      required this.title,
      required this.icon,
      required this.done,
      required this.current,
      required this.last,
      this.time,
      this.subtitle});
  final String title;
  final IconData icon;
  final bool done, current, last;
  final String? time, subtitle;
  @override
  Widget build(BuildContext context) => Semantics(
      label: '$title, ${done ? 'đã xong' : current ? 'hiện tại' : 'chưa tới'}',
      child: Container(
        margin: EdgeInsets.only(bottom: last ? 0 : 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: current ? BookingStyle.pale : Colors.transparent,
            borderRadius: BorderRadius.circular(14)),
        child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 32,
              child: Column(children: [
                Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? const Color(0xFFD1FAE5)
                            : current
                                ? BookingStyle.blue
                                : const Color(0xFFE5EEFF)),
                    child: Icon(done ? Icons.check : icon,
                        size: 17,
                        color: done
                            ? const Color(0xFF00714D)
                            : current
                                ? Colors.white
                                : const Color(0xFF747686))),
                if (!last)
                  Expanded(
                      child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                              width: 2,
                              color: done
                                  ? const Color(0xFFD1FAE5)
                                  : const Color(0xFFE5EEFF)))),
              ])),
          const SizedBox(width: 12),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.only(top: 3, bottom: 8),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: done || current
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: current
                                    ? BookingStyle.blue
                                    : done
                                        ? BookingStyle.ink
                                        : const Color(0xFF747686))),
                        if (subtitle != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(subtitle!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: BookingStyle.muted))),
                        if (time != null || current)
                          Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(current ? 'Hiện tại' : time!,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: current
                                          ? BookingStyle.blue
                                          : BookingStyle.muted))),
                      ]))),
        ])),
      ));
}

class QuoteStatusCard extends StatelessWidget {
  const QuoteStatusCard({super.key, required this.price});
  final int? price;
  @override
  Widget build(BuildContext context) => TrackingCard(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Row(children: [
              Icon(Icons.receipt_long_outlined,
                  color: BookingStyle.green, size: 20),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Báo giá minh bạch',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: BookingStyle.ink)))
            ]),
            const SizedBox(height: 12),
            if (price == null)
              const Text('Đối tác sẽ gửi báo giá sau khi kiểm tra.',
                  style: TextStyle(fontSize: 14, color: BookingStyle.muted))
            else ...[
              const Divider(color: BookingStyle.pale),
              const Text('Tổng báo giá',
                  style: TextStyle(fontSize: 12, color: BookingStyle.muted)),
              const SizedBox(height: 4),
              Text(money(price),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: BookingStyle.blue)),
            ],
          ]));
}

class EmergencySupportCard extends StatelessWidget {
  const EmergencySupportCard({super.key});
  Future<void> _call(BuildContext context) async {
    try {
      if (await launchUrl(Uri(scheme: 'tel', path: '19006868'))) return;
    } catch (_) {}
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hotline SOS: 1900 6868')));
  }

  @override
  Widget build(BuildContext context) => Material(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
          onTap: () => _call(context),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(12)),
                    child:
                        const Icon(Icons.support_agent, color: Colors.white)),
                const SizedBox(width: 12),
                const Expanded(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Hỗ trợ khẩn cấp',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF93000A))),
                      SizedBox(height: 4),
                      Text('1900 6868',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444))),
                      Text('Tổng đài hỗ trợ 24/7',
                          style: TextStyle(
                              fontSize: 12, color: BookingStyle.muted)),
                    ])),
                const Icon(Icons.chevron_right, color: Color(0xFFEF4444)),
              ]))));
}
