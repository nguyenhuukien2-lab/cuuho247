import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class ProviderListScreen extends StatefulWidget {
  const ProviderListScreen({super.key});

  @override
  State<ProviderListScreen> createState() => _ProviderListScreenState();
}

class _ProviderListScreenState extends State<ProviderListScreen> {
  String _selectedFilter = 'Gần nhất';
  final List<String> _filters = ['Gần nhất', 'Đánh giá cao', 'Giá tốt nhất', 'Đã xác thực'];

  final List<Map<String, dynamic>> _providers = [
    {
      'name': 'Garage Cứu Hộ 24h Sài Gòn',
      'distance': '0.8 km',
      'rating': 4.9,
      'reviews': 328,
      'price': '150.000 đ',
      'time': '5 phút tới',
      'verified': true,
      'image': 'https://images.unsplash.com/photo-1486006920555-c77dce18193b?w=200',
    },
    {
      'name': 'Trung Tâm Vá Vỏ Lưu Động Q1',
      'distance': '1.5 km',
      'rating': 4.8,
      'reviews': 194,
      'price': '100.000 đ',
      'time': '8 phút tới',
      'verified': true,
      'image': 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=200',
    },
    {
      'name': 'Cứu Hộ Ô Tô Minh Phát',
      'distance': '2.2 km',
      'rating': 4.7,
      'reviews': 142,
      'price': '200.000 đ',
      'time': '12 phút tới',
      'verified': false,
      'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thợ Cứu Hộ Gần Nhất', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A202C))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3748)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      selectedColor: const Color(0xFF1E88E5),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF2D3748),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      backgroundColor: const Color(0xFFF1F5F9),
                      onSelected: (selected) => setState(() => _selectedFilter = filter),
                    ),
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Provider List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _providers.length,
              itemBuilder: (context, index) {
                final provider = _providers[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          provider['image'],
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    provider['name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A202C)),
                                  ),
                                ),
                                if (provider['verified'])
                                  const Icon(Icons.verified, color: Color(0xFF1E88E5), size: 18),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                RatingBarIndicator(
                                  rating: provider['rating'],
                                  itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                                  itemSize: 14,
                                ),
                                const SizedBox(width: 4),
                                Text('${provider['rating']} (${provider['reviews']})', style: const TextStyle(fontSize: 12, color: Color(0xFF718096))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Color(0xFFE53935)),
                                Text(' ${provider['distance']} • ', style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568))),
                                const Icon(Icons.access_time, size: 14, color: Color(0xFF1E88E5)),
                                Text(' ${provider['time']}', style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.between,
                              children: [
                                Text(
                                  provider['price'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE53935), fontSize: 16),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pushNamed(context, '/tracking'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E88E5),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  child: const Text('CHỌN THỢ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
