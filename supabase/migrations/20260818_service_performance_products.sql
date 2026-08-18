-- `service_performance` écartait les produits revendus.
--
-- La clause `is_product = false` ne gardait que les prestations, alors que
-- l'écran « Par service » présente sa répartition comme celle du chiffre
-- d'affaires — « 100 % du CA ». Un salon qui revend du shampooing voyait donc
-- ses prestations occuper tout l'anneau, et le total affiché était inférieur
-- au CA de la même période sans que rien ne l'explique.
--
-- Les produits sont désormais retenus, avec :
--   * `is_product`, pour que l'app compte « 3 unités vendues » plutôt que
--     « 3 prestations » et classe les deux séparément ;
--   * la catégorie forcée à « Produits ». Sur une ligne produit, `category`
--     porte la marque : la laisser telle quelle ferait apparaître « Kérastase »
--     à côté de « Coiffure » dans l'anneau, une part par marque noyée parmi
--     les prestations.
--
-- Reprend les casts `::BIGINT` de `20260816_fix_service_performance.sql` :
-- `SUM()` d'un BIGINT rend un NUMERIC, et sans eux chaque appel levait
-- « 42804 Returned type numeric does not match expected type ».
--
-- `SECURITY INVOKER` : la fonction ne lit que `transactions`, déjà cloisonnée
-- par la RLS tenant. Pas de garde à maintenir.
DROP FUNCTION IF EXISTS public.service_performance(UUID, TIMESTAMPTZ, TIMESTAMPTZ);

CREATE FUNCTION public.service_performance(
  p_salon_id UUID,
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ
)
RETURNS TABLE (
  service_id TEXT,
  name TEXT,
  category TEXT,
  count BIGINT,
  revenue_fcfa BIGINT,
  is_product BOOLEAN
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH expanded_lines AS (
    SELECT
      COALESCE(
        (COALESCE(line->>'is_product', line->>'isProduct'))::BOOLEAN,
        false
      ) AS s_is_product,
      COALESCE(line->>'ref_id', line->>'refId')::TEXT AS s_id,
      -- NULLIF avant COALESCE : `COALESCE` seul laisse passer la chaîne vide,
      -- et une catégorie blanche donne une part de l'anneau sans légende.
      COALESCE(NULLIF(TRIM(line->>'label'), ''), 'Prestation')::TEXT AS s_name,
      CASE
        WHEN COALESCE(
          (COALESCE(line->>'is_product', line->>'isProduct'))::BOOLEAN,
          false
        ) THEN 'Produits'
        ELSE COALESCE(NULLIF(TRIM(line->>'category'), ''), 'Autre')
      END::TEXT AS s_category,
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
  )
  SELECT
    el.s_id,
    el.s_name,
    el.s_category,
    SUM(el.s_qty)::BIGINT,
    SUM(el.s_amount)::BIGINT,
    el.s_is_product
  FROM expanded_lines el
  GROUP BY el.s_id, el.s_name, el.s_category, el.s_is_product
  ORDER BY 5 DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION
  public.service_performance(UUID, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
