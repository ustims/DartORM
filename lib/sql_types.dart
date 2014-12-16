part of dart_orm;


abstract class TypedSQL {
  dynamic _value;
  dynamic get value => _value;

  TypedSQL(dynamic this._value);

  String toSql();
}

class RawSQL extends TypedSQL {
  RawSQL(dynamic value): super(value);

  String toSql() {
    return _value.toString();
  }
}

class StringSQL extends TypedSQL {
  StringSQL(String value): super(value);

  String toSql() {
    return "'$_value'";
  }
}

class NullSQL extends TypedSQL {
  NullSQL(): super(null);

  String toSql() {
    return 'NULL'; // TODO: this must be in sql adapter
  }
}

class ListSQL extends TypedSQL {
  ListSQL(List list): super(list);

  String toSql() {
    return '(' + _value.join(',') + ')'; // TODO: this must be in sql adapter
  }
}

TypedSQL getTypedSqlFromValue(var instanceFieldValue) {
  TypedSQL valueSql;

  if (instanceFieldValue == null) {
    valueSql = new NullSQL();
  }
  else if (instanceFieldValue is String) {
    valueSql = new StringSQL(instanceFieldValue);
  }
  else if (instanceFieldValue is List) {
      valueSql = new ListSQL(instanceFieldValue);
    }
    else {
      valueSql = new RawSQL(instanceFieldValue);
    }

  return valueSql;
}