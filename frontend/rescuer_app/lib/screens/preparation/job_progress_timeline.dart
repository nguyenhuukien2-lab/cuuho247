import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/mobile_ui.dart';
import '../../models/backend_models.dart';

/// Status and times are exclusively server milestones. Pending steps have no time.
class JobProgressTimeline extends StatelessWidget {
  const JobProgressTimeline({super.key, required this.assignment});
  final JobAssignment assignment;
  @override
  Widget build(BuildContext context) {
    final steps = [
      ('accepted', 'Đã nhận đơn', assignment.acceptedAt),
      ('en_route', 'Đang đến điểm cứu hộ', assignment.enRouteAt),
      ('arrived', 'Đã đến nơi', assignment.arrivedAt),
      ('in_progress', 'Đang hỗ trợ khách', assignment.inProgressAt),
      ('completed', 'Hoàn tất chuyến', assignment.completedAt),
      if (assignment.state == 'cancelled' || assignment.cancelledAt != null)
        ('cancelled', 'Đã hủy', assignment.cancelledAt),
    ];
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Builder(
            builder: (context) {
              final (state, label, time) = steps[i];
              final current = state == assignment.state;
              final done = time != null && !current;
              final color = current
                  ? AppColors.orange
                  : done
                  ? AppColors.success
                  : AppColors.muted;
              return Semantics(
                key: ValueKey('job-step-$state'),
                label:
                    '$label: ${current
                        ? 'Hiện tại'
                        : done
                        ? 'Đã ghi nhận'
                        : 'Chưa ghi nhận'}',
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 32,
                        child: Column(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: current || done
                                    ? color
                                    : RescueColors.container,
                              ),
                              child: Icon(
                                current
                                    ? Icons.radio_button_checked
                                    : done
                                    ? Icons.check
                                    : Icons.circle_outlined,
                                size: 18,
                                color: current || done
                                    ? Colors.white
                                    : AppColors.muted,
                              ),
                            ),
                            if (i < steps.length - 1)
                              Expanded(
                                child: Center(
                                  child: Container(
                                    width: 2,
                                    color: done
                                        ? AppColors.success
                                        : RescueColors.containerHigh,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: current
                                  ? AppColors.orangeSoft
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: AppType.body.copyWith(
                                    fontWeight: current
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: current
                                        ? RescueColors.accentPressed
                                        : done
                                        ? AppColors.ink
                                        : AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  current
                                      ? 'Hiện tại'
                                      : done
                                      ? 'Đã ghi nhận'
                                      : 'Chờ thực hiện',
                                  style: AppType.caption,
                                ),
                                if (time != null)
                                  Text(_time(time), style: AppType.caption),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  static String _time(DateTime value) {
    final t = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)} · ${two(t.day)}/${two(t.month)}/${t.year}';
  }
}
