import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/salon.dart';
import 'settings_providers.dart';

/// 10.1 — Infos salon : identité, horaires d'ouverture, contact.
class SalonInfoPage extends ConsumerWidget {
  const SalonInfoPage({super.key});

  static const routeName = '/settings/salon';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salon = ref.watch(currentSalonProvider);

    return AppScreen(
      title: 'Mon salon',
      footer: AppButton(
        label: 'Enregistrer',
        onPressed: salon.valueOrNull == null
            ? null
            : () {
                // TODO(settings): persister les modifications du salon.
              },
      ),
      child: salon.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(currentSalonProvider),
        ),
        data: (data) => data == null
            ? const AppEmptyState(
                title: 'Salon introuvable',
                message: 'Aucun salon n\'est rattaché à ce compte.',
                icon: Icons.storefront_outlined,
              )
            : _SalonBody(salon: data),
      ),
    );
  }
}

class _SalonBody extends StatelessWidget {
  const _SalonBody({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    final hours = SalonOpeningHours.fromJson(salon.openingHours);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                  image: (salon.logoUrl?.isNotEmpty ?? false)
                      ? DecorationImage(
                          image: NetworkImage(salon.logoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (salon.logoUrl?.isNotEmpty ?? false)
                    ? null
                    : const Icon(
                        Icons.content_cut_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      salon.name,
                      style: AppTypography.sora(
                        19,
                        FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      salon.address,
                      style: AppTypography.manrope(
                        12.5,
                        FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const AppSectionTitle(
          'Horaires d\'ouverture',
          padding: EdgeInsets.fromLTRB(2, 2, 2, 10),
        ),
        AppListCard(
          children: [
            for (final slot in hours.slots)
              AppListRow(
                label: slot.label,
                value: slot.isClosed ? 'Fermé' : '${slot.open} – ${slot.close}',
                muted: slot.isClosed,
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
          ],
        ),
        const AppSectionTitle('Contact'),
        AppListCard(
          children: [
            AppListRow(
              label: salon.phone.isEmpty ? 'Téléphone à renseigner' : salon.phone,
              leading: const Icon(
                Icons.phone_outlined,
                size: 19,
                color: AppColors.primary,
              ),
              muted: salon.phone.isEmpty,
              strong: true,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            AppListRow(
              label: salon.email?.isNotEmpty ?? false
                  ? salon.email!
                  : 'Email à renseigner',
              leading: const Icon(
                Icons.mail_outline_rounded,
                size: 19,
                color: AppColors.primary,
              ),
              muted: !(salon.email?.isNotEmpty ?? false),
              strong: true,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            AppListRow(
              label: salon.address.isEmpty
                  ? 'Adresse à renseigner'
                  : salon.address,
              leading: const Icon(
                Icons.place_outlined,
                size: 19,
                color: AppColors.primary,
              ),
              muted: salon.address.isEmpty,
              strong: true,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ],
        ),
      ],
    );
  }
}
