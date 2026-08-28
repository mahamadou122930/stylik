-- Le plafond de versement ne regardait que le mois en cours.
--
-- `request_payout` bornait le montant réclamable à
-- `commission du mois courant − versements du mois courant`. Deux défauts
-- opposés :
--
--  * une commission gagnée en juillet et jamais réglée devenait
--    **irréclamable** en août — la fenêtre repartait de zéro le 1er du mois,
--    et le dû du coiffeur disparaissait ;
--  * à l'inverse, un versement passé sur un mois précédent n'amputait rien du
--    mois suivant, ce qui laissait rattraper deux fois le même dû à cheval sur
--    un changement de mois.
--
-- Le solde devient **cumulatif** : tout ce qui a été gagné depuis l'ouverture,
-- moins tout ce qui a été versé ou est déjà demandé. Un versement supérieur à
-- la commission reste donc impossible, sauf précisément quand des commissions
-- antérieures n'ont pas été réglées — c'est alors du rattrapage légitime.
CREATE OR REPLACE FUNCTION public.request_payout(
  p_amount_fcfa INTEGER DEFAULT NULL,
  p_profile_id UUID DEFAULT NULL,
  p_note TEXT DEFAULT NULL
)
RETURNS public.payout_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id UUID := public.get_auth_profile_id();
  v_salon_id  UUID := public.get_auth_salon_id();
  -- Bénéficiaire : soi-même par défaut.
  v_target_id UUID := COALESCE(p_profile_id, public.get_auth_profile_id());
  -- Depuis le premier exercice, et jusqu'à la fin du mois courant pour que
  -- les ventes du jour comptent. Aligné sur `financeFirstYear` côté app.
  v_from      TIMESTAMPTZ := TIMESTAMPTZ '2025-01-01 00:00:00+00';
  v_to        TIMESTAMPTZ := date_trunc('month', now()) + INTERVAL '1 month';
  v_earned    BIGINT := 0;
  v_settled   BIGINT := 0;
  v_available BIGINT;
  v_amount    BIGINT;
  v_row       public.payout_requests;
BEGIN
  IF v_caller_id IS NULL OR v_salon_id IS NULL THEN
    RAISE EXCEPTION 'Profil introuvable pour ce compte'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF v_target_id IS DISTINCT FROM v_caller_id AND NOT public.auth_is_manager() THEN
    RAISE EXCEPTION 'Seul le gérant peut demander un versement pour un membre'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Le bénéficiaire doit appartenir au salon de l'appelant.
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
     WHERE id = v_target_id AND salon_id = v_salon_id
  ) THEN
    RAISE EXCEPTION 'Membre introuvable dans ce salon'
      USING ERRCODE = 'check_violation';
  END IF;

  -- Tout ce que le membre a gagné depuis l'ouverture.
  SELECT COALESCE(c.commission_fcfa, 0) INTO v_earned
    FROM public.stylist_commissions(v_salon_id, v_from, v_to) c
   WHERE c.stylist_id = v_target_id::TEXT;

  -- Tout ce qui lui a été versé, plus ce qui attend déjà le gérant. Sans
  -- borne de date, cette fois : un règlement de juillet doit continuer
  -- d'amputer le dû en août, sinon le même travail serait payé deux fois.
  SELECT COALESCE(SUM(amount_fcfa), 0) INTO v_settled
    FROM public.payout_requests
   WHERE profile_id = v_target_id
     AND status IN ('pending', 'paid');

  v_available := COALESCE(v_earned, 0) - v_settled;

  IF v_available <= 0 THEN
    RAISE EXCEPTION 'Aucun montant disponible à demander'
      USING ERRCODE = 'check_violation';
  END IF;

  -- Sans montant, on réclame tout le dû. Avec, il est borné : c'est ici que
  -- se joue la confiance, le client ne pouvant pas s'attribuer davantage.
  v_amount := COALESCE(NULLIF(p_amount_fcfa, 0)::BIGINT, v_available);

  IF v_amount <= 0 THEN
    RAISE EXCEPTION 'Le montant demandé doit être positif'
      USING ERRCODE = 'check_violation';
  END IF;

  IF v_amount > v_available THEN
    RAISE EXCEPTION 'Montant supérieur au disponible (% F)', v_available
      USING ERRCODE = 'check_violation';
  END IF;

  INSERT INTO public.payout_requests (
    salon_id, profile_id, amount_fcfa, status, note
  )
  VALUES (
    v_salon_id, v_target_id, v_amount, 'pending', NULLIF(btrim(p_note), '')
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION
  public.request_payout(INTEGER, UUID, TEXT) TO authenticated;
