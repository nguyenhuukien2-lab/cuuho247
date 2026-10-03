import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/backend_models.dart';

class JobProgressTimeline extends StatelessWidget {
  const JobProgressTimeline({super.key, required this.assignment});
  final JobAssignment assignment;
  @override
  Widget build(BuildContext context) {
    const labels = ['Đã nhận', 'Đang đến', 'Đã đến', 'Báo giá', 'Hoàn tất'];
    const steps = ['accepted', 'en_route', 'arrived', 'quote', 'completed'];
    const icons = [
      Icons.check_rounded,
      Icons.navigation_outlined,
      Icons.place_outlined,
      Icons.receipt_long_outlined,
      Icons.verified_outlined,
    ];
    final current = assignment.state == 'completed'
        ? 4
        : assignment.hasQuote
        ? 3
        : switch (assignment.state) {
            'accepted' => 0,
            'en_route' => 1,
            'arrived' => 2,
            'in_progress' => 3,
            _ => -1,
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.route_rounded, color: AppColors.orange),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Tiến độ ca cứu hộ', style: AppType.section),
            ),
            Text(
              current < 0 ? 'Đã kết thúc' : 'Bước ${current + 1}/5',
              style: AppType.caption,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: TimelineStep(
                  key: ValueKey('job-step-${steps[i]}'),
                  label: labels[i],
                  icon: icons[i],
                  done:
                      i < current ||
                      (i == 3 && assignment.hasQuote) ||
                      (i == 4 && assignment.state == 'completed'),
                  active: i == current,
                  last: i == labels.length - 1,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (assignment.state == 'in_progress')
          Container(
            key: const ValueKey('job-step-in_progress'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.orangeSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              assignment.hasQuote
                  ? 'Đang hỗ trợ · Đã gửi báo giá. Hoàn tất sau khi xử lý xong.'
                  : 'Đang hỗ trợ · Tạo báo giá trước khi hoàn tất.',
              style: AppType.caption.copyWith(color: AppColors.navy),
            ),
          ),
      ],
    );
  }
}

class TimelineStep extends StatelessWidget {
  const TimelineStep({
    super.key,
    required this.label,
    required this.icon,
    required this.done,
    required this.active,
    required this.last,
  });
  final String label;
  final IconData icon;
  final bool done, active, last;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '$label: ${done
            ? 'Đã hoàn thành'
            : active
            ? 'Hiện tại'
            : 'Chưa đến bước này'}',
    child: Column(
      children: [
        SizedBox(
          height: 38,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (!last)
                Positioned(
                  left: 30,
                  right: -30,
                  top: 18,
                  child: Container(
                    height: 2,
                    color: done ? AppColors.success : AppColors.line,
                  ),
                ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? AppColors.success
                      : active
                      ? AppColors.orange
                      : AppColors.background,
                  border: Border.all(
                    color: active
                        ? AppColors.orange
                        : done
                        ? AppColors.success
                        : AppColors.line,
                    width: 2,
                  ),
                ),
                child: Icon(
                  done ? Icons.check_rounded : icon,
                  size: 18,
                  color: done || active ? Colors.white : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active
                ? AppColors.orange
                : done
                ? AppColors.navy
                : AppColors.muted,
          ),
        ),
      ],
    ),
  );
}
