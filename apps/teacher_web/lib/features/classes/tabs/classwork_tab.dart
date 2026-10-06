import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter/material.dart';

import '../../classwork/classwork_page.dart';

/// The class page's Classwork tab — the same board as the Classwork page
/// (topics, filters, create, reuse), without the stat cards.
class ClassworkTab extends StatelessWidget {
  const ClassworkTab({super.key, required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context) =>
      ClassworkBoard(key: ValueKey(classRoom.id), classRoom: classRoom, showStats: false);
}
