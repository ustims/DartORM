library dart_orm.test_seperate_annotations;

import 'dart:async';
import 'package:test/test.dart';

import 'package:dart_orm/dart_orm.dart' as ORM;

class Comment {
  int id;
  String text;

  getText() {
    return text;
  }
}

@ORM.DBTable('comments', Comment)
class DBCommentMap {
  @ORM.DBField()
  @ORM.DBFieldPrimaryKey()
  int id;

  @ORM.DBField()
  String text;
}

Future testSeparateAnnotations() async {
  Comment comment = new Comment();
  comment.text = 'Comment text';

  int commentId = await ORM.insert(comment);
  expect(commentId, 1);

  comment = new Comment();
  comment.text = 'Another text';

  commentId = await ORM.insert(comment);
  expect(commentId, 2);

  ORM.FindOne f = new ORM.FindOne(Comment)..whereEquals('id', 1);

  Comment commentFromDb = await f.execute();
  expect(commentFromDb.text, 'Comment text');
  expect(commentFromDb.getText(), 'Comment text');
}
