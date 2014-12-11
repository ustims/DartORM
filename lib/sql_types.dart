abstract class TypedSQL {
  String toSql();
}

class RawSQL extends TypedSQL {
  dynamic _value;

  RawSQL(dynamic this._value);

  String toSql() {
    return _value.toString();
  }
}

class StringSQL extends TypedSQL {
  String _value;

  StringSQL(String this._value);

  String toSql() {
    return "'$_value'";
  }
}

class NullSQL extends TypedSQL {
  NullSQL();

  String toSql() {
    return 'NULL';
  }
}

class ListSQL extends TypedSQL {
  List<dynamic> _list;

  ListSQL(dynamic this._list);

  String toSql() {
    return '(' + _list.join(',') + ')';
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