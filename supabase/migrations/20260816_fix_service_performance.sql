-- `service_performance` échouait sur un type de retour.
--
-- Vérifié sur la base :
--
--   POST /rpc/service_performance
--   -> 42804 Returned type numeric does not match expected type
--
-- En PostgreSQL, `SUM()` d'un `BIGINT` rend un `NUMERIC`, alors que la
-- fonction déclare `count BIGINT` et `revenue_fcfa BIGINT`. Chaque appel
-- levait donc une exception, et le rapport « Par service » retombait
-- silencieusement sur le calcul Dart de secours.
--
-- `stylist_commissions` avait exactement le même défaut ; il y est déjà
-- corrigé, par les mêmes casts explicites.
--
-- Déclarée `SECURITY INVOKER` : la fonction ne lit que `transactions`, déjà
-- couverte par l'isolation tenant. C'est la RLS qui cloisonne, sans garde à
-- maintenir — même traitement que dans `20260815_tenant_guard_rpcs.sql`.
CREATE OR REPLACE FUNCTION public.service_performance(
  p_salon_id UUID,
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ
)
RETURNS TABLE (
  service_id TEXT,
  name TEXT,
  category TEXT,
  count BIGINT,
  revenue_fcfa BIGINT
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH expanded_lines AS (
    SELECT
      COALESCE(line->>'ref_id', line->>'refId')::TEXT AS s_id,
      COALESCE(line->>'label', 'Prestation')::TEXT AS s_name,
      COALESCE(line->>'category', 'Autre')::TEXT AS s_category,
      COALESCE((line->>'quantity')::BIGINT, 1) AS s_qty,
      COALESCE(
        (COALESCE(line->>'unit_price_fcfa', line->>'unitPriceFcfa'))::BIGINT,
        0
      ) * COALESCE((line->>'quantity')::BIGINT, 1) AS s_amount
    FROM public.transactions t,
         jsonb_array_elements(t.lines) AS line
    WHERE t.salon_id = p_salon_id
      AND t.created_at >= p_from
      AND t.created_at < p_to
      AND t.status = 'paid'
      AND COALESCE(
        (COALESCE(line->>'is_product', line->>'isProduct'))::BOOLEAN,
        false
      ) = false
  )
  SELECT
    el.s_id,
    el.s_name,
    el.s_category,
    -- Les deux casts qui manquaient.
    SUM(el.s_qty)::BIGINT,
    SUM(el.s_amount)::BIGINT
  FROM expanded_lines el
  GROUP BY el.s_id, el.s_name, el.s_category
  ORDER BY 5 DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION
  public.service_performance(UUID, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
