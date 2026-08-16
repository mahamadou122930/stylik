import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_typography.dart';
import 'app_atoms.dart';

/// Squelette d'écran de la maquette : fond `#F2F5EF`, en-tête compact,
/// corps défilant à 18 px de marge, et pied optionnel pour l'action primaire.
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.title,
    required this.child,
    this.topBar,
    this.subtitle,
    this.showBack = true,
    this.largeTitle = false,
    this.action,
    this.header,
    this.footer,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.scrollable = true,
    this.subtitleFirst = false,
    this.bodyPadding = const EdgeInsets.fromLTRB(
      AppSizes.screenPadding,
      0,
      AppSizes.screenPadding,
      20,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Remplace l'en-tête standard — écrans d'inscription, qui affichent une
  /// jauge d'étape à la place du titre.
  final Widget? topBar;

  final bool showBack;

  /// `true` pour le style « grand titre » (Sora 800 / 22) sans bouton retour.
  final bool largeTitle;

  /// Bouton d'action à droite du titre.
  final Widget? action;

  /// Bloc épinglé sous l'en-tête (onglets, recherche, filtres).
  final Widget? header;

  /// Pied d'écran épinglé (bouton principal).
  final Widget? footer;

  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool scrollable;

  /// Voir [AppTopBar.subtitleFirst].
  final bool subtitleFirst;

  final EdgeInsets bodyPadding;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: bodyPadding, child: child);

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            topBar ??
                AppTopBar(
                  title: title,
                  subtitle: subtitle,
                  showBack: showBack,
                  large: largeTitle,
                  action: action,
                  subtitleFirst: subtitleFirst,
                ),
            ?header,
            Expanded(
              child: scrollable
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: body,
                    )
                  : body,
            ),
            if (footer != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  12,
                  AppSizes.screenPadding,
                  MediaQuery.paddingOf(context).bottom + 22,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// En-tête d'écran : bouton retour carré, titre, action optionnelle.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = true,
    this.large = false,
    this.action,
    this.subtitleFirst = false,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final bool large;
  final Widget? action;

  /// Sous-titre posé au-dessus du titre — la date qui coiffe « Bonjour, Léa »
  /// sur l'accueil.
  final bool subtitleFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        large ? AppSizes.screenPadding : AppSizes.headerPadding,
        6,
        large ? AppSizes.screenPadding : AppSizes.headerPadding,
        12,
      ),
      child: Row(
        children: [
          if (showBack && Navigator.of(context).canPop()) ...[
            const AppIconButton(icon: Icons.arrow_back_ios_new_rounded),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subtitle != null && subtitleFirst)
                  Text(
                    subtitle!,
                    style: AppTypography.manrope(
                      13,
                      FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                Text(
                  title,
                  style: large
                      ? AppTypography.screenTitleLarge
                      : AppTypography.screenTitle,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && !subtitleFirst)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: AppTypography.rowSubtitle),
                  ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ),
    );
  }
}

/// En-tête d'un parcours en plusieurs étapes : retour, jauge de progression et
/// compteur « 1/2 » (écrans d'inscription de la maquette).
class AppStepHeader extends StatelessWidget {
  const AppStepHeader({
    super.key,
    required this.step,
    required this.stepCount,
  });

  /// Étape courante, à partir de 1.
  final int step;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        6,
        AppSizes.screenPadding,
        12,
      ),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            const AppIconButton(icon: Icons.arrow_back_ios_new_rounded),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: AppProgressBar(value: step / stepCount, height: 5),
          ),
          const SizedBox(width: 12),
          Text(
            '$step/$stepCount',
            style: AppTypography.sora(
              12.5,
              FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton carré 40×40 de l'en-tête (retour, filtre, options).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.filled = false,
    this.color,
    this.enabled = true,
  });

  final IconData icon;

  /// Sans action, le bouton fait un retour arrière — c'est le comportement
  /// voulu des flèches d'en-tête, qui s'écrivent sans `onTap`.
  final VoidCallback? onTap;

  /// `true` pour la variante pleine (fond accent, icône blanche).
  final bool filled;

  /// Teinte de l'icône, ou du fond en variante pleine.
  final Color? color;

  /// `false` grise le bouton et le rend inerte.
  ///
  /// Indispensable, car `onTap: null` ne désactive rien : le bouton retombe
  /// alors sur le retour arrière, et une flèche censée être indisponible
  /// quittait l'écran.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final background = filled
        ? (enabled ? (color ?? AppColors.accent) : AppColors.toggleOff)
        : AppColors.surface;
    final foreground = !enabled
        ? AppColors.textFaint
        : filled
            ? Colors.white
            : (color ?? AppColors.textPrimary);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: enabled ? (onTap ?? () => Navigator.maybePop(context)) : null,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Ink(
          width: AppSizes.iconButtonSize,
          height: AppSizes.iconButtonSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: filled ? null : Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: filled ? 20 : 18, color: foreground),
        ),
      ),
    );
  }
}

/// En-tête de section en capitales (« EN COURS », « ACTIVITÉ »…).
class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(this.label, {super.key, this.padding});

  final String label;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(2, 2, 2, 10),
      child: Text(label.toUpperCase(), style: AppTypography.sectionLabel),
    );
  }
}

/// Titre de bloc dans le corps de l'écran (« Horaires d'ouverture »).
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle(this.title, {super.key, this.trailing, this.padding});

  final String title;
  final Widget? trailing;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.sectionTitle)),
          ?trailing,
        ],
      ),
    );
  }
}
