import 'package:cloud_functions/cloud_functions.dart';

/// Wrappers for the admin Cloud Functions (firebase/functions/src/admin).
/// Each one checks on the server that the caller has the `admin` role.
class AdminFunctions {
  AdminFunctions(this._functions);

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    try {
      final result = await _functions.httpsCallable(name).call<Object?>(data);
      final value = result.data;
      return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw AdminActionException(e.message ?? 'Something went wrong (${e.code}).');
    }
  }

  /// Returns the new class's official code, e.g. "RIZAL-4A".
  Future<String> createClass({
    required int gradeLevel,
    required String section,
    required String subject,
    required String teacherId,
  }) async {
    final r = await _call('createClass', {
      'gradeLevel': gradeLevel,
      'section': section.trim(),
      'subject': subject.trim(),
      'teacherId': teacherId,
    });
    return '${r['classCode'] ?? ''}';
  }

  Future<String> approveClassRequest(
    String requestId, {
    int? gradeLevel,
    String? section,
    String? subject,
    String? teacherId,
  }) async {
    final r = await _call('approveClassRequest', {
      'requestId': requestId,
      if (gradeLevel != null) 'gradeLevel': gradeLevel,
      if (section != null) 'section': section.trim(),
      if (subject != null) 'subject': subject.trim(),
      if (teacherId != null) 'teacherId': teacherId,
    });
    return '${r['classCode'] ?? ''}';
  }

  Future<void> declineClassRequest(String requestId, String note) =>
      _call('declineClassRequest', {'requestId': requestId, 'note': note.trim()});

  Future<String> regenerateClassCode(String classId) async =>
      '${(await _call('regenerateClassCode', {'classId': classId}))['classCode'] ?? ''}';

  /// Creates the teacher's sign-in; returns a link for them to set a password.
  Future<String> createTeacherAccount({required String displayName, required String email}) async {
    final r = await _call('createTeacherAccount', {'displayName': displayName.trim(), 'email': email.trim()});
    return '${r['resetLink'] ?? ''}';
  }

  Future<String> teacherPasswordLink(String uid) async =>
      '${(await _call('teacherPasswordLink', {'uid': uid}))['resetLink'] ?? ''}';

  Future<void> setTeacherStatus(String uid, {required bool disabled}) =>
      _call('setTeacherStatus', {'uid': uid, 'disabled': disabled});

  Future<void> setAdminRole(String email, {required bool admin}) =>
      _call('setAdminRole', {'email': email.trim(), 'admin': admin});
}

/// A readable message from a failed admin action.
class AdminActionException implements Exception {
  AdminActionException(this.message);
  final String message;

  @override
  String toString() => message;
}
