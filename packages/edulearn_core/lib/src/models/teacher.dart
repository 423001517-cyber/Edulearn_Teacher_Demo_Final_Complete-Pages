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
  });

  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final AccountStatus status;
  final DateTime? createdAt;

  factory Teacher.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return Teacher(
      uid: doc.id,
      displayName: readString(d['displayName'], 'Teacher'),
      email: readStringOrNull(d['email']),
      photoUrl: readStringOrNull(d['photoUrl']),
      status: AccountStatus.parse(d['status']),
      createdAt: readDate(d['createdAt']),
    );
  }

  String get firstName => firstNameOf(displayName);

  /// How the class addresses them — "Teacher Jean".
  String get title => 'Teacher $firstName';

  String get initials => initialsOf(displayName);

  bool get isDisabled => status == AccountStatus.disabled;
}
