[![Build Status](https://travis-ci.org/ustims/DartORM.svg?branch=master)](https://travis-ci.org/ustims/DartORM)

Dart ORM
========

Easy-to-use and easy-to-setup database ORM for dart.

It is in the very beginning stage of development and not ready for production use.
Feel free to contribute!

Feature tour
============

If you want to jump to example code click here:
https://github.com/ustims/DartORM/blob/master/example/example.dart

Annotations
-----------

```dart
import 'package:dart_orm/orm.dart' as ORM;

@ORM.DBTable('users')
class User extends ORM.Model {
  // Every field that needs to be stored in database should be annotated with @DBField
  @ORM.DBField()
  @ORM.DBFieldPrimaryKey()
  int id;

  @ORM.DBField()
  String givenName;

  // column name can be overridden
  @ORM.DBField('family_name')
  String familyName;
}
```

With such annotated class when you first run ORM.Migrator.migrate()

it will execute such statement:

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    given_name text,
    family_name text
);
```

Migrations, schema versions and diffs will be implemented later.

Inserts and updates
-------------------

Every ORM.Model has .save() method which will update/insert a new row.

If class instance has 'id' field with not-null value,
.save() will execute 'UPDATE' statement with 'WHERE id = $id'.

If class instance has null 'id' field, 'INSERT' statement will be executed.

```dart
User u = new User();
u.givenName = 'Sergey';
u.familyName = 'Ustimenko';

var saveResult = await u.save();
```

This statement will be executed on save():

```sql
INSERT INTO users (
    given_name,
    family_name)
VALUES (
    'Sergey',
    'Ustimenko'
);
```

Finding records
---------------

ORM has two classes for finding records: Find and FindOne.

Constructors receives a class that extend ORM.Model.

```dart

ORM.Find f = new ORM.Find(User)
  ..where(new ORM.LowerThan('id', 3)
    .and(new ORM.Equals('givenName', 'Sergey')
      .or(new ORM.Equals('familyName', 'Ustimenko'))
    )
  )
  ..orderBy('id', 'DESC')
  ..setLimit(10);

List foundUsers = await f.execute();

for(User u in foundUsers){
  print('Found user:');
  print(u);
}
```

This will result such statement executed on the database:

```sql
SELECT *
FROM users
WHERE id < 3 AND (given_name = 'Sergey' OR family_name = 'Ustimenko')
ORDER BY id DESC LIMIT 10
```

Multiple database adapters support
----------------------------------

Currenty there are three adapters in work-in-progress status:

https://github.com/ustims/DartORM-PostgreSQL

https://github.com/ustims/DartORM-MySQL

https://github.com/ustims/DartORM-MongoDB



Roadmap
=======

- model relations (in progress)
- multiple adapters support(should be possible to store models on different adapters)
- migration system
- memory & file adapters
