import 'dart:mirrors';
import 'sql.dart';
import 'orm.dart';

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
   * By default, database table name will be class name converted to underscores.
   * One can override this by providing String parameter 'tableName' to constructor.
   */
  const DBTable([String this._dbTableName]);

  String get name => _dbTableName;
}

/**
 * Database field annotation.
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

class OrmAnnotationsParser {
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
                DBTableSQL table = OrmAnnotationsParser.constructTable(declaration);
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

  static DBTableSQL getDBTableSQLForInstance(OrmModel instance){
    InstanceMirror mirror = reflect(instance);
    String instanceClassName = MirrorSystem.getName(mirror.type.simpleName);

    return _ormClasses[instanceClassName];
  }

  static dynamic getPropertyValueForField(DBFieldSQL field, OrmModel instance){
    InstanceMirror mirror = reflect(instance);
    return mirror.getField(field.constructedFromPropertyName).reflectee;
  }

  static DBFieldSQL constructField(InstanceMirror annotation, VariableMirror fieldMirror){
    DBFieldSQL field = new DBFieldSQL();

    var propertyMeta = fieldMirror.metadata;

    for(InstanceMirror annotationMirror in propertyMeta){
      String annotationTypeName = getTypeName(annotationMirror.type);

      if(annotationTypeName == "DBFieldPrimaryKey"){
        field.isPrimaryKey = true;
      }
      if(annotationTypeName == "DBFieldType"){
        field.type = annotationMirror.reflectee.type;
      }
      if(annotationTypeName == 'DBFieldDefault'){
        field.defaultValue = annotationMirror.reflectee.defaultValue;
      }
    }

    if(field.type == null){
      String fieldDartType = getTypeName(fieldMirror.type);
      switch (fieldDartType) {
        case 'int':
          if(field.isPrimaryKey){
            field.type = 'SERIAL';
          }
          else{
            field.type = 'int';
          }
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

    if(field.fieldName == null){
      field.propertyName = getTypeName(fieldMirror);
    }

    field.constructedFromPropertyName = fieldMirror.simpleName;

    return field;
  }

  /**
   * Scans DB* annotations on class fields and constructs DBTableSQL instance
   */
  static DBTableSQL constructTable(ClassMirror modelClassMirror){
    DBTableSQL table = new DBTableSQL();

    table.className = _getTableName(modelClassMirror);
    table.fields = _getFields(modelClassMirror);

    return table;
  }

  static String _getTableName(ClassMirror modelClassMirror){
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

  static List<DBFieldSQL> _getFields(ClassMirror modelClassMirror){
    List<DBFieldSQL> fields = new List<DBFieldSQL>();

    for (var modelProperty in modelClassMirror.declarations.values) {
      for (var modelPropertyMeta in modelProperty.metadata) {
        String propertyMetaName = getTypeName(modelPropertyMeta.type);
        if (propertyMetaName == 'DBField') {
          DBFieldSQL field = constructField(modelPropertyMeta, modelProperty);
          fields.add(field);
        }
      }
    }

    return fields;
  }

  static String getTypeName(DeclarationMirror t){
    return MirrorSystem.getName(t.simpleName);
  }
}