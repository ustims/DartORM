part of dart_orm;


class PostgresqlAdapter extends SQLAdapter with DBAdapter {
  PostgresqlAdapter(dynamic connection): super(connection);

  Future select(Select selectSql) async {
    try {
      var result = await super.select(selectSql);
      return result;
    } catch(e){
      switch (e.serverMessage.code) {
        case '42P01':
          throw new Exception(DBAdapter.ErrTableNotExist);
          break;
        case '42703':
          throw new Exception(DBAdapter.ErrColumnNotExist);
          break;
      }

      throw new Exception(DBAdapter.ErrUnknown);
    }
  }
}