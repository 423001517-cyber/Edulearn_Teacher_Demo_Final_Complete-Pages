import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';

/// Opens the full-page Create / Edit classwork editor (the Classwork
/// designs). Kept under this name so the dashboard's Quick Create, the
/// Stream, previews and remedial quests all lead to the same pages.
///
/// [assignTo] pre-selects one student (remedial work).
Future<bool?> showClassworkForm(
  BuildContext context, {
  required ClassworkType type,
  ClassworkItem? existing,
  String? classId,
  Student? assignTo,
}) async {
  context.push(existing != null
      ? Routes.classworkEdit(existing.id)
      : Routes.classworkNew(type, classId: classId, studentId: assignTo?.id));
  return null;
}
