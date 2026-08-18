import '../../../core/utils/formatters.dart';

/// Canal d'envoi d'une campagne ou d'un rappel.
enum CampaignChannel {
  sms('sms', 'SMS'),
  whatsapp('whatsapp', 'WhatsApp'),
  both('both', 'SMS + WhatsApp');

  const CampaignChannel(this.value, this.label);

  final String value;
  final String label;

  static CampaignChannel fromValue(String? value) =>
      CampaignChannel.values.firstWhere(
        (channel) => channel.value == value,
        orElse: () => sms,
      );
}

/// Palier du programme de fidélité.
enum LoyaltyTier {
  bronze('Bronze', 0),
  silver('Argent', 200),
  gold('Or', 400),
  platinum('Platine', 800);

  const LoyaltyTier(this.label, this.threshold);

  final String label;
  final int threshold;

  static LoyaltyTier forPoints(int points) {
    var tier = LoyaltyTier.bronze;
    for (final candidate in LoyaltyTier.values) {
      if (points >= candidate.threshold) tier = candidate;
    }
    return tier;
  }

  /// Remise accordée en caisse, en pourcentage du sous-total.
  ///
  /// Bronze ne donne droit à rien : c'est le palier d'entrée, tout le monde y
  /// est dès la première visite. La remise commence à Argent, soit 200 points
  /// — environ 200 000 F dépensés, un point étant acquis par tranche de
  /// 1 000 F.
  int get discountPercent => switch (this) {
    bronze => 0,
    silver => 5,
    gold => 10,
    platinum => 15,
  };

  /// Palier suivant, ou `null` si le client est au sommet.
  LoyaltyTier? get next {
    final index = LoyaltyTier.values.indexOf(this);
    return index == LoyaltyTier.values.length - 1
        ? null
        : LoyaltyTier.values[index + 1];
  }
}

/// Récompense échangeable — table `loyalty_rewards`.
class LoyaltyReward {
  const LoyaltyReward({
    required this.id,
    required this.salonId,
    required this.name,
    required this.pointsCost,
    this.description,
    this.isActive = true,
  });

  final String id;
  final String salonId;
  final String name;
  final int pointsCost;
  final String? description;
  final bool isActive;

  bool isUnlockedAt(int points) => points >= pointsCost;

  factory LoyaltyReward.fromMap(Map<String, dynamic> map) => LoyaltyReward(
        id: map['id'] as String,
        salonId: map['salon_id'] as String,
        name: (map['name'] as String?) ?? '',
        pointsCost: (map['points_cost'] as num?)?.toInt() ?? 0,
        description: map['description'] as String?,
        isActive: (map['is_active'] as bool?) ?? true,
      );

  Map<String, dynamic> toMap() => {
        'salon_id': salonId,
        'name': name,
        'points_cost': pointsCost,
        'description': description,
        'is_active': isActive,
      };
}

/// Promotion / offre commerciale — table `promotions`.
class Promotion {
  const Promotion({
    required this.id,
    required this.salonId,
    required this.name,
    required this.description,
    required this.isActive,
    this.startsAt,
    this.endsAt,
    this.usageCount = 0,
    this.revenueFcfa = 0,
    this.isAutomatic = false,
  });

  final String id;
  final String salonId;
  final String name;
  final String description;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// Nombre d'utilisations et CA généré (agrégés côté base).
  final int usageCount;
  final int revenueFcfa;

  /// Promotion déclenchée automatiquement (anniversaire cliente…).
  final bool isAutomatic;

  bool get isScheduled =>
      startsAt != null && startsAt!.isAfter(DateTime.now());

  String get periodLabel {
    if (isScheduled) return 'Démarre le ${Formatters.dayMonth(startsAt!)}';
    if (endsAt != null) return 'Jusqu\'au ${Formatters.dayMonth(endsAt!)}';
    return 'Sans date de fin';
  }

  factory Promotion.fromMap(Map<String, dynamic> map) => Promotion(
        id: map['id'] as String,
        salonId: map['salon_id'] as String,
        name: (map['name'] as String?) ?? '',
        description: (map['description'] as String?) ?? '',
        isActive: (map['is_active'] as bool?) ?? false,
        startsAt: map['starts_at'] == null
            ? null
            : DateTime.parse(map['starts_at'] as String).toLocal(),
        endsAt: map['ends_at'] == null
            ? null
            : DateTime.parse(map['ends_at'] as String).toLocal(),
        usageCount: (map['usage_count'] as num?)?.toInt() ?? 0,
        revenueFcfa: (map['revenue_fcfa'] as num?)?.toInt() ?? 0,
        isAutomatic: (map['is_automatic'] as bool?) ?? false,
      );

  Map<String, dynamic> toMap() => {
        'salon_id': salonId,
        'name': name,
        'description': description,
        'is_active': isActive,
        'starts_at': startsAt?.toUtc().toIso8601String(),
        'ends_at': endsAt?.toUtc().toIso8601String(),
        'is_automatic': isAutomatic,
      };
}

/// Rappel automatique — table `reminder_rules`.
class ReminderRule {
  const ReminderRule({
    required this.id,
    required this.salonId,
    required this.name,
    required this.channel,
    required this.isEnabled,
    this.description,
    this.messageTemplate,
  });

  final String id;
  final String salonId;
  final String name;
  final CampaignChannel channel;
  final bool isEnabled;
  final String? description;

  /// Modèle de message envoyé au client.
  final String? messageTemplate;

  factory ReminderRule.fromMap(Map<String, dynamic> map) => ReminderRule(
        id: map['id'] as String,
        salonId: map['salon_id'] as String,
        name: (map['name'] as String?) ?? '',
        channel: CampaignChannel.fromValue(map['channel'] as String?),
        isEnabled: (map['is_enabled'] as bool?) ?? false,
        description: map['description'] as String?,
        messageTemplate: map['message_template'] as String?,
      );
}

/// Statistiques d'envoi des rappels (vue `reminder_stats`).
class ReminderStats {
  const ReminderStats({required this.sentThisMonth, required this.showUpRate});

  final int sentThisMonth;

  /// Taux de présence, entre 0 et 1.
  final double showUpRate;

  static const ReminderStats empty =
      ReminderStats(sentThisMonth: 0, showUpRate: 0);

  factory ReminderStats.fromMap(Map<String, dynamic> map) => ReminderStats(
        sentThisMonth: (map['sent_this_month'] as num?)?.toInt() ?? 0,
        showUpRate: (map['show_up_rate'] as num?)?.toDouble() ?? 0,
      );
}

/// Campagne marketing ponctuelle — table `campaigns`.
class LoyaltyCampaign {
  const LoyaltyCampaign({
    required this.id,
    required this.salonId,
    required this.name,
    required this.channel,
    required this.message,
    this.targetTags = const [],
    this.scheduledAt,
    this.sentCount = 0,
  });

  final String id;
  final String salonId;
  final String name;
  final CampaignChannel channel;
  final String message;

  /// Segments ciblés (étiquettes CRM : VIP, inactifs, coloration…).
  final List<String> targetTags;

  final DateTime? scheduledAt;
  final int sentCount;

  factory LoyaltyCampaign.fromMap(Map<String, dynamic> map) => LoyaltyCampaign(
        id: map['id'] as String,
        salonId: map['salon_id'] as String,
        name: (map['name'] as String?) ?? '',
        channel: CampaignChannel.fromValue(map['channel'] as String?),
        message: (map['message'] as String?) ?? '',
        targetTags:
            (map['target_tags'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        scheduledAt: map['scheduled_at'] == null
            ? null
            : DateTime.parse(map['scheduled_at'] as String).toLocal(),
        sentCount: (map['sent_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'salon_id': salonId,
        'name': name,
        'channel': channel.value,
        'message': message,
        'target_tags': targetTags,
        'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
      };
}

/// Règle de conversion des points de fidélité.
class LoyaltyRule {
  const LoyaltyRule({
    this.pointsPerThousandFcfa = 1,
    this.pointsForReward = 100,
    this.rewardValueFcfa = 5000,
  });

  /// Points gagnés par tranche de 1 000 FCFA dépensés.
  final int pointsPerThousandFcfa;

  /// Points nécessaires pour débloquer une récompense.
  final int pointsForReward;

  /// Valeur de la récompense.
  final int rewardValueFcfa;

  int pointsEarned(int amountFcfa) =>
      (amountFcfa ~/ 1000) * pointsPerThousandFcfa;

  bool canRedeem(int points) => points >= pointsForReward;
}
