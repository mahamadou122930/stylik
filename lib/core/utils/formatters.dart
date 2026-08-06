import 'package:intl/intl.dart';

/// Formatage des montants et des dates (locale fr).
abstract final class Formatters {
  static const String locale = 'fr_FR';

  static final NumberFormat _amount = NumberFormat.decimalPattern(locale);
  static final DateFormat _time = DateFormat('HH:mm', locale);
  static final DateFormat _day = DateFormat('EEEE d MMMM', locale);
  static final DateFormat _dayShort = DateFormat('dd/MM/yyyy', locale);
  static final DateFormat _dayTime = DateFormat('dd/MM/yyyy HH:mm', locale);
  static final DateFormat _dayMonth = DateFormat('d MMM', locale);
  static final DateFormat _weekdayDayMonth = DateFormat('EEE d MMM', locale);
  static final DateFormat _weekdayShort = DateFormat('E', locale);

  /// `12500` → `"12 500 F"` — notation courte utilisée dans la maquette.
  static String fcfa(num value) => '${_amount.format(value)} F';

  /// Alias explicite de [fcfa], pour les contextes où la brièveté compte.
  static String fcfaShort(num value) => fcfa(value);

  /// `12500` → `"12 500 FCFA"` (tickets, exports, documents).
  static String fcfaFull(num value) => '${_amount.format(value)} FCFA';

  /// `12500` → `"12 500"` (sans devise).
  static String amount(num value) => _amount.format(value);

  static String time(DateTime date) => _time.format(date.toLocal());

  static String day(DateTime date) => _day.format(date.toLocal());

  /// `2026-08-04` → `"lun"` — bandeau de semaine du planning individuel.
  static String weekdayShort(DateTime date) =>
      _weekdayShort.format(date.toLocal()).replaceAll('.', '');

  static String dayShort(DateTime date) => _dayShort.format(date.toLocal());

  /// `2026-09-01` → `"1 sept."` — format compact des cartes.
  static String dayMonth(DateTime date) => _dayMonth.format(date.toLocal());

  /// `2026-09-01` → `"lun. 1 sept."`.
  static String weekdayDayMonth(DateTime date) =>
      _weekdayDayMonth.format(date.toLocal());

  static String dayTime(DateTime date) => _dayTime.format(date.toLocal());

  /// `95` → `"1h35"`, `45` → `"45 min"`.
  static String duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
  }

  /// Initiales d'un nom complet (`"Awa Diallo"` → `"AD"`).
  static String initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
