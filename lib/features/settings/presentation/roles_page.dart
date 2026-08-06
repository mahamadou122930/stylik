import 'package:flutter/material.dart';

import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user_role.dart';

/// 10.2 — Rôles & permissions : ce que chaque rôle peut faire.
class RolesPage extends StatefulWidget {
  const RolesPage({super.key});

  static const routeName = '/settings/roles';

  @override
  State<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends State<RolesPage> {
  /// Seuls les rôles restreignables sont éditables ; le gérant a tout.
  static const List<UserRole> _editableRoles = [
    UserRole.coiffeur,
    UserRole.receptionniste,
  ];

  int _index = 0;

  /// Surcharges locales des permissions par rôle, avant persistance.
  final Map<UserRole, Map<RolePermission, bool>> _overrides = {};

  UserRole get _role => _editableRoles[_index];

  bool _isGranted(RolePermission permission) =>
      _overrides[_role]?[permission] ?? permission.isGrantedTo(_role);

  void _toggle(RolePermission permission, bool value) {
    setState(() {
      _overrides.putIfAbsent(_role, () => {})[permission] = value;
    });
    // TODO(settings): persister la matrice de permissions du salon.
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Rôles & permissions',
      header: AppSegmented(
        items: [for (final role in _editableRoles) role.label],
        selectedIndex: _index,
        onChanged: (value) => setState(() => _index = value),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 12),
            child: Text.rich(
              TextSpan(
                text: 'Permissions du rôle ',
                style: AppTypography.rowSubtitle.copyWith(fontSize: 12.5),
                children: [
                  TextSpan(
                    text: _role.label,
                    style: AppTypography.manrope(12.5, FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          AppListCard(
            children: [
              for (final permission in RolePermission.values)
                AppListRow(
                  label: permission.label,
                  muted: !_isGranted(permission),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  trailing: AppToggle(
                    value: _isGranted(permission),
                    onChanged: (value) => _toggle(permission, value),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const AppCallout(
            icon: Icons.star_border_rounded,
            message:
                'Le gérant a tous les accès et ne peut pas être restreint.',
          ),
        ],
      ),
    );
  }
}
