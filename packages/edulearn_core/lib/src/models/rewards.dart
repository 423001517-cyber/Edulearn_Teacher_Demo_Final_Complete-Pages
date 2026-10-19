import 'model_utils.dart';

/// Ways students earn points automatically (Rewards › How students earn points).
enum PointRule {
  quest('Finish a quest', 10),
  activity('Turn in an activity', 15),
  perfectQuiz('Perfect quiz score', 25),
  bossPass('Pass the Friday Boss', 30),
  onTime('Turn work in on time', 5);

  const PointRule(this.label, this.defaultPoints);
  final String label;
  final int defaultPoints;
}

/// What a badge is awarded for. Every kind except [manual] is worked out
/// from submissions, so badges appear on their own.
enum BadgeKind {
  topScorer('Score 90% or higher', 'times'),
  quizWhiz('Get a perfect quiz score', 'quizzes'),
  bossSlayer('Pass the Friday Boss', 'times'),
  perfectWeek('Turn in everything on time for a week', 'weeks'),
  earlyBird('Turn work in a day before it is due', 'times'),
  manual('Given by you', '');

  const BadgeKind(this.rule, this.unit);
  final String rule;
  final String unit;

  static BadgeKind parse(Object? v) =>
      BadgeKind.values.firstWhere((k) => k.name == v, orElse: () => BadgeKind.manual);
}

/// A badge students can earn. [icon] and [tone] are keys the UI maps to an
/// icon and color (see RewardIcons in edulearn_ui).
class BadgeDef {
  const BadgeDef({
    required this.id,
    required this.name,
    required this.kind,
    this.threshold = 1,
    this.icon = 'star',
    this.tone = 'green',
    this.enabled = true,
    this.description = '',
  });

  final String id;
  final String name;
  final BadgeKind kind;

  /// How many times the rule must be met (ignored for manual badges).
  final int threshold;
  final String icon;
  final String tone;
  final bool enabled;

  /// Only used by manual badges ("Given for helping a classmate").
  final String description;

  /// "Score 90% or higher 5 times"
  String get ruleText {
    if (kind == BadgeKind.manual) return description.isEmpty ? 'Given by you' : description;
    if (threshold <= 1) return kind.rule;
    return '${kind.rule} $threshold ${kind.unit}';
  }

  factory BadgeDef.fromMap(Object? raw) {
    final d = raw is Map ? raw : const {};
    return BadgeDef(
      id: readString(d['id'], 'badge'),
      name: readString(d['name'], 'Badge'),
      kind: BadgeKind.parse(d['kind']),
      threshold: d['threshold'] is num ? (d['threshold'] as num).toInt().clamp(1, 100).toInt() : 1,
      icon: readString(d['icon'], 'star'),
      tone: readString(d['tone'], 'green'),
      enabled: d['enabled'] != false,
      description: readString(d['description']),
    );
  }

  Json toMap() => {
        'id': id,
        'name': name.trim(),
        'kind': kind.name,
        'threshold': threshold,
        'icon': icon,
        'tone': tone,
        'enabled': enabled,
        'description': description.trim(),
      };

  BadgeDef copyWith({String? name, int? threshold, String? icon, String? tone, bool? enabled, String? description}) =>
      BadgeDef(
        id: id,
        name: name ?? this.name,
        kind: kind,
        threshold: threshold ?? this.threshold,
        icon: icon ?? this.icon,
        tone: tone ?? this.tone,
        enabled: enabled ?? this.enabled,
        description: description ?? this.description,
      );
}

/// Something students can spend points on (Rewards › Reward shop).
class ShopItem {
  const ShopItem({required this.id, required this.name, required this.cost, this.icon = 'gift', this.active = true});

  final String id;
  final String name;
  final int cost;
  final String icon;

  /// Hidden from students when false.
  final bool active;

  factory ShopItem.fromMap(Object? raw) {
    final d = raw is Map ? raw : const {};
    return ShopItem(
      id: readString(d['id'], 'item'),
      name: readString(d['name'], 'Reward'),
      cost: readInt(d['cost'], 100),
      icon: readString(d['icon'], 'gift'),
      active: d['active'] != false,
    );
  }

  Json toMap() => {'id': id, 'name': name.trim(), 'cost': cost, 'icon': icon, 'active': active};

  ShopItem copyWith({String? name, int? cost, String? icon, bool? active}) => ShopItem(
        id: id,
        name: name ?? this.name,
        cost: cost ?? this.cost,
        icon: icon ?? this.icon,
        active: active ?? this.active,
      );
}

/// `classes/{classId}/rewards/settings`
class RewardSettings {
  const RewardSettings({
    this.points = const {},
    this.levelSize = 200,
    this.badges = defaultBadges,
    this.shop = defaultShop,
  });

  static const defaultBadges = [
    BadgeDef(id: 'top-scorer', name: 'Top Scorer', kind: BadgeKind.topScorer, threshold: 5, icon: 'target', tone: 'green'),
    BadgeDef(id: 'quiz-whiz', name: 'Quiz Whiz', kind: BadgeKind.quizWhiz, icon: 'quiz', tone: 'purple'),
    BadgeDef(id: 'boss-slayer', name: 'Boss Slayer', kind: BadgeKind.bossSlayer, threshold: 3, icon: 'crown', tone: 'amber'),
    BadgeDef(id: 'perfect-week', name: 'Perfect Week', kind: BadgeKind.perfectWeek, icon: 'calendar', tone: 'blue'),
    BadgeDef(id: 'early-bird', name: 'Early Bird', kind: BadgeKind.earlyBird, threshold: 3, icon: 'sun', tone: 'amber'),
    BadgeDef(
      id: 'helping-hand',
      name: 'Helping Hand',
      kind: BadgeKind.manual,
      icon: 'heart',
      tone: 'red',
      description: 'Given by you for helping a classmate',
    ),
  ];

  static const defaultShop = [
    ShopItem(id: 'class-game', name: 'Pick the class review game', cost: 200, icon: 'game'),
    ShopItem(id: 'line-leader', name: 'Line leader for a day', cost: 150, icon: 'flag'),
    ShopItem(id: 'seat', name: 'Choose your seat for a day', cost: 120, icon: 'seat'),
    ShopItem(id: 'homework-pass', name: 'One-day homework pass', cost: 300, icon: 'ticket', active: false),
  ];

  /// Only rules that differ from [PointRule.defaultPoints] need to be stored.
  final Map<PointRule, int> points;

  /// Points per level (Level 1 starts at 0).
  final int levelSize;
  final List<BadgeDef> badges;
  final List<ShopItem> shop;

  int pointsFor(PointRule r) => points[r] ?? r.defaultPoints;

  factory RewardSettings.fromMap(Map<String, dynamic>? d) {
    if (d == null) return const RewardSettings();
    final raw = d['points'];
    return RewardSettings(
      points: {
        for (final r in PointRule.values)
          if (raw is Map && raw[r.name] is num) r: (raw[r.name] as num).toInt(),
      },
      levelSize: d['levelSize'] is num ? (d['levelSize'] as num).toInt().clamp(50, 5000).toInt() : 200,
      badges: d['badges'] is List ? (d['badges'] as List).map(BadgeDef.fromMap).toList() : defaultBadges,
      shop: d['shop'] is List ? (d['shop'] as List).map(ShopItem.fromMap).toList() : defaultShop,
    );
  }

  Json toMap() => {
        'points': {for (final r in PointRule.values) r.name: pointsFor(r)},
        'levelSize': levelSize,
        'badges': [for (final b in badges) b.toMap()],
        'shop': [for (final s in shop) s.toMap()],
      };

  RewardSettings copyWith({Map<PointRule, int>? points, int? levelSize, List<BadgeDef>? badges, List<ShopItem>? shop}) =>
      RewardSettings(
        points: points ?? this.points,
        levelSize: levelSize ?? this.levelSize,
        badges: badges ?? this.badges,
        shop: shop ?? this.shop,
      );
}

/// `pointAwards/{id}` — points (and manual badges) a teacher gives by hand.
class PointAward {
  const PointAward({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.studentName,
    required this.points,
    this.reason = '',
    this.badgeId,
    this.createdAt,
  });

  final String id;
  final String classId;
  final String studentId;
  final String studentName;

  /// Can be negative (taking points back).
  final int points;
  final String reason;

  /// A manual badge given with the points ("Helping Hand").
  final String? badgeId;
  final DateTime? createdAt;

  factory PointAward.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return PointAward(
      id: doc.id,
      classId: readString(d['classId']),
      studentId: readString(d['studentId']),
      studentName: readString(d['studentName'], 'Student'),
      points: readInt(d['points']),
      reason: readString(d['reason']),
      badgeId: readStringOrNull(d['badgeId']),
      createdAt: readDate(d['createdAt']),
    );
  }
}

enum RewardStatus {
  pending('Waiting'),
  approved('Approved'),
  declined('Declined');

  const RewardStatus(this.label);
  final String label;

  static RewardStatus parse(Object? v) =>
      RewardStatus.values.firstWhere((s) => s.name == v, orElse: () => RewardStatus.pending);
}

/// `rewardRequests/{id}` — created by the student app when a student
/// redeems a reward; the teacher approves or declines it.
class RewardRequest {
  const RewardRequest({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.studentName,
    required this.itemId,
    required this.itemName,
    required this.cost,
    required this.status,
    this.createdAt,
    this.decidedAt,
  });

  final String id;
  final String classId;
  final String studentId;
  final String studentName;
  final String itemId;
  final String itemName;
  final int cost;
  final RewardStatus status;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  factory RewardRequest.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return RewardRequest(
      id: doc.id,
      classId: readString(d['classId']),
      studentId: readString(d['studentId']),
      studentName: readString(d['studentName'], 'Student'),
      itemId: readString(d['itemId']),
      itemName: readString(d['itemName'], 'Reward'),
      cost: readInt(d['cost']),
      status: RewardStatus.parse(d['status']),
      createdAt: readDate(d['createdAt']),
      decidedAt: readDate(d['decidedAt']),
    );
  }
}
