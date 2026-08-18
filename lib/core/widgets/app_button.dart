import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_typography.dart';

enum AppButtonVariant {
  /// Action principale — fond `#13A06B`, texte blanc.
  primary,

  /// Action de marque — fond `#0C7A50`.
  brand,

  /// Action sombre — fond `#17231C`.
  dark,

  /// Action secondaire — fond blanc, bordure `#E6EBE1`.
  outline,

  /// Action destructrice — texte rouge sur fond blanc.
  danger,

  /// Action destructrice pleine — fond rouge, texte blanc (remboursement).
  dangerSolid,

  /// Action principale posée sur un fond de marque — fond blanc, texte vert.
  light,

  /// Action secondaire posée sur un fond de marque — bordure blanche translucide.
  outlineLight,

  /// Action textuelle.
  ghost,
}

/// Bouton de la maquette : hauteur 54, rayon 16, Sora 700 / 16.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
    this.height = AppSizes.ctaHeight,
    this.trailingLabel,
  });

  const AppButton.outline({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
    this.height = AppSizes.ctaHeight,
    this.trailingLabel,
  }) : variant = AppButtonVariant.outline;

  const AppButton.dark({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
    this.height = AppSizes.ctaHeight,
    this.trailingLabel,
  }) : variant = AppButtonVariant.dark;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;
  final double height;

  /// Montant aligné à droite dans le bouton (« Choisir le paiement · 59 400 F »).
  final String? trailingLabel;

  Color get _background => switch (variant) {
    AppButtonVariant.primary => AppColors.accent,
    AppButtonVariant.brand => AppColors.primary,
    AppButtonVariant.dark => AppColors.textPrimary,
    AppButtonVariant.dangerSolid => AppColors.expense,
    AppButtonVariant.outline ||
    AppButtonVariant.danger ||
    AppButtonVariant.light => AppColors.surface,
    AppButtonVariant.outlineLight ||
    AppButtonVariant.ghost => Colors.transparent,
  };

  Color get _foreground => switch (variant) {
    AppButtonVariant.primary ||
    AppButtonVariant.brand ||
    AppButtonVariant.dark ||
    AppButtonVariant.dangerSolid ||
    AppButtonVariant.outlineLight => Colors.white,
    AppButtonVariant.outline => AppColors.textPrimary,
    AppButtonVariant.danger => AppColors.danger,
    AppButtonVariant.light || AppButtonVariant.ghost => AppColors.primary,
  };

  BoxBorder? get _border => switch (variant) {
    AppButtonVariant.outline => Border.all(color: AppColors.border),
    AppButtonVariant.danger => Border.all(color: AppColors.border),
    AppButtonVariant.outlineLight => Border.all(
      color: Colors.white.withValues(alpha: 0.5),
      width: 1.5,
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final radius = BorderRadius.circular(AppSizes.radiusLg);

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: _foreground,
            ),
          )
        : Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: trailingLabel == null
                ? MainAxisAlignment.center
                : MainAxisAlignment.spaceBetween,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19, color: _foreground),
                const SizedBox(width: 9),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.button.copyWith(
                    color: enabled ? _foreground : AppColors.textFaint,
                  ),
                ),
              ),
              if (trailingLabel != null) ...[
                const SizedBox(width: 12),
                // Le montant se réduit plutôt que de déborder : sur un
                // écran étroit, « Payer » partageant sa ligne avec un autre
                // bouton n'a plus la place d'afficher 59 400 F en pleine
                // taille.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      trailingLabel!,
                      maxLines: 1,
                      style: AppTypography.sora(
                        19,
                        FontWeight.w800,
                        color: enabled ? _foreground : AppColors.textFaint,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );

    final button = Material(
      color: enabled ? _background : AppColors.toggleOff,
      borderRadius: radius,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: radius,
        child: Ink(
          height: height,
          decoration: BoxDecoration(borderRadius: radius, border: _border),
          padding: EdgeInsets.symmetric(
            horizontal: trailingLabel == null ? 18 : 22,
          ),
          child: Center(child: child),
        ),
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Petit bouton-pilule des lignes de liste (« Échanger », « Modifier »).
class AppPillButton extends StatelessWidget {
  const AppPillButton({
    super.key,
    required this.label,
    this.onTap,
    this.color = AppColors.primary,
    this.background = AppColors.tintGreen,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: AppTypography.sora(12.5, FontWeight.w700, color: color),
          ),
        ),
      ),
    );
  }
}
