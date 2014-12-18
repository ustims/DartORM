part of dart_orm;


abstract class DBAdapter {
  static final String ErrTableNotExist = 'Table does not exist';
  static final String ErrColumnNotExist = 'Column does not exist';
  static final String ErrUnknown = 'Unknown database error';

  dynamic select(Select selectSql);

  dynamic execute(dynamic sql);
}
