library dart_orm.mysql_integration_test;

import 'dart:io';

import 'package:dart_orm_adapter_mysql/dart_orm_adapter_mysql.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'test_util.dart';
import 'integration/test_integration.dart';

const String dbUserName = 'dart_orm_test';
const String dbName = 'dart_orm_test';

void setupMySql(mysqlUser) {
  void runMySql(String command) {
    run('mysql', ['-e', command, '-v', '-u', mysqlUser]);
  }

  log.info('---- MySQL Teardown -----');
  runMySql('DROP DATABASE $dbName;');
  runMySql('DROP USER \'$dbUserName\'@\'localhost\';');

  log.info('---- MySQL Setup -----');
  runMySql('CREATE DATABASE $dbName;');
  runMySql(
      'CREATE USER \'$dbUserName\'@\'localhost\' IDENTIFIED BY \'$dbUserName\';');
  runMySql('GRANT ALL ON $dbName.* TO \'$dbUserName\'@\'localhost\';');
  runMySql('FLUSH PRIVILEGES;');
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
