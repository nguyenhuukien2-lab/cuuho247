import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class CustomerRequestReview {
  const CustomerRequestReview(
      {required this.id,
      required this.requestId,
      required this.customerId,
      required this.rating,
      this.comment,
      required this.createdAt,
      required this.updatedAt});
  final String id, requestId, customerId;
  final int rating;
  final String? comment;
  final DateTime createdAt, updatedAt;
  factory CustomerRequestReview.fromJson(Map<String, dynamic> row) =>
      CustomerRequestReview(
          id: row['id'] as String,
          requestId: row['request_id'] as String,
          customerId: row['customer_id'] as String,
          rating: row['rating'] as int,
          comment: row['comment'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
          updatedAt: DateTime.parse(row['updated_at'] as String));
}

abstract interface class CustomerRequestReviewRepository {
  Future<CustomerRequestReview?> load(String requestId);
  Future<CustomerRequestReview> submit(String requestId,
      {required int rating, String? comment});
}

class SupabaseCustomerRequestReviewRepository
    implements CustomerRequestReviewRepository {
  const SupabaseCustomerRequestReviewRepository({this.client});
  final SupabaseClient? client;
  static const timeout = Duration(seconds: 20);
  SupabaseClient get db {
    if (client == null && !BackendConfiguration.isConfigured)
      throw const AppFailure('Backend chưa được cấu hình.');
    return client ?? Supabase.instance.client;
  }

  String owner(SupabaseClient database) {
    final id = database.auth.currentUser?.id;
    if (id == null)
      throw const AppFailure('Vui lòng đăng nhập lại.', sessionExpired: true);
    return id;
  }

  void check(SupabaseClient database, String customer) {
    if (database.auth.currentUser?.id != customer)
      throw const AppFailure('Phiên đăng nhập đã thay đổi.',
          sessionExpired: true);
  }

  @override
  Future<CustomerRequestReview?> load(String requestId) async {
    final database = db;
    final customer = owner(database);
    try {
      final row = await database
          .from('customer_request_reviews')
          .select()
          .eq('request_id', requestId)
          .eq('customer_id', customer)
          .maybeSingle()
          .timeout(timeout);
      check(database, customer);
      return row == null ? null : CustomerRequestReview.fromJson(row);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure('Không tải được đánh giá. Vui lòng thử lại.');
    }
  }

  @override
  Future<CustomerRequestReview> submit(String requestId,
      {required int rating, String? comment}) async {
    if (rating < 1 || rating > 5 || (comment?.length ?? 0) > 2000)
      throw const AppFailure(
          'Chọn từ 1 đến 5 sao; nhận xét tối đa 2000 ký tự.');
    final database = db;
    final customer = owner(database);
    try {
      final row = await database.rpc('submit_customer_request_review', params: {
        'p_request_id': requestId,
        'p_rating': rating,
        'p_comment':
            comment == null || comment.trim().isEmpty ? null : comment.trim(),
      }).timeout(timeout);
      check(database, customer);
      final result =
          CustomerRequestReview.fromJson(Map<String, dynamic>.from(row as Map));
      if (result.customerId != customer || result.requestId != requestId)
        throw const AppFailure('Đánh giá trả về không khớp yêu cầu.');
      return result;
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
          'Không gửi được đánh giá. Dữ liệu vẫn được giữ, vui lòng thử lại.');
    }
  }
}
