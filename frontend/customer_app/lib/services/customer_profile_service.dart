import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class CustomerProfile {
  const CustomerProfile(
      {required this.userId,
      required this.fullName,
      required this.email,
      this.phone,
      this.accountCreatedAt});
  final String userId;
  final String fullName;
  final String? email;
  final String? phone;
  final DateTime? accountCreatedAt;
}

String? validateCustomerName(String value) {
  if (value.trim().isEmpty) return 'Vui lòng nhập họ tên.';
  if (value.trim().length > 100) return 'Họ tên tối đa 100 ký tự.';
  return null;
}

String normalizeCustomerPhone(String value) =>
    value.trim().replaceAll(RegExp(r'[\s().-]'), '');

String? validateCustomerPhone(String value) {
  final phone = normalizeCustomerPhone(value);
  if (phone.isNotEmpty && !RegExp(r'^\+?[0-9]{9,15}$').hasMatch(phone)) {
    return 'Nhập số điện thoại hợp lệ (9–15 chữ số).';
  }
  return null;
}

abstract interface class CustomerProfileRepository {
  Future<CustomerProfile> load();
  Future<CustomerProfile> save(
      {required String fullName, required String phone});
}

class SupabaseCustomerProfileRepository implements CustomerProfileRepository {
  const SupabaseCustomerProfileRepository({this.client});
  final SupabaseClient? client;
  static const timeout = Duration(seconds: 20);

  SupabaseClient get db {
    if (client == null && !BackendConfiguration.isConfigured) {
      throw const AppFailure('Backend chưa được cấu hình.');
    }
    return client ?? Supabase.instance.client;
  }

  User requireUser(SupabaseClient db) {
    final user = db.auth.currentUser;
    if (user == null) {
      throw const AppFailure('Vui lòng đăng nhập lại.', sessionExpired: true);
    }
    return user;
  }

  void checkOwner(SupabaseClient db, User user) {
    if (db.auth.currentUser?.id != user.id) {
      throw const AppFailure(
          'Phiên đăng nhập đã thay đổi. Vui lòng tải lại hồ sơ.',
          sessionExpired: true);
    }
  }

  CustomerProfile decode(User user, Map<String, dynamic> row) =>
      CustomerProfile(
        userId: user.id, fullName: row['full_name'] as String? ?? '',
        phone: row['phone'] as String?, email: user.email,
        // Account creation belongs to Auth; a recovered profile may be newer.
        accountCreatedAt: DateTime.tryParse(user.createdAt)?.toLocal(),
      );

  @override
  Future<CustomerProfile> load() async {
    final database = db;
    final user = requireUser(database);
    try {
      var row = await database
          .from('customer_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle()
          .timeout(timeout);
      checkOwner(database, user);
      if (row == null) {
        final metadata = user.userMetadata ?? {};
        // DO NOTHING on conflict: another tab/registration trigger may have
        // created the profile since SELECT. Never overwrite it with metadata.
        await database.from('customer_profiles').upsert({
          'user_id': user.id,
          'full_name':
              metadata['full_name'] is String ? metadata['full_name'] : '',
          'phone': metadata['phone'] is String ? metadata['phone'] : user.phone,
        }, onConflict: 'user_id', ignoreDuplicates: true).timeout(timeout);
        checkOwner(database, user);
        row = await database
            .from('customer_profiles')
            .select()
            .eq('user_id', user.id)
            .single()
            .timeout(timeout);
      }
      checkOwner(database, user);
      return decode(user, row);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
          'Không tải được hồ sơ. Hãy kiểm tra mạng và thử lại.');
    }
  }

  @override
  Future<CustomerProfile> save(
      {required String fullName, required String phone}) async {
    final validation =
        validateCustomerName(fullName) ?? validateCustomerPhone(phone);
    if (validation != null) throw AppFailure(validation);
    final database = db;
    final user = requireUser(database);
    final normalizedPhone = normalizeCustomerPhone(phone);
    try {
      final row = await database
          .from('customer_profiles')
          .upsert({
            'user_id': user.id,
            'full_name': fullName.trim(),
            'phone': normalizedPhone.isEmpty ? null : normalizedPhone,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'user_id')
          .select()
          .single()
          .timeout(timeout);
      checkOwner(database, user);
      return decode(user, row);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
          'Không lưu được hồ sơ. Thông tin đã nhập vẫn được giữ, hãy thử lại.');
    }
  }
}
