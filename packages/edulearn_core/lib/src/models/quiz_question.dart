import 'model_utils.dart';

enum QuestionType {
  multipleChoice('Multiple choice'),
  trueFalse('True or false'),
  shortAnswer('Short answer');

  const QuestionType(this.label);
  final String label;

  static QuestionType parse(Object? v) =>
      QuestionType.values.firstWhere((t) => t.name == v, orElse: () => QuestionType.multipleChoice);
}

/// One quiz / Friday Boss question. Stored in
/// `classwork/{id}/private/questions` (teacher-only) because it contains the
/// answer key; the student app gets questions without answers.
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    this.text = '',
    this.type = QuestionType.multipleChoice,
    this.choices = const ['', '', '', ''],
    this.correctIndex = 0,
    this.answer = '',
    this.points = 1,
    this.explanation = '',
  });

  final String id;
  final String text;
  final QuestionType type;

  /// Multiple choice options (A, B, C, D…). True/false uses ["Tama", "Mali"].
  final List<String> choices;
  final int correctIndex;

  /// Accepted answer for short-answer questions.
  final String answer;
  final int points;

  /// Shown after the attempt when the boss setting is on.
  final String explanation;

  factory QuizQuestion.fromMap(Object? raw) {
    final d = raw is Map ? raw : const {};
    return QuizQuestion(
      id: readString(d['id'], 'q${d.hashCode}'),
      text: readString(d['text']),
      type: QuestionType.parse(d['type']),
      choices: d['choices'] is List ? [for (final c in d['choices'] as List) '$c'] : const [],
      correctIndex: d['correctIndex'] is num ? (d['correctIndex'] as num).toInt() : 0,
      answer: readString(d['answer']),
      points: d['points'] is num ? (d['points'] as num).toInt() : 1,
      explanation: readString(d['explanation']),
    );
  }

  Json toMap() => {
        'id': id,
        'text': text,
        'type': type.name,
        'choices': choices,
        'correctIndex': correctIndex,
        'answer': answer,
        'points': points,
        'explanation': explanation,
      };

  QuizQuestion copyWith({
    String? text,
    QuestionType? type,
    List<String>? choices,
    int? correctIndex,
    String? answer,
    int? points,
    String? explanation,
  }) =>
      QuizQuestion(
        id: id,
        text: text ?? this.text,
        type: type ?? this.type,
        choices: choices ?? this.choices,
        correctIndex: correctIndex ?? this.correctIndex,
        answer: answer ?? this.answer,
        points: points ?? this.points,
        explanation: explanation ?? this.explanation,
      );

  /// Problems that block assigning ("Question 3 has no correct answer").
  String? problem(int number) {
    if (text.trim().isEmpty) return 'Question $number has no question text.';
    if (points < 1) return 'Question $number needs at least 1 point.';
    switch (type) {
      case QuestionType.multipleChoice:
        final filled = choices.where((c) => c.trim().isNotEmpty).length;
        if (filled < 2) return 'Question $number needs at least two choices.';
        if (correctIndex < 0 || correctIndex >= choices.length || choices[correctIndex].trim().isEmpty) {
          return 'Question $number has no correct answer selected.';
        }
      case QuestionType.trueFalse:
        if (correctIndex < 0 || correctIndex > 1) return 'Question $number has no correct answer selected.';
      case QuestionType.shortAnswer:
        if (answer.trim().isEmpty) return 'Question $number needs the accepted answer.';
    }
    return null;
  }
}

/// Total points of a question list.
int totalQuestionPoints(Iterable<QuizQuestion> qs) => qs.fold(0, (n, q) => n + q.points);

/// A Friday Boss character students battle (illustrations come with the
/// student app; the teacher site shows a themed card).
class BossCharacter {
  const BossCharacter(this.id, this.name, this.tagline, this.emoji);

  final String id;
  final String name;
  final String tagline;
  final String emoji;

  static const all = [
    BossCharacter('kapuluan', 'Tagapangalaga ng Kapuluan', 'Tagapangalaga ng karagatan at mga isla ng Pilipinas.', '🛡️'),
    BossCharacter('bulkan', 'Diwata ng Bulkan', 'Bantay ng mga bulkan at kabundukan.', '🌋'),
    BossCharacter('bayani', 'Anino ng Kasaysayan', 'Sinusubok ang kaalaman mo sa ating mga bayani.', '📜'),
    BossCharacter('kalikasan', 'Higante ng Kalikasan', 'Tagapagtanggol ng likas na yaman ng bansa.', '🌳'),
  ];

  static BossCharacter byId(String id) => all.firstWhere((b) => b.id == id, orElse: () => all.first);
}

/// Badges a Friday Boss can award (shown in the student app).
const rewardBadges = ['Rehiyon Master', 'Bayani ng Kasaysayan', 'Tagapagtanggol ng Kalikasan', 'Kampeon ng Kapuluan'];
