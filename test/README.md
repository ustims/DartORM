Tests
=====

All unit/integration tests are here.

Main test.dart file contains code for recreating databases/users/privileges
on each run.

This script assumes that databases are accessible locally without password.

Usernames/db names should be set by environment variables: PSQL_USER, PSQL_DB, MYSQL_USER.