import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

/// `settings/school` (school name and year, set by the admin).
final schoolSettingsProvider = StreamProvider.autoDispose<SchoolSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watchSchool(),
);

/// Settings defaults, ready to use synchronously (falls back to the
/// built-in defaults while loading).
final preferencesProvider = Provider.autoDispose<TeacherPreferences>(
  (ref) => ref.watch(teacherPreferencesProvider).valueOrNull ?? const TeacherPreferences(),
);
