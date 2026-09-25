import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController(text: '0912345678');
  final _passwordController = TextEditingController(text: 'password123');
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Emergency Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF9A9A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935), size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'CỨU HỘ KHẨN CẤP 24/7',
                            style: TextStyle(
                              color: Color(0xFFC62828),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Hỗ trợ kéo xe, vá vỏ, kích bình mọi lúc mọi nơi.',
                            style: TextStyle(color: Color(0xFF555555), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // App Logo / Title
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_shipping_rounded, size: 56, color: Color(0xFFE53935)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'CỨU HỘ 247',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A202C),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ResQ247 - Đồng hành mọi nẻo đường',
                      style: TextStyle(fontSize: 14, color: Color(0xFF718096)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Form Inputs
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Số điện thoại / Email',
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF1E88E5)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1E88E5)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Quên mật khẩu?', style: TextStyle(color: Color(0xFF1E88E5))),
                ),
              ),
              const SizedBox(height: 24),

              // Login Button
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/home');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: const Text(
                  'ĐĂNG NHẬP',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 24),

              // Divider
              Row(
                children: const [
                  Expanded(child: Divider(color: Color(0xFFCBD5E0))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Hoặc đăng nhập với', style: TextStyle(color: Color(0xFF718096), fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: Color(0xFFCBD5E0))),
                ],
              ),
              const SizedBox(height: 24),

              // Social Logins
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialButton(Icons.g_mobiledata, 'Google', () => Navigator.pushReplacementNamed(context, '/home')),
                  const SizedBox(width: 16),
                  _socialButton(Icons.apple, 'Apple', () => Navigator.pushReplacementNamed(context, '/home')),
                  const SizedBox(width: 16),
                  _socialButton(Icons.facebook, 'Facebook', () => Navigator.pushReplacementNamed(context, '/home')),
                ],
              ),
              const SizedBox(height: 24),

              // Register prompt
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Chưa có tài khoản? ', style: TextStyle(color: Color(0xFF718096))),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chức năng đăng ký đang phát triển')),
                      );
                    },
                    child: const Text(
                      'Đăng ký ngay',
                      style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: const Color(0xFF2D3748)),
      label: Text(label, style: const TextStyle(color: Color(0xFF2D3748))),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }
}
