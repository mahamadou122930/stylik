-- Annulation d'encaissement : la fonction n'existait pas, et la colonne
-- qu'elle visait non plus.
--
-- Vérifié sur la base :
--
--   POST /rpc/refund_transaction -> PGRST202 (fonction absente)
--   transactions.notes           -> 42703 column does not exist
--
-- L'app appelait donc une RPC inexistante, avalait l'erreur dans un `catch`
-- et mettait la ligne en file d'attente hors ligne. Le message
-- « Remboursement enregistré » s'affichait, mais la transaction restait
-- « payée » en base : la caisse du jour comptait toujours la somme rendue.

ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS notes TEXT;

-- Rembourser, c'est annuler une recette déjà encaissée : l'opération reste au
-- gérant, comme le prévoit `UserRole.canVoidTransaction`. Sans ce contrôle,
-- n'importe quel membre pouvait effacer une vente de la caisse.
CREATE OR REPLACE FUNCTION public.refund_transaction(
  p_transaction_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS public.transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.transactions;
BEGIN
  IF NOT public.auth_is_manager() THEN
    RAISE EXCEPTION 'Seul le gérant peut annuler un encaissement'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  UPDATE public.transactions
     SET status = 'refunded',
         notes = CASE
           WHEN COALESCE(btrim(p_reason), '') = '' THEN notes
           ELSE btrim(COALESCE(notes || ' ', '') || '[Remboursé: ' || p_reason || ']')
         END
   WHERE id = p_transaction_id
     AND salon_id = public.get_auth_salon_id()
     -- Un ticket déjà remboursé ne se rembourse pas deux fois : sans cette
     -- borne, chaque appel retrancherait à nouveau la somme du total du jour.
     AND status = 'paid'
  RETURNING * INTO v_row;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'Transaction introuvable, déjà remboursée, ou hors de votre salon'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION
  public.refund_transaction(UUID, TEXT) TO authenticated;
