import 'package:flutter/material.dart';
import 'login_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String displayName = UserSession.fullName ?? 'Trần Hoàng Long';
    final String displayPhone = UserSession.phoneNumber != null && UserSession.phoneNumber!.isNotEmpty
        ? UserSession.phoneNumber!
        : '0912 ••• 678';

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
                      const Text('ResQ247', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1A1A1A))),
                      const Text(' • Tài khoản', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC1121F),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.phone, color: Colors.white, size: 14),
                            SizedBox(width: 6),
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
              const SizedBox(height: 20),

              // Profile Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE8F1FB),
                            border: Border.all(color: const Color(0xFF1565C0), width: 2),
                            image: const DecorationImage(
                              image: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Color(0xFFC1121F), shape: BoxShape.circle),
                            child: const Icon(Icons.verified, color: Colors.white, size: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1A1A1A))),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF6B7280)),
                                onPressed: () {},
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBE4DC),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('ResQ VIP', style: TextStyle(color: Color(0xFFC1121F), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Text(displayPhone, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              const Icon(Icons.check_circle, color: Color(0xFF1565C0), size: 14),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text('• Đã định danh CCCD & SĐT', style: TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3 Quick Stat Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(Icons.directions_car, 'Xe đã lưu', '2 xe', 'CX-5 • SH 150'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(Icons.security, 'Gói bảo hộ', 'Gold 24/7', 'Hạn 12/2025'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(Icons.account_balance_wallet, 'Ưu đãi / Ví', '350.000đ', '2 mã sẵn có'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Section 1: HỒ SƠ PHƯƠNG TIỆN & CỨU TRỢ
              const Text('HỒ SƠ PHƯƠNG TIỆN & CỨU TRỢ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    _buildMenuItem(Icons.directions_car_filled, 'Phương tiện của tôi', 'Quản lý biển số, hãng xe...', trailingBadge: '30A-982.14', onTap: () {}),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                    _buildMenuItem(Icons.contact_phone, 'Sổ liên lạc khẩn cấp', 'Tự động gửi vị trí cho người...', trailingBadge: '2 số đã lưu', onTap: () {}),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                    _buildMenuItem(Icons.local_police, 'Gói cứu hộ & Bảo hiểm đa tầng', 'Miễn phí cẩu xe 50km • Kích...', trailingChip: 'Chi tiết', onTap: () {}),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                    _buildMenuItem(Icons.payment, 'Phương thức thanh toán & Ví', 'MoMo, VNPay, Vietcombank link', showShield: true, onTap: () => Navigator.pushNamed(context, '/payment')),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                    _buildMenuItem(Icons.receipt_long, 'Lịch sử cứu hộ & Hóa đơn VAT', 'Tra cứu biên nhận điện tử & lịch trình cũ', onTap: () => Navigator.pushNamed(context, '/history')),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 2: HỆ THỐNG & HỖ TRỢ
              const Text('HỆ THỐNG & HỖ TRỢ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBE4DC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC1121F).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: Color(0xFFC1121F), shape: BoxShape.circle),
                      child: const Icon(Icons.phone, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Tổng đài cứu hộ 24/7', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFC1121F))),
                          SizedBox(height: 2),
                          Text('Trực ban khẩn cấp: 1900 6868 (Miễn phí)', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC1121F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        elevation: 0,
                      ),
                      child: const Text('Gọi ngay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    _buildMenuItem(Icons.settings_outlined, 'Cài đặt & Bảo mật', 'Mã PIN, xác thực sinh trắc học, thông báo...', onTap: () {}),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    UserSession.clear();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  icon: const Icon(Icons.logout, color: Color(0xFFC1121F)),
                  label: const Text('Đăng xuất tài khoản', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC1121F), fontSize: 15)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFC1121F)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text('ResQ247 v3.8.2 (Bảo hộ toàn diện Việt Nam)', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ),
              const SizedBox(height: 20),
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
            _NavItem(icon: Icons.home, label: 'Trang chủ', onTap: () => Navigator.pushReplacementNamed(context, '/home')),
            _NavItem(icon: Icons.car_crash, label: 'Cứu hộ', onTap: () => Navigator.pushNamed(context, '/request')),
            _NavItem(icon: Icons.radar, label: 'Đang xử lý', onTap: () => Navigator.pushNamed(context, '/tracking')),
            _NavItem(icon: Icons.history, label: 'Lịch sử', onTap: () => Navigator.pushNamed(context, '/history')),
            _NavItem(icon: Icons.person, label: 'Tài khoản', isSelected: true, onTap: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String title, String value, String sub) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1565C0), size: 18),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, {String? trailingBadge, String? trailingChip, bool showShield = false, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFEEF0FA), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: const Color(0xFF1565C0), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            if (trailingBadge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFEEF0FA), borderRadius: BorderRadius.circular(8)),
                child: Text(trailingBadge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
              ),
            if (trailingChip != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFE8F1FB), borderRadius: BorderRadius.circular(8)),
                child: Text(trailingChip, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
              ),
            if (showShield)
              const Icon(Icons.verified_user, color: Color(0xFF1565C0), size: 18),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 20),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, this.isSelected = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFFC1121F) : const Color(0xFF6B7280);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
