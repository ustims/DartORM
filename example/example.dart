import 'dart:io';

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

  String toString() {
    return 'User { id: $id, givenName: \'$givenName\', familyName: \'$familyName\' }';
  }
}

dynamic testUser() async {
  User u = new User();
  u.givenName = 'Sergey';
  u.familyName = 'Ustimenko';

  bool saveResult = await u.save();
  assert(saveResult);
  print('Saved successfully');

  // lets try simple one-row select by id
  ORM.FindOne findOne = new ORM.FindOne(User)
    // whereEquals is just a shortcut for .where(new ORM.Equals('id', 1))
    ..whereEquals('id', 1);

  User foundUser = await findOne.execute();
  assert(foundUser.id == 1);
  assert(foundUser.givenName == 'Sergey');
  print('Found user:');
  print(foundUser.toString());

  foundUser.givenName = 'yegreS';
  await foundUser.save();

  ORM.FindOne findOneModified = new ORM.FindOne(User)..whereEquals('id', 1);

  User foundModifiedUser = await findOneModified.execute();
  assert(foundModifiedUser.id == 1);
  assert(foundModifiedUser.givenName == 'yegreS');
  print('Found modified user:');
  print(foundModifiedUser.toString());

  // restore name back
  foundUser.givenName = 'Sergey';
  await foundUser.save();

  ORM.Find findMultiple = new ORM.Find(User)
    ..where(new ORM.LowerThan('id', 3).and(new ORM.Equals('givenName', 'Sergey')
        .or(new ORM.Equals('familyName', 'Ustimenko'))))
    ..orderBy('id', 'DESC')
    ..setLimit(10);

  List foundUsers = await findMultiple.execute();

  assert(foundUsers.length > 0);
  assert(foundUsers[0].givenName == 'Sergey');

  print('Found list of users:');
  print(foundUsers);
  print('\n');
}

dynamic example() async {
  // This will scan current isolate
  // for classes annotated with DBTable
  // and store sql definitions for them in memory
  ORM.AnnotationsParser.initialize();

  PostgresqlDBAdapter postgresqlAdapter = new PostgresqlDBAdapter(
      'postgres://dart_orm_test:dart_orm_test@localhost:5432/dart_orm_test');
  await postgresqlAdapter.connect();

  ORM.addAdapter('postgres', postgresqlAdapter);
  ORM.setDefaultAdapter('postgres');

  bool migrationResult = await ORM.Migrator.migrate();
  assert(migrationResult);

  print('\nTesting user model with postgresql adapter:');
  await testUser();

  MongoDBAdapter mongoAdapter = new MongoDBAdapter(
      'mongodb://dart_orm_test:dart_orm_test@127.0.0.1/dart_orm_test');
  await mongoAdapter.connect();

  ORM.addAdapter('mongo', mongoAdapter);
  ORM.setDefaultAdapter('mongo');

  migrationResult = await ORM.Migrator.migrate();
  assert(migrationResult);

  print('\nTesting user model with mongodb adapter:');
  await testUser();

  MySQLDBAdapter mysqlAdapter = new MySQLDBAdapter(
      'mysql://dart_orm_test:dart_orm_test@localhost:3306/dart_orm_test');
  await mysqlAdapter.connect();

  ORM.addAdapter('mysql', mysqlAdapter);
  ORM.setDefaultAdapter('mysql');

  migrationResult = await ORM.Migrator.migrate();
  assert(migrationResult);

  print('\nTesting user model with mysql adapter:');
  await testUser();

  exit(0);
}

void main() {
  example();
}
