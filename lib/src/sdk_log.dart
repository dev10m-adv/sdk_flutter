import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

const String _kRoot = 'uids_io_sdk_flutter';

/// Verbose diagnostics (flow steps). Suppressed in release builds.
void sdkLogDebug(String tag, String message) {
  if (kReleaseMode) return;
  developer.log(message, name: '$_kRoot.$tag', level: 500);
}

/// General diagnostic. Suppressed in release builds.
void sdkLogInfo(String tag, String message) {
  if (kReleaseMode) return;
  developer.log(message, name: '$_kRoot.$tag', level: 800);
}

/// Recoverable or unexpected conditions worth surfacing in all builds.
void sdkLogWarning(
  String tag,
  String message, {
  Object? error,
  StackTrace? stackTrace,
}) {
  developer.log(
    message,
    name: '$_kRoot.$tag',
    level: 900,
    error: error,
    stackTrace: stackTrace,
  );
}

/// Failures and errors. Does not log request bodies or tokens.
void sdkLogError(
  String tag,
  String message, {
  Object? error,
  StackTrace? stackTrace,
}) {
  developer.log(
    message,
    name: '$_kRoot.$tag',
    level: 1000,
    error: error,
    stackTrace: stackTrace,
  );
}

/// Safe one-line summary for [DioException] (method, URL, type, status, message).
/// Never includes request/response bodies.
String dioErrorSummary(DioException e) {
  final uri = e.requestOptions.uri;
  final method = e.requestOptions.method;
  final status = e.response?.statusCode;
  final buffer = StringBuffer()
    ..write('$method ')
    ..write(uri)
    ..write(' type=${e.type.name}');

  if (status != null) {
    buffer.write(' status=$status');
  }

  final msg = e.message;
  if (msg != null && msg.isNotEmpty) {
    buffer.write(' msg=$msg');
  }

  return buffer.toString();
}
