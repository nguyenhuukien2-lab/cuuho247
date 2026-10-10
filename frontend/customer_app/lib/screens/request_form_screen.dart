import 'package:flutter/material.dart';
import 'login_screen.dart';

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  String selectedVehicle = 'Ô tô';
  Set<String> selectedIssues = {'Nổ lốp'};

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
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.car_crash, color: Color(0xFFC1121F), size: 24),
                      const SizedBox(width: 6),
                      const Text('ResQ247', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A))),
                      const Text(' • Yêu cầu cứu hộ', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC1121F),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.phone, color: Colors.white, size: 13),
                        SizedBox(width: 4),
                        Text('1900 6868', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step Progress Indicator
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(color: Color(0xFFC1121F), shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: const Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(width: 10),
                          const Text('Thông tin sự cố & Vị trí', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A))),
                          const Spacer(),
                          Row(
                            children: [
                              Container(width: 32, height: 4, decoration: BoxDecoration(color: const Color(0xFFC1121F), borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 4),
                              Container(width: 16, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 4),
                              Container(width: 16, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
                            ],
                          ),
                          const SizedBox(width: 8),
                          const Text('1/3', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC1121F))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Vehicle Type Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('LOẠI PHƯƠNG TIỆN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
                              Text('Chọn 1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC1121F))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _VehicleTypeOption(icon: Icons.directions_car, label: 'Ô tô', isSelected: selectedVehicle == 'Ô tô', onTap: () => setState(() => selectedVehicle = 'Ô tô'))),
                              const SizedBox(width: 8),
                              Expanded(child: _VehicleTypeOption(icon: Icons.two_wheeler, label: 'Xe máy', isSelected: selectedVehicle == 'Xe máy', onTap: () => setState(() => selectedVehicle = 'Xe máy'))),
                              const SizedBox(width: 8),
                              Expanded(child: _VehicleTypeOption(icon: Icons.local_shipping, label: 'Bán tải', isSelected: selectedVehicle == 'Bán tải', onTap: () => setState(() => selectedVehicle = 'Bán tải'))),
                              const SizedBox(width: 8),
                              Expanded(child: _VehicleTypeOption(icon: Icons.electric_car, label: 'Xe điện', isSelected: selectedVehicle == 'Xe điện', onTap: () => setState(() => selectedVehicle = 'Xe điện'))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Vehicle & Pickup Location Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('XE & ĐIỂM ĐÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F7FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFEDEDED)),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.directions_car_filled, color: Color(0xFFC1121F), size: 18),
                                SizedBox(width: 10),
                                Text('Biển số: ', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                Text('30H-889.26', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A))),
                                Spacer(),
                                Text('Mazda CX-5', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F7FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFEDEDED)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.navigation, color: Color(0xFFC1121F), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text('Km 48+200, Cao tốc Pháp Vân - Cầu...', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1A1A1A))),
                                      SizedBox(height: 2),
                                      Text('GPS chính xác ±3m', style: TextStyle(fontSize: 10, color: Color(0xFF1565C0))),
                                    ],
                                  ),
                                ),
                                IconButton(icon: const Icon(Icons.edit_outlined, color: Color(0xFF1565C0), size: 18), onPressed: () {}),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Issues Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('VẤN ĐỀ GẶP PHẢI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
                              Text('Chọn 1 hoặc nhiều', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 2.8,
                            children: [
                              _IssueChip(icon: Icons.donut_large, label: 'Nổ lốp', isSelected: selectedIssues.contains('Nổ lốp'), onTap: () => setState(() => _toggleIssue('Nổ lốp'))),
                              _IssueChip(icon: Icons.bolt, label: 'Hết bình', isSelected: selectedIssues.contains('Hết bình'), onTap: () => setState(() => _toggleIssue('Hết bình'))),
                              _IssueChip(icon: Icons.car_repair, label: 'Xe không nổ máy', isSelected: selectedIssues.contains('Xe không nổ máy'), onTap: () => setState(() => _toggleIssue('Xe không nổ máy'))),
                              _IssueChip(icon: Icons.local_shipping, label: 'Cần cẩu xe', isSelected: selectedIssues.contains('Cần cẩu xe'), onTap: () => setState(() => _toggleIssue('Cần cẩu xe'))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Scene Photo Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  color: const Color(0xFFE5E7EB),
                                  child: const Icon(Icons.image, color: Colors.grey),
                                ),
                              ),
                              Positioned(
                                right: 2,
                                top: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Ảnh hiện trường', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A))),
                                SizedBox(height: 2),
                                Text('1 ảnh đã tải lên', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.camera_alt_outlined, size: 14, color: Color(0xFFC1121F)),
                            label: const Text('Thêm ảnh', style: TextStyle(color: Color(0xFFC1121F), fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFBE4DC)),
                              backgroundColor: const Color(0xFFFDECE3),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('Tạm tính:', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      SizedBox(height: 2),
                      Text('250.000đ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFC1121F))),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/providers'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC1121F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.radar, size: 18),
                            SizedBox(width: 6),
                            Text('Tìm đội cứu hộ gần nhất', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
            _NavItem(icon: Icons.car_crash, label: 'Cứu hộ', badge: '1', isSelected: true, onTap: () {}),
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

  void _toggleIssue(String issue) {
    setState(() {
      if (selectedIssues.contains(issue)) {
        selectedIssues.remove(issue);
      } else {
        selectedIssues.add(issue);
      }
    });
  }
}

class _VehicleTypeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _VehicleTypeOption({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFDECE3) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? const Color(0xFFC1121F) : const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFC1121F) : const Color(0xFF6B7280), size: 22),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isSelected ? const Color(0xFFC1121F) : const Color(0xFF1A1A1A))),
          ],
        ),
      ),
    );
  }
}

class _IssueChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _IssueChip({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC1121F) : const Color(0xFFF7F7FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? const Color(0xFFC1121F) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF6B7280), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSelected ? Colors.white : const Color(0xFF1A1A1A)),
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
