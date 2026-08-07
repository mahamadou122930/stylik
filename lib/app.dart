import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_typography.dart';
import 'core/services/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/widgets.dart';
import 'features/agenda/presentation/agenda_page.dart';
import 'features/agenda/presentation/appointment_detail_page.dart';
import 'features/agenda/presentation/appointment_form_page.dart';
import 'features/agenda/presentation/stylist_agenda_page.dart';
import 'features/agenda/presentation/walk_in_queue_page.dart';
import 'features/auth/domain/profile.dart';
import 'features/auth/domain/registration_draft.dart';
import 'features/auth/presentation/auth_providers.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/register_page.dart';
import 'features/auth/presentation/role_selection_page.dart';
import 'features/auth/presentation/welcome_page.dart';
import 'features/catalog/domain/salon_service.dart';
import 'features/catalog/presentation/catalog_page.dart';
import 'features/catalog/presentation/packages_page.dart';
import 'features/catalog/presentation/service_edit_page.dart';
import 'features/clients/presentation/client_detail_page.dart';
import 'features/clients/presentation/client_form_page.dart';
import 'features/clients/presentation/clients_page.dart';
import 'features/finance/presentation/expenses_page.dart';
import 'features/finance/presentation/export_page.dart';
import 'features/finance/presentation/finance_page.dart';
import 'features/finance/presentation/service_report_page.dart';
import 'features/finance/presentation/stylist_report_page.dart';
import 'features/home/presentation/home_page.dart';
import 'features/home/presentation/more_page.dart';
import 'features/inventory/presentation/consumption_page.dart';
import 'features/inventory/presentation/inventory_page.dart';
import 'features/inventory/presentation/product_detail_page.dart';
import 'features/inventory/presentation/stock_reception_page.dart';
import 'features/loyalty/presentation/loyalty_page.dart';
import 'features/loyalty/presentation/promotions_page.dart';
import 'features/loyalty/presentation/reminders_page.dart';
import 'features/pos/domain/ticket.dart';
import 'features/pos/presentation/payment_page.dart';
import 'features/pos/presentation/pos_page.dart';
import 'features/pos/presentation/receipt_page.dart';
import 'features/pos/presentation/refund_page.dart';
import 'features/pos/presentation/transactions_page.dart';
import 'features/settings/domain/subscription_plan.dart';
import 'features/settings/presentation/notifications_page.dart';
import 'features/settings/presentation/plan_checkout_page.dart';
import 'features/settings/presentation/plan_selection_page.dart';
import 'features/settings/presentation/roles_page.dart';
import 'features/settings/presentation/salon_info_page.dart';
import 'features/settings/presentation/settings_page.dart';
import 'features/settings/presentation/subscription_page.dart';
import 'features/staff/presentation/staff_detail_page.dart';
import 'features/staff/presentation/staff_form_page.dart';
import 'features/staff/presentation/staff_page.dart';
import 'features/staff/presentation/staff_schedule_page.dart';
import 'features/staff/presentation/time_off_page.dart';

import 'core/services/sync_engine.dart';
import 'core/widgets/offline_banner.dart';

/// Racine de l'application L'Atelier.
class AtelierApp extends ConsumerWidget {
  const AtelierApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialiser/démarrer l'écouteur du SyncEngine
    ref.listen(syncEngineProvider, (previous, next) {});

    return MaterialApp(
      title: 'L\'Atelier',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) {
        return OfflineBanner(child: child ?? const SizedBox.shrink());
      },
      home: const _AuthGate(),
      routes: {
        WelcomePage.routeName: (_) => const WelcomePage(),
        LoginPage.routeName: (_) => const LoginPage(),
        RegisterPage.routeName: (_) => const RegisterPage(),
        HomePage.routeName: (_) => const HomePage(),
        MorePage.routeName: (_) => const MorePage(),
        AgendaPage.routeName: (_) => const AgendaPage(),
        AppointmentFormPage.routeName: (_) => const AppointmentFormPage(),
        WalkInQueuePage.routeName: (_) => const WalkInQueuePage(),
        ClientsPage.routeName: (_) => const ClientsPage(),
        ClientFormPage.routeName: (_) => const ClientFormPage(),
        CatalogPage.routeName: (_) => const CatalogPage(),
        PackagesPage.routeName: (_) => const PackagesPage(),
        PosPage.routeName: (_) => const PosPage(),
        PaymentPage.routeName: (_) => const PaymentPage(),
        ReceiptPage.routeName: (_) => const ReceiptPage(),
        TransactionsPage.routeName: (_) => const TransactionsPage(),
        InventoryPage.routeName: (_) => const InventoryPage(),
        StockReceptionPage.routeName: (_) => const StockReceptionPage(),
        ConsumptionPage.routeName: (_) => const ConsumptionPage(),
        FinancePage.routeName: (_) => const FinancePage(),
        StylistReportPage.routeName: (_) => const StylistReportPage(),
        ServiceReportPage.routeName: (_) => const ServiceReportPage(),
        ExpensesPage.routeName: (_) => const ExpensesPage(),
        ExportPage.routeName: (_) => const ExportPage(),
        LoyaltyPage.routeName: (_) => const LoyaltyPage(),
        PromotionsPage.routeName: (_) => const PromotionsPage(),
        RemindersPage.routeName: (_) => const RemindersPage(),
        StaffPage.routeName: (_) => const StaffPage(),
        StaffFormPage.routeName: (_) => const StaffFormPage(),
        TimeOffPage.routeName: (_) => const TimeOffPage(),
        SettingsPage.routeName: (_) => const SettingsPage(),
        SalonInfoPage.routeName: (_) => const SalonInfoPage(),
        RolesPage.routeName: (_) => const RolesPage(),
        NotificationsPage.routeName: (_) => const NotificationsPage(),
        SubscriptionPage.routeName: (_) => const SubscriptionPage(),
        PlanSelectionPage.routeName: (_) => const PlanSelectionPage(),
      },
      onGenerateRoute: _onGenerateRoute,
    );
  }

  /// Routes qui reçoivent un argument (identifiant ou objet du domaine).
  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    Route<dynamic> page(Widget child) => MaterialPageRoute(
          builder: (_) => child,
          settings: settings,
        );

    return switch (settings.name) {
      RoleSelectionPage.routeName => page(
          RoleSelectionPage(
            draft: settings.arguments! as RegistrationDraft,
          ),
        ),
      ClientDetailPage.routeName =>
        page(ClientDetailPage(clientId: settings.arguments! as String)),
      AppointmentDetailPage.routeName => page(
          AppointmentDetailPage(appointmentId: settings.arguments! as String),
        ),
      StylistAgendaPage.routeName =>
        page(StylistAgendaPage(stylist: settings.arguments! as Profile)),
      StaffDetailPage.routeName =>
        page(StaffDetailPage(profileId: settings.arguments! as String)),
      StaffSchedulePage.routeName =>
        page(StaffSchedulePage(member: settings.arguments! as Profile)),
      ProductDetailPage.routeName =>
        page(ProductDetailPage(productId: settings.arguments! as String)),
      ServiceEditPage.routeName =>
        page(ServiceEditPage(service: settings.arguments as SalonService?)),
      RefundPage.routeName =>
        page(RefundPage(transaction: settings.arguments! as SalonTransaction)),
      PlanCheckoutPage.routeName =>
        page(PlanCheckoutPage(plan: settings.arguments! as SubscriptionPlan)),
      _ => null,
    };
  }
}

/// Aiguille vers la connexion ou l'espace de travail selon la session.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    if (session == null) return const WelcomePage();

    final profile = ref.watch(currentProfileProvider);
    return profile.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: AppLoader(),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(currentProfileProvider),
        ),
      ),
      // Session ouverte sans profil : le déclencheur Supabase n'a pas encore
      // (ou pas) créé la fiche. Rien d'utile à afficher — on laisse réessayer.
      data: (data) => data == null
          ? Scaffold(
              backgroundColor: AppColors.background,
              body: AppErrorState(
                message: 'Profil introuvable pour ce compte.',
                onRetry: () => ref.invalidate(currentProfileProvider),
              ),
            )
          : const HomeShell(),
    );
  }
}

/// Navigation principale : barre du bas sur mobile, rail sur tablette.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  final Set<int> _visitedIndices = {0};

  static const List<_Tab> _tabs = [
    _Tab('Accueil', Icons.home_outlined, Icons.home_rounded, HomePage()),
    _Tab(
      'Agenda',
      Icons.calendar_today_outlined,
      Icons.calendar_today_rounded,
      AgendaPage(),
    ),
    _Tab(
      'Caisse',
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
      PosPage(),
    ),
    _Tab(
      'Clients',
      Icons.people_outline_rounded,
      Icons.people_rounded,
      ClientsPage(),
    ),
    _Tab('Plus', Icons.grid_view_outlined, Icons.grid_view_rounded, MorePage()),
  ];

  void _onTabSelected(int index) {
    if (!_visitedIndices.contains(index)) {
      setState(() {
        _visitedIndices.add(index);
        _index = index;
      });
    } else {
      setState(() => _index = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < _tabs.length; i++)
          _visitedIndices.contains(i) ? _tabs[i].page : const SizedBox.shrink(),
      ],
    );

    if (MediaQuery.sizeOf(context).width >= 720) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: _onTabSelected,
              destinations: [
                for (final tab in _tabs)
                  NavigationRailDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.activeIcon),
                    label: Text(tab.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: body,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _TabButton(
                      tab: _tabs[i],
                      selected: i == _index,
                      onTap: () => _onTabSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textFaint;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? tab.activeIcon : tab.icon, size: 23, color: color),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: AppTypography.manrope(
                10.5,
                selected ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon, this.page);

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;
}
