import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';
import 'request_debug_log.dart';

class SelectedRequestPhoto {
  const SelectedRequestPhoto(
      {required this.id, required this.bytes, required this.contentType});
  final String id;
  final Uint8List bytes;
  final String contentType;
  static const maxBytes = 5 * 1024 * 1024;

  static Future<SelectedRequestPhoto> fromFile(XFile file) async {
    if (await file.length() > maxBytes) {
      throw const AppFailure('Ảnh vượt quá 5 MB. Vui lòng chọn ảnh nhỏ hơn.');
    }
    final bytes = await file.readAsBytes();
    final type = detectContentType(bytes);
    if (bytes.isEmpty || bytes.length > maxBytes || type == null) {
      throw const AppFailure('Chỉ hỗ trợ ảnh JPEG, PNG hoặc WebP tối đa 5 MB.');
    }
    // Validate the image itself, not the user-controlled filename/MIME header.
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1600);
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    } catch (_) {
      throw const AppFailure('Không đọc được ảnh này. Vui lòng chọn ảnh khác.');
    }
    return SelectedRequestPhoto(
        id: SupabaseService.newClientRequestId(),
        bytes: bytes,
        contentType: type);
  }

  static String? detectContentType(Uint8List bytes) {
    bool starts(List<int> prefix) =>
        bytes.length >= prefix.length &&
        listEquals(bytes.sublist(0, prefix.length), prefix);
    if (starts([0xff, 0xd8, 0xff])) return 'image/jpeg';
    if (starts([137, 80, 78, 71, 13, 10, 26, 10])) return 'image/png';
    if (bytes.length >= 12 &&
        starts([82, 73, 70, 70]) &&
        listEquals(bytes.sublist(8, 12), [87, 69, 66, 80])) return 'image/webp';
    return null;
  }
}

class RequestPhoto {
  const RequestPhoto({required this.id, required this.url});
  final String id;
  final String url;
}

abstract interface class RequestPhotoPicker {
  Future<SelectedRequestPhoto?> pick({required bool camera});
  Future<List<SelectedRequestPhoto>> recoverLostPhotos();
}

class DeviceRequestPhotoPicker implements RequestPhotoPicker {
  const DeviceRequestPhotoPicker();

  @override
  Future<SelectedRequestPhoto?> pick({required bool camera}) async {
    try {
      final file = await ImagePicker().pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      return file == null ? null : await SelectedRequestPhoto.fromFile(file);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
          'Không mở được ảnh/camera. Hãy kiểm tra quyền hoặc chọn ảnh từ thư viện.');
    }
  }

  @override
  Future<List<SelectedRequestPhoto>> recoverLostPhotos() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return [];
    try {
      final response = await ImagePicker().retrieveLostData();
      if (response.exception != null) throw response.exception!;
      return await Future.wait(
          (response.files ?? []).take(3).map(SelectedRequestPhoto.fromFile));
    } catch (_) {
      throw const AppFailure(
          'Không khôi phục được ảnh sau khi mở camera. Vui lòng chọn lại ảnh.');
    }
  }
}

abstract interface class RequestPhotoRepository {
  Future<void> upload(String requestId, SelectedRequestPhoto photo);
  Future<List<RequestPhoto>> list(String requestId);
}

class SupabaseRequestPhotoRepository implements RequestPhotoRepository {
  const SupabaseRequestPhotoRepository({this.client});
  final SupabaseClient? client;
  static const bucket = 'rescue-request-photos';
  static const _timeout = Duration(seconds: 30);

  SupabaseClient get _client {
    if (client != null) return client!;
    if (!BackendConfiguration.isConfigured) {
      throw const AppFailure('Backend chưa được cấu hình.');
    }
    return Supabase.instance.client;
  }

  void _checkSession(SupabaseClient client, String? customer) {
    if (customer == null || client.auth.currentUser?.id != customer) {
      throw const AppFailure(
          'Phiên đăng nhập đã thay đổi. Vui lòng đăng nhập lại.',
          sessionExpired: true);
    }
  }

  @override
  Future<void> upload(String requestId, SelectedRequestPhoto photo) async {
    SupabaseClient? db;
    var step = 'photos.prepare';
    logRequestStep('photos.upload.begin');
    try {
      db = _client;
      final customer = db.auth.currentUser?.id;
      _checkSession(db, customer);
      step = 'photos.reserve';
      final row = await db
          .rpc('reserve_customer_request_photo', params: {
            'p_request_id': requestId,
            'p_photo_id': photo.id,
            'p_content_type': photo.contentType,
            'p_byte_size': photo.bytes.length,
          })
          .single()
          .timeout(_timeout);
      _checkSession(db, customer);
      if (row['uploaded_at'] != null) return;
      step = 'photos.storage.uploadBinary';
      try {
        await db.storage
            .from(bucket)
            .uploadBinary(row['storage_path'] as String, photo.bytes,
                fileOptions:
                    FileOptions(contentType: photo.contentType, upsert: false))
            .timeout(_timeout);
      } catch (error, stackTrace) {
        logRequestFailure(step, error, stackTrace, client: db);
        step = 'photos.complete_after_upload_error';
        logRequestStep(step);
        // An upload may have succeeded before its response was lost. Finalize
        // checks the actual object, so retry never overwrites or duplicates it.
        _checkSession(db, customer);
        await db
            .rpc('complete_customer_request_photo', params: {
              'p_photo_id': photo.id,
            })
            .single()
            .timeout(_timeout);
        _checkSession(db, customer);
        return;
      }
      _checkSession(db, customer);
      step = 'photos.complete';
      await db
          .rpc('complete_customer_request_photo', params: {
            'p_photo_id': photo.id,
          })
          .single()
          .timeout(_timeout);
      _checkSession(db, customer);
    } on AppFailure catch (error, stackTrace) {
      logRequestFailure(step, error, stackTrace, client: db);
      rethrow;
    } catch (error, stackTrace) {
      logRequestFailure(step, error, stackTrace, client: db);
      // Setup errors propagated directly before diagnostics were added.
      if (step == 'photos.prepare') rethrow;
      throw const AppFailure(
          'Không tải được ảnh lên máy chủ. Hãy kiểm tra mạng và thử gửi ảnh lại.');
    }
  }

  @override
  Future<List<RequestPhoto>> list(String requestId) async {
    final db = _client;
    final customer = db.auth.currentUser?.id;
    _checkSession(db, customer);
    try {
      final rows = await db
          .from('rescue_request_photos')
          .select('id, storage_path')
          .eq('request_id', requestId)
          .not('uploaded_at', 'is', null)
          .order('slot')
          .timeout(_timeout);
      final photos = <RequestPhoto>[];
      for (final row in rows) {
        _checkSession(db, customer);
        final url = await db.storage
            .from(bucket)
            .createSignedUrl(row['storage_path'] as String, 600)
            .timeout(_timeout);
        photos.add(RequestPhoto(id: row['id'] as String, url: url));
      }
      _checkSession(db, customer);
      return photos;
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure('Không tải được ảnh sự cố. Vui lòng thử lại.');
    }
  }
}
