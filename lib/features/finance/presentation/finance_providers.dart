import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/finance_repository.dart';
import '../domain/finance_summary.dart';

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(ref.watch(supabaseClientProvider)),
);

/// Périodes de l'écran Chiffre d'affaires (jour / semaine / mois).
enum FinancePeriod {
  day('Jour', 1, 6),
  week('Semaine', 7, 7),
  month('Mois', 30, 4);

  const FinancePeriod(this.label, this.days, this.bucketCount);

  final String label;
  final int days;

  /// Nombre de colonnes de l'histogramme.
  final int bucketCount;

  ({DateTime from, DateTime to}) get range {
    final now = DateTime.now();
    final endOfDay =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return (from: endOfDay.subtract(Duration(days: days)), to: endOfDay);
  }
}

final financePeriodProvider =
    StateProvider<FinancePeriod>((ref) => FinancePeriod.month);

/// Synthèse du chiffre d'affaires sur la période sélectionnée.
final financeSummaryProvider = FutureProvider<FinanceSummary>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  final period = ref.watch(financePeriodProvider);
  final range = period.range;

  if (salonId == null) {
    return FinanceSummary.empty(from: range.from, to: range.to);
  }

  return ref.watch(financeRepositoryProvider).fetchSummary(
        salonId: salonId,
        from: range.from,
        to: range.to,
        bucketCount: period.bucketCount,
      );
});

/// Rapport par coiffeur sur la période sélectionnée.
final commissionsProvider =
    FutureProvider<List<StylistCommission>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  final range = ref.watch(financePeriodProvider).range;
  return ref.watch(financeRepositoryProvider).fetchCommissions(
        salonId: salonId,
        from: range.from,
        to: range.to,
      );
});

/// Rapport par service sur la période sélectionnée.
final servicePerformanceProvider =
    FutureProvider<List<ServicePerformance>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  final range = ref.watch(financePeriodProvider).range;
  return ref.watch(financeRepositoryProvider).fetchServicePerformance(
        salonId: salonId,
        from: range.from,
        to: range.to,
      );
});

/// Dépenses de la période sélectionnée.
final expensesProvider = FutureProvider<List<Expense>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  final range = ref.watch(financePeriodProvider).range;
  return ref.watch(financeRepositoryProvider).fetchExpenses(
        salonId: salonId,
        from: range.from,
        to: range.to,
      );
});

/// Total des charges de la période.
final expensesTotalProvider = Provider<int>((ref) {
  final expenses = ref.watch(expensesProvider).valueOrNull ?? const [];
  return expenses.fold(0, (sum, expense) => sum + expense.amountFcfa);
});

/// Résultat net (CA encaissé − charges) de la période.
final netResultProvider = Provider<int>((ref) {
  final revenue = ref.watch(financeSummaryProvider).valueOrNull?.revenueFcfa ?? 0;
  return revenue - ref.watch(expensesTotalProvider);
});

// --- Export comptable -----------------------------------------------------

enum ExportPeriod {
  month('Mois', 30),
  quarter('Trimestre', 92),
  year('Année', 365);

  const ExportPeriod(this.label, this.days);

  final String label;
  final int days;

  ({DateTime from, DateTime to}) get range {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    return (from: end.subtract(Duration(days: days)), to: end);
  }
}

enum ExportFormat {
  xlsx('xlsx', 'Fichier Excel (.xlsx)', 'Détail ligne par ligne'),
  pdf('pdf', 'Document PDF', 'Synthèse pour le comptable');

  const ExportFormat(this.value, this.label, this.description);

  final String value;
  final String label;
  final String description;
}

final exportPeriodProvider =
    StateProvider<ExportPeriod>((ref) => ExportPeriod.quarter);

final exportFormatProvider =
    StateProvider<ExportFormat>((ref) => ExportFormat.xlsx);

/// Synthèse recettes / charges de la période d'export.
final exportSummaryProvider =
    FutureProvider<({int revenue, int expenses})>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  final range = ref.watch(exportPeriodProvider).range;
  if (salonId == null) return (revenue: 0, expenses: 0);

  final repository = ref.watch(financeRepositoryProvider);
  final summary = await repository.fetchSummary(
    salonId: salonId,
    from: range.from,
    to: range.to,
  );
  final expenses = await repository.fetchExpenses(
    salonId: salonId,
    from: range.from,
    to: range.to,
  );

  return (
    revenue: summary.revenueFcfa,
    expenses: expenses.fold<int>(0, (sum, e) => sum + e.amountFcfa),
  );
});
