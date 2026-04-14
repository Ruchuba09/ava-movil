// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

var logger = Logger(
  filter: DevelopmentFilter(),
  level: Level.all,
  output: ConsoleOutput(),
  printer: PrettyPrinter(
    methodCount: 2,
    noBoxingByDefault: true,
    dateTimeFormat: DateTimeFormat.none,
    stackTraceBeginIndex: 1,
  ),
);

void printDev(var message) {
  if (kDebugMode) {
    if (message is String) {
      try {
        var jsonObject = jsonDecode(message);
        var jsonString = const JsonEncoder.withIndent('  ').convert(jsonObject);

        if (jsonString.length > 800) {
          _logLargeMessage(jsonString);
        } else {
          logger.d(jsonString);
        }
      } catch (e) {
        if (message.length > 800) {
          _logLargeMessage(message);
        } else {
          logger.d(message);
        }
      }
    } else if (message is Map || message is Iterable) {
      var jsonString = const JsonEncoder.withIndent('  ').convert(message);
      if (jsonString.length > 800) {
        _logLargeMessage(jsonString);
      } else {
        logger.d(jsonString);
      }
    } else {
      logger.d(message);
    }
  }
}

void _logLargeMessage(String message) {
  const int chunkSize = 800;
  for (int i = 0; i < message.length; i += chunkSize) {
    logger.d(message.substring(
        i, i + chunkSize > message.length ? message.length : i + chunkSize));
  }
}
