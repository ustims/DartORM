library dart_orm.migrator;

import 'dart:async';

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
      await f.execute();
      // TODO: check if existing schema in
      // tableDefinitions string is actual and run migrations
      // in dev mode or print diff in production mode
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
    // list of strings for all tables sql.
    // Every item will contain CREATE TABLE statement.
    List<String> tableDefinitions = new List<String>();

    try {
      for (Table t in ormClasses.values) {
        await adapter.createTable(t);
        // TODO: adapter should provide a way to get hash or info about current
        // schema so we can diff them
        //tableDefinitions.add(adapter.constructTableSql(t));
      }

      // all tables created, lets insert version info
      OrmInfoTable ormInfo = new OrmInfoTable()
        ..currentVersion = 0
        ..tableDefinitions = tableDefinitions.join('\n');
      return await ormInfo.save();
    } catch (err, stack) {
      log.severe('Failed to create tables.', err, stack);
      rethrow;
    }
  }
}
