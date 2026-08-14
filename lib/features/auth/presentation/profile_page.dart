import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../settings/presentation/roles_page.dart';
import '../../settings/presentation/settings_providers.dart';
import '../../staff/presentation/staff_providers.dart';
import 'auth_providers.dart';

/// Écran « Mon profil » d'après la maquette.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  static const routeName = '/profile';

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _notificationsEnabled = true;

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Se déconnecter ?',
          style: AppTypography.sora(17, FontWeight.w700),
        ),
        content: Text(
          'Vous devrez vous re-connecter pour accéder à votre salon.',
          style: AppTypography.manrope(
            13.5,
            FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Annuler',
              style: AppTypography.manrope(
                13,
                FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          AppButton(
            label: 'Déconnexion',
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await ref.read(authControllerProvider.notifier).signOut();
  }

  Future<void> _editPersonalInfo() async {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null) return;

    final nameController = TextEditingController(text: profile.fullName);
    final phoneController = TextEditingController(text: profile.phone ?? '');
    final emailController = TextEditingController(text: profile.email ?? '');

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Informations personnelles',
                    style: AppTypography.sora(18, FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: nameController,
                label: 'Nom complet',
                hint: 'Ex: Léa Fall',
              ),
              const SizedBox(height: 12),
              AppInput.phone(
                controller: phoneController,
                label: 'Téléphone',
                hint: '+221 77 123 45 67',
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: emailController,
                label: 'Email',
                hint: 'lea@latelier.sn',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Enregistrer',
                onPressed: () async {
                  try {
                    final updatedProfile = profile.copyWith(
                      fullName: nameController.text.trim(),
                      phone: phoneController.text.trim().isEmpty
                          ? null
                          : phoneController.text.trim(),
                      email: emailController.text.trim().isEmpty
                          ? null
                          : emailController.text.trim(),
                    );
                    await ref
                        .read(staffRepositoryProvider)
                        .update(updatedProfile);
                    ref.invalidate(currentProfileProvider);
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext, true);
                    }
                  } catch (e) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(content: Text('Erreur: $e')),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informations mises à jour !'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mot de passe & sécurité',
                    style: AppTypography.sora(18, FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: passwordController,
                label: 'Nouveau mot de passe',
                obscureText: true,
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: confirmController,
                label: 'Confirmer le mot de passe',
                obscureText: true,
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Modifier le mot de passe',
                onPressed: () async {
                  final pwd = passwordController.text.trim();
                  final confirm = confirmController.text.trim();
                  if (pwd.length < 6) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                        content: Text('Le mot de passe doit faire 6 caractères min.'),
                      ),
                    );
                    return;
                  }
                  if (pwd != confirm) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                        content: Text('Les mots de passe ne correspondent pas.'),
                      ),
                    );
                    return;
                  }

                  try {
                    await SupabaseService.auth.updateUser(
                      UserAttributes(password: pwd),
                    );
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mot de passe modifié avec succès !'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  } catch (e) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(content: Text('Erreur: $e')),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final salon = ref.watch(currentSalonProvider).valueOrNull;

    final fullName = profile?.fullName ?? 'Léa Fall';
    final email = profile?.email ?? 'lea@latelier.sn';
    final roleLabel = profile?.role.label ?? 'Gérante';
    final salonName = salon?.name ?? 'L\'Atelier Coiffure';

    return AppScreen(
      title: 'Mon profil',
      action: AppIconButton(
        icon: Icons.edit_outlined,
        onTap: _editPersonalInfo,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bloc En-tête Profil (Avatar, Nom, Email, Badge)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                // Avatar vert carré arrondi
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    Formatters.initials(fullName),
                    style: AppTypography.sora(
                      26,
                      FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  fullName,
                  style: AppTypography.sora(
                    21,
                    FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: AppTypography.manrope(
                    13,
                    FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                // Badge "Gérante · L'Atelier Coiffure"
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tintGreenSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$roleLabel · $salonName',
                    style: AppTypography.manrope(
                      12.5,
                      FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Section COMPTE
          const AppSectionTitle(
            'COMPTE',
            padding: EdgeInsets.fromLTRB(2, 4, 2, 8),
          ),
          AppListCard(
            children: [
              AppListRow(
                label: 'Informations personnelles',
                strong: true,
                padding: const EdgeInsets.symmetric(vertical: 13),
                leading: const AppIconTile(
                  icon: Icons.person_outline_rounded,
                  color: AppColors.primary,
                  background: AppColors.tintGreen,
                  size: 38,
                  radius: 12,
                ),
                trailing: const AppChevron(),
                onTap: _editPersonalInfo,
              ),
              AppListRow(
                label: 'Mot de passe & sécurité',
                strong: true,
                padding: const EdgeInsets.symmetric(vertical: 13),
                leading: const AppIconTile(
                  icon: Icons.lock_outline_rounded,
                  color: AppColors.blue,
                  background: AppColors.tintBlue,
                  size: 38,
                  radius: 12,
                ),
                trailing: const AppChevron(),
                onTap: _changePassword,
              ),
              if (profile?.role.canManageSettings ?? false)
                AppListRow(
                  label: 'Mon rôle & permissions',
                  strong: true,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  leading: const AppIconTile(
                    icon: Icons.star_outline_rounded,
                    color: AppColors.amber,
                    background: AppColors.tintAmber,
                    size: 38,
                    radius: 12,
                  ),
                  trailing: const AppChevron(),
                  onTap: () =>
                      Navigator.of(context).pushNamed(RolesPage.routeName),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Section PRÉFÉRENCES
          const AppSectionTitle(
            'PRÉFÉRENCES',
            padding: EdgeInsets.fromLTRB(2, 4, 2, 8),
          ),
          AppListCard(
            children: [
              AppListRow(
                label: 'Notifications push',
                strong: true,
                padding: const EdgeInsets.symmetric(vertical: 11),
                trailing: Switch.adaptive(
                  value: _notificationsEnabled,
                  activeTrackColor: AppColors.primary,
                  onChanged: (val) => setState(() => _notificationsEnabled = val),
                ),
              ),
              AppListRow(
                label: 'Langue',
                strong: true,
                padding: const EdgeInsets.symmetric(vertical: 13),
                trailing: Text(
                  'Français',
                  style: AppTypography.manrope(
                    13.5,
                    FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Bouton Se déconnecter rouge teinté
          Material(
            color: AppColors.tintDanger,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _signOut,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      color: AppColors.dangerDeep,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Se déconnecter',
                      style: AppTypography.sora(
                        15,
                        FontWeight.w700,
                        color: AppColors.dangerDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
