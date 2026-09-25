import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeTabContent(),
    Placeholder(), // Handled via routes or tabs
    Placeholder(),
    Placeholder(),
    Placeholder(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.local_shipping, color: Color(0xFFE53935)),
            SizedBox(width: 8),
            Text('Cứu Hộ 247', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A202C))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF2D3748)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Color(0xFF2D3748)),
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // GPS Location Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on, color: Color(0xFF1E88E5)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Vị trí hiện tại của bạn', style: TextStyle(color: Color(0xFF718096), fontSize: 12)),
                        SizedBox(height: 4),
                        Text(
                          '123 Nguyễn Huệ, P. Bến Nghé, Quận 1, TP.HCM',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3748)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF1E88E5)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã cập nhật vị trí GPS')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Giant Red SOS Button
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/request'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFC62828)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFE53935).withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.warning_rounded, color: Colors.white, size: 40),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CỨU HỘ NGAY (SOS)',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Chạm để gọi thợ cứu hộ gần nhất trong 3s',
                          style: TextStyle(color: Color(0xFFFFCDD2), fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Quick Services Grid Header
            Row(
              mainAxisAlignment: MainAxisAlignment.between,
              children: const [
                Text(
                  'Dịch vụ cứu hộ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A202C)),
                ),
                Text('Xem tất cả', style: TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),

            // Quick Services Grid
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _serviceItem(context, Icons.car_repair, 'Kéo xe', const Color(0xFFE53935)),
                _serviceItem(context, Icons.settings_accessibility, 'Vá vỏ', const Color(0xFF1E88E5)),
                _serviceItem(context, Icons.bolt, 'Kích bình', const Color(0xFFFB8C00)),
                _serviceItem(context, Icons.local_gas_station, 'Xăng xe', const Color(0xFF43A047)),
                _serviceItem(context, Icons.key, 'Mở khóa', const Color(0xFF8E24AA)),
                _serviceItem(context, Icons.build, 'Sửa nhanh', const Color(0xFF00ACC1)),
                _serviceItem(context, Icons.electric_car, 'Xe điện', const Color(0xFF3949AB)),
                _serviceItem(context, Icons.more_horiz, 'Khác', const Color(0xFF757575)),
              ],
            ),
            const SizedBox(height: 28),

            // Safety Tips Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFF1E88E5), size: 36),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Mẹo an toàn khi xe hỏng giữa đường',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0), fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Bật đèn cảnh báo hazard, đặt biển báo tam giác cách xe 50m và đứng vào lề an toàn.',
                          style: TextStyle(color: Color(0xFF424242), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFFE53935),
        unselectedItemColor: const Color(0xFF718096),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) Navigator.pushNamed(context, '/request');
          else if (index == 2) Navigator.pushNamed(context, '/providers');
          else if (index == 3) Navigator.pushNamed(context, '/tracking');
          else if (index == 4) Navigator.pushNamed(context, '/history');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.sos), label: 'Yêu cầu'),
          BottomNavigationBarItem(icon: Icon(Icons.engineering), label: 'Thợ cứu hộ'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Theo dõi'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Lịch sử'),
        ],
      ),
    );
  }

  Widget _serviceItem(BuildContext context, IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/request'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2D3748)),
          ),
        ],
      ),
    );
  }
}

class HomeTabContent extends StatelessWidget {
  const HomeTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
