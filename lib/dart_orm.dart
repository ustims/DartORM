library dart_orm;

import 'dart:mirrors';
import 'dart:async';
import 'dart:collection';

import 'package:logging/logging.dart';

part 'src/adapter.dart';
part 'src/annotations.dart';
part 'src/migrator.dart';
part 'src/operations.dart';
part 'src/sql_types.dart';
part 'src/sql.dart';

class Model {
  Table _tableDefinition = null;
  static DBAdapter _sAdapter = null;

  Model() {
    _tableDefinition = AnnotationsParser.getTableForInstance(this);
  }

  static set ormAdapter(DBAdapter adapter) {
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
      var instanceFieldValue =
          AnnotationsParser.getPropertyValueForField(field, this);
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
    if (primaryKeyValue != null) {
      throw new Exception('insert() should not be called' +
          'on instances with not-null primary key value, use update() instead.');
    }

    Insert insert = new Insert(_tableDefinition);

    for (Field field in _tableDefinition.fields) {
      if (!field.isPrimaryKey) {
        insert.value(field.fieldName,
            AnnotationsParser.getPropertyValueForField(field, this));
      }
    }

    var newRecordId = await ormAdapter.insert(insert);
    if (this.getPrimaryKeyField() != null) {
      this.setPrimaryKeyValue(newRecordId);
    }

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
    if (primaryKeyValue == null) {
      throw new Exception('update() should not be called' +
          'on instances with null primary key value, use insert() instead.');
    }

    Update update = new Update(_tableDefinition);

    for (Field field in _tableDefinition.fields) {
      var value = AnnotationsParser.getPropertyValueForField(field, this);
      if (field.isPrimaryKey) {
        update.where(new Equals(field.fieldName, value));
      } else {
        update.set(field.fieldName, value);
      }
    }

    var updateResult = await ormAdapter.update(update);
    return updateResult;
  }

  /**
   * Deletes this model instance data on database.
   * This model instance primary key should have a not null value.
   *
   * Throws [Exception] if this model instance is null.
   */
  Future delete() async {
    var primaryKeyValue = getPrimaryKeyValue();
    if (primaryKeyValue == null) {
      throw new Exception('delete() should not be called' +
          'on instances with null primary key value.');
    }

    Delete delete = new Delete(_tableDefinition);

    Field field = getPrimaryKeyField();
    if (field != null) {
      var value = AnnotationsParser.getPropertyValueForField(field, this);
      delete.where(new Equals(field.fieldName, value));
    }

    var deleteResult = await ormAdapter.delete(delete);
    return deleteResult;
  }

  Future<bool> save() async {
    var primaryKeyValue = getPrimaryKeyValue();

    if (primaryKeyValue != null) {
      var updateResult = this.update();
      return updateResult;
    } else {
      var newRecordId = await this.insert();
      if (this.getPrimaryKeyField() != null &&
          newRecordId == this.getPrimaryKeyValue()) {
        return true;
      } else if (newRecordId == 0) {
        // newRecordId will be 0 for models without primary key
        return true;
      }
    }

    return false;
  }
}

class FindBase extends Select {
  Type _modelType;
  Table table;

  FindBase(Type this._modelType) : super(['*']) {
    table = AnnotationsParser.getTableForType(_modelType);
  }

  whereEquals(String fieldName, var fieldValue) {
    for (Field field in table.fields) {
      if (fieldName == field.fieldName) {
        where(new Equals(fieldName, fieldValue));
      }
    }
  }

  orderBy(String fieldName, String order) {
    super.orderBy(fieldName, order);
  }

  static Future<Model> _executeFindOne(Type modelType, Select sql) async {
    List<Model> foundModels = await _executeFind(modelType, sql);
    if (foundModels.length > 0) {
      return foundModels.last;
    } else {
      return null;
    }
  }

  static Future<List<Model>> _executeFind(Type modelType, Select selectSql) {
    Completer completer = new Completer();

    Table modelTable = AnnotationsParser.getTableForType(modelType);
    ClassMirror modelMirror = reflectClass(modelType);

    List<Model> foundInstances = new List<Model>();

    Model.ormAdapter.select(selectSql).then((List rows) {
      for (Map<String, dynamic> row in rows) {
        InstanceMirror newInstance =
            modelMirror.newInstance(new Symbol(''), [], new Map());

        for (Field field in modelTable.fields) {
          var fieldValue = row[field.fieldName];
          newInstance.setField(field.constructedFromPropertyName, fieldValue);
        }

        foundInstances.add(newInstance.reflectee);
      }

      completer.complete(foundInstances);
    }).catchError((e) {
      completer.completeError(e);
    });

    return completer.future;
  }
}

class Find extends FindBase {
  Find(Type modelType) : super(modelType);

  Future<List<Model>> execute() {
    return FindBase._executeFind(_modelType, this);
  }
}

class FindOne extends FindBase {
  FindOne(Type modelType) : super(modelType);

  Future<Model> execute() {
    return FindBase._executeFindOne(_modelType, this);
  }
}
