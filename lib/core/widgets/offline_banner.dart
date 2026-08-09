import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../services/connectivity_service.dart';
import '../services/sync_engine.dart';

/// Indicateur discret flottant en haut de l'écran affichant l'état de la synchronisation
/// et le mode hors-ligne sans masquer l'interface ni décaler les éléments.
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

    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData iconData;
    final String label;

    if (!isOnline) {
      bgColor = const Color(0xFA2C2416);
      borderColor = const Color(0xFFB97706);
      textColor = const Color(0xFFFBBF24);
      iconData = Icons.wifi_off_rounded;
      label = pendingCount > 0
          ? 'Hors-ligne • $pendingCount en attente'
          : 'Mode hors-ligne';
    } else if (isSyncing) {
      bgColor = const Color(0xFA1E2838);
      borderColor = const Color(0xFF2A5FC0);
      textColor = const Color(0xFF93C5FD);
      iconData = Icons.sync_rounded;
      label = 'Synchronisation…';
    } else {
      bgColor = const Color(0xFA162B22);
      borderColor = AppColors.accent;
      textColor = const Color(0xFF6EE7B7);
      iconData = Icons.cloud_done_rounded;
      label = '$pendingCount modification(s) en attente';
    }

    final topPadding = MediaQuery.of(context).padding.top + 6;

    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: topPadding,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: showBanner ? 1.0 : 0.0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 300),
                  offset: showBanner ? Offset.zero : const Offset(0, -0.6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: borderColor.withValues(alpha: 0.6), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(iconData, size: 13, color: textColor),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (isSyncing) ...[
                          const SizedBox(width: 7),
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(textColor),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
