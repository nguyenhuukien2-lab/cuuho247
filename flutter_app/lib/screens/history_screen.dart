import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _showRatingCard = true;

  final List<Map<String, dynamic>> _history = [
    {
      'title': 'Vá vỏ lưu động • Ô tô',
      'date': '15/10/2023 - 14:30',
      'provider': 'Garage Cứu Hộ 24h Sài Gòn',
      'cost': '150.000 đ',
      'status': 'Hoàn thành',
      'statusColor': const Color(0xFF43A047),
    },
    {
      'title': 'Kích bình ắc-quy • Xe máy',
      'date': '02/10/2023 - 08:15',
      'provider': 'Trung Tâm Vá Vỏ Q1',
      'cost': '80.000 đ',
      'status': 'Hoàn thành',
      'statusColor': const Color(0xFF43A047),
    },
    {
      'title': 'Kéo xe cứu hộ • Ô tô',
      'date': '20/09/2023 - 19:00',
      'provider': 'Cứu Hộ Minh Phát',
      'cost': '500.000 đ',
      'status': 'Đã hủy',
      'statusColor': const Color(0xFFE53935),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch Sử Cứu Hộ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A202C))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3748)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pending Rating Card
          if (_showRatingCard) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD54F)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.between,
                    children: [
                      const Text(
                        'Đánh giá chuyến cứu hộ gần nhất',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF8D6E63)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Color(0xFF8D6E63)),
                        onPressed: () => setState(() => _showRatingCard = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Garage Cứu Hộ 24h Sài Gòn • Vá vỏ ô tô', style: TextStyle(fontSize: 12, color: Color(0xFF5D4037))),
                  const SizedBox(height: 16),
                  Center(
                    child: RatingBar.builder(
                      initialRating: 5,
                      minRating: 1,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemSize: 32,
                      itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                      onRatingUpdate: (rating) {},
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: const [
                      Chip(label: Text('Nhiệt tình')),
                      Chip(label: Text('Nhanh chóng')),
                      Chip(label: Text('Chuyên nghiệp')),
                      Chip(label: Text('Giá tốt')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _showRatingCard = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cảm ơn bạn đã đánh giá!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFB8C00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('GỬI ĐÁNH GIÁ', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Past Requests History
          const Text('Lịch sử yêu cầu cứu hộ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A202C))),
          const SizedBox(height: 12),
          ..._history.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.between,
                    children: [
                      Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A202C))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item['statusColor'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item['status'],
                          style: TextStyle(color: item['statusColor'], fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(item['provider'], style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568))),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.between,
                    children: [
                      Text(item['date'], style: const TextStyle(fontSize: 12, color: Color(0xFF718096))),
                      Text(item['cost'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE53935), fontSize: 15)),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
