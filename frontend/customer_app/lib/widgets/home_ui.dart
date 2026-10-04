import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../services/location_service.dart';
import 'booking_ui.dart';

const _title = TextStyle(
    fontSize: 18,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: BookingStyle.ink);
const _caption =
    TextStyle(fontSize: 12, height: 1.5, color: BookingStyle.muted);

class HomeGreetingLocation extends StatelessWidget {
  const HomeGreetingLocation(
      {super.key,
      required this.name,
      required this.location,
      required this.loading,
      required this.onRefresh});
  final String name;
  final LocationResult? location;
  final bool loading;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) {
    final coordinates = location?.coordinates;
    final acquired = location?.status == LocationStatus.acquired &&
        coordinates != null &&
        coordinates.isValid;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name.isEmpty ? 'Xin chào, bạn' : 'Xin chào, $name', style: _title),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.near_me_rounded,
              size: 18, color: BookingStyle.green),
          const SizedBox(width: 6),
          Expanded(
              child: Text(
                  loading || location == null
                      ? 'Đang xác định vị trí'
                      : acquired
                          ? coordinates.label
                          : location!.message,
                  style: _caption.copyWith(fontSize: 14)))
        ]),
        if (acquired && !loading) ...[
          const SizedBox(height: 6),
          const _Badge('Đã cập nhật GPS', color: Color(0xFF00714D))
        ],
      ])),
      const SizedBox(width: 8),
      IconButton.filledTonal(
          tooltip: 'Làm mới vị trí',
          onPressed: loading ? null : onRefresh,
          style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFDCE9FF),
              foregroundColor: BookingStyle.blue,
              minimumSize: const Size(48, 48)),
          icon: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync_rounded)),
    ]);
  }
}

class ActiveOrderBanner extends StatelessWidget {
  const ActiveOrderBanner(
      {super.key, required this.request, required this.onTrack});
  final RescueRequestData request;
  final VoidCallback onTrack;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
              colors: [Color(0xFFD3E4FE), Color(0xFFE1F7ED)])),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(
              radius: 24,
              backgroundColor: BookingStyle.blue,
              child: Icon(Icons.local_shipping_outlined, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    switch (request.stage) {
                      RequestStage.searching => 'Đang tìm cứu hộ',
                      RequestStage.accepted => 'Đã tiếp nhận',
                      RequestStage.arriving => 'Đang di chuyển đến',
                      RequestStage.inProgress => 'Đang hỗ trợ',
                      RequestStage.completed => 'Hoàn tất',
                      RequestStage.cancelled => 'Đã hủy',
                    },
                    style: const TextStyle(
                        color: Color(0xFF00714D), fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(request.service.label, style: _title),
              ]))
        ]),
        const SizedBox(height: 12),
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .8),
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Expanded(
                  child: Text(
                      request.address.trim().isEmpty
                          ? 'Yêu cầu đang được xử lý'
                          : request.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _caption)),
              const SizedBox(width: 8),
              FilledButton(onPressed: onTrack, child: const Text('Theo dõi')),
            ])),
      ]));
}

class EmergencyHeroCard extends StatelessWidget {
  const EmergencyHeroCard({super.key, required this.onRequest});
  final VoidCallback onRequest;
  @override
  Widget build(BuildContext context) => Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [BookingStyle.blue, Color(0xFF2563EB)]),
          boxShadow: [
            BoxShadow(
                color: BookingStyle.blue.withValues(alpha: .18),
                blurRadius: 20,
                offset: const Offset(0, 6))
          ]),
      child: Stack(children: [
        Positioned(
            right: -36,
            top: -48,
            child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .08)))),
        Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Expanded(
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: _Badge('Tổng đài trực 24/7',
                            color: Colors.white,
                            background: Color(0x26FFFFFF)))),
                Icon(Icons.bolt_rounded, color: Colors.white)
              ]),
              const SizedBox(height: 16),
              const Text('Bạn cần cứu hộ khẩn cấp?',
                  style: TextStyle(
                      fontSize: 26,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Hệ thống tìm đối tác gần bạn trong vài giây.',
                  style: TextStyle(
                      color: Color(0xFFE0E7FF), fontSize: 14, height: 1.5)),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: onRequest,
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: BookingStyle.blue,
                          minimumSize: const Size(0, 56),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          shape: const StadiumBorder()),
                      child: const Row(children: [
                        Icon(Icons.circle, color: Color(0xFFEF4444), size: 10),
                        SizedBox(width: 8),
                        Expanded(
                            child: Text('YÊU CẦU CỨU HỘ NGAY',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800))),
                        SizedBox(width: 8),
                        Icon(Icons.sos_rounded)
                      ]))),
            ])),
      ]));
}

class HomeServiceGrid extends StatelessWidget {
  const HomeServiceGrid({super.key, required this.onSelected});
  final ValueChanged<RescueService?> onSelected;
  static const services = [
    (
      'Cẩu & Kéo xe',
      'Hỗ trợ xe không thể di chuyển',
      Icons.rv_hookup,
      BookingStyle.blue,
      RescueService.towing
    ),
    (
      'Kích bình ắc quy',
      'Hỗ trợ khi bình hết điện',
      Icons.battery_charging_full,
      Color(0xFF00714D),
      RescueService.battery
    ),
    (
      'Vá vỏ & Thay lốp',
      'Hỗ trợ lốp xẹp hoặc hư hỏng',
      Icons.tire_repair,
      BookingStyle.blue,
      RescueService.tire
    ),
    (
      'Tiếp nhiên liệu',
      'Hỗ trợ khi xe hết nhiên liệu',
      Icons.local_gas_station,
      Color(0xFF006577),
      RescueService.fuel
    ),
    (
      'Sửa tại chỗ',
      'Hỗ trợ kiểm tra sự cố xe',
      Icons.home_repair_service,
      Color(0xFF00714D),
      null
    ),
    (
      'Mở khóa ô tô',
      'Hỗ trợ khi gặp sự cố khóa',
      Icons.key,
      BookingStyle.blue,
      null
    ),
  ];
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Expanded(child: Text('Dịch vụ tại chỗ', style: _title)),
          _Badge('6 dịch vụ', color: BookingStyle.blue)
        ]),
        const SizedBox(height: 4),
        const Text('Chọn dịch vụ phù hợp với sự cố của bạn', style: _caption),
        const SizedBox(height: 12),
        for (var row = 0; row < 3; row++) ...[
          if (row > 0) const SizedBox(height: 16),
          IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                for (var col = 0; col < 2; col++) ...[
                  if (col > 0) const SizedBox(width: 16),
                  Expanded(
                      child: ServiceCard(
                          title: services[row * 2 + col].$1,
                          subtitle: services[row * 2 + col].$2,
                          icon: services[row * 2 + col].$3,
                          color: services[row * 2 + col].$4,
                          onTap: () => onSelected(services[row * 2 + col].$5))),
                ],
              ])),
        ],
      ]);
}

class ServiceCard extends StatelessWidget {
  const ServiceCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.onTap});
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _Surface(
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(16)),
                        child: Icon(icon, size: 28, color: color)),
                    const SizedBox(height: 12),
                    Text(title, style: _title.copyWith(fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: _caption),
                  ]))));
}

class TrustCommitmentCard extends StatelessWidget {
  const TrustCommitmentCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: BookingStyle.pale, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.shield_outlined, color: BookingStyle.green),
          SizedBox(width: 8),
          Expanded(child: Text('An tâm cùng Cứu Hộ 24/7', style: _title))
        ]),
        const SizedBox(height: 12),
        for (final item in const [
          (
            Icons.price_check,
            'Minh bạch giá',
            'Xem báo giá từ đối tác trong ứng dụng'
          ),
          (Icons.support_agent, 'Hỗ trợ 24/7', 'Hotline SOS: 1900 6868'),
        ]) ...[
          _Surface(
              child: ListTile(
                  leading: Icon(item.$1, color: BookingStyle.blue),
                  title: Text(item.$2,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(item.$3, style: _caption))),
          const SizedBox(height: 8),
        ],
      ]));
}

class SafetyTipsCarousel extends StatelessWidget {
  const SafetyTipsCarousel({super.key});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.tips_and_updates_outlined, color: BookingStyle.blue),
          SizedBox(width: 8),
          Expanded(child: Text('Cẩm nang an toàn khẩn cấp', style: _title))
        ]),
        const SizedBox(height: 12),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  for (final tip in const [
                    (
                      'Cảnh báo sự cố',
                      'Bật đèn Hazard',
                      'Bật đèn khẩn cấp để cảnh báo phương tiện phía sau.',
                      Icons.warning_amber_rounded,
                      Color(0xFFEF4444)
                    ),
                    (
                      'Dễ nhận biết',
                      'Đặt tam giác phản quang',
                      'Chỉ đặt biển cảnh báo khi có thể tiếp cận vị trí an toàn.',
                      Icons.change_history_rounded,
                      Color(0xFF00714D)
                    ),
                    (
                      'Lưu ý máy xe',
                      'Không mở nắp két nước khi máy nóng',
                      'Chờ máy nguội hoặc kỹ thuật viên hỗ trợ.',
                      Icons.thermostat_rounded,
                      BookingStyle.blue
                    ),
                  ])
                    Padding(
                        padding: const EdgeInsets.only(right: 12, bottom: 6),
                        child: SizedBox(
                            width: 260,
                            child: _Surface(
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
                                                  fontSize: 16)),
                                          const SizedBox(height: 6),
                                          Text(tip.$3, style: _caption),
                                        ]))))),
                ]))),
      ]);
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      decoration:
          BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [
        BoxShadow(
            color: BookingStyle.blue.withValues(alpha: .06),
            blurRadius: 20,
            offset: const Offset(0, 4))
      ]),
      child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: child));
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {required this.color, this.background});
  final String label;
  final Color color;
  final Color? background;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
          color: background ?? color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)));
}
