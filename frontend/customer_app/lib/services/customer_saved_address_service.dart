import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class CustomerSavedAddress {
  const CustomerSavedAddress(
      {required this.id,
      required this.customerId,
      required this.label,
      required this.address,
      this.latitude,
      this.longitude,
      this.notes,
      this.isDefault = false});
  final String id, customerId, label, address;
  final double? latitude, longitude;
  final String? notes;
  final bool isDefault;
  factory CustomerSavedAddress.fromJson(Map<String, dynamic> row) =>
      CustomerSavedAddress(
          id: row['id'] as String,
          customerId: row['customer_id'] as String,
          label: row['label'] as String,
          address: row['address'] as String,
          latitude: (row['latitude'] as num?)?.toDouble(),
          longitude: (row['longitude'] as num?)?.toDouble(),
          notes: row['notes'] as String?,
          isDefault: row['is_default'] as bool? ?? false);
}

abstract interface class CustomerSavedAddressRepository {
  Future<List<CustomerSavedAddress>> list();
  Future<CustomerSavedAddress> save(
      {String? id,
      required String label,
      required String address,
      double? latitude,
      double? longitude,
      String? notes,
      bool isDefault = false});
  Future<void> delete(String id);
}

class SupabaseCustomerSavedAddressRepository
    implements CustomerSavedAddressRepository {
  const SupabaseCustomerSavedAddressRepository({this.client});
  final SupabaseClient? client;
  static const timeout = Duration(seconds: 20);
  SupabaseClient get db {
    if (client == null && !BackendConfiguration.isConfigured) {
      throw const AppFailure('Backend chưa được cấu hình.');
    }
    return client ?? Supabase.instance.client;
  }

  String owner(SupabaseClient db) {
    final id = db.auth.currentUser?.id;
    if (id == null)
      throw const AppFailure('Vui lòng đăng nhập lại.', sessionExpired: true);
    return id;
  }

  void check(SupabaseClient db, String id) {
    if (db.auth.currentUser?.id != id) {
      throw const AppFailure('Phiên đăng nhập đã thay đổi.',
          sessionExpired: true);
    }
  }

  @override
  Future<List<CustomerSavedAddress>> list() async {
    final database = db;
    final customer = owner(database);
    try {
      final rows = await database
          .from('customer_saved_addresses')
          .select()
          .eq('customer_id', customer)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false)
          .order('id', ascending: true)
          .timeout(timeout);
      check(database, customer);
      return rows.map(CustomerSavedAddress.fromJson).toList(growable: false);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
          'Không tải được danh sách địa chỉ. Vui lòng thử lại.');
    }
  }

  @override
  Future<CustomerSavedAddress> save(
      {String? id,
      required String label,
      required String address,
      double? latitude,
      double? longitude,
      String? notes,
      bool isDefault = false}) async {
    if (!['Nhà', 'Công ty', 'Trường học', 'Khác'].contains(label) ||
        address.trim().isEmpty ||
        address.trim().length > 1000 ||
        (notes?.trim().length ?? 0) > 1000 ||
        (latitude == null) != (longitude == null) ||
        (latitude != null &&
            (!latitude.isFinite || latitude < -90 || latitude > 90)) ||
        (longitude != null &&
            (!longitude.isFinite || longitude < -180 || longitude > 180))) {
      throw const AppFailure('Kiểm tra địa chỉ và tọa độ đã nhập.');
    }
    final database = db;
    final customer = owner(database);
    final body = <String, dynamic>{
      'label': label,
      'address': address.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
      'is_default': isDefault,
    };
    try {
      final Map<String, dynamic> row;
      if (id == null) {
        row = await database
            .from('customer_saved_addresses')
            .insert({...body, 'customer_id': customer})
            .select()
            .single()
            .timeout(timeout);
      } else {
        row = await database
            .from('customer_saved_addresses')
            .update(body)
            .eq('id', id)
            .eq('customer_id', customer)
            .select()
            .single()
            .timeout(timeout);
      }
      check(database, customer);
      return CustomerSavedAddress.fromJson(row);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
          'Không lưu được địa chỉ. Thông tin đã nhập vẫn được giữ, hãy thử lại.');
    }
  }

  @override
  Future<void> delete(String id) async {
    final database = db;
    final customer = owner(database);
    try {
      final rows = await database
          .from('customer_saved_addresses')
          .delete()
          .eq('id', id)
          .eq('customer_id', customer)
          .select('id')
          .timeout(timeout);
      check(database, customer);
      if (rows.isEmpty)
        throw const AppFailure(
            'Địa chỉ không còn tồn tại hoặc bạn không có quyền xóa. Hãy tải lại danh sách.');
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure('Không xóa được địa chỉ. Vui lòng thử lại.');
    }
  }
}
