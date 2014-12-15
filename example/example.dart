import 'package:dart_orm/orm.dart';

import 'package:postgresql/postgresql.dart' as psql_connector;

@DBTable('users')
class User extends OrmModel {
  @DBField()
  @DBFieldPrimaryKey()
  @DBFieldType('SERIAL')
  int id;

  @DBField()
  String givenName;

  @DBField()
  String familyName;

  String toString(){
    return 'User { id: $id, givenName: \'$givenName\', familyName: \'$familyName\' }';
  }
}

//@DBTable()
//class Comment {
//  @DBField()
//  @DBFieldPrimaryKey()
//  int id;
//
//  @DBField()
//  User postedBy;
//
//  @DBField()
//  List<User> likedBy;
//
//  @DBField()
//  String commentBody;
//}

void main(){
  // This will scan current isolate
  // for classes annotated with DBTable
  // and store sql definitions for them in memory
  OrmAnnotationsParser.initialize();

  var uri = 'postgres://dart_test:dart_test@localhost:5432/dart_test';
  psql_connector.connect(uri).then((conn) {
    OrmModel.ormAdapter = new PostgresqlAdapter(conn);
    //OrmModel.ormAdapter = new MemoryAdapter();

    // this will try to select current
    // schema version from database, and if it is empty -
    // create all the tables for found classes annotated with @DBTable
    return OrmMigrator.migrate();
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
    FindOne f = new FindOne(User)
      ..whereEquals('id', 1); // whereEquals is just a shortcut for .where(new EqualsSQL('id', 1))

    return f.execute();
  })
  .then((User user) {
    assert(user.id == 1);
    assert(user.givenName == 'Sergey');

    print('Found user:');
    print(user.toString());

    // now lets try something not so simple
    Find f = new Find(User)
      ..where(new LowerThanSQL('id', 3)
        .and(new EqualsSQL('givenName', 'Sergey')
          .or(new EqualsSQL('familyName', 'Ustimenko'))
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