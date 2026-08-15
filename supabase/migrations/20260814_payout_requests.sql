-- Demandes de versement de commission (écran « Mes commissions »).
--
-- Une seule table porte tout le cycle : le coiffeur demande, le gérant règle.
-- Le versement n'est pas un objet distinct — c'est cette même ligne une fois
-- `paid`, avec sa date, son moyen de paiement et sa référence. Deux tables à
-- rapprocher pour reconstituer « telle demande = tel versement » ne feraient
-- qu'ouvrir des écarts.

CREATE TABLE IF NOT EXISTS public.payout_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID NOT NULL REFERENCES public.salons(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount_fcfa INTEGER NOT NULL CHECK (amount_fcfa > 0),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'paid', 'rejected')),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Renseignés au règlement seulement : tant que la demande est en attente,
    -- le gérant n'a pas encore choisi comment il paie.
    method TEXT CHECK (
      method IS NULL
      OR method IN ('orange_money', 'moov_money', 'wave', 'cash', 'transfer')
    ),
    paid_at TIMESTAMPTZ,
    reference TEXT,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS payout_requests_profile_idx
  ON public.payout_requests (profile_id, requested_at DESC);

-- Une seule demande en attente à la fois par personne : sans ça, dix appuis
-- sur le bouton créent dix demandes du même montant et le gérant paie deux fois.
CREATE UNIQUE INDEX IF NOT EXISTS payout_requests_one_pending_per_profile
  ON public.payout_requests (profile_id)
  WHERE status = 'pending';

ALTER TABLE public.payout_requests ENABLE ROW LEVEL SECURITY;

-- ==========================================================================
-- Politiques
-- ==========================================================================

-- Cloisonnement par salon, comme les autres tables.
DROP POLICY IF EXISTS "Tenant isolation for payout_requests"
  ON public.payout_requests;
CREATE POLICY "Tenant isolation for payout_requests"
  ON public.payout_requests
  FOR ALL
  TO authenticated
  USING (salon_id = public.get_auth_salon_id())
  WITH CHECK (salon_id = public.get_auth_salon_id());

-- Chacun ne voit que ses propres demandes ; le gérant voit tout le salon,
-- c'est lui qui règle.
DROP POLICY IF EXISTS "Members read only their own payouts"
  ON public.payout_requests;
CREATE POLICY "Members read only their own payouts"
  ON public.payout_requests
  AS RESTRICTIVE
  FOR SELECT
  TO authenticated
  USING (
    public.auth_is_manager()
    OR profile_id = public.get_auth_profile_id()
  );

-- L'insertion directe est fermée à tous : elle passe obligatoirement par
-- `request_payout`, qui calcule le montant. Un INSERT libre laisserait
-- n'importe qui réclamer la somme de son choix.
DROP POLICY IF EXISTS "Payout requests go through the RPC"
  ON public.payout_requests;
CREATE POLICY "Payout requests go through the RPC"
  ON public.payout_requests
  AS RESTRICTIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (false);

-- Seul le gérant fait évoluer une demande (régler, refuser).
DROP POLICY IF EXISTS "Only the manager settles payouts"
  ON public.payout_requests;
CREATE POLICY "Only the manager settles payouts"
  ON public.payout_requests
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  USING (public.auth_is_manager())
  WITH CHECK (public.auth_is_manager());

DROP POLICY IF EXISTS "Only the manager deletes payouts"
  ON public.payout_requests;
CREATE POLICY "Only the manager deletes payouts"
  ON public.payout_requests
  AS RESTRICTIVE
  FOR DELETE
  TO authenticated
  USING (public.auth_is_manager());

-- ==========================================================================
-- Dépôt d'une demande
-- ==========================================================================

-- Le montant n'est pas un paramètre : il est recalculé ici, sinon demander
-- plus que son dû ne coûterait qu'un appel HTTP forgé. Le salon et le
-- demandeur viennent de la session pour la même raison.
--
-- Reste dû = commission acquise sur le mois − déjà versé ce mois − déjà
-- demandé et en attente.
CREATE OR REPLACE FUNCTION public.request_payout(p_note TEXT DEFAULT NULL)
RETURNS public.payout_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id UUID := public.get_auth_profile_id();
  v_salon_id   UUID := public.get_auth_salon_id();
  v_from       TIMESTAMPTZ := date_trunc('month', now());
  v_to         TIMESTAMPTZ := date_trunc('month', now()) + INTERVAL '1 month';
  v_earned     BIGINT := 0;
  v_settled    BIGINT := 0;
  v_available  BIGINT;
  v_row        public.payout_requests;
BEGIN
  IF v_profile_id IS NULL OR v_salon_id IS NULL THEN
    RAISE EXCEPTION 'Profil introuvable pour ce compte'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT COALESCE(c.commission_fcfa, 0) INTO v_earned
    FROM public.stylist_commissions(v_salon_id, v_from, v_to) c
   WHERE c.stylist_id = v_profile_id::TEXT;

  -- Versé ce mois-ci + déjà en attente : les deux amputent ce qui reste
  -- réclamable, sinon deux demandes successives cumuleraient le même dû.
  SELECT COALESCE(SUM(amount_fcfa), 0) INTO v_settled
    FROM public.payout_requests
   WHERE profile_id = v_profile_id
     AND (
       status = 'pending'
       OR (status = 'paid' AND paid_at >= v_from AND paid_at < v_to)
     );

  v_available := COALESCE(v_earned, 0) - v_settled;

  IF v_available <= 0 THEN
    RAISE EXCEPTION 'Aucun montant disponible à demander'
      USING ERRCODE = 'check_violation';
  END IF;

  INSERT INTO public.payout_requests (
    salon_id, profile_id, amount_fcfa, status, note
  )
  VALUES (
    v_salon_id, v_profile_id, v_available, 'pending', NULLIF(btrim(p_note), '')
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_payout(TEXT) TO authenticated;

-- ==========================================================================
-- Règlement par le gérant
-- ==========================================================================

CREATE OR REPLACE FUNCTION public.settle_payout(
  p_request_id UUID,
  p_method TEXT,
  p_reference TEXT DEFAULT NULL
)
RETURNS public.payout_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.payout_requests;
BEGIN
  IF NOT public.auth_is_manager() THEN
    RAISE EXCEPTION 'Seul le gérant peut régler un versement'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  UPDATE public.payout_requests
     SET status    = 'paid',
         method    = p_method,
         reference = NULLIF(btrim(p_reference), ''),
         paid_at   = now()
   WHERE id = p_request_id
     AND salon_id = public.get_auth_salon_id()
     AND status = 'pending'
  RETURNING * INTO v_row;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'Demande introuvable ou déjà traitée'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.settle_payout(UUID, TEXT, TEXT) TO authenticated;
