import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_typography.dart';

/// Pastille d'icône arrondie (40×40, fond teinté) omniprésente dans la maquette.
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.background = AppColors.tintGreen,
    this.size = AppSizes.iconTileSize,
    this.radius = AppSizes.radiusMd,
  });

  /// Variante neutre (fond gris, icône sombre).
  const AppIconTile.neutral({
    super.key,
    required this.icon,
    this.size = AppSizes.iconTileSize,
    this.radius = AppSizes.radiusMd,
  })  : color = AppColors.textBody,
        background = AppColors.surfaceMuted;

  final IconData icon;
  final Color color;
  final Color background;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Puce de statut arrondie (« Active », « À venir », « Palier Or »).
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.color = AppColors.primary,
    this.background,
    this.dense = false,
  });

  /// Puce sur fond sombre / coloré (texte blanc translucide).
  const AppBadge.onDark({super.key, required this.label, this.dense = false})
      : color = Colors.white,
        background = AppColors.overlayLight;

  final String label;
  final Color color;
  final Color? background;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 11,
        vertical: dense ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Text(
        label,
        style: AppTypography.badge.copyWith(color: color),
      ),
    );
  }
}

/// Petit label carré (numéro d'étape, code, quantité).
class AppTag extends StatelessWidget {
  const AppTag({
    super.key,
    required this.label,
    this.color = AppColors.primary,
    this.background = AppColors.tintGreen,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(
        label,
        style: AppTypography.sora(12, FontWeight.w800, color: color),
      ),
    );
  }
}

/// Interrupteur 44×26 dessiné comme dans la maquette.
class AppToggle extends StatelessWidget {
  const AppToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.width = AppSizes.toggleWidth,
    this.activeColor = AppColors.accent,
    this.inactiveColor = AppColors.toggleOff,
    this.thumbColor = Colors.white,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;
  final Color activeColor;
  final Color inactiveColor;
  final Color thumbColor;

  @override
  Widget build(BuildContext context) {
    const height = AppSizes.toggleHeight;
    final thumb = height - 6;

    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: value ? activeColor : inactiveColor,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              width: thumb,
              height: thumb,
              decoration: BoxDecoration(
                color: thumbColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Onglets segmentés pleine largeur (« Coiffeur / Réceptionniste »).
class AppSegmented extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.boxed = false,
    this.padding = const EdgeInsets.fromLTRB(
      AppSizes.screenPadding,
      0,
      AppSizes.screenPadding,
      14,
    ),
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Variante « boîte » : les onglets sont posés dans un conteneur blanc
  /// (écrans Chiffre d'affaires et Export comptable).
  final bool boxed;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (boxed) {
      return Padding(
        padding: padding,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(i),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == selectedIndex
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        items[i],
                        style: AppTypography.sora(
                          13.5,
                          FontWeight.w600,
                          color: i == selectedIndex
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selectedIndex
                        ? AppColors.primary
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: i == selectedIndex
                        ? null
                        : Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    items[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sora(
                      13,
                      FontWeight.w600,
                      color: i == selectedIndex
                          ? Colors.white
                          : AppColors.textBody,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Puces de filtre défilantes (catégories de services, périodes).
class AppFilterChips extends StatelessWidget {
  const AppFilterChips({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSizes.screenPadding,
    ),
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(index),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                border: selected ? null : Border.all(color: AppColors.border),
              ),
              child: Text(
                items[index],
                style: AppTypography.manrope(
                  12.5,
                  FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textBody,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Avatar rond avec initiales.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.initials,
    this.size = AppSizes.avatarSize,
    this.imageUrl,
    this.background = AppColors.tintGreen,
    this.color = AppColors.primary,
  });

  final String initials;
  final double size;
  final String? imageUrl;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: background,
        backgroundImage: NetworkImage(imageUrl!),
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        initials,
        style: AppTypography.sora(size * 0.34, FontWeight.w700, color: color),
      ),
    );
  }
}

/// Barre de progression fine (paliers de fidélité, objectifs).
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.accent,
    this.background = AppColors.toggleOff,
    this.height = 7,
  });

  /// Progression entre 0 et 1.
  final double value;
  final Color color;
  final Color background;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        color: color,
        backgroundColor: background,
      ),
    );
  }
}

/// Bordure en pointillés (zone « Ajouter un produit », séparateur de ticket).
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    this.color = AppColors.borderStrong,
    this.radius = 14,
    this.strokeWidth = 1.5,
    this.dashLength = 5,
    this.gapLength = 4,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// Filet horizontal en pointillés (séparateurs du ticket de caisse).
class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key, this.color = AppColors.borderStrong});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 1,
        width: double.infinity,
        child: CustomPaint(painter: _DashedLinePainter(color)),
      );
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint);
      x += 8;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Compteur − / valeur / + (réception de stock, quantités du ticket).
class AppStepper extends StatelessWidget {
  const AppStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.minValue = 0,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int minValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            enabled: value > minValue,
            onTap: () => onChanged(value - 1),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 34),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: AppTypography.sora(15, FontWeight.w800),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            filled: true,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.accent : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: filled ? null : Border.all(color: AppColors.border),
          ),
          child: Icon(
            icon,
            size: 15,
            color: filled
                ? Colors.white
                : (enabled ? AppColors.textBody : AppColors.textFaint),
          ),
        ),
      ),
    );
  }
}

/// Chevron de navigation des lignes de liste.
class AppChevron extends StatelessWidget {
  const AppChevron({super.key, this.color});

  /// Teinte le chevron d'une ligne mise en avant (choix suggéré).
  final Color? color;

  @override
  Widget build(BuildContext context) => Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: color ?? AppColors.textFaint,
      );
}
