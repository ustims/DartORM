library dart_orm.integration_tests;

import 'package:dart_orm_adapter_postgresql/dart_orm_adapter_postgresql.dart';
import 'package:dart_orm_adapter_mongodb/dart_orm_adapter_mongodb.dart';
import 'package:dart_orm_adapter_mysql/dart_orm_adapter_mysql.dart';

import 'integration_util.dart';

void runIntegrationTests() {
  PostgresqlDBAdapter postgresqlAdapter = new PostgresqlDBAdapter(
      'postgres://dart_orm_test:dart_orm_test@localhost:5432/dart_orm_test');

  registerTestsForAdapter('postgresql', postgresqlAdapter);

  MongoDBAdapter mongoAdapter = new MongoDBAdapter(
      'mongodb://dart_orm_test:dart_orm_test@127.0.0.1/dart_orm_test');

  registerTestsForAdapter('mongodb', mongoAdapter);

  MySQLDBAdapter mysqlAdapter = new MySQLDBAdapter(
      'mysql://dart_orm_test:dart_orm_test@localhost:3306/dart_orm_test');

  registerTestsForAdapter('mysql', mysqlAdapter);
}
