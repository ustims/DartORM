library dart_orm.annotations;

import 'dart:mirrors';

import 'operations.dart';

/**
 * Database table annotation. If some class wants to be orm-enabled,
 * it needs to be annotated with DBTable().
 *
 * This class is only for annotation purposes,
 * and its data is used to construct [DBTableSQL] instances.
 */
class DBTable {
  /**
   * New instance annotation.
   * By default, database table name
   * will be class name converted to underscores.
   * One can override this by providing
   * String parameter 'tableName' to constructor.
   */
  const DBTable([this.name, this.annotationTarget]);

  final String name;

  final Type annotationTarget;
}

/**
 * Database field annotation.
 *
 * Every property of class that needs to be stored to database
 * should be annotated with @DBField
 */
class DBField {
  const DBField([this.name]);

  final String name;
}

class DBFieldPrimaryKey {
  const DBFieldPrimaryKey();
}

class DBFieldType {
  const DBFieldType(this.type);

  final String type;
}

class DBFieldDefault {
  const DBFieldDefault(this.defaultValue);

  final String defaultValue;
}

class AnnotationsParser {
  static final Map<String, Table> ormClasses = new Map<String, Table>();

  static void initialize() {
    List<ClassMirror> classMirrorsWithMetadata = getAllClassesWithMetadata();

    for (ClassMirror classMirror in classMirrorsWithMetadata) {
      for (InstanceMirror metaInstanceMirror in classMirror.metadata) {
        String modelClassName = MirrorSystem.getName(classMirror.simpleName);
        String metaClassName =
            MirrorSystem.getName(metaInstanceMirror.type.simpleName);

        if (metaClassName == 'DBTable') {
          DBTable dbTableAnnotation = (metaInstanceMirror.reflectee as DBTable);

          // if annotation target is not provided then class annotated
          // with DBTable is a model itself
          Table table = AnnotationsParser.constructTable(classMirror);

          if (dbTableAnnotation.annotationTarget == null) {
            ormClasses[modelClassName] = table;
          } else {
            // we have annotation target so let's get that class
            ClassMirror target =
                reflectClass(dbTableAnnotation.annotationTarget);
            ormClasses[MirrorSystem.getName(target.simpleName)] = table;
          }
        }
      }
    }
  }

  /**
   * Iterates through all class declarations in current isolate
   * and returns a big list of all classes that have any metadata attached to.
   */
  static List<ClassMirror> getAllClassesWithMetadata() {
    List<ClassMirror> classMirrors = new List<ClassMirror>();

    MirrorSystem m = currentMirrorSystem();

    for (LibraryMirror mm in m.libraries.values) {
      for (var declaration in mm.declarations.values) {
        if (declaration is ClassMirror) {
          if (declaration.metadata.length > 0) {
            classMirrors.add(declaration);
          }
        }
      }
    }
    return classMirrors;
  }

  /**
   * Returns [Table] definition object for specified [Type]
   */
  static Table getTableForType(Type modelType) {
    ClassMirror modelMirror = reflectClass(modelType);
    String modelClassName = MirrorSystem.getName(modelMirror.simpleName);
    return ormClasses[modelClassName];
  }

  /**
   * Returns [Table] definition object for specified class name.
   */
  static Table getTableForClassName(String className) => ormClasses[className];

  /**
   * Returns [Table] definition object for specified model class instance.
   */
  static Table getTableForInstance(dynamic instance) {
    InstanceMirror mirror = reflect(instance);
    String instanceClassName = MirrorSystem.getName(mirror.type.simpleName);

    return ormClasses[instanceClassName];
  }

  /// Returns [field] value for provided model [instance]
  static dynamic getPropertyValueForField(Field field, dynamic instance) {
    InstanceMirror mirror = reflect(instance);
    return mirror.getField(field.constructedFromPropertyName).reflectee;
  }

  /// Allows setting [field]'s [value] on provided object instance.
  static dynamic setPropertyValueForField(
      Field field, dynamic value, dynamic instance) {
    InstanceMirror mirror = reflect(instance);
    return mirror.setField(field.constructedFromPropertyName, value);
  }

  static Field constructField(
      InstanceMirror annotation, VariableMirror fieldMirror) {
    Field field = new Field();

    var propertyMeta = fieldMirror.metadata;

    for (InstanceMirror annotationMirror in propertyMeta) {
      String annotationTypeName = getTypeName(annotationMirror.type);

      if (annotationTypeName == "DBFieldPrimaryKey") {
        field.isPrimaryKey = true;
      } else if (annotationTypeName == "DBFieldType") {
        field.type = annotationMirror.reflectee.type;
      } else if (annotationTypeName == 'DBFieldDefault') {
        field.defaultValue = annotationMirror.reflectee.defaultValue;
      }
    }

    field.propertyTypeName = getTypeName(fieldMirror.type);

    if (field.fieldName == null) {
      field.fieldName = getTypeName(fieldMirror);
    }

    field.propertyName = getTypeName(fieldMirror);
    field.constructedFromPropertyName = fieldMirror.simpleName;

    return field;
  }

  /**
   * Scans DB* annotations on class fields and constructs DBTableSQL instance
   */
  static Table constructTable(ClassMirror modelClassMirror) => new Table()
    ..className = _getTableName(modelClassMirror)
    ..fields = _getFields(modelClassMirror);

  static String _getTableName(ClassMirror modelClassMirror) {
    var classMetadata = modelClassMirror.metadata;
    String dbTableName = null;
    for (var m in classMetadata) {
      if (getTypeName(m.type) == 'DBTable') {
        dbTableName = m.reflectee.name;
      }
    }
    if (dbTableName == null) {
      dbTableName = getTypeName(modelClassMirror);
    }
    return dbTableName;
  }

  static List<Field> _getFields(ClassMirror modelClassMirror) {
    List<Field> fields = new List<Field>();

    for (var modelProperty in modelClassMirror.declarations.values) {
      for (var modelPropertyMeta in modelProperty.metadata) {
        String propertyMetaName = getTypeName(modelPropertyMeta.type);
        if (propertyMetaName == 'DBField') {
          Field field = constructField(modelPropertyMeta, modelProperty);
          fields.add(field);
        }
      }
    }

    return fields;
  }

  static String getTypeName(DeclarationMirror t) =>
      MirrorSystem.getName(t.simpleName);
}
