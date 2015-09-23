library dart_orm.adapter;

import 'dart:async';

import 'operations.dart';

/**
 * Base interface with database operations methods.
 */
abstract class DBAdapter {
  Future connect();

  /**
   * Must return a list of maps which keys are column names
   * and values are values from db.
   */
  Future<List<Map>> select(Select selectSql);

  /**
   * Must insert a row and return a number as primaryKey
   * if model contains primary key definition, or 0 if model does not
   * have a primary key definition.
   *
   * TODO: refactor this not only for int pkeys but for strings etc.
   */
  Future<int> insert(Insert insert);

  /**
   * Must update a row and return 1 as number of affected rows.
   */
  Future<int> update(Update update);

  /**
   * Must delete a row.
   */
  Future<int> delete(Delete delete);

  /**
   * Must create a table/collection.
   */
  Future createTable(Table table);
}

/**
 * Unified database exception wrapper.
 *
 * Database drivers raise exceptions in theirs own format
 * with own error codes etc.
 *
 * Adapter implementation must wrap all those exceptions to one of the below.
 */
class AdapterException implements Exception {
  static const String ErrTableNotExist = 'Table does not exist';
  static const String ErrColumnNotExist = 'Column does not exist';
  static const String ErrUnknown = 'Unknown database error';

  final String message;

  AdapterException(this.message);
}

class TableNotExistException extends AdapterException {
  TableNotExistException() : super(AdapterException.ErrTableNotExist);
}

class ColumnNotExistException extends AdapterException {
  ColumnNotExistException() : super(AdapterException.ErrColumnNotExist);
}

class UnknownAdapterException extends AdapterException {
  final dynamic originalException;

  UnknownAdapterException(this.originalException)
      : super(AdapterException.ErrUnknown);

  String toString() {
    return originalException.toString();
  }
}
