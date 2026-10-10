import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../services/supabase_service.dart';

class ProviderListScreen extends StatefulWidget {
  const ProviderListScreen({super.key});

  @override
  State<ProviderListScreen> createState() => _ProviderListScreenState();
}

class _ProviderListScreenState extends State<ProviderListScreen> {
  String selectedFilter = 'Gần nhất';
  List<dynamic> providers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRealProviders();
  }

  Future<void> _loadRealProviders() async {
    final list = await SupabaseService.fetchNearbyProviders(lat: 21.0285, lng: 105.8542);
    setState(() {
      providers = list.isNotEmpty ? list : [
        {
          'name': 'Đội cứu hộ 116 Hà Nội',
          'rating': 4.9,
          'distance_km': 1.8,
          'price_estimate': 350000,
          'image_url': 'https://images.unsplash.com/photo-1563720223185-11003d516935?auto=format&fit=crop&w=300&q=80'
        },
        {
          'name': 'Cứu hộ Minh Khang',
          'rating': 4.8,
          'distance_km': 2.5,
          'price_estimate': 220000,
          'image_url': 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&w=300&q=80'
        },
        {
          'name': 'Cứu hộ 24/7 Miền Bắc',
          'rating': 5.0,
          'distance_km': 4.1,
          'price_estimate': 400000,
          'image_url': 'https://images.unsplash.com/photo-1541899481282-d53bffe3c351?auto=format&fit=crop&w=300&q=80'
        },
      ];
      isLoading = false;
    });
  }

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
                      const Icon(Icons.car_crash, color: Color(0xFFC1121F), size: 28),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('ResQ247 24/7', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A))),
                          Text('Đội cứu hộ khả dụng (Real Supabase Data)', style: TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
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
                ],
              ),
            ),

            // Interactive Map View Area (Mock)
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFE5E7EB),
                    child: CustomPaint(
                      painter: _MapGridPainter(),
                    ),
                  ),
                  // Floating Location Bar over Map
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFFC1121F), size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Km 48+200, Đỗ Xá, Pháp Vân - Cầu Giê',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1A1A1A)),
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(30, 30)),
                            child: const Text('Đổi', style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: Color(0xFFF7F7FA), shape: BoxShape.circle),
                            child: const Icon(Icons.navigation, color: Color(0xFF1565C0), size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Map Pins
                  const Positioned(
                    top: 130,
                    left: 180,
                    child: _MapPin(title: 'Bạn ở đây', isUser: true),
                  ),
                  const Positioned(
                    top: 80,
                    left: 80,
                    child: _MapPin(title: '1.8km', isUser: false),
                  ),
                  const Positioned(
                    bottom: 40,
                    right: 100,
                    child: _MapPin(title: '2.5km', isUser: false),
                  ),
                ],
              ),
            ),

            // Bottom Sheet Provider List
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: const Color(0xFFCBD5E0), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('Đội cứu hộ quanh bạn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A))),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFEEF0FA), borderRadius: BorderRadius.circular(100)),
                              child: Text('${providers.length} xe', style: const TextStyle(color: Color(0xFF1565C0), fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Text('Báo giá minh bạch', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Filter Chips
                    Row(
                      children: [
                        _FilterChip(label: 'Gần nhất', icon: Icons.location_on, isSelected: selectedFilter == 'Gần nhất', onTap: () => setState(() => selectedFilter = 'Gần nhất')),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'Đánh giá cao', icon: Icons.star, isSelected: selectedFilter == 'Đánh giá cao', onTap: () => setState(() => selectedFilter = 'Đánh giá cao')),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'Giá rẻ nhất', icon: Icons.local_offer, isSelected: selectedFilter == 'Giá rẻ nhất', onTap: () => setState(() => selectedFilter = 'Giá rẻ nhất')),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Provider List
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC1121F)))
                          : ListView.builder(
                              itemCount: providers.length,
                              itemBuilder: (context, index) {
                                final p = providers[index];
                                final name = p['name'] ?? 'Đội cứu hộ';
                                final rating = p['rating']?.toString() ?? '4.9';
                                final distance = '${p['distance_km']?.toString() ?? '1.8'} km';
                                final price = '${p['price_estimate']?.toString() ?? '350000'}đ';
                                final imageUrl = p['image_url'] ?? 'https://images.unsplash.com/photo-1563720223185-11003d516935?auto=format&fit=crop&w=300&q=80';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ProviderCard(
                                    name: name,
                                    rating: rating,
                                    distance: distance,
                                    eta: '8 phút tới',
                                    price: price,
                                    imageUrl: imageUrl,
                                    onTap: () => Navigator.pushNamed(context, '/tracking'),
                                  ),
                                );
                              },
                            ),
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
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC1121F) : const Color(0xFFF7F7FA),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: isSelected ? const Color(0xFFC1121F) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF6B7280), size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isSelected ? Colors.white : const Color(0xFF1A1A1A))),
          ],
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final String name;
  final String rating;
  final String distance;
  final String eta;
  final String price;
  final String imageUrl;
  final VoidCallback onTap;

  const _ProviderCard({
    required this.name,
    required this.rating,
    required this.distance,
    required this.eta,
    required this.price,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              width: 65,
              height: 65,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 65,
                height: 65,
                color: const Color(0xFFE5E7EB),
                child: const Icon(Icons.car_repair, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: Color(0xFF1565C0), size: 14),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFF5B301), size: 13),
                    const SizedBox(width: 2),
                    Text(rating, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1A1A1A))),
                    const Text(' • ', style: TextStyle(color: Color(0xFF9CA3AF))),
                    Text(distance, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFC1121F))),
                    const Text(' • ', style: TextStyle(color: Color(0xFF9CA3AF))),
                    Text(eta, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFC1121F))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC1121F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
            child: const Text('Chọn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final String title;
  final bool isUser;

  const _MapPin({required this.title, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFF1565C0) : Colors.white,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))],
        border: isUser ? null : Border.all(color: const Color(0xFFC1121F), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isUser ? Icons.my_location : Icons.location_pin, color: isUser ? Colors.white : const Color(0xFFC1121F), size: 14),
          const SizedBox(width: 4),
          Text(title, style: TextStyle(color: isUser ? Colors.white : const Color(0xFF1A1A1A), fontSize: 10, fontWeight: FontWeight.bold)),
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
