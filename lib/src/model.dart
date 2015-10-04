library models;

import 'dart:async';
import 'dart:mirrors';

import 'adapter.dart';
import 'annotations.dart';
import 'operations.dart';
import 'orm.dart' as orm;

class Model {
  Table _tableDefinition;

  Model() {
    _tableDefinition = AnnotationsParser.getTableForInstance(this);
  }

  /// Adds adapter that will be used by models.
  /// This is deprecated and will be removed in 0.2.0
  /// Use [orm.addAdapter] and [orm.setDefaultAdapter] instead.
  @deprecated
  static void set ormAdapter(DBAdapter adapter) {
    orm.addAdapter('modelAdapter', adapter);
    orm.setDefaultAdapter('modelAdapter');
  }

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
  Future insert() => orm.insert(this);

  /**
   * Updates this model instance data on database.
   * This model instance primary key should have a not null value.
   *
   * Throws [Exception] if this model instance is null.
   */
  Future update() => orm.update(this);

  /**
   * Deletes this model instance data on database.
   * This model instance primary key should have a not null value.
   *
   * Throws [Exception] if this model instance is null.
   */
  Future delete() => orm.delete(this);

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

  static Future _executeFindOne(Type modelType, Select sql) async {
    List<Model> foundModels = await _executeFind(modelType, sql);
    if (foundModels.length > 0) {
      return foundModels.last;
    } else {
      return null;
    }
  }

  static Future<List> _executeFind(Type modelType, Select selectSql) async {
    Table modelTable = AnnotationsParser.getTableForType(modelType);
    ClassMirror modelMirror = reflectClass(modelType);

    List<dynamic> foundInstances = new List<dynamic>();

    var rows = await orm.getDefaultAdapter().select(selectSql);
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
