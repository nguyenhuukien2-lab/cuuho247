import 'package:flutter/material.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.car_crash, color: Color(0xFFC1121F), size: 28),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('ResQ247 24/7', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A))),
                          Text('Trang Chủ', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC1121F),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.phone, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('HOTLINE 1900 6868', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Color(0xFFC1121F), shape: BoxShape.circle),
                        child: const Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFE8F1FB), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.gps_fixed, color: Color(0xFF1565C0), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('GPS TRỰC TIẾP', style: TextStyle(fontSize: 10, color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('Km 14+200, Cao tốc Pháp Vân - Cầu...', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      child: const Text('Đổi', style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Nearby Alert Banner
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBE4DC),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.wifi_tethering, color: Color(0xFFC1121F), size: 16),
                      SizedBox(width: 6),
                      Text('42 xe cứu hộ sẵn sàng (bán kính 5km)', style: TextStyle(color: Color(0xFFC1121F), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Giant SOS Button Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFC1121F).withOpacity(0.1),
                          ),
                        ),
                        Container(
                          width: 125,
                          height: 125,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFC1121F).withOpacity(0.2),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/request'),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFFC1121F), Color(0xFF8E0F1A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [BoxShadow(color: Color(0xFFC1121F), blurRadius: 14, offset: const Offset(0, 5))],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
                                SizedBox(height: 2),
                                Text('CỨU HỘ', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                Text('NGAY', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('CHẠM 1 LẦN', style: TextStyle(color: Color(0xFFC1121F), fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.bolt, color: Color(0xFFC1121F), size: 15),
                        SizedBox(width: 4),
                        Text('Kết nối trạm gần nhất sau ', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                        Text('3s', style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Quick Services Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.settings_suggest, color: Color(0xFFC1121F), size: 20),
                      SizedBox(width: 6),
                      Text('Dịch vụ cứu hộ nhanh', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                    ],
                  ),
                  Text('Chuẩn niêm yết', style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),

              // Detailed Service Cards Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  _CompactServiceCard(
                    icon: Icons.donut_large,
                    title: 'Vá / Thay lốp',
                    price: '150.000đ',
                    sub: '15-20 phút',
                    onTap: () => Navigator.pushNamed(context, '/request'),
                  ),
                  _CompactServiceCard(
                    icon: Icons.bolt,
                    title: 'Kích bình ắc qu...',
                    price: '120.000đ',
                    sub: '10-15 phút',
                    onTap: () => Navigator.pushNamed(context, '/request'),
                  ),
                  _CompactServiceCard(
                    icon: Icons.local_gas_station,
                    title: 'Tiếp xăng dầu',
                    price: 'Tận xe',
                    sub: '15 phút tới',
                    onTap: () => Navigator.pushNamed(context, '/request'),
                  ),
                  _CompactServiceCard(
                    icon: Icons.car_repair,
                    title: 'Cẩu / Kéo xe',
                    price: '600.000đ',
                    sub: 'Xe sàn trượt',
                    onTap: () => Navigator.pushNamed(context, '/request'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Bottom Hotline Support Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF101828),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFC1121F), shape: BoxShape.circle),
                      child: const Icon(Icons.phone, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('TỔNG ĐÀI TRỰC 24/7', style: TextStyle(color: Color(0xFFF5A623), fontSize: 9, fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('1900 6868', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC1121F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Row(
                        children: const [
                          Text('Gọi ngay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.home, label: 'Trang chủ', isSelected: true, onTap: () {}),
            _NavItem(icon: Icons.car_crash, label: 'Cứu hộ', badge: '1', onTap: () => Navigator.pushNamed(context, '/request')),
            _NavItem(icon: Icons.radar, label: 'Đang xử lý', onTap: () => Navigator.pushNamed(context, '/tracking')),
            _NavItem(icon: Icons.history, label: 'Lịch sử', onTap: () => Navigator.pushNamed(context, '/history')),
            _NavItem(icon: Icons.person, label: 'Tài khoản', onTap: () {
              if (UserSession.isLoggedIn) {
                Navigator.pushNamed(context, '/account');
              } else {
                Navigator.pushNamed(context, '/login');
              }
            }),
          ],
        ),
      ),
    );
  }
}

class _CompactServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String price;
  final String sub;
  final VoidCallback onTap;

  const _CompactServiceCard({
    required this.icon,
    required this.title,
    required this.price,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFE8F1FB), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: const Color(0xFF1565C0), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 2),
                  Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFC1121F))),
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                ],
              ),
            ),
          ],
        ),
      ),
      );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, this.badge, this.isSelected = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFFC1121F) : const Color(0xFF6B7280);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Icon(icon, color: color, size: 22),
              if (badge != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Color(0xFFC1121F), shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                    child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
