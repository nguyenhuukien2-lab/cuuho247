import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/backend_models.dart';

class JobProgressTimeline extends StatelessWidget {
  const JobProgressTimeline({super.key, required this.assignment});
  final JobAssignment assignment;

  @override
  Widget build(BuildContext context) {
    const titles = ['Nhận đơn', 'Đang di chuyển', 'Đã đến nơi', 'Đang hỗ trợ'];
    const icons = [
      Icons.assignment_turned_in_outlined,
      Icons.local_shipping_outlined,
      Icons.place_outlined,
      Icons.handyman_outlined,
    ];
    final times = [
      assignment.acceptedAt,
      assignment.enRouteAt,
      assignment.arrivedAt,
      assignment.inProgressAt,
    ];
    final current = JobAssignment.progressStates.indexOf(assignment.state);
    return Column(
      children: [
        for (var i = 0; i < titles.length; i++)
          Semantics(
            key: ValueKey('job-step-${JobAssignment.progressStates[i]}'),
            label:
                '${titles[i]}: ${i < current
                    ? 'Đã qua bước này'
                    : i == current
                    ? 'Hiện tại'
                    : 'Chưa đến bước này'}',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 38,
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < current
                              ? AppColors.successSoft
                              : i == current
                              ? AppColors.orangeSoft
                              : AppColors.background,
                          border: Border.all(
                            color: i < current
                                ? AppColors.success
                                : i == current
                                ? AppColors.orange
                                : AppColors.line,
                            width: i == current ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          i < current ? Icons.check_rounded : icons[i],
                          size: 19,
                          color: i < current
                              ? AppColors.success
                              : i == current
                              ? AppColors.orange
                              : AppColors.muted,
                        ),
                      ),
                      if (i < titles.length - 1)
                        Container(
                          width: 2,
                          height: 27,
                          color: i < current
                              ? AppColors.success
                              : AppColors.line,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titles[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: i <= current
                                ? AppColors.navy
                                : AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          i == current
                              ? 'Hiện tại'
                              : i < current
                              ? 'Đã qua bước này'
                              : 'Chưa đến bước này',
                          style: AppType.caption.copyWith(
                            color: i == current
                                ? AppColors.orange
                                : AppColors.muted,
                          ),
                        ),
                        if (times[i] != null)
                          Text(_time(times[i]!), style: AppType.caption),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
