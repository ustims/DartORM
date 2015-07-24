import 'dart:async';
import 'package:unittest/unittest.dart';


import 'package:dart_orm/dart_orm.dart' as ORM;

import 'package:dart_orm_adapter_postgresql/dart_orm_adapter_postgresql.dart';
import 'package:dart_orm_adapter_mongodb/dart_orm_adapter_mongodb.dart';
import 'package:dart_orm_adapter_mysql/dart_orm_adapter_mysql.dart';


@ORM.DBTable('users')
class User extends ORM.Model {
  @ORM.DBField()
  @ORM.DBFieldPrimaryKey()
  @ORM.DBFieldType('SERIAL')
  int id;

  @ORM.DBField()
  String givenName;

  @ORM.DBField()
  String familyName;

  @ORM.DBField()
  double weight;

  @ORM.DBField()
  DateTime created;

  String toString() {
    return 'User { id: $id, ' +
    'givenName: \'$givenName\', familyName: \'$familyName\', weight: \'$weight\' }';
  }
}

Future primaryKeyTestCase() async {
  User u = new User();
  u.givenName = 'Sergey';
  u.familyName = 'Ustimenko';
  await u.save();
  expect(u.id, 1);

  User u2 = new User();
  u2.givenName = 'Sergey2';
  u2.familyName = 'Ustimenko2';
  await u2.save();
  expect(u2.id, 2);

  User u3 = new User();
  u3.givenName = 'Sergey3';
  u3.familyName = 'Ustimenko3';
  await u3.save();
  expect(u3.id, 3);

  User u4 = new User();
  u4.givenName = 'Sergey4';
  u4.familyName = 'Ustimenko4';
  await u4.save();
  expect(u4.id, 4);
}

Future saveTestCase() async {
  // first lets try to create a new user and save it to db
  User u = new User();
  u.givenName = 'Sergey';
  u.familyName = 'Ustimenko';
  u.weight = 123.456;
  await u.save();

  // that should give him an 'id', so lets use that id to find him
  ORM.FindOne f = new ORM.FindOne(User)
    ..whereEquals('id', u.id);
  User savedFound = await f.execute();

  expect(u.id, savedFound.id);
  expect(u.givenName, savedFound.givenName);
  expect(u.familyName, savedFound.familyName);
  expect(u.weight, savedFound.weight);

  // now lets change some properties for both instances
  savedFound.givenName = 'yegreS';
  savedFound.familyName = 'oknemitsU';
  savedFound.weight = 234.567;

  await savedFound.save();

  // now lets find him again to ensure that all information
  // was stored to the database
  ORM.FindOne findModified = new ORM.FindOne(User)
    ..whereEquals('id', u.id);
  User foundModified = await findModified.execute();
  expect(foundModified.id, u.id);
  expect(foundModified.givenName, 'yegreS');
  expect(foundModified.familyName, 'oknemitsU');
  expect(foundModified.weight, 234.567);
}

Future findOneTestCase() async {
  ORM.FindOne f = new ORM.FindOne(User)
    ..whereEquals('givenName', 'Sergey');

  User found = await f.execute();
  expect(found.givenName, 'Sergey');
}

Future findMultipleTestCase() async {
  ORM.Find f = new ORM.Find(User)
    ..where(new ORM.LowerThan('id', 4))
    ..orderBy('id', 'DESC')
    ..setLimit(2);

  List results = await f.execute();
  expect(results.length, 2);
  expect(results[0].id, 3);
  expect(results[1].id, 2);
  //expect(results[2].id, 1); -- this should not exist since we set limit to 2
}

Future dateTimeTestCase() async {
  User u = new User();
  u.givenName = 'Sergey';
  DateTime now = new DateTime.now();
  u.created = now;

  await u.save();

  ORM.FindOne f = new ORM.FindOne(User)
    ..whereEquals('id', u.id);
  User saved = await f.execute();

  int difference = saved.created.difference(now).inMilliseconds;
  // TODO: investigate why db drivers or dart makes this
  expect(difference < 1000, true);

  User futureUser = new User();
  futureUser.givenName = 'Bilbo';
  futureUser.created = new DateTime(2500, DateTime.JANUARY, 1, 12, 12, 12);
  await futureUser.save();

  // TODO: timezones need to be tested.

  ORM.Find findLowerThan = new ORM.Find(User)
    ..where(new ORM.LowerThan('created',
      new DateTime(now.year, now.month, now.day, now.hour, now.minute + 5)));

  List foundLowerThan = await findLowerThan.execute();
  expect(foundLowerThan.length, 1);

  ORM.Find findBiggerThan = new ORM.Find(User)
    ..where(new ORM.BiggerThan('created',
      new DateTime(now.year, now.month, now.day, now.hour, now.minute + 5)));

  List foundBiggerThan = await findBiggerThan.execute();
  expect(foundBiggerThan.length, 1);
}

class IntegrationTests {
  static allTests() {
    test('PrimaryKey', () async {
      await primaryKeyTestCase();
    });
    test('FindOne', () async {
      await findOneTestCase();
    });
    test('FindMultiple', () async {
      await findMultipleTestCase();
    });
    test('Save', () async {
      await saveTestCase();
    });
    test('DateTime', () async {
      await dateTimeTestCase();
    });
  }

  static execute() async {
    // This will scan current isolate
    // for classes annotated with DBTable
    // and store sql definitions for them in memory
    ORM.AnnotationsParser.initialize();

    PostgresqlDBAdapter postgresqlAdapter = new PostgresqlDBAdapter(
        'postgres://dart_orm_test:dart_orm_test@localhost:5432/dart_orm_test');
    await postgresqlAdapter.connect();
    ORM.Model.ormAdapter = postgresqlAdapter;
    bool migrationResult = await ORM.Migrator.migrate();
    assert(migrationResult);

    MongoDBAdapter mongoAdapter = new MongoDBAdapter(
        'mongodb://dart_orm_test:dart_orm_test@127.0.0.1/dart_orm_test');
    await mongoAdapter.connect();
    ORM.Model.ormAdapter = mongoAdapter;
    migrationResult = await ORM.Migrator.migrate();
    assert(migrationResult);

    MySQLDBAdapter mysqlAdapter = new MySQLDBAdapter(
        'mysql://dart_orm_test:dart_orm_test@localhost:3306/dart_orm_test'
    );
    await mysqlAdapter.connect();
    ORM.Model.ormAdapter = mysqlAdapter;
    migrationResult = await ORM.Migrator.migrate();
    assert(migrationResult);

    group('Integration tests:', () {
      group('PostgreSQL ->', () {
        setUp(() {
          ORM.Model.ormAdapter = postgresqlAdapter;
        });

        allTests();
      });

      group('MySQL ->', () {
        setUp(() {
          ORM.Model.ormAdapter = mysqlAdapter;
        });

        allTests();
      });

      group('MongoDB ->', () {
        setUp(() {
          ORM.Model.ormAdapter = mongoAdapter;
        });

        allTests();
      });
    });
  }
}
