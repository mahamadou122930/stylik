import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_typography.dart';
import 'app_atoms.dart';

/// Emplacement photo (avant / après client, logo salon, visuel produit).
///
/// Affiche, par ordre de priorité : le fichier local sélectionné, l'URL
/// distante, puis un état vide cliquable proposant appareil photo / galerie.
class ImageSlot extends StatelessWidget {
  const ImageSlot({
    super.key,
    required this.label,
    this.imageUrl,
    this.localFile,
    this.onImagePicked,
    this.onRemove,
    this.height = 150,
    this.isUploading = false,
  });

  final String label;
  final String? imageUrl;
  final File? localFile;
  final ValueChanged<File>? onImagePicked;
  final VoidCallback? onRemove;
  final double height;
  final bool isUploading;

  bool get _hasImage => localFile != null || (imageUrl?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.radiusLg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(
            label,
            style: AppTypography.manrope(
              12.5,
              FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(
          height: height,
          child: Material(
            color: AppColors.surfaceMuted,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onImagePicked == null
                  ? null
                  : () async {
                      final file = await pickImageFile(context);
                      if (file != null) onImagePicked!(file);
                    },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (localFile != null)
                    Image.file(localFile!, fit: BoxFit.cover)
                  else if (imageUrl?.isNotEmpty ?? false)
                    Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _Placeholder(),
                    )
                  else
                    const _Placeholder(),
                  if (isUploading)
                    Container(
                      color: AppColors.textPrimary.withValues(alpha: 0.18),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
                  if (_hasImage && onRemove != null && !isUploading)
                    Positioned(
                      top: AppSizes.sm,
                      right: AppSizes.sm,
                      child: _RoundIconButton(
                        icon: Icons.close_rounded,
                        onTap: onRemove!,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

}

/// Feuille « appareil photo / galerie », partagée par tous les emplacements
/// image. Renvoie `null` si l'utilisateur annule.
Future<File?> pickImageFile(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(
                'Prendre une photo',
                style: AppTypography.manrope(14, FontWeight.w600),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                'Choisir dans la galerie',
                style: AppTypography.manrope(14, FontWeight.w600),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return null;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    return picked == null ? null : File(picked.path);
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_a_photo_outlined,
            color: AppColors.textFaint,
            size: 22,
          ),
          const SizedBox(height: 8),
          Text(
            'Ajouter une photo',
            style: AppTypography.manrope(
              12,
              FontWeight.w600,
              color: AppColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.textPrimary.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xs),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// Emplacement carré du logo du salon (écran 1.3) : 96 × 96, bordure en
/// pointillés, icône et libellé verts au centre.
class LogoSlot extends StatelessWidget {
  const LogoSlot({
    super.key,
    this.file,
    this.imageUrl,
    required this.onPicked,
    this.size = 96,
  });

  final File? file;
  final String? imageUrl;
  final ValueChanged<File> onPicked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(26);
    final hasImage = file != null || (imageUrl?.isNotEmpty ?? false);

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: AppColors.surface,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              final picked = await pickImageFile(context);
              if (picked != null) onPicked(picked);
            },
            child: hasImage
                ? (file != null
                    ? Image.file(file!, fit: BoxFit.cover)
                    : Image.network(imageUrl!, fit: BoxFit.cover))
                : CustomPaint(
                    painter: DashedBorderPainter(
                      radius: 26,
                      color: AppColors.dashLine,
                      strokeWidth: 1.5,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          size: 24,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Logo',
                          style: AppTypography.manrope(
                            10.5,
                            FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Paire de photos avant / après pour la fiche client.
class BeforeAfterSlots extends StatelessWidget {
  const BeforeAfterSlots({
    super.key,
    this.beforeUrl,
    this.afterUrl,
    this.onBeforePicked,
    this.onAfterPicked,
  });

  final String? beforeUrl;
  final String? afterUrl;
  final ValueChanged<File>? onBeforePicked;
  final ValueChanged<File>? onAfterPicked;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ImageSlot(
            label: 'Avant',
            imageUrl: beforeUrl,
            onImagePicked: onBeforePicked,
          ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: ImageSlot(
            label: 'Après',
            imageUrl: afterUrl,
            onImagePicked: onAfterPicked,
          ),
        ),
      ],
    );
  }
}
