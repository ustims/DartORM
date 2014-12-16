part of dart_orm;


class PostgresqlAdapter extends SQLAdapter with DBAdapter {
  PostgresqlAdapter(dynamic connection): super(connection);

  String parseError(String errorCode) {
    throw new Exception('This should not be called.');
  }

  dynamic query(Select selectSql) {
    Completer completer = new Completer();

    super.query(selectSql)
    .then((result) {
      completer.complete(result);
    })
    .catchError((err) {
      switch (err.serverMessage.errorCode) {
        case '42P01':
          completer.completeError(new Exception(DBAdapter.ErrTableNotExist));
          break;
        case '42703':
          completer.completeError(new Exception(DBAdapter.ErrColumnNotExist));
          break;
      }
    });

    return completer.future;
  }
}