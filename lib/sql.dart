part of dart_orm;


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

  dynamic get condition => _condition;
  void set condition(String condition){
    _condition = condition;
  }

  String get logic => _logic;
  void set logic(String logic){
    _logic = logic;
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

  //----------------------------------------------------------
  // Getters & setters
  //----------------------------------------------------------
  String get joinType => _joinType;
  String get tableName => _tableName;
  String get tableAlias => _tableAlias;
  ConditionSQL get joinCondition => _joinCondition;
  //----------------------------------------------------------
  // /Getters & setters
  //----------------------------------------------------------
}

class SelectSQL extends SQL {
  List<String> _columnsToSelect = null;
  String _tableName = null;
  String _tableAlias = null;
  ConditionSQL _condition = null;
  List<JoinSQL> _joins = new List<JoinSQL>();
  Map<String, String> _sorts = new Map<String, String>();
  int _limit = null;
  int _offset = null;

  SelectSQL(List<String> columnsToSelect) {
    this._columnsToSelect = columnsToSelect;
  }

  //----------------------------------------------------------
  // Getters & setters
  //----------------------------------------------------------
  List<String> get columnsToSelect => _columnsToSelect;
  void set columnsToSelect(List<String> columnsList){
    _columnsToSelect = columnsList;
  }

  String get tableName => _tableName;
  String get tableAlias => _tableAlias;

  ConditionSQL get condition => _condition;
  List<JoinSQL> get joins => _joins;
  Map<String, String> get sorts => _sorts;

  int get limit => _limit;
  void set limit(int limit) {
    this._limit = limit;
  }
  void setLimit(int limit){
    this._limit = limit;
  }

  int get offset => _offset;
  void set offset(int offset) {
    this._offset = offset;
  }
  void setOffset(int offset){
    _offset = offset;
  }
  //----------------------------------------------------------
  // /Getters & setters
  //----------------------------------------------------------

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
    this._condition = cond;
  }

  orderBy(TypedSQL fieldName, String order) {
    _sorts[fieldName.toSql()] = order;
  }
}

class UpdateSQL {
  String _tableName;
  LinkedHashMap<String, TypedSQL> _fieldsToUpdate = new LinkedHashMap<String, TypedSQL>();
  ConditionSQL _condition;

  UpdateSQL(String this._tableName);

  String get tableName => tableName;
  LinkedHashMap<String, TypedSQL> get fieldsToUpdate => _fieldsToUpdate;
  ConditionSQL get condition => _condition;

  set(String fieldName, TypedSQL fieldValue) {
    _fieldsToUpdate[fieldName] = fieldValue;
  }

  where(ConditionSQL cond) {
    _condition = cond;
  }
}

class InsertSQL {
  String _tableName;
  LinkedHashMap<String, TypedSQL> _fieldsToInsert = new LinkedHashMap<String, TypedSQL>();

  InsertSQL(String this._tableName);

  LinkedHashMap<String, TypedSQL> get fieldsToInsert => _fieldsToInsert;
  String get tableName => _tableName;

  value(String fieldName, TypedSQL fieldValue) {
    _fieldsToInsert[fieldName] = fieldValue;
  }
}

/**
 * Represents database field.
 */
class DBFieldSQL {
  bool _isPrimaryKey = false;
  bool _isUnique = false;

  /**
   * Raw database type string. For example: TIMESTAMP
   */
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
}