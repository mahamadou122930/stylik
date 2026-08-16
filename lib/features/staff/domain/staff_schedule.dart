import '../../../core/utils/formatters.dart';

/// Horaire de travail d'un membre pour un jour de la semaine.
///
/// Stocké dans `profiles.working_hours` (JSONB) sous la forme :
/// `{"1": {"start": "09:00", "end": "19:00"}, ...}` (1 = lundi).
class StaffSchedule {
  const StaffSchedule({
    required this.weekday,
    required this.start,
    required this.end,
    this.isDayOff = false,
  });

  /// 1 = lundi … 7 = dimanche (aligné sur [DateTime.weekday]).
  final int weekday;

  /// Heure au format `HH:mm`.
  final String start;
  final String end;
  final bool isDayOff;

  static const List<String> weekdayLabels = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  String get weekdayLabel => weekdayLabels[(weekday - 1).clamp(0, 6)];

  /// Amplitude de la journée en heures décimales.
  double get hours {
    if (isDayOff) return 0;
    final startParts = start.split(':');
    final endParts = end.split(':');
    if (startParts.length < 2 || endParts.length < 2) return 0;

    final startMinutes =
        (int.tryParse(startParts[0]) ?? 0) * 60 + (int.tryParse(startParts[1]) ?? 0);
    final endMinutes =
        (int.tryParse(endParts[0]) ?? 0) * 60 + (int.tryParse(endParts[1]) ?? 0);
    return (endMinutes - startMinutes).clamp(0, 24 * 60) / 60;
  }

  StaffSchedule copyWith({String? start, String? end, bool? isDayOff}) =>
      StaffSchedule(
        weekday: weekday,
        start: start ?? this.start,
        end: end ?? this.end,
        isDayOff: isDayOff ?? this.isDayOff,
      );

  factory StaffSchedule.fromMap(int weekday, Map<String, dynamic> map) =>
      StaffSchedule(
        weekday: weekday,
        start: (map['start'] as String?) ?? '09:00',
        end: (map['end'] as String?) ?? '19:00',
        isDayOff: (map['is_day_off'] as bool?) ?? false,
      );

  Map<String, dynamic> toMap() => {
        'start': start,
        'end': end,
        'is_day_off': isDayOff,
      };

  /// Convertit la colonne JSONB complète en semaine ordonnée, en complétant
  /// les jours absents par un jour de repos.
  static List<StaffSchedule> listFromJson(Map<String, dynamic>? json) {
    return [
      for (var weekday = 1; weekday <= 7; weekday++)
        if (json?['$weekday'] is Map<String, dynamic>)
          StaffSchedule.fromMap(
            weekday,
            json!['$weekday'] as Map<String, dynamic>,
          )
        else
          StaffSchedule(
            weekday: weekday,
            start: '09:00',
            end: '19:00',
            isDayOff: true,
          ),
    ];
  }

  /// Total hebdomadaire, en heures.
  static double weeklyHours(List<StaffSchedule> week) =>
      week.fold(0, (sum, day) => sum + day.hours);
}

/// Type d'absence (`time_off.type`).
enum TimeOffType {
  vacation('vacation', 'Congé'),
  sickLeave('sick_leave', 'Absence maladie'),
  unpaid('unpaid', 'Absence non payée');

  const TimeOffType(this.value, this.label);

  final String value;
  final String label;

  static TimeOffType fromValue(String? value) => TimeOffType.values.firstWhere(
        (type) => type.value == value,
        orElse: () => vacation,
      );
}

/// Statut d'une demande d'absence.
enum TimeOffStatus {
  pending('pending', 'À valider'),
  approved('approved', 'Validé'),
  rejected('rejected', 'Refusé');

  const TimeOffStatus(this.value, this.label);

  final String value;
  final String label;

  static TimeOffStatus fromValue(String? value) =>
      TimeOffStatus.values.firstWhere(
        (status) => status.value == value,
        orElse: () => pending,
      );
}

/// Congé ou absence — table `time_off`.
class TimeOff {
  const TimeOff({
    required this.id,
    required this.salonId,
    required this.profileId,
    required this.type,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.profileName,
    this.note,
  });

  final String id;
  final String salonId;
  final String profileId;
  final TimeOffType type;
  final TimeOffStatus status;
  final DateTime startDate;
  final DateTime endDate;

  /// Nom du membre, issu de la jointure `profiles(full_name)`.
  final String? profileName;

  final String? note;

  int get dayCount => endDate.difference(startDate).inDays + 1;

  /// « 18–22 août » ou « 6 août » pour une journée.
  String get periodLabel {
    if (startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day) {
      return Formatters.dayMonth(startDate);
    }
    if (startDate.month == endDate.month) {
      return '${startDate.day}–${Formatters.dayMonth(endDate)}';
    }
    return '${Formatters.dayMonth(startDate)} – ${Formatters.dayMonth(endDate)}';
  }

  /// Absence en cours aujourd'hui.
  bool get isOngoing {
    final now = DateTime.now();
    return status == TimeOffStatus.approved &&
        !now.isBefore(startDate) &&
        !now.isAfter(endDate.add(const Duration(days: 1)));
  }

  factory TimeOff.fromMap(Map<String, dynamic> map) => TimeOff(
        id: map['id'] as String,
        salonId: map['salon_id'] as String,
        profileId: map['profile_id'] as String,
        type: TimeOffType.fromValue(map['type'] as String?),
        status: TimeOffStatus.fromValue(map['status'] as String?),
        startDate: DateTime.parse(map['start_date'] as String).toLocal(),
        endDate: DateTime.parse(map['end_date'] as String).toLocal(),
        profileName: map['profiles'] is Map<String, dynamic>
            ? (map['profiles'] as Map<String, dynamic>)['full_name'] as String?
            : null,
        note: map['note'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'salon_id': salonId,
        'profile_id': profileId,
        'type': type.value,
        'status': status.value,
        'start_date': startDate.toUtc().toIso8601String(),
        'end_date': endDate.toUtc().toIso8601String(),
        'note': note,
      };

  /// Effet du passage au statut [to] sur le solde de congés du membre.
  ///
  /// Négatif quand les jours sont retirés, positif quand ils sont rendus,
  /// nul quand le solde n'est pas concerné. Trois règles s'y cachent :
  ///
  ///  * seul le congé payé touche au solde — une absence maladie ou non payée
  ///    ne consomme pas des jours de vacances ;
  ///  * seule la bascule *vers* ou *depuis* « validé » compte, ce qui rend
  ///    l'opération idempotente : revalider une demande déjà validée ne
  ///    retire pas les jours une seconde fois ;
  ///  * revenir sur une validation rend les jours, sinon annuler une erreur
  ///    de saisie obligerait le gérant à corriger le solde à la main.
  int balanceDeltaFor(TimeOffStatus to) {
    if (type != TimeOffType.vacation) return 0;

    final wasApproved = status == TimeOffStatus.approved;
    final willBeApproved = to == TimeOffStatus.approved;
    if (wasApproved == willBeApproved) return 0;

    return willBeApproved ? -dayCount : dayCount;
  }

  /// Demande tranchée : elle appartient à l'historique, plus au flux courant.
  bool get isDecided => status != TimeOffStatus.pending;
}
