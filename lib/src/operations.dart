library dart_orm.operations;

import 'dart:collection';
import 'dart:mirrors';

class ConditionLogic {
  static const String AND = 'AND';
  static const String OR = 'OR';
  static const String IN = 'IN';
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
  dynamic firstVar;

  /**
   * Second variable for comparation.
   */
  dynamic secondVar;

  /**
   * Variable comparation rule. For example: '=' or '<'.
   */
  String condition;

  /**
   * Condition logic.
   * Can be not-null obly if this condition
   * is appended to another condition and here will be append
   * logic such as 'AND' or 'OR'
   */
  String logic;

  List<Condition> conditionQueue;

  Condition(this.firstVar, this.condition, this.secondVar, [this.logic]) {
    conditionQueue = new List<Condition>();
  }

  Condition and(Condition cond) {
    cond.logic = ConditionLogic.AND;
    conditionQueue.add(cond);
    return this;
  }

  Condition or(Condition cond) {
    cond.logic = ConditionLogic.OR;
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
  String joinType;
  String tableName;
  String tableAlias;
  Condition joinCondition;

  Join(this.joinType, this.tableName, this.tableAlias, this.joinCondition);
}

class Select extends SQL {
  final Map<String, String> sorts = new Map<String, String>();
  final List<Join> joins = new List<Join>();

  List<String> columnsToSelect;
  Table table;
  Condition condition;
  int limit;
  int offset;

  Select(this.columnsToSelect);

  void setLimit(int limit) {
    this.limit = limit;
  }

  void setOffset(int offset) {
    this.offset = offset;
  }

  void join(String joinType, String tableName, String tableAlias,
      Condition joinCondition) {
    joins.add(new Join(joinType, tableName, tableAlias, joinCondition));
  }

  void leftJoin(String tableName, String tableAlias, Condition joinCondition) {
    joins.add(new Join('LEFT', tableName, tableAlias, joinCondition));
  }

  void rightJoin(String tableName, String tableAlias, Condition joinCondition) {
    joins.add(new Join('RIGHT', tableName, tableAlias, joinCondition));
  }

  void where(Condition cond) {
    this.condition = cond;
  }

  void orderBy(fieldName, String order) {
    sorts[fieldName] = order;
  }

  String toString() {
    return 'SELECT ' + columnsToSelect.join(',') + ' FROM ' + table.tableName;
  }
}

class Update {
  Table table;

  final LinkedHashMap<String, dynamic> fieldsToUpdate =
      new LinkedHashMap<String, dynamic>();

  Update(Table this.table);

  Condition condition;

  set(String fieldName, dynamic fieldValue) {
    fieldsToUpdate[fieldName] = fieldValue;
  }

  void where(Condition cond) {
    condition = cond;
  }
}

class Delete {
  Table table;

  Delete(Table this.table);

  Condition condition;

  void where(Condition cond) {
    condition = cond;
  }
}

class Insert {
  Table table;
  final LinkedHashMap<String, dynamic> _fieldsToInsert =
      new LinkedHashMap<String, dynamic>();

  Insert(Table this.table);

  LinkedHashMap<String, dynamic> get fieldsToInsert => _fieldsToInsert;

  void value(String fieldName, dynamic fieldValue) {
    _fieldsToInsert[fieldName] = fieldValue;
  }
}

/// Represents database field.
class Field {
  bool isPrimaryKey = false;
  bool isUnique = false;

  /// Raw database type string. For example: TIMESTAMP
  String type;

  /// Database column name.
  String fieldName;

  /// Model property name.
  String propertyName;

  /// Name of the Dart type this field is attached to.
  String propertyTypeName;

  dynamic defaultValue;
  Symbol constructedFromPropertyName;
}

/// Field that should behave as a list of values.
/// Such fields are not stored directly in the table.
///
/// Instead, a new separate [ListJoinTable] is created
/// to store only two things: reference to id of the model from original [Table]
/// and a list element value.
///
/// Example: if we have a model `User` with `List<String> emails`
/// than there will be no `emails` field in `User` [Table].
/// But there will be other table called `user_id__emails`
/// which will have two [Field]s: id of the user and an email.
/// Such table could have multiple rows for one id, emulating list values.
class ListJoinField extends Field {
  /// If this field is an array(List), than here should be stored a
  /// type of values for an array.
  ClassMirror generic;

  /// Returns Dart type string name of values stored in the list
  String get genericName => MirrorSystem.getName(this.generic.simpleName);

  /// Table that stores values of this list.
  /// Could be either [ListJoinValuesTable] or [ListJoinModelsTable]
  Table joinTable;

  /// Name of the field in [joinTable] which points to original table's
  /// primary key.
  String primaryKeyJoinFieldName;
}

/// Represents database table
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

  Type modelType;

  Field getPrimaryKeyField() {
    for (Field f in fields) {
      if (f.isPrimaryKey) {
        return f;
      }
    }
    return null;
  }

  /// Returns true is this table contains references to another tables.
  /// References are used for list fields and for fields that referencing
  /// objects from other tables.
  bool get hasReferenceFields {
    // TODO: now only lists are supported. When direct references will
    // be implemented here should be another check.
    return this.fields.any((Field f) => f is ListJoinField);
  }

  String toString() {
    return 'Instance \'Table\', name: ${this.tableName}';
  }
}

/// This table stores values for List fields whose members
/// are simple Dart types like String/int etc.
///
/// Contains only two fields: one points to original [Table] primary key,
/// second one stores the value.
class ListJoinValuesTable extends Table {
  /// [originalTable] - table which contains original model.
  /// [field] - [ListJoinField] from originalTable for which this instance is created.
  ListJoinValuesTable(Table originalTable, ListJoinField field) {
    // For simple lists we need something human-readable like
    // 'users_id__emails' which will mean that table stores emails for users
    // and those emails are linked to user id's.
    this.tableName = originalTable.tableName +
        '_' +
        originalTable.getPrimaryKeyField().fieldName +
        '__' +
        field.fieldName;

    this.primaryKeyReferenceField = new Field()
      ..fieldName = originalTable.tableName + '_id'
      ..propertyTypeName = 'int';

    this.fields.add(this.primaryKeyReferenceField);

    this.valueField = new Field()
      ..fieldName = field.fieldName
      ..propertyTypeName = field.genericName;

    this.fields.add(this.valueField);
  }

  Field primaryKeyReferenceField;
  Field valueField;

  String toString() {
    return 'Instance \'ListReferenceTable\', name: ${this.tableName}';
  }
}

/// This table stores values for lists whose members are other orm models.
/// Contains only two fields: one stores primary key of the original [Table],
/// second one stores primary key of the table whoch rows are list members of [listField].
class ListJoinModelsTable extends Table {
  ListJoinModelsTable(
      Table originalTable, ListJoinField listField, Table listMembersTable) {

    this.originalTable = originalTable;
    this.listMembersTable = listMembersTable;

    // For lists pointing to other tables, table name should explicitly say that
    // this table joins two other tables by ids.
    //
    // For example:    users_with_gadgets_id__gadgets_id
    // main table name ^                  ^   ^       ^
    // main table join by field --------- |   |       |
    // values table name ---------------------|       |
    // values table join by field --------------------|

    this.tableName = originalTable.tableName +
        '_' +
        originalTable.getPrimaryKeyField().fieldName +
        '__' +
        listMembersTable.tableName +
        '_' +
        listMembersTable.getPrimaryKeyField().fieldName;

    var listMembersTablePrimaryKey = listMembersTable.getPrimaryKeyField();

    if (listMembersTablePrimaryKey == null) {
      throw new ArgumentError(
          'If table needs to be referenced from other tables, ' +
              'it should have primary key. Please add primary key to #' +
              listMembersTable.tableName +
              '# model.');
    }

    this.listHolderPrimaryKeyReference = new Field()
      ..fieldName = originalTable.tableName +
          '_' +
          originalTable.getPrimaryKeyField().fieldName
      ..propertyTypeName = originalTable.getPrimaryKeyField().propertyTypeName;

    this.fields.add(this.listHolderPrimaryKeyReference);

    this.listMembersPrimaryKeyReference = new Field()
      ..fieldName = listMembersTable.tableName +
          '_' +
          listMembersTable.getPrimaryKeyField().fieldName
      ..propertyTypeName =
          listMembersTable.getPrimaryKeyField().propertyTypeName;

    this.fields.add(this.listMembersPrimaryKeyReference);
  }

  /// [Table] which contains models that have list property
  Table originalTable;

  /// [Table] where list members are stored
  Table listMembersTable;

  /// Primary key reference to a model which holds a list
  Field listHolderPrimaryKeyReference;

  /// Primary key reference to model which is a value for list item
  Field listMembersPrimaryKeyReference;
}
