[![Build Status](https://travis-ci.org/ustims/DartORM.svg?branch=master)](https://travis-ci.org/ustims/DartORM)
[![Coverage Status](https://coveralls.io/repos/ustims/DartORM/badge.svg?branch=master&service=github)](https://coveralls.io/github/ustims/DartORM?branch=master)
[![Gitter](https://badges.gitter.im/ustims/DartORM.svg)](https://gitter.im/ustims/DartORM?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

Dart ORM
========

Easy-to-use and easy-to-setup database ORM for dart.

It is in the very beginning stage of development and not ready for production use.

Any feedback is greatly appreciated.

Feel free to contribute!

Features
========

Annotations
-----------

Annotations could be used in-place:

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

Or one can provide a target class for DBTable annotation. 
In such way one can store third-party classes in database without changing the original class definition.

```dart

// somelibrary.dart
class User {
  int id;
  String name;
}

// your code
import 'somelibrary.dart' as lib;

@ORM.Table('users', lib.User)
class DBUser {
  @ORM.DBField()
  int id;
  
  @ORM.DBField()
  String name;
}

// now User instances could be used like this:
lib.User u = new lib.User();
u.name = 'Name';
await ORM.insert(u);

// Note that DBUser is used only for annotation purposes and should not be used directly.
```

Types support
-------------

Any simple Dart type could be used: int/double/String/bool/DateTime.

Lists are supported and could be used as any other type just by annotating a property:

```dart
@ORM.DBTable('users')
class User {
  @ORM.DBField()
  List<String> emails;
}
```

References to other tables are not supported, but are in progress. Stay tuned!

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

Queries
-------

ORM has two classes for finding records: Find and FindOne.

Constructors receive a class that extend ORM.Model.

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

Server-side adapters:

https://github.com/ustims/DartORM-PostgreSQL

https://github.com/ustims/DartORM-MySQL

https://github.com/ustims/DartORM-MongoDB

To use an adapter install it with pub and do this:

```dart
import 'package:dart_orm_adapter_postgresql/dart_orm_adapter_postgresql.dart';
import 'package:dart_orm/dart_orm.dart' as orm;

main() {
  orm.AnnotationsParser.initialize();

  String connectionString =
      'postgres://<username>:<password>@localhost:5432/<dbname>';
      
  orm.DBAdapter postgresAdapter = new PostgresqlDBAdapter(connectionString);
  await postgresAdapter.connect();
  
  orm.addAdapter('postgres', postgresAdapter);
  orm.setDefaultAdapter('postgres');
  
  await orm.Migrator.migrate();
}
```      


DartORM could also be used on client side with indexedDB:

https://github.com/ustims/DartORM-IndexedDB

Roadmap
=======

- model relations (in progress)
- migration system
