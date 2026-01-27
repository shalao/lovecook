import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  void log({
    required String page,
    required String action,
    required String message,
    LogLevel level = LogLevel.info,
    Object? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase();

    final buffer = StringBuffer();
    buffer.writeln('[$timestamp] [$levelStr] [$page] [$action]');
    buffer.writeln('  Message: $message');
    if (data != null) {
      buffer.writeln('  Data: $data');
    }
    if (error != null) {
      buffer.writeln('  Error: $error');
    }
    if (stackTrace != null) {
      buffer.writeln('  StackTrace: $stackTrace');
    }

    debugPrint(buffer.toString());
  }

  // 便捷方法
  void info(String page, String action, String message, {Object? data}) {
    log(
        page: page,
        action: action,
        message: message,
        level: LogLevel.info,
        data: data);
  }

  void warning(String page, String action, String message, {Object? data}) {
    log(
        page: page,
        action: action,
        message: message,
        level: LogLevel.warning,
        data: data);
  }

  void error(String page, String action, String message,
      {Object? error, StackTrace? stackTrace, Object? data}) {
    log(
        page: page,
        action: action,
        message: message,
        level: LogLevel.error,
        error: error,
        stackTrace: stackTrace,
        data: data);
  }

  void apiCall(String page, String action,
      {required String api, Object? request, Object? response, bool isError = false}) {
    log(
      page: page,
      action: action,
      message: 'API Call: $api',
      level: isError ? LogLevel.error : LogLevel.info,
      data: {'request': request, 'response': response},
    );
  }
}

// 全局实例
final logger = LogService();
