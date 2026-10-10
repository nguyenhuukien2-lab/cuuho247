import 'stitch_customer_header.dart';
import '../app/mobile_ui.dart';
import '../app/app_controller.dart';
import 'package:flutter/material.dart';
import '../services/customer_vehicle_service.dart';
import '../services/customer_saved_address_service.dart';

const accountTitle = TextStyle(
    color: Color(0xFF0B1C30), fontSize: 16, fontWeight: FontWeight.w700);
const accountCaption =
    TextStyle(color: Color(0xFF434655), fontSize: 12, height: 1.4);

abstract final class AccountVisual {
  static const navy = Color(0xFF0037B0), blue = Color(0xFF1D4ED8);
  static const background = Color(0xFFF8F9FF), border = Color(0xFFE5E7EB);
  static const danger = Color(0xFFBA1A1A), orange = Color(0xFFF97316);
}

class AccountSectionTitle extends StatelessWidget {
  const AccountSectionTitle(this.title,
      {super.key, this.color = AccountVisual.blue, this.trailing});
  final String title;
  final Color color;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Row(children: [
          Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(999))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: AccountVisual.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ]),
      );
}

class CustomerAccountHeader extends StatelessWidget {
  const CustomerAccountHeader({super.key});
  @override
  Widget build(BuildContext context) => const StitchCustomerHeader();
}

class CustomerAccountHeaderCard extends StatelessWidget {
  const CustomerAccountHeaderCard(
      {super.key,
      required this.name,
      this.phone,
      this.customerCode,
      this.email,
      this.onEdit,
      this.onReload,
      this.vehicleCount,
      this.completedCount});
  final String name;
  final String? phone, email, customerCode;
  final VoidCallback? onEdit, onReload;
  final int? vehicleCount, completedCount;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2151DA), Color(0xFF0037B0)])),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0x33FFFFFF),
              child: Icon(Icons.person_outline_rounded,
                  color: Colors.white, size: 32)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name.isEmpty ? 'Thông tin cá nhân' : name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 24 / 18,
                        fontWeight: FontWeight.w800)),
                if (customerCode != null) ...[
                  const SizedBox(height: 6),
                  Container(
                      key: const ValueKey('account-customer-code-chip'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(999)),
                      child: Text('Mã KH: $customerCode',
                          semanticsLabel: 'Mã khách hàng: $customerCode',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              height: 14 / 11))),
                ],
                for (final contact in [
                  if (phone?.trim().isNotEmpty == true)
                    (Icons.phone_outlined, phone!),
                  if (email?.trim().isNotEmpty == true)
                    (Icons.mail_outline, email!),
                ])
                  Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(contact.$1, color: Colors.white70, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(contact.$2,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        height: 16 / 12))),
                          ])),
              ])),
          if (onEdit != null || onReload != null)
            Column(children: [
              if (onEdit != null)
                IconButton.filled(
                    tooltip: 'Chỉnh sửa thông tin',
                    onPressed: onEdit,
                    style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .15)),
                    icon: const Icon(Icons.edit_outlined,
                        color: Colors.white, size: 20)),
              if (onReload != null)
                IconButton(
                    tooltip: 'Tải lại hồ sơ',
                    onPressed: onReload,
                    icon: const Icon(Icons.sync_rounded,
                        color: Colors.white70, size: 20)),
            ]),
        ]),
        if (vehicleCount != null || completedCount != null) ...[
          const SizedBox(height: 16),
          IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                if (vehicleCount != null)
                  Expanded(
                      child: AccountMetricTile(
                          value: vehicleCount!, label: 'Xe đã lưu')),
                if (vehicleCount != null && completedCount != null)
                  const SizedBox(width: 8),
                if (completedCount != null)
                  Expanded(
                      child: AccountMetricTile(
                          value: completedCount!,
                          label: 'Đơn hoàn tất\nđã tải')),
              ])),
        ],
      ]));
}

class AccountMetricTile extends StatelessWidget {
  const AccountMetricTile(
      {super.key, required this.value, required this.label});
  final int value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Text('$value',
            style: const TextStyle(
                color: Color(0xFF6CF8BB),
                fontSize: 24,
                height: 32 / 24,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label,
            style: accountCaption.copyWith(color: Colors.white70),
            textAlign: TextAlign.center),
      ]));
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
          borderRadius: BorderRadius.circular(RescueRadius.card),
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
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(16)),
                          child: Icon(
                              switch (vehicle.kind) {
                                VehicleKind.motorbike =>
                                  Icons.two_wheeler_outlined,
                                VehicleKind.truck =>
                                  Icons.local_shipping_outlined,
                                VehicleKind.car =>
                                  Icons.directions_car_outlined,
                                VehicleKind.other => Icons.commute_outlined,
                              },
                              color: AccountVisual.blue,
                              size: 28)),
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
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(999)),
                          child: Text(vehicle.licensePlate,
                              style: const TextStyle(
                                  color: AccountVisual.navy,
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
      radius: 22,
      child: Column(children: [
        if (addresses.isEmpty)
          const AccountEmptyContent(
              title: 'Chưa có địa chỉ đã lưu',
              message: 'Lưu địa chỉ thường dùng để đặt cứu hộ nhanh hơn',
              icon: Icons.add_home_outlined,
              color: Color(0xFF006C49),
              background: Color(0xFFDCFCE7)),
        for (final address in addresses)
          ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              onTap: onManage,
              leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(
                      address.label.toLowerCase().contains('nhà')
                          ? Icons.home_outlined
                          : address.label.toLowerCase().contains('cơ quan')
                              ? Icons.business_outlined
                              : Icons.location_on_outlined,
                      color: const Color(0xFF006C49))),
              title: Wrap(spacing: 8, runSpacing: 4, children: [
                Text(address.label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (address.isDefault)
                  const Text('Mặc định',
                      style: TextStyle(color: Color(0xFF00714D), fontSize: 12)),
              ]),
              subtitle: Text(address.address, style: accountCaption),
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
  @override
  Widget build(BuildContext context) => const AccountSettingsItem(
      title: 'Hỗ trợ',
      subtitle: 'Chưa có thông tin liên hệ hỗ trợ.',
      icon: Icons.support_agent_outlined);
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
              backgroundColor: const Color(0xFFFFDAD6),
              foregroundColor: AccountVisual.danger,
              minimumSize: const Size(48, 56),
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
  const AccountSurface({super.key, required this.child, this.radius = 20});
  final Widget child;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AccountVisual.border)),
      child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: child));
}

class AccountEmptyContent extends StatelessWidget {
  const AccountEmptyContent(
      {super.key,
      required this.title,
      required this.message,
      required this.icon,
      this.color = AccountVisual.blue,
      this.background = const Color(0xFFDBEAFE)});
  final String title, message;
  final IconData icon;
  final Color color, background;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: background, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 28)),
          const SizedBox(height: 12),
          Text(title, style: accountTitle),
          const SizedBox(height: 6),
          Text(message, style: accountCaption),
        ]),
      );
}

class AccountSettingsItem extends StatelessWidget {
  const AccountSettingsItem(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      this.onTap,
      this.color = AccountVisual.blue,
      this.background = const Color(0xFFDBEAFE)});
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Color color, background;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: background, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 22)),
        title: Text(title, style: accountTitle),
        subtitle: Text(subtitle, style: accountCaption),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right_rounded,
                color: AccountVisual.navy),
        onTap: onTap,
      );
}
