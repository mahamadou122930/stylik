-- Le montant remboursé n'était stocké nulle part.
--
-- `refund()` côté application recevait bien un `amountFcfa`, la RPC
-- `refund_transaction` acceptait un motif — mais ni l'une ni l'autre n'écrivait
-- la somme rendue. La table ne portait d'ailleurs aucune colonne pour
-- l'accueillir. Un remboursement se réduisait donc à `status = 'refunded'`.
--
-- Conséquence : l'écran de remboursement propose un montant partiel, mais un
-- remboursement de 1 000 F sur un ticket de 5 000 F annulait le ticket entier.
-- Le chiffre d'affaires perdait 5 000 F au lieu de 1 000, et le coiffeur
-- perdait la totalité de sa commission au lieu du cinquième.
--
-- `refunded_amount_fcfa` porte la somme rendue. Un remboursement intégral y
-- inscrit le montant du ticket ; le chiffre d'affaires retenu devient partout
-- `total_amount_fcfa - refunded_amount_fcfa`, qui vaut alors zéro. Les deux
-- cas suivent ainsi la même règle, sans traitement particulier.
ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS refunded_amount_fcfa INTEGER NOT NULL DEFAULT 0;

-- Les tickets déjà remboursés avant cette migration l'ont été intégralement :
-- c'était le seul comportement possible. On le rend explicite plutôt que de
-- laisser un zéro qui les ferait recompter comme du chiffre d'affaires.
UPDATE public.transactions
SET refunded_amount_fcfa = total_amount_fcfa
WHERE status = 'refunded'
  AND refunded_amount_fcfa = 0;

-- Un remboursement ne peut pas dépasser le ticket, ni être négatif.
ALTER TABLE public.transactions
  DROP CONSTRAINT IF EXISTS transactions_refund_within_total;
ALTER TABLE public.transactions
  ADD CONSTRAINT transactions_refund_within_total
  CHECK (
    refunded_amount_fcfa >= 0
    AND refunded_amount_fcfa <= total_amount_fcfa
  );

-- `refund_transaction` accepte désormais le montant.
--
-- `p_amount` à NULL vaut remboursement intégral : c'est ce que fait l'écran
-- quand la caissière ne saisit pas de montant partiel.
--
-- `SECURITY INVOKER` : la fonction n'écrit que dans `transactions`, déjà
-- cloisonnée par la RLS tenant. La version `SECURITY DEFINER` d'origine
-- laissait rembourser le ticket d'un autre salon pour qui connaissait son
-- identifiant.
DROP FUNCTION IF EXISTS public.refund_transaction(UUID, TEXT);

CREATE FUNCTION public.refund_transaction(
  p_transaction_id UUID,
  p_reason TEXT DEFAULT NULL,
  p_amount INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  UPDATE public.transactions
  SET
    -- Un remboursement partiel laisse le ticket payé : la vente a bien eu
    -- lieu, seule une part est rendue. Seul un remboursement intégral bascule
    -- le statut, sinon la commission et le chiffre d'affaires du reste
    -- disparaîtraient avec lui.
    status = CASE
               WHEN COALESCE(p_amount, total_amount_fcfa) >= total_amount_fcfa
               THEN 'refunded'
               ELSE status
             END,
    refunded_amount_fcfa = LEAST(
      COALESCE(p_amount, total_amount_fcfa),
      total_amount_fcfa
    ),
    notes = CASE
              WHEN p_reason IS NOT NULL AND p_reason != ''
              THEN COALESCE(notes, '') || ' [Remboursé: ' || p_reason || ']'
              ELSE COALESCE(notes, '')
            END
  WHERE id = p_transaction_id
    -- Un ticket déjà remboursé ne l'est pas deux fois.
    AND status = 'paid';
END;
$$;

GRANT EXECUTE ON FUNCTION
  public.refund_transaction(UUID, TEXT, INTEGER) TO authenticated;
