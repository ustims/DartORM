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
    return 'NULL';
  }
}

class ListSQL extends TypedSQL {
  ListSQL(List list): super(list);

  String toSql() {
    return '(' + _value.join(',') + ')';
  }
}