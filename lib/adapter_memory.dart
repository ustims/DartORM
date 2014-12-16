part of dart_orm;

/**
 * Slow and dumb in-memory storage.
 */
class MemoryAdapter extends DBAdapter {
  MemoryAdapter(): super();

  Map<Table, LinkedHashMap<int, dynamic>> _records = new Map<Table, LinkedHashMap<int, dynamic>>();

  String parseError(String errorCode) {
    return DBAdapter.ErrUnknown;
  }

  LinkedHashMap<int, dynamic> getTableRecords(String tableName) {
    for (Table table in _records.keys) {
      if (table.tableName == tableName) {
        return _records[table];
      }
    }
    return null;
  }

  dynamic query(Select selectSql) {
    Completer completer = new Completer();

    print(selectSql);

    Map records = getTableRecords(selectSql.tableName);

    if (records == null) {
      completer.completeError(new Exception(DBAdapter.ErrTableNotExist));
    } else {
      for (Map record in records.values) {
        // TODO: here must(will) be much better condition handling
        if (record.containsKey(selectSql.condition.firstVar.value) &&
        record[selectSql.condition.firstVar.value] == selectSql.condition.secondVar.value) {
          completer.complete([record.values.toList()]);
        }
      }
    }

    return completer.future;
  }

  dynamic execute(dynamic operation) {
    if (operation is Update) {
      throw new Exception('Not implemented yet');
      return this.update(operation);
    } else if (operation is Insert) {
      return this.insert(operation);
    } else if (operation is Table) {
      return this.createTable(operation);
    } else {
      throw new Exception('Unknown class passed to execute.');
    }
  }

  dynamic createTable(Table table) {
    Completer completer = new Completer();

    if (_records.containsKey(table.tableName)) {
      throw new Exception('table already exists');
    }

    _records[table] = new LinkedHashMap<int, dynamic>();

    completer.complete(1);
    return completer.future;
  }

  dynamic insert(Insert insert) {
    Completer completer = new Completer();

    // now we should remove DBTypes wrappers from values
    Map<String, dynamic> valuesToInsert = new Map<String, dynamic>();

    int primaryKey = 0;
    for (Table table in _records.keys) {
      // find the table we want to insert to
      if (table.tableName == insert.tableName) {
        // now lets find primary key field name
        for (Field field in table.fields) {
          if (field.isPrimaryKey) {
            if (!insert.fieldsToInsert.containsKey(field.fieldName)) {
              primaryKey = _records[table].keys.length + 1;
            }
            else {
              primaryKey = insert.fieldsToInsert[field.fieldName].value;
            }

            valuesToInsert[field.fieldName] = primaryKey;
          }
          else{
            valuesToInsert[field.fieldName] = insert.fieldsToInsert[field.fieldName].value;
          }

        }

        _records[table][primaryKey] = valuesToInsert;
      }
    }

    completer.complete(1);
    return completer.future;
  }
}