import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../core/services/storage_service.dart';
import '../domain/salon.dart';
import '../domain/subscription.dart';

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
  Future<Salon> create({
    required String name,
    required String phone,
    required String address,
  }) async {
    final data = await _client
        .from(SupabaseTables.salons)
        .insert({'name': name, 'phone': phone, 'address': address})
        .select()
        .single();
    return Salon.fromMap(data);
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
  Future<Subscription?> fetchSubscription(String salonId) async {
    final data = await _client
        .from('subscriptions')
        .select()
        .eq('salon_id', salonId)
        .maybeSingle();
    return data == null ? null : Subscription.fromMap(data);
  }
}
