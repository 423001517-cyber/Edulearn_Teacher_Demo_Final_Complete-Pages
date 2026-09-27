import 'model_utils.dart';

/// `admins/{uid}` — profile of a user with the `admin` role. The role
/// itself is a Firebase Auth custom claim set by a Cloud Function.
class AdminUser {
  const AdminUser({required this.uid, required this.displayName, this.email = ''});

  final String uid;
  final String displayName;
  final String email;

  factory AdminUser.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return AdminUser(
      uid: doc.id,
      displayName: readString(d['displayName'], 'Administrator'),
      email: readString(d['email']),
    );
  }

  String get firstName => firstNameOf(displayName);
  String get initials => initialsOf(displayName);
}
