-- Catalogue des formules SaaS (écrans « Choisir un abonnement » et
-- « Comparatif & paiement » de la maquette `Salon App.dc.html`).
--
-- Contrairement à `subscriptions` (l'abonnement d'UN salon), cette table est
-- globale : elle décrit l'offre commerciale, identique pour tout le monde.

CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,              -- 'solo', 'pro', 'multi'
    name TEXT NOT NULL,                     -- « Pro Salon »
    tagline TEXT,                           -- « Salon avec équipe »
    summary TEXT,                           -- ligne sous le prix
    price_per_month_fcfa INTEGER NOT NULL DEFAULT 0,
    -- Codes des fonctions comparées (voir PlanCapability côté Flutter) :
    -- 'agenda', 'pos', 'team', 'reports', 'messaging'.
    capabilities TEXT[] DEFAULT '{}',
    -- Puces « Inclus dans … » reprises sur l'écran 10.4.
    features TEXT[] DEFAULT '{}',
    is_popular BOOLEAN DEFAULT false,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Solde de congés affiché sur la fiche employé (maquette 4.2).
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS leave_balance_days INTEGER DEFAULT 0;

-- L'abonnement du salon retient désormais la formule choisie et sa périodicité.
ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS plan_code TEXT,
  ADD COLUMN IF NOT EXISTS billing_cycle TEXT DEFAULT 'monthly';

-- Un seul abonnement par salon — nécessaire à l'upsert du changement de formule.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_subscriptions_salon
  ON public.subscriptions(salon_id);

ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

-- Catalogue public en lecture ; il n'est modifié que côté administration.
DROP POLICY IF EXISTS "Anyone can read subscription plans"
  ON public.subscription_plans;
CREATE POLICY "Anyone can read subscription plans"
  ON public.subscription_plans FOR SELECT TO anon, authenticated
  USING (true);

-- Offre de lancement (prix en FCFA, facturation Wave / Orange Money / carte).
INSERT INTO public.subscription_plans
  (code, name, tagline, summary, price_per_month_fcfa,
   capabilities, features, is_popular, sort_order)
VALUES
  (
    'solo', 'Solo', 'Coiffeur indépendant',
    '1 utilisateur · agenda, caisse, clients', 8000,
    ARRAY['agenda', 'pos'],
    ARRAY['1 utilisateur', 'Agenda & rendez-vous', 'Caisse et fiches clients'],
    false, 1
  ),
  (
    'pro', 'Pro Salon', 'Salon avec équipe',
    'Jusqu''à 10 employés · rapports, SMS/WhatsApp illimités', 18000,
    ARRAY['agenda', 'pos', 'team', 'reports', 'messaging'],
    ARRAY[
      'Jusqu''à 10 employés',
      'Rappels SMS & WhatsApp illimités',
      'Rapports & export comptable'
    ],
    true, 2
  ),
  (
    'multi', 'Multi-salon', 'Plusieurs établissements',
    'Salons illimités · consolidation, support prioritaire', 39000,
    ARRAY['agenda', 'pos', 'team', 'reports', 'messaging'],
    ARRAY[
      'Salons illimités',
      'Consolidation multi-établissements',
      'Support prioritaire'
    ],
    false, 3
  )
ON CONFLICT (code) DO NOTHING;
