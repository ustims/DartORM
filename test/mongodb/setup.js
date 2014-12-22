use dart_orm_test;

if (db.version().toString().indexOf('2.4') > -1) {
    db.addUser(
        {
            user: "dart_orm_test_user",
            pwd: "dart_orm_test_user",
            roles: ["readWrite"]
        }
    );
} else {
    db.createUser(
        {
            user: "dart_orm_test_user",
            pwd: "dart_orm_test_user",
            roles: [{role: "userAdmin", db: "dart_orm_test"}]
        }
    );
}
