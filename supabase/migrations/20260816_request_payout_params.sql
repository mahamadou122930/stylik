-- `request_payout` n'acceptait qu'un motif, l'app en envoie trois.
--
-- Erreur remontée par l'app :
--
--   PGRST202 Could not find the function
--   public.request_payout(p_amount_fcfa, p_note, p_profile_id)
--
-- L'écran permet désormais de saisir un montant partiel — un coiffeur peut
-- ne demander qu'une avance — et au gérant de déposer la demande à la place
-- d'un membre, typiquement une demande faite oralement à la réception.
--
-- Les deux ajouts ouvrent chacun une porte qu'il faut refermer :
--
--  * un montant transmis par le client doit être **borné** par le dû réel,
--    sinon demander plus que sa commission ne coûte qu'un appel forgé ;
--  * déposer pour autrui est réservé au gérant, sans quoi n'importe qui
--    déclencherait un versement au nom d'un collègue.

DROP FUNCTION IF EXISTS public.request_payout(TEXT);

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
  v_from      TIMESTAMPTZ := date_trunc('month', now());
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

  SELECT COALESCE(c.commission_fcfa, 0) INTO v_earned
    FROM public.stylist_commissions(v_salon_id, v_from, v_to) c
   WHERE c.stylist_id = v_target_id::TEXT;

  -- Versé ce mois-ci + déjà en attente : les deux amputent ce qui reste
  -- réclamable, sinon deux demandes successives cumuleraient le même dû.
  SELECT COALESCE(SUM(amount_fcfa), 0) INTO v_settled
    FROM public.payout_requests
   WHERE profile_id = v_target_id
     AND (
       status = 'pending'
       OR (status = 'paid' AND paid_at >= v_from AND paid_at < v_to)
     );

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
