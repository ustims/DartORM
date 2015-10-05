library dart_orm.test_integration;

import 'package:dart_orm/dart_orm.dart';
import 'package:test/test.dart';

import 'test_basic_integration.dart';
import 'test_separate_annotations.dart';

bool _parserInitialized = false;

void registerTestsForAdapter(String name, DBAdapter adapter) {
  var migrated = false;

  group(name, () {
    setUp(() async {
      if (!_parserInitialized) {
        // This will scan current isolate
        // for classes annotated with DBTable
        // and store sql definitions for them in memory
        AnnotationsParser.initialize();

        _parserInitialized = true;
      }

      if (!migrated) {
        await adapter.connect();
        addAdapter(name, adapter);
        setDefaultAdapter(name);

        var result = await Migrator.migrate();
        expect(result, isTrue, reason: 'migration should succeed');

        migrated = true;
      } else {
        setDefaultAdapter(name);
      }
    });

    registerBasicIntegrationTests();

    test('SeparateAnnotations', testSeparateAnnotations);
  });
}
