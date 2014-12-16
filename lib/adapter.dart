part of dart_orm;


abstract class DBAdapter {
  static final String ErrTableNotExist = 'Table does not exist';
  static final String ErrColumnNotExist = 'Column does not exist';
  static final String ErrUnknown = 'Unknown database error';

  /**
   * Parses database error and return unified
   * error for all database providers
   */
  String parseError(String errorCode);

  dynamic query(Select selectSql);

  dynamic execute(dynamic sql);
}
