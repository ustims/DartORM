library dart_orm.mysql_integration_test;

import 'dart:io';

import 'package:dart_orm_adapter_mysql/dart_orm_adapter_mysql.dart';
import 'package:logging/logging.dart';
import 'package:sqljocky5/sqljocky.dart';
import 'package:test/test.dart';

import 'integration/test_integration.dart';

const String dbUserName = 'dart_orm_test';
const String dbName = 'dart_orm_test';

void setupMySql(String dbString) async {
  var dbStringParts = dbString.split(':');
  var pool = new ConnectionPool(
      host: dbStringParts[0], port: int.parse(dbStringParts[1]),
      user: 'dart_orm_test', password: 'dart_orm_test',
      db: 'dart_orm_test', max: 5);

  var rows = await pool.query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'dart_orm_test'");
  await for(var row in rows) {
    await pool.query('DROP TABLE IF EXISTS ${row[0]} CASCADE');
  }
}

void main() {
  var useDocker = Platform.environment['USE_DOCKER'] == 'true';

  var dbString = useDocker ? 'mysql:3306': 'localhost:3000';

  setUpAll(() async {
    Logger.root.level = Level.FINEST;
    Logger.root.onRecord.listen((LogRecord rec) {
      if (rec.loggerName.contains('DartORM')) {
        print(
            '[${rec.loggerName}] ${rec.level.name}: ${rec.time}: ${rec.message}');
      }
    });

    await setupMySql(dbString);
  });

  MySQLDBAdapter mysqlAdapter = new MySQLDBAdapter(
      'mysql://dart_orm_test:dart_orm_test@$dbString/dart_orm_test');

  registerTestsForAdapter('mysql', mysqlAdapter);

  tearDownAll(() {
    mysqlAdapter.close();
  });
}
