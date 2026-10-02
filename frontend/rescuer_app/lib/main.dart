import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Cứu Hộ 24/7 Đối tác',
      home: Scaffold(
        body: Center(child: Text('Cứu Hộ 24/7 Đối tác — đang chuẩn bị')),
      ),
    );
  }
}
