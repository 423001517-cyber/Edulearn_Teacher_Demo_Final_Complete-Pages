import 'model_utils.dart';

/// Disabled teachers can't sign in (set by an admin).
enum AccountStatus {
  active,
  disabled;

  static AccountStatus parse(Object? v) =>
      v == AccountStatus.disabled.name ? AccountStatus.disabled : AccountStatus.active;
}

/// `teachers/{uid}`
class Teacher {
  const Teacher({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
    this.status = AccountStatus.active,
    this.createdAt,
    this.titleName = '',
    this.subject = '',
    this.gradeLevels = const [],
    this.bio = '',
  });

  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final AccountStatus status;
  final DateTime? createdAt;

  /// What students call them ("Teacher Jean"). Empty = "Teacher" + first name.
  final String titleName;

  /// e.g. "Araling Panlipunan"
  final String subject;

  /// Grade levels they teach, e.g. [4, 5, 6].
  final List<int> gradeLevels;

  /// Welcome message shown to students in the EduLearn app.
  final String bio;

  factory Teacher.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return Teacher(
      uid: doc.id,
      displayName: readString(d['displayName'], 'Teacher'),
      email: readStringOrNull(d['email']),
      photoUrl: readStringOrNull(d['photoUrl']),
      status: AccountStatus.parse(d['status']),
      createdAt: readDate(d['createdAt']),
      titleName: readString(d['titleName']),
      subject: readString(d['subject']),
      gradeLevels: d['gradeLevels'] is List
          ? [for (final g in d['gradeLevels'] as List) if (g is num) g.toInt()]
          : const [],
      bio: readString(d['bio']),
    );
  }

  String get firstName => firstNameOf(displayName);

  /// How the class addresses them — "Teacher Jean".
  String get title => titleName.trim().isNotEmpty ? titleName.trim() : 'Teacher $firstName';

  String get initials => initialsOf(displayName);

  bool get isDisabled => status == AccountStatus.disabled;
}
