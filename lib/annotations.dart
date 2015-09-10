part of dart_orm;

/**
 * Database table annotation. If some class wants to be orm-enabled,
 * it needs to be annotated with DBTable().
 *
 * This class is only for annotation purposes,
 * and its data is used to construct [DBTableSQL] instances.
 */
class DBTable {
  final String _dbTableName;

  /**
   * New instance annotation.
   * By default, database table name
   * will be class name converted to underscores.
   * One can override this by providing
   * String parameter 'tableName' to constructor.
   */
  const DBTable([String this._dbTableName]);

  String get name => _dbTableName;
}

/**
 * Database field annotation.
 *
 * Every property of class that needs to be stored to database
 * should be annotated with @DBField
 */
class DBField {
  final String _dbFieldName;

  const DBField([String this._dbFieldName]);

  String get name => _dbFieldName;
}

class DBFieldPrimaryKey {
  const DBFieldPrimaryKey();
}

class DBFieldType {
  final String _type;

  const DBFieldType(String this._type);

  String get type => _type;
}

class DBFieldDefault {
  final dynamic _defaultValue;

  const DBFieldDefault(this._defaultValue);

  String get defaultValue => _defaultValue;
}

class AnnotationsParser {
  static Map<String, Table> _ormClasses = new Map<String, Table>();

  static get ormClasses => _ormClasses;

  static void initialize() {
    List<ClassMirror> classMirrorsWithMetadata = getAllClassesWithMetadata();

    for (ClassMirror classMirror in classMirrorsWithMetadata) {
      for (InstanceMirror metaInstanceMirror in classMirror.metadata) {
        String modelClassName = MirrorSystem.getName(classMirror.simpleName);
        String metaClassName =
            MirrorSystem.getName(metaInstanceMirror.type.simpleName);

        if (metaClassName == 'DBTable') {
          Table table = AnnotationsParser.constructTable(classMirror);
          _ormClasses[modelClassName] = table;
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
    return _ormClasses[modelClassName];
  }

  /**
   * Returns [Table] definition object for specified class name.
   */
  static Table getTableForClassName(String className) {
    return _ormClasses[className];
  }

  /**
   * Returns [Table] definition object for specified model class instance.
   */
  static Table getTableForInstance(Model instance) {
    InstanceMirror mirror = reflect(instance);
    String instanceClassName = MirrorSystem.getName(mirror.type.simpleName);

    return _ormClasses[instanceClassName];
  }

  static dynamic getPropertyValueForField(Field field, Model instance) {
    InstanceMirror mirror = reflect(instance);
    return mirror.getField(field.constructedFromPropertyName).reflectee;
  }

  static dynamic setPropertyValueForField(
      Field field, dynamic value, Model instance) {
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
  static Table constructTable(ClassMirror modelClassMirror) {
    Table table = new Table();

    table.className = _getTableName(modelClassMirror);
    table.fields = _getFields(modelClassMirror);

    return table;
  }

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

  static String getTypeName(DeclarationMirror t) {
    return MirrorSystem.getName(t.simpleName);
  }
}
