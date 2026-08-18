import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/features/staff/domain/staff_schedule.dart';

/// Décompte du solde de congés à la validation. C'est de la paie : retirer
/// deux fois les mêmes jours, ou ne pas les rendre après une annulation,
/// se voit directement sur ce que le salon doit à l'employé.
void main() {
  TimeOff request({
    required TimeOffType type,
    required TimeOffStatus status,
    int days = 5,
  }) => TimeOff(
    id: 'r1',
    salonId: 'salon',
    profileId: 'moi',
    type: type,
    status: status,
    startDate: DateTime(2026, 8, 18),
    // Bornes incluses : 18 + 4 = 22 août, soit cinq jours.
    endDate: DateTime(2026, 8, 18).add(Duration(days: days - 1)),
  );

  test('valider un congé retire ses jours', () {
    final pending = request(
      type: TimeOffType.vacation,
      status: TimeOffStatus.pending,
    );

    expect(pending.dayCount, 5);
    expect(pending.balanceDeltaFor(TimeOffStatus.approved), -5);
  });

  test('revalider une demande déjà validée ne retire rien de plus', () {
    final approved = request(
      type: TimeOffType.vacation,
      status: TimeOffStatus.approved,
    );

    // Idempotence : sans ça, deux appuis sur « Valider » coûtent dix jours.
    expect(approved.balanceDeltaFor(TimeOffStatus.approved), 0);
  });

  test('revenir sur une validation rend les jours', () {
    final approved = request(
      type: TimeOffType.vacation,
      status: TimeOffStatus.approved,
    );

    expect(approved.balanceDeltaFor(TimeOffStatus.rejected), 5);
    expect(approved.balanceDeltaFor(TimeOffStatus.pending), 5);
  });

  test('refuser une demande en attente ne touche pas au solde', () {
    final pending = request(
      type: TimeOffType.vacation,
      status: TimeOffStatus.pending,
    );

    // Les jours n'avaient jamais été retirés : rien à rendre.
    expect(pending.balanceDeltaFor(TimeOffStatus.rejected), 0);
    expect(pending.balanceDeltaFor(TimeOffStatus.pending), 0);
  });

  test('maladie et absence non payée ne consomment pas de congés', () {
    for (final type in [TimeOffType.sickLeave, TimeOffType.unpaid]) {
      for (final from in TimeOffStatus.values) {
        for (final to in TimeOffStatus.values) {
          expect(
            request(type: type, status: from).balanceDeltaFor(to),
            0,
            reason: '${type.value} : $from → $to',
          );
        }
      }
    }
  });

  test('une journée seule vaut un jour, pas zéro', () {
    final single = request(
      type: TimeOffType.vacation,
      status: TimeOffStatus.pending,
      days: 1,
    );

    expect(single.dayCount, 1);
    expect(single.balanceDeltaFor(TimeOffStatus.approved), -1);
  });

  test('aller-retour validation puis annulation laisse le solde intact', () {
    const days = 5;
    final pending = request(
      type: TimeOffType.vacation,
      status: TimeOffStatus.pending,
      days: days,
    );
    final approved = request(
      type: TimeOffType.vacation,
      status: TimeOffStatus.approved,
      days: days,
    );

    final net =
        pending.balanceDeltaFor(TimeOffStatus.approved) +
        approved.balanceDeltaFor(TimeOffStatus.rejected);

    expect(net, 0);
  });

  test('seules les demandes tranchées entrent dans l\'historique', () {
    expect(
      request(
        type: TimeOffType.vacation,
        status: TimeOffStatus.pending,
      ).isDecided,
      isFalse,
    );
    expect(
      request(
        type: TimeOffType.vacation,
        status: TimeOffStatus.approved,
      ).isDecided,
      isTrue,
    );
    expect(
      request(
        type: TimeOffType.vacation,
        status: TimeOffStatus.rejected,
      ).isDecided,
      isTrue,
    );
  });
}
