import 'package:logger/logger.dart';

class DLog {
  static final Logger _logger = Logger(
    filter: ProductionFilter(),
    printer: PrettyPrinter(
      lineLength: 99,
      methodCount: 0,
    ),
  );

  static void info(dynamic message) {
    _logger.i(message);
  }

  static void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (error is StackTrace && stackTrace == null) {
      _logger.w(message, error: null, stackTrace: error);
    } else {
      _logger.w(message, error: error, stackTrace: stackTrace);
    }
  }

  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (error is StackTrace && stackTrace == null) {
      _logger.e(message, error: null, stackTrace: error);
    } else {
      _logger.e(message, error: error, stackTrace: stackTrace);
    }
  }
}
