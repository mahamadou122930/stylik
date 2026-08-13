import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/services/supabase_service.dart';
import 'core/utils/formatters.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait sur mobile, paysage autorisé pour l'usage tablette en salon.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Formats de dates en français (agenda, tickets, exports).
  await initializeDateFormatting(Formatters.locale);

  // Chargement des variables d'environnement (.env)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Erreur de chargement du fichier .env: $e');
  }

  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Erreur d\'initialisation Supabase: $e');
  }


  runApp(const ProviderScope(child: AtelierApp()));
}
