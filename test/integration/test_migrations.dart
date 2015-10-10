library dart_orm.test_migrations;

import 'dart:async';
import 'package:test/test.dart';

import 'package:dart_orm/dart_orm.dart' as ORM;

class ClassForMigration {
  int id;
  String text;
}

@ORM.DBTable('class_for_migration', ClassForMigration)
class DBClassForMigration {
  @ORM.DBField()
  @ORM.DBFieldPrimaryKey()
  int id;

  @ORM.DBField()
  String text;
}

Future testMigrations() async {
  ORM.Table t = ORM.AnnotationsParser.ormClasses['ClassForMigration'];

  ORM.Field newField = new ORM.Field();
  newField.fieldName = 'new_field';
  newField.isPrimaryKey = false;

  t.fields.add(newField);

  ORM.Migrator.migrate();
}
