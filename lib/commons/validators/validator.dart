class Validator {
  static final Validator instance = Validator();

  bool isEmpty(String? data) => (data ?? "").trim().isEmpty;

  bool isValidEmail(String? email) {
    if (email == null) return false;
    final emailRegExp =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegExp.hasMatch(email.trim());
  }

  bool isValidPassword(String? password) {
    return password != null && password.length >= 6;
  }

  bool isValidPhone(String? data) => (data?.trim().length ?? 0) >= 9;
}
