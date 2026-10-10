import 'package:flutter/material.dart';
import 'login_screen.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      body: SafeArea(
        child: Stack(
          children: [
            // Map Background Area
            Positioned.fill(
              bottom: 380,
              child: Container(
                color: const Color(0xFFE5E7EB),
                child: CustomPaint(
                  painter: _MapGridPainter(),
                ),
              ),
            ),

            // Top Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white.withValues(alpha: 0.95),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.car_crash, color: Color(0xFFC1121F), size: 28),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('ResQ247', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A))),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFC1121F), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('24/7 LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const Text('Theo dõi cứu hộ trực tiếp', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
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
                              Text('1900 6868', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
              ),
            ),

            // Bottom Sheet Panel
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -6))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: const Color(0xFFCBD5E0), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ETA & Status Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: const [
                                Text('7', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: Color(0xFFC1121F), height: 1)),
                                SizedBox(width: 4),
                                Text('phút', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFC1121F))),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text('Dự kiến 07:45 • Cách 1.4 km', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(100)),
                          child: Row(
                            children: const [
                              Icon(Icons.fiber_manual_record, color: Color(0xFF1E8E3E), size: 10),
                              SizedBox(width: 4),
                              Text('Đang di chuyển', style: TextStyle(color: Color(0xFF1E8E3E), fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4-Stage Progress Bar
                    Row(
                      children: [
                        Expanded(child: _StageBar(label: '1. Đặt xe', state: _StageState.completed)),
                        const SizedBox(width: 4),
                        Expanded(child: _StageBar(label: '2. Đang đến', state: _StageState.active)),
                        const SizedBox(width: 4),
                        Expanded(child: _StageBar(label: '3. Đã tới', state: _StageState.pending)),
                        const SizedBox(width: 4),
                        Expanded(child: _StageBar(label: '4. Hoàn thành', state: _StageState.pending)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Technician Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: Image.network(
                                  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const CircleAvatar(radius: 25, backgroundColor: Colors.grey),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: const Icon(Icons.verified, color: Color(0xFF1E8E3E), size: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Nguyễn Văn Tuấn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A1A))),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFFFF2DC), borderRadius: BorderRadius.circular(6)),
                                      child: Row(
                                        children: const [
                                          Icon(Icons.star, color: Color(0xFFF5B301), size: 11),
                                          SizedBox(width: 2),
                                          Text('4.9 (350+)', style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text('Kỹ thuật viên ResQ Pro', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                const SizedBox(height: 2),
                                const Text('Xe sàn trượt Isuzu • 29C-774.82', style: TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF1565C0)),
                            ),
                            child: const Text('ResQ Pro', style: TextStyle(color: Color(0xFF1565C0), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.phone, size: 16),
                              label: const Text('Gọi thợ ngay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC1121F),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, '/payment'),
                              icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF1565C0)),
                              label: const Text('Nhắn tin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1565C0))),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE8F1FB),
                                foregroundColor: const Color(0xFF1565C0),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Issue Summary Alert Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.error_outline, color: Color(0xFFC1121F), size: 16),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text('Sự cố: Nổ lốp trước bên phụ • Mazda CX-5 (3...', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1A1A1A))),
                              ),
                              Text('#RQ-8842', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1565C0))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFFFFF2DC), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: const [
                                Icon(Icons.warning_amber_rounded, color: Color(0xFFF5A623), size: 16),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text('Bật đèn hazard và đứng sau lan can đường an toàn', style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Bottom Footer Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.share, size: 14, color: Color(0xFF1565C0)),
                          label: const Text('Chia sẻ lộ trình', style: TextStyle(color: Color(0xFF1565C0), fontSize: 12, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        ),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFF6B7280)),
                          label: const Text('Hủy ca cứu hộ', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.home, label: 'Trang chủ', onTap: () => Navigator.pushNamed(context, '/home')),
            _NavItem(icon: Icons.car_crash, label: 'Cứu hộ', badge: '1', onTap: () => Navigator.pushNamed(context, '/request')),
            _NavItem(icon: Icons.radar, label: 'Đang xử lý', isSelected: true, onTap: () {}),
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

enum _StageState { completed, active, pending }

class _StageBar extends StatelessWidget {
  final String label;
  final _StageState state;

  const _StageBar({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (state == _StageState.completed) {
      color = const Color(0xFF1565C0);
    } else if (state == _StageState.active) {
      color = const Color(0xFFC1121F);
    } else {
      color = const Color(0xFFE5E7EB);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 5,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: state == _StageState.active ? const Color(0xFFC1121F) : const Color(0xFF6B7280))),
      ],
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

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
