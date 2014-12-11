
import 'package:dart_orm/annotations.dart';
import 'package:dart_orm/orm.dart';
import 'package:dart_orm/sql.dart';

import 'package:postgresql/postgresql.dart';

@DBTable()
class SomeUser extends OrmModel {
  @DBField()
  @DBFieldPrimaryKey()
  @DBFieldType('SERIAL')
  int id;

  @DBField()
  String givenName;

  @DBField()
  String familyName;
}

void main(){
  // This will scan current isolate
  // for classes annotated with DBTable
  // and store sql definitions for them in memory
  DBAnnotationsParser.initialize();

  var uri = 'postgres://dart_test:dart_test@localhost:5432/dart_test';
  connect(uri).then((conn) {
    // orm initialization
    OrmModel.setConnection(conn);
    // this will try to select current
    // schema version from database, and if it is empty -
    // create all the tables for found classes annotated with @DBTable
    return OrmModel.migrate();
  })
  .then((migrationResult) {
    // lets try to save some user
    SomeUser u = new SomeUser();
    u.givenName = 'Sergey';
    u.familyName = 'Ustimenko';

    return u.save();
  })
  .then((saveResult) {
    assert(saveResult > 0);

    // lets try simple one-row select by id
    FindOne f = new FindOne(SomeUser)
      ..whereEquals('id', 1); // whereEquals is just a shortcut for .where(new EqualsSQL('id', 1))

    return f.execute();
  })
  .then((SomeUser user) {
    assert(user.id == 1);
    assert(user.givenName == 'Sergey');

    // now lets try something not so simple
    Find f = new Find(SomeUser)
      ..where(new LowerThanSQL('id', 3)
        .and(new EqualsSQL('givenName', 'Sergey')
          .or(new EqualsSQL('familyName', 'Ustimenko'))
        )
      )
      ..orderBy('id', 'DESC')
      ..limit(10);

    print(f.toSql());

    return f.execute();
  })
  .then((List foundUsers) {
    assert(foundUsers.length > 0);
    assert(foundUsers[0].givenName == 'Sergey');
  })
  .catchError((err) {
    print("Error!");
    throw err;
  });

}