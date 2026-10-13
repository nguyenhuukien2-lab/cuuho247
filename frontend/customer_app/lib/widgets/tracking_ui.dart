import 'stitch_customer_header.dart';
import '../app/mobile_ui.dart';
import '../core/utils/display_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app/app_controller.dart';
import '../services/location_service.dart';
import 'booking_ui.dart';
import 'customer_ui.dart';
import 'rescue_location_map.dart';
import 'rescue_widgets.dart';

abstract final class TrackingStyle {
  static const background = Color(0xFFF8F9FF);
  static const blue = Color(0xFF1D4ED8);
  static const darkBlue = Color(0xFF1D4ED8);
  static const navy = Color(0xFF0037B0);
  static const pale = Color(0xFFEEF4FF);
  static const green = Color(0xFF006C49);
  static const danger = Color(0xFFBA1A1A);
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

String trackingHeadline(RequestStage stage) => switch (stage) {
      RequestStage.searching => 'Đang tìm đối tác cứu hộ',
      RequestStage.accepted => 'Đối tác đã tiếp nhận yêu cầu',
      RequestStage.arriving => 'Đối tác đang di chuyển đến',
      RequestStage.inProgress => 'Đang hỗ trợ cứu hộ',
      RequestStage.completed => 'Cứu hộ đã hoàn tất',
      RequestStage.cancelled => 'Yêu cầu đã hủy',
    };

String trackingGuidance(RequestStage stage) => switch (stage) {
      RequestStage.searching => 'Hệ thống đang tìm đối tác phù hợp.',
      RequestStage.accepted => 'Giữ liên lạc để xác nhận vị trí cứu hộ.',
      RequestStage.arriving => 'Đối tác đang trên đường đến vị trí cứu hộ.',
      RequestStage.inProgress => 'Đối tác đang thực hiện cứu hộ.',
      RequestStage.completed => 'Xem chi tiết và đánh giá trong lịch sử.',
      RequestStage.cancelled => 'Bạn có thể xem lại yêu cầu trong lịch sử.',
    };

String trackingStageLabel(RequestStage stage) => switch (stage) {
      RequestStage.searching => 'Đang tìm',
      RequestStage.accepted => 'Đã nhận',
      RequestStage.arriving => 'Đang đến',
      RequestStage.inProgress => 'Đang hỗ trợ',
      RequestStage.completed => 'Hoàn tất',
      RequestStage.cancelled => 'Đã hủy',
    };

String trackingDisplayCode(String? code, {required String prefix}) {
  final value = code?.trim();
  return value != null && RegExp('^$prefix-[0-9]+\$').hasMatch(value)
      ? displayCode(value)
      : 'Chưa có mã';
}

class TrackingHeader extends StatelessWidget {
  const TrackingHeader({super.key, required this.onAccount});
  final VoidCallback onAccount;
  @override
  Widget build(BuildContext context) =>
      StitchCustomerHeader(onAccount: onAccount);
}

class TrackingCard extends StatelessWidget {
  const TrackingCard(
      {super.key, required this.child, this.kind = RescueCardKind.information});
  final Widget child;
  final RescueCardKind kind;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: kind == RescueCardKind.status
              ? const Color(0xFFF0FFF8)
              : Colors.white,
          borderRadius:
              BorderRadius.circular(kind == RescueCardKind.status ? 12 : 16),
          border: Border.all(
              color: kind == RescueCardKind.status
                  ? const Color(0xFF6CF8BB)
                  : TrackingStyle.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0F0B3A66), blurRadius: 14, offset: Offset(0, 6))
          ]),
      child: Material(color: Colors.transparent, child: child));
}

class TrackingBadge extends StatelessWidget {
  const TrackingBadge(this.label,
      {super.key,
      this.color = TrackingStyle.darkBlue,
      this.background = TrackingStyle.pale});
  final String label;
  final Color color, background;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TrackingStyle.caption
              .copyWith(color: color, fontWeight: FontWeight.w700)));
}

class TrackingStageBadge extends StatelessWidget {
  const TrackingStageBadge({super.key, required this.stage});
  final RequestStage stage;
  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (stage) {
      RequestStage.searching => (
          const Color(0xFFB45309),
          const Color(0xFFFEF3C7)
        ),
      RequestStage.completed => (
          const Color(0xFF15803D),
          const Color(0xFFDCFCE7)
        ),
      RequestStage.cancelled => (
          const Color(0xFFB91C1C),
          const Color(0xFFFFDAD6)
        ),
      _ => (TrackingStyle.darkBlue, const Color(0xFFDBEAFE)),
    };
    return TrackingBadge(trackingStageLabel(stage),
        color: color, background: background);
  }
}

class TrackingRefreshButton extends StatelessWidget {
  const TrackingRefreshButton(
      {super.key,
      required this.label,
      required this.onPressed,
      required this.loading,
      required this.icon});
  final String label;
  final VoidCallback onPressed;
  final bool loading;
  final IconData icon;
  @override
  Widget build(BuildContext context) => IconButton(
      tooltip: label,
      onPressed: loading ? null : onPressed,
      color: TrackingStyle.blue,
      icon: loading
          ? const SizedBox.square(
              dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, size: 20));
}

class TrackingStatusCard extends StatelessWidget {
  const TrackingStatusCard({
    super.key,
    required this.request,
    this.action,
    this.etaMinutes,
    this.distanceKm,
    this.speedKmh,
  });
  final RescueRequestData request;
  final Widget? action;
  // Presentation inputs only. The current screen has no travel data source.
  final int? etaMinutes;
  final double? distanceKm, speedKmh;
  @override
  Widget build(BuildContext context) {
    final updated = request.updatedAt.toLocal();
    final time =
        '${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}';
    final travelling = request.stage == RequestStage.accepted ||
        request.stage == RequestStage.arriving;
    final travelBlocks = <Widget>[
      if (travelling && etaMinutes != null && etaMinutes! >= 0)
        TrackingInfoBlock(
            label: 'ETA', value: '$etaMinutes phút', icon: Icons.schedule),
      if (travelling &&
          distanceKm != null &&
          distanceKm!.isFinite &&
          distanceKm! >= 0)
        TrackingInfoBlock(
            label: 'Khoảng cách',
            value: '${distanceKm!.toStringAsFixed(1)} km',
            icon: Icons.route_outlined),
      if (travelling &&
          speedKmh != null &&
          speedKmh!.isFinite &&
          speedKmh! >= 0)
        TrackingInfoBlock(
            label: 'Tốc độ',
            value: '${speedKmh!.toStringAsFixed(0)} km/h',
            icon: Icons.speed_outlined),
    ];
    final blocks = travelBlocks.isNotEmpty
        ? travelBlocks
        : <Widget>[
            if (!travelling)
              TrackingInfoBlock(
                  label: 'Trạng thái',
                  value: trackingStageLabel(request.stage),
                  icon: Icons.radar),
            if (!travelling || request.hasServerUpdateTime)
              TrackingInfoBlock(
                  label: 'Cập nhật',
                  value:
                      request.hasServerUpdateTime ? time : 'Chưa có cập nhật',
                  icon: Icons.update,
                  tooltip: request.hasServerUpdateTime
                      ? customerDate(request.updatedAt, includeTime: true)
                      : null),
            TrackingInfoBlock(
                label: 'Dịch vụ',
                value: request.service.label,
                icon: Icons.build_outlined),
          ];
    return TrackingCard(
        key: const ValueKey('tracking-hero'),
        kind: RescueCardKind.status,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
                child: Wrap(spacing: 6, runSpacing: 6, children: [
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                      'Mã đơn ${trackingDisplayCode(request.requestCode, prefix: 'CH')}',
                      style: TrackingStyle.caption.copyWith(
                          color: TrackingStyle.ink,
                          fontWeight: FontWeight.w700))),
              TrackingStageBadge(stage: request.stage),
            ])),
            if (action != null) action!,
          ]),
          const SizedBox(height: 8),
          Text(trackingHeadline(request.stage),
              style: TrackingStyle.title.copyWith(fontSize: 19)),
          const SizedBox(height: 4),
          Text(trackingGuidance(request.stage),
              style: TrackingStyle.body
                  .copyWith(fontSize: 12, color: TrackingStyle.muted)),
          const SizedBox(height: 10),
          IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                for (var index = 0; index < blocks.length; index++) ...[
                  if (index > 0) const SizedBox(width: 6),
                  Expanded(child: blocks[index]),
                ],
              ])),
        ]));
  }
}

class TrackingInfoBlock extends StatelessWidget {
  const TrackingInfoBlock(
      {super.key,
      required this.label,
      required this.value,
      this.tooltip,
      this.icon = Icons.info_outline});
  final String label, value;
  final String? tooltip;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final content = Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: const Color(0xFFF5F7FB),
            borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 13, color: TrackingStyle.muted),
            const SizedBox(width: 4),
            Expanded(
                child: Text(label,
                    style: TrackingStyle.caption.copyWith(fontSize: 10))),
          ]),
          const SizedBox(height: 4),
          Text(value,
              style: TrackingStyle.title
                  .copyWith(fontSize: 14, color: TrackingStyle.navy)),
        ]));
    return tooltip == null
        ? content
        : Tooltip(message: tooltip!, child: content);
  }
}

class TrackingMapCard extends StatelessWidget {
  const TrackingMapCard(
      {super.key,
      required this.request,
      this.embedded = false,
      this.partnerCoordinates,
      this.routeCoordinates = const []});
  final RescueRequestData request;
  final bool embedded;
  // Only a supplied route is rendered; never infer one from two markers.
  final RescueCoordinates? partnerCoordinates;
  final List<RescueCoordinates> routeCoordinates;
  RescueCoordinates? get coordinates {
    if (request.latitude == null || request.longitude == null) return null;
    final point = RescueCoordinates(request.latitude!, request.longitude!);
    return point.isValid ? point : null;
  }

  @override
  Widget build(BuildContext context) {
    final point = coordinates;
    final address = request.address.trim().isEmpty
        ? 'Chưa có địa chỉ cứu hộ'
        : request.address;
    final hasAssignment = request.stage == RequestStage.accepted ||
        request.stage == RequestStage.arriving ||
        request.stage == RequestStage.inProgress;
    final partner = hasAssignment && partnerCoordinates?.isValid == true
        ? partnerCoordinates
        : null;
    final hasRoute = hasAssignment &&
        routeCoordinates.length >= 2 &&
        routeCoordinates.every((point) => point.isValid);
    final hasPartnerMap = partner != null || hasRoute;
    if (point == null) {
      return TrackingCard(
          key: const ValueKey('tracking-location'),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.location_on_outlined, color: TrackingStyle.blue),
              SizedBox(width: 8),
              Expanded(child: Text('Vị trí cứu hộ', style: TrackingStyle.title))
            ]),
            const SizedBox(height: 10),
            Text(address,
                style:
                    TrackingStyle.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            const TrackingBadge('Vị trí nhập tay',
                color: Color(0xFFB45309), background: Color(0xFFFEF3C7)),
          ]));
    }
    return Container(
        key: const ValueKey('tracking-location'),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TrackingStyle.border)),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(children: [
              Stack(children: [
                RescueLocationMap(
                    coordinates: point,
                    height: 288,
                    showRecenterButton: true,
                    additionalMarkers: [
                      if (partner != null)
                        Marker(
                            point: LatLng(partner.latitude, partner.longitude),
                            width: 40,
                            height: 40,
                            child: Container(
                                key: const ValueKey('tracking-partner-marker'),
                                decoration: BoxDecoration(
                                    color: TrackingStyle.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 3)),
                                child: const Icon(Icons.local_shipping_outlined,
                                    semanticLabel: 'Vị trí đối tác',
                                    color: Colors.white,
                                    size: 22))),
                    ],
                    polylines: [
                      if (hasRoute)
                        Polyline(
                            points: routeCoordinates
                                .map((point) =>
                                    LatLng(point.latitude, point.longitude))
                                .toList(),
                            strokeWidth: 4,
                            color: TrackingStyle.blue),
                    ]),
                Positioned(
                    top: 10,
                    left: 10,
                    right: 64,
                    child: IgnorePointer(
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: TrackingBadge(
                                hasPartnerMap
                                    ? trackingHeadline(request.stage)
                                    : 'Vị trí cứu hộ',
                                background: Colors.white)))),
              ]),
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(hasRoute ? Icons.route_outlined : Icons.location_on,
                        color: TrackingStyle.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              hasRoute
                                  ? 'Lộ trình đến vị trí cứu hộ'
                                  : partner != null
                                      ? 'Vị trí đối tác đã cập nhật'
                                      : 'Vị trí cứu hộ đã xác nhận',
                              style: TrackingStyle.caption),
                          const SizedBox(height: 3),
                          Text(address,
                              style: TrackingStyle.body
                                  .copyWith(fontWeight: FontWeight.w600)),
                        ])),
                  ])),
            ])));
  }
}

class RescuerInfoCard extends StatelessWidget {
  const RescuerInfoCard(
      {super.key,
      required this.stage,
      this.embedded = false,
      this.partnerName,
      this.avatar,
      this.rating,
      this.vehicleLabel,
      this.licensePlate,
      this.phone,
      this.onCall,
      this.onChat});
  final RequestStage stage;
  final bool embedded;
  // Optional display data and existing actions; no profile/contact lookup.
  final String? partnerName, vehicleLabel, licensePlate, phone;
  final ImageProvider<Object>? avatar;
  final double? rating;
  final VoidCallback? onCall, onChat;

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
    final waiting = stage == RequestStage.searching;
    final name = waiting ? null : _displayValue(partnerName);
    final vehicle = waiting ? null : _displayValue(vehicleLabel);
    final plate = waiting ? null : _displayValue(licensePlate);
    final contactPhone = waiting ? null : _displayValue(phone);
    final hasRating = !waiting &&
        rating != null &&
        rating!.isFinite &&
        rating! >= 0 &&
        rating! <= 5;
    final canCall = contactPhone != null && onCall != null;
    final content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            CircleAvatar(
                key: const ValueKey('tracking-partner-avatar'),
                radius: 22,
                backgroundColor: TrackingStyle.pale,
                foregroundColor: TrackingStyle.blue,
                backgroundImage: waiting ? null : avatar,
                child: waiting || avatar == null
                    ? Icon(
                        waiting
                            ? Icons.person_search_outlined
                            : Icons.person_outline,
                        size: 24)
                    : null),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      name ??
                          switch (stage) {
                            RequestStage.searching =>
                              'Chưa có đối tác nhận đơn',
                            RequestStage.accepted ||
                            RequestStage.arriving ||
                            RequestStage.inProgress =>
                              'Đối tác đã nhận đơn',
                            RequestStage.completed =>
                              'Đối tác đã hoàn tất hỗ trợ',
                            RequestStage.cancelled => 'Yêu cầu đã hủy',
                          },
                      style: TrackingStyle.title.copyWith(fontSize: 15)),
                  if (!waiting) ...[
                    const SizedBox(height: 4),
                    Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TrackingStageBadge(stage: stage),
                          if (hasRating)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFF59E0B), size: 16),
                              const SizedBox(width: 3),
                              Text(rating!.toStringAsFixed(1),
                                  style: TrackingStyle.body
                                      .copyWith(fontWeight: FontWeight.w700)),
                            ]),
                        ]),
                  ],
                  if (waiting ||
                      stage == RequestStage.cancelled ||
                      (name == null && contactPhone == null)) ...[
                    const SizedBox(height: 4),
                    Text(
                        waiting
                            ? 'Hệ thống đang tìm đối tác phù hợp'
                            : stage == RequestStage.cancelled
                                ? 'Xem lại yêu cầu trong lịch sử.'
                                : 'Chưa có thông tin liên hệ đối tác trong đơn.',
                        style: TrackingStyle.body.copyWith(
                            fontSize: 12, color: TrackingStyle.muted)),
                  ],
                ])),
          ]),
          if (vehicle != null || plate != null) ...[
            const SizedBox(height: 10),
            Container(
                key: const ValueKey('tracking-partner-vehicle'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FB),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.local_shipping_outlined,
                      color: TrackingStyle.blue, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        if (vehicle != null)
                          Text(vehicle,
                              style: TrackingStyle.body
                                  .copyWith(fontWeight: FontWeight.w600)),
                        if (plate != null)
                          Padding(
                              padding:
                                  EdgeInsets.only(top: vehicle != null ? 3 : 0),
                              child: Text('Biển số: $plate',
                                  style: TrackingStyle.caption)),
                      ])),
                ])),
          ],
          if (canCall || (!waiting && onChat != null)) ...[
            const SizedBox(height: 10),
            Row(children: [
              if (canCall)
                Expanded(
                    flex: 4,
                    child: FilledButton.icon(
                        onPressed: onCall,
                        style: FilledButton.styleFrom(
                            backgroundColor: TrackingStyle.blue,
                            minimumSize: const Size(48, 56),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(Icons.call_outlined, size: 20),
                        label: const Text('Gọi đối tác'))),
              if (canCall && !waiting && onChat != null)
                const SizedBox(width: 8),
              if (!waiting && onChat != null)
                Expanded(
                    child: SizedBox(
                        height: 56,
                        child: IconButton.outlined(
                            tooltip: 'Nhắn tin',
                            onPressed: onChat,
                            style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            icon: const Icon(Icons.chat_bubble_outline,
                                size: 22)))),
            ]),
          ],
        ]);
    return embedded
        ? content
        : TrackingCard(key: const ValueKey('tracking-partner'), child: content);
  }
}

class TrackingTimeline extends StatelessWidget {
  const TrackingTimeline({super.key, required this.request});
  final RescueRequestData request;
  static const labels = [
    'Đã gửi yêu cầu thành công',
    'Đang tìm đối tác gần nhất',
    'Đối tác tiếp nhận đơn',
    'Đang trên đường tới',
    'Đang hỗ trợ tại chỗ',
    'Hoàn tất'
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
        key: const ValueKey('tracking-progress'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(
                child: Text('Tiến trình cứu hộ', style: TrackingStyle.title)),
            const SizedBox(width: 8),
            Flexible(
                child: current < 0
                    ? const TrackingBadge('Đã hủy',
                        color: Color(0xFFB91C1C), background: Color(0xFFFFDAD6))
                    : TrackingBadge('Bước ${current + 1}/6')),
          ]),
          const SizedBox(height: 12),
          for (var index = 0; index < labels.length; index++)
            TimelineStep(
                key: ValueKey('tracking-timeline-$index'),
                title: labels[index],
                icon: icons[index],
                done: index == 0 ||
                    (index == 5 && request.stage == RequestStage.completed),
                current: index == current,
                last: index == labels.length - 1 && current >= 0,
                // updated_at also changes on quotes/vehicle deletion; it is
                // not a status-event timestamp. History renders actual events.
                time: index == 0 ? time : null,
                activeColor: request.stage == RequestStage.completed
                    ? TrackingStyle.green
                    : TrackingStyle.blue),
          if (current < 0)
            TimelineStep(
                key: const ValueKey('tracking-timeline-cancelled'),
                title: 'Yêu cầu đã hủy',
                icon: Icons.cancel_outlined,
                done: false,
                current: true,
                last: true,
                activeColor: TrackingStyle.danger,
                time: null),
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
      this.subtitle,
      this.activeColor});
  final String title;
  final IconData icon;
  final bool done, current, last;
  final String? time, subtitle;
  final Color? activeColor;
  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? TrackingStyle.blue;
    return Semantics(
        label:
            '$title, ${done ? 'đã xong' : current ? 'hiện tại' : 'chưa có mốc cập nhật'}',
        child: Container(
            margin: EdgeInsets.only(bottom: last ? 0 : 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: current ? TrackingStyle.pale : Colors.transparent,
                borderRadius: BorderRadius.circular(12)),
            child: IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  SizedBox(
                      width: 28,
                      child: Column(children: [
                        Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: done
                                    ? const Color(0xFFDCFCE7)
                                    : current
                                        ? color
                                        : const Color(0xFFF1F4F9)),
                            child: Icon(done ? Icons.check : icon,
                                size: 16,
                                color: done
                                    ? TrackingStyle.green
                                    : current
                                        ? Colors.white
                                        : TrackingStyle.muted)),
                        if (!last)
                          Expanded(
                              child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Container(
                                      width: 2,
                                      color: done
                                          ? const Color(0xFFBBF7D0)
                                          : TrackingStyle.border))),
                      ])),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Padding(
                          padding: const EdgeInsets.only(top: 3, bottom: 8),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: TrackingStyle.body.copyWith(
                                        fontWeight: current || done
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: current
                                            ? color
                                            : done
                                                ? TrackingStyle.ink
                                                : TrackingStyle.muted)),
                                if (subtitle != null)
                                  Text(subtitle!, style: TrackingStyle.caption),
                                if (time != null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(time!,
                                          style: TrackingStyle.caption)),
                              ]))),
                ]))));
  }
}

class QuoteStatusCard extends StatelessWidget {
  const QuoteStatusCard({super.key, required this.price, this.quoteCode});
  final int? price;
  final String? quoteCode;
  @override
  Widget build(BuildContext context) {
    final code = trackingDisplayCode(quoteCode, prefix: 'BG');
    final hasQuote = price != null || code != 'Chưa có mã';
    return TrackingCard(
        key: const ValueKey('tracking-quote'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.receipt_long_outlined,
                color: TrackingStyle.blue, size: 22),
            const SizedBox(width: 8),
            Expanded(
                child: Text(hasQuote ? 'Báo giá minh bạch' : 'Báo giá',
                    style: TrackingStyle.title))
          ]),
          const SizedBox(height: 12),
          if (!hasQuote) ...[
            const Align(
                alignment: Alignment.centerLeft,
                child: TrackingBadge('Chưa có báo giá',
                    color: Color(0xFFB45309), background: Color(0xFFFEF3C7))),
            const SizedBox(height: 10),
            const Text('Đối tác sẽ gửi báo giá trước khi thực hiện.',
                style: TrackingStyle.body),
          ] else ...[
            Text('Mã báo giá: $code',
                style: TrackingStyle.body
                    .copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
            if (price == null) ...[
              const SizedBox(height: 8),
              const Text('Chưa có tổng tiền báo giá.',
                  style: TrackingStyle.caption)
            ],
          ],
          if (price != null) ...[
            const SizedBox(height: 12),
            Container(
                key: const ValueKey('tracking-quote-total'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: TrackingStyle.pale,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tổng tiền', style: TrackingStyle.caption),
                      const SizedBox(height: 4),
                      Text(money(price),
                          style: TrackingStyle.title.copyWith(
                              fontSize: 28, color: TrackingStyle.blue)),
                    ])),
          ],
        ]));
  }
}

class TrackingSupportCard extends StatelessWidget {
  const TrackingSupportCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
      key: const ValueKey('tracking-support'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFFFDAD6),
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .65),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.support_agent,
                color: TrackingStyle.danger, size: 23)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hỗ trợ',
              style: TrackingStyle.title.copyWith(color: TrackingStyle.danger)),
          const SizedBox(height: 4),
          const Text('Chưa có thông tin liên hệ hỗ trợ.',
              style: TrackingStyle.caption),
        ])),
      ]));
}

class TrackingOrderCard extends StatelessWidget {
  const TrackingOrderCard(
      {super.key, required this.request, this.details = const []});
  final RescueRequestData request;
  final List<Widget> details;
  @override
  Widget build(BuildContext context) => TrackingCard(
        key: const ValueKey('tracking-request-info'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Thông tin yêu cầu', style: TrackingStyle.title),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            Text(request.service.label,
                style: RescueType.body.copyWith(fontWeight: FontWeight.w600)),
            Text(request.vehicle.label, style: RescueType.body)
          ]),
          const SizedBox(height: 8),
          Text(
              request.address.trim().isEmpty
                  ? 'Chưa có địa chỉ cứu hộ'
                  : request.address,
              style: RescueType.body),
          const SizedBox(height: 6),
          Text('Tạo lúc ${customerDate(request.createdAt, includeTime: true)}',
              style: RescueType.caption),
          ...details,
        ]),
      );
}

class TrackingQuotePartnerCard extends StatelessWidget {
  const TrackingQuotePartnerCard({super.key, required this.request});
  final RescueRequestData request;
  @override
  Widget build(BuildContext context) => TrackingCard(
        key: const ValueKey('tracking-quote-partner'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Báo giá / Đối tác', style: RescueType.section),
          const SizedBox(height: 10),
          if (trackingDisplayCode(request.quoteCode, prefix: 'BG') !=
              'Chưa có mã')
            TrackingInfoRow('Mã báo giá',
                trackingDisplayCode(request.quoteCode, prefix: 'BG')),
          if (request.price != null)
            TrackingInfoRow('Tổng tiền', money(request.price), emphasized: true)
          else
            const Text('Chưa có báo giá', style: RescueType.body),
          const SizedBox(height: 12),
          RescuerInfoCard(stage: request.stage, embedded: true),
        ]),
      );
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

class EmergencySupportCard extends StatelessWidget {
  const EmergencySupportCard({super.key});
  @override
  Widget build(BuildContext context) => const TrackingSupportCard();
}
