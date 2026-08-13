class AppError implements Exception {
  final String message;
  final int? statusCode;

  AppError({required this.message, this.statusCode});

  static AppError defaultError({String? statusMessage}) {
    return AppError(message: statusMessage ?? "Đã có lỗi xảy ra");
  }

  @override
  String toString() => message;
}
