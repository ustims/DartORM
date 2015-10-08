library dart_orm.migrator;

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import 'adapter.dart';
import 'annotations.dart';
import 'model.dart';
import 'operations.dart';
import 'orm.dart';

final Logger log = new Logger('Migrator');

@DBTable()
class OrmInfoTable extends Model {
  @DBField()
  int currentVersion;

  @DBField()
  String tableDefinitions;
}

class Migrator {
  static Future<bool> migrate() async {
    DBAdapter adapter = getDefaultAdapter();

    // we store database schema and its version in
    // addition table called orm_info_table
    // So the first thing we want to do is check it.
    FindOne f = new FindOne(OrmInfoTable)
      ..orderBy('currentVersion', 'DESC')
      ..setLimit(1);

    try {
      OrmInfoTable versionInfo = await f.execute();

      List tablesSerialized = JSON.decode(versionInfo.tableDefinitions);
      List actualTables = new List();

      for (Map tableMap in tablesSerialized) {
        Table table = new Table.fromJson(tableMap);
        actualTables.add(table);
      }

      List differences = Migrator.compareSchemas(
          new List.from(AnnotationsParser.ormClasses.values), actualTables);

      log.info("Tables exists. Later here will be check for difference.");
    } on TableNotExistException {
      // relation does not exists
      // create db
      bool migrationResult = await Migrator.createSchemasFromScratch(
          adapter, AnnotationsParser.ormClasses);
      log.info('All orm tables were created from scratch.');
      return migrationResult;
    }

    return true;
  }

  static Future<bool> createSchemasFromScratch(
      DBAdapter adapter, Map<String, Table> ormClasses) async {
    List<Map> tablesSerialized = new List<Map>();

    try {
      for (Table t in ormClasses.values) {
        await adapter.createTable(t);
        tablesSerialized.add(t.toJson());
      }

      // all tables created, lets insert version info
      OrmInfoTable ormInfo = new OrmInfoTable()
        ..currentVersion = 0
        ..tableDefinitions = JSON.encode(tablesSerialized);

      return await ormInfo.save();
    } catch (err, stack) {
      log.severe('Failed to create tables.', err, stack);
      rethrow;
    }
  }

  /// Compares two lists of database tables and returns list with [AlterTable] instances.
  /// That list could be used to migrate from [existingSchema] to [actualSchema]
  static compareSchemas(List<Table> actualSchema, List<Table> existingSchema) {
    List differences = new List();

    for (Table actualTable in actualSchema) {
      bool tableExists = false;

      for (Table existingTable in existingSchema) {
        if (actualTable.tableName == existingTable.tableName) {
          tableExists = true;
          differences
              .addAll(Migrator.compareTables(actualTable, existingTable));
        }
      }

      if (!tableExists) {
        differences.add(new CreateTable(actualTable));
      }
    }

    // Reverse loop to find tables that exist on database
    // but not in actual schema. Such tables should be dropped.
    for (Table existingTable in existingSchema) {
      bool tableExists = false;

      for (Table actualTable in actualSchema) {
        if (existingTable.tableName == actualTable.tableName) {
          tableExists = true;
        }
      }

      if (!tableExists) {
        differences.add(new DropTable(existingTable));
      }
    }

    return differences;
  }

  /// Compares two tables and returns a list of [AlterTable] instances.
  /// That list could be used to migrate from [existingTable] table structure
  /// to new [actualTable] table structure.
  static compareTables(Table actualTable, Table existingTable) {
    List differences = new List();

    for (Field actualField in actualTable.fields) {
      bool fieldFound = false;

      for (Field existingField in existingTable.fields) {
        if (actualField.fieldName == existingField.fieldName) {
          fieldFound = true;
          differences
              .addAll(Migrator.compareFields(actualField, existingField));
        }
      }

      if (!fieldFound) {
        differences.add(new CreateField(actualTable, actualField));
      }
    }

    // Reverse loop to find fields that exist on existing table
    // but not in actual table. Such fields should be dropped.
    for (Field existingField in existingTable.fields) {
      bool fieldFound = false;

      for (Field actualField in actualTable.fields) {
        if (actualField.fieldName == existingField.fieldName) {
          fieldFound = true;
        }
      }

      if (!fieldFound) {
        differences.add(new DropField(existingTable, existingField));
      }
    }

    return differences;
  }

  /// Compares two table fields and returns a list of [AlterTable] instances.
  /// That list could be used to migrate from [existingField] to [actualField].
  static compareFields(Field actualField, Field existingField) {
    return [];
  }
}
