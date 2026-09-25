import 'package:flutter/material.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theo Dõi Cứu Hộ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A202C))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3748)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Map Background Placeholder
          Container(
            height: MediaQuery.of(context).size.height * 0.55,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1524661135-423995f22d0b?w=800'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              alignment: Alignment.topRight,
              padding: const EdgeInsets.all(16),
              child: FloatingActionButton.small(
                backgroundColor: Colors.white,
                child: const Icon(Icons.my_location, color: Color(0xFF1E88E5)),
                onPressed: () {},
              ),
            ),
          ),

          // Bottom Sheet Content
          DraggableScrollableSheet(
            initialChildSize: 0.52,
            minChildSize: 0.45,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5)),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: const Color(0xFFCBD5E0), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.between,
                      children: const [
                        Text('Trạng thái cứu hộ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A202C))),
                        Text('Dự kiến: 5 phút', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 4-Stage Progress Tracker
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        _ProgressStep(icon: Icons.check_circle, label: 'Tiếp nhận', isActive: true),
                        _ProgressStep(icon: Icons.directions_car, label: 'Đang đến', isActive: true),
                        _ProgressStep(icon: Icons.build, label: 'Đang sửa', isActive: false),
                        _ProgressStep(icon: Icons.task_alt, label: 'Hoàn thành', isActive: false),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),

                    // Technician Card
                    const Text('Thông tin thợ cứu hộ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A202C))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150'),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Nguyễn Văn Thợ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A202C))),
                              SizedBox(height: 2),
                              Text('Honda AirBlade • Biển số: 59-C1 12345', style: TextStyle(fontSize: 12, color: Color(0xFF718096))),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber, size: 14),
                                  Text(' 4.9 (248 đánh giá)', style: TextStyle(fontSize: 12, color: Color(0xFF4A5568))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Call & Message buttons
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chat, color: Color(0xFF1E88E5)),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(Icons.phone, color: Color(0xFF43A047)),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Proceed to Payment Button (for demo purposes)
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('XEM THANH TOÁN (DEMO)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _ProgressStep({required this.icon, required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFE53935) : const Color(0xFFEDF2F7),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isActive ? Colors.white : const Color(0xFFA0AEC0), size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? const Color(0xFFE53935) : const Color(0xFF718096),
          ),
        ),
      ],
    );
  }
}
