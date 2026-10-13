import 'stitch_customer_header.dart';
export 'home_active_request_card.dart' show ActiveOrderBanner;
import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../services/location_service.dart';

const _title =
    TextStyle(color: HomeVisual.ink, fontSize: 18, fontWeight: FontWeight.w700);
const _caption = TextStyle(color: HomeVisual.muted, fontSize: 12, height: 1.4);

abstract final class HomeVisual {
  static const navy = Color(0xFF0037B0), blue = Color(0xFF1D4ED8);
  static const orange = Color(0xFFF97316), green = Color(0xFF006C49);
  static const background = Color(0xFFF8F9FF), border = Color(0xFFE5E7EB);
  static const ink = Color(0xFF0B1C30), muted = Color(0xFF434655);
}

class HomeAppHeader extends StatelessWidget {
  const HomeAppHeader({super.key, required this.onAccount, this.onRefresh});
  final VoidCallback onAccount;
  final VoidCallback? onRefresh;
  @override
  Widget build(BuildContext context) =>
      StitchCustomerHeader(onAccount: onAccount, onRefresh: onRefresh);
}

class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle(this.title,
      {super.key, this.color = HomeVisual.blue, this.trailing});
  final String title;
  final Color color;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(999))),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: _title)),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ]);
}

class HomeGreetingLocation extends StatelessWidget {
  const HomeGreetingLocation(
      {super.key,
      required this.name,
      required this.location,
      required this.loading,
      required this.onRefresh,
      this.selectedAddress,
      this.selectedCoordinates});
  final String name;
  final LocationResult? location;
  final bool loading;
  final VoidCallback onRefresh;
  final String? selectedAddress;
  final RescueCoordinates? selectedCoordinates;
  @override
  Widget build(BuildContext context) {
    final currentCoordinates = location?.status == LocationStatus.acquired
        ? location?.coordinates
        : null;
    final coordinates = currentCoordinates?.isValid == true
        ? currentCoordinates
        : selectedCoordinates?.isValid == true
            ? selectedCoordinates
            : null;
    final hasAddress = selectedAddress?.trim().isNotEmpty == true;
    final address = hasAddress
        ? selectedAddress!.trim()
        : coordinates?.label ?? 'Chưa chọn vị trí';
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _HomeGreetingTitle(name: name),
            const SizedBox(height: 4),
            _HomeAddressRow(
                address: address,
                selected: hasAddress,
                hasLocation: coordinates != null || hasAddress),
            const SizedBox(height: 5),
            _HomeLocationStatusRow(
                hasGps: currentCoordinates?.isValid == true,
                hasAddress: hasAddress,
                location: location,
                loading: loading),
            if (hasAddress &&
                location?.capturedAt != null &&
                currentCoordinates != null)
              Text('GPS thiết bị: ${currentCoordinates.label}',
                  style: _caption),
            if (location?.capturedAt case final capturedAt?)
              Text(
                  'Cập nhật gần nhất: ${capturedAt.toLocal().toString().split('.').first}',
                  style: _caption),
            if (location?.accuracy case final accuracy?)
              Text('Độ chính xác GPS: ${accuracy.toStringAsFixed(0)} m',
                  style: _caption),
          ])),
      const SizedBox(width: 8),
      _HomeRefreshCircleButton(loading: loading, onRefresh: onRefresh),
    ]);
  }
}

class _HomeGreetingTitle extends StatelessWidget {
  const _HomeGreetingTitle({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) =>
      Row(key: const ValueKey('home-greeting-title-row'), children: [
        Flexible(
            child: Text(name.isEmpty ? 'Xin chào, bạn' : 'Xin chào, $name',
                key: const ValueKey('home-greeting-title'),
                style: const TextStyle(
                    color: HomeVisual.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 24 / 18))),
        const SizedBox(width: 4),
        const ExcludeSemantics(
            child: Text('👋',
                key: ValueKey('home-greeting-wave'),
                style: TextStyle(fontSize: 17, height: 1.2))),
      ]);
}

class _HomeAddressRow extends StatelessWidget {
  const _HomeAddressRow(
      {required this.address,
      required this.hasLocation,
      this.selected = false});
  final String address;
  final bool hasLocation;
  final bool selected;

  @override
  Widget build(BuildContext context) => Tooltip(
      message: selected ? 'Vị trí cứu hộ đã chọn' : 'Vị trí GPS thiết bị',
      child: Row(key: const ValueKey('home-greeting-address-row'), children: [
        const Icon(Icons.near_me_rounded, size: 16, color: HomeVisual.green),
        const SizedBox(width: 6),
        Expanded(
            child: Text(address,
                key: const ValueKey('home-greeting-address'),
                style: TextStyle(
                    color: hasLocation
                        ? const Color(0xFF1F2937)
                        : HomeVisual.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.2))),
      ]));
}

class _HomeLocationStatusRow extends StatelessWidget {
  const _HomeLocationStatusRow(
      {required this.hasGps,
      required this.hasAddress,
      this.location,
      this.loading = false});
  final bool hasGps;
  final bool hasAddress;
  final LocationResult? location;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final label = loading
        ? 'Đang cập nhật vị trí'
        : hasGps
            ? 'GPS sẵn sàng'
            : location?.status == LocationStatus.acquired
                ? 'Không thể lấy vị trí'
                : location != null && location!.status != LocationStatus.idle
                    ? location!.statusLabel
                    : hasAddress
                        ? 'Vị trí đã chọn'
                        : location?.statusLabel ?? 'Chưa chọn vị trí';
    final foreground = hasGps
        ? const Color(0xFF15803D)
        : hasAddress
            ? const Color(0xFF1D4ED8)
            : const Color(0xFFB45309);
    final background = hasGps
        ? const Color(0xFFDCFCE7)
        : hasAddress
            ? const Color(0xFFDBEAFE)
            : const Color(0xFFFEF3C7);
    return Row(key: const ValueKey('home-greeting-status-row'), children: [
      Flexible(
          child: Container(
              key: const ValueKey('home-greeting-location-badge'),
              constraints: const BoxConstraints(minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: background, borderRadius: BorderRadius.circular(999)),
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: foreground,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1)))),
    ]);
  }
}

class _HomeRefreshCircleButton extends StatelessWidget {
  const _HomeRefreshCircleButton(
      {required this.loading, required this.onRefresh});
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => IconButton.filled(
      key: const ValueKey('home-greeting-refresh'),
      tooltip: 'Làm mới vị trí',
      onPressed: loading ? null : onRefresh,
      style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFEAF2FF),
          disabledBackgroundColor: const Color(0xFFEAF2FF),
          foregroundColor: HomeVisual.blue,
          minimumSize: const Size(40, 40),
          fixedSize: const Size(40, 40),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: const CircleBorder()),
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: HomeVisual.blue))
          : const Icon(Icons.sync_rounded, size: 20));
}

class EmergencyHeroCard extends StatelessWidget {
  const EmergencyHeroCard(
      {super.key, required this.onRequest, this.hasActiveRequest = false});
  final VoidCallback onRequest;
  final bool hasActiveRequest;
  @override
  Widget build(BuildContext context) => Container(
      key: const ValueKey('sos-hero-surface'),
      constraints: const BoxConstraints(minHeight: 180),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
              colors: [Color(0xFF0037B0), Color(0xFF1D4ED8), Color(0xFF2151DA)],
              stops: [0, .65, 1],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          boxShadow: [
            BoxShadow(
                color: HomeVisual.navy.withValues(alpha: .12),
                blurRadius: 14,
                offset: const Offset(0, 6))
          ]),
      child: Stack(children: [
        Positioned(
            right: 0,
            top: 0,
            child: IgnorePointer(
                child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .08))))),
        Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                key: const ValueKey('sos-hero-content'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(key: const ValueKey('sos-hero-header'), children: [
                    Expanded(
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                                key: const ValueKey('sos-hero-badge'),
                                constraints:
                                    const BoxConstraints(minHeight: 22),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .14),
                                    borderRadius: BorderRadius.circular(999)),
                                child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.health_and_safety_outlined,
                                          size: 14, color: Colors.white),
                                      SizedBox(width: 4),
                                      Flexible(
                                          child: Text(
                                              'Yêu cầu cứu hộ trực tuyến',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  height: 1,
                                                  fontWeight:
                                                      FontWeight.w600))),
                                    ])))),
                    const SizedBox(width: 8),
                    Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .15)),
                        child: const Icon(Icons.bolt_rounded,
                            size: 18, color: Colors.white)),
                  ]),
                  const SizedBox(height: 16),
                  const Text('Bạn cần cứu hộ khẩn cấp?',
                      style: TextStyle(
                          fontSize: 24,
                          height: 32 / 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Gửi yêu cầu, hệ thống sẽ tìm đối tác phù hợp.',
                      key: const ValueKey('sos-hero-subtitle'),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: .85),
                          fontSize: 14,
                          height: 20 / 14)),
                  const SizedBox(height: 20),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: hasActiveRequest ? null : onRequest,
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1D4ED8),
                              disabledBackgroundColor: Colors.white,
                              disabledForegroundColor: const Color(0xFF1D4ED8),
                              minimumSize: const Size(48, 56),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999))),
                          child: Row(children: [
                            Container(
                                key: const ValueKey('hero-sos-dot'),
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                    color: Color(0xFFBA1A1A),
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    hasActiveRequest
                                        ? 'YÊU CẦU ĐANG XỬ LÝ'
                                        : 'YÊU CẦU CỨU HỘ NGAY',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700))),
                            const SizedBox(width: 6),
                            const Text('SOS',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700)),
                          ]))),
                  const SizedBox(height: 16),
                  IntrinsicHeight(
                      child: Row(
                          key: const ValueKey('sos-hero-trust-row'),
                          spacing: 4,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        for (final item in const [
                          ('Gửi yêu cầu', Icons.sos_rounded),
                          ('Xem báo giá', Icons.receipt_long_outlined),
                          ('Theo dõi trạng thái', Icons.route_outlined)
                        ])
                          Expanded(
                              child: Container(
                                  key: ValueKey('hero-trust-${item.$1}'),
                                  constraints:
                                      const BoxConstraints(minHeight: 44),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(8)),
                                  alignment: Alignment.center,
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(item.$2,
                                            size: 12, color: Colors.white),
                                        const SizedBox(height: 2),
                                        Text(item.$1,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                height: 14 / 11,
                                                fontWeight: FontWeight.w700)),
                                      ]))),
                      ])),
                ])),
      ]));
}

class HomeServiceGrid extends StatelessWidget {
  const HomeServiceGrid({super.key, required this.onSelected});
  final ValueChanged<RescueService?> onSelected;
  static const services = [
    (
      'Cẩu & Kéo xe',
      'Xe không thể di chuyển',
      Icons.rv_hookup,
      HomeVisual.blue,
      RescueService.towing
    ),
    (
      'Kích bình ắc quy',
      'Bình yếu hoặc hết điện',
      Icons.battery_charging_full,
      HomeVisual.green,
      RescueService.battery
    ),
    (
      'Vá vỏ & Thay lốp',
      'Lốp xẹp, thủng',
      Icons.tire_repair,
      Color(0xFF4F46E5),
      RescueService.tire
    ),
    (
      'Tiếp nhiên liệu',
      'Xe hết nhiên liệu',
      Icons.local_gas_station,
      Color(0xFF0D9488),
      RescueService.fuel
    ),
    (
      'Sửa tại chỗ',
      'Hỗ trợ sự cố khác',
      Icons.build_outlined,
      HomeVisual.orange,
      RescueService.other
    ),
    (
      'Khác',
      'Sự cố cần hỗ trợ',
      Icons.home_repair_service,
      Color(0xFF15803D),
      null
    ),
  ];
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionTitle('Dịch vụ tại chỗ',
              trailing:
                  _Badge('${services.length} gói', color: HomeVisual.blue)),
          const SizedBox(height: 6),
          const Text('Chọn dịch vụ phù hợp với tình huống của bạn',
              style: _caption),
          const SizedBox(height: 12),
          LayoutBuilder(
              builder: (context, constraints) => Column(children: [
                    for (var row = 0; row < services.length; row += 2) ...[
                      if (row > 0) const SizedBox(height: 10),
                      IntrinsicHeight(
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            for (var column = row;
                                column < row + 2 && column < services.length;
                                column++) ...[
                              if (column > row) const SizedBox(width: 10),
                              Expanded(
                                  child: ServiceCard(
                                      title: services[column].$1,
                                      subtitle: services[column].$2,
                                      icon: services[column].$3,
                                      color: services[column].$4,
                                      tag: const [
                                        'Theo yêu cầu',
                                        'Xem chi tiết',
                                        'Xem chi tiết',
                                        'Theo yêu cầu',
                                        'Tùy tình huống',
                                        'Tùy tình huống'
                                      ][column],
                                      onTap: () =>
                                          onSelected(services[column].$5))),
                            ],
                          ])),
                    ],
                  ])),
        ],
      );
}

class ServiceCard extends StatelessWidget {
  const ServiceCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.onTap,
      this.tag = 'Theo yêu cầu'});
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tag;
  @override
  Widget build(BuildContext context) => _Surface(
        radius: 12,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, size: 30, color: color)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: HomeVisual.ink,
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 3),
              Tooltip(
                  message: subtitle,
                  child: Text(subtitle,
                      style: _caption.copyWith(fontSize: 12, height: 16 / 12))),
              const SizedBox(height: 3),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF0F3FF),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(tag,
                      style: TextStyle(
                          fontSize: 11,
                          height: 14 / 11,
                          color: color,
                          fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
      );
}

class TrustCommitmentCard extends StatelessWidget {
  const TrustCommitmentCard({super.key});
  @override
  Widget build(BuildContext context) => _Surface(
      key: const ValueKey('home-trust-panel'),
      background: const Color(0xFFEEF6FF),
      radius: 20,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.verified_outlined, color: HomeVisual.green, size: 22),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Cam kết vàng từ Cứu Hộ 24/7', style: _title)),
            ]),
            const SizedBox(height: 12),
            for (final item in const [
              (
                Icons.fact_check_outlined,
                'Minh bạch thông tin',
                'Xem yêu cầu và báo giá trong ứng dụng'
              ),
              (
                Icons.verified_user_outlined,
                'Thông tin yêu cầu rõ ràng',
                'Dịch vụ, vị trí và phương tiện đã chọn'
              ),
              (
                Icons.route_outlined,
                'Theo dõi trạng thái đơn',
                'Kiểm tra tiến trình ngay trong ứng dụng'
              ),
            ])
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _Surface(
                      radius: 16,
                      subtle: true,
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFD5F9EC),
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    child: Icon(item.$1,
                                        color: HomeVisual.green, size: 22)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(item.$2,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              height: 20 / 14,
                                              color: HomeVisual.ink,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(item.$3, style: _caption),
                                    ])),
                              ])))),
          ])));
}

class SafetyTipsCarousel extends StatelessWidget {
  const SafetyTipsCarousel({super.key});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const HomeSectionTitle('Cẩm nang an toàn khẩn cấp',
            color: HomeVisual.orange,
            trailing: Text('Xem tất cả',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))),
        const SizedBox(height: 12),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  for (final tip in const [
                    (
                      'Quan trọng',
                      'Bật đèn cảnh báo',
                      'Báo hiệu cho phương tiện phía sau.',
                      Icons.warning_amber_rounded,
                      Color(0xFFBA1A1A)
                    ),
                    (
                      'Quy chuẩn',
                      'Đặt cảnh báo phía sau xe',
                      'Chỉ đặt khi có thể tiếp cận an toàn.',
                      Icons.change_history_rounded,
                      HomeVisual.green
                    ),
                    (
                      'Lưu ý',
                      'Giữ khoảng cách an toàn',
                      'Đứng ở vị trí an toàn, tránh luồng xe đang chạy.',
                      Icons.directions_car_outlined,
                      HomeVisual.blue
                    ),
                  ])
                    Padding(
                        padding: const EdgeInsets.only(right: 12, bottom: 6),
                        child: SizedBox(
                            width: 280,
                            child: _Surface(
                                radius: 16,
                                child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Expanded(
                                                child: Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: _Badge(tip.$1,
                                                        color: tip.$5))),
                                            Icon(tip.$4,
                                                color: tip.$5, size: 22)
                                          ]),
                                          const SizedBox(height: 12),
                                          Text(tip.$2,
                                              style: _title.copyWith(
                                                  fontSize: 14)),
                                          const SizedBox(height: 6),
                                          Text(tip.$3, style: _caption),
                                          const SizedBox(height: 10),
                                          _Badge('Ghi nhớ khi gặp sự cố',
                                              color: tip.$5, compact: true),
                                        ]))))),
                ]))),
      ]);
}

class _Surface extends StatelessWidget {
  const _Surface(
      {super.key,
      required this.child,
      this.background = Colors.white,
      this.subtle = false,
      this.radius = 20});
  final Widget child;
  final Color background;
  final bool subtle;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: subtle
              ? const [
                  BoxShadow(
                      color: Color(0x060B3A66),
                      blurRadius: 8,
                      offset: Offset(0, 2))
                ]
              : const [
                  BoxShadow(
                      color: Color(0x0F0B3A66),
                      blurRadius: 14,
                      offset: Offset(0, 6))
                ],
          border: Border.all(color: HomeVisual.border)),
      child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: child));
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {required this.color, this.compact = false});
  final String label;
  final Color color;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
          color: color == const Color(0xFF15803D)
              ? const Color(0xFFDCFCE7)
              : color == const Color(0xFF92400E)
                  ? const Color(0xFFFEF3C7)
                  : color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600)));
}
