---
name: run-stylik
description: Build, launch, drive and screenshot the Stylik Flutter salon app (L'Atelier) on Windows. Use when asked to run, start, preview, test or screenshot a screen of the app, or to check a UI change in the real running app rather than in tests.
---

# Lancer et piloter Stylik

App Flutter (mobile-first, backend Supabase). Tous les chemins ci-dessous sont
relatifs à la racine du dépôt (`<unit>/`).

**L'obstacle central : l'app démarre sur `_AuthGate`, qui exige une session
Supabase.** Sans identifiants, `flutter run` n'amène nulle part — un agent ne
peut pas saisir de mot de passe. Le driver contourne ça en générant un point
d'entrée jetable qui monte l'écran voulu directement.

On sert l'app sur `-d web-server` (pas `-d chrome`) et on la pilote avec les
outils navigateur `mcp__claude-in-chrome__*` dans le Chrome déjà ouvert.
`chromium-cli` n'est pas installé sur cette machine.

## Prérequis

Flutter et Node sont déjà installés. Vérifié :

```powershell
flutter devices    # doit lister "Windows (desktop)" et "Chrome (web)"
```

Le fichier `.env` (déclaré comme asset dans `pubspec.yaml`) doit exister à la
racine avec `SUPABASE_URL` et `SUPABASE_ANON_KEY`. Sans lui, `SupabaseService`
lève `SUPABASE_URL / SUPABASE_ANON_KEY manquants` au démarrage.

## Lancer un écran (chemin agent)

```powershell
node .claude/skills/run-stylik/driver.mjs `
  --import features/settings/presentation/plan_selection_page.dart `
  --home "const PlanSelectionPage()" `
  --port 8099
```

Lance-le **en tâche de fond** : il reste au premier plan et streame la sortie de
`flutter`. Il imprime `GENERATED <fichier>` puis `READY http://127.0.0.1:8099`
dès que le serveur répond. Attends cette ligne :

```bash
f="<fichier-de-sortie-de-la-tâche>"
until grep -qE "^READY |Failed to compile|Error:" "$f"; do sleep 3; done
```

Écran qui reçoit un argument via `pushNamed` — déclare la route ; la variable
`settings` (`RouteSettings`) est disponible dans l'expression :

```powershell
node .claude/skills/run-stylik/driver.mjs `
  --import features/settings/presentation/plan_selection_page.dart `
  --import features/settings/presentation/plan_checkout_page.dart `
  --import features/settings/domain/subscription_plan.dart `
  --home "const PlanSelectionPage()" `
  --route "PlanCheckoutPage.routeName => PlanCheckoutPage(plan: settings.arguments! as SubscriptionPlan)" `
  --port 8099
```

Puis, avec les outils navigateur : `navigate` vers `http://127.0.0.1:8099`,
**attendre ~18 s** (voir Gotchas), `screenshot`. Clique aux coordonnées lues sur
la capture — c'est le seul moyen, le DOM ne contient rien d'exploitable.

Arrêt et nettoyage — **toujours les deux** :

```powershell
node .claude/skills/run-stylik/driver.mjs --stop
node .claude/skills/run-stylik/driver.mjs --clean
```

`--help` liste toutes les options.

## Vérifier que le code compile

```powershell
flutter analyze
```

Le fichier généré `lib/run_preview.g.dart` est analysé lui aussi : une faute de
frappe dans l'expression Dart passée à `--home` ou `--route` ressort ici avant
même le lancement. Utile.

## Chemin humain

`flutter run -d chrome` (ou `-d windows`) ouvre l'app complète sur l'écran de
bienvenue, à piloter à la main avec de vrais identifiants. C'est le seul moyen
de tester ce qui dépend d'une session (voir Limites).

## Limites — ce que ce harnais ne peut PAS tester

Sans session, `currentSalonIdProvider` vaut `null`. Conséquence, vérifiée à
l'écran : `SettingsPage` s'affiche correctement mais la carte du salon retombe
sur « Mon salon / Adresse à renseigner » au lieu des vraies données.

- **Marchent avec de vraies données** : les écrans dont les tables sont ouvertes
  en lecture à `anon` par RLS. À ce jour uniquement `subscription_plans`, donc
  `PlanSelectionPage` / `PlanCheckoutPage`.
- **S'affichent mais à vide** : agenda, clients, caisse, stock, finance, staff —
  toute la mise en page est vérifiable, pas les données.
- **Intestable ici** : toute écriture. `changePlan()` sort immédiatement quand
  `salonId` est nul ; le bouton ne plante pas et ne fait rien. Ne conclus pas
  d'un clic sans erreur que l'écriture fonctionne.

## Gotchas

- **Page blanche 10–20 s après `READY`.** Le serveur répond avant que le
  bootstrap Dart n'ait peint quoi que ce soit. Ce n'est pas un échec. Enchaîne
  deux attentes de 8–10 s avant la première capture (le `wait` est plafonné à
  10 s).
- **`get_page_text` échoue toujours** (« No text content found »). Flutter web
  peint dans un `<canvas>` : aucun texte dans le DOM, et `find` / `read_page`
  sont tout aussi inutiles. **Les captures d'écran sont la seule observation
  possible** — et il faut vraiment les regarder.
- **Après un timeout CDP sur `Page.captureScreenshot`, le canvas se corrompt** :
  l'écran apparaît répété en mosaïque sur plusieurs colonnes. Ce n'est pas un
  bug de l'app. Recharge la page (`navigate` sur la même URL) et recommence.
  Vu deux fois ; refaire simplement la capture ne suffit pas.
- **Les coordonnées de clic périment vite.** Flutter réagence tout quand la
  fenêtre change d'échelle : un clic calculé sur une capture prise deux appels
  plus tôt tombe à côté, sans erreur — l'écran ne bouge simplement pas.
  Reprends une capture **juste avant** chaque clic, dans un appel séparé (dans
  un `browser_batch`, les coordonnées se réfèrent à la capture d'AVANT le
  batch). Et vérifie sur la capture suivante que le clic a bien pris.
- **Impossible d'envoyer `q` à `flutter run` lancé en tâche de fond** — pas de
  stdin. `--stop` tue le processus `dart`, ce qui libère le port. Sans ça, un
  relancement échoue en boucle sur le port occupé.
- **Le driver relance une compilation complète à chaque lancement** (~50–90 s la
  première fois, ~40 s ensuite). Il n'y a pas de hot reload par ce chemin :
  regroupe tes vérifications en une seule session plutôt que de relancer.
- **Ne committe jamais `lib/run_preview.g.dart`.** Il est régénéré à chaque
  lancement et écrasé sans avertissement.
- **La largeur du navigateur n'est pas celle d'un téléphone.** Les écrans sont
  dessinés pour 390 px ; en plein écran les cartes s'étirent et l'espacement ne
  reflète pas la maquette. Juge le contenu et la logique, pas les proportions.

## Troubleshooting

| Symptôme | Cause / correctif |
|---|---|
| `SUPABASE_URL / SUPABASE_ANON_KEY manquants` | `.env` absent à la racine. |
| Le lancement s'arrête sur un port déjà utilisé | Un `dart` traîne : `driver.mjs --stop`. |
| `Error: Undefined name 'XxxPage'` | Le `--import` correspondant manque, ou son chemin n'est pas relatif à `lib/`. |
| `--route doit contenir "=>"` | La valeur de `--route` doit être `NomDeRoute => Expression`. |
| `Cannot find module '...\lib\.claude\skills\...'` | Le shell PowerShell garde son répertoire entre les appels et a dérivé. `Set-Location <racine>` avant la commande. |
| Capture en mosaïque répétée | Canvas corrompu après timeout CDP — recharge la page. |
| Page blanche qui ne part pas | Regarde la console (`read_console_messages`) ; sinon la compilation a échoué, lis la sortie de la tâche. |
