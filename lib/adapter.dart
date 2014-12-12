import 'dart:async';

abstract class OrmDBAdapter {
  static final String ErrTableNotExist = 'Table does not exist';
  static final String ErrColumnNotExist = 'Column does not exist';
  static final String ErrUnknown = 'Unknown database error';

  dynamic _connection;

  OrmDBAdapter(dynamic connection) {
    _connection = connection;
  }

  get connection => _connection;

  dynamic query(String sql) {
    return _connection.query(sql);
  }

  dynamic execute(String sql) {
    return _connection.execute(sql);
  }

  /**
   * Parses database error and return unified
   * error for all database providers
   */
  String parseError(String errorCode);
}