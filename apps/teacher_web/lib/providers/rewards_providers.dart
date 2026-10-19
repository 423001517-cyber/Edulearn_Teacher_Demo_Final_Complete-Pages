import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'classes_providers.dart';
import 'core_providers.dart';
import 'data_providers.dart';
import 'gradebook_providers.dart';

enum LeaderboardPeriod {
  week('This week'),
  month('This month'),
  all('All time');

  const LeaderboardPeriod(this.label);
  final String label;

  /// null = no start (all points).
  DateTime? start(DateTime now) => switch (this) {
        LeaderboardPeriod.week => startOfWeek(now),
        LeaderboardPeriod.month => DateTime(now.year, now.month, 1),
        LeaderboardPeriod.all => null,
      };
}

final rewardSettingsProvider = StreamProvider.autoDispose.family<RewardSettings, String>(
  (ref, classId) => ref.watch(rewardsRepositoryProvider).watchSettings(classId),
);

final pointAwardsProvider = StreamProvider.autoDispose.family<List<PointAward>, String>(
  (ref, classId) => ref.watch(rewardsRepositoryProvider).watchAwards(classId),
);

final rewardRequestsProvider = StreamProvider.autoDispose.family<List<RewardRequest>, String>(
  (ref, classId) => ref.watch(rewardsRepositoryProvider).watchRequests(classId),
);

/// Points, levels, badges and streaks for every student in a class.
final classRewardsProvider =
    Provider.autoDispose.family<AsyncValue<List<StudentRewards>>, (String, LeaderboardPeriod)>((ref, key) {
  final (classId, period) = key;
  final students = ref.watch(classStudentsProvider(classId));
  final work = ref.watch(classClassworkProvider(classId));
  final subs = ref.watch(classSubmissionsProvider(classId));
  final awards = ref.watch(pointAwardsProvider(classId));
  final requests = ref.watch(rewardRequestsProvider(classId));
  final settings = ref.watch(rewardSettingsProvider(classId));
  for (final v in <AsyncValue<Object>>[students, work, subs, awards, requests, settings]) {
    if (v.hasError) return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
  }
  if (!students.hasValue ||
      !work.hasValue ||
      !subs.hasValue ||
      !awards.hasValue ||
      !requests.hasValue ||
      !settings.hasValue) {
    return const AsyncLoading();
  }
  final now = DateTime.now();
  return AsyncData(computeRewards(
    students: students.requireValue,
    work: work.requireValue,
    submissions: subs.requireValue,
    awards: awards.requireValue,
    requests: requests.requireValue,
    settings: settings.requireValue,
    now: now,
    periodStart: period.start(now),
  ));
});
