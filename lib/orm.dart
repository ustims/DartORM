import 'dart:mirrors';
import 'sql.dart';
import 'dart:async';
import 'annotations.dart';
import 'sql_types.dart';


@DBTable()
class OrmInfoTable extends OrmModel {
  @DBField()
  int currentVersion;

  @DBField()
  String tableDefinitions;
}


class OrmModel {
  DBTableSQL _tableSql = null;
  static dynamic _connection = null;

  OrmModel() {
    _tableSql = DBAnnotationsParser.getDBTableSQLForInstance(this);
  }

  static void setConnection(conn) {
    _connection = conn;
  }

  static Future migrate() {
    Completer completer = new Completer();

    FindOne f = new FindOne(OrmInfoTable)
      ..orderBy('current_version', OrderSQL.DESC)
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
      if (err.serverMessage.code == '42P01') {
        // relation does not exists
        // create db
        Map<String, DBTableSQL> ormClasses = DBAnnotationsParser.ormClasses;

        List<Future> futures = new List<Future>();

        List<String> tableDefinitions = new List<String>();

        for (DBTableSQL t in ormClasses.values) {
          futures.add(_connection.execute(t.toSql()));
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
          print('ORM info saved.');
          completer.complete(true);
        })
        .catchError((err) {
          completer.completeError(err);
        });
      }

      completer.completeError('Something bad has happened');
    });

    return completer.future;
  }

  String toSql() {
    return _tableSql.toSql();
  }

  /**
   * Returns DBFieldSQL instance
   * for primary key defined in this model.
   */
  DBFieldSQL getPrimaryKeyField() {
    for (DBFieldSQL field in _tableSql.fields) {
      if (field.isPrimaryKey) {
        return field;
      }
    }
    return null;
  }

  /**
   * Returns primary key value for this instance.
   */
  getPrimaryKeyValue() {
    DBFieldSQL field = getPrimaryKeyField();
    if (field != null) {
      var instanceFieldValue = DBAnnotationsParser.getPropertyValueForField(field, this);
      return instanceFieldValue;
    }

    return null;
  }

  UpdateSQL getUpdateSQL() {
    UpdateSQL updateSql = new UpdateSQL(_tableSql.tableName);

    for (DBFieldSQL field in _tableSql.fields) {
      TypedSQL valueSql = getTypedSqlFromValue(DBAnnotationsParser.getPropertyValueForField(field, this));

      if (field.isPrimaryKey) {
        if (valueSql == null) {
          throw new Exception('Cannot save model without id.');
        }

        updateSql.where(new EqualsSQL(new RawSQL(field.fieldName), valueSql));
      }
      else {
        updateSql.set(field.fieldName, valueSql);
      }
    }

    return updateSql;
  }

  InsertSQL getInsertSQL() {
    InsertSQL insertSql = new InsertSQL(_tableSql.tableName);

    for (DBFieldSQL field in _tableSql.fields) {
      if (!field.isPrimaryKey) {
        TypedSQL valueSql = getTypedSqlFromValue(DBAnnotationsParser.getPropertyValueForField(field, this));

        insertSql.value(field.fieldName, valueSql);
      }
    }

    return insertSql;
  }

  String getCreateTableSQL() {
    return _tableSql.toSql();
  }

  String getSaveSql() {
    String sql = '';

    var primaryKeyValue = getPrimaryKeyValue();
    if (primaryKeyValue != null) {
      UpdateSQL updateSql = getUpdateSQL();
      sql = updateSql.toSql();
    }
    else {
      InsertSQL insertSql = getInsertSQL();

      sql = insertSql.toSql();
    }

    return sql;
  }

  Future save() {
    Completer completer = new Completer();

    String saveSql = getSaveSql();
    print('Save sql:');
    print(saveSql);
    _connection.execute(saveSql)
    .then((result) {
      if (result != 1) {
        throw new Exception('Failed to save model!');
      }

      completer.complete(result);
    })
    .whenComplete(() {
      //_connection.close();
    })
    .catchError((err) {
      completer.completeError(err);
    });

    return completer.future;
  }

  static Future<OrmModel> executeFindOne(Type modelType, SelectSQL sql) {
    Completer completer = new Completer();

    executeFind(modelType, sql)
    .then((List<OrmModel> foundModels) {
      completer.complete(foundModels.first);
    })
    .catchError((err) {
      completer.completeError(err);
    });

    return completer.future;
  }

  static Future<List<OrmModel>> executeFind(Type modelType, SelectSQL sql) {
    Completer completer = new Completer();

    DBTableSQL modelTableSQL = DBAnnotationsParser.getDBTableSQLForType(modelType);
    ClassMirror modelMirror = reflectClass(modelType);

    List<OrmModel> foundInstances = new List<OrmModel>();

    _connection.query(sql.toSql())
    .toList()
    .then((rows) {
      for (var row in rows) {
        int fieldNumber = 0;
        InstanceMirror newInstance = modelMirror.newInstance(new Symbol(''), [], new Map());

        for (DBFieldSQL field in modelTableSQL.fields) {
          var fieldValue = row[fieldNumber++];
          newInstance.setField(field.constructedFromPropertyName, fieldValue);
        }

        foundInstances.add(newInstance.reflectee);
      }

      completer.complete(foundInstances);
    })
    .catchError((err) {
      completer.completeError(err);
    });

    return completer.future;
  }


//  String getFindByIdSql(var id) {
//    DBFieldSQL field = getPrimaryKeyField();
//
//    SelectSQL s = new SelectSQL(['*'])
//      ..table(_tableSql.name)
//      ..where(new EqualsSQL(new RawSQL(field.name), new RawSQL(id)))
//      ..limit(1);
//
//    return s.toSql();
//  }


//  static SelectSQL getFindSQL(Type modelType) {
//    DBTableSQL table = DBAnnotationsParser.getDBTableSQLForType(modelType);
//    return new SelectSQL(['*'])
//      ..table(table.name);
//  }

//
//  static Future<List<ORMModel>> findBy(Type modelType, String fieldName, var fieldValue) {
//    SelectSQL s = getFindSQL(modelType)
//      ..where(new ConditionSQL(new RawSQL(fieldName), '=', getTypedSqlFromValue(fieldValue)));
//
//    return executeFind(modelType, s);
//  }
//
//  Future<ORMModel> findOneBy(String fieldName, var fieldValue) {
//    SelectSQL s = getFindSQL()
//      ..where(new ConditionSQL(new RawSQL(fieldName), '=', getTypedSqlFromValue(fieldValue)));
//
//    return executeFindOne(s);
//  }
}

class FindBase extends SelectSQL {
  Type _modelType;
  DBTableSQL _tableSql;

  FindBase(Type this._modelType): super(['*']) {
    _tableSql = DBAnnotationsParser.getDBTableSQLForType(_modelType);
    table(_tableSql.tableName);
  }

  whereEquals(String fieldName, var fieldValue) {
    for (DBFieldSQL field in _tableSql.fields) {
      if (fieldName == field.fieldName) {
        where(new EqualsSQL(new RawSQL(fieldName), getTypedSqlFromValue(fieldValue)));
      }
    }
  }

  void _formatCondition(ConditionSQL cond) {
    for (DBFieldSQL field in _tableSql.fields) {
      if (!(cond.firstVar is TypedSQL)
        && (field.fieldName == cond.firstVar || field.propertyName == cond.firstVar)) {
        cond.firstVar = new RawSQL(SQL.camelCaseToUnderscore(cond.firstVar));
      }
      if (!(cond.secondVar is TypedSQL)
        && (field.fieldName == cond.secondVar || field.propertyName == cond.secondVar)) {
        cond.secondVar = new RawSQL(SQL.camelCaseToUnderscore(cond.secondVar));
      }
    }
    if (cond.conditionQueue.length > 0) {
      for (ConditionSQL queuedCond in cond.conditionQueue) {
        _formatCondition(queuedCond);
      }
    }
  }

  where(ConditionSQL cond) {
    _formatCondition(cond);
    super.where(cond);
  }
}

class Find extends FindBase {
  Find(Type modelType): super(modelType);

  Future<List<OrmModel>> execute() {
    return OrmModel.executeFind(_modelType, this);
  }
}

class FindOne extends FindBase {
  FindOne(Type modelType): super(modelType);

  Future<OrmModel> execute() {
    return OrmModel.executeFindOne(_modelType, this);
  }
}
