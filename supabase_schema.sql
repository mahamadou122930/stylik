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
    invite_code TEXT,             -- code à 6 caractères dicté aux employés
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

-- Aucune policy permissive sur `salons` : l'accès passe par « Tenant isolation
-- for salons » plus bas. Une policy `USING (true)` ici s'ajouterait à celle-ci
-- par OU et annulerait l'isolation multi-tenant.
--
-- Le salon est créé avant le compte du gérant (inscription 1.3 → 1.4), donc par
-- un appelant encore anonyme : cette création passe exclusivement par la RPC
-- SECURITY DEFINER ci-dessous, jamais par un INSERT direct.
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
  -- Exécutable par `anon`, et la clé anonyme est lisible dans l'APK : on refuse
  -- au moins les lignes vides ou aberrantes.
  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Le nom du salon est obligatoire'
      USING ERRCODE = 'check_violation';
  END IF;

  IF length(btrim(p_name)) > 120 THEN
    RAISE EXCEPTION 'Nom de salon trop long'
      USING ERRCODE = 'check_violation';
  END IF;

  INSERT INTO public.salons (name, phone, address)
  VALUES (btrim(p_name), nullif(btrim(coalesce(p_phone, '')), ''),
          nullif(btrim(coalesce(p_address, '')), ''))
  RETURNING * INTO v_salon;
  RETURN v_salon;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_salon_for_signup(TEXT, TEXT, TEXT) TO anon, authenticated;

-- Nettoyage d'un salon dont l'inscription du gérant a échoué juste après.
CREATE OR REPLACE FUNCTION public.delete_orphan_salon(p_salon_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.salons s
   WHERE s.id = p_salon_id
     AND NOT EXISTS (
       SELECT 1 FROM public.profiles p WHERE p.salon_id = s.id
     );
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_orphan_salon(UUID) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_auth_salon_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT salon_id FROM public.profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

-- Politiques RLS strictes multi-tenant par salon_id
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

-- Le catalogue des formules est public en lecture, modifiable seulement côté admin.
CREATE POLICY "Anyone can read subscription plans" ON public.subscription_plans FOR SELECT TO anon, authenticated USING (true);

-- Code d'invitation du salon (parcours « Rejoindre un salon »).
-- Alphabet sans caractères ambigus (ni 0/O, ni 1/I/L) : le code est dicté à
-- l'oral ou recopié depuis un SMS.
CREATE OR REPLACE FUNCTION public.generate_invite_code()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_alphabet CONSTANT TEXT := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code TEXT;
  v_try INTEGER := 0;
BEGIN
  LOOP
    v_code := '';
    FOR i IN 1..6 LOOP
      v_code := v_code || substr(
        v_alphabet,
        1 + floor(random() * length(v_alphabet))::int,
        1
      );
    END LOOP;

    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.salons WHERE upper(invite_code) = v_code
    );

    v_try := v_try + 1;
    IF v_try > 50 THEN
      RAISE EXCEPTION 'Impossible de générer un code d''invitation unique';
    END IF;
  END LOOP;

  RETURN v_code;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS salons_invite_code_key
  ON public.salons (upper(invite_code));

ALTER TABLE public.salons
  ALTER COLUMN invite_code SET DEFAULT public.generate_invite_code();

-- Appelée par un visiteur encore anonyme, sur l'écran « Rejoindre un salon » :
-- elle ne renvoie que le nom, de quoi confirmer « Salon reconnu ». Le code seul
-- ne donne aucun accès — l'inscription exige en plus une fiche employé.
CREATE OR REPLACE FUNCTION public.salon_by_invite_code(p_code TEXT)
RETURNS TABLE (id UUID, name TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT s.id, s.name
    FROM public.salons s
   WHERE upper(s.invite_code) = upper(btrim(coalesce(p_code, '')))
     AND btrim(coalesce(p_code, '')) <> '';
$$;

GRANT EXECUTE ON FUNCTION public.salon_by_invite_code(TEXT) TO anon, authenticated;

-- Trigger pour la création automatique du profil après inscription Supabase Auth
-- À l'inscription : réclamer la fiche pré-créée par le gérant (même email et
-- même salon) plutôt que d'en créer une seconde en doublon.
--
-- Sur le parcours « Rejoindre un salon », le salon vient du code résolu ici :
-- un `salon_id` posé par le client ne peut donc pas servir à s'inviter dans un
-- salon tiers. Et sans fiche employé correspondant à l'email, l'inscription est
-- refusée — sinon deviner un code à six caractères suffirait à entrer.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_join_code TEXT := upper(btrim(coalesce(NEW.raw_user_meta_data->>'join_code', '')));
  v_salon_id  UUID := (NEW.raw_user_meta_data->>'salon_id')::uuid;
  v_claimed   UUID;
  v_matches   INTEGER;
BEGIN
  IF v_join_code <> '' THEN
    SELECT s.id INTO v_salon_id
      FROM public.salons s
     WHERE upper(s.invite_code) = v_join_code;

    IF v_salon_id IS NULL THEN
      RAISE EXCEPTION 'Code d''invitation inconnu'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  -- Sans `salon_id` transmis, plusieurs salons peuvent avoir pré-créé une fiche
  -- avec le même email. On ne réclame que s'il n'y a aucune ambiguïté : un
  -- `LIMIT 1` arbitraire rattacherait la personne au mauvais salon.
  SELECT count(*) INTO v_matches
    FROM public.profiles
   WHERE user_id IS NULL
     AND email IS NOT NULL
     AND lower(email) = lower(NEW.email)
     AND (v_salon_id IS NULL OR salon_id = v_salon_id);

  IF v_matches = 1 THEN
    SELECT id INTO v_claimed
      FROM public.profiles
     WHERE user_id IS NULL
       AND email IS NOT NULL
       AND lower(email) = lower(NEW.email)
       AND (v_salon_id IS NULL OR salon_id = v_salon_id);
  END IF;

  IF v_join_code <> '' AND v_claimed IS NULL THEN
    RAISE EXCEPTION 'Aucune fiche employé n''attend cet email dans ce salon'
      USING ERRCODE = 'check_violation';
  END IF;

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
$$;

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

-- Verification du PIN utilisateur (sécurisé via pgcrypto)
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

  -- Un hash pgcrypto commence toujours par '$' ($2a$, $2b$, $6$…). Appeler
  -- crypt() sur un PIN en clair lèverait « invalid salt » au lieu de refuser.
  IF v_stored_pin LIKE '$%' THEN
    RETURN v_stored_pin = crypt(p_pin, v_stored_pin);
  END IF;

  RETURN v_stored_pin = p_pin;
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_pin(UUID, TEXT) TO authenticated;

-- Synthèse financière de la période
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

-- Ajustement du stock produit
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

-- Crédit / Débit de points de fidélité client
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

-- Remboursement d'une transaction
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

-- Statistiques des rappels & automatisations
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

-- Statistiques de performance d'un membre d'équipe
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
