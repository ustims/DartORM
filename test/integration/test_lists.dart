library dart_orm.test_basic_integration;

import 'dart:async';

import 'package:dart_orm/dart_orm.dart' as ORM;
import 'package:test/test.dart';

@ORM.DBTable()
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

Future stringListTestCase() async {
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

Future intListTestCase() async {
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

Future boolListTestCase() async {
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

  expect(users.length, 2,
      reason: 'there should be only two users with bool arrays');
  expect(users[0].bools.length, 1,
      reason: 'first user bool array should have only one value');
  expect(users[0].bools[0], true,
      reason: 'first user bool array should contain "true"');

  expect(users[1].bools[0], true,
      reason: 'second user bool array should contain "true" as first element');
  expect(users[1].bools[1], false,
      reason: 'second user bool array should contain "false" as second element');

  await u.delete();
  await u2.delete();
}

Future updateListTestCase() async {
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
  expect(foundUpdated.emails.length, 2,
      reason: 'User should have two emails after update');
  expect(foundUpdated.emails[1], 'test2@test.com');

  await u.delete();
  await foundUpdated.delete();
}

@ORM.DBTable()
class Gadget extends ORM.Model {
  @ORM.DBField()
  @ORM.DBFieldPrimaryKey()
  int id;

  @ORM.DBField()
  String name;

  @ORM.DBField()
  DateTime bought;
}

@ORM.DBTable()
class UserWithGadgets extends ORM.Model {
  @ORM.DBField()
  @ORM.DBFieldPrimaryKey()
  int id;

  @ORM.DBField()
  String name;

  @ORM.DBField()
  List<Gadget> gadgets = [];

  @ORM.DBField()
  List<Gadget> wishlist = [];
}

/// Tests lists of ORM models
Future modelListTestCase() async {
  UserWithGadgets u = new UserWithGadgets();
  u.name = 'Sergey';
  await u.save();

  ORM.FindOne f = new ORM.FindOne(UserWithGadgets)
  ..whereEquals('name', 'Sergey');

  UserWithGadgets found = await f.execute();

  expect(found.gadgets.length, 0);

  u.gadgets.add(new Gadget()..name = 'Macbook'..bought = new DateTime(2014));
  u.gadgets.add(new Gadget()..name = 'Macbook2'..bought = new DateTime(2012));
  u.gadgets.add(new Gadget()..name = 'PC'..bought = new DateTime(2010));
  await u.save();

  f = new ORM.FindOne(UserWithGadgets)
  ..whereEquals('name', 'Sergey');

  found = await f.execute();
  expect(found.gadgets.length, 3);
  expect(found.gadgets[0].name, 'Macbook');

  UserWithGadgets u2 = new UserWithGadgets();
  u2.name = 'Kate';
  u2.gadgets.add(new Gadget()..name = 'Nokia');
  u2.gadgets.add(new Gadget()..name = 'iPhone');
  u2.gadgets.add(new Gadget()..name = 'ChromeBook');

  await u2.save();

  ORM.FindOne findKate = new ORM.FindOne(UserWithGadgets)
  ..whereEquals('name', 'Kate');

  UserWithGadgets kate = await findKate.execute();

  expect(kate.gadgets.length, 3);
  expect(kate.gadgets[1].name, 'iPhone');

  kate.gadgets.removeAt(0);
  await kate.save();

  ORM.FindOne findKateWithoutNokia = new ORM.FindOne(UserWithGadgets);
  UserWithGadgets kateWithoutNokia = await findKateWithoutNokia.execute();

  expect(kateWithoutNokia.gadgets.length, 2);
  expect(kateWithoutNokia.gadgets[0].name, 'iPhone');


  // not lets try two properties with same Gadget
  UserWithGadgets u3 = new UserWithGadgets();
  u3.gadgets.add(new Gadget()..name = 'ps4');
  await u3.save();
  u3.wishlist.addAll(u3.gadgets);
  await u3.save();

  ORM.FindOne f3 = new ORM.FindOne(UserWithGadgets)
  ..whereEquals('id', u3.id);

  UserWithGadgets u3Found = await f3.execute();
  expect(u3Found.gadgets.length, 1);
  expect(u3Found.wishlist.length, 1);

  expect(u3Found.gadgets[0].id, u3Found.wishlist[0].id);
}

registerListsIntegrationTests() {
  test('String arrays', stringListTestCase);
  test('Int arrays', intListTestCase);
  test('Bool arrays', boolListTestCase);
  test('update arrays', updateListTestCase);
  test('model lists', modelListTestCase );
}