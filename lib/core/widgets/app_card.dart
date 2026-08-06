import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_typography.dart';

/// Carte blanche : bordure `#E6EBE1`, rayon 16, ombre douce.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.borderColor,
    this.radius = AppSizes.radiusLg,
    this.shadow = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: shadow ? AppColors.cardShadow : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: content,
      ),
    );
  }
}

/// Carte-liste : les enfants sont séparés par un filet 1 px, avec le padding
/// horizontal de 14 px de la maquette.
class AppListCard extends StatelessWidget {
  const AppListCard({super.key, required this.children, this.color});

  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(const Divider(height: 1, color: AppColors.border));
      }
    }

    return AppCard(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

/// Ligne de [AppListCard] : libellé, sous-titre et valeur/contrôle à droite.
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.label,
    this.subtitle,
    this.value,
    this.trailing,
    this.leading,
    this.onTap,
    this.muted = false,
    this.strong = false,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
  });

  final String label;
  final String? subtitle;

  /// Valeur affichée à droite (Sora 650 / 13.5).
  final String? value;

  /// Contrôle à droite (interrupteur, chevron, puce).
  final Widget? trailing;

  final Widget? leading;
  final VoidCallback? onTap;

  /// Ligne grisée (option indisponible / jour fermé).
  final bool muted;

  /// Libellé en Manrope 700 plutôt que 650.
  final bool strong;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final labelColor = muted ? AppColors.textFaint : AppColors.textPrimary;

    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: (strong
                          ? AppTypography.rowTitleStrong
                          : AppTypography.rowTitle)
                      .copyWith(color: labelColor),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle!, style: AppTypography.rowSubtitle),
                ],
              ],
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: AppTypography.rowValue.copyWith(color: labelColor),
            ),
          if (trailing != null) ...[
            if (value != null) const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// Carte à dégradé (abonnement, promotion active, carte de fidélité).
class AppGradientCard extends StatelessWidget {
  const AppGradientCard({
    super.key,
    required this.child,
    this.gradient = AppColors.brandGradient,
    this.padding = const EdgeInsets.all(20),
    this.bubbleAlignment = Alignment.topRight,
    this.bubbleColor = AppColors.overlaySoft,
    this.bubbleSize = 96,
    this.onTap,
  });

  final Widget child;
  final Gradient gradient;
  final EdgeInsets padding;

  /// Cercle décoratif débordant du coin, comme dans la maquette.
  final Alignment bubbleAlignment;
  final Color bubbleColor;
  final double bubbleSize;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.radiusXl);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(gradient: gradient, borderRadius: radius),
          child: Stack(
            children: [
              Positioned(
                right: bubbleAlignment.x > 0 ? -16 : null,
                left: bubbleAlignment.x < 0 ? -16 : null,
                top: bubbleAlignment.y < 0 ? -16 : null,
                bottom: bubbleAlignment.y > 0 ? -16 : null,
                child: Container(
                  width: bubbleSize,
                  height: bubbleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bubbleColor,
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tuile de statistique (« Envoyés (mois) · 312 »).
class AppStatTile extends StatelessWidget {
  const AppStatTile({
    super.key,
    required this.label,
    required this.value,
    this.tinted = false,
    this.valueColor,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;

  /// Variante vert clair (`#F0FAF4` / bordure `#CDE4D8`).
  final bool tinted;
  final Color? valueColor;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = valueColor ?? (tinted ? AppColors.primary : AppColors.textPrimary);

    return AppCard(
      onTap: onTap,
      radius: 15,
      shadow: !tinted,
      color: tinted ? AppColors.tintGreenSoft : null,
      borderColor: tinted ? AppColors.tintGreenBorder : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.statLabel.copyWith(
              color: tinted ? AppColors.primary : AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTypography.amountMedium.copyWith(color: accentColor),
            maxLines: 1,
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: AppTypography.rowSubtitle),
          ],
        ],
      ),
    );
  }
}

/// Encart d'information vert clair avec icône.
class AppCallout extends StatelessWidget {
  const AppCallout({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color = AppColors.primary,
    this.background = AppColors.tintGreenSoft,
    this.borderColor = AppColors.tintGreenBorder,
  });

  final String message;
  final IconData icon;
  final Color color;
  final Color background;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: background,
      borderColor: borderColor,
      radius: 14,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.manrope(
                12.5,
                FontWeight.w500,
                color: AppColors.textBody,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloc de citation (aperçu d'un message SMS/WhatsApp).
class AppQuoteBlock extends StatelessWidget {
  const AppQuoteBlock(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(
        text,
        style: AppTypography.manrope(
          12.5,
          FontWeight.w500,
          color: AppColors.textBody,
          height: 1.5,
        ),
      ),
    );
  }
}
