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
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'stylist', -- 'owner', 'manager', 'receptionist', 'stylist'
    specialties TEXT[] DEFAULT '{}',
    commission_rate NUMERIC DEFAULT 0,
    pin_code TEXT,
    avatar_url TEXT,
    phone TEXT,
    is_active BOOLEAN DEFAULT true,
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
    plan_name TEXT DEFAULT 'Formule',
    price_per_month_fcfa INTEGER DEFAULT 0,
    status TEXT DEFAULT 'active', -- 'active', 'trialing', 'past_due', 'canceled'
    features TEXT[] DEFAULT '{}',
    payment_label TEXT,
    next_charge_at TIMESTAMPTZ,
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

-- Autoriser la lecture / écriture aux utilisateurs authentifiés
CREATE POLICY "Authenticated users full access to salons" ON public.salons FOR ALL TO authenticated USING (true);
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
