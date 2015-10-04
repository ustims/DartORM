library dart_orm.test;

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'integration/integration_tests.dart';
import 'test_util.dart';

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

  // mongodb teardown
  run('mongo', [
    '$dbName',
    '--eval',
    """
  db.runCommand( { dropAllUsersFromDatabase: 1, writeConcern: { w: "majority" } } );
  db.dropDatabase();
  """
  ]);

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

  log.info('---- MongoDB Setup -----');
  // mongodb setup
  run('mongo', [
    '$dbName',
    '--eval',
    """
  if (db.version().toString().indexOf('2.4') > -1) {
      db.addUser(
          {
              user: "$dbUserName",
              pwd: "$dbUserName",
              roles: ["readWrite"]
          }
      );
  } else {
      db.createUser(
          {
              user: "$dbUserName",
              pwd: "$dbUserName",
              roles: [{role: "userAdmin", db: "$dbName"}]
          }
      );
  }
  """
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

  runIntegrationTests();
}
