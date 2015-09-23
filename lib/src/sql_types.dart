library dart_orm.sql_types;

abstract class TypedSQL<T> {
  final T value;

  TypedSQL(this.value);

  String toSql();
}

class RawSQL extends TypedSQL {
  RawSQL(dynamic value) : super(value);

  String toSql() => value.toString();
}

class StringSQL extends TypedSQL<String> {
  StringSQL(String value) : super(value);

  String toSql() => "'$value'";
}

class NullSQL extends TypedSQL {
  NullSQL() : super(null);

  String toSql() => 'NULL';
}

class ListSQL extends TypedSQL<List> {
  ListSQL(List list) : super(list);

  String toSql() => '(${value.join(',')})';
}

class DateTimeSQL extends TypedSQL<DateTime> {
  DateTimeSQL(DateTime datetime) : super(datetime);

  String toSql() => "'${value.toIso8601String()}'";
}
