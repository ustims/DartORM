library dart_orm;


import 'dart:mirrors';
import 'dart:async';
import 'dart:collection';

part 'sql.dart';
part 'annotations.dart';
part 'sql_types.dart';
part 'adapter.dart';
part 'src/adapters/sql.dart';
part 'src/adapters/memory.dart';
part 'src/adapters/postgres.dart';
part 'migrator.dart';


@DBTable()
class OrmInfoTable extends Model {
  @DBField()
  int currentVersion;

  @DBField()
  String tableDefinitions;
}


class Model {
  Table _tableDefinition = null;
  static DBAdapter _sAdapter = null;

  Model() {
    _tableDefinition = AnnotationsParser.getTableForInstance(this);
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
    for (Field field in _tableDefinition.fields) {
      if (field.isPrimaryKey) {
        return field;
      }
    }
    return null;
  }

  /**
   * Returns primary key value for this instance.
   */
  dynamic getPrimaryKeyValue() {
    Field field = getPrimaryKeyField();
    if (field != null) {
      var instanceFieldValue = AnnotationsParser.getPropertyValueForField(field, this);
      return instanceFieldValue;
    }

    return null;
  }

  void setPrimaryKeyValue(dynamic value) {
    Field field = getPrimaryKeyField();
    if (field != null) {
      AnnotationsParser.setPropertyValueForField(field, value, this);
    }
  }

  /**
   * Inserts current model instance to database.
   * Primary key should be empty.
   *
   * Throws [Exception] if model instance has not-null primary key.
   */
  Future insert() async {
    var primaryKeyValue = getPrimaryKeyValue();
    if(primaryKeyValue != null){
      throw new Exception('insert() should not be called' +
        'on instances with not-null primary key value, use update() instead.');
    }

    Insert insert = new Insert(_tableDefinition);

    Symbol primaryKeyProperty = null;
    for (Field field in _tableDefinition.fields) {
      if (!field.isPrimaryKey) {
        TypedSQL valueSql = getTypedSqlFromValue(AnnotationsParser.getPropertyValueForField(field, this));
        insert.value(field.fieldName, valueSql);
      }
    }

    var newRecordId = await ormAdapter.insert(insert);

    this.setPrimaryKeyValue(newRecordId);

    return newRecordId;
  }

  /**
   * Updates this model instance data on database.
   * This model instance primary key should have a not null value.
   *
   * Throws [Exception] if this model instance is null.
   */
  Future update() async {
    var primaryKeyValue = getPrimaryKeyValue();
    if(primaryKeyValue = null){
      throw new Exception('update() should not be called' +
      'on instances with null primary key value, use insert() instead.');
    }

    Update update = new Update(_tableDefinition.tableName);

    for (Field field in _tableDefinition.fields) {
      TypedSQL valueSql = getTypedSqlFromValue(AnnotationsParser.getPropertyValueForField(field, this));

      if (field.isPrimaryKey) {
        update.where(new Equals(new RawSQL(field.fieldName), valueSql));
      }
      else {
        update.set(field.fieldName, valueSql);
      }
    }

    var updateResult = await ormAdapter.update(update);
    return updateResult;
  }

  Future<bool> save() async {
    Completer completer = new Completer();

    var primaryKeyValue = getPrimaryKeyValue();
    var operation = null;
    if (primaryKeyValue != null) {
      return this.update();
    }
    else {
      var newRecordId =  await this.insert();
      if(newRecordId == this.getPrimaryKeyValue()){
        return true;
      }
    }

    return false;
  }
}

class FindBase extends Select {
  Type _modelType;
  Table table;

  FindBase(Type this._modelType): super(['*']) {
    table = AnnotationsParser.getTableForType(_modelType);
    //table(_table.tableName);
  }

  whereEquals(String fieldName, var fieldValue) {
    for (Field field in table.fields) {
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

    for (Field field in table.fields) {
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

    Table modelTableSQL = AnnotationsParser.getTableForType(modelType);
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
