import 'mysql_integration_test.dart' as mysql;
import 'postgres_integration_test.dart' as postgres;
import 'mongodb_integration_test.dart' as mongo;

/// test file to run everything. Needed for coveralls because it can accept only one file.
void main() {
  mysql.main();
  postgres.main();
  mongo.main();
}
