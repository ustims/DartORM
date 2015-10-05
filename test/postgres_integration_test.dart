library dart_orm.postgres_integration_test;

import 'dart:io';

import 'package:dart_orm_adapter_postgresql/dart_orm_adapter_postgresql.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'test_util.dart';
import 'integration/test_integration.dart';

void setupDBs(psql_user, psql_db) {
  if (psql_user.length < 1 || psql_db.length < 1) {
    throw new Exception(
        'PSQL_USER, PSQL_DB, MYSQL_USER environment variables should be provided.');
  }

  String dbUserName = 'dart_orm_test';
  String dbName = 'dart_orm_test';

  // psql teardown
  run('psql', ['-c', 'DROP DATABASE $dbName;', '-U', psql_user, psql_db]);
  run('psql', ['-c', 'DROP ROLE $dbUserName;', '-U', psql_user, psql_db]);

  // psql setup
  log.info('---- PSQL Setup -----');
  run('psql', ['-c', 'CREATE DATABASE $dbName;', '-U', psql_user, psql_db]);
  run('psql', [
    '-c',
    'CREATE ROLE $dbUserName WITH PASSWORD \'$dbUserName\' LOGIN;',
    '-U',
    psql_user,
    psql_db
  ]);
  run('psql', [
    '-c',
    'GRANT ALL PRIVILEGES ON DATABASE $dbName TO $dbUserName;',
    '-U',
    psql_user,
    psql_db
  ]);
}

void main() {
  var configured = false;

  setUp(() {
    if (configured) return;

    String PSQL_USER = '';
    String PSQL_DB = '';

    try {
      for (String varName in Platform.environment.keys) {
        if (varName == 'PSQL_USER') {
          PSQL_USER = Platform.environment[varName];
        }
        if (varName == 'PSQL_DB') {
          PSQL_DB = Platform.environment[varName];
        }
      }
    } catch (e) {
      log.shout(e);
    }

    Logger.root.level = Level.FINEST;
    Logger.root.onRecord.listen((LogRecord rec) {
      if (rec.loggerName.contains('DartORM')) {
        print(
            '[${rec.loggerName}] ${rec.level.name}: ${rec.time}: ${rec.message}');
      }
    });

    setupDBs(PSQL_USER, PSQL_DB);

    configured = true;
  });

  PostgresqlDBAdapter postgresqlAdapter = new PostgresqlDBAdapter(
      'postgres://dart_orm_test:dart_orm_test@localhost:5432/dart_orm_test');

  registerTestsForAdapter('postgresql', postgresqlAdapter);
}
