#!/usr/bin/env node
// Lance Stylik sur un serveur web local, en montant DIRECTEMENT l'écran voulu.
//
// Pourquoi ce driver existe : `flutter run` démarre l'app sur `_AuthGate`, qui
// exige une session Supabase. Un agent ne peut pas saisir de mot de passe, donc
// tout écran interne est hors de portée sans contournement. Ce script génère un
// point d'entrée jetable qui initialise dotenv + Supabase puis pousse l'écran
// demandé comme `home:`, sans authentification.
//
// Les écrans qui lisent des tables ouvertes en RLS à `anon` (subscription_plans)
// affichent de vraies données. Ceux qui dépendent de `currentSalonIdProvider`
// (agenda, clients, caisse…) le verront à `null` : leurs providers renvoient
// vide et l'écran rend son état vide. C'est une limite, pas un bug — voir
// SKILL.md § Limites.
//
// Usage : voir `node driver.mjs --help`.

import { spawn, execSync } from 'node:child_process';
import { writeFileSync, rmSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const UNIT = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const GENERATED = resolve(UNIT, 'lib/run_preview.g.dart');
const READY = 'is being served at';

function parseArgs(argv) {
  const out = { imports: [], routes: [], port: '8099', home: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => argv[++i];
    if (a === '--import') out.imports.push(next());
    else if (a === '--route') out.routes.push(next());
    else if (a === '--home') out.home = next();
    else if (a === '--port') out.port = next();
    else if (a === '--stop') out.stop = true;
    else if (a === '--clean') out.clean = true;
    else if (a === '--help' || a === '-h') out.help = true;
    else throw new Error(`Option inconnue : ${a}`);
  }
  return out;
}

const HELP = `
Usage :
  node .claude/skills/run-stylik/driver.mjs \\
    --import <chemin/sous/lib.dart> [--import ...] \\
    --home  "<expression Dart du widget>" \\
    [--route "<RouteName> => <ExpressionWidget>"] [--route ...] \\
    [--port 8099]

  node .claude/skills/run-stylik/driver.mjs --stop     # tue flutter/dart
  node .claude/skills/run-stylik/driver.mjs --clean    # supprime le fichier généré

Dans --route, la variable \`settings\` (RouteSettings) est disponible : c'est
ainsi qu'on passe un argument, ex.
  --route "PlanCheckoutPage.routeName => PlanCheckoutPage(plan: settings.arguments! as SubscriptionPlan)"

Le script reste au premier plan et streame la sortie de flutter. Lancez-le en
tâche de fond : il imprime "READY <url>" dès que le serveur répond.
`.trim();

// --- Sous-commandes -------------------------------------------------------

function stop() {
  // `flutter run` en tâche de fond n'a pas de stdin : on ne peut pas lui
  // envoyer 'q'. On tue le processus dart, ce qui libère le port.
  try {
    execSync(
      'powershell -NoProfile -Command "' +
        '$p = Get-Process -Name dart -ErrorAction SilentlyContinue; ' +
        'if ($p) { $p | Stop-Process -Force }"',
      { stdio: 'ignore' },
    );
  } catch {
    // Aucun processus à tuer : très bien.
  }
  console.log('STOPPED');
}

function clean() {
  if (existsSync(GENERATED)) rmSync(GENERATED);
  console.log('CLEANED');
}

// --- Génération du point d'entrée ----------------------------------------

function generateEntrypoint({ imports, home, routes }) {
  const importLines = imports
    .map((p) => `import '${p.replace(/\\/g, '/').replace(/^lib\//, '')}';`)
    .join('\n');

  const routeCases = routes
    .map((r) => {
      const idx = r.indexOf('=>');
      if (idx === -1) {
        throw new Error(`--route doit contenir "=>" : ${r}`);
      }
      const name = r.slice(0, idx).trim();
      const widget = r.slice(idx + 2).trim();
      return `          ${name} => MaterialPageRoute<void>(\n            builder: (_) => ${widget},\n            settings: settings,\n          ),`;
    })
    .join('\n');

  return `// FICHIER GÉNÉRÉ par .claude/skills/run-stylik/driver.mjs — ne pas committer.
// Point d'entrée jetable : monte un écran sans passer par l'authentification.
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/formatters.dart';
${importLines}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(Formatters.locale);
  // .env est déclaré comme asset dans pubspec.yaml ; sans lui, SupabaseService
  // lève "SUPABASE_URL / SUPABASE_ANON_KEY manquants".
  await dotenv.load(fileName: '.env');
  await SupabaseService.initialize();

  runApp(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: ${home},
        onGenerateRoute: (settings) => switch (settings.name) {
${routeCases}
          _ => null,
        },
      ),
    ),
  );
}
`;
}

// --- Lancement ------------------------------------------------------------

function run(opts) {
  if (!opts.home) throw new Error('--home est obligatoire (expression Dart).');

  writeFileSync(GENERATED, generateEntrypoint(opts), 'utf8');
  console.log(`GENERATED ${GENERATED}`);

  const url = `http://127.0.0.1:${opts.port}`;
  const child = spawn(
    'flutter',
    [
      'run',
      '-d',
      'web-server',
      '--web-port',
      opts.port,
      '--web-hostname',
      '127.0.0.1',
      '-t',
      'lib/run_preview.g.dart',
    ],
    { cwd: UNIT, shell: true },
  );

  let announced = false;
  const scan = (buf) => {
    const text = buf.toString();
    process.stdout.write(text);
    if (!announced && text.includes(READY)) {
      announced = true;
      // Le serveur répond, mais le bootstrap Dart côté navigateur prend encore
      // ~10-20 s : la page est blanche pendant ce temps.
      console.log(`\nREADY ${url}`);
    }
  };

  child.stdout.on('data', scan);
  child.stderr.on('data', scan);
  child.on('exit', (code) => process.exit(code ?? 0));
}

// --- Entrée ---------------------------------------------------------------

const opts = parseArgs(process.argv.slice(2));
if (opts.help) console.log(HELP);
else if (opts.stop) stop();
else if (opts.clean) clean();
else run(opts);
