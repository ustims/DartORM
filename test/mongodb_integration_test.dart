library dart_orm.mongodb_integration_test;

import 'dart:io';

import 'package:dart_orm_adapter_mongodb/dart_orm_adapter_mongodb.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';

import 'integration/test_integration.dart';

const String dbUserName = 'dart_orm_test';
const String dbName = 'dart_orm_test';

void setupDBs(String dbString) async {
  // mongodb teardown
  var db = new Db('mongodb://$dbString/dart_orm_test');
  await db.open();
  await db.drop();
  await db.close();
}

void main() {
  var useDocker = Platform.environment['USE_DOCKER'] == 'true';

  var dbString = useDocker ? 'mongo:27017': 'localhost:27000';

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

  MongoDBAdapter mongoAdapter = new MongoDBAdapter(
      'mongodb://$dbString/dart_orm_test');

  registerTestsForAdapter('mongodb', mongoAdapter);

  tearDownAll(() {
    mongoAdapter.close();
  });
}
