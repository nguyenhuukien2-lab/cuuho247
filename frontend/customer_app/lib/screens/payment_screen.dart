import 'package:flutter/material.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String selectedMethod = 'momo';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  const Text('Thanh toán dịch vụ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1A1A1A))),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status & Request Code Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF1565C0), size: 20),
                          const SizedBox(width: 8),
                          const Text('Đã cứu hộ thành công', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A))),
                          const SizedBox(width: 6),
                          const Text('• 20:45', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFFBE4DC), borderRadius: BorderRadius.circular(100)),
                            child: const Text('#RQ-8839', style: TextStyle(color: Color(0xFFC1121F), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cost Breakdown Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CostRow(label: 'Vá lốp lưu động', amount: '150.000đ'),
                          const SizedBox(height: 12),
                          _CostRow(label: 'Phụ tùng vá nấm', amount: '50.000đ'),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Row(
                                children: [
                                  Icon(Icons.local_offer_outlined, color: Color(0xFFC1121F), size: 16),
                                  SizedBox(width: 6),
                                  Text('Giảm giá thành viên', style: TextStyle(fontSize: 13, color: Color(0xFFC1121F), fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Text('-30.000đ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFC1121F))),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(color: Color(0xFFEDEDED), height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('Tổng thanh toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A1A))),
                              Text('170.000đ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFC1121F))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Payment Method Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('Phương thức thanh toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A1A))),
                              Row(
                                children: [
                                  Icon(Icons.lock_outline, color: Color(0xFF6B7280), size: 13),
                                  SizedBox(width: 4),
                                  Text('PCI-DSS', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          _PaymentMethodItem(
                            iconBg: const Color(0xFFD81B60),
                            icon: Icons.account_balance_wallet,
                            title: 'Ví MoMo',
                            badge: 'Hoàn 5%',
                            isSelected: selectedMethod == 'momo',
                            onTap: () => setState(() => selectedMethod = 'momo'),
                          ),
                          const SizedBox(height: 8),

                          _PaymentMethodItem(
                            iconBg: const Color(0xFF1565C0),
                            icon: Icons.qr_code_2,
                            title: 'Cổng VNPay - QR',
                            isSelected: selectedMethod == 'vnpay',
                            onTap: () => setState(() => selectedMethod = 'vnpay'),
                          ),
                          const SizedBox(height: 8),

                          _PaymentMethodItem(
                            iconBg: const Color(0xFF374151),
                            icon: Icons.credit_card,
                            title: 'Thẻ ATM / Visa / Mastercard',
                            isSelected: selectedMethod == 'card',
                            onTap: () => setState(() => selectedMethod = 'card'),
                          ),
                          const SizedBox(height: 8),

                          _PaymentMethodItem(
                            iconBg: const Color(0xFF1E8E3E),
                            icon: Icons.payments,
                            title: 'Tiền mặt',
                            isSelected: selectedMethod == 'cash',
                            onTap: () => setState(() => selectedMethod = 'cash'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/history'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC1121F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.lock_outline, size: 18),
                          SizedBox(width: 8),
                          Text('Xác nhận thanh toán 170.000đ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.verified_user, color: Color(0xFF1565C0), size: 14),
                      SizedBox(width: 6),
                      Text('Bảo hành cứu hộ 30 ngày trên toàn quốc', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  final String label;
  final String amount;

  const _CostRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A))),
      ],
    );
  }
}

class _PaymentMethodItem extends StatelessWidget {
  final Color iconBg;
  final IconData icon;
  final String title;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodItem({
    required this.iconBg,
    required this.icon,
    required this.title,
    this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F1FB) : const Color(0xFFF7F7FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? const Color(0xFF1565C0) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A))),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFBE4DC), borderRadius: BorderRadius.circular(100)),
                      child: Text(badge!, style: const TextStyle(color: Color(0xFFC1121F), fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF1565C0) : const Color(0xFF9CA3AF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
