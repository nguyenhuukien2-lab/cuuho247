import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/app_theme.dart';
import '../../models/rescuer_status.dart';
import '../../widgets/app_components.dart';
import '../onboarding/onboarding_screens.dart';
import '../account/account_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});
  final AppState state;

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final isReady = state.isOnline;
    final canGoOnline =
        state.partnerStatus == PartnerReviewStatus.approved &&
        state.hasLocationPermission &&
        state.isGpsEnabled &&
        state.isNetworkAvailable &&
        state.isBackendAvailable &&
        !state.isBusy;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
              sliver: SliverList.list(
                children: [
                  _HomeTopBar(
                    online: isReady,
                    onAccount: () => state.selectTab(4),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    isReady ? 'Đang trực tuyến' : 'Sẵn sàng hỗ trợ',
                    style: AppType.pageTitle.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isReady
                        ? 'Bạn sẽ nhận đơn phù hợp khi có yêu cầu.'
                        : 'Hoàn tất các điều kiện để bật trạng thái nhận đơn.',
                    style: AppType.body.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 18),
                  _RadarCard(
                    online: isReady,
                    ready: canGoOnline,
                    onToggle: () {
                      if (isReady) {
                        state.setOnline(false);
                      } else if (!state.isBackendAvailable) {
                        _open(
                          context,
                          const DeviceStatusScreen(
                            kind: DeviceStatusKind.connection,
                          ),
                        );
                      } else {
                        state.setOnline(true);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!state.isBackendAvailable)
                    const InfoBanner(
                      title: 'Chưa kết nối dịch vụ',
                      message: 'Trạng thái nhận đơn đang tắt cho đến khi dịch vụ được cấu hình.',
                      icon: Icons.cloud_off_outlined,
                      tone: BadgeTone.orange,
                    )
                  else if (!state.hasLocationPermission || !state.isGpsEnabled)
                    const InfoBanner(
                      title: 'Cần quyền vị trí',
                      message: 'Cho phép vị trí và bật GPS để tìm đơn trong khu vực.',
                      icon: Icons.location_off_outlined,
                      tone: BadgeTone.orange,
                    )
                  else if (state.partnerStatus != PartnerReviewStatus.approved)
                    const InfoBanner(
                      title: 'Hồ sơ đang chờ hoàn tất',
                      message: 'Hoàn thiện hồ sơ đối tác để tiếp tục các bước xác minh.',
                      icon: Icons.fact_check_outlined,
                      tone: BadgeTone.blue,
                    ),
                  const SizedBox(height: 22),
                  const SectionTitle(title: 'Tình trạng kết nối'),
                  const SizedBox(height: 12),
                  _ConnectionCard(
                    icon: Icons.my_location_outlined,
                    title: 'Vị trí thiết bị',
                    subtitle: state.hasLocationPermission && state.isGpsEnabled
                        ? 'Đã bật trên thiết bị'
                        : 'Cần cấp quyền vị trí và bật GPS',
                    tone: state.hasLocationPermission && state.isGpsEnabled
                        ? BadgeTone.green
                        : BadgeTone.orange,
                    onTap: () => _open(
                      context,
                      const DeviceStatusScreen(kind: DeviceStatusKind.location),
                    ),
                  ),
                  const SizedBox(height: 9),
                  _ConnectionCard(
                    icon: Icons.wifi_rounded,
                    title: 'Kết nối dịch vụ',
                    subtitle: state.isBackendAvailable
                        ? 'Đang kết nối'
                        : 'Dịch vụ chưa khả dụng',
                    tone: state.isBackendAvailable
                        ? BadgeTone.green
                        : BadgeTone.neutral,
                    onTap: () => _open(
                      context,
                      const DeviceStatusScreen(
                        kind: DeviceStatusKind.connection,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(child: SectionTitle(title: 'Đơn phù hợp')),
                      TextButton(
                        onPressed: () => state.selectTab(1),
                        child: const Text('Mở danh sách'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (!state.isBackendAvailable)
                    const StatePanel(
                      kind: PanelKind.unavailable,
                      title: 'Chưa thể tải đơn',
                      message: 'Danh sách sẽ hiển thị khi dịch vụ khả dụng.',
                      compact: true,
                    )
                  else if (!isReady)
                    const StatePanel(
                      kind: PanelKind.empty,
                      title: 'Bạn đang offline',
                      message: 'Bật sẵn sàng nhận đơn khi bạn đủ điều kiện.',
                      compact: true,
                    )
                  else
                    const StatePanel(
                      kind: PanelKind.empty,
                      title: 'Đang chờ đơn phù hợp',
                      message: 'Đơn mới sẽ xuất hiện tại đây.',
                      compact: true,
                    ),
                  const SizedBox(height: 22),
                  const SectionTitle(title: 'Hoàn thiện tài khoản'),
                  const SizedBox(height: 12),
                  _SetupProgressCard(
                    currentStep: _registrationStep(state),
                    onTap: () => _open(
                      context,
                      RegistrationProgressScreen(state: state),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickLink(
                          icon: Icons.folder_open_outlined,
                          label: 'Giấy tờ',
                          onTap: () => _open(
                            context,
                            DocumentVerificationScreen(state: state),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickLink(
                          icon: Icons.two_wheeler_outlined,
                          label: 'Phương tiện',
                          onTap: () => _open(
                            context,
                            VehicleRegistrationScreen(state: state),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _registrationStep(AppState value) {
    if (value.partnerStatus == PartnerReviewStatus.submitted) return 4;
    if (value.vehicleStatus == VehicleReviewStatus.submitted) return 3;
    if (value.identityStatus == DocumentReviewStatus.submitted) return 2;
    if (value.isSignedIn) return 1;
    return 0;
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({required this.online, required this.onAccount});
  final bool online;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const BrandMark(size: 44),
      const SizedBox(width: 11),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cứu Hộ 24/7',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            Text('Dành cho đối tác cứu hộ', style: AppType.caption),
          ],
        ),
      ),
      StatusBadge(
        label: online ? 'Đang trực' : 'Offline',
        tone: online ? BadgeTone.green : BadgeTone.neutral,
        icon: online ? Icons.wifi_tethering_rounded : Icons.wifi_off_rounded,
      ),
      const SizedBox(width: 4),
      IconButton(
        tooltip: 'Tài khoản',
        onPressed: onAccount,
        icon: const Icon(Icons.account_circle_outlined),
        color: AppColors.navy,
      ),
    ],
  );
}

class _RadarCard extends StatelessWidget {
  const _RadarCard({
    required this.online,
    required this.ready,
    required this.onToggle,
  });
  final bool online;
  final bool ready;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
    decoration: BoxDecoration(
      color: AppColors.navy,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.navySoft, AppColors.navy],
      ),
    ),
    child: Column(
      children: [
        SizedBox(
          height: 172,
          width: 172,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 3; i >= 0; i--)
                Container(
                  width: 158 - i * 33,
                  height: 158 - i * 33,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (i.isEven ? Colors.white : AppColors.orange)
                        .withValues(alpha: online ? .08 : .045),
                    border: Border.all(
                      color: (online ? AppColors.orange : Colors.white)
                          .withValues(alpha: online ? .42 : .18),
                      width: 1,
                    ),
                  ),
                ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: online ? AppColors.orange : AppColors.navySoft,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .24),
                  ),
                ),
                child: Icon(
                  online ? Icons.radar_rounded : Icons.radar_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              Positioned(
                top: 16,
                right: 29,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: online ? AppColors.orange : Colors.white24,
                    boxShadow: online
                        ? const [
                            BoxShadow(color: Color(0x80ED7A22), blurRadius: 12),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          online ? 'Đang chờ đơn phù hợp' : 'Bạn đang offline',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          online
              ? 'Khu vực hoạt động được xác định từ vị trí thiết bị.'
              : 'Bật trạng thái sẵn sàng khi dịch vụ và vị trí đã khả dụng.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFD0D9E3),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              value: online,
              onChanged: ready || online ? (_) => onToggle() : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              activeThumbColor: AppColors.navy,
              activeTrackColor: AppColors.orange,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFF607184),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              tileColor: Colors.white.withValues(alpha: .08),
              title: const Text(
                'Sẵn sàng nhận đơn',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                ready || online
                    ? 'Bạn có thể tắt trạng thái bất cứ lúc nào.'
                    : 'Chưa khả dụng khi thiếu dịch vụ hoặc quyền vị trí.',
                style: const TextStyle(color: Color(0xFFD0D9E3), fontSize: 11),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final BadgeTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadii.md),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.navy, size: 21),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppType.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}

class _SetupProgressCard extends StatelessWidget {
  const _SetupProgressCard({required this.currentStep, required this.onTap});
  final int currentStep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadii.lg),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Hồ sơ đối tác', style: AppType.section),
                ),
                Text(
                  '$currentStep/5',
                  style: AppType.caption.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: currentStep / 5,
                minHeight: 7,
                backgroundColor: AppColors.background,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(height: 11),
            const Text(
              'Hồ sơ → Giấy tờ → Phương tiện → Dịch vụ → Chờ duyệt',
              style: AppType.caption,
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Text(
                  'Tiếp tục hoàn thiện',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppColors.navy,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 50),
      foregroundColor: AppColors.navy,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}
