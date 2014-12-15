part of dart_orm;


abstract class OrmDBAdapter {
  static final String ErrTableNotExist = 'Table does not exist';
  static final String ErrColumnNotExist = 'Column does not exist';
  static final String ErrUnknown = 'Unknown database error';

  /**
   * Parses database error and return unified
   * error for all database providers
   */
  String parseError(String errorCode);

  dynamic query(SelectSQL selectSql);

  dynamic execute(dynamic sql);
}
