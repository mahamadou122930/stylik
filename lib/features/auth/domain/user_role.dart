/// Rôles du personnel du salon (colonne `profiles.role`).
enum UserRole {
  gerant('gerant', 'Gérant'),
  coiffeur('coiffeur', 'Coiffeur'),
  receptionniste('receptionniste', 'Réceptionniste');

  const UserRole(this.value, this.label);

  /// Valeur stockée en base.
  final String value;

  /// Libellé affiché dans l'interface.
  final String label;

  static UserRole fromValue(String? value) => UserRole.values.firstWhere(
        (role) => role.value == value,
        orElse: () => UserRole.coiffeur,
      );

  bool can(RolePermission permission) => permission.isGrantedTo(this);

  // --- Raccourcis de permissions utilisés dans la navigation --------------
  bool get canViewFullAgenda => can(RolePermission.viewFullAgenda);
  bool get canViewFinance => can(RolePermission.viewFinance);
  bool get canManageStaff => can(RolePermission.manageStaff);
  bool get canManageCatalog => can(RolePermission.managePricing);
  bool get canManageInventory => can(RolePermission.manageInventory);
  bool get canOperatePos => can(RolePermission.checkout);
  bool get canVoidTransaction => this == gerant;
  bool get canManageSettings => this == gerant;
}

/// Matrice de permissions présentée dans l'écran « Rôles & permissions ».
enum RolePermission {
  viewOwnAgenda('Voir son planning', {
    UserRole.gerant,
    UserRole.coiffeur,
    UserRole.receptionniste,
  }),
  viewFullAgenda('Voir le planning du salon', {
    UserRole.gerant,
    UserRole.receptionniste,
  }),
  checkout('Encaisser', {
    UserRole.gerant,
    UserRole.coiffeur,
    UserRole.receptionniste,
  }),
  viewClients('Voir les fiches clients', {
    UserRole.gerant,
    UserRole.coiffeur,
    UserRole.receptionniste,
  }),
  manageInventory('Gérer le stock', {
    UserRole.gerant,
    UserRole.receptionniste,
  }),
  viewFinance('Voir la finance', {UserRole.gerant}),
  manageStaff('Gérer le personnel', {UserRole.gerant}),
  managePricing('Modifier les tarifs', {UserRole.gerant});

  const RolePermission(this.label, this.defaultRoles);

  final String label;

  /// Rôles auxquels la permission est accordée par défaut.
  final Set<UserRole> defaultRoles;

  bool isGrantedTo(UserRole role) =>
      role == UserRole.gerant || defaultRoles.contains(role);
}
