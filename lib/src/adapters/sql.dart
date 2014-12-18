part of dart_orm;

class SQLAdapter {
  dynamic _connection;

  SQLAdapter(dynamic connection) {
    _connection = connection;
  }

  get connection => _connection;

  Future<List> select(Select selectSql) async {
    String sqlQueryString = SQLAdapter.constructSelectSql(selectSql);
    List results = await _connection.query(sqlQueryString).toList();
    return results;
  }

  Future insert(Insert insert) async {
    String sqlQueryString = SQLAdapter.constructInsertSql(insert);

    var result = await _connection.query(sqlQueryString).toList();
    if(result.length > 0){
      return result[0][0];
    }

    return 0;
  }

  Future update(Update update) async {
    String sqlQueryString = SQLAdapter.constructUpdateSql(update);
    var affectedRows = await _connection.execute(sqlQueryString);
    return affectedRows;
  }

  @deprecated()
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

    var result = await _connection.execute(sqlQueryString);
    return result;
  }

  /**
   * Condition sql constructor.
   * Makes strings such as 'a = b OR (b = c AND c = 10)'
   *
   * Uses _constructOneConditionSQL helper method for creating simple
   * conditions and appends all of them to a string by their condition.logic.
   */
  static String constructConditionSql(Condition condition,
                                      [Table table = null]) {
    String sql = SQLAdapter._constructOneConditionSQL(condition, table);

    for (Condition cond in condition.conditionQueue) {
      if (cond.logic != null) {
        sql += ' ' + cond.logic + ' (';
      }

      sql += SQLAdapter.constructConditionSql(cond, table);

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
  static String _constructOneConditionSQL(Condition condition,
                                          [Table table = null]) {
    if (!(condition.firstVar is TypedSQL)) {
      if (table != null) {
        condition.firstVar = SQLAdapter.getTypedSqlFromValue(
            condition.firstVar, table);
      } else {
        condition.firstVar = SQLAdapter.getTypedSqlFromValue(
            condition.firstVar);
      }

    }
    if (!(condition.secondVar is TypedSQL)) {
      if (table != null) {
        condition.secondVar = SQLAdapter.getTypedSqlFromValue(
            condition.secondVar, table);
      } else {
        condition.secondVar = SQLAdapter.getTypedSqlFromValue(
            condition.secondVar);
      }
    }

    return condition.firstVar.toSql() + ' ' +
    condition.condition + ' ' +
    condition.secondVar.toSql();
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
    //if (select.table.tableAlias != null) {
    //  sql += ' AS ' + select.tableAlias;
    //}

    if (select.joins.length > 0) {
      for (Join j in select.joins) {
        sql += SQLAdapter.constructJoinSql(j);
      }
    }

    if (select.condition != null) {
      sql += '\nWHERE ' + SQLAdapter.constructConditionSql(
          select.condition,
          select.table
      );
    }

    if (select.sorts.length > 0) {
      sql += '\nORDER BY ';
      List<String> sorts = new List<String>();
      for (String sortFieldName in select.sorts.keys) {
        TypedSQL sortFieldSql = SQLAdapter.getTypedSqlFromValue(
            sortFieldName, select.table);
        sorts.add(sortFieldSql.toSql() + ' ' + select.sorts[sortFieldName]);
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
      values.add(SQLAdapter.getTypedSqlFromValue(v).toSql());
    }

    String sql = 'INSERT INTO ${insert.table.tableName} (\n    ';
    sql += insert.fieldsToInsert.keys
    .map((String fieldName) => SQL.camelCaseToUnderscore(fieldName))
    .join(',\n    ');
    sql += ')\n';
    sql += 'VALUES (\n    ';
    sql += values.join(',\n    ');
    sql += '\n)';

    // TODO: this should be in postgres adapter
    Field primaryKeyField = insert.table.getPrimaryKeyField();
    if(primaryKeyField != null) {
      var primaryKeyName = SQL.camelCaseToUnderscore(primaryKeyField.fieldName);
      sql += '\nRETURNING ${primaryKeyName}';
    }

    return sql;
  }

  /**
   * UPDATE sql statement constructor.
   */
  static String constructUpdateSql(Update update) {
    String sql = 'UPDATE ${update.table.tableName} ';
    sql += '\nSET ';

    List<String> fields = new List<String>();

    for (String fieldName in update.fieldsToUpdate.keys) {
      TypedSQL fieldValue = SQLAdapter.getTypedSqlFromValue(
          update.fieldsToUpdate[fieldName]);
      fieldName = SQL.camelCaseToUnderscore(fieldName);
      fields.add(fieldName + ' = ' + fieldValue.toSql());
    }

    sql += fields.join(',\n    ');

    sql += '\nWHERE ' + SQLAdapter.constructConditionSql(
        update.condition, update.table);

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

    String fieldDefinition = SQL.camelCaseToUnderscore(field.fieldName)
    + ' ' + fieldType;

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

  /**
   * Wraps any value instance with approciate TypedSQL class
   * which can be converted to SQL string.
   *
   * Tricky thing is about column names. For example is we receive 'id' string:
   * is it the value which should be wrapped with quotes, or is it a column name
   * which should not be wrapped with quotes.
   *
   * As a workaround this method receives optional [Table] argument.
   * If it is provided and if instanceFieldValue is [String] it will be compared
   * with all of the table field names.
   */
  static TypedSQL getTypedSqlFromValue(var instanceFieldValue,
                                       [Table table=null]) {
    if (instanceFieldValue is String && table != null) {
      for (Field f in table.fields) {
        if (f.fieldName == instanceFieldValue) {
          // sql field names should be converted to underscore
          String fieldName = SQL.camelCaseToUnderscore(instanceFieldValue);
          return new RawSQL(fieldName);
        }
      }
    }

    TypedSQL valueSql;

    if (instanceFieldValue == null) {
      valueSql = new NullSQL();
    } else if (instanceFieldValue is String) {
      valueSql = new StringSQL(instanceFieldValue);
    } else if (instanceFieldValue is List) {
      valueSql = new ListSQL(instanceFieldValue);
    } else {
      valueSql = new RawSQL(instanceFieldValue);
    }

    return valueSql;
  }
}