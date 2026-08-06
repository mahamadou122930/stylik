# Fix Login Page Design Mismatch

The current Login Page uses a light theme that doesn't match the "dark branded" design from the reference mockup (Lot 1.2). I will update the page to match the dark background, centered branding, and specific styling of the mockup.

## Proposed Changes

### [Core Widgets]

#### [MODIFY] [app_input.dart](file:///D:/02-Dev/Dev/stylik/lib/core/widgets/app_input.dart)
- Add a `dark` boolean parameter to `AppInput`.
- When `dark` is true:
    - Use white text.
    - Use a transparent/dark background with a subtle border.
    - Change prefix icon color to white.

### [Auth Feature]

#### [MODIFY] [login_page.dart](file:///D:/02-Dev/Dev/stylik/lib/features/auth/presentation/login_page.dart)
- Set `Scaffold` background to `AppColors.textPrimary`.
- Center the logo, title, and subtitle.
- Update logo container to be a centered square with `AppColors.accent`.
- Update text colors to white.
- Use the new `dark` variant for `AppInput`.
- Change "Créer un compte" to match the design: "Pas de compte ? Inscrire mon salon".

## Verification Plan

### Manual Verification
- Launch the app to the login screen.
- Verify that the background is dark.
- Verify that the logo is a centered green square.
- Verify that inputs have white icons and text.
- Verify that the "Sign up" link is correctly styled at the bottom.
