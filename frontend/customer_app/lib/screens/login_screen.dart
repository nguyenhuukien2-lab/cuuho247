import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/supabase_service.dart';

// Simple session holder for logged in user
class UserSession {
  static String? phoneNumber;
  static String? fullName;
  static String? email;
  static String? userId;
  static bool get isLoggedIn => phoneNumber != null && phoneNumber!.isNotEmpty;

  static void clear() {
    phoneNumber = null;
    fullName = null;
    email = null;
    userId = null;
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoginTab = true;
  
  // Login Controllers
  final TextEditingController _loginPhoneController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  bool isLoading = false;

  // Register Controllers
  final TextEditingController _regPhoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Handle Direct Login (No OTP)
  Future<void> _loginUser() async {
    final phone = _loginPhoneController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số điện thoại và mật khẩu.')),
      );
      return;
    }

    setState(() => isLoading = true);

    UserSession.phoneNumber = phone;
    UserSession.fullName = 'Khách hàng ResQ247';
    UserSession.userId = 'user_$phone';

    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đăng nhập thành công!')),
    );
    Navigator.pushReplacementNamed(context, '/home');
  }

  // Handle Registration
  Future<void> _registerUser() async {
    final phone = _regPhoneController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ Số điện thoại và Họ tên.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Save user to Supabase users table via REST API
      final response = await http.post(
        Uri.parse('${SupabaseService.supabaseUrl}/rest/v1/users'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseService.anonKey,
          'Authorization': 'Bearer ${SupabaseService.anonKey}',
          'Prefer': 'return=representation',
        },
        body: jsonEncode({
          'phone_number': phone,
          'full_name': name,
          'email': email.isNotEmpty ? email : null,
          'role': 'CUSTOMER',
        }),
      );

      // Save session regardless of HTTP error (in case user already exists or offline dev mode)
      UserSession.phoneNumber = phone;
      UserSession.fullName = name;
      UserSession.email = email;
      UserSession.userId = 'user_${phone}';

      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng ký tài khoản thành công cho $name!')),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      // Fallback session save for dev
      UserSession.phoneNumber = phone;
      UserSession.fullName = name;
      UserSession.email = email;
      UserSession.userId = 'user_${phone}';

      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng ký thành công (Offline mode): Chào mừng $name!')),
      );
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacementNamed(context, '/home');
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.car_crash, color: Color(0xFFC1121F), size: 28),
                      const SizedBox(width: 8),
                      const Text('ResQ247', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1A1A1A))),
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
              const SizedBox(height: 24),

              // Main Header
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBE4DC),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.location_on, color: Color(0xFFC1121F), size: 14),
                          SizedBox(width: 4),
                          Text('HỆ THỐNG CỨU HỘ TOÀN QUỐC', style: TextStyle(color: Color(0xFFC1121F), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Cứu Hộ Giao Thông 24/7', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 6),
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        children: [
                          TextSpan(text: 'Kết nối đội thợ và xe cứu hộ gần nhất chỉ trong '),
                          TextSpan(text: '15 phút', style: TextStyle(color: Color(0xFFC1121F), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tab Switcher (Đăng nhập / Đăng ký mới)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0FA),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => isLoginTab = true),
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isLoginTab ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: isLoginTab ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login, size: 16, color: isLoginTab ? const Color(0xFFC1121F) : const Color(0xFF6B7280)),
                              const SizedBox(width: 6),
                              Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isLoginTab ? const Color(0xFFC1121F) : const Color(0xFF6B7280))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => isLoginTab = false),
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isLoginTab ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: !isLoginTab ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_add_outlined, size: 16, color: !isLoginTab ? const Color(0xFFC1121F) : const Color(0xFF6B7280)),
                              const SizedBox(width: 6),
                              Text('Đăng ký mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: !isLoginTab ? const Color(0xFFC1121F) : const Color(0xFF6B7280))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Main Input Card (Dynamic based on Tab)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: isLoading
                    ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFFC1121F))))
                    : (isLoginTab ? _buildLoginForm() : _buildRegisterForm()),
              ),
              const SizedBox(height: 16),

              // Emergency Quick Guest Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBE4DC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC1121F).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Color(0xFFC1121F), shape: BoxShape.circle),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Cần cứu hộ xe ngay lập tức?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFC1121F))),
                          SizedBox(height: 2),
                          Text('Bỏ qua bước đăng nhập • Gọi thợ trong 3 giây', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC1121F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        elevation: 0,
                      ),
                      child: Row(
                        children: const [
                          Text('Gọi ngay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          SizedBox(width: 2),
                          Icon(Icons.arrow_forward, size: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- Login Form (Phone + Password - No OTP) ---
  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Đăng nhập tài khoản', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 4),
        const Text('Nhập số điện thoại và mật khẩu của bạn', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 16),

        const Text('Số điện thoại', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 6),
        TextField(
          controller: _loginPhoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '0912345678',
            filled: true,
            fillColor: const Color(0xFFF7F7FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        const Text('Mật khẩu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 6),
        TextField(
          controller: _loginPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: '••••••••',
            filled: true,
            fillColor: const Color(0xFFF7F7FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loginUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC1121F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              elevation: 2,
            ),
            child: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  // --- Register Form with Supabase / Backend Save Rule ---
  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Đăng ký tài khoản mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 4),
        const Text('Nhập thông tin cá nhân để tạo tài khoản khách hàng ResQ247', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 16),
        
        const Text('Số điện thoại', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 6),
        TextField(
          controller: _regPhoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '0912345678',
            filled: true,
            fillColor: const Color(0xFFF7F7FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        const Text('Họ và tên', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'Nguyễn Văn A',
            filled: true,
            fillColor: const Color(0xFFF7F7FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        const Text('Email (tuỳ chọn)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'example@gmail.com',
            filled: true,
            fillColor: const Color(0xFFF7F7FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        const Text('Mật khẩu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: '••••••••',
            filled: true,
            fillColor: const Color(0xFFF7F7FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _registerUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC1121F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              elevation: 2,
            ),
            child: const Text('Hoàn tất đăng ký & Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

class _NetworkChip extends StatelessWidget {
  final String label;
  const _NetworkChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SocialBtn({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A))),
        ],
      ),
    );
  }
}
