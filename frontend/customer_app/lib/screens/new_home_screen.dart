import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/app_theme.dart';
import '../app/user_session.dart';
import '../widgets/rescue_widgets.dart';
import '../widgets/customer_ui.dart';

class NewHomeScreen extends StatelessWidget {
  const NewHomeScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final name = displayCustomerName(UserSession.fullName);
    final active = controller.activeRequest;
    return ListView(
        key: const PageStorageKey('home-scroll'),
        padding: AppSpacing.page,
        children: [
          Row(children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.health_and_safety_rounded,
                    color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Cứu Hộ 24/7',
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(name.isEmpty ? 'Chào bạn!' : 'Chào $name!',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted)),
                ])),
          ]),
          const SizedBox(height: 24),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Text('Bạn cần cứu hộ?',
                                  style: TextStyle(
                                      fontSize: 26,
                                      height: 1.2,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white))),
                          SizedBox(width: 12),
                          Icon(Icons.car_repair_rounded,
                              size: 32, color: Colors.white),
                        ]),
                    const SizedBox(height: 8),
                    const Text('Gửi vị trí và tình trạng xe để yêu cầu hỗ trợ.',
                        style: TextStyle(color: Color(0xFFE6EFF8))),
                    const SizedBox(height: 24),
                    PrimaryButton(
                        label: 'Gọi cứu hộ ngay',
                        icon: Icons.sos_rounded,
                        onPressed: controller.startRequest),
                  ])),
          if (controller.loadingRequests) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator()
          ],
          if (controller.loadError != null) ...[
            const SizedBox(height: 16),
            InlineNotice(controller.loadError!,
                onRetry: controller.loadingRequests
                    ? null
                    : controller.refreshRequests)
          ],
          if (active != null) ...[
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
                duration: customerMotion(context),
                tween: Tween(begin: 0, end: 1),
                builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                        offset: Offset(0, 6 * (1 - value)), child: child)),
                child: Card(
                    child: InkWell(
                        onTap: () => controller.selectTab(2),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(children: [
                                    Icon(Icons.route_rounded,
                                        color: AppColors.navy),
                                    SizedBox(width: 8),
                                    Expanded(
                                        child: Text('Yêu cầu đang xử lý',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700))),
                                    Icon(Icons.chevron_right_rounded),
                                  ]),
                                  const SizedBox(height: 8),
                                  Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(active.service.label),
                                        StatusPill(stage: active.stage)
                                      ]),
                                  const SizedBox(height: 8),
                                  Text(active.address,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AppColors.muted)),
                                ]))))),
          ],
          const SizedBox(height: 24),
          const SectionTitle('Dịch vụ cứu hộ',
              subtitle: 'Chọn sự cố bạn đang gặp'),
          const SizedBox(height: 12),
          ServiceGrid(
              onSelected: (service) =>
                  controller.startRequest(service: service)),
          const SizedBox(height: 24),
          const SectionTitle('Phương tiện',
              subtitle: 'Chọn loại xe cần hỗ trợ'),
          const SizedBox(height: 12),
          DropdownButtonFormField<VehicleKind>(
              initialValue: controller.vehicle,
              isExpanded: true,
              decoration: InputDecoration(
                  labelText: 'Loại phương tiện',
                  prefixIcon: Icon(vehicleIcon(controller.vehicle))),
              items: VehicleKind.values
                  .map((kind) =>
                      DropdownMenuItem(value: kind, child: Text(kind.label)))
                  .toList(),
              onChanged: (kind) {
                if (kind != null) controller.selectVehicle(kind);
              }),
          const SizedBox(height: 24),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.verified_user_outlined, size: 22, color: AppColors.navy),
            SizedBox(width: 8),
            Expanded(
                child: Text(
                    'Kiểm tra địa chỉ và số liên hệ trước khi gửi. Chi phí được xác nhận trước khi sửa chữa.',
                    style: TextStyle(color: AppColors.muted))),
          ]),
        ]);
  }
}
