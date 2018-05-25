library dart_orm.postgres_integration_test;

import 'dart:async';
import 'dart:io';

import 'package:dart_orm_adapter_postgresql/dart_orm_adapter_postgresql.dart';
import 'package:logging/logging.dart';
import 'package:postgresql/postgresql.dart';
import 'package:test/test.dart';

import 'integration/test_integration.dart';

Future setupDBs(String dbString) async {
  var connection = await connect("postgres://dart_orm_test:dart_orm_test@$dbString/dart_orm_test");
  var rows = connection.query("select tablename from pg_tables WHERE schemaname = 'public'");
  await for (var row in rows) {
    await connection.execute('drop table if exists ${row[0]} cascade');
  }
}

void main() {
  var useDocker = Platform.environment['USE_DOCKER'] == 'true';

  var dbString = useDocker ? 'postgres:5432': 'localhost:5000';

  setUpAll(() async {
    Logger.root.level = Level.FINEST;
    Logger.root.onRecord.listen((LogRecord rec) {
      if (rec.loggerName.contains('DartORM')) {
        print(
            '[${rec.loggerName}] ${rec.level.name}: ${rec.time}: ${rec.message}');
      }
    });

    await setupDBs(dbString);
  });

  PostgresqlDBAdapter postgresqlAdapter = new PostgresqlDBAdapter(
      'postgres://dart_orm_test:dart_orm_test@$dbString/dart_orm_test');

  registerTestsForAdapter('postgresql', postgresqlAdapter);

  tearDownAll(() {
    postgresqlAdapter.close();
  });
}
