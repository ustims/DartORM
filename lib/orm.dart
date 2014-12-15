library dart_orm;


import 'dart:mirrors';
import 'dart:async';
import 'dart:collection';

part 'sql.dart';
part 'annotations.dart';
part 'sql_types.dart';
part 'adapter.dart';
part 'adapter_sql.dart';
part 'adapter_memory.dart';
part 'adapter_postgres.dart';
part 'migrator.dart';


@DBTable()
class OrmInfoTable extends OrmModel {
  @DBField()
  int currentVersion;

  @DBField()
  String tableDefinitions;
}


class OrmModel {
  DBTableSQL _tableSql = null;
  static OrmDBAdapter _sAdapter = null;

  OrmModel() {
    _tableSql = OrmAnnotationsParser.getDBTableSQLForInstance(this);
  }


  static set ormAdapter(OrmDBAdapter adapter){
    _sAdapter = adapter;
  }
  static get ormAdapter => _sAdapter;

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
      var instanceFieldValue = OrmAnnotationsParser.getPropertyValueForField(field, this);
      return instanceFieldValue;
    }

    return null;
  }

  UpdateSQL getUpdateSQL() {
    UpdateSQL updateSql = new UpdateSQL(_tableSql.tableName);

    for (DBFieldSQL field in _tableSql.fields) {
      TypedSQL valueSql = getTypedSqlFromValue(OrmAnnotationsParser.getPropertyValueForField(field, this));

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
        TypedSQL valueSql = getTypedSqlFromValue(OrmAnnotationsParser.getPropertyValueForField(field, this));

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

    var primaryKeyValue = getPrimaryKeyValue();
    var operation = null;
    if (primaryKeyValue != null) {
      operation = getUpdateSQL();
    }
    else {
      operation = getInsertSQL();
    }

    ormAdapter.execute(operation)
    .then((result) {
      if (result != 1) {
        completer.completeError('Failed to save model!');
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
}

class FindBase extends SelectSQL {
  Type _modelType;
  DBTableSQL _tableSql;

  FindBase(Type this._modelType): super(['*']) {
    _tableSql = OrmAnnotationsParser.getDBTableSQLForType(_modelType);
    table(_tableSql.tableName);
  }

  whereEquals(String fieldName, var fieldValue) {
    for (DBFieldSQL field in _tableSql.fields) {
      if (fieldName == field.fieldName) {
        where(new EqualsSQL(new RawSQL(fieldName), getTypedSqlFromValue(fieldValue)));
      }
    }
  }

  dynamic _formatVariable(dynamic variable){
    if(variable is TypedSQL){
      return variable;
    }

    dynamic formatted = null;

    for (DBFieldSQL field in _tableSql.fields) {
      if(field.fieldName == variable || field.propertyName == variable) {
        formatted = new RawSQL(SQL.camelCaseToUnderscore(variable));
      }
    }

    if(formatted == null){
      formatted = variable;
    }

    return formatted;
  }

  void _formatCondition(ConditionSQL cond) {
    cond.firstVar = _formatVariable(cond.firstVar);
    cond.secondVar = _formatVariable(cond.secondVar);

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

  orderBy(String fieldName, String order){
    super.orderBy(_formatVariable(fieldName), order);
  }

  static Future<OrmModel> _executeFindOne(Type modelType, SelectSQL sql) {
    Completer completer = new Completer();

    _executeFind(modelType, sql)
    .then((List<OrmModel> foundModels) {
      completer.complete(foundModels.first);
    })
    .catchError((err) {
      completer.completeError(err);
    });

    return completer.future;
  }

  static Future<List<OrmModel>> _executeFind(Type modelType, SelectSQL selectSql) {
    Completer completer = new Completer();

    DBTableSQL modelTableSQL = OrmAnnotationsParser.getDBTableSQLForType(modelType);
    ClassMirror modelMirror = reflectClass(modelType);

    List<OrmModel> foundInstances = new List<OrmModel>();

    //OrmModel.ormAdapter.query(sql.toSql())
    OrmModel.ormAdapter.query(selectSql)
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
}

class Find extends FindBase {
  Find(Type modelType): super(modelType);

  Future<List<OrmModel>> execute() {
    return FindBase._executeFind(_modelType, this);
  }
}

class FindOne extends FindBase {
  FindOne(Type modelType): super(modelType);

  Future<OrmModel> execute() {
    return FindBase._executeFindOne(_modelType, this);
  }
}
