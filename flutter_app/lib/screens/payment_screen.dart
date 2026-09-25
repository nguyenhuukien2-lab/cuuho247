import 'package:flutter/material.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'MoMo';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh Toán Cứu Hộ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A202C))),
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
            // Success Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF43A047), size: 36),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cứu hộ hoàn thành thành công!',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 15),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Cảm ơn bạn đã sử dụng dịch vụ của ResQ247.',
                          style: TextStyle(color: Color(0xFF555555), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Cost Breakdown Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chi tiết hóa đơn dịch vụ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A202C))),
                  const SizedBox(height: 16),
                  _costRow('Phí dịch vụ vá vỏ lưu động', '100.000 đ'),
                  const SizedBox(height: 8),
                  _costRow('Phí di chuyển ban đêm', '50.000 đ'),
                  const SizedBox(height: 8),
                  _costRow('Vật tư phụ thay thế', '0 đ'),
                  const Divider(height: 24, color: Color(0xFFE2E8F0)),
                  _costRow('Tổng cộng', '150.000 đ', isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Methods
            const Text('Phương thức thanh toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A202C))),
            const SizedBox(height: 12),
            _paymentOption('MoMo', Icons.account_balance_wallet, 'Ví điện tử MoMo'),
            const SizedBox(height: 8),
            _paymentOption('VNPay', Icons.qr_code, 'Cổng thanh toán VNPay'),
            const SizedBox(height: 8),
            _paymentOption('Cash', Icons.payments, 'Tiền mặt trực tiếp cho thợ'),
            const SizedBox(height: 32),

            // Confirm Button
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thanh toán thành công! Chuyển về lịch sử.')),
                );
                Navigator.pushReplacementNamed(context, '/history');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
              ),
              child: const Text('XÁC NHẬN THANH TOÁN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _costRow(String label, String amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.between,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? const Color(0xFF1A202C) : const Color(0xFF718096),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: isTotal ? const Color(0xFFE53935) : const Color(0xFF2D3748),
          ),
        ),
      ],
    );
  }

  Widget _paymentOption(String id, IconData icon, String label) {
    final isSelected = _selectedMethod == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E88E5) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF1E88E5) : const Color(0xFF718096)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: const Color(0xFF2D3748)),
              ),
            ),
            Radio<String>(
              value: id,
              groupValue: _selectedMethod,
              activeColor: const Color(0xFF1E88E5),
              onChanged: (val) => setState(() => _selectedMethod = val!),
            ),
          ],
        ),
      ),
    );
  }
}
