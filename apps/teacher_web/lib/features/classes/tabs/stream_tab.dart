import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter/material.dart';

import '../../stream/stream_feed.dart';

/// The class page's Stream tab — the same feed as the Stream page
/// (composer, posts, classwork updates, class comments).
class StreamTab extends StatelessWidget {
  const StreamTab({super.key, required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context) => StreamFeed(classRoom: classRoom);
}
