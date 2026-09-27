import 'model_utils.dart';

/// `settings/school` — edited by admins, readable by every signed-in user.
class SchoolSettings {
  const SchoolSettings({
    this.schoolName = 'EduLearn School',
    this.schoolYear = '',
    this.contactEmail = '',
  });

  final String schoolName;

  /// e.g. "2026–2027"
  final String schoolYear;
  final String contactEmail;

  factory SchoolSettings.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return SchoolSettings(
      schoolName: readString(d['schoolName'], 'EduLearn School'),
      schoolYear: readString(d['schoolYear']),
      contactEmail: readString(d['contactEmail']),
    );
  }

  Json toMap() => {
        'schoolName': schoolName.trim(),
        'schoolYear': schoolYear.trim(),
        'contactEmail': contactEmail.trim(),
      };
}
