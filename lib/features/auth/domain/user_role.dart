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
  bool get canBookAppointments => can(RolePermission.bookAppointments);
  bool get canViewFinance => can(RolePermission.viewFinance);
  bool get canManageStaff => can(RolePermission.manageStaff);
  bool get canManageCatalog => can(RolePermission.managePricing);
  bool get canManageInventory => can(RolePermission.manageInventory);
  bool get canOperatePos => can(RolePermission.checkout);
  bool get canViewOwnCommission => can(RolePermission.viewOwnCommission);
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
  // La prise de rendez-vous est un acte de comptoir. Le coiffeur fait avancer
  // le sien (« terminé »), mais ne remplit pas le carnet.
  bookAppointments('Prendre un rendez-vous', {
    UserRole.gerant,
    UserRole.receptionniste,
  }),
  // Le coiffeur réalise la prestation, la réception encaisse : lui laisser la
  // caisse reviendrait à lui ouvrir le détail financier des tickets du salon.
  checkout('Encaisser', {
    UserRole.gerant,
    UserRole.receptionniste,
  }),
  viewClients('Voir les fiches clients', {
    UserRole.gerant,
    UserRole.coiffeur,
    UserRole.receptionniste,
  }),
  // Chacun voit ses propres commissions — c'est sa rémunération. Voir celles
  // du salon entier relève de `viewFinance`, réservée au gérant.
  viewOwnCommission('Voir ses commissions', {
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
  // Le catalogue fixe les prix du salon : la réception en a besoin au
  // quotidien, le coiffeur le consulte sans pouvoir le modifier.
  managePricing('Modifier les tarifs', {
    UserRole.gerant,
    UserRole.receptionniste,
  });

  const RolePermission(this.label, this.defaultRoles);

  final String label;

  /// Rôles auxquels la permission est accordée par défaut.
  final Set<UserRole> defaultRoles;

  bool isGrantedTo(UserRole role) =>
      role == UserRole.gerant || defaultRoles.contains(role);
}
