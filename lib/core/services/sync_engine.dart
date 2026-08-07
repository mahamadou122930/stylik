import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'connectivity_service.dart';
import 'local_db_service.dart';
import 'providers.dart';

/// Moteur de synchronisation arrière-plan renforcé et tolérant aux pannes.
class SyncEngine extends StateNotifier<bool> {
  SyncEngine(this._ref, this._dbService, this._supabaseClient) : super(false) {
    _initListener();
  }

  final Ref _ref;
  final LocalDbService _dbService;
  final SupabaseClient _supabaseClient;
  StreamSubscription<bool>? _connectivitySub;

  void _initListener() {
    _connectivitySub = _ref.read(connectivityServiceProvider).onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        syncPendingItems();
      }
    });
  }

  /// Déclenche la synchronisation sécurisée de toutes les mutations en attente vers Supabase.
  Future<void> syncPendingItems() async {
    if (state) return; // Déjà en cours de synchronisation

    final isOnline = await _ref.read(connectivityServiceProvider).isOnline;
    if (!isOnline) return;

    state = true; // Indique le début de la synchro

    try {
      final items = await _dbService.getPendingSyncItems();

      for (final item in items) {
        // Si l'élément a échoué trop de fois (ex: erreur de contrainte permanente), on le retire pour débloquer la file.
        if (item.retryCount >= 5) {
          debugPrint('SyncItem ${item.id} (${item.tableName}) supprimé après 5 échecs consécutifs.');
          await _dbService.removeSyncItem(item.id);
          continue;
        }

        try {
          switch (item.action) {
            case 'INSERT':
              try {
                await _supabaseClient.from(item.tableName).insert(item.payload);
              } on PostgrestException catch (pe) {
                // Code 23505 : Violations de clé unique (l'enregistrement existe déjà)
                if (pe.code == '23505') {
                  debugPrint('Élément ${item.recordId} déjà existant dans Supabase (${item.tableName}). Tentative de mise à jour.');
                  await _supabaseClient
                      .from(item.tableName)
                      .update(item.payload)
                      .eq('id', item.recordId);
                } else {
                  rethrow;
                }
              }
              break;

            case 'UPDATE':
              await _supabaseClient
                  .from(item.tableName)
                  .update(item.payload)
                  .eq('id', item.recordId);
              break;

            case 'DELETE':
              await _supabaseClient
                  .from(item.tableName)
                  .delete()
                  .eq('id', item.recordId);
              break;
          }

          // Retirer l'élément de la file d'attente une fois synchronisé avec succès
          await _dbService.removeSyncItem(item.id);
        } on PostgrestException catch (e) {
          debugPrint('Erreur Postgres lors de la synchronisation de l\'item ${item.id} (${item.tableName}): ${e.message} [Code ${e.code}]');
          await _dbService.incrementRetry(item.id);
        } catch (e) {
          debugPrint('Erreur réseau / générale lors de la synchronisation de l\'item ${item.id}: $e');
          await _dbService.incrementRetry(item.id);
          // Arrêter la boucle pour retenter ultérieurement lors de la prochaine reconnexion
          break;
        }
      }
    } catch (globalError) {
      debugPrint('Erreur globale du SyncEngine: $globalError');
    } finally {
      state = false; // Toujours garantir le retour à false
      _ref.invalidate(pendingSyncCountProvider);
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}

/// Provider fournissant l'état "synchronisation en cours".
final syncEngineProvider = StateNotifierProvider<SyncEngine, bool>((ref) {
  return SyncEngine(
    ref,
    ref.watch(localDbServiceProvider),
    ref.watch(supabaseClientProvider),
  );
});

/// Provider fournissant le nombre d'éléments actuellement en attente de synchronisation.
final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final dbService = ref.watch(localDbServiceProvider);
  return await dbService.getPendingCount();
});
