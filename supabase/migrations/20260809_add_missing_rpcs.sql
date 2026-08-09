-- Migration: Add missing RPC functions

-- 1. finance_summary
CREATE OR REPLACE FUNCTION public.finance_summary(
  p_salon_id UUID,
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ,
  p_bucket_count INT DEFAULT 4
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_revenue BIGINT := 0;
  v_collected BIGINT := 0;
  v_pending BIGINT := 0;
  v_count INT := 0;
BEGIN
  SELECT 
    COALESCE(SUM(total_amount_fcfa), 0),
    COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount_fcfa ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN status != 'paid' AND status != 'cancelled' AND status != 'refunded' THEN total_amount_fcfa ELSE 0 END), 0),
    COUNT(*)
  INTO v_revenue, v_collected, v_pending, v_count
  FROM public.transactions
  WHERE salon_id = p_salon_id
    AND created_at >= p_from
    AND created_at < p_to
    AND status NOT IN ('cancelled', 'refunded');

  RETURN jsonb_build_object(
    'revenue_fcfa', v_revenue,
    'collected_fcfa', v_collected,
    'pending_fcfa', v_pending,
    'ticket_count', v_count
  );
END;
$$;

-- 2. adjust_stock
CREATE OR REPLACE FUNCTION public.adjust_stock(
  p_product_id UUID,
  p_delta INT,
  p_reason TEXT DEFAULT 'ajustement',
  p_created_by UUID DEFAULT NULL,
  p_context TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_salon_id UUID;
BEGIN
  SELECT salon_id INTO v_salon_id FROM public.products WHERE id = p_product_id;
  IF v_salon_id IS NULL THEN
    RAISE EXCEPTION 'Produit introuvable';
  END IF;

  UPDATE public.products
  SET stock_quantity = GREATEST(0, stock_quantity + p_delta)
  WHERE id = p_product_id;

  INSERT INTO public.stock_movements (
    salon_id,
    product_id,
    quantity,
    type,
    reason,
    created_by
  ) VALUES (
    v_salon_id,
    p_product_id,
    ABS(p_delta),
    CASE WHEN p_delta >= 0 THEN 'in' ELSE 'out' END,
    COALESCE(p_context, p_reason),
    p_created_by
  );
END;
$$;

-- 3. add_loyalty_points
CREATE OR REPLACE FUNCTION public.add_loyalty_points(
  p_client_id UUID,
  p_points INT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.clients
  SET loyalty_points = GREATEST(0, COALESCE(loyalty_points, 0) + p_points)
  WHERE id = p_client_id;
END;
$$;

-- 4. refund_transaction
CREATE OR REPLACE FUNCTION public.refund_transaction(
  p_transaction_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.transactions
  SET status = 'refunded',
      notes = CASE 
                WHEN p_reason IS NOT NULL AND p_reason != '' 
                THEN COALESCE(notes, '') || ' [Remboursé: ' || p_reason || ']'
                ELSE COALESCE(notes, '')
              END
  WHERE id = p_transaction_id;
END;
$$;

-- 5. reminder_stats
CREATE OR REPLACE FUNCTION public.reminder_stats(
  p_salon_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sent INT := 0;
  v_confirmed INT := 0;
BEGIN
  SELECT 
    COALESCE(SUM(sent_count), 0),
    COALESCE(SUM(converted_count), 0)
  INTO v_sent, v_confirmed
  FROM public.campaigns
  WHERE salon_id = p_salon_id;

  RETURN jsonb_build_object(
    'sent_count', v_sent,
    'confirmed_count', v_confirmed
  );
END;
$$;

-- 6. stylist_stats
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
BEGIN
  SELECT salon_id, COALESCE(commission_rate, 0) INTO v_salon_id, v_rate
  FROM public.profiles WHERE id = p_profile_id;

  IF v_salon_id IS NULL THEN
    RETURN jsonb_build_object('revenue_fcfa', 0, 'service_count', 0, 'commission_fcfa', 0);
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
