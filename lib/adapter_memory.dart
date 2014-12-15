part of dart_orm;

/**
 * Slow and dumb in-memory storage.
 */
class MemoryAdapter extends OrmDBAdapter {
  MemoryAdapter(): super();

  Map<DBTableSQL, LinkedHashMap<int, dynamic>> _records = new Map<DBTableSQL, LinkedHashMap<int, dynamic>>();

  String parseError(String errorCode) {
    return OrmDBAdapter.ErrUnknown;
  }

  dynamic query(SelectSQL selectSql) {
    Completer completer = new Completer();

    print(selectSql);
    if(!_records.containsKey(selectSql.tableName)){
      completer.completeError(new Exception(OrmDBAdapter.ErrTableNotExist));
    } else{
      completer.complete(_records[selectSql.tableName]);
    }

    return completer.future;
  }

  dynamic execute(dynamic operation) {
    if (operation is UpdateSQL) {
      return this.update(operation);
    } else if (operation is InsertSQL) {
      return this.insert(operation);
    } else if (operation is DBTableSQL) {
      return this.createTable(operation);
    } else {
      throw new Exception('Unknown class passed to execute.');
    }
  }

  dynamic createTable(DBTableSQL table) {
    Completer completer = new Completer();

    if(_records.containsKey(table.tableName)){
      throw new Exception('table already exists');
    }

    _records[table] = new LinkedHashMap<int, dynamic>();

    completer.complete(1);
    return completer.future;
  }

  dynamic insert(InsertSQL insert){
    Completer completer = new Completer();

    int primaryKey = 0;
    for(DBTableSQL table in _records.keys){
      // find the table we want to insert to
      if(table.tableName == insert.tableName){
        // now lets find primary key field name
        for(DBFieldSQL field in table.fields){
          if(field.isPrimaryKey){
            if(!insert.fieldsToInsert.containsKey(field.fieldName)){
              primaryKey = _records[table].keys.last + 1;
            }
            else{
              primaryKey = insert.fieldsToInsert[field.fieldName];
            }
          }
        }

        _records[table][primaryKey] = insert.fieldsToInsert;
      }
    }

    completer.complete(1);
    return completer.future;
  }
}