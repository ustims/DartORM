part of dart_orm;


class MongoAdapter extends DBAdapter {
  dynamic _connection;
  dynamic where;
  dynamic createQueryDbCommand;

  MongoAdapter(dynamic connection, dynamic this.where, this.createQueryDbCommand) {
    _connection = connection;
  }

  get connection => _connection;

  Future<List> select(Select select) {
    Completer completer = new Completer();

    List found = new List();
    _connection.listCollections()
    .then((List collections) {
      if (!collections.contains(select.table.tableName)) {
        throw new TableNotExistException();
      }

      return _connection.collection(select.table.tableName);
    })
    .then((collection) {
      var w = where.ne('_id', null);

      if(select.condition != null) {
        Condition cond = select.condition;

        Field pKey = select.table.getPrimaryKeyField();
        if(pKey != null){
          if(cond.firstVar == pKey.fieldName){
            cond.firstVar = '_id';
          }
          if(cond.secondVar == pKey.fieldName){
            cond.secondVar = '_id';
          }
        }

        switch (cond.condition) {
          case '=':
            w = where.eq(cond.firstVar, cond.secondVar);
            break;
          case '>':
            w = where.gt(cond.firstVar, cond.secondVar);
            break;
          case '<':
            w = where.lt(cond.firstVar, cond.secondVar);
            break;
        }
      }

      if(select.sorts.length > 0){
        for(String fieldName in select.sorts.keys){
          Field pKey = select.table.getPrimaryKeyField();
          if(pKey != null){
            if(fieldName == pKey.fieldName){
              fieldName = '_id';
            }
          }

          if(select.sorts[fieldName] == 'ASC') {
            w = w.sortBy(fieldName, descending:false);
          } else {
            w = w.sortBy(fieldName, descending:true);
          }
        }

      }

      return collection.find(w).forEach((value) {
        // for each found value, if select.table contains primary key
        // we need to change '_id' to that primary key name
        Field f = select.table.getPrimaryKeyField();
        if(f != null){
          value[f.fieldName] = value['_id'];
        }
        found.add(value);
      });
    })
    .then((a) {
      completer.complete(found);
    })
    .catchError((e) {
      completer.completeError(e);
    });

    return completer.future;
  }

  Future createTable(Table table) async {
    // check if table has primary key
    Field pKey = table.getPrimaryKeyField();
    if (pKey != null) {
      var countersCollection = await _connection.collection('counters');
      var existingCounter = await countersCollection.findOne(
          where.eq('_id', "${table.tableName}_primaryKey")
      );
      if (existingCounter == null) {
        var insertResult = await countersCollection.insert({
            '_id': "${table.tableName}_primaryKey",
            'seq': 0
        });
      }
    }

    var createdCollection = await _connection.collection(table.tableName);
    print(createdCollection);
    return true;
  }

  Future insert(Insert insert) async {
    var collection = await _connection.collection(insert.table.tableName);

    Field pKey = insert.table.getPrimaryKeyField();
    var primaryKeyValue = 0;
    if(pKey != null){
      primaryKeyValue = await getNextSequence("${insert.table.tableName}_primaryKey");
      insert.fieldsToInsert['_id'] = primaryKeyValue;
    }

    var insertResult = await collection.insert(insert.fieldsToInsert);
    return primaryKeyValue;
  }

  Future<int> getNextSequence(name) {
    Completer completer = new Completer();

    Map command = {
        'findAndModify': 'counters',
        'query': {
            '_id': name
        },
        'update': {
            r'$inc': {
                'seq': 1
            }
        },
        'new': true
    };

    _connection.executeDbCommand(createQueryDbCommand(_connection, command))
    .then((Map result) {
      var value = result['value']['seq'];
      completer.complete(value);
    })
    .catchError((e) {
      completer.completeError(e);
    });

    return completer.future;
  }

}
