import 'package:flutter/material.dart';
import 'login_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String selectedTab = 'Tất cả (4)';
  Set<String> selectedChips = {'Đến nhanh'};
  bool showRatingCard = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, color: Color(0xFFC1121F), size: 28),
                      const SizedBox(width: 8),
                      const Text('Lịch sử cứu hộ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1A1A1A))),
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

            // Segmented Tabs
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0FA),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                children: [
                  Expanded(child: _TabButton(label: 'Tất cả (4)', isSelected: selectedTab == 'Tất cả (4)', onTap: () => setState(() => selectedTab = 'Tất cả (4)'))),
                  Expanded(child: _TabButton(label: 'Đã xong', isSelected: selectedTab == 'Đã xong', onTap: () => setState(() => selectedTab = 'Đã xong'))),
                  Expanded(child: _TabButton(label: 'Đã hủy', isSelected: selectedTab == 'Đã hủy', onTap: () => setState(() => selectedTab = 'Đã hủy'))),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pending Review Card
                    if (showRatingCard) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.fiber_manual_record, color: Color(0xFFC1121F), size: 10),
                                    SizedBox(width: 6),
                                    Text('ĐÁNH GIÁ CA VỪA HOÀN THÀNH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFC1121F))),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFFFBE4DC), borderRadius: BorderRadius.circular(100)),
                                  child: const Text('Vừa xong', style: TextStyle(color: Color(0xFFC1121F), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: Image.network(
                                    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
                                    width: 45,
                                    height: 45,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const CircleAvatar(radius: 22, backgroundColor: Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text('Nguyễn Văn T...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A1A))),
                                      SizedBox(height: 2),
                                      Text('Xe 29C-741.05 • ...', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) => const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.star_border, color: Color(0xFFF5B301), size: 28),
                              )),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _ReviewChip(label: '⚡ Đến nhanh', isSelected: selectedChips.contains('Đến nhanh'), onTap: () => setState(() => _toggleChip('Đến nhanh'))),
                                const SizedBox(width: 6),
                                _ReviewChip(label: '🤝 Nhiệt tình', isSelected: selectedChips.contains('Nhiệt tình'), onTap: () => setState(() => _toggleChip('Nhiệt tình'))),
                                const SizedBox(width: 6),
                                _ReviewChip(label: '📄 Giá chuẩn', isSelected: selectedChips.contains('Giá chuẩn'), onTap: () => setState(() => _toggleChip('Giá chuẩn'))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () => setState(() => showRatingCard = false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC1121F),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.send, size: 16),
                                    SizedBox(width: 6),
                                    Text('Gửi đánh giá', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Past Requests Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Chuyến cứu hộ trước', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A))),
                        Text('Hà Nội', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Past Request Items
                    _HistoryItemCard(
                      icon: Icons.bolt,
                      iconBg: const Color(0xFFFBE4DC),
                      iconColor: const Color(0xFFC1121F),
                      title: 'Kích bình ắc quy',
                      date: '24/10',
                      vehicle: 'Mazda CX-5 • 30H-889.26',
                      status: 'Đã xong',
                      cost: '120.000đ',
                      paymentMethod: 'MOMO',
                      onInvoice: () {},
                      onRebook: () {},
                    ),
                    const SizedBox(height: 10),
                    _HistoryItemCard(
                      icon: Icons.local_shipping,
                      iconBg: const Color(0xFFE8F1FB),
                      iconColor: const Color(0xFF1565C0),
                      title: 'Kéo xe sàn trượt',
                      date: '15/08',
                      vehicle: 'Hyundai Accent • 29A-452.19',
                      status: 'Đã xong',
                      cost: '650.000đ',
                      paymentMethod: 'VNPAY',
                      onInvoice: () {},
                      onRebook: () {},
                    ),
                    const SizedBox(height: 10),
                    _CancelledHistoryItemCard(
                      icon: Icons.car_repair,
                      title: 'Thay bánh sơ cua',
                      date: '02/06',
                      vehicle: 'Mazda CX-5 • 30H-889.26',
                      reason: 'Lý do: Khách tự mượn được dụng cụ',
                      cost: '0đ',
                    ),
                    const SizedBox(height: 20),
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.home, label: 'Trang chủ', onTap: () => Navigator.pushNamed(context, '/home')),
            _NavItem(icon: Icons.car_crash, label: 'Cứu hộ', badge: '1', onTap: () => Navigator.pushNamed(context, '/request')),
            _NavItem(icon: Icons.radar, label: 'Đang xử lý', onTap: () => Navigator.pushNamed(context, '/tracking')),
            _NavItem(icon: Icons.history, label: 'Lịch sử', isSelected: true, onTap: () {}),
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

  void _toggleChip(String chip) {
    setState(() {
      if (selectedChips.contains(chip)) {
        selectedChips.remove(chip);
      } else {
        selectedChips.add(chip);
      }
    });
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: isSelected ? const Color(0xFFC1121F) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _ReviewChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReviewChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFBE4DC) : const Color(0xFFF7F7FA),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: isSelected ? const Color(0xFFC1121F) : const Color(0xFFE5E7EB)),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isSelected ? const Color(0xFFC1121F) : const Color(0xFF1A1A1A))),
      ),
    );
  }
}

class _HistoryItemCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String date;
  final String vehicle;
  final String status;
  final String cost;
  final String paymentMethod;
  final VoidCallback onInvoice;
  final VoidCallback onRebook;

  const _HistoryItemCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.date,
    required this.vehicle,
    required this.status,
    required this.cost,
    required this.paymentMethod,
    required this.onInvoice,
    required this.onRebook,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$title • $date', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 2),
                    Text(vehicle, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(100)),
                child: Row(
                  children: const [
                    Icon(Icons.check, color: Color(0xFF1E8E3E), size: 12),
                    SizedBox(width: 2),
                    Text('Đã xong', style: TextStyle(color: Color(0xFF1E8E3E), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFFEDEDED), height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(cost, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A1A))),
                  const SizedBox(width: 6),
                  Text(paymentMethod, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onInvoice,
                    icon: const Icon(Icons.receipt_long, size: 13, color: Color(0xFF1565C0)),
                    label: const Text('Biên lai', style: TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      side: const BorderSide(color: Color(0xFFE8F1FB)),
                      backgroundColor: const Color(0xFFE8F1FB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: onRebook,
                    icon: const Icon(Icons.refresh, size: 13, color: Colors.white),
                    label: const Text('Đặt lại', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancelledHistoryItemCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String date;
  final String vehicle;
  final String reason;
  final String cost;

  const _CancelledHistoryItemCard({
    required this.icon,
    required this.title,
    required this.date,
    required this.vehicle,
    required this.reason,
    required this.cost,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Color(0xFFF7F7FA), shape: BoxShape.circle),
                child: Icon(icon, color: const Color(0xFF6B7280), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$title • $date', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 2),
                    Text(vehicle, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFBE4DC), borderRadius: BorderRadius.circular(100)),
                child: Row(
                  children: const [
                    Icon(Icons.close, color: Color(0xFFC1121F), size: 12),
                    SizedBox(width: 2),
                    Text('Đã hủy', style: TextStyle(color: Color(0xFFC1121F), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFFEDEDED), height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(reason, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)))),
              Text(cost, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A1A))),
            ],
          ),
        ],
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
