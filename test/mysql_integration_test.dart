library dart_orm.test;

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'package:dart_orm_adapter_mysql/dart_orm_adapter_mysql.dart';

import 'integration/integration_util.dart';
import 'test_util.dart';

const String dbUserName = 'dart_orm_test';
const String dbName = 'dart_orm_test';

void setupMySql(mysqlUser) {
  log.info('---- MySQL Teardown -----');
  run('mysql', ['-e', 'DROP DATABASE $dbName;', '-u', mysqlUser]);
  run('mysql',
      ['-e', 'DROP USER \'$dbUserName\'@\'localhost\';', '-u', mysqlUser]);
  run('mysql', ['-e', 'FLUSH PRIVILEGES;', '-u', mysqlUser]);

  log.info('---- MySQL Setup -----');
  run('mysql', ['-e', 'CREATE DATABASE $dbName;', '-v', '-u', 'root']);
  run('mysql', [
    '-e',
    'CREATE USER \'$dbUserName\'@\'localhost\' IDENTIFIED BY \'$dbUserName\';',
    '-v',
    '-u',
    mysqlUser
  ]);
  run('mysql', [
    '-e',
    'GRANT ALL ON $dbName.* TO \'$dbUserName\'@\'localhost\';',
    '-v',
    '-u',
    mysqlUser
  ]);
  run('mysql', ['-e', 'FLUSH PRIVILEGES;', '-v', '-u', 'root']);
}

void main() {
  var configured = false;

  setUp(() {
    if (configured) return;

    String MYSQL_USER = Platform.environment['MYSQL_USER'];

    if (MYSQL_USER == null || MYSQL_USER.isEmpty) {
      throw 'MYSQL_USER must be set in the environment';
    }

    Logger.root.level = Level.FINEST;
    Logger.root.onRecord.listen((LogRecord rec) {
      if (rec.loggerName.contains('DartORM')) {
        print(
            '[${rec.loggerName}] ${rec.level.name}: ${rec.time}: ${rec.message}');
      }
    });

    setupMySql(MYSQL_USER);

    configured = true;
  });

  MySQLDBAdapter mysqlAdapter = new MySQLDBAdapter(
      'mysql://dart_orm_test:dart_orm_test@localhost:3306/dart_orm_test');

  registerTestsForAdapter('mysql', mysqlAdapter);
}
