/// Noms des tables et buckets Supabase.
///
/// Centralisés ici pour éviter les chaînes magiques dans les repositories.
abstract final class SupabaseTables {
  // Cœur métier
  static const String salons = 'salons';
  static const String profiles = 'profiles';
  static const String clients = 'clients';
  static const String services = 'services';
  static const String appointments = 'appointments';
  static const String walkInQueue = 'walk_in_queue';
  static const String products = 'products';
  static const String transactions = 'transactions';

  // Extensions couvertes par la maquette
  static const String timeOff = 'time_off';
  static const String payoutRequests = 'payout_requests';
  static const String stockMovements = 'stock_movements';
  static const String expenses = 'expenses';
  static const String promotions = 'promotions';
  static const String loyaltyRewards = 'loyalty_rewards';
  static const String reminderRules = 'reminder_rules';
  static const String campaigns = 'campaigns';
  static const String subscriptions = 'subscriptions';
  static const String subscriptionPlans = 'subscription_plans';
}

/// Buckets Supabase Storage.
abstract final class SupabaseBuckets {
  static const String salonLogos = 'salon-logos';
  static const String clientPhotos = 'client-photos';
  static const String productPhotos = 'product-photos';
}
