import 'classwork_item.dart';
import 'gradebook.dart';
import 'model_utils.dart';

/// Things a teacher can be notified about (Settings › Notifications).
/// The names match what the Cloud Functions check before writing a
/// notification.
enum NotifyTopic {
  submissions('New work turned in', 'When a student submits classwork'),
  missingWork('Late and missing work', 'One summary each evening'),
  messages('Messages from students', 'Direct messages and class group replies'),
  comments('Comments on your posts', 'Replies on the Stream and on classwork'),
  rewards('Reward requests', 'When a student wants to redeem a reward');

  const NotifyTopic(this.label, this.hint);
  final String label;
  final String hint;
}

class NotifyChoice {
  const NotifyChoice({this.web = true, this.email = false});

  /// Bell notifications on the teacher website.
  final bool web;

  /// Sent once the school connects an email service.
  final bool email;

  NotifyChoice copyWith({bool? web, bool? email}) =>
      NotifyChoice(web: web ?? this.web, email: email ?? this.email);

  @override
  bool operator ==(Object other) => other is NotifyChoice && other.web == web && other.email == email;

  @override
  int get hashCode => Object.hash(web, email);
}

/// `teachers/{uid}/settings/preferences` — Settings page choices that other
/// pages use as defaults (new classwork, new gradebooks, the calendar).
class TeacherPreferences {
  const TeacherPreferences({
    this.notify = defaultNotify,
    this.activityPoints = 10,
    this.bossPoints = 50,
    this.dueHour = 23,
    this.dueMinute = 59,
    this.allowLate = true,
    this.notifyOnGrade = true,
    this.postToStream = true,
    this.showLeaderboard = true,
    this.calculation = GradeCalculation.totalPoints,
    this.passingGrade = 75,
    this.weekStartsMonday = false,
  });

  static const defaultNotify = <NotifyTopic, NotifyChoice>{
    NotifyTopic.submissions: NotifyChoice(),
    NotifyTopic.missingWork: NotifyChoice(email: true),
    NotifyTopic.messages: NotifyChoice(),
    NotifyTopic.comments: NotifyChoice(),
    NotifyTopic.rewards: NotifyChoice(),
  };

  final Map<NotifyTopic, NotifyChoice> notify;

  /// Default points for new activities and Friday Boss assessments.
  /// (New quests and quizzes start at the class's "Total points".)
  final int activityPoints;
  final int bossPoints;

  /// Default due time for new classwork.
  final int dueHour;
  final int dueMinute;
  final bool allowLate;

  /// "Notify student" starts switched on when returning work.
  final bool notifyOnGrade;
  final bool postToStream;
  final bool showLeaderboard;

  /// Used for a class until its Gradebook settings are saved.
  final GradeCalculation calculation;
  final int passingGrade;
  final bool weekStartsMonday;

  NotifyChoice choiceFor(NotifyTopic t) => notify[t] ?? defaultNotify[t] ?? const NotifyChoice();

  /// null = use the class's Total points / the type's usual points.
  int? pointsFor(ClassworkType t) => switch (t) {
        ClassworkType.activity => activityPoints,
        ClassworkType.boss => bossPoints,
        _ => null,
      };

  GradebookSettings get gradebookDefaults =>
      GradebookSettings(calculation: calculation, passingGrade: passingGrade);

  factory TeacherPreferences.fromMap(Map<String, dynamic>? d) {
    if (d == null) return const TeacherPreferences();
    const base = TeacherPreferences();
    int i(String k, int fallback, int min, int max) =>
        d[k] is num ? (d[k] as num).toInt().clamp(min, max).toInt() : fallback;
    bool b(String k, bool fallback) => d[k] is bool ? d[k] as bool : fallback;
    final notify = <NotifyTopic, NotifyChoice>{};
    final raw = d['notify'];
    for (final t in NotifyTopic.values) {
      final v = raw is Map ? raw[t.name] : null;
      final fallback = defaultNotify[t]!;
      notify[t] = v is Map
          ? NotifyChoice(
              web: v['web'] is bool ? v['web'] as bool : fallback.web,
              email: v['email'] is bool ? v['email'] as bool : fallback.email,
            )
          : fallback;
    }
    return TeacherPreferences(
      notify: notify,
      activityPoints: i('activityPoints', base.activityPoints, 0, 1000),
      bossPoints: i('bossPoints', base.bossPoints, 0, 1000),
      dueHour: i('dueHour', base.dueHour, 0, 23),
      dueMinute: i('dueMinute', base.dueMinute, 0, 59),
      allowLate: b('allowLate', base.allowLate),
      notifyOnGrade: b('notifyOnGrade', base.notifyOnGrade),
      postToStream: b('postToStream', base.postToStream),
      showLeaderboard: b('showLeaderboard', base.showLeaderboard),
      calculation: GradeCalculation.parse(d['calculation']),
      passingGrade: i('passingGrade', base.passingGrade, 0, 100),
      weekStartsMonday: b('weekStartsMonday', base.weekStartsMonday),
    );
  }

  Json toMap() => {
        'notify': {
          for (final t in NotifyTopic.values) t.name: {'web': choiceFor(t).web, 'email': choiceFor(t).email},
        },
        'activityPoints': activityPoints,
        'bossPoints': bossPoints,
        'dueHour': dueHour,
        'dueMinute': dueMinute,
        'allowLate': allowLate,
        'notifyOnGrade': notifyOnGrade,
        'postToStream': postToStream,
        'showLeaderboard': showLeaderboard,
        'calculation': calculation.name,
        'passingGrade': passingGrade,
        'weekStartsMonday': weekStartsMonday,
      };

  TeacherPreferences copyWith({
    Map<NotifyTopic, NotifyChoice>? notify,
    int? activityPoints,
    int? bossPoints,
    int? dueHour,
    int? dueMinute,
    bool? allowLate,
    bool? notifyOnGrade,
    bool? postToStream,
    bool? showLeaderboard,
    GradeCalculation? calculation,
    int? passingGrade,
    bool? weekStartsMonday,
  }) =>
      TeacherPreferences(
        notify: notify ?? this.notify,
        activityPoints: activityPoints ?? this.activityPoints,
        bossPoints: bossPoints ?? this.bossPoints,
        dueHour: dueHour ?? this.dueHour,
        dueMinute: dueMinute ?? this.dueMinute,
        allowLate: allowLate ?? this.allowLate,
        notifyOnGrade: notifyOnGrade ?? this.notifyOnGrade,
        postToStream: postToStream ?? this.postToStream,
        showLeaderboard: showLeaderboard ?? this.showLeaderboard,
        calculation: calculation ?? this.calculation,
        passingGrade: passingGrade ?? this.passingGrade,
        weekStartsMonday: weekStartsMonday ?? this.weekStartsMonday,
      );

  TeacherPreferences withChoice(NotifyTopic t, NotifyChoice c) =>
      copyWith(notify: {...notify, t: c});

  @override
  bool operator ==(Object other) =>
      other is TeacherPreferences && _same(toMap(), other.toMap());

  @override
  int get hashCode => toMap().toString().hashCode;
}

bool _same(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_same(a[k], b[k])) return false;
    }
    return true;
  }
  return a == b;
}
