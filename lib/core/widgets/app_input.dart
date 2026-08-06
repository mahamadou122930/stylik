import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_typography.dart';

/// Champ de saisie de la maquette : libellé au-dessus, champ blanc rayon 12.
class AppInput extends StatelessWidget {
  const AppInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffix,
    this.textInputAction,
    this.autofocus = false,
    this.dark = false,
  });

  /// Champ téléphone (clavier numérique, icône combiné).
  const AppInput.phone({
    super.key,
    this.label = 'Téléphone',
    this.hint = '77 000 00 00',
    this.controller,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.textInputAction,
    this.autofocus = false,
    this.dark = false,
  })  : keyboardType = TextInputType.phone,
        inputFormatters = null,
        obscureText = false,
        maxLines = 1,
        prefixIcon = Icons.phone_outlined,
        suffix = null;

  /// Champ montant en FCFA (chiffres uniquement, suffixe « F »).
  AppInput.amount({
    super.key,
    this.label = 'Montant',
    this.hint = '0',
    this.controller,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.textInputAction,
    this.autofocus = false,
    this.dark = false,
  })  : keyboardType = TextInputType.number,
        inputFormatters = [FilteringTextInputFormatter.digitsOnly],
        obscureText = false,
        maxLines = 1,
        prefixIcon = null,
        suffix = Text(
          'F',
          style: AppTypography.sora(14, FontWeight.w700),
        );

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 7),
            child: Text(
              label!,
              style: AppTypography.manrope(
                12.5,
                FontWeight.w600,
                color: dark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ),
        ],
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          onChanged: onChanged,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          obscureText: obscureText,
          enabled: enabled,
          maxLines: obscureText ? 1 : maxLines,
          autofocus: autofocus,
          textInputAction: textInputAction,
          style: AppTypography.manrope(13.5, FontWeight.w600).copyWith(
            color: dark ? Colors.white : AppColors.textPrimary,
          ),
          cursorColor: dark ? Colors.white : AppColors.accent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: dark
                ? AppTypography.manrope(
                    13.5,
                    FontWeight.w500,
                    color: Colors.white30,
                  )
                : null,
            fillColor: dark ? Colors.white10 : null,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(
                    prefixIcon,
                    size: 18,
                    color: dark ? Colors.white60 : AppColors.primary,
                  ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 42, minHeight: 20),
            enabledBorder: dark
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    borderSide: const BorderSide(color: Colors.white12),
                  )
                : null,
            focusedBorder: dark
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    borderSide: const BorderSide(color: Colors.white38),
                  )
                : null,
            suffixIcon: suffix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Align(
                      alignment: Alignment.centerRight,
                      widthFactor: 1,
                      child: suffix,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Barre de recherche des listes (clients, services, produits).
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Rechercher…',
    this.controller,
    this.trailing,
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final TextEditingController? controller;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: AppTypography.manrope(13.5, FontWeight.w600),
              cursorColor: AppColors.accent,
              decoration: InputDecoration(
                hintText: hint,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 19,
                  color: AppColors.textFaint,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

/// Sélecteur de valeur type « champ » ouvrant une feuille (date, coiffeur…).
class AppSelectField extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
    this.placeholder = 'Choisir',
  });

  final String label;
  final String? value;
  final IconData? icon;
  final VoidCallback? onTap;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final filled = value != null && value!.isNotEmpty;

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
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: Ink(
              height: AppSizes.inputHeight,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      filled ? value! : placeholder,
                      style: AppTypography.manrope(
                        13.5,
                        FontWeight.w600,
                        color: filled
                            ? AppColors.textPrimary
                            : AppColors.textFaint,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.textFaint,
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
