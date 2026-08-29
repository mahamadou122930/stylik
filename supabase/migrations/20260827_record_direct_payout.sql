-- Le gérant ne pouvait pas enregistrer un versement direct.
--
-- Vérifié sur la base :
--
--   POST /rest/v1/payout_requests
--   -> 42501 new row violates row-level security policy
--
-- `createDirectPayout` côté application fait un INSERT direct dans
-- `payout_requests`. Or la policy « Payout requests go through the RPC » est
-- `WITH CHECK (false)` : l'insertion libre est fermée **à tout le monde**,
-- délibérément — un INSERT ouvert laisserait n'importe qui s'attribuer la
-- somme de son choix.
--
-- Cette fermeture est la bonne décision ; ce qui manquait, c'est la porte
-- d'entrée contrôlée pour le cas légitime : le gérant qui règle un coiffeur
-- sans demande préalable, de la main à la main.
--
-- `record_payout` crée donc la ligne déjà réglée, après avoir vérifié que
-- l'appelant est gérant, que le bénéficiaire est de son salon, et que le
-- montant ne dépasse pas le dû cumulé — la même borne que `request_payout`.
CREATE OR REPLACE FUNCTION public.record_payout(
  p_profile_id UUID,
  p_amount_fcfa INTEGER,
  p_method TEXT DEFAULT 'cash',
  p_reference TEXT DEFAULT NULL,
  p_note TEXT DEFAULT NULL
)
RETURNS public.payout_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_salon_id  UUID := public.get_auth_salon_id();
  v_from      TIMESTAMPTZ := TIMESTAMPTZ '2025-01-01 00:00:00+00';
  v_to        TIMESTAMPTZ := date_trunc('month', now()) + INTERVAL '1 month';
  v_earned    BIGINT := 0;
  v_settled   BIGINT := 0;
  v_available BIGINT;
  v_row       public.payout_requests;
BEGIN
  IF v_salon_id IS NULL THEN
    RAISE EXCEPTION 'Profil introuvable pour ce compte'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Enregistrer un versement, c'est constater une sortie de caisse : seul le
  -- gérant le fait. Sans ce contrôle, un coiffeur pourrait déclarer avoir été
  -- payé et effacer son propre dû.
  IF NOT public.auth_is_manager() THEN
    RAISE EXCEPTION 'Seul le gérant peut enregistrer un versement'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
     WHERE id = p_profile_id AND salon_id = v_salon_id
  ) THEN
    RAISE EXCEPTION 'Membre introuvable dans ce salon'
      USING ERRCODE = 'check_violation';
  END IF;

  IF p_amount_fcfa IS NULL OR p_amount_fcfa <= 0 THEN
    RAISE EXCEPTION 'Le montant versé doit être positif'
      USING ERRCODE = 'check_violation';
  END IF;

  SELECT COALESCE(c.commission_fcfa, 0) INTO v_earned
    FROM public.stylist_commissions(v_salon_id, v_from, v_to) c
   WHERE c.stylist_id = p_profile_id::TEXT;

  SELECT COALESCE(SUM(amount_fcfa), 0) INTO v_settled
    FROM public.payout_requests
   WHERE profile_id = p_profile_id
     AND status IN ('pending', 'paid');

  v_available := COALESCE(v_earned, 0) - v_settled;

  IF p_amount_fcfa > v_available THEN
    RAISE EXCEPTION 'Montant supérieur au dû restant (% F)', v_available
      USING ERRCODE = 'check_violation';
  END IF;

  INSERT INTO public.payout_requests (
    salon_id, profile_id, amount_fcfa, status, method, reference, note, paid_at
  )
  VALUES (
    v_salon_id,
    p_profile_id,
    p_amount_fcfa,
    'paid',
    COALESCE(NULLIF(btrim(p_method), ''), 'cash'),
    NULLIF(btrim(p_reference), ''),
    NULLIF(btrim(p_note), ''),
    now()
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION
  public.record_payout(UUID, INTEGER, TEXT, TEXT, TEXT) TO authenticated;
