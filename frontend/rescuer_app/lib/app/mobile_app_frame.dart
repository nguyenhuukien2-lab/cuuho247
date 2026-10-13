import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Matches customer_app's root mobile viewport, including Navigator overlays.
class MobileAppFrame extends StatelessWidget {
  const MobileAppFrame({super.key, required this.child});

  // Keep aligned with customer_app/lib/main.dart's MaterialApp.builder.
  static const maxWidth = 520.0;

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.navy,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) => SizedBox.expand(
            child: ClipRect(
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(size: constraints.biggest),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
