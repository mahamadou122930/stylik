import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_typography.dart';
import 'app_button.dart';

/// État vide (liste sans résultat, agenda libre, stock non renseigné).
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Version resserrée insérée dans une page défilante.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.tintGreen,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 26, color: AppColors.primary),
        ),
        const SizedBox(height: AppSizes.lg),
        Text(title, style: AppTypography.sora(15, FontWeight.w700)),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppSizes.xl),
          AppButton(
            label: actionLabel!,
            onPressed: onAction,
            expanded: false,
            height: 46,
          ),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 28 : 56, horizontal: 24),
      child: Center(child: content),
    );
  }
}

/// État d'erreur avec bouton « Réessayer ».
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) => AppEmptyState(
        title: 'Une erreur est survenue',
        message: message,
        icon: Icons.error_outline_rounded,
        actionLabel: onRetry == null ? null : 'Réessayer',
        onAction: onRetry,
        compact: compact,
      );
}

/// Indicateur de chargement.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 28 : 56),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
}
