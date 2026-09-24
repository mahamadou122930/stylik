-- ==========================================================================
-- Migration : passerelle d'administration (console admintools → Stylik)
-- ==========================================================================
-- La console d'administration gère les abonnements de Dukani Commerce en
-- parlant à projectest. Les salons Stylik vivent ici, dans Supabase : c'est
-- et ça reste la source de vérité. projectest les lit et les active à travers
-- quatre fonctions `admin_*`, sans jamais recevoir la clé `service_role`.
--
--   admintools ──x-internal-key──▶ projectest ──x-stylik-key──▶ admin_*()
--
-- Pourquoi pas `service_role` : elle ouvre toute la base, RLS comprise. Posée
-- dans la configuration de projectest — un serveur exposé à Internet — sa
-- fuite livrerait les clients, les ventes et les comptes de tous les salons.
-- Une clé dédiée n'ouvre que ces quatre fonctions.
--
-- Cette migration ferme aussi l'activation gratuite : `change_subscription_
-- plan` laissait un gérant passer en formule payée sans rien payer. Il
-- dépose désormais une demande ; l'opérateur l'active depuis la console une
-- fois l'argent reçu.

-- --------------------------------------------------------------------------
-- 1. La clé de la console, hors de portée de l'API
-- --------------------------------------------------------------------------
-- Un schéma que PostgREST n'expose pas : aucune requête HTTP ne l'atteint,
-- quelle que soit la clé présentée. Seule l'empreinte y est gardée — une
-- sauvegarde qui fuit ne livre pas la clé.
CREATE SCHEMA IF NOT EXISTS admin_bridge;
REVOKE ALL ON SCHEMA admin_bridge FROM PUBLIC;

CREATE TABLE IF NOT EXISTS admin_bridge.console_key (
  id         SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  key_hash   TEXT NOT NULL,
  rotated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- À exécuter une fois depuis l'éditeur SQL de Supabase, avec la même valeur
-- que `STYLIK_CONSOLE_KEY` côté projectest :
--
--   SELECT admin_bridge.set_console_key('<au moins 32 caractères aléatoires>');
--
-- La rejouer avec une autre valeur fait tourner la clé.
CREATE OR REPLACE FUNCTION admin_bridge.set_console_key(p_key TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = admin_bridge, public
AS $$
BEGIN
  IF p_key IS NULL OR length(p_key) < 32 THEN
    RAISE EXCEPTION 'La clé de console doit compter au moins 32 caractères';
  END IF;

  INSERT INTO admin_bridge.console_key (id, key_hash)
  VALUES (1, encode(extensions.digest(p_key, 'sha256'), 'hex'))
  ON CONFLICT (id) DO UPDATE
    SET key_hash = EXCLUDED.key_hash, rotated_at = now();
END;
$$;

REVOKE ALL ON FUNCTION admin_bridge.set_console_key(TEXT) FROM PUBLIC;

-- Refuse tout appel qui ne présente pas la clé de la console.
--
-- La clé voyage dans un en-tête, jamais dans le corps ni l'URL : les journaux
-- de l'API enregistrent les chemins, pas les en-têtes. Sans clé configurée,
-- tout est refusé — une clé absente est une erreur d'exploitation, pas une
-- autorisation.
CREATE OR REPLACE FUNCTION admin_bridge.require_console()
RETURNS VOID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = admin_bridge, public
AS $$
DECLARE
  v_expected TEXT;
  v_provided TEXT;
BEGIN
  SELECT key_hash INTO v_expected FROM admin_bridge.console_key WHERE id = 1;

  v_provided := nullif(current_setting('request.headers', true), '')::json
                  ->> 'x-stylik-key';

  IF v_expected IS NULL
     OR v_provided IS NULL
     OR encode(extensions.digest(v_provided, 'sha256'), 'hex') <> v_expected
  THEN
    RAISE EXCEPTION 'Accès console refusé'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION admin_bridge.require_console() FROM PUBLIC;

-- --------------------------------------------------------------------------
-- 2. Ce que la console doit pouvoir porter sur un abonnement
-- --------------------------------------------------------------------------
-- La suspension est un interrupteur à part, comme `Tenant.active` chez
-- projectest : lever une suspension rend au salon l'état qu'il avait, au
-- lieu de devoir le reconstituer.
ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS suspended BOOLEAN NOT NULL DEFAULT false;

-- Remise annuelle par formule, reprise du catalogue de la console.
ALTER TABLE public.subscription_plans
  ADD COLUMN IF NOT EXISTS yearly_discount NUMERIC NOT NULL DEFAULT 0.20;

-- --------------------------------------------------------------------------
-- 3. La règle d'accès, alignée sur celle de projectest
-- --------------------------------------------------------------------------
-- `20260923_read_only_when_expired` laissait une formule 'active' ouverte
-- sans limite, faute de rien pour repousser son échéance. Ce mécanisme
-- existe désormais : c'est l'opérateur, depuis la console, à chaque
-- règlement. Une période payée expire donc à son terme, comme chez Dukani.
--
-- Restent ouverts, par prudence : un salon sans ligne d'abonnement, et une
-- échéance absente. Une donnée manquante ne ferme pas une caisse.
CREATE OR REPLACE FUNCTION public.salon_subscription_is_active(p_salon_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (
      SELECT NOT s.suspended
         AND s.status IN ('active', 'trialing')
         AND (s.next_charge_at IS NULL OR s.next_charge_at > now())
        FROM public.subscriptions s
       WHERE s.salon_id = p_salon_id
       LIMIT 1
    ),
    true
  );
$$;

-- --------------------------------------------------------------------------
-- 4. Les demandes d'activation
-- --------------------------------------------------------------------------
-- Ce que dépose un gérant qui veut s'abonner. Le montant est calculé ici, à
-- partir du catalogue : un montant venu de l'application serait celui que
-- l'application voudrait.
CREATE TABLE IF NOT EXISTS public.subscription_requests (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id      UUID NOT NULL REFERENCES public.salons(id) ON DELETE CASCADE,
  plan_code     TEXT NOT NULL,
  plan_name     TEXT NOT NULL,
  billing_cycle TEXT NOT NULL DEFAULT 'monthly'
                CHECK (billing_cycle IN ('monthly', 'annual')),
  months        INTEGER NOT NULL CHECK (months > 0),
  amount_fcfa   INTEGER NOT NULL CHECK (amount_fcfa >= 0),
  method        TEXT,
  -- Rappelée par le gérant dans son envoi Orange Money / Wave : c'est elle
  -- qui permet à l'opérateur de rapprocher un paiement reçu d'une demande.
  reference     TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'approved', 'rejected', 'canceled')),
  requested_by  UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at   TIMESTAMPTZ
);

-- Une seule demande ouverte par salon : la console n'a pas à deviner laquelle
-- de trois demandes contradictoires correspond à l'argent reçu.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_pending_request_per_salon
  ON public.subscription_requests (salon_id) WHERE status = 'pending';

ALTER TABLE public.subscription_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Salon members read their requests"
  ON public.subscription_requests;
CREATE POLICY "Salon members read their requests"
  ON public.subscription_requests
  FOR SELECT TO authenticated
  USING (salon_id = public.get_auth_salon_id());

-- Pas de trigger de lecture seule sur cette table, et c'est voulu : un salon
-- éteint doit justement pouvoir demander sa réactivation.

-- Comptes sur lesquels envoyer le paiement. Lisibles de tous : ce sont les
-- numéros que le gérant doit connaître pour payer. Renseignés depuis
-- l'éditeur SQL en attendant que la console les gère.
CREATE TABLE IF NOT EXISTS public.billing_payment_accounts (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  method         TEXT NOT NULL,   -- « Orange Money », « Wave », « Moov Money »
  account_number TEXT NOT NULL,
  holder_name    TEXT,
  sort_order     INTEGER NOT NULL DEFAULT 0,
  active         BOOLEAN NOT NULL DEFAULT true
);

ALTER TABLE public.billing_payment_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone reads active payment accounts"
  ON public.billing_payment_accounts;
CREATE POLICY "Anyone reads active payment accounts"
  ON public.billing_payment_accounts
  FOR SELECT TO anon, authenticated
  USING (active);

-- Dépôt d'une demande, par le gérant seul.
CREATE OR REPLACE FUNCTION public.request_subscription_activation(
  p_plan_code     TEXT,
  p_billing_cycle TEXT DEFAULT 'monthly',
  p_method        TEXT DEFAULT NULL
)
RETURNS public.subscription_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_salon_id UUID := public.get_auth_salon_id();
  v_plan     public.subscription_plans;
  v_cycle    TEXT;
  v_months   INTEGER;
  v_amount   INTEGER;
  v_row      public.subscription_requests;
BEGIN
  IF v_salon_id IS NULL THEN
    RAISE EXCEPTION 'Profil introuvable pour ce compte'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- S'abonner engage la caisse du salon : seul le gérant le fait.
  IF NOT public.auth_is_manager() THEN
    RAISE EXCEPTION 'Seul le gérant peut demander une activation'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT * INTO v_plan FROM public.subscription_plans
   WHERE code = p_plan_code LIMIT 1;
  IF v_plan.code IS NULL THEN
    RAISE EXCEPTION 'Formule inconnue' USING ERRCODE = 'check_violation';
  END IF;

  v_cycle  := CASE WHEN p_billing_cycle = 'annual' THEN 'annual' ELSE 'monthly' END;
  v_months := CASE WHEN v_cycle = 'annual' THEN 12 ELSE 1 END;
  -- Même calcul que la console (`toFormula`) : douze mois, remise déduite.
  v_amount := CASE
    WHEN v_cycle = 'annual'
      THEN round(v_plan.price_per_month_fcfa * 12 * (1 - v_plan.yearly_discount))
    ELSE v_plan.price_per_month_fcfa
  END;

  -- La demande précédente, si elle court encore, est remplacée : le gérant
  -- a changé d'avis avant de payer.
  UPDATE public.subscription_requests
     SET status = 'canceled', resolved_at = now()
   WHERE salon_id = v_salon_id AND status = 'pending';

  INSERT INTO public.subscription_requests (
    salon_id, plan_code, plan_name, billing_cycle, months, amount_fcfa,
    method, reference, requested_by
  )
  VALUES (
    v_salon_id, v_plan.code, v_plan.name, v_cycle, v_months, v_amount,
    nullif(btrim(coalesce(p_method, '')), ''),
    -- Courte, sans caractère ambigu à l'oral : elle est dictée ou recopiée.
    'STY-' || upper(substr(translate(
      encode(extensions.gen_random_bytes(6), 'base64'), '+/=0O1IL', ''), 1, 6)),
    (SELECT id FROM public.profiles WHERE user_id = auth.uid() LIMIT 1)
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.request_subscription_activation(TEXT, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.request_subscription_activation(TEXT, TEXT, TEXT)
  TO authenticated;

-- L'activation gratuite est retirée. Une application restée à l'ancienne
-- version recevra « fonction introuvable » au lieu d'un mois offert.
DROP FUNCTION IF EXISTS public.change_subscription_plan(TEXT, TEXT, TEXT);

-- --------------------------------------------------------------------------
-- 5. La vue d'un salon, telle que la console la lit
-- --------------------------------------------------------------------------
-- L'état est tranché ici, par la même règle que celle qui bloque les
-- écritures : la console affiche ce que la base applique, pas une
-- reconstitution qui pourrait en diverger.
CREATE OR REPLACE FUNCTION admin_bridge.salon_overview(p_salon_id UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'id',          s.id,
    'name',        s.name,
    'phone',       nullif(s.phone, ''),
    'email',       s.email,
    'createdAt',   s.created_at,
    'memberCount', (SELECT count(*) FROM public.profiles p
                     WHERE p.salon_id = s.id AND coalesce(p.is_active, true)),
    'manager', (
      SELECT jsonb_build_object(
               'name',  p.full_name,
               'phone', p.phone,
               'email', coalesce(p.email, u.email))
        FROM public.profiles p
        LEFT JOIN auth.users u ON u.id = p.user_id
       WHERE p.salon_id = s.id AND p.role IN ('gerant', 'owner', 'manager')
       ORDER BY p.created_at
       LIMIT 1
    ),
    'subscription', CASE WHEN sub.id IS NULL THEN NULL ELSE jsonb_build_object(
      'planCode',      sub.plan_code,
      'planName',      sub.plan_name,
      'monthlyPrice',  sub.price_per_month_fcfa,
      'billingCycle',  sub.billing_cycle,
      'status',        sub.status,
      'periodEnd',     sub.next_charge_at,
      'suspended',     sub.suspended
    ) END,
    'state', CASE
      WHEN sub.id IS NULL                  THEN 'trialing'
      WHEN sub.suspended                   THEN 'suspended'
      WHEN sub.status IN ('active', 'trialing')
           AND (sub.next_charge_at IS NULL OR sub.next_charge_at > now())
                                           THEN sub.status
      ELSE 'expired'
    END,
    'canWrite', public.salon_subscription_is_active(s.id),
    -- Un salon suspendu garde la lecture : Stylik n'a pas de fermeture
    -- totale. L'annoncer autrement serait mentir à l'opérateur.
    'canRead', true,
    -- Arrondi au supérieur, comme `daysUntil` chez projectest : à douze
    -- heures de la fin, il reste « 1 jour », pas « 0 ».
    'daysLeft', CASE
      WHEN sub.next_charge_at IS NOT NULL AND sub.next_charge_at > now()
       AND NOT sub.suspended AND sub.status IN ('active', 'trialing')
      THEN ceil(extract(epoch FROM sub.next_charge_at - now()) / 86400)::int
    END,
    -- Dernière trace d'usage réelle : connexion ou vente, la plus récente.
    -- La connexion seule mentirait — une session reste ouverte des semaines.
    'lastSeenAt', (
      SELECT greatest(
        (SELECT max(u.last_sign_in_at) FROM public.profiles p
           JOIN auth.users u ON u.id = p.user_id WHERE p.salon_id = s.id),
        (SELECT max(t.created_at) FROM public.transactions t
          WHERE t.salon_id = s.id)
      )
    ),
    'pendingRequest', (
      SELECT jsonb_build_object(
               'id',        r.id,
               'planCode',  r.plan_code,
               'planName',  r.plan_name,
               'months',    r.months,
               'amount',    r.amount_fcfa,
               'method',    r.method,
               'reference', r.reference,
               'createdAt', r.created_at)
        FROM public.subscription_requests r
       WHERE r.salon_id = s.id AND r.status = 'pending'
       LIMIT 1
    )
  )
  FROM public.salons s
  LEFT JOIN public.subscriptions sub ON sub.salon_id = s.id
  WHERE s.id = p_salon_id;
$$;

REVOKE ALL ON FUNCTION admin_bridge.salon_overview(UUID) FROM PUBLIC;

-- --------------------------------------------------------------------------
-- 6. Les quatre portes de la console
-- --------------------------------------------------------------------------
-- Appelées avec la clé anonyme et l'en-tête `x-stylik-key`. Chacune commence
-- par `require_console()` ; sans la clé, aucune ne rend quoi que ce soit.

-- Tous les salons, du plus récent au plus ancien.
CREATE OR REPLACE FUNCTION public.admin_list_salons()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM admin_bridge.require_console();
  RETURN coalesce(
    (SELECT jsonb_agg(admin_bridge.salon_overview(s.id) ORDER BY s.created_at DESC)
       FROM public.salons s),
    '[]'::jsonb
  );
END;
$$;

-- Ouvre ou prolonge un abonnement payé.
--
-- Même règle d'empilement que `extendPeriod` chez projectest : une période
-- payée qui court encore est prolongée depuis sa fin, une période échue — ou
-- un essai — repart d'aujourd'hui. Le temps d'essai restant n'est pas
-- reporté, comme chez Dukani.
CREATE OR REPLACE FUNCTION public.admin_activate_salon(
  p_salon_id  UUID,
  p_plan_code TEXT,
  p_months    INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plan public.subscription_plans;
  v_sub  public.subscriptions;
  v_base TIMESTAMPTZ;
BEGIN
  PERFORM admin_bridge.require_console();

  IF p_months IS NULL OR p_months < 1 OR p_months > 36 THEN
    RAISE EXCEPTION 'Durée invalide (1 à 36 mois)'
      USING ERRCODE = 'check_violation';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.salons WHERE id = p_salon_id) THEN
    RAISE EXCEPTION 'Salon introuvable' USING ERRCODE = 'no_data_found';
  END IF;

  SELECT * INTO v_plan FROM public.subscription_plans
   WHERE code = p_plan_code LIMIT 1;
  IF v_plan.code IS NULL THEN
    RAISE EXCEPTION 'Formule inconnue de Stylik : synchronisez le catalogue'
      USING ERRCODE = 'check_violation';
  END IF;

  SELECT * INTO v_sub FROM public.subscriptions WHERE salon_id = p_salon_id;

  v_base := CASE
    WHEN v_sub.status = 'active' AND v_sub.next_charge_at > now()
      THEN v_sub.next_charge_at
    ELSE now()
  END;

  INSERT INTO public.subscriptions (
    salon_id, plan_code, plan_name, price_per_month_fcfa, billing_cycle,
    status, features, payment_label, next_charge_at, suspended
  )
  VALUES (
    p_salon_id, v_plan.code, v_plan.name, v_plan.price_per_month_fcfa,
    CASE WHEN p_months >= 12 THEN 'annual' ELSE 'monthly' END,
    'active', v_plan.features, 'Activé par la console',
    v_base + make_interval(months => p_months), false
  )
  ON CONFLICT (salon_id) DO UPDATE SET
    plan_code            = EXCLUDED.plan_code,
    plan_name            = EXCLUDED.plan_name,
    price_per_month_fcfa = EXCLUDED.price_per_month_fcfa,
    billing_cycle        = EXCLUDED.billing_cycle,
    status               = 'active',
    features             = EXCLUDED.features,
    payment_label        = EXCLUDED.payment_label,
    next_charge_at       = EXCLUDED.next_charge_at,
    -- Payer, c'est redevenir en règle : comme chez projectest, un
    -- règlement lève la suspension.
    suspended            = false;

  -- La demande en attente est honorée par cette activation.
  UPDATE public.subscription_requests
     SET status = 'approved', resolved_at = now()
   WHERE salon_id = p_salon_id AND status = 'pending';

  RETURN admin_bridge.salon_overview(p_salon_id);
END;
$$;

-- Suspend ou rétablit un salon, sans toucher à sa période.
CREATE OR REPLACE FUNCTION public.admin_set_salon_suspended(
  p_salon_id  UUID,
  p_suspended BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM admin_bridge.require_console();

  UPDATE public.subscriptions
     SET suspended = coalesce(p_suspended, false)
   WHERE salon_id = p_salon_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Abonnement introuvable pour ce salon'
      USING ERRCODE = 'no_data_found';
  END IF;

  RETURN admin_bridge.salon_overview(p_salon_id);
END;
$$;

-- Remplace le catalogue par celui de la console.
--
-- La console fait foi pour les prix : c'est là que l'opérateur les modifie.
-- L'application continue de lire sa table locale — elle marche hors ligne,
-- et l'essai offert à l'inscription y trouve sa formule — mais cette table
-- n'est plus qu'un reflet, réécrit à chaque changement dans la console.
--
-- `capabilities` n'existe pas côté console : celles d'une formule déjà
-- connue sont conservées, une formule nouvelle reçoit l'agenda et la caisse.
-- `tagline` est conservée de la même façon.
CREATE OR REPLACE FUNCTION public.admin_sync_plans(p_plans JSONB)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plan  JSONB;
  v_codes TEXT[] := '{}';
BEGIN
  PERFORM admin_bridge.require_console();

  IF p_plans IS NULL OR jsonb_typeof(p_plans) <> 'array'
     OR jsonb_array_length(p_plans) = 0 THEN
    -- Un catalogue vide effacerait toutes les formules de l'application :
    -- c'est plus probablement une panne en amont qu'une décision.
    RAISE EXCEPTION 'Catalogue vide ou invalide : rien n''a été modifié'
      USING ERRCODE = 'check_violation';
  END IF;

  FOR v_plan IN SELECT * FROM jsonb_array_elements(p_plans) LOOP
    IF coalesce(v_plan ->> 'code', '') = '' THEN
      RAISE EXCEPTION 'Formule sans code : rien n''a été modifié'
        USING ERRCODE = 'check_violation';
    END IF;

    INSERT INTO public.subscription_plans (
      code, name, summary, price_per_month_fcfa, features,
      is_popular, sort_order, yearly_discount, capabilities
    )
    VALUES (
      v_plan ->> 'code',
      coalesce(v_plan ->> 'name', v_plan ->> 'code'),
      nullif(v_plan ->> 'summary', ''),
      coalesce((v_plan ->> 'monthlyPrice')::int, 0),
      coalesce(ARRAY(SELECT jsonb_array_elements_text(v_plan -> 'features')), '{}'),
      coalesce(v_plan ->> 'badge', '') <> '',
      coalesce((v_plan ->> 'sortOrder')::int, 0),
      coalesce((v_plan ->> 'yearlyDiscount')::numeric, 0.20),
      ARRAY['agenda', 'pos']
    )
    ON CONFLICT (code) DO UPDATE SET
      name                 = EXCLUDED.name,
      summary              = EXCLUDED.summary,
      price_per_month_fcfa = EXCLUDED.price_per_month_fcfa,
      features             = EXCLUDED.features,
      is_popular           = EXCLUDED.is_popular,
      sort_order           = EXCLUDED.sort_order,
      yearly_discount      = EXCLUDED.yearly_discount;
      -- `capabilities` et `tagline` : conservées, voir plus haut.

    v_codes := v_codes || (v_plan ->> 'code');
  END LOOP;

  -- Une formule retirée de la console n'est plus proposée. Les abonnements
  -- qui la portent gardent leur copie du nom et du prix.
  DELETE FROM public.subscription_plans WHERE NOT (code = ANY (v_codes));

  RETURN array_length(v_codes, 1);
END;
$$;

-- La clé anonyme suffit pour atteindre ces fonctions ; c'est la clé de
-- console, vérifiée à l'intérieur, qui décide.
--
-- Supabase accorde par défaut EXECUTE sur toute fonction de `public` à
-- `anon` et `authenticated`, explicitement : un REVOKE FROM PUBLIC ne les
-- retire pas. On les nomme donc, puis on rend à chacun ce qui lui revient.
REVOKE ALL ON FUNCTION public.admin_list_salons()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_activate_salon(UUID, TEXT, INTEGER)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_set_salon_suspended(UUID, BOOLEAN)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_sync_plans(JSONB)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_salons() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_activate_salon(UUID, TEXT, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_set_salon_suspended(UUID, BOOLEAN) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_sync_plans(JSONB) TO anon;

-- --------------------------------------------------------------------------
-- 7. Le refus dit la vraie raison
-- --------------------------------------------------------------------------
-- La suspension réutilise le trigger de lecture seule, mais pas son message :
-- « votre abonnement est arrivé à échéance » enverrait un gérant suspendu
-- chercher un retard de paiement qui n'existe pas.
CREATE OR REPLACE FUNCTION public.enforce_active_subscription()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_salon_id  UUID;
  v_suspended BOOLEAN;
BEGIN
  -- Service role, migrations, console : pas d'utilisateur, pas de blocage.
  IF auth.uid() IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  IF TG_OP = 'DELETE' THEN
    v_salon_id := (to_jsonb(OLD) ->> 'salon_id')::UUID;
  ELSE
    v_salon_id := (to_jsonb(NEW) ->> 'salon_id')::UUID;
  END IF;
  v_salon_id := COALESCE(v_salon_id, public.get_auth_salon_id());

  IF v_salon_id IS NULL OR public.salon_subscription_is_active(v_salon_id) THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT suspended INTO v_suspended
    FROM public.subscriptions WHERE salon_id = v_salon_id;

  IF v_suspended THEN
    RAISE EXCEPTION
      'Ce salon est suspendu. Vos données restent consultables, mais aucune nouvelle saisie n''est possible. Contactez le support Stylik.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  RAISE EXCEPTION
    'Votre abonnement est arrivé à échéance. Vos données restent consultables et exportables, mais aucune nouvelle saisie n''est possible tant qu''une formule n''est pas activée.'
    USING ERRCODE = 'insufficient_privilege';

  RETURN NULL;
END;
$$;
