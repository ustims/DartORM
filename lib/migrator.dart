import 'dart:async';
import 'package:dart_orm/orm.dart';
import 'package:dart_orm/sql.dart';
import 'package:dart_orm/annotations.dart';
import 'package:dart_orm/adapter.dart';

class OrmMigrator {
  static Future migrate() {
    Completer completer = new Completer();
    OrmDBAdapter adapter = OrmModel.ormAdapter;

    // we store database schema and its version in
    // addition table called orm_info_table
    // So the first thing we want to do is check it.
    FindOne f = new FindOne(OrmInfoTable)
      ..orderBy('currentVersion', OrderSQL.DESC)
      ..limit(1);

    f.execute()
    .then((OrmInfoTable ormInfoTable) {
      // TODO: check if existing schema in
      // tableDefinitions string is actual and run migrations
      // in dev mode or print diff in production mode
      print("yahoo");
      completer.complete(true);
    })
    .catchError((err) {
      if (adapter.parseError(err.serverMessage.code) == OrmDBAdapter.ErrTableNotExist) {
        // relation does not exists
        // create db
        createSchemasFromScratch(adapter.connection, OrmAnnotationsParser.ormClasses)
        .then((bool completeResult){
          print('All orm tables were created from scratch.');
          completer.complete(true);
        })
        .catchError((err) {
          print('Failed to create database orm tables.');
          completer.completeError(err);
        });
      }

      // its bad if we don't know what happened
      // because we miss all the ifs above, but lets notice about it.
      completer.completeError(err);
    });

    return completer.future;
  }

  static Future createSchemasFromScratch(dynamic connection,
                                         Map<String, DBTableSQL> ormClasses){
    Completer completer = new Completer();

    // here will be all futures for creating all the tables.
    List<Future> futures = new List<Future>();
    // list of strings for all tables sql. Every item will contain CREATE TABLE ...
    List<String> tableDefinitions = new List<String>();

    for (DBTableSQL t in ormClasses.values) {
      futures.add(connection.execute(t.toSql()));
      tableDefinitions.add(t.toSql());
    }

    Future.wait(futures)
    .then((allTables) {
      // all tables created, lets insert version info
      OrmInfoTable ormInfo = new OrmInfoTable();
      ormInfo.currentVersion = 0;
      ormInfo.tableDefinitions = tableDefinitions.join('\n');
      return ormInfo.save();
    })
    .then((ormInfoSaveResult) {
      completer.complete(true);
    })
    .catchError((err) {
      completer.completeError(err);
    });

    return completer.future;
  }
}