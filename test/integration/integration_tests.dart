library dart_orm.integration_tests;

import 'dart:async';
import 'package:unittest/unittest.dart';

import 'package:dart_orm/dart_orm.dart' as ORM;

import 'package:dart_orm_adapter_postgresql/dart_orm_adapter_postgresql.dart';
import 'package:dart_orm_adapter_mongodb/dart_orm_adapter_mongodb.dart';
import 'package:dart_orm_adapter_mysql/dart_orm_adapter_mysql.dart';

import 'test_definitions.dart';

Future runIntegrationTests() async {
  // This will scan current isolate
  // for classes annotated with DBTable
  // and store sql definitions for them in memory
  ORM.AnnotationsParser.initialize();

  PostgresqlDBAdapter postgresqlAdapter = new PostgresqlDBAdapter(
      'postgres://dart_orm_test:dart_orm_test@localhost:5432/dart_orm_test');
  await postgresqlAdapter.connect();

  ORM.addAdapter('postgresql', postgresqlAdapter);
  ORM.setDefaultAdapter('postgresql');

  bool migrationResult = await ORM.Migrator.migrate();
  assert(migrationResult);

  MongoDBAdapter mongoAdapter = new MongoDBAdapter(
      'mongodb://dart_orm_test:dart_orm_test@127.0.0.1/dart_orm_test');
  await mongoAdapter.connect();

  ORM.addAdapter('mongodb', mongoAdapter);
  ORM.setDefaultAdapter('mongodb');

  migrationResult = await ORM.Migrator.migrate();
  assert(migrationResult);

  MySQLDBAdapter mysqlAdapter = new MySQLDBAdapter(
      'mysql://dart_orm_test:dart_orm_test@localhost:3306/dart_orm_test');
  await mysqlAdapter.connect();

  ORM.addAdapter('mysql', mysqlAdapter);
  ORM.setDefaultAdapter('mysql');

  migrationResult = await ORM.Migrator.migrate();
  assert(migrationResult);

  group('Integration tests:', () {
    group('PostgreSQL ->', () {
      setUp(() {
        // Set default adapter before running tests so all operations
        // will be made on postres adapter
        ORM.setDefaultAdapter('postgresql');
      });

      allTests();
    });

    group('MySQL ->', () {
      setUp(() {
        // Set default adapter before running tests so all operations
        // will be made on mysql adapter
        ORM.setDefaultAdapter('mysql');
      });

      allTests();
    });

    group('MongoDB ->', () {
      setUp(() {
        // Set default adapter before running tests so all operations
        // will be made on mongo adapter
        ORM.setDefaultAdapter('mongodb');
      });

      allTests();
    });
  });
}
