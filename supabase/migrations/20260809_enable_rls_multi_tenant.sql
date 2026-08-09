-- Migration: Enable multi-tenant RLS isolation & Secure PIN Verification RPC

-- 1. Helper function to get salon_id of the currently authenticated user
CREATE OR REPLACE FUNCTION public.get_auth_salon_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT salon_id FROM public.profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

-- 2. Drop legacy permissive policies
DROP POLICY IF EXISTS "Authenticated users full access to profiles" ON public.profiles;
DROP POLICY IF EXISTS "Authenticated users full access to clients" ON public.clients;
DROP POLICY IF EXISTS "Authenticated users full access to services" ON public.services;
DROP POLICY IF EXISTS "Authenticated users full access to appointments" ON public.appointments;
DROP POLICY IF EXISTS "Authenticated users full access to walk_in_queue" ON public.walk_in_queue;
DROP POLICY IF EXISTS "Authenticated users full access to products" ON public.products;
DROP POLICY IF EXISTS "Authenticated users full access to stock_movements" ON public.stock_movements;
DROP POLICY IF EXISTS "Authenticated users full access to transactions" ON public.transactions;
DROP POLICY IF EXISTS "Authenticated users full access to time_off" ON public.time_off;
DROP POLICY IF EXISTS "Authenticated users full access to expenses" ON public.expenses;
DROP POLICY IF EXISTS "Authenticated users full access to loyalty_rewards" ON public.loyalty_rewards;
DROP POLICY IF EXISTS "Authenticated users full access to promotions" ON public.promotions;
DROP POLICY IF EXISTS "Authenticated users full access to reminder_rules" ON public.reminder_rules;
DROP POLICY IF EXISTS "Authenticated users full access to campaigns" ON public.campaigns;
DROP POLICY IF EXISTS "Authenticated users full access to subscriptions" ON public.subscriptions;

-- 3. Strict Multi-Tenant RLS Policies
CREATE POLICY "Tenant isolation for salons" ON public.salons
  FOR ALL TO authenticated USING (id = public.get_auth_salon_id());

CREATE POLICY "Tenant isolation for profiles" ON public.profiles
  FOR ALL TO authenticated USING (salon_id = public.get_auth_salon_id());

CREATE POLICY "Tenant isolation for clients" ON public.clients
  FOR ALL TO authenticated USING (salon_id = public.get_auth_salon_id());

CREATE POLICY "Tenant isolation for services" ON public.services
  FOR ALL TO authenticated USING (salon_id = public.get_auth_salon_id());

CREATE POLICY "Tenant isolation for appointments" ON public.appointments
  FOR ALL TO authenticated USING (salon_id = public.get_auth_salon_id());

CREATE POLICY "Tenant isolation for walk_in_queue" ON public.walk_in_queue
  FOR ALL TO authenticated USING (salon_id = public.get_auth_salon_id());

CREATE POLICY "Tenant isolation for products" ON public.products
  FOR ALL TO authenticated USING (salon_id = public.get_auth_salon_id());

CREATE POLICY "Tenant isolation for stock_movements" ON public.stock_movements
  FOR ALL TO authenticated USING (salon_id = public.get_auth_salon_id());

CREATE POLICY "Tenant isolation for transactions" ON public.transactions
  FOR ALL TO authenticated USING (salon_id = public.get_auth_salon_id());

CREATE POLICY "Tenant isolation for time_off" ON public.time_off
  FOR ALL TO authenticated USING (salon_id = public.get_auth_salon_id());

CREATE POLICY "Tenant isolation for expenses" ON public.expenses
  FOR ALL TO authenticated USING (salon_id = public.get_auth_salon_id());

CREATE POLICY "Tenant isolation for loyalty_rewards" ON public.loyalty_rewards
  FOR ALL TO authenticated USING (salon_id = public.get_auth_salon_id());

CREATE POLICY "Tenant isolation for promotions" ON public.promotions
  FOR ALL TO authenticated USING (salon_id = public.get_auth_salon_id());

CREATE POLICY "Tenant isolation for reminder_rules" ON public.reminder_rules
  FOR ALL TO authenticated USING (salon_id = public.get_auth_salon_id());

CREATE POLICY "Tenant isolation for campaigns" ON public.campaigns
  FOR ALL TO authenticated USING (salon_id = public.get_auth_salon_id());

CREATE POLICY "Tenant isolation for subscriptions" ON public.subscriptions
  FOR ALL TO authenticated USING (salon_id = public.get_auth_salon_id());

-- 4. PIN Security RPC
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.verify_pin(
  p_profile_id UUID,
  p_pin TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stored_pin TEXT;
BEGIN
  SELECT pin_code INTO v_stored_pin
  FROM public.profiles
  WHERE id = p_profile_id;

  IF v_stored_pin IS NULL OR v_stored_pin = '' THEN
    RETURN FALSE;
  END IF;

  IF v_stored_pin = p_pin OR v_stored_pin = crypt(p_pin, v_stored_pin) THEN
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_pin(UUID, TEXT) TO authenticated;
