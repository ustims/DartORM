import 'adapter.dart';

class PostgresAdapter extends OrmDBAdapter {
  PostgresAdapter(dynamic connection): super(connection);

  String parseError(String errorCode) {
    // error codes from
    // http://www.postgresql.org/docs/9.3/static/errcodes-appendix.html
    switch(errorCode) {
      case '42P01':
        return OrmDBAdapter.ErrTableNotExist;
      case '42703':
        return OrmDBAdapter.ErrColumnNotExist;
    }

    return OrmDBAdapter.ErrUnknown;
  }
}