-- ==========================================
-- STYLIK - SCHEMA COMPLET SUPABASE
-- ==========================================
-- À exécuter dans l'éditeur SQL de Supabase (SQL Editor)

-- Extension pour UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Table `salons`
CREATE TABLE IF NOT EXISTS public.salons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    phone TEXT NOT NULL DEFAULT '',
    address TEXT NOT NULL DEFAULT '',
    email TEXT,
    logo_url TEXT,
    opening_hours JSONB DEFAULT '{}'::jsonb,
    currency TEXT DEFAULT 'FCFA',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Table `profiles` (Personnel / Utilisateurs)
-- Le profil est autonome : le gérant crée un employé sans compte Auth. Le
-- rattachement se fait par `user_id` si la personne s'inscrit un jour.
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
    email TEXT,                   -- sert au rattachement à l'inscription
    salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'stylist', -- 'owner', 'manager', 'receptionist', 'stylist'
    specialties TEXT[] DEFAULT '{}',
    commission_rate NUMERIC DEFAULT 0,
    pin_code TEXT,
    avatar_url TEXT,
    phone TEXT,
    is_active BOOLEAN DEFAULT true,
    leave_balance_days INTEGER DEFAULT 0, -- solde de congés (fiche employé 4.2)
    working_hours JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Table `clients`
CREATE TABLE IF NOT EXISTS public.clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL DEFAULT '',
    gender TEXT DEFAULT 'other', -- 'female', 'male', 'other'
    allergies_notes TEXT,
    loyalty_points INTEGER DEFAULT 0,
    tags TEXT[] DEFAULT '{}',
    photo_before_url TEXT,
    photo_after_url TEXT,
    preferences JSONB DEFAULT '{}'::jsonb,
    visit_count INTEGER DEFAULT 0,
    total_spent_fcfa INTEGER DEFAULT 0,
    last_visit_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Table `services` (Catalogue des prestations et forfaits)
CREATE TABLE IF NOT EXISTS public.services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT DEFAULT 'Autre',
    duration_minutes INTEGER DEFAULT 30,
    price_fcfa INTEGER DEFAULT 0,
    commission_rate NUMERIC DEFAULT 0,
    is_package BOOLEAN DEFAULT false,
    included_service_ids TEXT[] DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    description TEXT,
    is_bookable_online BOOLEAN DEFAULT true,
    original_price_fcfa INTEGER,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Table `appointments` (Rendez-vous)
CREATE TABLE IF NOT EXISTS public.appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE,
    client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL,
    stylist_id UUID REFERENCES public.profiles(id) ON DELETE RESTRICT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'scheduled', -- 'scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show'
    total_price_fcfa INTEGER DEFAULT 0,
    service_items JSONB DEFAULT '[]'::jsonb,
    service_ids TEXT[] DEFAULT '{}',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. Table `walk_in_queue` (File d'attente sans rendez-vous)
CREATE TABLE IF NOT EXISTS public.walk_in_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE,
    client_name TEXT NOT NULL,
    service_requested TEXT NOT NULL DEFAULT '',
    arrival_time TIMESTAMPTZ DEFAULT now(),
    status TEXT NOT NULL DEFAULT 'waiting', -- 'waiting', 'assigned', 'in_progress', 'served', 'left'
    assigned_stylist_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    phone TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. Table `products` (Stock / Inventaire)
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    brand TEXT DEFAULT '',
    category TEXT DEFAULT 'Autre',
    stock_quantity INTEGER DEFAULT 0,
    alert_threshold INTEGER DEFAULT 0,
    unit_sale_price_fcfa INTEGER DEFAULT 0,
    unit_cost_fcfa INTEGER DEFAULT 0,
    supplier TEXT,
    packaging TEXT,
    usage TEXT DEFAULT 'resale', -- 'resale', 'consumable'
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 8. Table `stock_movements` (Mouvements de stock)
CREATE TABLE IF NOT EXISTS public.stock_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL,
    reason TEXT DEFAULT 'adjustment', -- 'reception', 'consumption', 'sale', 'adjustment', 'loss'
    occurred_at TIMESTAMPTZ DEFAULT now(),
    product_name TEXT,
    unit_label TEXT,
    context_label TEXT,
    cost_fcfa INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 9. Table `transactions` (Encaissements Caisse / POS)
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE,
    appointment_id UUID REFERENCES public.appointments(id) ON DELETE SET NULL,
    client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL,
    cashier_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    subtotal_fcfa INTEGER DEFAULT 0,
    discount_fcfa INTEGER DEFAULT 0,
    total_amount_fcfa INTEGER DEFAULT 0,
    payment_method TEXT DEFAULT 'cash', -- 'cash', 'wave', 'orange_money', 'card', 'check'
    status TEXT DEFAULT 'paid', -- 'draft', 'paid', 'refunded', 'cancelled'
    lines JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 10. Table `time_off` (Absences / Congés)
CREATE TABLE IF NOT EXISTS public.time_off (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE,
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    type TEXT DEFAULT 'vacation', -- 'vacation', 'sick_leave', 'unpaid'
    status TEXT DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 11. Table `expenses` (Dépenses / Charges)
CREATE TABLE IF NOT EXISTS public.expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    amount_fcfa INTEGER DEFAULT 0,
    category TEXT DEFAULT 'other', -- 'rent', 'supplies', 'utilities', 'payroll', 'marketing', 'other'
    spent_at TIMESTAMPTZ DEFAULT now(),
    supplier TEXT,
    is_recurring BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 12. Table `loyalty_rewards` (Récompenses fidélité)
CREATE TABLE IF NOT EXISTS public.loyalty_rewards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    points_cost INTEGER DEFAULT 0,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 13. Table `promotions` (Promotions)
CREATE TABLE IF NOT EXISTS public.promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT true,
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    usage_count INTEGER DEFAULT 0,
    revenue_fcfa INTEGER DEFAULT 0,
    is_automatic BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 14. Table `reminder_rules` (Règles de rappels auto)
CREATE TABLE IF NOT EXISTS public.reminder_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    channel TEXT DEFAULT 'sms', -- 'sms', 'whatsapp', 'both'
    is_enabled BOOLEAN DEFAULT false,
    description TEXT,
    message_template TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 15. Table `campaigns` (Campagnes Marketing)
CREATE TABLE IF NOT EXISTS public.campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    channel TEXT DEFAULT 'sms', -- 'sms', 'whatsapp', 'both'
    message TEXT NOT NULL DEFAULT '',
    target_tags TEXT[] DEFAULT '{}',
    scheduled_at TIMESTAMPTZ,
    sent_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 16. Table `subscriptions` (Abonnements SaaS)
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE,
    plan_code TEXT,               -- référence `subscription_plans.code`
    plan_name TEXT DEFAULT 'Formule',
    price_per_month_fcfa INTEGER DEFAULT 0,
    billing_cycle TEXT DEFAULT 'monthly', -- 'monthly', 'annual'
    status TEXT DEFAULT 'active', -- 'active', 'trialing', 'past_due', 'canceled'
    features TEXT[] DEFAULT '{}',
    payment_label TEXT,
    next_charge_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Un seul abonnement par salon (nécessaire à l'upsert du changement de formule)
CREATE UNIQUE INDEX IF NOT EXISTS uniq_subscriptions_salon ON public.subscriptions(salon_id);

-- 17. Table `subscription_plans` (Catalogue des formules SaaS)
-- Table globale, sans `salon_id` : elle décrit l'offre commerciale affichée sur
-- les écrans « Choisir un abonnement » et « Comparatif & paiement ».
CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,    -- 'solo', 'pro', 'multi'
    name TEXT NOT NULL,
    tagline TEXT,                 -- « Salon avec équipe »
    summary TEXT,                 -- ligne descriptive sous le prix
    price_per_month_fcfa INTEGER NOT NULL DEFAULT 0,
    -- Fonctions comparées : 'agenda', 'pos', 'team', 'reports', 'messaging'
    capabilities TEXT[] DEFAULT '{}',
    features TEXT[] DEFAULT '{}', -- puces « Inclus dans … »
    is_popular BOOLEAN DEFAULT false,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- INDEX POUR LES PERFORMANCES
-- ==========================================
CREATE INDEX IF NOT EXISTS idx_profiles_salon ON public.profiles(salon_id);
CREATE INDEX IF NOT EXISTS idx_clients_salon ON public.clients(salon_id);
CREATE INDEX IF NOT EXISTS idx_services_salon ON public.services(salon_id);
CREATE INDEX IF NOT EXISTS idx_appointments_salon ON public.appointments(salon_id);
CREATE INDEX IF NOT EXISTS idx_appointments_stylist ON public.appointments(stylist_id);
CREATE INDEX IF NOT EXISTS idx_appointments_start ON public.appointments(start_time);
CREATE INDEX IF NOT EXISTS idx_products_salon ON public.products(salon_id);
CREATE INDEX IF NOT EXISTS idx_transactions_salon ON public.transactions(salon_id);
CREATE INDEX IF NOT EXISTS idx_expenses_salon ON public.expenses(salon_id);

-- ==========================================
-- ROW LEVEL SECURITY (RLS) & POLICIES
-- ==========================================
-- Activer RLS sur les tables
ALTER TABLE public.salons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.walk_in_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.time_off ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reminder_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

-- Le salon est créé avant le compte du gérant (inscription 1.3 → 1.4) : l'INSERT
-- doit donc être ouvert aux anonymes, le reste reste réservé aux authentifiés.
CREATE POLICY "Anyone can create a salon during signup" ON public.salons FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can read salons" ON public.salons FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can update salons" ON public.salons FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated users can delete salons" ON public.salons FOR DELETE TO authenticated USING (true);

-- Création du salon par un utilisateur encore anonyme, sans ouvrir la lecture.
CREATE OR REPLACE FUNCTION public.create_salon_for_signup(
  p_name TEXT,
  p_phone TEXT,
  p_address TEXT
)
RETURNS public.salons
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_salon public.salons;
BEGIN
  INSERT INTO public.salons (name, phone, address)
  VALUES (p_name, p_phone, p_address)
  RETURNING * INTO v_salon;
  RETURN v_salon;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_salon_for_signup(TEXT, TEXT, TEXT) TO anon, authenticated;

CREATE POLICY "Authenticated users full access to profiles" ON public.profiles FOR ALL TO authenticated USING (true);
CREATE POLICY "Authenticated users full access to clients" ON public.clients FOR ALL TO authenticated USING (true);
CREATE POLICY "Authenticated users full access to services" ON public.services FOR ALL TO authenticated USING (true);
CREATE POLICY "Authenticated users full access to appointments" ON public.appointments FOR ALL TO authenticated USING (true);
CREATE POLICY "Authenticated users full access to walk_in_queue" ON public.walk_in_queue FOR ALL TO authenticated USING (true);
CREATE POLICY "Authenticated users full access to products" ON public.products FOR ALL TO authenticated USING (true);
CREATE POLICY "Authenticated users full access to stock_movements" ON public.stock_movements FOR ALL TO authenticated USING (true);
CREATE POLICY "Authenticated users full access to transactions" ON public.transactions FOR ALL TO authenticated USING (true);
CREATE POLICY "Authenticated users full access to time_off" ON public.time_off FOR ALL TO authenticated USING (true);
CREATE POLICY "Authenticated users full access to expenses" ON public.expenses FOR ALL TO authenticated USING (true);
CREATE POLICY "Authenticated users full access to loyalty_rewards" ON public.loyalty_rewards FOR ALL TO authenticated USING (true);
CREATE POLICY "Authenticated users full access to promotions" ON public.promotions FOR ALL TO authenticated USING (true);
CREATE POLICY "Authenticated users full access to reminder_rules" ON public.reminder_rules FOR ALL TO authenticated USING (true);
CREATE POLICY "Authenticated users full access to campaigns" ON public.campaigns FOR ALL TO authenticated USING (true);
CREATE POLICY "Authenticated users full access to subscriptions" ON public.subscriptions FOR ALL TO authenticated USING (true);

-- Le catalogue des formules est public en lecture, modifiable seulement côté admin.
CREATE POLICY "Anyone can read subscription plans" ON public.subscription_plans FOR SELECT TO anon, authenticated USING (true);

-- Trigger pour la création automatique du profil après inscription Supabase Auth
-- À l'inscription : réclamer la fiche pré-créée par le gérant (même email et
-- même salon) plutôt que d'en créer une seconde en doublon.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_salon_id UUID := (NEW.raw_user_meta_data->>'salon_id')::uuid;
  v_claimed  UUID;
BEGIN
  SELECT id INTO v_claimed
    FROM public.profiles
   WHERE user_id IS NULL
     AND email IS NOT NULL
     AND lower(email) = lower(NEW.email)
     AND (v_salon_id IS NULL OR salon_id = v_salon_id)
   LIMIT 1;

  IF v_claimed IS NOT NULL THEN
    UPDATE public.profiles
       SET user_id   = NEW.id,
           full_name = COALESCE(
             NULLIF(NEW.raw_user_meta_data->>'full_name', ''),
             full_name
           )
     WHERE id = v_claimed;
  ELSE
    INSERT INTO public.profiles (user_id, salon_id, full_name, email, role)
    VALUES (
      NEW.id,
      v_salon_id,
      COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
      NEW.email,
      COALESCE(NEW.raw_user_meta_data->>'role', 'coiffeur')
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==========================================
-- STORAGE BUCKETS
-- ==========================================
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('salon-logos', 'salon-logos', true),
    ('client-photos', 'client-photos', true),
    ('product-photos', 'product-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Politiques d'accès aux Buckets Storage
CREATE POLICY "Public Read salon-logos" ON storage.objects FOR SELECT USING (bucket_id = 'salon-logos');
CREATE POLICY "Authenticated Upload salon-logos" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'salon-logos');

CREATE POLICY "Public Read client-photos" ON storage.objects FOR SELECT USING (bucket_id = 'client-photos');
CREATE POLICY "Authenticated Upload client-photos" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'client-photos');

CREATE POLICY "Public Read product-photos" ON storage.objects FOR SELECT USING (bucket_id = 'product-photos');
CREATE POLICY "Authenticated Upload product-photos" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'product-photos');

-- ==========================================
-- FONCTIONS DU RAPPORT FINANCIER & CAISSE
-- ==========================================

-- Rapport de ventes par prestation
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

-- Rapport de commissions par coiffeur
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
