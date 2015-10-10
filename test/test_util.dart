library dart_orm.test_util;

import 'dart:io';

import 'package:logging/logging.dart';

final Logger log = new Logger('[DartORM.test_util]');

String run(String executable, List<String> arguments) {
  var result = Process.runSync(executable, arguments);
  if (result.stderr.length > 0) {
    log.severe('$executable:' + result.stderr);
  }
  if (result.stdout.length > 0) {
    log.finest(result.stdout);
  }
  return result.stdout;
}
