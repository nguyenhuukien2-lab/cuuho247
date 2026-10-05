String? partnerEmailError(String? value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Nhập email hợp lệ';

String? partnerNameError(String? value) =>
    (value?.trim().length ?? 0) >= 1 && (value?.trim().length ?? 0) <= 150
    ? null
    : 'Nhập họ tên từ 1–150 ký tự';

String? partnerPhoneError(String? value) =>
    RegExp(r'^\+?[0-9]{8,15}$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Nhập 8–15 chữ số, có thể bắt đầu bằng +';

String? partnerPasswordError(String? value) =>
    (value?.length ?? 0) >= 8 && value!.trim().isNotEmpty
    ? null
    : 'Mật khẩu cần ít nhất 8 ký tự';
