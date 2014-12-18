part of dart_orm;

class SQLAdapter {
  dynamic _connection;

  SQLAdapter(dynamic connection) {
    _connection = connection;
  }

  get connection => _connection;

  dynamic query(Select selectSql) async {
    Completer completer = new Completer();

    String sqlQueryString = SQLAdapter.constructSelectSql(selectSql);
    print('[SQLAdapter] <query>');
    print(sqlQueryString);
    print('[SQLAdapter] </query>');

    _connection.query(sqlQueryString)
    .toList()
    .then((result) {
      print('[SQLAdapter] <result>');
      print(result);
      print('[SQLAdapter] </result>');
      completer.complete(result);
    })
    .catchError((err) {
      print('[SQLAdapter] <error>');
      print(err);
      print('[SQLAdapter] </error>');
      completer.completeError(err);
    });

    return completer.future;
  }

  Future insert(Insert insert) async {
    String sqlQueryString = SQLAdapter.constructInsertSql(insert);

    print('[SQLAdapter] Inserting row:');
    print(sqlQueryString);

    var result = await _connection.query(sqlQueryString).toList();
    return result[0][0];
  }

  Future update(Update update) async {
    String sqlQueryString = SQLAdapter.constructUpdateSql(update);

    print('[SQLAdapter] updating row:');
    print(sqlQueryString);

    var affectedRows = await _connection.execute(sqlQueryString);

    return affectedRows;
  }

  dynamic execute(dynamic operation) async {
    Completer completer = new Completer();

    String sqlQueryString = '';

    if (operation is Update) {
      sqlQueryString = SQLAdapter.constructUpdateSql(operation);
    } else if (operation is Insert) {
      sqlQueryString = SQLAdapter.constructInsertSql(operation);
    } else if (operation is Table) {
      sqlQueryString = SQLAdapter.constructTableSql(operation);
    } else {
      throw new Exception('Unknown class passed to execute.');
    }

    print('[SQLAdapter] Executing operation:');
    print(sqlQueryString);

    if(operation is Insert){
      // since our inserts have 'RETURNING %primaryKey%'
      // we should make 'query' instead of 'execute'
      var result = await _connection.query(sqlQueryString).toList();
      var createdId = result.last[0];
      return createdId;
    }
    else{
      var result = await _connection.execute(sqlQueryString);
      return result;
    }
  }

  /**
   * Condition sql constructor.
   * Makes strings such as 'a = b OR (b = c AND c = 10)'
   *
   * Uses _constructOneConditionSQL helper method for creating simple
   * conditions and appends all of them to a string by their condition.logic.
   */
  static String constructConditionSql(Condition condition) {
    String sql = SQLAdapter._constructOneConditionSQL(condition);

    for (Condition cond in condition.conditionQueue) {
      if (cond.logic != null) {
        sql += ' ' + cond.logic + ' (';
      }

      sql += SQLAdapter.constructConditionSql(cond);

      if (cond.logic != null) {
        sql += ')';
      }
    }

    return sql;
  }

  /**
   * Simple condition constructor.
   * Makes string such as 'a = b', 'b < 10' etc.
   *
   * Works by concantenating
   * condition.firstVar + condition.condition + condition.secondVar.
   */
  static String _constructOneConditionSQL(Condition condition) {
    if (!(condition.firstVar is TypedSQL)) {
      condition.firstVar = getTypedSqlFromValue(condition.firstVar);
    }
    if (!(condition.secondVar is TypedSQL)) {
      condition.secondVar = getTypedSqlFromValue(condition.secondVar);
    }
    return condition.firstVar.toSql() + ' ' + condition.condition + ' ' + condition.secondVar.toSql();
  }

  /**
   * SELECT query constructor.
   *
   * Constructs select statements such as
   *
   * 'SELECT {{selectSql.columnsToSelect}}
   *  FROM {{selectSql.tableName}}
   *  JOIN {{selectSql.joins}}
   *  WHERE {{selectSql.condition}}
   *  ORDER BY {{selectSql.orders}}
   *  LIMIT {{selectSql.limit}}
   *  OFFSET {{selectSql.offset}}'
   */
  static String constructSelectSql(Select select) {
    String sql = 'SELECT ';
    sql += select.columnsToSelect.join(', \n       ');
    sql += ' \nFROM ' + select.table.tableName;

    // TODO: if select has joins here we need to add table alias.
//    if (select.table.tableAlias != null) {
//      sql += ' AS ' + select.tableAlias;
//    }

    if (select.joins.length > 0) {
      for (Join j in select.joins) {
        sql += SQLAdapter.constructJoinSql(j);
      }
    }

    if (select.condition != null) {
      sql += '\nWHERE ' + SQLAdapter.constructConditionSql(select.condition);
    }

    if (select.sorts.length > 0) {
      sql += '\nORDER BY ';
      List<String> sorts = new List<String>();
      for (String sortField in select.sorts.keys) {
        sorts.add(sortField + ' ' + select.sorts[sortField]);
      }
      sql += sorts.join(', ');
    }

    if (select.limit != null) {
      sql += " LIMIT " + select.limit.toString();
    }

    if (select.offset != null) {
      sql += " OFFSET " + select.offset.toString();
    }

    return sql;
  }

  /**
   * JOIN sql statement constructor.
   */
  static String constructJoinSql(Join join) {
    String sql = '';
    sql += '\n' + join.joinType.toUpperCase() + ' JOIN ';
    sql += join.tableName;
    sql += ' AS ' + join.tableAlias;
    sql += '\n ON ' + SQLAdapter.constructConditionSql(join.joinCondition);
    return sql;
  }

  /**
   * INSERT sql statement constructor.
   */
  static String constructInsertSql(Insert insert) {
    List<String> values = new List<String>();

    for (var v in insert.fieldsToInsert.values) {
      if (v is TypedSQL) {
        values.add(v.toSql());
      }
      else {
        values.add(v);
      }
    }

    String sql = 'INSERT INTO ${insert.table.tableName} (\n    ';
    sql += insert.fieldsToInsert.keys.join(',\n    ');
    sql += ')\n';
    sql += 'VALUES (\n    ';
    sql += values.join(',\n    ');
    sql += '\n)';

    // TODO: this should be in postgres adapter
    Field primaryKey = insert.table.getPrimaryKeyField();

    sql += '\nRETURNING ${primaryKey.fieldName}';

    return sql;
  }

  /**
   * UPDATE sql statement constructor.
   */
  static String constructUpdateSql(Update update) {
    String sql = 'UPDATE ${update.tableName} ';
    sql += '\nSET ';

    List<String> fields = new List<String>();

    for (String fieldName in update.fieldsToUpdate) {
      fields.add(fieldName + ' = ' + update.fieldsToUpdate[fieldName].toSql());
    }

    sql += fields.join(',\n    ');

    sql += '\nWHERE ' + SQLAdapter.constructConditionSql(update.condition);

    return sql;
  }

  /**
   * CREATE TABLE sql statement constructor.
   */
  static String constructTableSql(Table table) {
    String sql = 'CREATE TABLE ${table.tableName} (';

    List<String> fieldDefinitions = new List<String>();

    for (Field f in table.fields) {
      String fieldDefinition = '\n    ' + SQLAdapter.constructFieldSql(f);
      fieldDefinitions.add(fieldDefinition);
    }

    sql += fieldDefinitions.join(',');
    sql += '\n);';

    return sql;
  }

  /**
   * Field sql constructor helper for CREATE TABLE.
   */
  static String constructFieldSql(Field field) {
    String fieldType = '';

    switch (field.propertyTypeName) {
      case 'int':
        if (field.isPrimaryKey) {
          fieldType = 'SERIAL';
        }
        else {
          fieldType = 'int';
        }
        break;
      case 'String':
        fieldType = 'text';
        break;
      case 'bool':
        fieldType = 'bool';
        break;
      case 'LinkedHashMap':
        fieldType = 'json';
        break;
    }

    String fieldDefinition = field.fieldName + ' ' + fieldType;

    if (field.isPrimaryKey) {
      fieldDefinition += ' PRIMARY KEY';
    }

    if (field.defaultValue != null) {
      fieldDefinition += ' DEFAULT ' + field.defaultValue.toString();
    }

    if (field.isUnique) {
      fieldDefinition += ' UNIQUE';
    }

    return fieldDefinition;
  }
}