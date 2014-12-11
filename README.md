Dart ORM
========

Easy-to-use and easy-to-setup database ORM for dart.

It is in the very beginning stage of development and not ready for production use.
Feel free to contribute!

Feature tour
============

If you want jump to example code click here: https://github.com/ustims/DartORM/blob/master/example/example.dart

Annotations
-----------


Classes and fields can be annotated like this

```dart
import 'package:dart_orm/annotations.dart';

@DBTable()
class User extends ORMModel { // every DartORM class should extend ORMModel
  @DBField() // Every field that needs to be stored in database should be annotated with @DBField
  @DBFieldPrimaryKey()
  @DBFieldType('SERIAL') // Database field type can be overridden to database-engine specific type
  int id;

  @DBField()
  String givenName;

  @DBField('family_name') // Database field name can be provided
  String familyName;
}
```

Inserts and updates
-------------------

Every ORMModel has .save() method which will update/insert new row.
If class instance has 'id' field with not-null value, .save() will execute 'UPDATE' statement with 'WHERE id = $id'.
If class instance has null 'id' field, 'INSERT' statement will be executed.

```dart
User u = new User();
u.givenName = 'Sergey';
u.familyName = 'Ustimenko';

u.save() // returns Future
.then((result){
})
```

Finding records
---------------

Package dart_orm/orm.dart has two classes for finding records: Find and FindOne.
Constructors receives a class that extends ORMMModel.

```dart
import 'package:dart_orm/orm.dart'; // Find and FindOne classes are here
import 'package:dart_orm/sql.dart'; // Sql construction helpers such as EqualsSQL are here

Find f = new Find(User)
  ..where(new LowerThanSQL('id', 3)
    .and(new EqualsSQL('givenName', 'Sergey')
      .or(new EqualsSQL('familyName', 'Ustimenko'))
    )
  )
  ..orderBy('id', 'DESC')
  ..limit(10);

  return f.execute(); // returns Future<ORMModel>
```
