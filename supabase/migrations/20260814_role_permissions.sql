-- Cloisonnement par rôle — le pendant en base du filtrage de l'interface.
--
-- Jusqu'ici l'isolation s'arrêtait au salon : n'importe quel membre pouvait
-- lire et écrire tout ce que son salon contenait. La clé anonyme étant lisible
-- dans l'APK, masquer un bouton côté Flutter ne protège rien — un coiffeur
-- curieux interroge PostgREST directement. Ces politiques posent la règle là
-- où elle tient : le coiffeur ne voit que ses rendez-vous, ne modifie pas le
-- catalogue et n'encaisse pas.
--
-- Les politiques « Tenant isolation for X » de 20260806 restent en place et
-- continuent de porter le cloisonnement par salon. Celles ajoutées ici sont
-- RESTRICTIVE : PostgreSQL combine les permissives par OU mais les
-- restrictives par ET, donc elles retranchent sans qu'une permissive existante
-- puisse les contourner.

-- ==========================================================================
-- 1. Le rôle et la fiche du membre connecté
-- ==========================================================================

-- `SECURITY DEFINER` : ces fonctions lisent `profiles`, qui est elle-même sous
-- RLS. Sans ça, l'évaluation d'une politique déclencherait la lecture d'une
-- table protégée par une politique — récursion infinie.
CREATE OR REPLACE FUNCTION public.get_auth_profile_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM public.profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.get_auth_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

-- Les rôles applicatifs sont 'gerant' / 'coiffeur' / 'receptionniste', mais le
-- schéma d'origine documentait 'owner' / 'manager' / 'receptionist' / 'stylist'
-- et `profiles.role` a pour défaut 'stylist'. Les deux vocabulaires peuvent
-- donc coexister en base : les accepter tous les deux évite d'enfermer dehors
-- un gérant historique enregistré en 'owner'.
CREATE OR REPLACE FUNCTION public.auth_is_manager()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.get_auth_role() IN ('gerant', 'owner', 'manager');
$$;

-- Gérant + réceptionniste : encaissement, catalogue, planning du salon.
CREATE OR REPLACE FUNCTION public.auth_is_front_desk()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.get_auth_role()
           IN ('gerant', 'owner', 'manager', 'receptionniste', 'receptionist');
$$;

GRANT EXECUTE ON FUNCTION public.get_auth_profile_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_auth_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.auth_is_manager() TO authenticated;
GRANT EXECUTE ON FUNCTION public.auth_is_front_desk() TO authenticated;

-- ==========================================================================
-- 2. Agenda : le coiffeur ne voit que ses propres rendez-vous
-- ==========================================================================

DROP POLICY IF EXISTS "Stylists read only their own appointments"
  ON public.appointments;
CREATE POLICY "Stylists read only their own appointments"
  ON public.appointments
  AS RESTRICTIVE
  FOR SELECT
  TO authenticated
  USING (
    public.auth_is_front_desk()
    OR stylist_id = public.get_auth_profile_id()
  );

-- La prise et la modification de rendez-vous restent au comptoir. Le coiffeur
-- garde en revanche la main sur le déroulé de sa prestation : sans cette
-- exception, il ne pourrait pas passer son RDV en « terminé ».
DROP POLICY IF EXISTS "Only front desk books appointments"
  ON public.appointments;
CREATE POLICY "Only front desk books appointments"
  ON public.appointments
  AS RESTRICTIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (public.auth_is_front_desk());

DROP POLICY IF EXISTS "Stylists update only their own appointments"
  ON public.appointments;
CREATE POLICY "Stylists update only their own appointments"
  ON public.appointments
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  USING (
    public.auth_is_front_desk()
    OR stylist_id = public.get_auth_profile_id()
  )
  WITH CHECK (
    public.auth_is_front_desk()
    OR stylist_id = public.get_auth_profile_id()
  );

DROP POLICY IF EXISTS "Only front desk deletes appointments"
  ON public.appointments;
CREATE POLICY "Only front desk deletes appointments"
  ON public.appointments
  AS RESTRICTIVE
  FOR DELETE
  TO authenticated
  USING (public.auth_is_front_desk());

-- ==========================================================================
-- 3. Catalogue : consultable par tous, modifiable au comptoir
-- ==========================================================================

-- Le coiffeur a besoin des durées et des prix pour travailler : la lecture
-- reste ouverte, seule l'écriture est fermée.
DROP POLICY IF EXISTS "Only front desk writes services" ON public.services;
CREATE POLICY "Only front desk writes services"
  ON public.services
  AS RESTRICTIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (public.auth_is_front_desk());

DROP POLICY IF EXISTS "Only front desk updates services" ON public.services;
CREATE POLICY "Only front desk updates services"
  ON public.services
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  USING (public.auth_is_front_desk())
  WITH CHECK (public.auth_is_front_desk());

DROP POLICY IF EXISTS "Only front desk deletes services" ON public.services;
CREATE POLICY "Only front desk deletes services"
  ON public.services
  AS RESTRICTIVE
  FOR DELETE
  TO authenticated
  USING (public.auth_is_front_desk());

-- ==========================================================================
-- 4. Caisse : le coiffeur n'encaisse pas et ne lit pas les tickets du salon
-- ==========================================================================

DROP POLICY IF EXISTS "Only front desk reads transactions"
  ON public.transactions;
CREATE POLICY "Only front desk reads transactions"
  ON public.transactions
  AS RESTRICTIVE
  FOR SELECT
  TO authenticated
  USING (
    public.auth_is_front_desk()
    OR cashier_id = public.get_auth_profile_id()
  );

DROP POLICY IF EXISTS "Only front desk writes transactions"
  ON public.transactions;
CREATE POLICY "Only front desk writes transactions"
  ON public.transactions
  AS RESTRICTIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (public.auth_is_front_desk());

DROP POLICY IF EXISTS "Only front desk updates transactions"
  ON public.transactions;
CREATE POLICY "Only front desk updates transactions"
  ON public.transactions
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  USING (public.auth_is_front_desk())
  WITH CHECK (public.auth_is_front_desk());

-- ==========================================================================
-- 5. `stylist_commissions` : sa propre ligne, et rien que son salon
-- ==========================================================================

-- Deux corrections au passage :
--
--  * la fonction ne vérifiait pas que l'appelant appartient à `p_salon_id`.
--    Étant `SECURITY DEFINER`, elle contournait l'isolation tenant : passer
--    l'identifiant d'un salon tiers en suffisait à lire son chiffre d'affaires
--    par coiffeur ;
--  * elle lisait `p.speciality`, colonne qui n'existe pas — `profiles` porte
--    `specialties TEXT[]`. L'appel échouait donc systématiquement et l'app
--    retombait sur son calcul Dart de secours. Désormais que la lecture des
--    transactions est fermée au coiffeur, ce repli ne fonctionnerait plus pour
--    lui : la fonction doit marcher.
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
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id UUID := public.get_auth_profile_id();
BEGIN
  IF p_salon_id IS DISTINCT FROM public.get_auth_salon_id() THEN
    RAISE EXCEPTION 'Salon inaccessible'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  RETURN QUERY
  WITH expanded_lines AS (
    SELECT
      p.id::TEXT AS st_id,
      p.full_name AS st_name,
      NULLIF(p.specialties[1], '') AS st_spec,
      COALESCE(p.commission_rate, 0)::NUMERIC AS st_rate,
      COALESCE(
        (COALESCE(line->>'unit_price_fcfa', line->>'unitPriceFcfa'))::BIGINT,
        0
      ) * COALESCE((line->>'quantity')::BIGINT, 1) AS line_amount,
      COALESCE((line->>'quantity')::BIGINT, 1) AS line_qty,
      t.client_id
    FROM public.transactions t
    CROSS JOIN jsonb_array_elements(t.lines) AS line
    JOIN public.profiles p
      ON p.id::TEXT = COALESCE(
           line->>'stylist_id',
           line->>'stylistId',
           t.cashier_id::TEXT
         )
    WHERE t.salon_id = p_salon_id
      AND t.created_at >= p_from
      AND t.created_at < p_to
      AND t.status = 'paid'
      -- Sans droit sur la finance, on ne rapporte que sa propre ligne.
      AND (public.auth_is_manager() OR p.id = v_profile_id)
  )
  SELECT
    el.st_id,
    el.st_name,
    SUM(el.line_amount)::BIGINT,
    ROUND(SUM(el.line_amount) * MAX(el.st_rate) / 100)::BIGINT,
    SUM(el.line_qty)::BIGINT,
    MAX(el.st_rate),
    MAX(el.st_spec),
    COUNT(DISTINCT el.client_id)::BIGINT
  FROM expanded_lines el
  GROUP BY el.st_id, el.st_name
  ORDER BY 3 DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION
  public.stylist_commissions(UUID, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
