-- ==========================================================================
-- Migration : le salon passe en lecture seule quand l'abonnement est éteint
-- ==========================================================================
-- Jusqu'ici, la fin de l'essai n'affichait qu'un bandeau sur l'accueil du
-- gérant. Caisse, agenda et stock continuaient de fonctionner pour tout le
-- monde, indéfiniment. `Subscription.isActive` était calculé côté Dart et
-- n'avait aucun lecteur.
--
-- Le blocage vit désormais ici. Une vérification côté application seule se
-- contourne en rejouant les requêtes : la clé anonyme est lisible dans l'APK,
-- et PostgREST accepte tout ce que la base accepte.
--
-- Lecture seule, et non fermeture : le salon consulte son historique, ses
-- clients et ses chiffres, et peut les exporter. Il ne peut plus rien créer.

-- --------------------------------------------------------------------------
-- 1. L'abonnement du salon est-il vivant ?
-- --------------------------------------------------------------------------
-- Deux choix délibérés, tous deux dans le sens de ne jamais enfermer dehors
-- un salon qui paie :
--
--   * une formule 'active' reste active même passé `next_charge_at`. Aucun
--     webhook de paiement ne vient encore repousser cette date : la respecter
--     couperait tous les salons abonnés un mois après leur souscription ;
--
--   * un salon sans ligne d'abonnement est considéré actif. La ligne est
--     créée à l'inscription et rétro-appliquée, mais une donnée manquante ne
--     doit pas bloquer une caisse un samedi après-midi.
--
-- Seul l'essai arrivé à échéance, et les statuts 'canceled' / 'past_due',
-- font basculer le salon en lecture seule. La règle est la même que celle
-- de `Subscription.isActive` côté Dart, et c'est ici qu'elle fait foi.
CREATE OR REPLACE FUNCTION public.salon_subscription_is_active(p_salon_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (
      SELECT s.status = 'active'
          OR (s.status = 'trialing'
              AND (s.next_charge_at IS NULL OR s.next_charge_at > now()))
        FROM public.subscriptions s
       WHERE s.salon_id = p_salon_id
       LIMIT 1
    ),
    true
  );
$$;

-- Le même test pour le salon de l'appelant.
CREATE OR REPLACE FUNCTION public.auth_salon_is_active()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.salon_subscription_is_active(public.get_auth_salon_id());
$$;

GRANT EXECUTE ON FUNCTION public.salon_subscription_is_active(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.auth_salon_is_active() TO authenticated;

-- --------------------------------------------------------------------------
-- 2. Le refus, posé sur les tables plutôt que dans les policies
-- --------------------------------------------------------------------------
-- Une policy RESTRICTIVE aurait suffi pour les écritures directes de
-- PostgREST, mais pas pour `adjust_stock`, `add_loyalty_points`,
-- `refund_transaction` ou `record_payout` : ces fonctions sont SECURITY
-- DEFINER et passent au travers des policies. Un trigger, lui, s'applique
-- quel que soit le chemin — et le message qu'il lève est lisible, là où une
-- policy ne rend qu'un 42501 muet.
--
-- Deux portes volontairement laissées ouvertes :
--
--   * `auth.uid()` nul : requête service_role, migration, console
--     d'administration. C'est par là que passera `admintools` pour
--     réactiver un salon ;
--   * `salons`, `profiles`, `subscriptions` : sans elles, un gérant dont le
--     salon est éteint ne pourrait plus se connecter ni atteindre l'écran
--     qui lui permet justement de payer.
CREATE OR REPLACE FUNCTION public.enforce_active_subscription()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_salon_id UUID;
BEGIN
  -- Service role, migrations, tâches planifiées : pas d'utilisateur, pas de
  -- salon à vérifier. L'administration doit pouvoir réparer un salon éteint.
  IF auth.uid() IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- NEW n'existe pas sur un DELETE, OLD pas sur un INSERT : les confondre
  -- lèverait une erreur de la fonction elle-même plutôt que le refus voulu.
  IF TG_OP = 'DELETE' THEN
    v_salon_id := (to_jsonb(OLD) ->> 'salon_id')::UUID;
  ELSE
    v_salon_id := (to_jsonb(NEW) ->> 'salon_id')::UUID;
  END IF;

  -- Une table sans colonne `salon_id` se rattache au salon de l'appelant.
  v_salon_id := COALESCE(v_salon_id, public.get_auth_salon_id());

  IF v_salon_id IS NULL OR public.salon_subscription_is_active(v_salon_id) THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Ce message-ci est celui que verra le gérant : `ErrorMessages.humanize`
  -- laisse passer tel quel le texte d'une exception levée en français.
  RAISE EXCEPTION
    'Votre abonnement est arrivé à échéance. Vos données restent consultables et exportables, mais aucune nouvelle saisie n''est possible tant qu''une formule n''est pas activée.'
    USING ERRCODE = 'insufficient_privilege';

  -- Inatteignable — RAISE interrompt toujours. Présent pour que PL/pgSQL ne
  -- puisse pas sortir de la procédure sans valeur de retour.
  RETURN NULL;
END;
$$;

DO $$
DECLARE
  v_table TEXT;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'clients',
    'services',
    'appointments',
    'walk_in_queue',
    'products',
    'stock_movements',
    'transactions',
    'time_off',
    'expenses',
    'loyalty_rewards',
    'promotions',
    'reminder_rules',
    'campaigns',
    'payout_requests',
    'invoice_counters'
  ]
  LOOP
    IF to_regclass('public.' || v_table) IS NULL THEN
      CONTINUE;
    END IF;

    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_subscription_required ON public.%I',
      v_table
    );

    -- BEFORE, pour refuser avant d'écrire ; FOR EACH ROW, parce que le
    -- salon se lit sur la ligne.
    EXECUTE format(
      'CREATE TRIGGER trg_subscription_required'
      ' BEFORE INSERT OR UPDATE OR DELETE ON public.%I'
      ' FOR EACH ROW EXECUTE FUNCTION public.enforce_active_subscription()',
      v_table
    );
  END LOOP;
END;
$$;
