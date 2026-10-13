import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../core/utils/display_code.dart';
import 'customer_ui.dart' show customerDate;

const _blue = Color(0xFF0B4EDB);
const _ink = Color(0xFF0B1C30);
const _secondary = Color(0xFF434655);

/// The same main-row / status-strip skeleton for every request stage.
/// Optional partner and travel inputs must come from verified, already loaded
/// data. The current home caller supplies none; this widget performs no lookup.
class ActiveOrderBanner extends StatelessWidget {
  const ActiveOrderBanner({
    super.key,
    required this.request,
    required this.onTrack,
    this.partnerName,
    this.partnerAvatar,
    this.etaMinutes,
    this.distanceKm,
  });

  final RescueRequestData request;
  final VoidCallback onTrack;
  final String? partnerName;
  final ImageProvider<Object>? partnerAvatar;
  final int? etaMinutes;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final searching = request.stage == RequestStage.searching;
    final name = searching ? null : partnerName?.trim();
    final hasName = name?.isNotEmpty == true;
    return Container(
      key: const ValueKey('home-active-surface'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFDCEEFF), Color(0xFFDDFBEF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0037B0).withValues(alpha: .08),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _MainRow(
          key: const ValueKey('home-active-summary'),
          request: request,
          partnerName: hasName ? name : null,
          avatar: searching ? null : partnerAvatar,
          etaMinutes: searching || etaMinutes == null || etaMinutes! < 0
              ? null
              : etaMinutes,
          distanceKm: searching ||
                  distanceKm == null ||
                  !distanceKm!.isFinite ||
                  distanceKm! < 0
              ? null
              : distanceKm,
        ),
        const SizedBox(height: 10),
        _StatusStrip(
            key: const ValueKey('home-active-footer'),
            stage: request.stage,
            onTrack: onTrack),
      ]),
    );
  }
}

class _MainRow extends StatelessWidget {
  const _MainRow(
      {super.key,
      required this.request,
      this.partnerName,
      this.avatar,
      this.etaMinutes,
      this.distanceKm});
  final RescueRequestData request;
  final String? partnerName;
  final ImageProvider<Object>? avatar;
  final int? etaMinutes;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final hasMeta =
        etaMinutes != null || distanceKm != null || request.hasServerUpdateTime;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
            child: Row(children: [
          _LeadingVisual(
              key: const ValueKey('home-active-icon'),
              request: request,
              avatar: avatar,
              hasPartner: partnerName != null),
          const SizedBox(width: 10),
          Expanded(
              child: _MainContent(
                  key: const ValueKey('home-active-main-content'),
                  request: request,
                  partnerName: partnerName)),
        ])),
        if (hasMeta) ...[
          const SizedBox(width: 6),
          SizedBox(
              width: 46,
              child: _StatusMeta(
                  key: const ValueKey('home-active-meta'),
                  request: request,
                  etaMinutes: etaMinutes,
                  distanceKm: distanceKm)),
        ],
      ]),
    );
  }
}

class _LeadingVisual extends StatelessWidget {
  const _LeadingVisual(
      {super.key,
      required this.request,
      required this.hasPartner,
      this.avatar});
  final RescueRequestData request;
  final bool hasPartner;
  final ImageProvider<Object>? avatar;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 23,
        backgroundColor: Colors.white.withValues(alpha: .8),
        foregroundImage: avatar,
        onForegroundImageError: avatar == null ? null : (error, stackTrace) {},
        child: Icon(
          request.stage == RequestStage.searching
              ? Icons.search_rounded
              : hasPartner
                  ? Icons.person_outline_rounded
                  : switch (request.service) {
                      RescueService.tire => Icons.tire_repair,
                      RescueService.battery => Icons.battery_charging_full,
                      RescueService.fuel => Icons.local_gas_station_outlined,
                      RescueService.towing => Icons.rv_hookup,
                      RescueService.other => Icons.build_outlined,
                    },
          size: 22,
          color: _blue,
        ),
      );
}

class _MainContent extends StatelessWidget {
  const _MainContent({super.key, required this.request, this.partnerName});
  final RescueRequestData request;
  final String? partnerName;

  @override
  Widget build(BuildContext context) {
    final (badge, color, background) = switch (request.stage) {
      RequestStage.searching => (
          'ĐANG TÌM ĐỐI TÁC',
          const Color(0xFFB45309),
          const Color(0xFFFEF3C7)
        ),
      RequestStage.accepted => (
          'ĐÃ NHẬN YÊU CẦU',
          const Color(0xFF1D4ED8),
          const Color(0xFFDBEAFE)
        ),
      RequestStage.arriving => (
          'ĐANG DI CHUYỂN',
          const Color(0xFF1D4ED8),
          const Color(0xFFDBEAFE)
        ),
      RequestStage.inProgress => (
          'ĐANG HỖ TRỢ',
          const Color(0xFF1D4ED8),
          const Color(0xFFFFF1E8)
        ),
      RequestStage.completed => (
          'ĐÃ HOÀN TẤT',
          const Color(0xFF15803D),
          const Color(0xFFDCFCE7)
        ),
      RequestStage.cancelled => (
          'ĐÃ HỦY',
          const Color(0xFFB91C1C),
          const Color(0xFFFFDAD6)
        ),
    };
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const ValueKey('home-active-status'),
            constraints: const BoxConstraints(minHeight: 20),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: background, borderRadius: BorderRadius.circular(999)),
            child: Text(badge,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          Text(
              partnerName ??
                  (request.service == RescueService.tire
                      ? 'Vá / thay lốp'
                      : request.service.label),
              key: const ValueKey('home-active-title'),
              style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  height: 1.15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('${displayCode(request.requestCode)} • ${request.vehicle.label}',
              key: const ValueKey('home-active-request-meta'),
              style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w500)),
        ]);
  }
}

class _StatusMeta extends StatelessWidget {
  const _StatusMeta(
      {super.key, required this.request, this.etaMinutes, this.distanceKm});
  final RescueRequestData request;
  final int? etaMinutes;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (etaMinutes != null)
              Container(
                key: const ValueKey('home-active-eta'),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .9),
                    borderRadius: BorderRadius.circular(999)),
                child: Text('$etaMinutes phút',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: _blue,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            if (distanceKm != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                    '${distanceKm!.toStringAsFixed(distanceKm! % 1 == 0 ? 0 : 1)} km',
                    key: const ValueKey('home-active-distance'),
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: _secondary, fontSize: 10)),
              ),
            if (etaMinutes == null &&
                distanceKm == null &&
                request.hasServerUpdateTime)
              Tooltip(
                message: customerDate(request.updatedAt, includeTime: true),
                child: Text(
                    'Cập nhật: ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(request.updatedAt), alwaysUse24HourFormat: true)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: _secondary, fontSize: 10, height: 1.2)),
              ),
          ]);
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({super.key, required this.stage, required this.onTrack});
  final RequestStage stage;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final progress = switch (stage) {
      RequestStage.searching => 'Hệ thống đang tìm đối tác phù hợp',
      RequestStage.accepted => 'Đối tác đã tiếp nhận yêu cầu',
      RequestStage.arriving => 'Đối tác đang di chuyển',
      RequestStage.inProgress => 'Yêu cầu đang được hỗ trợ',
      RequestStage.completed => 'Yêu cầu đã hoàn tất',
      RequestStage.cancelled => 'Yêu cầu đã hủy',
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(
          builder: (context, constraints) => Row(children: [
                Expanded(
                    child: Text.rich(
                        TextSpan(children: [
                          const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                  padding: EdgeInsets.only(right: 3),
                                  child: Icon(Icons.directions_car_outlined,
                                      size: 18, color: _blue))),
                          TextSpan(text: progress),
                        ]),
                        key: const ValueKey('home-active-progress'),
                        semanticsLabel: progress,
                        style: const TextStyle(
                            color: _secondary, fontSize: 11, height: 1))),
                const SizedBox(width: 6),
                ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: constraints.maxWidth / 2),
                    child: FilledButton(
                        onPressed: onTrack,
                        style: FilledButton.styleFrom(
                            backgroundColor: _blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            textStyle: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 12,
                                height: 1.1,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w700),
                            shape: const StadiumBorder()),
                        child: const Text('Theo dõi →'))),
              ])),
    );
  }
}
