import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/backend_models.dart';

class PickedDocument {
  const PickedDocument(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;
}

class DocumentPicker {
  Future<PickedDocument?> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      allowMultiple: false,
      withData: false,
      withReadStream: true,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.size <= 0 || file.size > 10485760) {
      throw const RescuerFailure('Chọn tệp JPEG, PNG hoặc PDF tối đa 10 MB.');
    }
    final builder = BytesBuilder(copy: false);
    if (file.bytes != null) {
      builder.add(file.bytes!);
    } else if (file.readStream != null) {
      await for (final chunk in file.readStream!) {
        if (builder.length + chunk.length > 10485760) {
          throw const RescuerFailure('Tệp vượt quá 10 MB.');
        }
        builder.add(chunk);
      }
    } else {
      throw const RescuerFailure('Không đọc được tệp. Vui lòng chọn lại.');
    }
    final bytes = builder.takeBytes();
    if (bytes.length != file.size) {
      throw const RescuerFailure(
        'Tệp chưa được đọc đầy đủ. Vui lòng chọn lại.',
      );
    }
    return PickedDocument(bytes, detectDocumentMime(bytes));
  }
}

String detectDocumentMime(Uint8List bytes) {
  bool starts(List<int> magic) =>
      bytes.length >= magic.length &&
      Iterable<int>.generate(magic.length).every((i) => bytes[i] == magic[i]);
  if (starts([0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (starts([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return 'image/png';
  }
  if (starts([0x25, 0x50, 0x44, 0x46, 0x2d])) return 'application/pdf';
  throw const RescuerFailure(
    'Nội dung tệp không phải JPEG, PNG hoặc PDF hợp lệ.',
  );
}
