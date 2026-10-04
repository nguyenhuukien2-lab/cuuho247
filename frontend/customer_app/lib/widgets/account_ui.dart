import '../app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/customer_vehicle_service.dart';
import '../services/customer_saved_address_service.dart';
import 'booking_ui.dart';

const accountTitle = TextStyle(
    fontSize: 18,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: BookingStyle.ink);
const accountCaption =
    TextStyle(fontSize: 12, height: 1.5, color: BookingStyle.muted);

class CustomerAccountHeaderCard extends StatelessWidget {
  const CustomerAccountHeaderCard(
      {super.key,
      required this.name,
      this.phone,
      this.email,
      this.onEdit,
      this.onReload,
      this.vehicleCount,
      this.completedCount});
  final String name;
  final String? phone, email;
  final VoidCallback? onEdit, onReload;
  final int? vehicleCount, completedCount;
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
                color: BookingStyle.blue.withValues(alpha: .15),
                blurRadius: 20,
                offset: const Offset(0, 4))
          ]),
      child: Stack(children: [
        Positioned(
            right: -40,
            bottom: -40,
            child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: BookingStyle.green.withValues(alpha: .15)))),
        Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const CircleAvatar(
                    radius: 32,
                    backgroundColor: Color(0x26FFFFFF),
                    child: Icon(Icons.person_outline_rounded,
                        color: Colors.white, size: 36)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name.isEmpty ? 'Thông tin cá nhân' : name,
                          style: accountTitle.copyWith(color: Colors.white)),
                      if (phone?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text(phone!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14))
                      ],
                      if (email?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(email!,
                            style: const TextStyle(
                                color: Color(0xFFCAD3FF), fontSize: 12))
                      ],
                    ])),
              ]),
              if (onEdit != null) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: onEdit,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0x66FFFFFF)),
                              minimumSize: const Size(0, 48)),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Chỉnh sửa thông tin'))),
                  if (onReload != null)
                    IconButton(
                        tooltip: 'Tải lại hồ sơ',
                        onPressed: onReload,
                        color: Colors.white,
                        icon: const Icon(Icons.refresh_rounded)),
                ])
              ],
              if (vehicleCount != null || completedCount != null) ...[
                const SizedBox(height: 16),
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(16)),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (vehicleCount != null)
                            Expanded(
                                child: AccountMetricTile(
                                    value: vehicleCount!,
                                    label: 'Xe liên kết')),
                          if (completedCount != null)
                            Expanded(
                                child: AccountMetricTile(
                                    value: completedCount!,
                                    label: 'Hoàn tất đã tải')),
                        ])),
              ],
            ])),
      ]));
}

class AccountMetricTile extends StatelessWidget {
  const AccountMetricTile(
      {super.key, required this.value, required this.label});
  final int value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text('$value',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(color: Color(0xFFCAD3FF), fontSize: 11),
            textAlign: TextAlign.center),
      ]);
}

class AccountVehicleCard extends StatelessWidget {
  const AccountVehicleCard(
      {super.key, required this.vehicle, required this.onManage});
  final CustomerVehicle vehicle;
  final VoidCallback onManage;
  @override
  Widget build(BuildContext context) => AccountSurface(
      child: InkWell(
          onTap: onManage,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              color: BookingStyle.pale,
                              borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.directions_car_outlined,
                              color: BookingStyle.blue, size: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                vehicle.brandModel.isEmpty
                                    ? vehicle.kind.label
                                    : vehicle.brandModel,
                                style: accountTitle),
                            const SizedBox(height: 4),
                            Text(
                                [
                                  vehicle.kind.label,
                                  if (vehicle.color.isNotEmpty) vehicle.color
                                ].join(' • '),
                                style: accountCaption),
                          ])),
                      IconButton(
                          tooltip: 'Quản lý xe',
                          onPressed: onManage,
                          icon: const Icon(Icons.more_vert_rounded)),
                    ]),
                    if (vehicle.licensePlate.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: BookingStyle.pale,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(vehicle.licensePlate,
                              style: const TextStyle(
                                  color: BookingStyle.ink,
                                  fontWeight: FontWeight.w700))),
                    ],
                  ]))));
}

class AccountAddressSection extends StatelessWidget {
  const AccountAddressSection(
      {super.key, required this.addresses, required this.onManage});
  final List<CustomerSavedAddress> addresses;
  final VoidCallback onManage;
  @override
  Widget build(BuildContext context) => AccountSurface(
          child: Column(children: [
        if (addresses.isEmpty)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Chưa có địa chỉ đã lưu', style: accountCaption)),
        for (final address in addresses)
          ListTile(
              onTap: onManage,
              leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: BookingStyle.pale,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(
                      address.label.toLowerCase().contains('nhà')
                          ? Icons.home_outlined
                          : Icons.location_on_outlined,
                      color: BookingStyle.blue)),
              title: Wrap(spacing: 8, runSpacing: 4, children: [
                Text(address.label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (address.isDefault)
                  const Text('Mặc định',
                      style: TextStyle(color: Color(0xFF00714D), fontSize: 12)),
              ]),
              subtitle: Text(address.address,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: accountCaption),
              trailing: const Icon(Icons.chevron_right_rounded)),
      ]));
}

class AccountSettingsSection extends StatelessWidget {
  const AccountSettingsSection({super.key});
  @override
  Widget build(BuildContext context) => const AccountSurface(
      child: Padding(padding: EdgeInsets.all(8), child: SupportHotlineTile()));
}

class SupportHotlineTile extends StatelessWidget {
  const SupportHotlineTile({super.key});
  Future<void> _call(BuildContext context) async {
    try {
      if (await launchUrl(Uri(scheme: 'tel', path: '19006868'))) return;
    } catch (_) {}
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Vui lòng gọi 1900 6868 để được hỗ trợ.')));
  }

  @override
  Widget build(BuildContext context) => Material(
      color: const Color(0xFFFFF1F2),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
          onTap: () => _call(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Icon(Icons.sos_rounded,
                    color: Color(0xFFEF4444), size: 30),
                const SizedBox(width: 12),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Hotline SOS 24/7',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('1900 6868',
                          style: TextStyle(
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w700)),
                    ])),
                const Icon(Icons.phone_outlined, color: Color(0xFFEF4444)),
              ]))));
}

class LogoutButton extends StatelessWidget {
  const LogoutButton(
      {super.key, required this.loading, required this.onPressed});
  final bool loading;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFEE2E2),
              foregroundColor: const Color(0xFFB91C1C),
              minimumSize: const Size(0, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
          icon: loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.logout_rounded),
          label: Text(loading ? 'Đang đăng xuất…' : 'Đăng xuất tài khoản')));
}

class AccountSurface extends StatelessWidget {
  const AccountSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      decoration:
          BoxDecoration(borderRadius: BorderRadius.circular(22), boxShadow: [
        BoxShadow(
            color: BookingStyle.blue.withValues(alpha: .06),
            blurRadius: 20,
            offset: const Offset(0, 4))
      ]),
      child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: child));
}
