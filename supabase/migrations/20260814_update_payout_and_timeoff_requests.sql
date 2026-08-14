-- Mise à jour de request_payout :
-- 1. Permet la saisie d'un montant personnalisé (p_amount_fcfa) jusqu'à concurrence du solde disponible.
-- 2. Permet au gérant ou à la réception de déposer une demande pour un coiffeur (p_profile_id).

CREATE OR REPLACE FUNCTION public.request_payout(
  p_amount_fcfa INTEGER DEFAULT NULL,
  p_note TEXT DEFAULT NULL,
  p_profile_id UUID DEFAULT NULL
)
RETURNS public.payout_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_profile_id UUID := public.get_auth_profile_id();
  v_target_profile_id UUID;
  v_salon_id          UUID := public.get_auth_salon_id();
  v_from              TIMESTAMPTZ := date_trunc('month', now());
  v_to                TIMESTAMPTZ := date_trunc('month', now()) + INTERVAL '1 month';
  v_earned            BIGINT := 0;
  v_settled           BIGINT := 0;
  v_available         BIGINT;
  v_request_amount    BIGINT;
  v_row               public.payout_requests;
BEGIN
  IF v_caller_profile_id IS NULL OR v_salon_id IS NULL THEN
    RAISE EXCEPTION 'Profil introuvable pour ce compte'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Si p_profile_id est transmis, vérifier que l'appelant est gérant ou réceptionniste
  IF p_profile_id IS NOT NULL AND p_profile_id != v_caller_profile_id THEN
    IF NOT (public.auth_is_manager() OR public.auth_has_role('receptionniste')) THEN
      RAISE EXCEPTION 'Seule la réception ou le gérant peut déposer une demande pour un collègue'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
    v_target_profile_id := p_profile_id;
  ELSE
    v_target_profile_id := v_caller_profile_id;
  END IF;

  SELECT COALESCE(c.commission_fcfa, 0) INTO v_earned
    FROM public.stylist_commissions(v_salon_id, v_from, v_to) c
   WHERE c.stylist_id = v_target_profile_id::TEXT;

  SELECT COALESCE(SUM(amount_fcfa), 0) INTO v_settled
    FROM public.payout_requests
   WHERE profile_id = v_target_profile_id
     AND (
       status = 'pending'
       OR (status = 'paid' AND paid_at >= v_from AND paid_at < v_to)
     );

  v_available := COALESCE(v_earned, 0) - v_settled;

  IF v_available <= 0 THEN
    RAISE EXCEPTION 'Aucun montant disponible à demander pour ce coiffeur'
      USING ERRCODE = 'check_violation';
  END IF;

  -- Si un montant valide est saisi, l'utiliser ; sinon demander tout le disponible par défaut
  IF p_amount_fcfa IS NOT NULL AND p_amount_fcfa > 0 AND p_amount_fcfa <= v_available THEN
    v_request_amount := p_amount_fcfa;
  ELSE
    v_request_amount := v_available;
  END IF;

  INSERT INTO public.payout_requests (
    salon_id, profile_id, amount_fcfa, status, note
  )
  VALUES (
    v_salon_id, v_target_profile_id, v_request_amount, 'pending', NULLIF(btrim(p_note), '')
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_payout(INTEGER, TEXT, UUID) TO authenticated;
