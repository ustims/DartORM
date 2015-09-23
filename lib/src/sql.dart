library dart_orm.sql;

import 'dart:async';

import 'annotations.dart';
import 'operations.dart';
import 'sql_types.dart';

class SQLAdapter {
  dynamic connection;

  /**
   * Returns list of maps which keys are column names
   * and values are values from db.
   */
  Future<List<Map>> select(Select select) async {
    String sqlQueryString = this.constructSelectSql(select);

    List rawResults = await connection.query(sqlQueryString).toList();
    List<Map> results = new List<Map>();

    // sql adapters usually returns a list of fields without field names
    for (var rawRow in rawResults) {
      Map<String, dynamic> row = new Map<String, dynamic>();

      int fieldNumber = 0;
      for (Field f in select.table.fields) {
        row[f.fieldName] = rawRow[fieldNumber];
        fieldNumber++;
      }

      results.add(row);
    }

    return results;
  }

  Future<int> insert(Insert insert) async {
    String sqlQueryString = this.constructInsertSql(insert);

    var result = await connection.query(sqlQueryString).toList();
    if (result.length > 0) {
      // if we have any results, here will be returned new primary key
      // of the inserted row
      return result[0][0];
    }

    // if model does'nt have primary key we simply return 0
    return 0;
  }

  Future<int> update(Update update) async {
    String sqlQueryString = this.constructUpdateSql(update);
    var affectedRows = await connection.execute(sqlQueryString);
    return affectedRows;
  }

  Future<int> delete(Delete delete) async {
    String sqlQueryString = this.constructDeleteSql(delete);
    var affectedRows = await connection.execute(sqlQueryString);
    return affectedRows;
  }

  Future createTable(Table table) async {
    String sqlQueryString = this.constructTableSql(table);
    var result = await connection.execute(sqlQueryString);
    return result;
  }

  /**
   * Condition sql constructor.
   * Makes strings such as 'a = b OR (b = c AND c = 10)'
   *
   * Uses _constructOneConditionSQL helper method for creating simple
   * conditions and appends all of them to a string by their condition.logic.
   */
  String constructConditionSql(Condition condition, [Table table = null]) {
    String sql = this._constructOneConditionSQL(condition, table);

    for (Condition cond in condition.conditionQueue) {
      if (cond.logic != null) {
        sql += ' ' + cond.logic + ' ';
      }

      if (cond.logic != null && cond.conditionQueue.length > 0) {
        sql += '(';
      }

      sql += this.constructConditionSql(cond, table);

      if (cond.logic != null && cond.conditionQueue.length > 0) {
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
  String _constructOneConditionSQL(Condition condition, [Table table = null]) {
    if (!(condition.firstVar is TypedSQL)) {
      if (table != null) {
        condition.firstVar =
            this.getTypedSqlFromValue(condition.firstVar, table);
      } else {
        condition.firstVar = this.getTypedSqlFromValue(condition.firstVar);
      }
    }
    if (!(condition.secondVar is TypedSQL)) {
      if (table != null) {
        condition.secondVar =
            this.getTypedSqlFromValue(condition.secondVar, table);
      } else {
        condition.secondVar = this.getTypedSqlFromValue(condition.secondVar);
      }
    }

    return condition.firstVar.toSql() +
        ' ' +
        condition.condition +
        ' ' +
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
  String constructSelectSql(Select select) {
    String sql = 'SELECT ';
    sql += select.columnsToSelect.join(', \n       ');
    sql += ' \nFROM ' + select.table.tableName;

    // TODO: if select has joins here we need to add table alias.
    //if (select.table.tableAlias != null) {
    //  sql += ' AS ' + select.tableAlias;
    //}

    if (select.joins.length > 0) {
      for (Join j in select.joins) {
        sql += this.constructJoinSql(j);
      }
    }

    if (select.condition != null) {
      sql += '\nWHERE ' +
          this.constructConditionSql(select.condition, select.table);
    }

    if (select.sorts.length > 0) {
      sql += '\nORDER BY ';
      List<String> sorts = new List<String>();
      for (String sortFieldName in select.sorts.keys) {
        TypedSQL sortFieldSql =
            this.getTypedSqlFromValue(sortFieldName, select.table);
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
  String constructJoinSql(Join join) {
    String sql = '';
    sql += '\n' + join.joinType.toUpperCase() + ' JOIN ';
    sql += join.tableName;
    sql += ' AS ' + join.tableAlias;
    sql += '\n ON ' + this.constructConditionSql(join.joinCondition);
    return sql;
  }

  /**
   * INSERT sql statement constructor.
   */
  String constructInsertSql(Insert insert) {
    List<String> values = new List<String>();

    for (var v in insert.fieldsToInsert.values) {
      values.add(this.getTypedSqlFromValue(v).toSql());
    }

    String sql = 'INSERT INTO ${insert.table.tableName} (\n    ';
    sql += insert.fieldsToInsert.keys
        .map((String fieldName) => SQL.camelCaseToUnderscore(fieldName))
        .join(',\n    ');
    sql += ')\n';
    sql += 'VALUES (\n    ';
    sql += values.join(',\n    ');
    sql += '\n)';

    return sql;
  }

  /**
   * UPDATE sql statement constructor.
   */
  String constructUpdateSql(Update update) {
    String sql = 'UPDATE ${update.table.tableName} ';
    sql += '\nSET ';

    List<String> fields = new List<String>();

    for (String fieldName in update.fieldsToUpdate.keys) {
      TypedSQL fieldValue =
          this.getTypedSqlFromValue(update.fieldsToUpdate[fieldName]);
      fieldName = SQL.camelCaseToUnderscore(fieldName);
      fields.add(fieldName + ' = ' + fieldValue.toSql());
    }

    sql += fields.join(',\n    ');

    sql +=
        '\nWHERE ' + this.constructConditionSql(update.condition, update.table);

    return sql;
  }

  /**
   * DELETE sql statement constructor.
   */
  String constructDeleteSql(Delete delete) {
    String sql = 'DELETE FROM ${delete.table.tableName} ';

    sql +=
        '\nWHERE ' + this.constructConditionSql(delete.condition, delete.table);

    return sql;
  }

  /**
   * CREATE TABLE sql statement constructor.
   */
  String constructTableSql(Table table) {
    String sql = 'CREATE TABLE ${table.tableName} (';

    List<String> fieldDefinitions = new List<String>();

    for (Field f in table.fields) {
      String fieldDefinition = '\n    ' + this.constructFieldSql(f);
      fieldDefinitions.add(fieldDefinition);
    }

    sql += fieldDefinitions.join(',');

    sql += '\n' + this.getConstraintsSql(table);
    sql += '\n);';

    return sql;
  }

  String getConstraintsSql(Table table) {
    return '';
  }

  Map<Field, Field> getRelatedFields(Table table) {
    Map<Field, Field> relatedFields = new Map<Field, Field>();
    for (Field f in table.fields) {
      Field relatedField = this.getRelationField(f);
      if (relatedField != null) {
        relatedFields[f] = relatedField;
      }
    }
    return relatedFields;
  }

  Field getRelationField(field) {
    Table relatedTable =
        AnnotationsParser.getTableForClassName(field.propertyTypeName);
    if (relatedTable != null) {
      return relatedTable.getPrimaryKeyField();
    } else {
      return null;
    }
  }

  /**
   * Field sql constructor helper for CREATE TABLE.
   */
  String constructFieldSql(Field field) {
    String fieldType = '';

    Field relatedField = this.getRelationField(field);

    if (relatedField != null) {
      // seems that we have foreign key here
      // so we need to set type based on the type
      // of the related table's primary key
      fieldType = this.getSqlType(relatedField);
    } else {
      if (field.isPrimaryKey) {
        fieldType = 'SERIAL';
      } else {
        fieldType = this.getSqlType(field);
      }
    }

    String fieldDefinition =
        SQL.camelCaseToUnderscore(field.fieldName) + ' ' + fieldType;

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
   * This method is invoked when db table(column) is created to determine
   * what sql type to use.
   */
  String getSqlType(Field field) {
    String dbTypeName = '';
    switch (field.propertyTypeName) {
      case 'int':
        dbTypeName = 'int';
        break;
      case 'double':
        dbTypeName = 'double precision';
        break;
      case 'String':
        dbTypeName = 'text';
        break;
      case 'bool':
        dbTypeName = 'bool';
        break;
      case 'LinkedHashMap':
        dbTypeName = 'json';
        break;
    }
    return dbTypeName;
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
  TypedSQL getTypedSqlFromValue(var instanceFieldValue, [Table table = null]) {
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
    } else if (instanceFieldValue is DateTime) {
      valueSql = new DateTimeSQL(instanceFieldValue);
    } else {
      valueSql = new RawSQL(instanceFieldValue);
    }

    return valueSql;
  }
}
