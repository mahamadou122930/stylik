-- Validation d'une absence et décompte du solde de congés, en une opération.
--
-- Le client faisait jusqu'ici une lecture du solde puis une écriture : deux
-- gérants tranchant à la même seconde s'écrasaient mutuellement, et le salon
-- perdait ou offrait des jours sans trace. PostgREST ne sachant pas exprimer
-- `leave_balance_days = leave_balance_days + n`, la seule façon de rendre
-- l'opération atomique est de la faire en base.
--
-- Trois règles, identiques à `TimeOff.balanceDeltaFor` côté Dart :
--
--   * seul le congé payé ('vacation') touche au solde — maladie et absence
--     non payée ne consomment pas de jours de vacances ;
--   * seule la bascule vers ou depuis 'approved' compte, ce qui rend l'appel
--     idempotent : revalider une demande déjà validée ne retire rien ;
--   * revenir sur une validation rend les jours.

CREATE OR REPLACE FUNCTION public.decide_time_off(
  p_request_id UUID,
  p_status TEXT
)
RETURNS public.time_off
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_request public.time_off;
  v_days    INTEGER;
  v_delta   INTEGER := 0;
BEGIN
  IF p_status NOT IN ('pending', 'approved', 'rejected') THEN
    RAISE EXCEPTION 'Statut d''absence inconnu : %', p_status
      USING ERRCODE = 'check_violation';
  END IF;

  IF NOT public.auth_is_manager() THEN
    RAISE EXCEPTION 'Seul le gérant tranche une demande d''absence'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- `FOR UPDATE` sérialise les décisions concurrentes sur la même demande :
  -- la seconde attend, relit le statut déjà changé, et son delta tombe à zéro.
  SELECT * INTO v_request
    FROM public.time_off
   WHERE id = p_request_id
     AND salon_id = public.get_auth_salon_id()
   FOR UPDATE;

  IF v_request.id IS NULL THEN
    RAISE EXCEPTION 'Demande d''absence introuvable'
      USING ERRCODE = 'check_violation';
  END IF;

  -- Bornes incluses : du 18 au 22 août fait cinq jours. Les dates sont posées
  -- à minuit local et le Mali est à UTC+0 toute l'année, donc la conversion
  -- en `date` ne décale rien.
  v_days := (v_request.end_date::date - v_request.start_date::date) + 1;

  IF v_request.type = 'vacation'
     AND (v_request.status = 'approved') IS DISTINCT FROM (p_status = 'approved')
  THEN
    v_delta := CASE WHEN p_status = 'approved' THEN -v_days ELSE v_days END;
  END IF;

  UPDATE public.time_off
     SET status = p_status
   WHERE id = p_request_id
  RETURNING * INTO v_request;

  IF v_delta <> 0 THEN
    -- Incrément relatif, jamais une valeur calculée par l'appelant : c'est
    -- tout l'intérêt de passer par la base.
    UPDATE public.profiles
       SET leave_balance_days = COALESCE(leave_balance_days, 0) + v_delta
     WHERE id = v_request.profile_id;
  END IF;

  RETURN v_request;
END;
$$;

GRANT EXECUTE ON FUNCTION public.decide_time_off(UUID, TEXT) TO authenticated;
