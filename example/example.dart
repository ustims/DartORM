import 'dart:io';

import 'package:dart_orm/dart_orm.dart' as ORM;

import 'package:dart_orm_adapter_postgresql/dart_orm_adapter_postgresql.dart';
import 'package:dart_orm_adapter_mongodb/dart_orm_adapter_mongodb.dart';

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

  String toString(){
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

  ORM.FindOne findOneModified = new ORM.FindOne(User)
    ..whereEquals('id', 1);

  User foundModifiedUser = await findOneModified.execute();
  assert(foundModifiedUser.id == 1);
  assert(foundModifiedUser.givenName == 'yegreS');
  print('Found modified user:');
  print(foundModifiedUser.toString());

  // restore name back
  foundUser.givenName = 'Sergey';
  await foundUser.save();

  ORM.Find findMultiple = new ORM.Find(User)
    ..where(new ORM.LowerThan('id', 3)
      .and(new ORM.Equals('givenName', 'Sergey')
        .or(new ORM.Equals('familyName', 'Ustimenko'))
      )
  )
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

  String psqlUser = 'dart_orm_test_user';
  String psqlPassword = 'dart_orm_test_user';
  String psqlDBName = 'dart_orm_test';

  PostgresqlDBAdapter postgresqlAdapter = new PostgresqlDBAdapter(
    'postgres://$psqlUser:$psqlPassword@localhost:5432/$psqlDBName');
  await postgresqlAdapter.connect();

  ORM.Model.ormAdapter = postgresqlAdapter;

  bool migrationResult = await ORM.Migrator.migrate();
  assert(migrationResult);

  print('\nTesting user model with postgresql adapter:');
  await testUser();


  String mongoUser = 'dart_orm_test_user';
  String mongoPass = 'dart_orm_test_user';
  String mongoDBName = 'dart_orm_test';

  MongoDBAdapter mongoAdapter = new MongoDBAdapter(
      'mongodb://$mongoUser:$mongoPass@127.0.0.1/$mongoDBName');
  await mongoAdapter.connect();

  ORM.Model.ormAdapter = mongoAdapter;

  migrationResult = await ORM.Migrator.migrate();
  assert(migrationResult);

  print('\nTesting user model with mongodb adapter:');
  await testUser();

  exit(0);
}

void main() {
  example();
}