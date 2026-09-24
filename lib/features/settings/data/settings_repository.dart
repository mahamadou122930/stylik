import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../core/services/storage_service.dart';
import '../domain/salon.dart';
import '../domain/subscription.dart';
import '../domain/subscription_plan.dart';

/// Informations du salon et paramètres généraux.
class SettingsRepository {
  const SettingsRepository(this._client, this._storage);

  final SupabaseClient _client;
  final StorageService _storage;

  Future<Salon?> fetchSalon(String salonId) async {
    final data = await _client
        .from(SupabaseTables.salons)
        .select()
        .eq('id', salonId)
        .maybeSingle();
    return data == null ? null : Salon.fromMap(data);
  }

  /// Crée le salon lors de l'inscription (écran 1.3) et renvoie sa fiche,
  /// identifiant généré compris.
  ///
  /// Le salon est créé avant le compte du gérant : l'appelant est donc encore
  /// anonyme. On passe par une fonction `SECURITY DEFINER` plutôt qu'un insert
  /// direct, qui exigerait d'ouvrir aussi la lecture de `salons` aux anonymes.
  Future<Salon> create({
    required String name,
    required String phone,
    required String address,
  }) async {
    final data = await _client.rpc<Map<String, dynamic>>(
      'create_salon_for_signup',
      params: {'p_name': name, 'p_phone': phone, 'p_address': address},
    );
    return Salon.fromMap(data);
  }

  /// Supprime un salon créé à l'inscription quand la suite a échoué.
  ///
  /// Sans ça la ligne reste en base à jamais : l'isolation multi-tenant la rend
  /// invisible dès qu'elle n'a pas de gérant. La RPC ne supprime que les salons
  /// sans aucun profil rattaché.
  Future<void> deleteOrphan(String salonId) {
    return _client.rpc<void>(
      'delete_orphan_salon',
      params: {'p_salon_id': salonId},
    );
  }

  Future<Salon> update(Salon salon) async {
    final data = await _client
        .from(SupabaseTables.salons)
        .update(salon.toMap())
        .eq('id', salon.id)
        .select()
        .single();
    return Salon.fromMap(data);
  }

  Future<Salon> updateLogo({required Salon salon, required File file}) async {
    final url = await _storage.uploadSalonLogo(salonId: salon.id, file: file);
    return update(salon.copyWith(logoUrl: url));
  }

  /// Abonnement SaaS courant du salon (table `subscriptions`).
  ///
  /// La ligne est créée côté serveur, par `create_salon_for_signup`, dans la
  /// même transaction que le salon. La créer aussi depuis le client obligeait
  /// à laisser l'écriture ouverte à n'importe quel membre du salon, et son
  /// `catch` avalait les refus RLS : l'écran annonçait « aucun abonnement »
  /// sans que rien ne dise pourquoi.
  Future<Subscription?> fetchSubscription(String salonId) async {
    final data = await _client
        .from(SupabaseTables.subscriptions)
        .select()
        .eq('salon_id', salonId)
        .maybeSingle();
    return data == null ? null : Subscription.fromMap(data);
  }

  /// Catalogue des formules proposées, de la moins chère à la plus complète.
  Future<List<SubscriptionPlan>> fetchPlans() async {
    final data = await _client
        .from(SupabaseTables.subscriptionPlans)
        .select()
        // `order()` est descendant par défaut côté postgrest.
        .order('sort_order', ascending: true);
    return data.map(SubscriptionPlan.fromMap).toList();
  }

  /// Souscrit à [plan] pour [salonId] — écran « Comparatif & paiement ».
  ///
  /// Un salon n'a qu'un abonnement (index unique sur `salon_id`) : on remplace
  /// donc la ligne existante plutôt que d'en empiler une nouvelle.
  ///
  /// L'écriture passe par une RPC parce que la table n'est plus modifiable
  /// depuis le client : elle vérifie que l'appelant est gérant, et lit le
  /// tarif comme l'échéance côté serveur. Envoyés d'ici, ils permettaient de
  /// s'offrir la formule Pro à 0 F, ou de se donner dix ans d'avance.
  Future<Subscription> changePlan({
    required String salonId,
    required SubscriptionPlan plan,
    required BillingCycle cycle,
    required String paymentLabel,
  }) async {
    final data = await _client.rpc<Map<String, dynamic>>(
      'change_subscription_plan',
      params: {
        'p_plan_code': plan.code,
        'p_billing_cycle': cycle.value,
        'p_payment_label': paymentLabel,
      },
    );
    return Subscription.fromMap(data);
  }
}
