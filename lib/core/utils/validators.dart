class Validators {
  static String? required(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null
          ? 'Vui lòng nhập $fieldName'
          : 'Trường này không được để trống';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập địa chỉ email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Email không hợp lệ (ví dụ: user@example.com)';
    }
    return null;
  }

  static String? minLength(String? value, int min, [String? fieldName]) {
    if (value == null || value.trim().length < min) {
      return '${fieldName ?? 'Giá trị'} phải có ít nhất $min ký tự';
    }
    return null;
  }

  static String? confirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng xác nhận lại mật khẩu';
    }
    if (value != originalPassword) {
      return 'Mật khẩu xác nhận không trùng khớp';
    }
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập mã OTP';
    }
    final cleaned = value.trim();
    if (cleaned.length != 6 || int.tryParse(cleaned) == null) {
      return 'Mã OTP phải gồm 6 chữ số';
    }
    return null;
  }

  static String? number(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập ${fieldName ?? 'số'}';
    }
    if (num.tryParse(value.trim()) == null) {
      return '${fieldName ?? 'Giá trị'} phải là số';
    }
    return null;
  }

  static String? nonNegativeNumber(String? value, [String? fieldName]) {
    final numError = number(value, fieldName);
    if (numError != null) return numError;
    final val = num.parse(value!.trim());
    if (val < 0) {
      return '${fieldName ?? 'Giá trị'} không được âm';
    }
    return null;
  }
}
