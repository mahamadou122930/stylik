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
  static final DateFormat _month = DateFormat('MMMM', locale);
  static final DateFormat _dayMonthYear = DateFormat('d MMMM y', locale);

  /// Forme comparable d'un texte : minuscules, sans accents ni cédille.
  ///
  /// Une fiche saisie « Shampooing Kérastase » doit se retrouver en tapant
  /// « kerastase », et inversement — sur un clavier de téléphone, personne ne
  /// met les accents pour chercher.
  static String searchable(String value) {
    final lower = value.toLowerCase();
    final buffer = StringBuffer();

    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_diacritics[char] ?? char);
    }
    return buffer.toString();
  }

  static const Map<String, String> _diacritics = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n', 'ÿ': 'y',
  };

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

  /// `2026-08-13` → `"août"` — période de paie affichée au coiffeur.
  static String monthName(DateTime date) => _month.format(date.toLocal());

  /// `2026-08-04` → `"4 août 2026"` — date d'émission d'une facture, où
  /// l'année doit figurer.
  static String dayMonthYear(DateTime date) =>
      _dayMonthYear.format(date.toLocal());

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
