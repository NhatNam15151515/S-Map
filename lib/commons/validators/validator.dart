class Validator {
  static final Validator instance = Validator();

  // Basic Auth & Form Validators
  bool isEmpty(String? data) => (data ?? "").trim().isEmpty;

  bool isValidEmail(String? email) {
    if (email == null) return false;
    final emailRegExp =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegExp.hasMatch(email.trim());
  }

  bool isValidPassword(String? password) =>
      password != null && password.length >= 6;

  bool isValidPhone(String? data) => (data?.trim().length ?? 0) >= 9;

  // 🗺️ Search & Map Specific Validators
  bool isValidSearchQuery(String? query) {
    if (query == null) return false;
    return query.trim().length >= 2;
  }

  /// Kiểm tra chuỗi có phải định dạng tọa độ "lat, lng" (ví dụ: "10.762622, 106.660172")
  bool isCoordinates(String? query) {
    if (query == null || query.trim().isEmpty) return false;
    final coordRegExp = RegExp(
      r'^\s*[-+]?([1-8]?\d(\.\d+)?|90(\.0+)?)\s*[, ]\s*[-+]?(180(\.0+)?|((1[0-7]\d)|([1-9]?\d))(\.\d+)?)\s*$',
    );
    return coordRegExp.hasMatch(query.trim());
  }

  /// Kiểm tra có phải URL Google Maps / Map share link
  bool isMapUrl(String? query) {
    if (query == null || query.trim().isEmpty) return false;
    final mapUrlRegExp = RegExp(
      r'^(https?:\/\/)?(www\.)?(maps\.google\.[a-z.]+|google\.[a-z.]+\/maps|maps\.app\.goo\.gl|goo\.gl\/maps)($|[\/?#].*)',
      caseSensitive: false,
    );
    return mapUrlRegExp.hasMatch(query.trim());
  }

  /// Kiểm tra chuỗi có chứa ký tự tiếng Việt có dấu hay không
  bool hasDiacritics(String? query) {
    if (query == null || query.isEmpty) return false;
    final vietnamesePattern = RegExp(
      r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
      r'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ]',
    );
    return vietnamesePattern.hasMatch(query);
  }
}
