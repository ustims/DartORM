part of dart_orm;

class SQLAdapter {
  dynamic _connection;

  SQLAdapter(dynamic connection) {
    _connection = connection;
  }

  get connection => _connection;

  dynamic query(SelectSQL selectSql) async {
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

  dynamic execute(dynamic operation) {
    Completer completer = new Completer();

    String sqlQueryString = '';

    if (operation is UpdateSQL) {
      sqlQueryString = SQLAdapter.constructUpdateSql(operation);
    }
    else if (operation is InsertSQL) {
      sqlQueryString = SQLAdapter.constructInsertSql(operation);
    }
    else if (operation is DBTableSQL) {
        sqlQueryString = SQLAdapter.constructTableSql(operation);
      }
      else {
        throw new Exception('Unknown class passed to execute.');
      }

    print('[SQLAdapter] Executing operation:');
    print(sqlQueryString);
    _connection.execute(sqlQueryString)
    .then((result) {
      print('[SQLAdapter] result:');
      print(result);
      completer.complete(result);
    })
    .catchError((err) {
      print('[SQLAdapter] Error:');
      print(err);
      completer.completeError(err);
    });

    return completer.future;
  }

  /**
   * Condition sql constructor.
   * Makes strings such as 'a = b OR (b = c AND c = 10)'
   *
   * Uses _constructOneConditionSQL helper method for creating simple
   * conditions and appends all of them to a string by their condition.logic.
   */
  static String constructConditionSql(ConditionSQL condition) {
    String sql = SQLAdapter._constructOneConditionSQL(condition);

    for (ConditionSQL cond in condition.conditionQueue) {
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
  static String _constructOneConditionSQL(ConditionSQL condition) {
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
  static String constructSelectSql(SelectSQL selectSql) {
    String sql = 'SELECT ';
    sql += selectSql.columnsToSelect.join(', \n       ');
    sql += ' \nFROM ' + selectSql.tableName;

    if (selectSql.tableAlias != null) {
      sql += ' AS ' + selectSql.tableAlias;
    }

    if (selectSql.joins.length > 0) {
      for (JoinSQL j in selectSql.joins) {
        sql += SQLAdapter.constructJoinSql(j);
      }
    }

    if (selectSql.condition != null) {
      sql += '\nWHERE ' + SQLAdapter.constructConditionSql(selectSql.condition);
    }

    if (selectSql.sorts.length > 0) {
      sql += '\nORDER BY ';
      List<String> sorts = new List<String>();
      for (String sortField in selectSql.sorts.keys) {
        sorts.add(sortField + ' ' + selectSql.sorts[sortField]);
      }
      sql += sorts.join(', ');
    }

    if (selectSql.limit != null) {
      sql += " LIMIT " + selectSql.limit.toString();
    }

    if (selectSql.offset != null) {
      sql += " OFFSET " + selectSql.offset.toString();
    }

    return sql;
  }

  /**
   * JOIN sql statement constructor.
   */
  static String constructJoinSql(JoinSQL join) {
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
  static String constructInsertSql(InsertSQL insert) {
    List<String> values = new List<String>();

    for (var v in insert.fieldsToInsert.values) {
      if (v is TypedSQL) {
        values.add(v.toSql());
      }
      else {
        values.add(v);
      }
    }

    String sql = 'INSERT INTO ${insert.tableName} (\n    ';
    sql += insert.fieldsToInsert.keys.join(',\n    ');
    sql += ')\n';
    sql += 'VALUES (\n    ';
    sql += values.join(',\n    ');
    sql += '\n);';

    return sql;
  }

  /**
   * UPDATE sql statement constructor.
   */
  static String constructUpdateSql(UpdateSQL update) {
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
  static String constructTableSql(DBTableSQL table) {
    String sql = 'CREATE TABLE ${table.tableName} (';

    List<String> fieldDefinitions = new List<String>();

    for (DBFieldSQL f in table.fields) {
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
  static String constructFieldSql(DBFieldSQL field) {
    String fieldDefinition = field.fieldName + ' ' + field.type;

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