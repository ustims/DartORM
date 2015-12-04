/// This library contains all common methods for orm like insert/update/delete.
/// It's responsible for storing list of available adapters.
library dart_orm.orm;

import 'dart:async';
import 'dart:collection';

import 'adapter.dart';
import 'annotations.dart';
import 'operations.dart';

/// List of all available adapters.
final LinkedHashMap<String, DBAdapter> _adapters =
    new LinkedHashMap<String, DBAdapter>();

String _defaultAdapter = null;

/// Adds database adapter that could be used by orm.
void addAdapter(String adapterName, DBAdapter adapter) {
  if (_adapters.containsKey(adapterName)) {
    throw new Exception('Adapter $adapterName already exists.');
  }

  _adapters[adapterName] = adapter;
}

/// Set default adapter that will be used for all models.
/// Throws exception if there are no adapters configured.
void setDefaultAdapter(String adapterName) {
  if (!_adapters.containsKey(adapterName)) {
    throw new Exception('Adapter $adapterName does not exists.');
  }

  _defaultAdapter = adapterName;
}

/// Returns default adapter
/// Throws exception if there are no adapters configured.
DBAdapter getDefaultAdapter() {
  if (_adapters.length == 0) {
    throw new Exception(
        'ORM has no adapters. Add one with addAdapter(adapterName, adapter)');
  }

  return _adapters[_defaultAdapter];
}

/// Returns primary key value for [model] instance.
/// [model] could be any object which class is annotated with DB* annotations.
dynamic getPrimaryKeyValue(dynamic model) {
  Table table = AnnotationsParser.getTableForInstance(model);

  if (table == null) {
    throw new Exception(
        'Provided class instance does not have DBTable annotation.');
  }

  Field field = table.getPrimaryKeyField();
  if (field != null) {
    var instanceFieldValue =
        AnnotationsParser.getPropertyValueForField(field, model);
    return instanceFieldValue;
  }

  return null;
}

/// Allows to set primary key [value] for [model] instance.
void setPrimaryKeyValue(dynamic model, dynamic value) {
  Table table = AnnotationsParser.getTableForInstance(model);

  if (table == null) {
    throw new Exception(
        'Provided class instance does not have DBTable annotation.');
  }

  Field field = table.getPrimaryKeyField();
  if (field != null) {
    AnnotationsParser.setPropertyValueForField(field, value, model);
  } else {
    throw new Exception(
        'Provided class instance does not have DBFieldPrimaryKey annotation.');
  }
}

Future _saveListMembers(dynamic listHolderId, List list, ListJoinField field,
    DBAdapter adapter) async {
  // table that stores relations between list members and list holder
  ListJoinModelsTable joinTable = field.joinTable;

  // table that stores actual list members
  Table listMembersTable = joinTable.listMembersTable;

  // insert or update all list items. This will assign primary keys to all list
  // items
  for (var listItem in list) {
    var primaryKeyValue = AnnotationsParser.getPropertyValueForField(
        listMembersTable.getPrimaryKeyField(), listItem);

    if (primaryKeyValue != null) {
      await update(listItem);
    } else {
      await insert(listItem);
    }
  }

  // delete all reference records from join table
  Delete d = new Delete(joinTable)
    ..where(new Equals(
        joinTable.listHolderPrimaryKeyReference.fieldName, listHolderId));
  await adapter.delete(d);

  for (var listItem in list) {
    var listItemId = AnnotationsParser.getPropertyValueForField(
        listMembersTable.getPrimaryKeyField(), listItem);

    if (listItemId == null) {
      throw new StateError(
          'Something went wrong: list item does not have an id.');
    } else {
      Insert referenceInsert = new Insert(field.joinTable)
        ..value(joinTable.listHolderPrimaryKeyReference.fieldName, listHolderId)
        ..value(joinTable.listMembersPrimaryKeyReference.fieldName, listItemId);

      await adapter.insert(referenceInsert);
    }
  }
}

/// Inserts [model] instance to database.
/// Primary key should be empty.
///
/// [model] class must have orm annotations.
Future insert(dynamic model, [DBAdapter adapter = null]) async {
  var primaryKeyValue = getPrimaryKeyValue(model);
  if (primaryKeyValue != null) {
    throw new Exception('insert() should not be called' +
        'on instances with not-null primary key value, use update() instead.');
  }

  Table table = AnnotationsParser.getTableForInstance(model);
  Insert _insert = new Insert(table);

  for (Field field in table.fields) {
    // skip primary keys and
    // [ListJoinField] since Join fields are stored in separate tables.
    if (!field.isPrimaryKey && !(field is ListJoinField)) {
      _insert.value(field.fieldName,
          AnnotationsParser.getPropertyValueForField(field, model));
    }
  }

  if (adapter == null) {
    adapter = getDefaultAdapter();
  }

  var newRecordId = await adapter.insert(_insert);
  if (table.getPrimaryKeyField() != null) {
    setPrimaryKeyValue(model, newRecordId);
  }

  // If model instance has lists
  if (_insert.table.hasReferenceFields) {
    for (Field f in _insert.table.fields) {
      if (f is ListJoinField) {
        Table joinTable = f.joinTable;

        // raw list of values
        List listToInsert =
            AnnotationsParser.getPropertyValueForField(f, model);

        if(listToInsert == null) {
          continue;
        }

        if (joinTable is ListJoinValuesTable) {
          for (var value in listToInsert) {
            Insert referenceInsert = new Insert(joinTable)
              ..value(joinTable.primaryKeyReferenceField.fieldName, newRecordId)
              ..value(joinTable.valueField.fieldName, value);

            await adapter.insert(referenceInsert);
          }
        } else if (joinTable is ListJoinModelsTable) {
          await _saveListMembers(newRecordId, listToInsert, f, adapter);
        } else {
          throw new StateError('Unknown joinTable type');
        }
      }
    }
  }

  return newRecordId;
}

/// Updates [model] instance in database.
/// Primary key should not be empty.
///
/// [model] class must have orm annotations.
Future update(dynamic model, [DBAdapter adapter = null]) async {
  var primaryKeyValue = getPrimaryKeyValue(model);
  if (primaryKeyValue == null) {
    throw new Exception('update() should not be called' +
        'on instances with null primary key value, use insert() instead.');
  }

  Table table = AnnotationsParser.getTableForInstance(model);
  Update update = new Update(table);

  for (Field field in table.fields) {
    var value = AnnotationsParser.getPropertyValueForField(field, model);
    if (field.isPrimaryKey) {
      update.where(new Equals(field.fieldName, value));
    } else if (!(field is ListJoinField)) {
      update.set(field.fieldName, value);
    }
  }

  if (adapter == null) {
    adapter = getDefaultAdapter();
  }

  var updateResult = await adapter.update(update);

  if (update.table.hasReferenceFields) {
    for (Field f in update.table.fields) {
      if (f is ListJoinField) {
        List listToInsert =
            AnnotationsParser.getPropertyValueForField(f, model);

        if (f.joinTable is ListJoinValuesTable) {
          ListJoinValuesTable referenceTable = f.joinTable;

          Delete delete = new Delete(referenceTable)
            ..where(new Equals(
                referenceTable.primaryKeyReferenceField.fieldName,
                primaryKeyValue));

          await adapter.delete(delete);

          for (var value in listToInsert) {
            Insert referenceInsert = new Insert(referenceTable)
              ..value(referenceTable.primaryKeyReferenceField.fieldName,
                  primaryKeyValue)
              ..value(referenceTable.valueField.fieldName, value);

            await adapter.insert(referenceInsert);
          }
        } else if (f.joinTable is ListJoinModelsTable) {
          await _saveListMembers(primaryKeyValue, listToInsert, f, adapter);
        } else {
          throw new StateError('Unknown joinTable type');
        }
      }
    }
  }

  return updateResult;
}

/// Deletes [model] instance from database.
/// Primary key should not be empty.
///
/// [model] class must have orm annotations.
Future delete(dynamic model, [DBAdapter adapter = null]) async {
  var primaryKeyValue = getPrimaryKeyValue(model);
  if (primaryKeyValue == null) {
    throw new Exception('delete() should not be called' +
        'on instances with null primary key value.');
  }

  Table table = AnnotationsParser.getTableForInstance(model);
  Delete delete = new Delete(table);

  Field field = table.getPrimaryKeyField();
  if (field != null) {
    var value = AnnotationsParser.getPropertyValueForField(field, model);
    delete.where(new Equals(field.fieldName, value));
  }

  if (adapter == null) {
    adapter = getDefaultAdapter();
  }

  var deleteResult = await adapter.delete(delete);
  return deleteResult;
}
