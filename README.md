Dart ORM
========

Easy-to-use and easy-to-setup database ORM for dart.

It is in the very beginning stage of development and not ready for production use.
Feel free to contribute!

Feature tour
============

If you want to jump to example code click here: https://github.com/ustims/DartORM/blob/master/example/example.dart

Annotations
-----------

```dart
import 'package:dart_orm/annotations.dart';

// every DartORM class should extend OrmModel
@DBTable()
class SomeUser extends OrmModel {
  // Every field that needs to be stored in database should be annotated with @DBField
  @DBField()
  @DBFieldPrimaryKey()
  // Database field type can be overridden to database-engine specific type
  // By default a property annotated with DBFieldPrimaryKey will set field type to SERIAL
  // So this is for example.
  @DBFieldType('SERIAL')
  int id;

  @DBField()
  String givenName;

  // Database field name will be converted to underscore
  // for example: family_name in this case,
  // but this can be overridden by
  // providing string argument to the annotation constructor
  @DBField('family_name')
  String familyName;
}
```

With such annotated class when you first run OrmModel.migrate()

it will execute such statement:

```sql
CREATE TABLE some_user (
    id SERIAL PRIMARY KEY,
    given_name text,
    family_name text
);
```

Migrations, schema versions and diffs will be implemented later.

Inserts and updates
-------------------

Every OrmModel has .save() method which will update/insert new row.

If class instance has 'id' field with not-null value, .save() will execute 'UPDATE' statement with 'WHERE id = $id'.

If class instance has null 'id' field, 'INSERT' statement will be executed.

```dart
SomeUser u = new SomeUser();
u.givenName = 'Sergey';
u.familyName = 'Ustimenko';

u.save() // returns Future
.then((result){
})
```

This statement will be executed on save():

```sql
INSERT INTO some_user (
    given_name,
    family_name)
VALUES (
    'Sergey',
    'Ustimenko'
);
```

Finding records
---------------

Package dart_orm/orm.dart has two classes for finding records: Find and FindOne.

Constructors receives a class that extends OrmModel.

```dart
// Find and FindOne classes are here
import 'package:dart_orm/orm.dart';
// Sql construction helpers such as EqualsSQL are here
import 'package:dart_orm/sql.dart';

Find f = new Find(SomeUser)
  ..where(new LowerThanSQL('id', 3)
    .and(new EqualsSQL('givenName', 'Sergey')
      .or(new EqualsSQL('familyName', 'Ustimenko'))
    )
  )
  ..orderBy('id', 'DESC')
  ..limit(10)
  ..execute()
  .then((List<SomeUser> foundUsers) {
    for(SomeUser u in foundUsers){
      print('Found user:');
      print(u);
    }
  });
```

This will result such statement executed on the database:

```sql
SELECT *
FROM some_user
WHERE id < 3 AND (given_name = 'Sergey' OR (family_name = 'Ustimenko'))
ORDER BY id DESC LIMIT 10
```