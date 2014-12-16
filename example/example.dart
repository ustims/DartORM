import 'package:dart_orm/orm.dart' as ORM;

import 'package:postgresql/postgresql.dart' as psql_connector;

@ORM.DBTable('users')
class User extends ORM.Model {
  @ORM.DBField()
  @ORM.DBFieldPrimaryKey()
  @ORM.DBFieldType('SERIAL')
  int id;

  @ORM.DBField()
  String givenName;

  @ORM.DBField()
  String familyName;

  String toString(){
    return 'User { id: $id, givenName: \'$givenName\', familyName: \'$familyName\' }';
  }
}

void main(){
  // This will scan current isolate
  // for classes annotated with DBTable
  // and store sql definitions for them in memory
  ORM.AnnotationsParser.initialize();

  var uri = 'postgres://dart_test:dart_test@localhost:5432/dart_test';
  psql_connector.connect(uri).then((conn) {
    ORM.Model.ormAdapter = new ORM.PostgresqlAdapter(conn);
    //OrmModel.ormAdapter = new MemoryAdapter();

    // this will try to select current
    // schema version from database, and if it is empty -
    // create all the tables for found classes annotated with @DBTable
    return ORM.Migrator.migrate();
  })
  .then((migrationResult) {
    // lets try to save some user
    User u = new User();
    u.givenName = 'Sergey';
    u.familyName = 'Ustimenko';

    return u.save();
  })
  .then((saveResult) {
    assert(saveResult > 0);

    // lets try simple one-row select by id
    ORM.FindOne f = new ORM.FindOne(User)
      ..whereEquals('id', 1); // whereEquals is just a shortcut for .where(new EqualsSQL('id', 1))

    return f.execute();
  })
  .then((User user) {
    assert(user.id == 1);
    assert(user.givenName == 'Sergey');

    print('Found user:');
    print(user.toString());

    // now lets try something not so simple
    ORM.Find f = new ORM.Find(User)
      ..where(new ORM.LowerThan('id', 3)
        .and(new ORM.Equals('givenName', 'Sergey')
          .or(new ORM.Equals('familyName', 'Ustimenko'))
        )
      )
      ..orderBy('id', 'DESC')
      ..setLimit(10);

    return f.execute();
  })
  .then((List foundUsers) {
    assert(foundUsers.length > 0);
    assert(foundUsers[0].givenName == 'Sergey');

    print('Found list of users:');
    print(foundUsers);
  })
  .catchError((err) {
    print("Error!");
    throw err;
  });

}