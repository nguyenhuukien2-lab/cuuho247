import '../app/mobile_ui.dart';
import '../core/utils/display_code.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_controller.dart';
import '../services/location_service.dart';
import 'booking_ui.dart';
import 'customer_ui.dart';
import 'request_location_card.dart';
import 'rescue_widgets.dart';

String trackingHeadline(RequestStage stage) => switch (stage) {
      RequestStage.searching => 'Đang chờ đối tác nhận đơn',
      RequestStage.accepted => 'Đối tác đã tiếp nhận yêu cầu',
      RequestStage.arriving => 'Đối tác đang di chuyển đến',
      RequestStage.inProgress => 'Đối tác đang hỗ trợ',
      RequestStage.completed => 'Yêu cầu đã hoàn tất',
      RequestStage.cancelled => 'Yêu cầu đã hủy',
    };

// Only public CH/BG codes belong in this screen, never internal identifiers.
String trackingDisplayCode(String? code, {required String prefix}) {
  final value = code?.trim();
  return value != null && RegExp('^$prefix-[0-9]+\$').hasMatch(value)
      ? displayCode(value)
      : 'Chưa có mã';
}

class TrackingCard extends StatelessWidget {
  const TrackingCard(
      {super.key, required this.child, this.kind = RescueCardKind.information});
  final Widget child;
  final RescueCardKind kind;
  @override
  Widget build(BuildContext context) => RescueCard(kind: kind, child: child);
}

class TrackingStatusCard extends StatelessWidget {
  const TrackingStatusCard({super.key, required this.request, this.action});
  final RescueRequestData request;
  final Widget? action;
  @override
  Widget build(BuildContext context) => TrackingCard(
      kind: RescueCardKind.status,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RescueStatusBadge(
                      status: request.stage.databaseValue,
                      label: request.stage == RequestStage.searching
                          ? 'Chờ nhận đơn'
                          : null),
                  Text(
                      'Mã đơn: ${trackingDisplayCode(request.requestCode, prefix: 'CH')}',
                      style: RescueType.code),
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
                    fontSize: 14, color: BookingStyle.muted, height: 1.5)),
            const SizedBox(height: 12),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: BookingStyle.pale,
                    borderRadius: BorderRadius.circular(RescueRadius.control)),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.update_rounded,
                          color: BookingStyle.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Cập nhật gần nhất',
                                style: RescueType.title),
                            const SizedBox(height: 4),
                            Text(
                                request.hasServerUpdateTime
                                    ? customerDate(request.updatedAt,
                                        includeTime: true)
                                    : 'Chưa có thời gian cập nhật trạng thái.',
                                style: RescueType.caption),
                          ])),
                    ])),
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ]));
}

/// Essential order details stay visible instead of hiding in an expansion.
class TrackingOrderCard extends StatelessWidget {
  const TrackingOrderCard({super.key, required this.request});
  final RescueRequestData request;
  @override
  Widget build(BuildContext context) => TrackingCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
            const Text('Thông tin yêu cầu', style: RescueType.section),
            const SizedBox(height: 8),
            TrackingInfoRow('Mã đơn',
                trackingDisplayCode(request.requestCode, prefix: 'CH')),
            TrackingInfoRow('Dịch vụ', request.service.label),
            TrackingInfoRow('Xe', request.vehicle.label),
            TrackingInfoRow(
                'Địa điểm',
                request.address.trim().isEmpty
                    ? 'Chưa có địa chỉ cứu hộ'
                    : request.address),
            TrackingInfoRow('Thời gian tạo',
                customerDate(request.createdAt, includeTime: true)),
            const Divider(height: 24, color: RescueColors.border),
            TrackingInfoRow(
                'Báo giá',
                request.price == null
                    ? 'Chưa có báo giá'
                    : money(request.price),
                emphasized: request.price != null),
            if (trackingDisplayCode(request.quoteCode, prefix: 'BG') !=
                'Chưa có mã')
              TrackingInfoRow('Mã báo giá',
                  trackingDisplayCode(request.quoteCode, prefix: 'BG')),
            const Divider(height: 24, color: RescueColors.border),
            RescuerInfoCard(stage: request.stage, embedded: true),
          ]));
}

/// Stack labels on small phones or with large text, so values keep their space.
class TrackingInfoRow extends StatelessWidget {
  const TrackingInfoRow(this.label, this.value,
      {super.key, this.emphasized = false});
  final String label, value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(builder: (context, constraints) {
        final labelWidget = Text(label, style: RescueType.caption);
        final valueWidget = Text(value,
            style: RescueType.body.copyWith(
                fontWeight: FontWeight.w600,
                color: emphasized ? BookingStyle.blue : BookingStyle.ink));
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 18) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 4), valueWidget]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 100, child: labelWidget),
          const SizedBox(width: 12),
          Expanded(child: valueWidget),
        ]);
      }));
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
  const RescuerInfoCard(
      {super.key, required this.stage, this.embedded = false});
  final RequestStage stage;
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final waiting = stage == RequestStage.searching;
    final content =
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: BookingStyle.pale,
              borderRadius: BorderRadius.circular(16)),
          child: Icon(
              waiting ? Icons.person_search_outlined : Icons.handshake_outlined,
              color: BookingStyle.blue,
              size: 22)),
      const SizedBox(width: 12),
      Expanded(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Text('Đối tác hỗ trợ', style: RescueType.caption),
            const SizedBox(height: 4),
            Text(
                switch (stage) {
                  RequestStage.searching => 'Chưa có đối tác nhận đơn',
                  RequestStage.accepted ||
                  RequestStage.arriving ||
                  RequestStage.inProgress =>
                    'Đối tác đã nhận đơn',
                  RequestStage.completed => 'Đối tác đã hoàn tất hỗ trợ',
                  RequestStage.cancelled => 'Yêu cầu đã hủy',
                },
                style: RescueType.title),
            const SizedBox(height: 4),
            Text(
                waiting
                    ? 'Hệ thống đang chờ đối tác phù hợp'
                    : stage == RequestStage.cancelled
                        ? 'Xem lại thông tin yêu cầu trong lịch sử.'
                        : 'Chưa có thông tin liên hệ đối tác trong đơn.',
                style: RescueType.caption),
          ])),
    ]);
    return embedded ? content : TrackingCard(child: content);
  }
}

class TrackingTimeline extends StatelessWidget {
  const TrackingTimeline({super.key, required this.request});
  final RescueRequestData request;
  static const labels = [
    'Đã gửi yêu cầu',
    'Chờ đối tác nhận đơn',
    'Đối tác tiếp nhận đơn',
    'Đang trên đường tới',
    'Đang hỗ trợ tại chỗ',
    'Hoàn tất yêu cầu'
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
        Flexible(
            child: Text(current < 0 ? 'Đã hủy' : 'Bước ${current + 1} / 6',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: current < 0
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF00714D))))
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
  Widget build(BuildContext context) {
    final highlighted = current || (done && last);
    return Semantics(
        label:
            '$title, ${done ? 'đã xong' : current ? 'hiện tại' : 'chưa tới'}',
        child: Container(
          margin: EdgeInsets.only(bottom: last ? 0 : 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: highlighted ? BookingStyle.pale : Colors.transparent,
              border: highlighted ? Border.all(color: BookingStyle.blue) : null,
              borderRadius: BorderRadius.circular(14)),
          child: IntrinsicHeight(
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                                  fontWeight: highlighted
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: highlighted
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
                                child: Text(
                                    current ? 'Hiện tại' : 'Đã gửi lúc $time',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: current
                                            ? BookingStyle.blue
                                            : BookingStyle.muted))),
                        ]))),
          ])),
        ));
  }
}

class QuoteStatusCard extends StatelessWidget {
  const QuoteStatusCard({super.key, required this.price, this.quoteCode});
  final int? price;
  final String? quoteCode;
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
              Text(
                  'Mã báo giá: ${trackingDisplayCode(quoteCode, prefix: 'BG')}',
                  style: RescueType.code),
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
      borderRadius: BorderRadius.circular(RescueRadius.card),
      child: InkWell(
          onTap: () => _call(context),
          borderRadius: BorderRadius.circular(RescueRadius.card),
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
