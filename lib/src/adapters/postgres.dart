part of dart_orm;


class PostgresqlAdapter extends SQLAdapter with DBAdapter {
  PostgresqlAdapter(dynamic connection): super(connection);

  Future select(Select select) async {
    try {
      var result = await super.select(select);
      return result;
    } catch(e){
      // TODO: catch here only postgresql exceptions
      switch (e.serverMessage.code) {
        case '42P01':
          throw new TableNotExistException();
          break;
        case '42703':
          throw new ColumnNotExistException();
          break;
      }

      throw new UnknownAdapterException();
    }
  }
}