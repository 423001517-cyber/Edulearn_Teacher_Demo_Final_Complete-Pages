import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Icons and tones for each model value, kept in one place so every page
/// renders the same thing the same way.

extension ClassworkTypeVisuals on ClassworkType {
  // Classwork design: blue lesson, green quest trophy, orange activity,
  // purple quiz, gold Friday Boss crown, grey material.
  IconData get icon => switch (this) {
        ClassworkType.lesson => Icons.article_rounded,
        ClassworkType.quest => Icons.emoji_events_rounded,
        ClassworkType.quiz => Icons.quiz_rounded,
        ClassworkType.boss => Icons.workspace_premium_rounded,
        ClassworkType.activity => Icons.auto_stories_rounded,
        ClassworkType.material => Icons.folder_copy_rounded,
      };

  Tone get tone => switch (this) {
        ClassworkType.lesson => Tone.blue,
        ClassworkType.quest => Tone.green,
        ClassworkType.activity || ClassworkType.boss => Tone.amber,
        ClassworkType.quiz => Tone.purple,
        ClassworkType.material => Tone.neutral,
      };
}

extension ClassworkStatusVisuals on ClassworkStatus {
  Tone get tone => switch (this) {
        ClassworkStatus.published => Tone.green,
        ClassworkStatus.scheduled => Tone.blue,
        ClassworkStatus.draft || ClassworkStatus.closed => Tone.neutral,
      };

  /// Students see published work as "Assigned".
  String get displayLabel => this == ClassworkStatus.published ? 'Assigned' : label;
}

extension NotificationKindVisuals on NotificationKind {
  IconData get icon => switch (this) {
        NotificationKind.submissions => Icons.description_outlined,
        NotificationKind.missingWork => Icons.priority_high_rounded,
        NotificationKind.schedule => Icons.emoji_events_rounded,
        NotificationKind.general => Icons.notifications_none_rounded,
      };

  Tone get tone => switch (this) {
        NotificationKind.submissions || NotificationKind.schedule => Tone.amber,
        NotificationKind.missingWork => Tone.red,
        NotificationKind.general => Tone.blue,
      };
}

extension ActivityKindVisuals on ActivityKind {
  IconData get icon => switch (this) {
        ActivityKind.submitted => Icons.description_outlined,
        ActivityKind.joined => Icons.group_add_outlined,
        ActivityKind.announcement => Icons.chat_bubble_outline,
        ActivityKind.completed => Icons.check_rounded,
        ActivityKind.missed => Icons.priority_high_rounded,
        ActivityKind.published => Icons.quiz_outlined,
      };

  Tone get tone => switch (this) {
        ActivityKind.submitted || ActivityKind.completed => Tone.green,
        ActivityKind.joined || ActivityKind.published => Tone.blue,
        ActivityKind.announcement => Tone.amber,
        ActivityKind.missed => Tone.red,
      };
}

extension StandingVisuals on Standing {
  Tone get tone => switch (this) {
        Standing.onTrack => Tone.green,
        Standing.needsSupport => Tone.amber,
        Standing.excellent => Tone.blue,
      };

  IconData get icon => switch (this) {
        Standing.onTrack => Icons.check_circle_rounded,
        Standing.needsSupport => Icons.error_rounded,
        Standing.excellent => Icons.verified_rounded,
      };
}

extension SupportLevelVisuals on SupportLevel {
  Tone get tone => this == SupportLevel.urgent ? Tone.red : Tone.amber;
}

extension ScoreBandVisuals on ScoreBand {
  Tone get tone => switch (this) {
        ScoreBand.excellent => Tone.green,
        ScoreBand.proficient => Tone.blue,
        ScoreBand.developing => Tone.amber,
        ScoreBand.needsSupport => Tone.red,
      };
}
