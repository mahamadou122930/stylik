-- Fix RPC functions to handle both snake_case and camelCase keys in JSONB lines

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
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH expanded_lines AS (
    SELECT 
      COALESCE(line->>'ref_id', line->>'refId')::TEXT as s_id,
      COALESCE(line->>'label', 'Prestation')::TEXT as s_name,
      COALESCE(line->>'category', 'Autre')::TEXT as s_category,
      COALESCE((line->>'quantity')::BIGINT, 1) as s_qty,
      COALESCE((COALESCE(line->>'unit_price_fcfa', line->>'unitPriceFcfa'))::BIGINT, 0) * COALESCE((line->>'quantity')::BIGINT, 1) as s_amount
    FROM public.transactions t,
         jsonb_array_elements(t.lines) as line
    WHERE t.salon_id = p_salon_id
      AND t.created_at >= p_from
      AND t.created_at < p_to
      AND t.status = 'paid'
      AND COALESCE((COALESCE(line->>'is_product', line->>'isProduct'))::BOOLEAN, false) = false
  )
  SELECT 
    el.s_id as service_id,
    el.s_name as name,
    el.s_category as category,
    SUM(el.s_qty) as count,
    SUM(el.s_amount) as revenue_fcfa
  FROM expanded_lines el
  GROUP BY el.s_id, el.s_name, el.s_category
  ORDER BY revenue_fcfa DESC;
END;
$$;

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
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH expanded_lines AS (
    SELECT 
      p.id::TEXT as st_id,
      p.full_name as st_name,
      p.speciality as st_spec,
      COALESCE(p.commission_rate, 0)::NUMERIC as st_rate,
      COALESCE((COALESCE(line->>'unit_price_fcfa', line->>'unitPriceFcfa'))::BIGINT, 0) * COALESCE((line->>'quantity')::BIGINT, 1) as line_amount,
      COALESCE((line->>'quantity')::BIGINT, 1) as line_qty,
      t.client_id
    FROM public.transactions t
    CROSS JOIN jsonb_array_elements(t.lines) as line
    JOIN public.profiles p ON p.id::TEXT = COALESCE(line->>'stylist_id', line->>'stylistId', t.cashier_id::TEXT)
    WHERE t.salon_id = p_salon_id
      AND t.created_at >= p_from
      AND t.created_at < p_to
      AND t.status = 'paid'
  )
  SELECT 
    el.st_id as stylist_id,
    el.st_name as stylist_name,
    SUM(el.line_amount) as revenue_fcfa,
    ROUND(SUM(el.line_amount) * (MAX(el.st_rate) / 100.0))::BIGINT as commission_fcfa,
    SUM(el.line_qty) as service_count,
    MAX(el.st_rate) as commission_rate,
    MAX(el.st_spec) as speciality,
    COUNT(DISTINCT el.client_id) as client_count
  FROM expanded_lines el
  GROUP BY el.st_id, el.st_name;
END;
$$;
