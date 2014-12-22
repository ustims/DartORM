part of dart_orm;

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

  Future createTable(Table table);
}

class AdapterException implements Exception {
  static final String ErrTableNotExist = 'Table does not exist';
  static final String ErrColumnNotExist = 'Column does not exist';
  static final String ErrUnknown = 'Unknown database error';

  String message;
  AdapterException(this.message);
}

class TableNotExistException extends AdapterException {
  TableNotExistException(): super(AdapterException.ErrTableNotExist);
}

class ColumnNotExistException extends AdapterException {
  ColumnNotExistException(): super(AdapterException.ErrColumnNotExist);
}

class UnknownAdapterException extends AdapterException {
  UnknownAdapterException(): super(AdapterException.ErrUnknown);
}