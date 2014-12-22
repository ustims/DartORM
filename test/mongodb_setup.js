use dart_orm_test;

db.createUser(
    {
        user: "dart_orm_test_user",
        pwd: "dart_orm_test_user",
        roles: [{role: "userAdmin", db: "dart_orm_test"}]
    }
);
