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
class OrmInfoTable extends Model {
  @DBField()
  int currentVersion;

  @DBField()
  String tableDefinitions;
}


class Model {
  Table _tableSql = null;
  static DBAdapter _sAdapter = null;

  Model() {
    _tableSql = AnnotationsParser.getDBTableSQLForInstance(this);
  }


  static set ormAdapter(DBAdapter adapter){
    _sAdapter = adapter;
  }
  static get ormAdapter => _sAdapter;

  /**
   * Returns DBFieldSQL instance
   * for primary key defined in this model.
   */
  Field getPrimaryKeyField() {
    for (Field field in _tableSql.fields) {
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
    Field field = getPrimaryKeyField();
    if (field != null) {
      var instanceFieldValue = AnnotationsParser.getPropertyValueForField(field, this);
      return instanceFieldValue;
    }

    return null;
  }

  Update getUpdateSQL() {
    Update updateSql = new Update(_tableSql.tableName);

    for (Field field in _tableSql.fields) {
      TypedSQL valueSql = getTypedSqlFromValue(AnnotationsParser.getPropertyValueForField(field, this));

      if (field.isPrimaryKey) {
        if (valueSql == null) {
          throw new Exception('Cannot save model without id.');
        }

        updateSql.where(new Equals(new RawSQL(field.fieldName), valueSql));
      }
      else {
        updateSql.set(field.fieldName, valueSql);
      }
    }

    return updateSql;
  }

  Insert getInsertSQL() {
    Insert insertSql = new Insert(_tableSql.tableName);

    for (Field field in _tableSql.fields) {
      if (!field.isPrimaryKey) {
        TypedSQL valueSql = getTypedSqlFromValue(AnnotationsParser.getPropertyValueForField(field, this));

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
      Update updateSql = getUpdateSQL();
      sql = updateSql.toSql();
    }
    else {
      Insert insertSql = getInsertSQL();

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

class FindBase extends Select {
  Type _modelType;
  Table _tableSql;

  FindBase(Type this._modelType): super(['*']) {
    _tableSql = AnnotationsParser.getDBTableSQLForType(_modelType);
    table(_tableSql.tableName);
  }

  whereEquals(String fieldName, var fieldValue) {
    for (Field field in _tableSql.fields) {
      if (fieldName == field.fieldName) {
        where(new Equals(new RawSQL(fieldName), getTypedSqlFromValue(fieldValue)));
      }
    }
  }

  dynamic _formatVariable(dynamic variable){
    if(variable is TypedSQL){
      return variable;
    }

    dynamic formatted = null;

    for (Field field in _tableSql.fields) {
      if(field.fieldName == variable || field.propertyName == variable) {
        formatted = new RawSQL(SQL.camelCaseToUnderscore(variable));
      }
    }

    if(formatted == null){
      formatted = variable;
    }

    return formatted;
  }

  void _formatCondition(Condition cond) {
    cond.firstVar = _formatVariable(cond.firstVar);
    cond.secondVar = _formatVariable(cond.secondVar);

    if (cond.conditionQueue.length > 0) {
      for (Condition queuedCond in cond.conditionQueue) {
        _formatCondition(queuedCond);
      }
    }
  }

  where(Condition cond) {
    _formatCondition(cond);
    super.where(cond);
  }

  orderBy(String fieldName, String order){
    super.orderBy(_formatVariable(fieldName), order);
  }

  static Future<Model> _executeFindOne(Type modelType, Select sql) {
    Completer completer = new Completer();

    _executeFind(modelType, sql)
    .then((List<Model> foundModels) {
      completer.complete(foundModels.first);
    })
    .catchError((err) {
      completer.completeError(err);
    });

    return completer.future;
  }

  static Future<List<Model>> _executeFind(Type modelType, Select selectSql) {
    Completer completer = new Completer();

    Table modelTableSQL = AnnotationsParser.getDBTableSQLForType(modelType);
    ClassMirror modelMirror = reflectClass(modelType);

    List<Model> foundInstances = new List<Model>();

    //OrmModel.ormAdapter.query(sql.toSql())
    Model.ormAdapter.query(selectSql)
    .then((rows) {
      for (var row in rows) {
        int fieldNumber = 0;
        InstanceMirror newInstance = modelMirror.newInstance(new Symbol(''), [], new Map());

        for (Field field in modelTableSQL.fields) {
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

  Future<List<Model>> execute() {
    return FindBase._executeFind(_modelType, this);
  }
}

class FindOne extends FindBase {
  FindOne(Type modelType): super(modelType);

  Future<Model> execute() {
    return FindBase._executeFindOne(_modelType, this);
  }
}
