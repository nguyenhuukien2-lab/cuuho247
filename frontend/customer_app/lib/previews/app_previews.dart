import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../main.dart';

@Preview(
  name: 'Cứu Hộ 24/7',
  group: 'Ứng dụng',
  // Keep a real phone aspect ratio while fitting the complete device frame
  // and preview controls inside the IDE panel.
  size: Size(260, 562),
)
Widget rescueAppPreview() => const FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(width: 390, height: 844, child: RescueApp()),
    );
