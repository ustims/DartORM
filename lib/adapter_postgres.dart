part of dart_orm;


class PostgresqlAdapter extends SQLAdapter with OrmDBAdapter {
  PostgresqlAdapter(dynamic connection): super(connection);

  String parseError(String errorCode) {
    throw new Exception('This should not be called.');
  }

//  String parseError(String errorCode) {
//    // error codes from
//    // http://www.postgresql.org/docs/9.3/static/errcodes-appendix.html
//    switch (errorCode) {
//      case '42P01':
//        return OrmDBAdapter.ErrTableNotExist;
//      case '42703':
//        return OrmDBAdapter.ErrColumnNotExist;
//    }
//
//    return OrmDBAdapter.ErrUnknown;
//  }

  dynamic query(SelectSQL selectSql) {
    Completer completer = new Completer();

    super.query(selectSql)
    .then((result) {
      completer.complete(result);
    })
    .catchError((err) {
      switch (err.serverMessage.errorCode) {
        case '42P01':
          completer.completeError(new Exception(OrmDBAdapter.ErrTableNotExist));
          break;
        case '42703':
          completer.completeError(new Exception(OrmDBAdapter.ErrColumnNotExist));
          break;
      }
    });

    return completer.future;
  }
}