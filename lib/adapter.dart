part of dart_orm;


abstract class DBAdapter {
  static final String ErrTableNotExist = 'Table does not exist';
  static final String ErrColumnNotExist = 'Column does not exist';
  static final String ErrUnknown = 'Unknown database error';

  Future<List> select(Select selectSql);

  Future<int> insert(Insert insert);

  Future<int> update(Update update);

  Future createTable(Table table);
}
