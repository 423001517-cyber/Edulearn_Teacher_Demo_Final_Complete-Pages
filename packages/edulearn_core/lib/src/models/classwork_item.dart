import 'package:cloud_firestore/cloud_firestore.dart';

import '../dates.dart';
import 'model_utils.dart';
import 'post_attachment.dart';

enum ClassworkType {
  lesson('Lesson'),
  quest('Quest'),
  quiz('Quiz'),
  boss('Friday Boss Assessment'),
  activity('Activity'),
  material('Material');

  const ClassworkType(this.label);
  final String label;

  /// Lessons and materials are for reading; everything else is scored.
  bool get isGraded => this != ClassworkType.lesson && this != ClassworkType.material;

  /// Quizzes and Friday Boss Assessments have a question list.
  bool get hasQuestions => this == ClassworkType.quiz || this == ClassworkType.boss;

  /// "Friday Boss" in compact places (rows, chips).
  String get shortLabel => this == ClassworkType.boss ? 'Friday Boss' : label;

  int get defaultPoints => switch (this) {
        ClassworkType.lesson || ClassworkType.material => 0,
        ClassworkType.activity => 10,
        ClassworkType.boss => 50,
        ClassworkType.quest || ClassworkType.quiz => 20,
      };

  static ClassworkType parse(Object? v) => ClassworkType.values
      .firstWhere((t) => t.name == v, orElse: () => ClassworkType.quest);
}

enum Difficulty {
  easy('Easy'),
  medium('Medium'),
  hard('Hard');

  const Difficulty(this.label);
  final String label;

  static Difficulty parse(Object? v) =>
      Difficulty.values.firstWhere((d) => d.name == v, orElse: () => Difficulty.medium);
}

/// How students hand in an Activity.
enum SubmissionType {
  file('File upload', 'Students submit files (PDF, DOC, PPT, images, etc.)'),
  text('Text response', 'Students type their answer'),
  photo('Photo', 'Students submit a photo'),
  none('No submission', 'No submission required');

  const SubmissionType(this.label, this.hint);
  final String label;
  final String hint;

  static SubmissionType parse(Object? v) =>
      SubmissionType.values.firstWhere((t) => t.name == v, orElse: () => SubmissionType.file);
}

/// One row of an Activity rubric.
class RubricCriterion {
  const RubricCriterion({required this.title, this.description = '', this.points = 5});

  final String title;
  final String description;
  final int points;

  factory RubricCriterion.fromMap(Object? raw) {
    final d = raw is Map ? raw : const {};
    return RubricCriterion(
      title: readString(d['title'], 'Criterion'),
      description: readString(d['description']),
      points: d['points'] is num ? (d['points'] as num).toInt() : 0,
    );
  }

  Json toMap() => {'title': title, 'description': description, 'points': points};
}

enum ClassworkStatus {
  draft('Draft'),
  scheduled('Scheduled'),
  published('Published'),
  closed('Closed');

  const ClassworkStatus(this.label);
  final String label;

  static ClassworkStatus parse(Object? v) => ClassworkStatus.values
      .firstWhere((s) => s.name == v, orElse: () => ClassworkStatus.published);
}

/// `classwork/{itemId}` — lessons, quests, quizzes, activities, Friday Boss
/// Assessments and materials share one collection, keyed by `type`.
/// Quiz and boss answer keys live in `classwork/{id}/private/questions`
/// (teacher-only); [questionCount] mirrors their number.
class ClassworkItem {
  const ClassworkItem({
    this.id = '',
    required this.classId,
    required this.className,
    required this.type,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.status = ClassworkStatus.published,
    this.points = 0,
    this.attachmentUrl,
    this.attachmentName,
    this.assignedStudentIds = const [],
    this.createdAt,
    this.submittedCount = 0,
    this.scoreSum = 0,
    this.scoredCount = 0,
    this.commentCount = 0,
    this.attachmentSize,
    // ---- Classwork module
    this.topicId,
    this.quarter = 1,
    this.position = 0,
    this.attachments = const [],
    this.publishAt,
    this.objectives = '',
    this.content = '',
    this.postToStream = true,
    this.notifyStudents = true,
    this.allowLate = false,
    this.xpReward = 0,
    this.coinReward = 0,
    this.attempts = 1,
    this.difficulty = Difficulty.medium,
    this.submissionType = SubmissionType.file,
    this.groupWork = false,
    this.rubric = const [],
    this.timeLimitMinutes,
    this.shuffleQuestions = false,
    this.shuffleChoices = false,
    this.showScoreImmediately = true,
    this.autoGrade = true,
    this.questionCount = 0,
    this.passingScore = 70,
    this.bossId = 'kapuluan',
    this.bossHp = 100,
    this.rewardBadge = '',
    this.showExplanations = true,
  });

  final String id;
  final String classId;
  final String className;
  final ClassworkType type;
  final String title;

  /// Instructions / description (formatted like stream posts).
  final String description;

  /// Due date (quests, quizzes, activities, boss) or publish date (lessons,
  /// materials). Includes the due time.
  final DateTime dueDate;
  final ClassworkStatus status;
  final int points;

  /// Legacy single attachment (kept so older items still show their file).
  final String? attachmentUrl;
  final String? attachmentName;

  /// Empty = whole class. Remedial quests target specific students.
  final List<String> assignedStudentIds;
  final DateTime? createdAt;

  // Maintained by the `onSubmissionWritten` Cloud Function.
  final int submittedCount;
  final double scoreSum; // sum of score/maxScore ratios
  final int scoredCount;

  /// Class comments on this item (kept by a Cloud Function).
  final int commentCount;

  /// Bytes of the legacy attachment, when known.
  final int? attachmentSize;

  /// `classes/{classId}/topics/{topicId}`; null = "No topic".
  final String? topicId;
  final int quarter;

  /// Order inside its topic (drag to reorder).
  final double position;
  final List<PostAttachment> attachments;

  /// When a scheduled item goes live (publishScheduledPosts function).
  final DateTime? publishAt;

  /// Lesson "Learning objectives" / quest "Learning objective".
  final String objectives;

  /// Lesson content.
  final String content;
  final bool postToStream;
  final bool notifyStudents;
  final bool allowLate;

  // Quest / boss game settings
  final int xpReward;
  final int coinReward;
  final int attempts;
  final Difficulty difficulty;

  // Activity
  final SubmissionType submissionType;
  final bool groupWork;
  final List<RubricCriterion> rubric;

  // Quiz / boss
  final int? timeLimitMinutes;
  final bool shuffleQuestions;
  final bool shuffleChoices;
  final bool showScoreImmediately;
  final bool autoGrade;
  final int questionCount;

  // Friday Boss
  final int passingScore;
  final String bossId;
  final int bossHp;
  final String rewardBadge;
  final bool showExplanations;

  factory ClassworkItem.fromDoc(Doc doc) {
    final d = dataOf(doc);
    int i(String k, int fallback) => d[k] is num ? (d[k] as num).toInt() : fallback;
    bool b(String k, bool fallback) => d[k] is bool ? d[k] as bool : fallback;
    return ClassworkItem(
      id: doc.id,
      classId: readString(d['classId']),
      className: readString(d['className']),
      type: ClassworkType.parse(d['type']),
      title: readString(d['title'], 'Untitled'),
      description: readString(d['description']),
      dueDate: readDate(d['dueDate']) ?? DateTime.now(),
      status: ClassworkStatus.parse(d['status']),
      points: readInt(d['points']),
      attachmentUrl: readStringOrNull(d['attachmentUrl']),
      attachmentName: readStringOrNull(d['attachmentName']),
      assignedStudentIds: readStringList(d['assignedStudentIds']),
      createdAt: readDate(d['createdAt']),
      submittedCount: readInt(d['submittedCount']),
      scoreSum: readDouble(d['scoreSum']),
      scoredCount: readInt(d['scoredCount']),
      commentCount: readInt(d['commentCount']),
      attachmentSize: d['attachmentSize'] is num ? (d['attachmentSize'] as num).toInt() : null,
      topicId: readStringOrNull(d['topicId']),
      quarter: i('quarter', 1),
      position: readDouble(d['position']),
      attachments: PostAttachment.listFrom(d['attachments']),
      publishAt: readDate(d['publishAt']),
      objectives: readString(d['objectives']),
      content: readString(d['content']),
      postToStream: b('postToStream', true),
      notifyStudents: b('notifyStudents', true),
      allowLate: b('allowLate', false),
      xpReward: i('xpReward', 0),
      coinReward: i('coinReward', 0),
      attempts: i('attempts', 1),
      difficulty: Difficulty.parse(d['difficulty']),
      submissionType: SubmissionType.parse(d['submissionType']),
      groupWork: b('groupWork', false),
      rubric: d['rubric'] is List ? (d['rubric'] as List).map(RubricCriterion.fromMap).toList() : const [],
      timeLimitMinutes: d['timeLimitMinutes'] is num ? (d['timeLimitMinutes'] as num).toInt() : null,
      shuffleQuestions: b('shuffleQuestions', false),
      shuffleChoices: b('shuffleChoices', false),
      showScoreImmediately: b('showScoreImmediately', true),
      autoGrade: b('autoGrade', true),
      questionCount: i('questionCount', 0),
      passingScore: i('passingScore', 70),
      bossId: readString(d['bossId'], 'kapuluan'),
      bossHp: i('bossHp', 100),
      rewardBadge: readString(d['rewardBadge']),
      showExplanations: b('showExplanations', true),
    );
  }

  Json toMap() => {
        'classId': classId,
        'className': className,
        'type': type.name,
        'title': title,
        'description': description,
        'dueDate': Timestamp.fromDate(dueDate),
        'status': status.name,
        'points': points,
        'attachmentUrl': attachmentUrl,
        'attachmentName': attachmentName,
        'attachmentSize': attachmentSize,
        'assignedStudentIds': assignedStudentIds,
        'topicId': topicId,
        'quarter': quarter,
        'position': position,
        'attachments': [for (final a in attachments) a.toMap()],
        'publishAt': publishAt == null ? null : Timestamp.fromDate(publishAt!),
        'objectives': objectives,
        'content': content,
        'postToStream': postToStream,
        'notifyStudents': notifyStudents,
        'allowLate': allowLate,
        'xpReward': xpReward,
        'coinReward': coinReward,
        'attempts': attempts,
        'difficulty': difficulty.name,
        'submissionType': submissionType.name,
        'groupWork': groupWork,
        'rubric': [for (final r in rubric) r.toMap()],
        'timeLimitMinutes': timeLimitMinutes,
        'shuffleQuestions': shuffleQuestions,
        'shuffleChoices': shuffleChoices,
        'showScoreImmediately': showScoreImmediately,
        'autoGrade': autoGrade,
        'questionCount': questionCount,
        'passingScore': passingScore,
        'bossId': bossId,
        'bossHp': bossHp,
        'rewardBadge': rewardBadge,
        'showExplanations': showExplanations,
      };

  /// Every file / link / video, including a legacy single attachment.
  List<PostAttachment> get allAttachments => [
        if (attachmentName != null && !attachments.any((a) => a.name == attachmentName))
          PostAttachment(name: attachmentName!, url: attachmentUrl, sizeBytes: attachmentSize),
        ...attachments,
      ];

  /// "Monday Quest", "Thursday Activity", "Friday Boss Assessment".
  String get headline => switch (type) {
        ClassworkType.quest || ClassworkType.activity =>
          '${weekdayName(dueDate)} ${type.label}',
        _ => type.label,
      };

  bool get isRemedial => assignedStudentIds.isNotEmpty;

  /// Share of assigned students who submitted, 0.0 – 1.0.
  double completionRate(int classSize) {
    final assigned = assignedStudentIds.isNotEmpty ? assignedStudentIds.length : classSize;
    if (assigned <= 0) return 0;
    return (submittedCount / assigned).clamp(0.0, 1.0).toDouble();
  }

  /// Average score of returned work, or null if nothing is graded yet.
  double? get averageScore => scoredCount == 0 ? null : scoreSum / scoredCount;

  bool isPastDue(DateTime now) => dueDate.isBefore(startOfDay(now));

  /// Students can see it (scheduled items go live at [publishAt]).
  bool isLive(DateTime now) =>
      status == ClassworkStatus.published ||
      status == ClassworkStatus.closed ||
      (status == ClassworkStatus.scheduled && publishAt != null && !publishAt!.isAfter(now));

  /// This item's basic fields (title, dates, points…) with every
  /// Classwork-module setting (topic, quarter, attachments, game, quiz and
  /// boss settings) taken from [stored] — so simpler editors can't wipe them.
  ClassworkItem withSettingsFrom(ClassworkItem stored) => ClassworkItem(
        id: id,
        classId: classId,
        className: className,
        type: type,
        title: title,
        description: description,
        dueDate: dueDate,
        status: status,
        points: points,
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
        attachmentSize: attachmentSize,
        assignedStudentIds: assignedStudentIds,
        topicId: stored.topicId,
        quarter: stored.quarter,
        position: stored.position,
        attachments: stored.attachments,
        publishAt: stored.publishAt,
        objectives: stored.objectives,
        content: stored.content,
        postToStream: stored.postToStream,
        notifyStudents: stored.notifyStudents,
        allowLate: stored.allowLate,
        xpReward: stored.xpReward,
        coinReward: stored.coinReward,
        attempts: stored.attempts,
        difficulty: stored.difficulty,
        submissionType: stored.submissionType,
        groupWork: stored.groupWork,
        rubric: stored.rubric,
        timeLimitMinutes: stored.timeLimitMinutes,
        shuffleQuestions: stored.shuffleQuestions,
        shuffleChoices: stored.shuffleChoices,
        showScoreImmediately: stored.showScoreImmediately,
        autoGrade: stored.autoGrade,
        questionCount: stored.questionCount,
        passingScore: stored.passingScore,
        bossId: stored.bossId,
        bossHp: stored.bossHp,
        rewardBadge: stored.rewardBadge,
        showExplanations: stored.showExplanations,
      );

  ClassworkItem copyWith({
    String? id,
    String? classId,
    String? className,
    String? title,
    DateTime? dueDate,
    ClassworkStatus? status,
    List<String>? assignedStudentIds,
    String? topicId,
    bool clearTopic = false,
    int? quarter,
    double? position,
    List<PostAttachment>? attachments,
    DateTime? publishAt,
    bool clearPublishAt = false,
  }) =>
      ClassworkItem(
        id: id ?? this.id,
        classId: classId ?? this.classId,
        className: className ?? this.className,
        type: type,
        title: title ?? this.title,
        description: description,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        points: points,
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
        attachmentSize: attachmentSize,
        assignedStudentIds: assignedStudentIds ?? this.assignedStudentIds,
        topicId: clearTopic ? null : (topicId ?? this.topicId),
        quarter: quarter ?? this.quarter,
        position: position ?? this.position,
        attachments: attachments ?? this.attachments,
        publishAt: clearPublishAt ? null : (publishAt ?? this.publishAt),
        objectives: objectives,
        content: content,
        postToStream: postToStream,
        notifyStudents: notifyStudents,
        allowLate: allowLate,
        xpReward: xpReward,
        coinReward: coinReward,
        attempts: attempts,
        difficulty: difficulty,
        submissionType: submissionType,
        groupWork: groupWork,
        rubric: rubric,
        timeLimitMinutes: timeLimitMinutes,
        shuffleQuestions: shuffleQuestions,
        shuffleChoices: shuffleChoices,
        showScoreImmediately: showScoreImmediately,
        autoGrade: autoGrade,
        questionCount: questionCount,
        passingScore: passingScore,
        bossId: bossId,
        bossHp: bossHp,
        rewardBadge: rewardBadge,
        showExplanations: showExplanations,
      );
}
