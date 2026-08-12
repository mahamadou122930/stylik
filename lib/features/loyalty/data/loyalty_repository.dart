import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../clients/domain/client.dart';
import '../domain/loyalty_campaign.dart';

/// Fidélité et marketing : points, récompenses, promotions, rappels.
class LoyaltyRepository {
  const LoyaltyRepository(this._client);

  final SupabaseClient _client;

  // --- Points -------------------------------------------------------------

  /// Crédite des points à un client (RPC atomique côté Postgres).
  Future<void> addPoints({required String clientId, required int points}) {
    return _client.rpc<void>(
      'add_loyalty_points',
      params: {'p_client_id': clientId, 'p_points': points},
    );
  }

  /// Débite les points d'une récompense échangée.
  Future<void> redeemReward({
    required String clientId,
    required LoyaltyReward reward,
  }) =>
      addPoints(clientId: clientId, points: -reward.pointsCost);

  /// Meilleurs clients par points cumulés.
  Future<List<Client>> fetchTopClients({
    required String salonId,
    int limit = 20,
  }) async {
    final data = await _client
        .from(SupabaseTables.clients)
        .select()
        .eq('salon_id', salonId)
        .order('loyalty_points', ascending: false)
        .limit(limit);

    return data.map((row) => Client.fromMap(row)).toList();
  }

  // --- Récompenses --------------------------------------------------------

  Future<List<LoyaltyReward>> fetchRewards(String salonId) async {
    final data = await _client
        .from(SupabaseTables.loyaltyRewards)
        .select()
        .eq('salon_id', salonId)
        .eq('is_active', true)
        .order('points_cost', ascending: true);

    return data.map((row) => LoyaltyReward.fromMap(row)).toList();
  }

  // --- Promotions ---------------------------------------------------------

  Future<List<Promotion>> fetchPromotions(String salonId) async {
    final data = await _client
        .from(SupabaseTables.promotions)
        .select()
        .eq('salon_id', salonId)
        .order('starts_at', ascending: false);

    return data.map((row) => Promotion.fromMap(row)).toList();
  }

  Future<void> createPromotion(Promotion promo) async {
    final payload = promo.toMap();
    if (payload['id'] == null || payload['id'] == '') payload.remove('id');
    await _client.from(SupabaseTables.promotions).insert(payload);
  }

  Future<void> setPromotionActive({
    required String promotionId,
    required bool isActive,
  }) =>
      _client
          .from(SupabaseTables.promotions)
          .update({'is_active': isActive})
          .eq('id', promotionId);

  // --- Rappels automatiques ----------------------------------------------

  Future<List<ReminderRule>> fetchReminderRules(String salonId) async {
    final data = await _client
        .from(SupabaseTables.reminderRules)
        .select()
        .eq('salon_id', salonId)
        .order('created_at', ascending: true);

    return data.map((row) => ReminderRule.fromMap(row)).toList();
  }

  Future<void> setReminderEnabled({
    required String ruleId,
    required bool isEnabled,
  }) =>
      _client
          .from(SupabaseTables.reminderRules)
          .update({'is_enabled': isEnabled})
          .eq('id', ruleId);

  /// Statistiques d'envoi du mois (fonction `reminder_stats`).
  Future<ReminderStats> fetchReminderStats(String salonId) async {
    final data = await _client.rpc<Map<String, dynamic>?>(
      'reminder_stats',
      params: {'p_salon_id': salonId},
    );
    return data == null ? ReminderStats.empty : ReminderStats.fromMap(data);
  }

  // --- Campagnes ----------------------------------------------------------

  /// Clients d'un segment (étiquettes CRM) — cible d'une campagne.
  Future<List<Client>> fetchSegment({
    required String salonId,
    required List<String> tags,
  }) async {
    var query =
        _client.from(SupabaseTables.clients).select().eq('salon_id', salonId);

    if (tags.isNotEmpty) query = query.overlaps('tags', tags);

    final data = await query.order('full_name', ascending: true);
    return data.map((row) => Client.fromMap(row)).toList();
  }

  /// Déclenche l'envoi d'une campagne via l'Edge Function `send-campaign`.
  Future<void> sendCampaign(LoyaltyCampaign campaign) async {
    await _client.functions.invoke('send-campaign', body: campaign.toMap());
  }
}
