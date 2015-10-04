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
  Insert insert = new Insert(table);

  for (Field field in table.fields) {
    if (!field.isPrimaryKey) {
      insert.value(field.fieldName,
          AnnotationsParser.getPropertyValueForField(field, model));
    }
  }

  if (adapter == null) {
    adapter = getDefaultAdapter();
  }

  var newRecordId = await adapter.insert(insert);
  if (table.getPrimaryKeyField() != null) {
    setPrimaryKeyValue(model, newRecordId);
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
    } else {
      update.set(field.fieldName, value);
    }
  }

  if (adapter == null) {
    adapter = getDefaultAdapter();
  }

  var updateResult = await adapter.update(update);
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
