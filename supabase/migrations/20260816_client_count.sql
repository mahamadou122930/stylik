-- « 0 clients » sur un coiffeur qui a pourtant encaissé.
--
-- Le décompte était `COUNT(DISTINCT t.client_id)`. Or la caisse n'attache pas
-- toujours une fiche : « Client de passage » enregistre un `client_id` nul, et
-- `COUNT(DISTINCT NULL)` vaut zéro. Un coiffeur pouvait donc afficher
-- 3 000 F de chiffre d'affaires et « 0 clients » — exact au sens littéral,
-- mais sans rapport avec la question posée, qui est « combien de personnes
-- a-t-il coiffées ».
--
-- Un client de passage reste un client servi. On compte donc les fiches
-- distinctes, et chaque ticket anonyme pour un client de plus : deux visites
-- d'une même cliente identifiée comptent pour une personne, deux passages
-- anonymes comptent pour deux.
--
-- Seul le décompte change ; le reste de la fonction est celui de
-- `20260814_role_permissions.sql`.
CREATE OR REPLACE FUNCTION public.stylist_commissions(
  p_salon_id UUID,
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ
)
RETURNS TABLE (
  stylist_id TEXT,
  stylist_name TEXT,
  revenue_fcfa BIGINT,
  commission_fcfa BIGINT,
  service_count BIGINT,
  commission_rate NUMERIC,
  speciality TEXT,
  client_count BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id UUID := public.get_auth_profile_id();
BEGIN
  IF p_salon_id IS DISTINCT FROM public.get_auth_salon_id() THEN
    RAISE EXCEPTION 'Salon inaccessible'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  RETURN QUERY
  WITH expanded_lines AS (
    SELECT
      p.id::TEXT AS st_id,
      p.full_name AS st_name,
      NULLIF(p.specialties[1], '') AS st_spec,
      COALESCE(p.commission_rate, 0)::NUMERIC AS st_rate,
      COALESCE(
        (COALESCE(line->>'unit_price_fcfa', line->>'unitPriceFcfa'))::BIGINT,
        0
      ) * COALESCE((line->>'quantity')::BIGINT, 1) AS line_amount,
      COALESCE((line->>'quantity')::BIGINT, 1) AS line_qty,
      -- Clé de comptage : la fiche client si elle existe, le ticket sinon.
      COALESCE('c:' || t.client_id::TEXT, 't:' || t.id::TEXT) AS served_key
    FROM public.transactions t
    CROSS JOIN jsonb_array_elements(t.lines) AS line
    JOIN public.profiles p
      ON p.id::TEXT = COALESCE(
           line->>'stylist_id',
           line->>'stylistId',
           t.cashier_id::TEXT
         )
    WHERE t.salon_id = p_salon_id
      AND t.created_at >= p_from
      AND t.created_at < p_to
      AND t.status = 'paid'
      -- Sans droit sur la finance, on ne rapporte que sa propre ligne.
      AND (public.auth_is_manager() OR p.id = v_profile_id)
  )
  SELECT
    el.st_id,
    el.st_name,
    SUM(el.line_amount)::BIGINT,
    ROUND(SUM(el.line_amount) * MAX(el.st_rate) / 100)::BIGINT,
    SUM(el.line_qty)::BIGINT,
    MAX(el.st_rate),
    MAX(el.st_spec),
    COUNT(DISTINCT el.served_key)::BIGINT
  FROM expanded_lines el
  GROUP BY el.st_id, el.st_name
  ORDER BY 3 DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION
  public.stylist_commissions(UUID, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
