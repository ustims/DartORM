part of dart_orm;


class MongoAdapter extends DBAdapter {
  dynamic _connection;
  dynamic _mongoSelectorBuilderType;
  dynamic _mongoUpdateBuilderType;
  dynamic createQueryDbCommand;

  MongoAdapter(dynamic connection,
               dynamic this._mongoSelectorBuilderType,
               dynamic this._mongoUpdateBuilderType,
               this.createQueryDbCommand) {
    _connection = connection;
  }

  get connection => _connection;

  dynamic getMongoSelectorBuilder() {
    ClassMirror classMirror = reflectClass(_mongoSelectorBuilderType);

    var instance = classMirror.newInstance(new Symbol(''), []);
    return instance.reflectee;
  }

  dynamic getMongoUpdateBuilder() {
    ClassMirror classMirror = reflectClass(_mongoUpdateBuilderType);

    var instance = classMirror.newInstance(new Symbol(''), []);
    return instance.reflectee;
  }

  dynamic convertCondition(Table table, Condition cond) {
    var w = null;

    Field pKey = table.getPrimaryKeyField();
    if (pKey != null) {
      if (cond.firstVar == pKey.fieldName) {
        cond.firstVar = '_id';
      }
      if (cond.secondVar == pKey.fieldName) {
        cond.secondVar = '_id';
      }
    }

    switch (cond.condition) {
      case '=':
        w = getMongoSelectorBuilder().eq(cond.firstVar, cond.secondVar);
        break;
      case '>':
        w = getMongoSelectorBuilder().gt(cond.firstVar, cond.secondVar);
        break;
      case '<':
        w = getMongoSelectorBuilder().lt(cond.firstVar, cond.secondVar);
        break;
    }

    if (cond.conditionQueue.length > 0) {
      for (Condition innerCond in cond.conditionQueue) {
        var innerWhere = convertCondition(table, innerCond);
        if (innerCond.logic == 'AND') {
          w.and(innerWhere);
        }
        if (innerCond.logic == 'OR') {
          w.or(innerWhere);
        }
      }
    }

    return w;
  }

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
      var mongoSelector = null;

      if (select.condition != null) {
        mongoSelector = convertCondition(select.table, select.condition);
      }

      if (mongoSelector == null) {
        mongoSelector = getMongoSelectorBuilder().ne('_id', null);
      }

      if (select.sorts.length > 0) {
        for (String fieldName in select.sorts.keys) {
          Field pKey = select.table.getPrimaryKeyField();
          if (pKey != null) {
            if (fieldName == pKey.fieldName) {
              fieldName = '_id';
            }
          }

          if (select.sorts[fieldName] == 'ASC') {
            mongoSelector = mongoSelector.sortBy(fieldName, descending:false);
          } else {
            mongoSelector = mongoSelector.sortBy(fieldName, descending:true);
          }
        }

      }

      return collection.find(mongoSelector).forEach((value) {
        // for each found value, if select.table contains primary key
        // we need to change '_id' to that primary key name
        Field f = select.table.getPrimaryKeyField();
        if (f != null) {
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
      await createSequence(table, pKey);
    }

    var createdCollection = await _connection.collection(table.tableName);
    print(createdCollection);
    return true;
  }

  Future insert(Insert insert) async {
    var collection = await _connection.collection(insert.table.tableName);

    Field pKey = insert.table.getPrimaryKeyField();
    var primaryKeyValue = 0;
    if (pKey != null) {
      primaryKeyValue = await getNextSequence(insert.table, pKey);
      insert.fieldsToInsert['_id'] = primaryKeyValue;
    }

    var insertResult = await collection.insert(insert.fieldsToInsert);
    return primaryKeyValue;
  }

  Future update(Update update) async {
    print(update);
    var collection = await _connection.collection(update.table.tableName);

    Field pKey = update.table.getPrimaryKeyField();
    if (pKey == null) {
      throw new Exception('Could not update a table row withour primary key.');
    }

    var selector = convertCondition(update.table, update.condition);
    var modifiers = getMongoUpdateBuilder();
    for(String fieldName in update.fieldsToUpdate.keys){
      modifiers.set(fieldName, update.fieldsToUpdate[fieldName]);
    }

    var updateResult = await collection.update(selector, modifiers);
    return updateResult;
  }

  Future createSequence(Table table, Field field) async {
    var countersCollection = await _connection.collection('counters');

    var existingCounter = await countersCollection.findOne(
        getMongoSelectorBuilder().eq(
            '_id', "${table.tableName}_${field.fieldName}_seq")
    );
    if (existingCounter == null) {
      var insertResult = await countersCollection.insert({
          '_id': "${table.tableName}_${field.fieldName}_seq",
          'seq': 0
      });
    }
  }

  Future<int> getNextSequence(Table table, Field field) {
    Completer completer = new Completer();

    String seqName = "${table.tableName}_${field.fieldName}_seq";

    Map command = {
        'findAndModify': 'counters',
        'query': {
            '_id': seqName
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
