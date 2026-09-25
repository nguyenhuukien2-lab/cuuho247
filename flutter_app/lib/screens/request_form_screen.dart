import 'package:flutter/material.dart';

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  String _selectedVehicle = 'Ô tô';
  String _selectedIssue = 'Hỏng lốp / Vá vỏ';
  final _plateController = TextEditingController(text: '51F-888.88');
  final _noteController = TextEditingController(text: 'Xe bị thủng lốp sau bên phải, cần vá gấp.');

  final List<String> _vehicles = ['Ô tô', 'Xe máy', 'Xe tải', 'Xe điện'];
  final List<String> _issues = [
    'Hỏng lốp / Vá vỏ',
    'Hết bình ắc-quy',
    'Chết máy dọc đường',
    'Hết nhiên liệu',
    'Sự cố khóa cửa',
    'Cứu hộ tai nạn'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo Yêu Cầu Cứu Hộ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A202C))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3748)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vehicle Type Selector
            const Text('1. Chọn loại phương tiện', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A202C))),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _vehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = _vehicles[index];
                  final isSelected = _selectedVehicle == vehicle;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ChoiceChip(
                      label: Text(vehicle),
                      selected: isSelected,
                      selectedColor: const Color(0xFFE53935),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF2D3748),
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: Colors.white,
                      onSelected: (selected) {
                        setState(() => _selectedVehicle = vehicle);
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Vehicle Info
            const Text('2. Thông tin xe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A202C))),
            const SizedBox(height: 12),
            TextField(
              controller: _plateController,
              decoration: InputDecoration(
                labelText: 'Biển số xe / Hãng xe',
                prefixIcon: const Icon(Icons.directions_car, color: Color(0xFF1E88E5)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // Issue Chips
            const Text('3. Mô tả sự cố gặp phải', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A202C))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _issues.map((issue) {
                final isSelected = _selectedIssue == issue;
                return ChoiceChip(
                  label: Text(issue),
                  selected: isSelected,
                  selectedColor: const Color(0xFF1E88E5),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF2D3748),
                  ),
                  backgroundColor: Colors.white,
                  onSelected: (selected) {
                    setState(() => _selectedIssue = issue);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Chi tiết thêm (tùy chọn)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // Map Preview Card
            const Text('4. Vị trí cứu hộ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A202C))),
            const SizedBox(height: 12),
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(16),
                image: const DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1524661135-423995f22d0b?w=600'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.location_pin, color: Color(0xFFE53935)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '123 Nguyễn Huệ, P. Bến Nghé, Quận 1, TP.HCM',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/providers');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
              ),
              child: const Text(
                'TÌM THỢ CỨU HỘ NGAY',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
