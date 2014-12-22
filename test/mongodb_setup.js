use dart_orm_test

if (db.createUser) {
    db.createUser(
        {
            user: "dart_orm_test_user",
            pwd: "dart_orm_test_user",
            roles: [{role: "userAdmin", db: "dart_orm_test"}]
        }
    )
} else {
    db.addUser(
        {
            user: "dart_orm_test_user",
            pwd: "dart_orm_test_user",
            roles: ["readWrite"]
        }
    )
}
