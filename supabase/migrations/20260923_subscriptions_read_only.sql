-- ==========================================================================
-- Migration : l'abonnement cesse d'être écrit depuis le client
-- ==========================================================================
-- La policy en place était :
--
--   CREATE POLICY "Tenant isolation for subscriptions" ON public.subscriptions
--     FOR ALL TO authenticated USING (salon_id = public.get_auth_salon_id());
--
-- `FOR ALL` sans `WITH CHECK` : PostgreSQL réutilise l'expression `USING`
-- pour l'INSERT et l'UPDATE. N'importe quel membre authentifié du salon —
-- un coiffeur, une réceptionniste — pouvait donc repousser `next_charge_at`
-- de dix ans ou passer `status` à 'active'. La serrure et la clé étaient
-- dans la même main, et l'essai gratuit ne valait que pour qui l'ignorait.
--
-- Désormais : lecture pour les membres du salon, écriture par la seule RPC
-- ci-dessous, qui vérifie le rôle et lit le tarif au catalogue plutôt que
-- de le recevoir de l'appelant.

DROP POLICY IF EXISTS "Tenant isolation for subscriptions" ON public.subscriptions;

CREATE POLICY "Salon members read their subscription" ON public.subscriptions
  FOR SELECT TO authenticated
  USING (salon_id = public.get_auth_salon_id());

-- ==========================================================================
-- Changement de formule
-- ==========================================================================
-- Ni le prix ni l'échéance ne viennent du client : le premier est lu dans
-- `subscription_plans`, la seconde est calculée ici. Un appelant ne peut
-- donc pas s'offrir le plan Pro à 0 F ni se donner une échéance lointaine.
CREATE OR REPLACE FUNCTION public.change_subscription_plan(
  p_plan_code TEXT,
  p_billing_cycle TEXT DEFAULT 'monthly',
  p_payment_label TEXT DEFAULT NULL
)
RETURNS public.subscriptions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_salon_id UUID := public.get_auth_salon_id();
  v_plan     public.subscription_plans;
  v_cycle    TEXT;
  v_row      public.subscriptions;
BEGIN
  IF v_salon_id IS NULL THEN
    RAISE EXCEPTION 'Profil introuvable pour ce compte'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Souscrire engage la caisse du salon : seul le gérant le fait.
  IF NOT public.auth_is_manager() THEN
    RAISE EXCEPTION 'Seul le gérant peut changer de formule'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT * INTO v_plan
    FROM public.subscription_plans
   WHERE code = p_plan_code
   LIMIT 1;

  IF v_plan.code IS NULL THEN
    RAISE EXCEPTION 'Formule inconnue'
      USING ERRCODE = 'check_violation';
  END IF;

  v_cycle := CASE WHEN p_billing_cycle = 'annual' THEN 'annual' ELSE 'monthly' END;

  INSERT INTO public.subscriptions (
    salon_id, plan_code, plan_name, price_per_month_fcfa,
    billing_cycle, status, features, payment_label, next_charge_at
  )
  VALUES (
    v_salon_id,
    v_plan.code,
    v_plan.name,
    COALESCE(v_plan.price_per_month_fcfa, 0),
    v_cycle,
    'active',
    COALESCE(v_plan.features, '{}'),
    p_payment_label,
    CASE WHEN v_cycle = 'annual'
         THEN now() + INTERVAL '1 year'
         ELSE now() + INTERVAL '1 month'
    END
  )
  ON CONFLICT (salon_id) DO UPDATE SET
    plan_code            = EXCLUDED.plan_code,
    plan_name            = EXCLUDED.plan_name,
    price_per_month_fcfa = EXCLUDED.price_per_month_fcfa,
    billing_cycle        = EXCLUDED.billing_cycle,
    status               = EXCLUDED.status,
    features             = EXCLUDED.features,
    payment_label        = EXCLUDED.payment_label,
    next_charge_at       = EXCLUDED.next_charge_at
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.change_subscription_plan(TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.change_subscription_plan(TEXT, TEXT, TEXT)
  TO authenticated;
