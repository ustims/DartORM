library models;

import 'dart:async';
import 'dart:mirrors';
import 'dart:collection';

import 'adapter.dart';
import 'annotations.dart';
import 'operations.dart';
import 'orm.dart' as orm;

class Model {
  Table _tableDefinition;
  static DBAdapter _sAdapter;

  Model() {
    _tableDefinition = AnnotationsParser.getTableForInstance(this);
  }

  static void set ormAdapter(DBAdapter adapter) {
    _sAdapter = adapter;
  }

  static DBAdapter get ormAdapter => _sAdapter;

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
  Future insert() {
    return orm.insert(this);
  }

  /**
   * Updates this model instance data on database.
   * This model instance primary key should have a not null value.
   *
   * Throws [Exception] if this model instance is null.
   */
  Future update() {
    return orm.update(this);
  }

  /**
   * Deletes this model instance data on database.
   * This model instance primary key should have a not null value.
   *
   * Throws [Exception] if this model instance is null.
   */
  Future delete() async {
    return orm.delete(this);
  }

  Future<bool> save() async {
    var primaryKeyValue = this.getPrimaryKeyValue();

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
  final Type _modelType;
  final Table table;

  FindBase(Type modelType)
      : this._modelType = modelType,
        this.table = AnnotationsParser.getTableForType(modelType),
        super(['*']);

  whereEquals(String fieldName, dynamic fieldValue) {
    for (Field field in table.fields) {
      if (fieldName == field.fieldName) {
        where(new Equals(fieldName, fieldValue));
      }
    }
  }

  static Future<dynamic> _executeFindOne(Type modelType, Select sql) async {
    List<Model> foundModels = await _executeFind(modelType, sql);
    if (foundModels.length > 0) {
      return foundModels.last;
    } else {
      return null;
    }
  }

  static Future<List<dynamic>> _executeFind(
      Type modelType, Select selectSql) async {
    Table modelTable = AnnotationsParser.getTableForType(modelType);
    ClassMirror modelMirror = reflectClass(modelType);

    List<dynamic> foundInstances = new List<dynamic>();

    var rows = await Model.ormAdapter.select(selectSql);
    for (Map<String, dynamic> row in rows) {
      InstanceMirror newInstance =
          modelMirror.newInstance(new Symbol(''), [], new Map());

      for (Field field in modelTable.fields) {
        var fieldValue = row[field.fieldName];
        newInstance.setField(field.constructedFromPropertyName, fieldValue);
      }

      foundInstances.add(newInstance.reflectee);
    }

    return foundInstances;
  }
}

class Find extends FindBase {
  Find(Type modelType) : super(modelType);

  Future<List<dynamic>> execute() => FindBase._executeFind(_modelType, this);
}

class FindOne extends FindBase {
  FindOne(Type modelType) : super(modelType);

  Future<dynamic> execute() => FindBase._executeFindOne(_modelType, this);
}
