import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typographies de L'Atelier, calées sur la maquette.
///
/// - **Sora** : titres, chiffres, montants, libellés de boutons (600→800,
///   interlettrage négatif sur les grandes tailles).
/// - **Manrope** : corps de texte, libellés de listes, descriptions (500→700).
///
/// Les deux familles sont des polices *variables* embarquées dans
/// `assets/fonts/` : la graisse est portée à la fois par `fontWeight` (pour la
/// mise en page et les polices de secours) et par l'axe `wght` via
/// [FontVariation], seul moyen d'obtenir le rendu exact hors connexion.
abstract final class AppTypography {
  static TextStyle _styled(
    String family,
    double size,
    FontWeight weight,
    Color color,
    double? letterSpacing,
    double? height,
    double? wght,
  ) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation.weight(wght ?? weight.value.toDouble())],
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// [wght] force la valeur exacte de l'axe de graisse — utile pour les
  /// `font-weight: 650` de la maquette, que [FontWeight] ne sait pas exprimer.
  static TextStyle sora(
    double size,
    FontWeight weight, {
    Color color = AppColors.textPrimary,
    double? letterSpacing,
    double? height,
    double? wght,
  }) =>
      _styled('Sora', size, weight, color, letterSpacing, height, wght);

  static TextStyle manrope(
    double size,
    FontWeight weight, {
    Color color = AppColors.textPrimary,
    double? letterSpacing,
    double? height,
    double? wght,
  }) =>
      _styled('Manrope', size, weight, color, letterSpacing, height, wght);

  // --- Styles nommés de la maquette ---------------------------------------

  /// Titre d'écran avec bouton retour — Sora 700 / 18 / -0.4.
  static TextStyle get screenTitle =>
      sora(18, FontWeight.w700, letterSpacing: -0.4);

  /// Grand titre d'écran (sans retour) — Sora 800 / 22 / -0.5.
  static TextStyle get screenTitleLarge =>
      sora(22, FontWeight.w800, letterSpacing: -0.5);

  /// Titre de bloc dans le corps — Sora 700 / 15.
  static TextStyle get sectionTitle => sora(15, FontWeight.w700);

  /// En-tête de section en capitales — Sora 700 / 13 / +0.3.
  static TextStyle get sectionLabel => sora(
        13,
        FontWeight.w700,
        color: AppColors.textFaint,
        letterSpacing: 0.3,
      );

  /// Ligne de liste — Manrope 650 / 14.
  static TextStyle get rowTitle => manrope(14, FontWeight.w600, wght: 650);

  /// Ligne de liste mise en avant — Manrope 700 / 14.
  static TextStyle get rowTitleStrong => manrope(14, FontWeight.w700);

  /// Sous-titre de ligne — Manrope 500 / 11.5.
  static TextStyle get rowSubtitle =>
      manrope(11.5, FontWeight.w500, color: AppColors.textSecondary);

  /// Valeur alignée à droite dans une ligne — Sora 650 / 13.5.
  static TextStyle get rowValue => sora(13.5, FontWeight.w600, wght: 650);

  /// Corps de texte — Manrope 500 / 13.5 / 1.5.
  static TextStyle get body =>
      manrope(13.5, FontWeight.w500, color: AppColors.textBody, height: 1.45);

  /// Libellé de bouton principal — Sora 700 / 16.
  static TextStyle get button => sora(16, FontWeight.w700);

  /// Puce de statut — Manrope 700 / 11.
  static TextStyle get badge => manrope(11, FontWeight.w700);

  /// Grand montant — Sora 800 / 28 / -0.5.
  static TextStyle get amountLarge =>
      sora(28, FontWeight.w800, letterSpacing: -0.5);

  /// Montant de tuile statistique — Sora 800 / 20.
  static TextStyle get amountMedium => sora(20, FontWeight.w800);

  /// Légende de tuile statistique — Manrope 600 / 11.
  static TextStyle get statLabel =>
      manrope(11, FontWeight.w600, color: AppColors.textSecondary);

  /// TextTheme injecté dans [ThemeData].
  static TextTheme get textTheme => TextTheme(
        displayLarge: sora(44, FontWeight.w800, letterSpacing: -1),
        displayMedium: sora(36, FontWeight.w800, letterSpacing: -1),
        displaySmall: sora(28, FontWeight.w800, letterSpacing: -0.5),
        headlineLarge: sora(24, FontWeight.w800, letterSpacing: -0.5),
        headlineMedium: sora(22, FontWeight.w800, letterSpacing: -0.5),
        headlineSmall: sora(19, FontWeight.w800, letterSpacing: -0.5),
        titleLarge: sora(18, FontWeight.w700, letterSpacing: -0.4),
        titleMedium: sora(15, FontWeight.w700),
        titleSmall: sora(14, FontWeight.w700),
        bodyLarge: manrope(14, FontWeight.w600),
        bodyMedium: manrope(13.5, FontWeight.w500, color: AppColors.textBody),
        bodySmall: manrope(11.5, FontWeight.w500, color: AppColors.textSecondary),
        labelLarge: sora(16, FontWeight.w700),
        labelMedium: manrope(13, FontWeight.w600),
        labelSmall: manrope(11, FontWeight.w700),
      );
}
