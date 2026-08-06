import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';

/// Préférence de notification affichée dans l'écran 10.3.
enum NotificationPreference {
  newAppointment(
    'Activité',
    'Nouveau rendez-vous',
    subtitle: 'Réservation en ligne',
  ),
  cancellation('Activité', 'Annulation / no-show'),
  leaveRequest('Activité', 'Demande de congé'),
  lowStock('Stock & finance', 'Alerte stock bas'),
  dailyReport(
    'Stock & finance',
    'Bilan quotidien',
    subtitle: 'Chaque soir à 20:00',
  ),
  weeklyReport('Stock & finance', 'Résumé hebdomadaire', enabled: false),
  push('Canaux', 'Push (application)'),
  email('Canaux', 'Email', enabled: false);

  const NotificationPreference(
    this.section,
    this.label, {
    this.subtitle,
    this.enabled = true,
  });

  final String section;
  final String label;
  final String? subtitle;

  /// Valeur par défaut à l'installation.
  final bool enabled;

  static const List<String> sections = [
    'Activité',
    'Stock & finance',
    'Canaux',
  ];
}

/// 10.3 — Notifications : ce que l'application signale, et par quel canal.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  static const routeName = '/settings/notifications';

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final Map<NotificationPreference, bool> _values = {
    for (final preference in NotificationPreference.values)
      preference: preference.enabled,
  };

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Notifications',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in NotificationPreference.sections) ...[
            AppSectionLabel(
              section,
              padding: EdgeInsets.fromLTRB(
                2,
                section == NotificationPreference.sections.first ? 2 : 18,
                2,
                10,
              ),
            ),
            AppListCard(
              children: [
                for (final preference in NotificationPreference.values
                    .where((item) => item.section == section))
                  AppListRow(
                    label: preference.label,
                    subtitle: preference.subtitle,
                    strong: preference.subtitle != null,
                    muted: !_values[preference]!,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    trailing: AppToggle(
                      value: _values[preference]!,
                      onChanged: (value) {
                        setState(() => _values[preference] = value);
                        // TODO(settings): enregistrer les préférences côté
                        // profil (colonne `notification_settings`).
                      },
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
