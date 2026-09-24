-- ==========================================================================
-- Migration : Essai gratuit Pro de 15 jours par défaut pour chaque salon
-- ==========================================================================
-- Tout nouveau salon bénéficie automatiquement de 15 jours d'essai gratuit
-- sur la formule « Pro Salon » avec l'intégralité des fonctionnalités.

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
  v_plan_code TEXT := 'pro';
  v_plan_name TEXT := 'Pro Salon';
  v_price INTEGER := 18000;
  v_features TEXT[] := ARRAY[
    'Jusqu''à 10 employés',
    'Rappels SMS & WhatsApp illimités',
    'Rapports & export comptable'
  ];
BEGIN
  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Le nom du salon est obligatoire'
      USING ERRCODE = 'check_violation';
  END IF;

  IF length(btrim(p_name)) > 120 THEN
    RAISE EXCEPTION 'Nom de salon trop long'
      USING ERRCODE = 'check_violation';
  END IF;

  -- 1. Création du salon
  INSERT INTO public.salons (name, phone, address)
  VALUES (btrim(p_name), nullif(btrim(coalesce(p_phone, '')), ''),
          nullif(btrim(coalesce(p_address, '')), ''))
  RETURNING * INTO v_salon;

  -- 2. Récupération des informations de la formule Pro si elle est présente au catalogue
  SELECT
    code, name, price_per_month_fcfa, features
  INTO
    v_plan_code, v_plan_name, v_price, v_features
  FROM public.subscription_plans
  WHERE code = 'pro'
  LIMIT 1;

  -- 3. Activation automatique de l'essai Pro 15 jours
  INSERT INTO public.subscriptions (
    salon_id,
    plan_code,
    plan_name,
    price_per_month_fcfa,
    billing_cycle,
    status,
    features,
    payment_label,
    next_charge_at
  )
  VALUES (
    v_salon.id,
    coalesce(v_plan_code, 'pro'),
    coalesce(v_plan_name, 'Pro Salon'),
    coalesce(v_price, 18000),
    'monthly',
    'trialing',
    coalesce(v_features, ARRAY['Jusqu''à 10 employés', 'Rappels SMS & WhatsApp illimités', 'Rapports & export comptable']),
    'Essai gratuit (15 jours)',
    now() + INTERVAL '15 days'
  )
  ON CONFLICT (salon_id) DO NOTHING;

  RETURN v_salon;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_salon_for_signup(TEXT, TEXT, TEXT)
  TO anon, authenticated;

-- Rétro-application pour tous les salons existants n'ayant pas encore d'abonnement
INSERT INTO public.subscriptions (
  salon_id,
  plan_code,
  plan_name,
  price_per_month_fcfa,
  billing_cycle,
  status,
  features,
  payment_label,
  next_charge_at
)
SELECT
  s.id,
  coalesce(p.code, 'pro'),
  coalesce(p.name, 'Pro Salon'),
  coalesce(p.price_per_month_fcfa, 18000),
  'monthly',
  'trialing',
  coalesce(p.features, ARRAY['Jusqu''à 10 employés', 'Rappels SMS & WhatsApp illimités', 'Rapports & export comptable']),
  'Essai gratuit (15 jours)',
  now() + INTERVAL '15 days'
FROM public.salons s
LEFT JOIN LATERAL (
  SELECT code, name, price_per_month_fcfa, features
  FROM public.subscription_plans
  WHERE code = 'pro'
  LIMIT 1
) p ON true
WHERE NOT EXISTS (
  SELECT 1 FROM public.subscriptions sub WHERE sub.salon_id = s.id
)
ON CONFLICT (salon_id) DO NOTHING;
