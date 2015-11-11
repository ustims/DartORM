library dart_orm.test_basic_integration;

import 'dart:async';

import 'package:dart_orm/dart_orm.dart' as ORM;
import 'package:test/test.dart';

@ORM.DBTable()
class Address extends ORM.Model {
  @ORM.DBField()
  @ORM.DBFieldPrimaryKey()
  int id;

  @ORM.DBField()
  String address;
}

@ORM.DBTable('users_arrays')
class UserArrays extends ORM.Model {
  @ORM.DBField()
  @ORM.DBFieldPrimaryKey()
  @ORM.DBFieldType('SERIAL')
  int id;

  @ORM.DBField()
  String name;

  @ORM.DBField()
  List<String> emails = [];

  @ORM.DBField()
  List<int> ints = [];

  @ORM.DBField()
  List<bool> bools = [];

  String toString() => "User { id: $id, "
      "givenName: '$name' }";
}

Future stringArraysTestCase() async {
  UserArrays u = new UserArrays()
    ..name = 'Sergey'
    ..emails.add('test@test.com')
    ..emails.add('test1@test.com');

  await u.save();

  UserArrays u2 = new UserArrays()
    ..name = 'Ekaterina'
    ..emails.add('kitty@test.com')
    ..emails.add('ekaterina@test.com')
    ..emails.add('ekaterina123@test.com');

  await u2.save();

  UserArrays u3 = new UserArrays()
    ..name = 'Alexander'
    ..emails.add('alexander@test.com')
    ..emails.add('sasha@test.com')
    ..emails.add('alex@test.com');

  await u3.save();

  ORM.FindOne f = new ORM.FindOne(UserArrays)
    ..whereEquals('name', 'Sergey');

  UserArrays foundUser = await f.execute();

  expect(foundUser, isNotNull);
  expect(foundUser.name, 'Sergey');
  expect(foundUser.emails.length, 2);
  expect(foundUser.emails[0], 'test@test.com');

  ORM.Find findAll = new ORM.Find(UserArrays);

  List<UserArrays> allUsersWithArrays = await findAll.execute();
  expect(allUsersWithArrays.length, 3);

  await u.delete();
  await u2.delete();
  await u3.delete();
}

Future intArraysTestCase() async {
  UserArrays u = new UserArrays();
  u.name = 'TestIntArrays';
  u.ints = [1, 2, 3];

  await u.save();

  UserArrays u2 = new UserArrays();
  u2.name = 'TestIntArrays';
  u2.ints = [1000, 2000, 3000, 4000, 5000];

  await u2.save();

  ORM.Find f = new ORM.Find(UserArrays)
  ..whereEquals('name', 'TestIntArrays');

  List<UserArrays> users = await f.execute();

  expect(users.length, 2);
  expect(users[0].ints[0], 1);

  await u.delete();
  await u2.delete();
}

Future boolArraysTestCase() async {
  UserArrays u = new UserArrays();
  u.name = 'TestBoolArrays';
  u.bools = [true];

  await u.save();

  UserArrays u2 = new UserArrays();
  u2.name = 'TestBoolArrays';
  u2.bools = [true, false, true, true];

  await u2.save();

  ORM.Find f = new ORM.Find(UserArrays)
    ..whereEquals('name', 'TestBoolArrays');

  List<UserArrays> users = await f.execute();

  expect(users.length, 2, reason: 'there should be only two users with bool arrays');
  expect(users[0].bools.length, 1, reason: 'first user bool array should have only one value');
  expect(users[0].bools[0], true, reason: 'first user bool array should contain "true"');

  expect(users[1].bools[0], true, reason: 'second user bool array should contain "true" as first element');
  expect(users[1].bools[1], false, reason: 'second user bool array should contain "false" as second element');

  await u.delete();
  await u2.delete();
}

Future updateArraysTestCase() async {
  UserArrays u = new UserArrays();
  u.name = 'TestUpdate';
  u.emails = ['test@test.com'];

  await u.save();

  ORM.FindOne f = new ORM.FindOne(UserArrays)
  ..whereEquals('name', 'TestUpdate');

  UserArrays found = await f.execute();
  expect(found.emails.length, 1, reason: 'User should have only one email');
  expect(found.emails[0], 'test@test.com');

  found.emails.add('test2@test.com');

  await found.save();

  ORM.FindOne findUpdated = new ORM.FindOne(UserArrays)
  ..whereEquals('name', 'TestUpdate');

  UserArrays foundUpdated = await findUpdated.execute();
  expect(foundUpdated.emails.length, 2, reason: 'User should have two emails after update');
  expect(foundUpdated.emails[1], 'test2@test.com');

  await u.delete();
  await foundUpdated.delete();
}

registerArraysIntegrationTests() {
  test('String arrays', stringArraysTestCase);
  test('Int arrays', intArraysTestCase);
  test('Bool arrays', boolArraysTestCase);
  test('update arrays', updateArraysTestCase);
}