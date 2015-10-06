library dart_orm.mongodb_integration_test;

import 'package:dart_orm_adapter_mongodb/dart_orm_adapter_mongodb.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'test_util.dart';
import 'integration/test_integration.dart';

const String dbUserName = 'dart_orm_test';
const String dbName = 'dart_orm_test';

void setupDBs() {
  // mongodb teardown
  run('mongo', [
    '$dbName',
    '--eval',
    """
  db.runCommand( { dropAllUsersFromDatabase: 1, writeConcern: { w: "majority" } } );
  db.dropDatabase();
  """
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

    Logger.root.level = Level.FINEST;
    Logger.root.onRecord.listen((LogRecord rec) {
      if (rec.loggerName.contains('DartORM')) {
        print(
            '[${rec.loggerName}] ${rec.level.name}: ${rec.time}: ${rec.message}');
      }
    });

    setupDBs();

    configured = true;
  });

  MongoDBAdapter mongoAdapter = new MongoDBAdapter(
      'mongodb://dart_orm_test:dart_orm_test@127.0.0.1/dart_orm_test');

  registerTestsForAdapter('mongodb', mongoAdapter);
}
