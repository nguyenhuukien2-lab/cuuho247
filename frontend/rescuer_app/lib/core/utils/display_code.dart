String displayCode(String? code) {
  final value = code?.trim();
  if (value == null || value.isEmpty) return 'Chưa có mã';
  return value;
}
