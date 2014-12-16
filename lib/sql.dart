part of dart_orm;


class ConditionLogic {
  static String AND = 'AND';
  static String OR = 'OR';
  static String IN = 'IN';
}

// TODO: move this somewhere
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

  Condition(dynamic this._firstVar, this._condition, dynamic this._secondVar, [this._logic = null]) {
    conditionQueue = new List<Condition>();
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
  Equals(var firstVar, var secondVar, [String logic]): super(firstVar, '=', secondVar, logic);
}

class In extends Condition {
  In(var firstVar, var secondVar, [String logic]): super(firstVar, 'IN', secondVar, logic);
}

class NotIn extends Condition {
  NotIn(var firstVar, var secondVar, [String logic]): super(firstVar, 'NOT IN', secondVar, logic);
}

class NotEquals extends Condition {
  NotEquals(var firstVar, var secondVar, [String logic]): super(firstVar, '<>', secondVar, logic);
}

class LowerThan extends Condition {
  LowerThan(var firstVar, var secondVar, [String logic]): super(firstVar, '<', secondVar, logic);
}

class BiggerThan extends Condition {
  BiggerThan(var firstVar, var secondVar, [String logic]): super(firstVar, '>', secondVar, logic);
}

class Join {
  String _joinType = null;
  String _tableName = null;
  String _tableAlias = null;
  Condition _joinCondition = null;

  Join(this._joinType, this._tableName, this._tableAlias, this._joinCondition);

  //----------------------------------------------------------
  // Getters & setters
  //----------------------------------------------------------
  String get joinType => _joinType;
  String get tableName => _tableName;
  String get tableAlias => _tableAlias;
  Condition get joinCondition => _joinCondition;
  //----------------------------------------------------------
  // /Getters & setters
  //----------------------------------------------------------
}

class Select extends SQL {
  List<String> _columnsToSelect = null;
  String _tableName = null;
  String _tableAlias = null;
  Condition _condition = null;
  List<Join> _joins = new List<Join>();
  Map<String, String> _sorts = new Map<String, String>();
  int _limit = null;
  int _offset = null;

  Select(List<String> columnsToSelect) {
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

  Condition get condition => _condition;
  List<Join> get joins => _joins;
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

  join(String joinType, String tableName, String tableAlias, Condition joinCondition) {
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

  orderBy(TypedSQL fieldName, String order) {
    _sorts[fieldName.toSql()] = order;
  }
}

class Update {
  String _tableName;
  LinkedHashMap<String, TypedSQL> _fieldsToUpdate = new LinkedHashMap<String, TypedSQL>();
  Condition _condition;

  Update(String this._tableName);

  String get tableName => tableName;
  LinkedHashMap<String, TypedSQL> get fieldsToUpdate => _fieldsToUpdate;
  Condition get condition => _condition;

  set(String fieldName, TypedSQL fieldValue) {
    _fieldsToUpdate[fieldName] = fieldValue;
  }

  where(Condition cond) {
    _condition = cond;
  }
}

class Insert {
  String _tableName;
  LinkedHashMap<String, TypedSQL> _fieldsToInsert = new LinkedHashMap<String, TypedSQL>();

  Insert(String this._tableName);

  LinkedHashMap<String, TypedSQL> get fieldsToInsert => _fieldsToInsert;
  String get tableName => _tableName;

  value(String fieldName, TypedSQL fieldValue) {
    _fieldsToInsert[fieldName] = fieldValue;
  }
}

/**
 * Represents database field.
 */
class Field {
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

  /**
   * Name of the Dart type this field is attached to.
   */
  String _propertyTypeName;

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

  String get propertyTypeName => _propertyTypeName;
  void set propertyTypeName(String propertyTypeName){
    _propertyTypeName = propertyTypeName;
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

class Table {
  /**
   * Model class name.
   */
  String _className;

  /**
   * Database table name. Converted from _className to underscore notation.
   */
  String _tableName;

  List<Field> _fields = new List<Field>();

  String get className => _className;
  void set className(String className){
    _className = className;
    _tableName = SQL.camelCaseToUnderscore(className);
  }

  String get tableName => _tableName;

  void set tableName(String name) {
    _tableName = name;
  }

  List<Field> get fields => _fields;
  void set fields(List<Field> fields) {
    _fields = fields;
  }
}