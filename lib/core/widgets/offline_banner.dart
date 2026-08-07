import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connectivity_service.dart';
import '../services/sync_engine.dart';

/// Bannière affichée en haut de l'application indiquant l'état de la connexion
/// et les opérations en attente de synchronisation.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(isOnlineProvider);
    final isSyncing = ref.watch(syncEngineProvider);
    final pendingCountAsync = ref.watch(pendingSyncCountProvider);

    final isOnline = isOnlineAsync.valueOrNull ?? true;
    final pendingCount = pendingCountAsync.valueOrNull ?? 0;

    final showBanner = !isOnline || isSyncing || pendingCount > 0;

    return Column(
      children: [
        if (showBanner)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: !isOnline
                ? const Color(0xFFD97706) // Ambre / Orange chaud
                : isSyncing
                    ? const Color(0xFF2563EB) // Bleu synchro
                    : const Color(0xFF059669), // Vert succès
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    !isOnline
                        ? Icons.wifi_off_rounded
                        : isSyncing
                            ? Icons.sync_rounded
                            : Icons.cloud_done_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    !isOnline
                        ? pendingCount > 0
                            ? 'Mode hors-ligne • $pendingCount modification(s) en attente de synchro'
                            : 'Mode hors-ligne • Consultation du cache local'
                        : isSyncing
                            ? 'Synchronisation des données avec le serveur...'
                            : 'Données synchronisées',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isSyncing) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}
