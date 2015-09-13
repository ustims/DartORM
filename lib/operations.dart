part of dart_orm;

class ConditionLogic {
  static String AND = 'AND';
  static String OR = 'OR';
  static String IN = 'IN';
}

class SQL {
  static String camelCaseToUnderscore(String camelCase) {
    String result = '';
    int charNumber = 0;
    bool prevCharWasUpper = false;
    for (int char in camelCase.codeUnits) {
      String c = new String.fromCharCode(char);
      bool isUpper = c == c.toUpperCase();

      if (isUpper && charNumber > 0 && !prevCharWasUpper) {
        result += '_' + c.toLowerCase();
        prevCharWasUpper = true;
      } else {
        result += c.toLowerCase();
        if (charNumber > 0 && !isUpper) {
          prevCharWasUpper = false;
        } else {
          prevCharWasUpper = true;
        }
      }
      charNumber++;
    }
    return result;
  }
}

class Condition {
  /**
   * First variable for comparation.
   */
  dynamic _firstVar = null;

  /**
   * Second variable for comparation.
   */
  dynamic _secondVar = null;

  /**
   * Variable comparation rule. For example: '=' or '<'.
   */
  String _condition = null;

  /**
   * Condition logic.
   * Can be not-null obly if this condition
   * is appended to another condition and here will be append
   * logic such as 'AND' or 'OR'
   */
  String _logic = null;

  List<Condition> conditionQueue;

  Condition(
      dynamic this._firstVar, String this._condition, dynamic this._secondVar,
      [this._logic = null]) {
    conditionQueue = new List<Condition>();
  }

  dynamic get firstVar => _firstVar;

  void set firstVar(var value) {
    _firstVar = value;
  }

  dynamic get secondVar => _secondVar;

  void set secondVar(var value) {
    _secondVar = value;
  }

  dynamic get condition => _condition;

  void set condition(String condition) {
    _condition = condition;
  }

  String get logic => _logic;

  void set logic(String logic) {
    _logic = logic;
  }

  Condition and(Condition cond) {
    cond._logic = ConditionLogic.AND;
    conditionQueue.add(cond);
    return this;
  }

  or(Condition cond) {
    cond._logic = ConditionLogic.OR;
    conditionQueue.add(cond);
    return this;
  }
}

class Equals extends Condition {
  Equals(var firstVar, var secondVar, [String logic])
      : super(firstVar, '=', secondVar, logic);
}

class In extends Condition {
  In(var firstVar, var secondVar, [String logic])
      : super(firstVar, 'IN', secondVar, logic);
}

class NotIn extends Condition {
  NotIn(var firstVar, var secondVar, [String logic])
      : super(firstVar, 'NOT IN', secondVar, logic);
}

class NotEquals extends Condition {
  NotEquals(var firstVar, var secondVar, [String logic])
      : super(firstVar, '<>', secondVar, logic);
}

class LowerThan extends Condition {
  LowerThan(var firstVar, var secondVar, [String logic])
      : super(firstVar, '<', secondVar, logic);
}

class BiggerThan extends Condition {
  BiggerThan(var firstVar, var secondVar, [String logic])
      : super(firstVar, '>', secondVar, logic);
}

class Join {
  String joinType = null;
  String tableName = null;
  String tableAlias = null;
  Condition joinCondition = null;

  Join(this.joinType, this.tableName, this.tableAlias, this.joinCondition);
}

class Select extends SQL {
  List<String> columnsToSelect = null;

  Table table = null;

  Condition _condition = null;
  List<Join> _joins = new List<Join>();
  Map<String, String> _sorts = new Map<String, String>();
  int limit = null;
  int offset = null;

  Select(List<String> columnsToSelect) {
    this.columnsToSelect = columnsToSelect;
  }

  Condition get condition => _condition;

  List<Join> get joins => _joins;

  Map<String, String> get sorts => _sorts;

  void setLimit(int limit) {
    this.limit = limit;
  }

  void setOffset(int offset) {
    this.offset = offset;
  }

  join(String joinType, String tableName, String tableAlias,
      Condition joinCondition) {
    this._joins.add(new Join(joinType, tableName, tableAlias, joinCondition));
  }

  leftJoin(String tableName, String tableAlias, Condition joinCondition) {
    this._joins.add(new Join('LEFT', tableName, tableAlias, joinCondition));
  }

  rightJoin(String tableName, String tableAlias, Condition joinCondition) {
    this._joins.add(new Join('RIGHT', tableName, tableAlias, joinCondition));
  }

  where(Condition cond) {
    this._condition = cond;
  }

  orderBy(fieldName, String order) {
    _sorts[fieldName] = order;
  }

  String toString() {
    return 'SELECT ' + columnsToSelect.join(',') + ' FROM ' + table.tableName;
  }
}

class Update {
  Table table;

  LinkedHashMap<String, dynamic> fieldsToUpdate =
      new LinkedHashMap<String, dynamic>();

  Condition _condition;

  Update(Table this.table);

  Condition get condition => _condition;

  set(String fieldName, dynamic fieldValue) {
    fieldsToUpdate[fieldName] = fieldValue;
  }

  where(Condition cond) {
    _condition = cond;
  }
}

class Delete {
  Table table;

  Condition _condition;

  Delete(Table this.table);

  Condition get condition => _condition;

  where(Condition cond) {
    _condition = cond;
  }
}

class Insert {
  Table table;
  LinkedHashMap<String, dynamic> _fieldsToInsert =
      new LinkedHashMap<String, dynamic>();

  Insert(Table this.table);

  LinkedHashMap<String, dynamic> get fieldsToInsert => _fieldsToInsert;

  value(String fieldName, dynamic fieldValue) {
    _fieldsToInsert[fieldName] = fieldValue;
  }
}

/**
 * Represents database field.
 */
class Field {
  bool isPrimaryKey = false;
  bool isUnique = false;

  /**
   * Raw database type string. For example: TIMESTAMP
   */
  String type;

  /**
   * Database column name.
   */
  String fieldName;

  /**
   * Model property name.
   */
  String propertyName;

  /**
   * Name of the Dart type this field is attached to.
   */
  String propertyTypeName;

  dynamic defaultValue;
  Symbol constructedFromPropertyName;
  
  /**
   *  Converter for value
   */
  FieldConverter converter = null; 
}

class Table {
  /**
   * Model class name.
   */
  String _className;

  /**
   * Database table name. Converted from _className to underscore notation.
   */
  String tableName;

  List<Field> fields = new List<Field>();

  String get className => _className;

  void set className(String className) {
    _className = className;
    tableName = SQL.camelCaseToUnderscore(className);
  }

  Field getPrimaryKeyField() {
    for (Field f in fields) {
      if (f.isPrimaryKey) {
        return f;
      }
    }
    return null;
  }
}
