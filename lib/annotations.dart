import 'dart:mirrors';
import 'sql.dart';
import 'orm.dart';

class DBTable {
  final String _dbTableName;
  const DBTable([String this._dbTableName]);
}

class DBField {
  final String _dbFieldName;
  const DBField([String this._dbFieldName]);
}

class DBFieldPrimaryKey {
  const DBFieldPrimaryKey();
}

class DBFieldType {
  final String _type;

  const DBFieldType(String this._type);
}

class DBFieldDefault {
  final dynamic _defaultValue;

  const DBFieldDefault(this._defaultValue);
}

class DBAnnotationsParser {
  static Map<String, DBTableSQL> _ormClasses = new Map<String, DBTableSQL>();

  static get ormClasses => _ormClasses;

  static void initialize(){
    MirrorSystem m = currentMirrorSystem();
    IsolateMirror i = m.isolate;

    for(LibraryMirror mm in m.libraries.values){
      for(var declaration in mm.declarations.values){
        if(declaration is ClassMirror){
          if(declaration.metadata.length > 0){
            for(InstanceMirror metaInstanceMirror in declaration.metadata){
              String modelClassName = MirrorSystem.getName(declaration.simpleName);
              String metaClassName = MirrorSystem.getName(metaInstanceMirror.type.simpleName);

              if(metaClassName == 'DBTable'){
                DBTableSQL table = DBAnnotationsParser.constructTable(declaration);
                _ormClasses[modelClassName] = table;
              }
            }
          }
        }
      }
    }
  }

  static DBTableSQL getDBTableSQLForType(Type modelType){
    ClassMirror modelMirror = reflectClass(modelType);
    String modelClassName = MirrorSystem.getName(modelMirror.simpleName);
    return _ormClasses[modelClassName];
  }

  static DBTableSQL getDBTableSQLForClassName(String className){
    return _ormClasses[className];
  }

  static DBTableSQL getDBTableSQLForInstance(ORMModel instance){
    InstanceMirror mirror = reflect(instance);
    String instanceClassName = MirrorSystem.getName(mirror.type.simpleName);

    return _ormClasses[instanceClassName];
  }

  static dynamic getPropertyValueForField(DBFieldSQL field, ORMModel instance){
    InstanceMirror mirror = reflect(instance);
    return mirror.getField(field.constructedFromPropertyName).reflectee;
  }

  static DBFieldSQL constructField(InstanceMirror annotation, VariableMirror fieldMirror){
    DBFieldSQL field = new DBFieldSQL();

    var propertyMeta = fieldMirror.metadata;

    for(InstanceMirror annotationMirror in propertyMeta){
      String annotationTypeName = MirrorSystem.getName(annotationMirror.type.simpleName);

      if(annotationTypeName == "DBFieldPrimaryKey"){
        field.isPrimaryKey = true;
      }
      if(annotationTypeName == "DBFieldType"){
        field.type = annotationMirror.reflectee._type;
      }
      if(annotationTypeName == 'DBFieldDefault'){
        field.defaultValue = annotationMirror.reflectee._defaultValue;
      }
    }

    if(field.type == null){
      String fieldDartType = MirrorSystem.getName(fieldMirror.type.simpleName);
      switch (fieldDartType) {
        case 'int':
          field.type = 'int';
          break;
        case 'String':
          field.type = 'text';
          break;
        case 'bool':
          field.type = 'bool';
          break;
        case 'LinkedHashMap':
          field.type = 'json';
          break;
      }
    }

    if(field.name == null){
      field.name = MirrorSystem.getName(fieldMirror.simpleName);
    }

    field.constructedFromPropertyName = fieldMirror.simpleName;

    return field;
  }

  /**
   * Scans DB* annotations on class fields and constructs DBTableSQL instance
   */
  static DBTableSQL constructTable(ClassMirror modelClassMirror){
    DBTableSQL table = new DBTableSQL();

    table.name = _getTableName(modelClassMirror);
    table.fields = _getFields(modelClassMirror);

    return table;
  }

  static String _getTableName(ClassMirror modelClassMirror){
    var classMetadata = modelClassMirror.metadata;
    String dbTableName = null;
    for (var m in classMetadata) {
      if (MirrorSystem.getName(m.type.simpleName) == 'DBTable') {
        dbTableName = m.reflectee._dbTableName;
      }
    }
    if (dbTableName == null) {
      dbTableName = MirrorSystem.getName(modelClassMirror.simpleName);
    }
    return dbTableName;
  }

  static List<DBFieldSQL> _getFields(ClassMirror modelClassMirror){
    List<DBFieldSQL> fields = new List<DBFieldSQL>();

    for (var modelProperty in modelClassMirror.declarations.values) {
      for (var modelPropertyMeta in modelProperty.metadata) {
        String propertyMetaName = MirrorSystem.getName(modelPropertyMeta.type.simpleName);
        if (propertyMetaName == 'DBField') {
          DBFieldSQL field = constructField(modelPropertyMeta, modelProperty);
          fields.add(field);
        }
      }
    }

    return fields;
  }
}