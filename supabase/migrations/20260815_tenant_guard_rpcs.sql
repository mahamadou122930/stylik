-- Cloisonnement par salon des fonctions `SECURITY DEFINER`.
--
-- L'isolation multi-tenant repose sur les politiques « Tenant isolation for X »,
-- qui comparent `salon_id` à `get_auth_salon_id()`. Mais une fonction déclarée
-- `SECURITY DEFINER` s'exécute avec les droits de son propriétaire : la RLS ne
-- s'y applique pas. Sept d'entre elles acceptaient un identifiant en paramètre
-- sans jamais vérifier qu'il appartient à l'appelant.
--
-- La clé anonyme étant lisible dans l'APK, il suffisait d'un compte sur
-- n'importe quel salon et de l'identifiant d'un autre pour lire son chiffre
-- d'affaires, ses commissions, ses statistiques — voire modifier son stock.
--
-- Deux traitements selon le besoin réel de chaque fonction.

-- ==========================================================================
-- 1. Rapports de lecture : la RLS suffit, `DEFINER` n'apportait rien
-- ==========================================================================

-- Ces trois-là ne lisent que des tables déjà couvertes par l'isolation tenant
-- et ne servent que des rôles autorisés à les lire en direct. Repasser en
-- `INVOKER` les soumet à la RLS : un identifiant de salon étranger ne renvoie
-- plus aucune ligne, sans qu'aucune garde explicite soit à maintenir.
ALTER FUNCTION public.finance_summary(UUID, TIMESTAMPTZ, TIMESTAMPTZ)
  SECURITY INVOKER;

ALTER FUNCTION public.service_performance(UUID, TIMESTAMPTZ, TIMESTAMPTZ)
  SECURITY INVOKER;

ALTER FUNCTION public.reminder_stats(UUID)
  SECURITY INVOKER;

-- ==========================================================================
-- 2. Fonctions qui doivent rester `DEFINER` : garde explicite
-- ==========================================================================

-- `verify_pin` lit `pin_code`, colonne délibérément absente de
-- `Profile.columns` pour qu'aucun membre ne puisse lire le code caisse de ses
-- collègues. Elle doit donc contourner la RLS — mais sans garde, elle
-- autorisait à tester des PIN sur le personnel de n'importe quel salon, sans
-- limite de tentatives.
CREATE OR REPLACE FUNCTION public.verify_pin(
  p_profile_id UUID,
  p_pin TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stored_pin TEXT;
  v_salon_id   UUID;
BEGIN
  SELECT pin_code, salon_id INTO v_stored_pin, v_salon_id
  FROM public.profiles
  WHERE id = p_profile_id;

  -- Même réponse qu'un PIN faux : distinguer « pas votre salon » de « mauvais
  -- code » renseignerait sur l'existence de la fiche.
  IF v_salon_id IS DISTINCT FROM public.get_auth_salon_id() THEN
    RETURN FALSE;
  END IF;

  IF v_stored_pin IS NULL OR v_stored_pin = '' THEN
    RETURN FALSE;
  END IF;

  -- Un hash pgcrypto commence toujours par '$' ($2a$, $2b$, $6$…). Appeler
  -- crypt() sur un PIN en clair lèverait « invalid salt » au lieu de refuser.
  IF v_stored_pin LIKE '$%' THEN
    RETURN v_stored_pin = crypt(p_pin, v_stored_pin);
  END IF;

  RETURN v_stored_pin = p_pin;
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_pin(UUID, TEXT) TO authenticated;

-- `adjust_stock` écrit : c'était la faille la plus grave, puisqu'elle
-- permettait de modifier l'inventaire d'un salon tiers et d'y insérer des
-- mouvements de stock.
--
-- Le corps corrigé — y compris l'insertion, qui visait des colonnes
-- inexistantes — est dans `20260815_fix_adjust_stock.sql`, appliquée après
-- celle-ci. La garde de salon y est reprise à l'identique.

-- `stylist_stats` déduit le salon de la fiche visée, ce qui la rendait
-- utilisable sur n'importe quel employé de n'importe quel salon : son CA et
-- sa commission du mois étaient lisibles avec le seul identifiant de profil.
CREATE OR REPLACE FUNCTION public.stylist_stats(
  p_profile_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_salon_id UUID;
  v_revenue BIGINT := 0;
  v_count INT := 0;
  v_rate NUMERIC := 0;
  v_empty JSONB := jsonb_build_object(
    'revenue_fcfa', 0, 'service_count', 0, 'commission_fcfa', 0
  );
BEGIN
  SELECT salon_id, COALESCE(commission_rate, 0) INTO v_salon_id, v_rate
  FROM public.profiles WHERE id = p_profile_id;

  IF v_salon_id IS NULL THEN
    RETURN v_empty;
  END IF;

  IF v_salon_id IS DISTINCT FROM public.get_auth_salon_id() THEN
    RAISE EXCEPTION 'Fiche inaccessible'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Sans droit sur la finance du salon, on ne consulte que ses propres
  -- chiffres : le coiffeur voit sa commission, pas celle de son collègue.
  IF NOT public.auth_is_manager()
     AND p_profile_id IS DISTINCT FROM public.get_auth_profile_id() THEN
    RAISE EXCEPTION 'Fiche inaccessible'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT
    COALESCE(SUM((COALESCE(line->>'unit_price_fcfa', line->>'unitPriceFcfa'))::BIGINT * COALESCE((line->>'quantity')::BIGINT, 1)), 0),
    COALESCE(SUM(COALESCE((line->>'quantity')::BIGINT, 1)), 0)
  INTO v_revenue, v_count
  FROM public.transactions t
  CROSS JOIN jsonb_array_elements(t.lines) as line
  WHERE t.salon_id = v_salon_id
    AND t.status = 'paid'
    AND COALESCE(line->>'stylist_id', line->>'stylistId', t.cashier_id::TEXT) = p_profile_id::TEXT;

  RETURN jsonb_build_object(
    'revenue_fcfa', v_revenue,
    'service_count', v_count,
    'commission_fcfa', ROUND(v_revenue * (v_rate / 100.0))
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.stylist_stats(UUID) TO authenticated;

-- `stylist_commissions` est corrigée dans 20260814_role_permissions.sql, qui
-- lui ajoute la même vérification du salon appelant.
