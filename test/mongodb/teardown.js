use dart_orm_test;

db.runCommand( { dropAllUsersFromDatabase: 1, writeConcern: { w: "majority" } } );
db.dropDatabase();