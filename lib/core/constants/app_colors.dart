import 'package:flutter/material.dart';

/// Palette visuelle de L'Atelier, extraite de la maquette `Salon App.dc.html`.
///
/// Toute couleur utilisée dans l'application doit provenir de cette classe
/// (ou du [ColorScheme] dérivé dans `app_theme.dart`) — jamais de littéral
/// `Color(0x...)` posé dans un widget.
abstract final class AppColors {
  // --- Marque -------------------------------------------------------------
  /// Vert profond — titres de marque, onglets actifs, icônes.
  static const Color primary = Color(0xFF0C7A50);

  /// Vert clair — boutons d'action, interrupteurs actifs, accents.
  static const Color accent = Color(0xFF13A06B);

  /// Fond général des écrans.
  static const Color background = Color(0xFFF2F5EF);

  /// Fond des cartes et des listes.
  static const Color surface = Color(0xFFFFFFFF);

  /// Surface neutre secondaire (pastilles d'icônes désactivées).
  static const Color surfaceMuted = Color(0xFFF1F4EE);

  /// Fond des blocs de citation / encarts discrets.
  static const Color surfaceSubtle = Color(0xFFF7F9F4);

  /// Piste d'une barre de progression posée sur une carte blanche.
  static const Color trackNeutral = Color(0xFFEEF3EA);

  // --- Texte --------------------------------------------------------------
  /// Texte principal.
  static const Color textPrimary = Color(0xFF17231C);

  /// Texte courant, descriptions.
  static const Color textBody = Color(0xFF3C473F);

  /// Texte secondaire, sous-titres.
  static const Color textSecondary = Color(0xFF6C7870);

  /// Texte désactivé, en-têtes de section, chevrons.
  static const Color textFaint = Color(0xFF9AA69C);

  // --- Traits --------------------------------------------------------------
  static const Color border = Color(0xFFE6EBE1);

  /// Bordure appuyée — contour d'un choix non sélectionné (radio, carte).
  static const Color borderStrong = Color(0xFFD5DCCD);

  /// Trait pointillé — bloc « ajouter », séparateur de ticket.
  static const Color dashLine = Color(0xFFC4CEBB);

  /// Trait de la grille horaire de l'agenda.
  static const Color gridLine = Color(0xFFEEF1EA);

  /// Piste d'interrupteur à l'état inactif.
  static const Color toggleOff = Color(0xFFE1E8DC);

  // --- Teintes ------------------------------------------------------------
  /// Pastille verte (icônes, puces « Échanger »).
  static const Color tintGreen = Color(0xFFE2F3EA);

  /// Encart vert clair.
  static const Color tintGreenSoft = Color(0xFFF0FAF4);
  static const Color tintGreenBorder = Color(0xFFCDE4D8);

  /// Vert menthe sur fond sombre.
  static const Color mint = Color(0xFF7EE0B4);

  /// Ambre — attente, planifié, alertes douces.
  static const Color amber = Color(0xFFB97706);
  static const Color tintAmber = Color(0xFFFEF2DF);

  /// Ambre foncé — texte d'un encart d'alerte (stock bas).
  static const Color amberDeep = Color(0xFF9A6510);

  /// Bordure d'encart ambre.
  static const Color amberBorder = Color(0xFFF5E0B8);

  /// Violet — marketing, relances.
  static const Color violet = Color(0xFF7C3AED);
  static const Color tintViolet = Color(0xFFEEE1FA);

  /// Rouge — annulation, rupture de stock, dépenses.
  static const Color danger = Color(0xFFD1453B);
  static const Color tintDanger = Color(0xFFFDECEA);

  /// Rouge foncé — libellés d'alerte, remboursement, allergie.
  static const Color dangerDeep = Color(0xFFC0432C);

  /// Rouge très foncé — texte secondaire dans un encart d'alerte.
  static const Color dangerDarker = Color(0xFF9A4030);

  /// Bordure d'encart rouge.
  static const Color dangerBorder = Color(0xFFF6D5CD);

  /// Bleu — informations, paiements mobiles.
  static const Color info = Color(0xFF2F6FB2);
  static const Color tintInfo = Color(0xFFE7F0F9);

  /// Rouge des sorties d'argent (dépenses, remboursements).
  static const Color expense = Color(0xFFE4583E);
  static const Color tintExpense = Color(0xFFFCEBE7);

  /// Bleu profond des avatars et catégories secondaires.
  static const Color blue = Color(0xFF2A5FC0);
  static const Color tintBlue = Color(0xFFEAF1FD);

  /// Palette des graphiques (répartition du CA par catégorie).
  static const List<Color> chartSeries = [
    accent,
    Color(0xFF3B7BEA),
    Color(0xFFF4A526),
    borderStrong,
    violet,
    Color(0xFFE4583E),
  ];

  // --- Voiles sur fond sombre ---------------------------------------------
  /// Pastille blanche translucide (puce posée sur une carte sombre).
  static const Color overlayLight = Color(0x33FFFFFF);

  /// Cercle décoratif débordant d'une carte à dégradé.
  static const Color overlaySoft = Color(0x1FFFFFFF);

  // --- Sémantique ---------------------------------------------------------
  static const Color success = accent;
  static const Color warning = amber;
  static const Color onPrimary = Color(0xFFFFFFFF);

  // --- Dégradés -----------------------------------------------------------
  /// Cartes d'action (abonnement, promotion active).
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, primary],
  );

  /// Écran de bienvenue — `linear-gradient(165deg,#13A06B,#0C7A50 55%,#0A6544)`.
  static const LinearGradient welcomeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0, 0.55, 1],
    colors: [accent, primary, Color(0xFF0A6544)],
  );

  /// Cartes sombres (carte de fidélité, encaissement).
  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [textPrimary, Color(0xFF2C3B30)],
  );

  /// Ombre portée des cartes : `0 1px 2px rgba(20,30,20,.04)`.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A141E14),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];
}
