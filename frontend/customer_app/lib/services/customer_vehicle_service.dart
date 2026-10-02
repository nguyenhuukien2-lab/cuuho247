import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/app_controller.dart';
import 'supabase_service.dart';

class CustomerVehicle {
  const CustomerVehicle(
      {required this.id,
      required this.customerId,
      required this.kind,
      required this.brandModel,
      this.licensePlate = '',
      this.color = '',
      this.notes = ''});
  final String id;
  final String customerId;
  final VehicleKind kind;
  final String brandModel;
  final String licensePlate;
  final String color;
  final String notes;
  String get label =>
      '${kind.label} • ${brandModel.isEmpty ? 'Chưa có hãng/hiệu' : brandModel}${licensePlate.isEmpty ? '' : ' • $licensePlate'}';
  factory CustomerVehicle.fromJson(Map<String, dynamic> row) => CustomerVehicle(
        id: row['id'] as String,
        customerId: row['customer_id'] as String,
        kind: VehicleKind.values.firstWhere((kind) => kind.name == row['kind'],
            orElse: () => VehicleKind.other),
        brandModel: row['display_name'] as String? ?? '',
        licensePlate: row['license_plate'] as String? ?? '',
        color: row['color'] as String? ?? '',
        notes: row['notes'] as String? ?? '',
      );
}

abstract interface class CustomerVehicleRepository {
  Future<List<CustomerVehicle>> list();
  Future<CustomerVehicle> save(
      {String? id,
      required VehicleKind kind,
      required String brandModel,
      required String licensePlate,
      required String color,
      required String notes});
  Future<void> delete(String id);
}

class SupabaseCustomerVehicleRepository implements CustomerVehicleRepository {
  const SupabaseCustomerVehicleRepository({this.client});
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
  Future<List<CustomerVehicle>> list() async {
    final database = db;
    final customer = owner(database);
    try {
      final rows = await database
          .from('customer_vehicles')
          .select()
          .eq('customer_id', customer)
          .order('created_at', ascending: false)
          .order('id', ascending: true)
          .timeout(timeout);
      check(database, customer);
      return rows.map(CustomerVehicle.fromJson).toList(growable: false);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure('Không tải được danh sách xe. Vui lòng thử lại.');
    }
  }

  @override
  Future<CustomerVehicle> save(
      {String? id,
      required VehicleKind kind,
      required String brandModel,
      required String licensePlate,
      required String color,
      required String notes}) async {
    if (brandModel.trim().isEmpty ||
        brandModel.trim().length > 100 ||
        licensePlate.trim().length > 30 ||
        color.trim().length > 50 ||
        notes.trim().length > 1000) {
      throw const AppFailure(
          'Kiểm tra hãng/hiệu xe và độ dài thông tin đã nhập.');
    }
    final database = db;
    final customer = owner(database);
    final body = <String, dynamic>{
      'kind': kind.name,
      'display_name': brandModel.trim(),
      'license_plate': licensePlate.trim().isEmpty ? null : licensePlate.trim(),
      'color': color.trim().isEmpty ? null : color.trim(),
      'notes': notes.trim().isEmpty ? null : notes.trim()
    };
    try {
      final Map<String, dynamic> row;
      if (id == null) {
        row = await database
            .from('customer_vehicles')
            .insert({...body, 'customer_id': customer})
            .select()
            .single()
            .timeout(timeout);
      } else {
        row = await database
            .from('customer_vehicles')
            .update(body)
            .eq('id', id)
            .eq('customer_id', customer)
            .select()
            .single()
            .timeout(timeout);
      }
      check(database, customer);
      return CustomerVehicle.fromJson(row);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
          'Không lưu được xe. Thông tin đã nhập vẫn được giữ, hãy thử lại.');
    }
  }

  @override
  Future<void> delete(String id) async {
    final database = db;
    final customer = owner(database);
    try {
      final rows = await database
          .from('customer_vehicles')
          .delete()
          .eq('id', id)
          .eq('customer_id', customer)
          .select('id')
          .timeout(timeout);
      check(database, customer);
      if (rows.isEmpty)
        throw const AppFailure(
            'Xe không còn tồn tại hoặc bạn không có quyền xóa. Hãy tải lại danh sách.');
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure('Không xóa được xe. Vui lòng thử lại.');
    }
  }
}
