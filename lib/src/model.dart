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
  Type _modelType;
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

    if (modelTable == null) {
      ClassMirror modelMirror = reflectClass(modelType);
      String modelClassName = MirrorSystem.getName(modelMirror.simpleName);

      throw new Exception(
          'Can\'t find ORM annotations for class $modelClassName');
    }

    ClassMirror modelMirror = reflectClass(modelType);

    List<dynamic> foundInstances = new List<dynamic>();

    var rows = await orm.getDefaultAdapter().select(selectSql);

    List resulRowsPromaryKeys = [];
    bool hasReferenceFields = modelTable.hasReferenceFields;

    for (Map<String, dynamic> row in rows) {
      InstanceMirror newInstance =
          modelMirror.newInstance(new Symbol(''), [], new Map());

      for (Field field in modelTable.fields) {
        var fieldValue = row[field.fieldName];

        if (field is ListJoinField) {
          fieldValue = []; // just create new list. It will be populated later.
        }

        if (field.isPrimaryKey) {
          resulRowsPromaryKeys.add(fieldValue);
        }

        newInstance.setField(field.constructedFromPropertyName, fieldValue);
      }

      foundInstances.add(newInstance.reflectee);
    }

    foundInstances = await _populate(foundInstances);

    return foundInstances;
  }

  static Future _populate(List modelsFound) async {
    if (modelsFound.length < 1) {
      return modelsFound;
    }

    Table modelTable = AnnotationsParser.getTableForInstance(modelsFound[0]);
    Field modelPrimaryKeyField = modelTable.getPrimaryKeyField();

    List modelsIds =
        new List.from(modelsFound.map((m) => orm.getPrimaryKeyValue(m)));

    for (Field field in modelTable.fields) {
      if (field is ListJoinField) {
        ListJoinField listField = field;

        if (field.joinTable is ListJoinValuesTable) {
          // When list members are simple types and are stored right inside
          // join table
          ListJoinValuesTable listTable = field.joinTable;

          Select referenceSelect = new Select(['*']);
          referenceSelect.table = listField.joinTable;
          referenceSelect.where(
              new In(listTable.primaryKeyReferenceField.fieldName, modelsIds));

          var results = await orm.getDefaultAdapter().select(referenceSelect);

          // now we have all values from reference table for all results from original select.
          // let's go through reference results and populate original results
          for (Map<String, dynamic> row in results) {
            var modelId = row[listTable.primaryKeyReferenceField.fieldName];
            var value = row[listTable.valueField.fieldName];

            for (var foundInstance in modelsFound) {
              var foundInstanceId = AnnotationsParser.getPropertyValueForField(
                  modelPrimaryKeyField, foundInstance);

              if (foundInstanceId == modelId) {
                var list = AnnotationsParser.getPropertyValueForField(
                    field, foundInstance);
                list.add(value);
              }
            }
          }
        } else if (field.joinTable is ListJoinModelsTable) {
          ListJoinModelsTable listTable = field.joinTable;

          // first - select list members ids from join table
          Select listMembersIdsSelect = new Select(['*']);
          listMembersIdsSelect.table = listField.joinTable;
          listMembersIdsSelect.where(new In(
              listTable.listHolderPrimaryKeyReference.fieldName, modelsIds));

          // raw list of list members ids. Each item in this list will have a
          // map with list holder id and list member id.
          List rawListMembersIds =
          await orm.getDefaultAdapter().select(listMembersIdsSelect);

          // Just gather all list members ids in a simple list
          List allListMemberIds = [];

          // Make a map which keys are model ids and values are lists with found
          // list members
          Map<dynamic, List> listMembersIdByModelId = {};

          rawListMembersIds.forEach((m) {
            allListMemberIds
                .add(m[listTable.listMembersPrimaryKeyReference.fieldName]);

            var modelId = m[listTable.listHolderPrimaryKeyReference.fieldName];

            if (!listMembersIdByModelId.containsKey(modelId)) {
              listMembersIdByModelId[modelId] = [];
            }

            listMembersIdByModelId[modelId]
                .add(m[listTable.listMembersPrimaryKeyReference.fieldName]);
          });

          if (allListMemberIds.length > 0) {
            // find all list members for all found models
            Find findMembers = new Find(listTable.listMembersTable.modelType);
            findMembers.where(new In(
                listTable.listMembersTable
                    .getPrimaryKeyField()
                    .fieldName,
                allListMemberIds));

            List allListMembers = await findMembers.execute();

            // now lets move found list members to models lists

            for (var foundInstance in modelsFound) {
              var foundInstanceId = AnnotationsParser.getPropertyValueForField(
                  modelPrimaryKeyField, foundInstance);

              List listMemberIdsForFoundModel = listMembersIdByModelId[foundInstanceId];
              List listMembers = new List.from(allListMembers.where((m) {
                return listMemberIdsForFoundModel.contains(
                    orm.getPrimaryKeyValue(m));
              }));

              AnnotationsParser.setPropertyValueForField(
                  field, listMembers, foundInstance);
            }
          }
        }
      }
    }

    return modelsFound;
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
