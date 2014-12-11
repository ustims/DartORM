import 'dart:collection';
import 'sql_types.dart';

class ConditionLogic {
  static String AND = 'AND';
  static String OR = 'OR';
  static String IN = 'IN';
}

class OrderSQL {
  static final String ASC = 'ASC';
  static final String DESC = 'DESC';
}

class SQL {
  int _limit = null;
  int _offset = null;

  limit(int rowsNumber) {
    this._limit = rowsNumber;
  }

  offset(int rowsNumber) {
    this._offset = rowsNumber;
  }

  String _toSql(String preparedSql) {
    if (this._limit != null) {
      preparedSql += " LIMIT " + this._limit.toString();
    }

    if (this._offset != null) {
      preparedSql += " OFFSET " + this._offset.toString();
    }

    return preparedSql;
  }

  static String camelCaseToUnderscore(String camelCase){
    String result = '';
    int charNumber = 0;
    bool prevCharWasUpper = false;
    for(int char in camelCase.codeUnits){
      String c = new String.fromCharCode(char);
      bool isUpper = c == c.toUpperCase();

      if(isUpper && charNumber > 0 && !prevCharWasUpper){
        result += '_' + c.toLowerCase();
        prevCharWasUpper = true;
      }
      else{
        result += c.toLowerCase();
        if(charNumber > 0 && !isUpper){
          prevCharWasUpper = false;
        }
        else{
          prevCharWasUpper = true;
        }

      }
      charNumber++;
    }
    return result;
  }
}

class ConditionSQL {
  dynamic _firstVar = null;
  dynamic _secondVar = null;
  String _condition = null;
  String _logic = null;

  List<ConditionSQL> conditionQueue;

  ConditionSQL(dynamic this._firstVar, this._condition, dynamic this._secondVar, [this._logic = null]) {
    conditionQueue = new List<ConditionSQL>();
  }

  dynamic get firstVar => _firstVar;
  void set firstVar(var value){
    _firstVar = value;
  }

  dynamic get secondVar => _secondVar;
  void set secondVar(var value){
    _secondVar = value;
  }

  ConditionSQL and(ConditionSQL cond) {
    cond._logic = ConditionLogic.AND;
    conditionQueue.add(cond);
    return this;
  }

  or(ConditionSQL cond) {
    cond._logic = ConditionLogic.OR;
    conditionQueue.add(cond);
    return this;
  }

  String toSql() {
    String sql = this._toSql();

    for (ConditionSQL cond in conditionQueue) {
      if (cond._logic != null) {
        sql += ' ' + cond._logic + ' (';
      }

      sql += cond.toSql();

      if (cond._logic != null) {
        sql += ')';
      }
    }

    return sql;
  }

  String _toSql() {
    if(!(_firstVar is TypedSQL)){
      _firstVar = getTypedSqlFromValue(_firstVar);
    }
    if(!(_secondVar is TypedSQL)){
      _secondVar = getTypedSqlFromValue(_secondVar);
    }
    return _firstVar.toSql() + ' ' + _condition + ' ' + _secondVar.toSql();
  }
}

class EqualsSQL extends ConditionSQL {
  EqualsSQL(var firstVar, var secondVar, [String logic]): super(firstVar, '=', secondVar, logic);
}

class InSQL extends ConditionSQL {
  InSQL(var firstVar, var secondVar, [String logic]): super(firstVar, 'IN', secondVar, logic);
}

class NotInSQL extends ConditionSQL {
  NotInSQL(var firstVar, var secondVar, [String logic]): super(firstVar, 'NOT IN', secondVar, logic);
}

class NotEqualsSQL extends ConditionSQL {
  NotEqualsSQL(var firstVar, var secondVar, [String logic]): super(firstVar, '<>', secondVar, logic);
}

class LowerThanSQL extends ConditionSQL {
  LowerThanSQL(var firstVar, var secondVar, [String logic]): super(firstVar, '<', secondVar, logic);
}

class BiggerThanSQL extends ConditionSQL {
  BiggerThanSQL(var firstVar, var secondVar, [String logic]): super(firstVar, '>', secondVar, logic);
}

class JoinSQL {
  String _joinType = null;
  String _tableName = null;
  String _tableAlias = null;
  ConditionSQL _joinCondition = null;

  JoinSQL(this._joinType, this._tableName, this._tableAlias, this._joinCondition);

  toSql() {
    String sql = '';
    sql += '\n' + this._joinType.toUpperCase() + ' JOIN ';
    sql += this._tableName;
    sql += ' AS ' + this._tableAlias;
    sql += '\n ON ' + this._joinCondition.toSql();
    return sql;
  }
}

class SelectSQL extends SQL {
  List<String> _columnsToSelect = null;
  String _tableName = null;
  String _tableAlias = null;
  ConditionSQL _where = null;
  List<JoinSQL> _joins = new List<JoinSQL>();
  Map<String, String> _sorts = new Map<String, String>();

  SelectSQL(List<String> columnsToSelect) {
    this._columnsToSelect = columnsToSelect;
  }

  table(String tableName, [String tableAlias]) {
    this._tableName = tableName;
    this._tableAlias = tableAlias;
  }

  join(String joinType, String tableName, String tableAlias, ConditionSQL joinCondition) {
    this._joins.add(new JoinSQL(joinType, tableName, tableAlias, joinCondition));
  }

  leftJoin(String tableName, String tableAlias, ConditionSQL joinCondition) {
    this._joins.add(new JoinSQL('LEFT', tableName, tableAlias, joinCondition));
  }

  rightJoin(String tableName, String tableAlias, ConditionSQL joinCondition) {
    this._joins.add(new JoinSQL('RIGHT', tableName, tableAlias, joinCondition));
  }

  where(ConditionSQL cond) {
    this._where = cond;
  }

  orderBy(String fieldName, String order) {
    _sorts[fieldName] = order;
  }

  toSql() {
    String sql = 'SELECT ';
    sql += this._columnsToSelect.join(', \n       ');
    sql += ' \nFROM ' + this._tableName;

    if (this._tableAlias != null) {
      sql += ' AS ' + this._tableAlias;
    }

    if (this._joins.length > 0) {
      for (JoinSQL j in this._joins) {
        sql += j.toSql();
      }
    }

    if (this._where != null) {
      sql += '\nWHERE ' + this._where.toSql();
    }

    if (this._sorts.length > 0) {
      sql += '\nORDER BY ';
      List<String> sorts = new List<String>();
      for (String sortField in _sorts.keys) {
        sorts.add(sortField + ' ' + _sorts[sortField]);
      }
      sql += sorts.join(', ');
    }

    return this._toSql(sql);
  }
}

class UpdateSQL {
  String _tableName;
  LinkedHashMap<String, TypedSQL> _fieldsToUpdate = new LinkedHashMap<String, TypedSQL>();
  ConditionSQL _condition;

  UpdateSQL(String this._tableName);

  set(String fieldName, TypedSQL fieldValue) {
    _fieldsToUpdate[fieldName] = fieldValue;
  }

  where(ConditionSQL cond) {
    _condition = cond;
  }

  String toSql() {
    String sql = 'UPDATE $_tableName ';
    sql += '\nSET ';

    List<String> fields = new List<String>();


    _fieldsToUpdate.forEach((String fieldName, TypedSQL fieldValue) {
      fields.add(fieldName + ' = ' + fieldValue.toSql());
    });

    sql += fields.join(',\n    ');

    sql += '\nWHERE ' + _condition.toSql();

    return sql;
  }
}

class InsertSQL {
  String _tableName;
  LinkedHashMap<String, TypedSQL> _fieldsToInsert = new LinkedHashMap<String, TypedSQL>();

  InsertSQL(String this._tableName);

  value(String fieldName, TypedSQL fieldValue) {
    _fieldsToInsert[fieldName] = fieldValue;
  }

  String toSql() {
    List<String> fieldNames = new List<String>();
    List<String> fieldValues = new List<String>();

    _fieldsToInsert.forEach((String fieldName, TypedSQL fieldValue) {
      if (fieldValue != null) {
        fieldNames.add(fieldName);
        fieldValues.add(fieldValue.toSql());
      }

    });

    String sql = 'INSERT INTO $_tableName (\n    ';
    sql += fieldNames.join(',\n    ');
    sql += ')\n';
    sql += 'VALUES (\n    ';
    sql += fieldValues.join(',\n    ');
    sql += '\n);';

    return sql;
  }
}

class DBFieldSQL {
  bool _isPrimaryKey = false;
  bool _isUnique = false;
  String _type;

  /**
   * Database field name.
   * This field is converted from _propertyName to underscore notation.
   */
  String _fieldName;

  /**
   * Model property name.
   */
  String _propertyName;

  dynamic _defaultValue;
  Symbol _constructedFromPropertyName;

  bool get isPrimaryKey => _isPrimaryKey;

  void set isPrimaryKey(bool isPrimaryKey) {
    _isPrimaryKey = isPrimaryKey;
  }

  bool get isUnique => _isUnique;

  void set isUnique(bool isUnique) {
    _isUnique = isUnique;
  }

  String get type => _type;

  void set type(String type) {
    _type = type;
  }

  String get fieldName => _fieldName;

  void set fieldName(String name) {
    _fieldName = name;
  }

  String get propertyName => _propertyName;
  void set propertyName(String propertyName){
    _propertyName = propertyName;
    _fieldName = SQL.camelCaseToUnderscore(propertyName);
  }

  dynamic get defaultValue => _defaultValue;

  void set defaultValue(dynamic defaultValue) {
    _defaultValue = defaultValue;
  }

  Symbol get constructedFromPropertyName => _constructedFromPropertyName;

  void set constructedFromPropertyName(Symbol constructedFrom) {
    _constructedFromPropertyName = constructedFrom;
  }

  String toSql() {
    String fieldDefinition = _fieldName + ' ' + _type;

    if (_isPrimaryKey) {
      fieldDefinition += ' PRIMARY KEY';
    }

    if (_defaultValue != null) {
      fieldDefinition += ' DEFAULT ' + _defaultValue.toString();
    }

    if (_isUnique) {
      fieldDefinition += ' UNIQUE';
    }

    return fieldDefinition;
  }
}

class DBTableSQL {
  /**
   * Model class name.
   */
  String _className;

  /**
   * Database table name. Converted from _className to underscore notation.
   */
  String _tableName;

  List<DBFieldSQL> _fields = new List<DBFieldSQL>();

  String get className => _className;
  void set className(String className){
    _className = className;
    _tableName = SQL.camelCaseToUnderscore(className);
  }

  String get tableName => _tableName;

  void set tableName(String name) {
    _tableName = name;
  }

  List<DBFieldSQL> get fields => _fields;

  void set fields(List<DBFieldSQL> fields) {
    _fields = fields;
  }

  String toSql() {
    String tableName = _tableName;
    String sql = 'CREATE TABLE $tableName (';

    List<String> fieldDefinitions = new List<String>();

    for (DBFieldSQL f in _fields) {
      String fieldDefinition = '\n    ' + f.toSql();
      fieldDefinitions.add(fieldDefinition);
    }

    sql += fieldDefinitions.join(',');
    sql += '\n);';

    return sql;
  }
}