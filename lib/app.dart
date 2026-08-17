import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'features/auth/domain/user_role.dart';
import 'features/auth/presentation/auth_providers.dart';
import 'features/auth/presentation/join_salon_page.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/profile_page.dart';
import 'features/auth/presentation/register_page.dart';
import 'features/auth/presentation/role_selection_page.dart';
import 'features/auth/presentation/signup_choice_page.dart';
import 'features/auth/presentation/welcome_page.dart';
import 'features/catalog/domain/salon_service.dart';
import 'features/catalog/presentation/catalog_page.dart';
import 'features/catalog/presentation/package_form_page.dart';
import 'features/catalog/presentation/packages_page.dart';
import 'features/catalog/presentation/service_edit_page.dart';
import 'features/clients/presentation/client_detail_page.dart';
import 'features/clients/presentation/client_form_page.dart';
import 'features/clients/presentation/clients_page.dart';
import 'features/finance/domain/finance_summary.dart';
import 'features/finance/presentation/expense_form_page.dart';
import 'features/finance/presentation/expenses_page.dart';
import 'features/finance/presentation/export_page.dart';
import 'features/finance/presentation/finance_page.dart';
import 'features/finance/presentation/my_commission_page.dart';
import 'features/finance/presentation/net_result_page.dart';
import 'features/finance/presentation/payout_requests_page.dart';
import 'features/finance/presentation/service_report_page.dart';
import 'features/finance/presentation/stylist_commission_detail_page.dart';
import 'features/finance/presentation/stylist_report_page.dart';
import 'features/home/presentation/home_page.dart';
import 'features/home/presentation/more_page.dart';
import 'features/inventory/domain/product.dart';
import 'features/inventory/presentation/consumption_page.dart';
import 'features/inventory/presentation/inventory_page.dart';
import 'features/inventory/presentation/product_detail_page.dart';
import 'features/inventory/presentation/product_form_page.dart';
import 'features/inventory/presentation/stock_reception_page.dart';
import 'features/loyalty/presentation/loyalty_page.dart';
import 'features/loyalty/presentation/promotion_form_page.dart';
import 'features/loyalty/presentation/promotions_page.dart';
import 'features/loyalty/presentation/reminders_page.dart';
import 'features/pos/domain/ticket.dart';
import 'features/pos/presentation/payment_page.dart';
import 'features/pos/presentation/pos_add_to_ticket_page.dart';
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
import 'features/staff/presentation/time_off_history_page.dart';
import 'features/staff/presentation/time_off_page.dart';
import 'features/staff/presentation/time_off_request_page.dart';

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
      // Sans ces délégués, `showDatePicker` et `showTimePicker` ne trouvent
      // que l'anglais : demander une date en français faisait échouer la
      // résolution des `MaterialLocalizations` et cassait le sélecteur.
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return OfflineBanner(child: child ?? const SizedBox.shrink());
      },
      home: const _AuthGate(),
      onGenerateRoute: buildRoute,
    );
  }

  /// Générateur de route global et imbriqué.
  static Route<dynamic>? buildRoute(RouteSettings settings) {
    Route<dynamic> page(Widget child) => MaterialPageRoute(
          builder: (_) => child,
          settings: settings,
        );

    final simpleWidget = _routesMap[settings.name];
    if (simpleWidget != null) return page(simpleWidget);

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
      StaffFormPage.routeName =>
        page(StaffFormPage(member: settings.arguments as Profile?)),
      StaffSchedulePage.routeName =>
        page(StaffSchedulePage(member: settings.arguments! as Profile)),
      ProductDetailPage.routeName =>
        page(ProductDetailPage(productId: settings.arguments! as String)),
      ProductFormPage.routeName =>
        page(ProductFormPage(product: settings.arguments as Product?)),
      ServiceEditPage.routeName =>
        page(ServiceEditPage(service: settings.arguments as SalonService?)),
      RefundPage.routeName =>
        page(RefundPage(transaction: settings.arguments! as SalonTransaction)),
      PlanCheckoutPage.routeName =>
        page(PlanCheckoutPage(plan: settings.arguments! as SubscriptionPlan)),
      StylistCommissionDetailPage.routeName => page(
          StylistCommissionDetailPage(
            commission: settings.arguments! as StylistCommission,
          ),
        ),
      _ => null,
    };
  }

  static final Map<String, Widget> _routesMap = {
    WelcomePage.routeName: const WelcomePage(),
    LoginPage.routeName: const LoginPage(),
    SignupChoicePage.routeName: const SignupChoicePage(),
    RegisterPage.routeName: const RegisterPage(),
    JoinSalonPage.routeName: const JoinSalonPage(),
    HomePage.routeName: const HomePage(),
    MorePage.routeName: const MorePage(),
    AgendaPage.routeName: const AgendaPage(),
    AppointmentFormPage.routeName: const AppointmentFormPage(),
    WalkInQueuePage.routeName: const WalkInQueuePage(),
    ClientsPage.routeName: const ClientsPage(),
    ClientFormPage.routeName: const ClientFormPage(),
    CatalogPage.routeName: const CatalogPage(),
    PackagesPage.routeName: const PackagesPage(),
    PackageFormPage.routeName: const PackageFormPage(),
    PosPage.routeName: const PosPage(),
    PosAddToTicketPage.routeName: const PosAddToTicketPage(),
    PaymentPage.routeName: const PaymentPage(),
    ReceiptPage.routeName: const ReceiptPage(),
    TransactionsPage.routeName: const TransactionsPage(),
    InventoryPage.routeName: const InventoryPage(),
    StockReceptionPage.routeName: const StockReceptionPage(),
    ConsumptionPage.routeName: const ConsumptionPage(),
    FinancePage.routeName: const FinancePage(),
    StylistReportPage.routeName: const StylistReportPage(),
    MyCommissionPage.routeName: const MyCommissionPage(),
    NetResultPage.routeName: const NetResultPage(),
    PayoutRequestsPage.routeName: const PayoutRequestsPage(),
    ServiceReportPage.routeName: const ServiceReportPage(),
    ExpensesPage.routeName: const ExpensesPage(),
    ExpenseFormPage.routeName: const ExpenseFormPage(),
    ExportPage.routeName: const ExportPage(),
    LoyaltyPage.routeName: const LoyaltyPage(),
    PromotionsPage.routeName: const PromotionsPage(),
    PromotionFormPage.routeName: const PromotionFormPage(),
    RemindersPage.routeName: const RemindersPage(),
    StaffPage.routeName: const StaffPage(),
    TimeOffPage.routeName: const TimeOffPage(),
    TimeOffRequestPage.routeName: const TimeOffRequestPage(),
    TimeOffHistoryPage.routeName: const TimeOffHistoryPage(),
    SettingsPage.routeName: const SettingsPage(),
    SalonInfoPage.routeName: const SalonInfoPage(),
    RolesPage.routeName: const RolesPage(),
    NotificationsPage.routeName: const NotificationsPage(),
    SubscriptionPage.routeName: const SubscriptionPage(),
    PlanSelectionPage.routeName: const PlanSelectionPage(),
    ProfilePage.routeName: const ProfilePage(),
  };
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

  /// Indexées plutôt que listées : le nombre d'onglets dépend du rôle.
  final Map<int, GlobalKey<NavigatorState>> _navigatorKeys = {};

  static const _Tab _homeTab =
      _Tab('Accueil', Icons.home_outlined, Icons.home_rounded, HomePage());
  static const _Tab _agendaTab = _Tab(
    'Agenda',
    Icons.calendar_today_outlined,
    Icons.calendar_today_rounded,
    AgendaPage(),
  );
  static const _Tab _posTab = _Tab(
    'Caisse',
    Icons.receipt_long_outlined,
    Icons.receipt_long_rounded,
    PosPage(),
  );
  static const _Tab _clientsTab = _Tab(
    'Clients',
    Icons.people_outline_rounded,
    Icons.people_rounded,
    ClientsPage(),
  );
  static const _Tab _moreTab =
      _Tab('Plus', Icons.grid_view_outlined, Icons.grid_view_rounded, MorePage());

  /// La caisse n'apparaît que pour qui a le droit d'encaisser. Le coiffeur
  /// réalise la prestation ; c'est la réception qui encaisse.
  List<_Tab> _tabsFor(UserRole role) => [
        _homeTab,
        _agendaTab,
        if (role.canOperatePos) _posTab,
        _clientsTab,
        _moreTab,
      ];

  GlobalKey<NavigatorState> _navigatorKey(int index) =>
      _navigatorKeys.putIfAbsent(index, GlobalKey<NavigatorState>.new);

  void _onTabSelected(int index) {
    if (_index == index) {
      _navigatorKey(index).currentState?.popUntil((route) => route.isFirst);
    } else {
      if (!_visitedIndices.contains(index)) {
        setState(() {
          _visitedIndices.add(index);
          _index = index;
        });
      } else {
        setState(() => _index = index);
      }
    }
  }

  Widget _buildTabNavigator(List<_Tab> tabs, int index) {
    return Navigator(
      key: _navigatorKey(index),
      onGenerateRoute: (settings) {
        if (settings.name == '/' || settings.name == null) {
          return MaterialPageRoute(builder: (_) => tabs[index].page);
        }
        return AtelierApp.buildRoute(settings);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider) ?? UserRole.coiffeur;
    final tabs = _tabsFor(role);

    // La caisse est le bouton central surélevé. Sans elle, la barre retombe
    // sur quatre onglets réguliers et le bouton disparaît.
    final posIndex = tabs.indexOf(_posTab);

    // Le rôle peut arriver après le premier rendu : si l'onglet courant sort
    // de la liste, on se replie sur l'accueil plutôt que d'indexer hors bornes.
    if (_index >= tabs.length) _index = 0;

    final body = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final currentNav = _navigatorKey(_index).currentState;
        if (currentNav != null && currentNav.canPop()) {
          currentNav.pop();
        } else if (_index != 0) {
          setState(() => _index = 0);
        }
      },
      child: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < tabs.length; i++)
            _visitedIndices.contains(i)
                ? _buildTabNavigator(tabs, i)
                : const SizedBox.shrink(),
        ],
      ),
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
                for (final tab in tabs)
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Pilule flottante sombre (Prototype Lot 2/6/8)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1E1B),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4714190F),
                        blurRadius: 30,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (var i = 0; i < tabs.length; i++)
                        if (i == posIndex)
                          // Espace réservé au bouton central surélevé.
                          const SizedBox(width: 58)
                        else
                          Expanded(
                            child: _TabButton(
                              tab: tabs[i],
                              selected: _index == i,
                              onTap: () => _onTabSelected(i),
                            ),
                          ),
                    ],
                  ),
                ),
              ),

              // 2. Bouton d'action central vert surélevé (Caisse / POS)
              if (posIndex >= 0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _onTabSelected(posIndex),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1E1B),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4D20251F),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _index == posIndex
                                ? const Color(0xFF22D65C)
                                : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _index == posIndex
                                ? Icons.receipt_long_rounded
                                : Icons.add_rounded,
                            size: 28,
                            color: _index == posIndex
                                ? const Color(0xFF0A2A16)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
    final color = selected ? const Color(0xFF22D65C) : const Color(0xFFEDEFEC);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? tab.activeIcon : tab.icon, size: 21, color: color),
            const SizedBox(height: 3),
            Text(
              tab.label,
              style: AppTypography.manrope(
                10,
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
