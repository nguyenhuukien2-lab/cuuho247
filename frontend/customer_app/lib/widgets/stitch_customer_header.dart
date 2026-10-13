import 'package:flutter/material.dart';
import '../app/mobile_ui.dart';

/// Shared 64 px header; grows only when accessibility text needs more room.
class StitchCustomerHeader extends StatelessWidget {
  const StitchCustomerHeader(
      {super.key,
      this.onAccount,
      this.onRefresh,
      this.subtitle = 'Khách Hàng'});
  final VoidCallback? onAccount, onRefresh;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        color: Colors.white,
        child: Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: const Color(0xFFE9EFFF),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.verified_user_outlined,
                  color: RescueColors.navy, size: 24)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Cứu Hộ 24/7',
                    style: TextStyle(
                        fontSize: 18,
                        height: 24 / 18,
                        fontWeight: FontWeight.w800,
                        color: RescueColors.navy)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11,
                        height: 14 / 11,
                        color: RescueColors.muted)),
              ])),
          if (onRefresh != null)
            IconButton(
                tooltip: 'Tải lại yêu cầu',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 20)),
          if (onAccount != null)
            IconButton(
                tooltip: 'Mở tài khoản',
                onPressed: onAccount,
                icon: const CircleAvatar(
                    radius: 16,
                    backgroundColor: RescueColors.accent,
                    child: Icon(Icons.person_outline_rounded,
                        color: Colors.white, size: 20))),
        ]),
      );
}
